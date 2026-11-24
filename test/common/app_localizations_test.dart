import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/common/network_error.dart';
import 'package:fl_clash/common/webdav.dart';
import 'package:fl_clash/core/desktop/helper_client.dart';
import 'package:fl_clash/core/desktop/launch_policy.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations appLocalizations;

  setUpAll(() async {
    appLocalizations = loadAppLocalizations(const Locale('en'));
  });

  test(
    'login errors use approved localized copy without native details',
    () async {
      try {
        for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
          final localizations = loadAppLocalizations(locale);
          final expected = <String, String>{
            'login_item_requires_approval':
                localizations.loginItemRequiresApproval,
            'login_item_not_found': localizations.loginItemNotFound,
            'login_item_unexpected_status':
                localizations.loginItemUnexpectedStatus,
            'login_item_missing_status': localizations.loginItemMissingStatus,
            'login_item_operation_failed':
                localizations.loginItemOperationFailed,
            'login_item_future_state': localizations.loginItemOperationFailed,
          };
          for (final entry in expected.entries) {
            final error = PlatformException(
              code: entry.key,
              message: 'RAW_NATIVE /Users/private/App.app',
              details: {'path': '/Users/private/App.app', 'nativeCode': 42},
            );
            expect(userFacingErrorMessage(error, localizations), entry.value);
            expect(entry.value, isNot(contains('RAW_NATIVE')));
            expect(entry.value, isNot(contains('/Users/')));
          }
          expect(
            localizations.loginItemRequiresApproval,
            locale.languageCode == 'zh'
                ? '需要在系统设置中允许 Flash 登录时打开。'
                : 'Allow Flash to open at login in System Settings.',
          );
        }
      } finally {
        loadAppLocalizations(const Locale('en'));
      }
    },
  );

  DioException dioError(
    DioExceptionType type, {
    int? statusCode,
    Object? cause,
  }) {
    final options = RequestOptions(path: '/');
    return DioException(
      requestOptions: options,
      type: type,
      error: cause,
      response: statusCode == null
          ? null
          : Response<void>(requestOptions: options, statusCode: statusCode),
    );
  }

  group('Dio failures name their cause', () {
    final cases = <String, (DioException, String Function(AppLocalizations))>{
      'timeout': (
        dioError(DioExceptionType.receiveTimeout),
        (l) => l.networkTimeoutError,
      ),
      'host lookup': (
        dioError(
          DioExceptionType.connectionError,
          cause: const SocketException("Failed host lookup: 'sub.example'"),
        ),
        (l) => l.networkHostLookupError,
      ),
      'refused connection': (
        dioError(
          DioExceptionType.connectionError,
          cause: const SocketException('Connection refused'),
        ),
        (l) => l.networkConnectionError,
      ),
      'TLS handshake': (
        dioError(
          DioExceptionType.unknown,
          cause: const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        ),
        (l) => l.networkTlsError,
      ),
      'bad certificate': (
        dioError(DioExceptionType.badCertificate),
        (l) => l.networkTlsError,
      ),
      'HTTP 403': (
        dioError(DioExceptionType.badResponse, statusCode: 403),
        (l) => l.networkAccessDeniedError(403),
      ),
      'HTTP 404': (
        dioError(DioExceptionType.badResponse, statusCode: 404),
        (l) => l.networkNotFoundError(404),
      ),
      'HTTP 429': (
        dioError(DioExceptionType.badResponse, statusCode: 429),
        (l) => l.networkRateLimitedError,
      ),
      'HTTP 502': (
        dioError(DioExceptionType.badResponse, statusCode: 502),
        (l) => l.networkServerError(502),
      ),
      'HTTP 400': (
        dioError(DioExceptionType.badResponse, statusCode: 400),
        (l) => l.networkBadResponseError(400),
      ),
    };
    for (final MapEntry(key: name, value: (error, expected)) in cases.entries) {
      test(name, () {
        expect(
          networkErrorMessage(error, appLocalizations),
          expected(appLocalizations),
        );
      });
    }
  });

  test('keeps the detail of an unclassified Dio failure', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/'),
      error: const FormatException('bad body'),
      message: 'bad body',
    );
    expect(
      networkErrorMessage(error, appLocalizations),
      appLocalizations.networkRequestFailed('bad body'),
    );
  });

  test('leaves bare socket and timeout errors to the caller', () {
    expect(
      networkErrorMessage(const SocketException('refused'), appLocalizations),
      isNull,
    );
    expect(
      networkErrorMessage(TimeoutException('core'), appLocalizations),
      isNull,
    );
    expect(networkErrorMessage(StateError('boom'), appLocalizations), isNull);
  });

  test('maps WebDAV status failures like any HTTP response', () {
    expect(
      networkErrorMessage(
        const DAVException(method: 'PUT', path: '/a', statusCode: 401),
        appLocalizations,
      ),
      appLocalizations.networkAccessDeniedError(401),
    );
  });

  test('respect rules without a Proxy Server Nameserver reads as the fix, '
      'however the start meets it', () {
    const mihomo =
        'if “respect-rules” is turned on, “proxy-server-nameserver” cannot be '
        'empty';
    try {
      for (final locale in [const Locale('en'), const Locale('zh')]) {
        final l = loadAppLocalizations(locale);
        const rejected = CoreMethodException(
          code: 'mount_rejected',
          message: mihomo,
          details: {'outcome': 'blocked'},
        );
        for (final error in <Object>[
          const DnsRespectRulesUnmetException(),
          rejected,
          const CoreMethodException(code: 'config_rejected', message: mihomo),
          ParallelWaitError<(void, void), (AsyncError?, AsyncError?)>(
            (null, null),
            (AsyncError(rejected, StackTrace.empty), null),
          ),
          ParallelWaitError<(void, void), (AsyncError?, AsyncError?)>(
            (null, null),
            (null, AsyncError(rejected, StackTrace.empty)),
          ),
        ]) {
          expect(userFacingErrorMessage(error, l), l.dnsRespectRulesUnmetError);
        }
        expect(l.dnsRespectRulesUnmetError, isNot(contains('cannot be')));
      }
      expect(
        loadAppLocalizations(const Locale('ja')).dnsRespectRulesUnmetError,
        loadAppLocalizations(const Locale('en')).dnsRespectRulesUnmetError,
      );
    } finally {
      loadAppLocalizations(const Locale('en'));
    }
  });

  test('another error a start waits on still reads as its own', () {
    expect(
      userFacingErrorMessage(
        ParallelWaitError<(void, void), (AsyncError?, AsyncError?)>(
          (null, null),
          (
            AsyncError(
              const CoreMethodException(code: 'x', message: 'core said no'),
              StackTrace.empty,
            ),
            null,
          ),
        ),
        appLocalizations,
      ),
      'core said no',
    );
  });

  test('maps Core request failures by their reason and status', () {
    expect(
      networkErrorMessage(
        const CoreMethodException(
          code: 'request_bad_response',
          message: '403 Forbidden',
          details: {'providerName': 'sub', 'statusCode': 403},
        ),
        appLocalizations,
      ),
      appLocalizations.networkAccessDeniedError(403),
    );
    expect(
      networkErrorMessage(
        const CoreMethodException(
          code: 'request_bad_response',
          message: '503 Service Unavailable',
        ),
        appLocalizations,
      ),
      appLocalizations.networkServerError(503),
    );
    expect(
      networkErrorMessage(
        const CoreMethodException(
          code: 'request_error',
          message: 'context deadline exceeded',
          details: {'reason': 'timeout'},
        ),
        appLocalizations,
      ),
      appLocalizations.networkTimeoutError,
    );
    expect(
      networkErrorMessage(
        const CoreMethodException(code: 'request_error', message: 'odd'),
        appLocalizations,
      ),
      appLocalizations.networkRequestFailed('odd'),
    );
  });

  test('uses the Core message for non-request failures', () {
    expect(
      userFacingErrorMessage(
        const CoreMethodException(
          code: 'provider_update_error',
          message: 'proxy 0: unsupported type',
        ),
        appLocalizations,
      ),
      'proxy 0: unsupported type',
    );
  });

  group('a lost Core session', () {
    test('says the connection is gone when it has no cause', () {
      expect(
        coreSessionLostMessage(null, appLocalizations),
        'The app lost its connection to the core',
      );
      expect(
        coreSessionLostMessage(
          null,
          lookupAppLocalizations(const Locale('zh')),
        ),
        '应用与核心的连接已断开',
      );
    });

    test('adds the cause in the words used for any error', () {
      expect(
        coreSessionLostMessage(
          const CoreMethodException(code: 'io', message: 'pipe reset'),
          appLocalizations,
        ),
        'The app lost its connection to the core: pipe reset',
      );
    });
  });

  group('policy-blocked Core launch', () {
    const blocked = DesktopCoreFailure(
      code: 'start_failed',
      phase: DesktopCorePhase.starting,
      revision: 1,
      cause: HelperException(
        code: 'processLaunchFailed',
        message: 'spawn failed',
        details: {'osError': 577},
      ),
    );

    tearDown(() {
      smartAppControlStateReader = readSmartAppControlState;
    });

    test('names Smart App Control when it is on', () {
      smartAppControlStateReader = () => SmartAppControlState.on;

      expect(
        userFacingErrorMessage(blocked, appLocalizations),
        appLocalizations.coreBlockedBySmartAppControlTip,
      );
    });

    test('names the generic policy with its error code otherwise', () {
      smartAppControlStateReader = () => SmartAppControlState.off;

      expect(
        userFacingErrorMessage(blocked, appLocalizations),
        appLocalizations.coreBlockedByPolicyTip(577),
      );
    });

    test('leaves other start failures on the raw description', () {
      smartAppControlStateReader = () => SmartAppControlState.on;
      const timedOut = DesktopCoreFailure(
        code: 'start_failed',
        phase: DesktopCorePhase.starting,
        revision: 1,
        cause: HelperException(
          code: 'transportError',
          message: 'Helper start request failed',
        ),
      );

      expect(
        userFacingErrorMessage(timedOut, appLocalizations),
        timedOut.toString(),
      );
    });
  });

  test('a provider update the mount gate refused names only the provider', () {
    CoreMethodException refused(Map<String, Object?> details) =>
        CoreMethodException(
          code: 'provider_update_refused_mount',
          message:
              'sub now holds a Tailscale node while subscription nodes '
              'are mounted; apply the profile again to take it',
          details: details,
        );

    expect(
      userFacingErrorMessage(
        refused({'providerName': 'sub', 'kept': true}),
        appLocalizations,
      ),
      appLocalizations.mountProviderUpdateRefused('sub'),
    );
    for (final details in [
      {'providerName': 'sub', 'kept': false},
      {'providerName': 'sub'},
    ]) {
      expect(
        userFacingErrorMessage(refused(details), appLocalizations),
        appLocalizations.mountProviderUpdateRefusedUnconfirmed('sub'),
      );
    }
  });
}
