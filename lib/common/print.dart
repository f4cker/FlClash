import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';

String compactError(Object error) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    return statusCode != null
        ? 'DioException(${error.type.name}, HTTP $statusCode)'
        : 'DioException(${error.type.name})';
  }
  return error.toString();
}

final _urlPattern = RegExp(
  r'''(?<![A-Za-z0-9+.\-])([a-zA-Z][a-zA-Z0-9+.\-]*)://([^\s"'<>]*)''',
);

final _hostPattern = RegExp(
  r'^(?:[A-Za-z0-9.\-]+|\[[0-9A-Fa-f:.]+\])(?::\d+)?$',
);

final _authorityEnd = RegExp(r'[/?#]');

final _ageSecretKeyPattern = RegExp(
  r'AGE-SECRET-KEY-1[0-9A-Z]+',
  caseSensitive: false,
);

const _hostSchemes = {'http', 'https', 'ws', 'wss'};

/// Cuts every URL in [text] down to scheme and host, so a subscription's
/// path, query token or login never reaches a log the user may export.
/// Share links (vmess://, ss:// …) carry their secrets where a host would be,
/// so anything but a web address keeps only its scheme. `file://` paths in
/// stack traces stay as they are. An age secret key is cut to its prefix.
String redactUrls(String text) {
  final keyless = text.replaceAll(_ageSecretKeyPattern, 'AGE-SECRET-KEY-…');
  if (!keyless.contains('://')) return keyless;
  return keyless.replaceAllMapped(_urlPattern, (match) {
    final scheme = match[1]!;
    final rest = match[2]!;
    if (scheme.toLowerCase() == 'file') return match[0]!;
    // An @ past the first / ? or # may belong to a login holding those
    // characters, or to a token in the path: no host can be trusted then.
    final at = rest.lastIndexOf('@');
    final firstEnd = rest.indexOf(_authorityEnd);
    if (firstEnd >= 0 && at > firstEnd) return '$scheme://…';
    final hostEnd = rest.indexOf(_authorityEnd, at + 1);
    final authority = rest.substring(at + 1, hostEnd < 0 ? null : hostEnd);
    final keepHost =
        _hostSchemes.contains(scheme.toLowerCase()) &&
        _hostPattern.hasMatch(authority);
    return keepHost ? '$scheme://$authority/…' : '$scheme://…';
  });
}

/// Logs a failed update or import as "label: reason" with the reason the failure list
/// shows, and returns that reason for the list.
String logUpdateFailure(
  String label,
  Object error, {
  AppLocalizations? appLocalizations,
  StackTrace? stackTrace,
}) {
  final message = userFacingErrorMessage(
    error,
    appLocalizations ?? currentAppLocalizations,
  );
  final trace = stackTrace == null ? '' : '\n$stackTrace';
  commonPrint.log(
    'failed: $label: $message (${compactError(error)})$trace',
    logLevel: LogLevel.warning,
  );
  return message;
}

class CommonPrint {
  static CommonPrint? _instance;

  CommonPrint._internal();

  factory CommonPrint() {
    _instance ??= CommonPrint._internal();
    return _instance!;
  }

  void log(String? text, {LogLevel logLevel = LogLevel.info}) {
    final payload = redactUrls('[APP] $text');
    debugPrint(payload);
    if (!globalState.isAttach) {
      return;
    }
    globalState.container
        .read(logsProvider.notifier)
        .add(Log.app(payload).copyWith(logLevel: logLevel));
  }
}

final commonPrint = CommonPrint();
