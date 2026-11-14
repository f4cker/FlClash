import 'package:fl_clash/common/launch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

class _FakeLauncher implements LaunchAtStartup {
  bool enabled = false;
  PlatformException? readFailure;
  final calls = <String>[];

  @override
  void setup({
    required String appName,
    required String appPath,
    String? packageName,
    List<String> args = const [],
  }) {
    calls.add('setup');
  }

  @override
  Future<bool> isEnabled() async {
    calls.add('isEnabled');
    if (readFailure != null) throw readFailure!;
    return enabled;
  }

  @override
  Future<bool> enable() async {
    calls.add('enable');
    enabled = true;
    return true;
  }

  @override
  Future<bool> disable() async {
    calls.add('disable');
    enabled = false;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalLauncher = AutoLaunch.launcher;
  late _FakeLauncher launcher;
  late AutoLaunch autoLaunch;

  setUp(() {
    launcher = _FakeLauncher();
    AutoLaunch.launcher = launcher;
    autoLaunch = AutoLaunch();
    launcher.calls.clear();
  });

  tearDownAll(() {
    AutoLaunch.launcher = originalLauncher;
  });

  test('AutoLaunch is a singleton', () {
    expect(AutoLaunch(), same(autoLaunch));
  });

  test('each call delegates straight to the launcher', () async {
    launcher.enabled = true;
    expect(await autoLaunch.isEnable, isTrue);

    expect(await autoLaunch.disable(), isTrue);
    expect(launcher.enabled, isFalse);

    expect(await autoLaunch.enable(), isTrue);
    expect(launcher.enabled, isTrue);

    expect(launcher.calls, ['isEnabled', 'disable', 'enable']);
  });

  test(
    'status refresh saves only verified actual state without setters',
    () async {
      var displayed = true;
      launcher.enabled = false;
      await autoLaunch.refreshStatus((enabled) => displayed = enabled);
      expect(displayed, isFalse);
      launcher.enabled = true;
      await autoLaunch.refreshStatus((enabled) => displayed = enabled);
      expect(displayed, isTrue);
      expect(launcher.calls, ['isEnabled', 'isEnabled']);
    },
  );

  test(
    'failed refresh preserves known preference and propagates error',
    () async {
      var displayed = false;
      launcher.readFailure = PlatformException(
        code: 'login_item_requires_approval',
      );
      await expectLater(
        autoLaunch.refreshStatus((enabled) => displayed = enabled),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'login_item_requires_approval',
          ),
        ),
      );
      expect(displayed, isFalse);
      expect(launcher.calls, ['isEnabled']);
    },
  );

  test('a debug build never registers autostart', () async {
    expect(
      kDebugMode,
      isTrue,
      reason: 'flutter test runs in debug; the guard below assumes it.',
    );

    await autoLaunch.updateStatus(true);
    await autoLaunch.updateStatus(false);

    expect(
      launcher.calls,
      isEmpty,
      reason:
          'updateStatus must return before reading or writing the autostart '
          'entry, or every debug run would register the running binary.',
    );
  });

  group('macOS main-app login channel', () {
    final macOS = MacOSLoginItemLauncher();
    final calls = <MethodCall>[];
    Object? response;
    PlatformException? failure;

    setUp(() {
      calls.clear();
      response = null;
      failure = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MacOSLoginItemLauncher.channel, (
            call,
          ) async {
            calls.add(call);
            if (failure != null) throw failure!;
            return response;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MacOSLoginItemLauncher.channel, null);
    });

    test('reads the existing Boolean channel contract', () async {
      response = true;
      expect(await macOS.isEnabled(), isTrue);
      response = false;
      expect(await macOS.isEnabled(), isFalse);
      expect(calls.map((call) => call.method), [
        'launchAtStartupIsEnabled',
        'launchAtStartupIsEnabled',
      ]);
    });

    test('null status is not converted to false', () async {
      await expectLater(
        macOS.isEnabled(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'login_item_missing_status',
          ),
        ),
      );
    });

    test('both setters reach native without a Boolean preflight', () async {
      expect(await macOS.enable(), isTrue);
      expect(await macOS.disable(), isTrue);
      expect(calls.map((call) => call.method), [
        'launchAtStartupSetEnabled',
        'launchAtStartupSetEnabled',
      ]);
      expect(calls.map((call) => call.arguments), [
        {'setEnabledValue': true},
        {'setEnabledValue': false},
      ]);
    });

    for (final code in [
      'login_item_requires_approval',
      'login_item_not_found',
      'login_item_operation_failed',
      'login_item_unexpected_status',
    ]) {
      test('$code is never reported as Boolean success', () async {
        failure = PlatformException(
          code: code,
          message: 'Not applied',
          details: {'status': 'requiresApproval', 'nativeCode': 42},
        );
        final matcher = throwsA(
          isA<PlatformException>()
              .having((error) => error.code, 'code', code)
              .having((error) => error.details, 'details', failure!.details),
        );
        await expectLater(macOS.enable(), matcher);
        await expectLater(macOS.disable(), matcher);
        await expectLater(macOS.isEnabled(), matcher);
      });
    }
  });
}
