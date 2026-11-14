import 'dart:async';

import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallNative implements MacHelperNativeApi {
  String state = 'installerRequired';
  String? installationStatus;
  Map<Object?, Object?> result = const {'code': 'authorizationCancelled'};
  Completer<Map<Object?, Object?>>? pending;
  final calls = <String>[];
  final arguments = <Map<String, Object?>>[];

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    this.arguments.add(arguments);
    return switch (method) {
      'status' => {
        'code': state,
        if (installationStatus != null)
          'installationStatus': installationStatus,
      },
      'installerInstructions' => pending?.future ?? result,
      'openApprovalSettings' => {'code': 'approvalRequired'},
      _ => throw StateError('Unexpected native call: $method'),
    };
  }
}

MacHelperMaintenance makeMaintenance(InstallNative native) =>
    MacHelperMaintenance(
      MacHelperClient(native: native, safeMode: () => false),
      stop: () async => const CoreLifecycleResult(
        revision: 1,
        outcome: CoreLifecycleOutcome.applied,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no consent means no status, stop or privileged call', () async {
    final native = InstallNative();
    final flow = makeMaintenance(native);
    expect(
      () => flow.install(confirmed: false),
      throwsA(isA<MacHelperException>()),
    );
    await expectLater(
      flow.client.installerInstructions(confirmed: false),
      throwsA(isA<MacHelperException>()),
    );
    expect(native.calls, isEmpty);
  });

  test('compatible enabled helper is reused without installer', () async {
    final native = InstallNative()..state = 'enabled';
    final flow = makeMaintenance(native);
    expect(await flow.check(), MacHelperState.enabled);
    expect(await flow.install(confirmed: true), MacHelperState.enabled);
    expect(
      await flow.client.installerInstructions(confirmed: true),
      MacHelperState.enabled,
    );
    expect(native.calls, ['status', 'status']);
  });

  test(
    'concurrent install and check join one operation; cancelled is terminal',
    () async {
      final native = InstallNative()..pending = Completer();
      final flow = makeMaintenance(native);
      await flow.check();
      final first = flow.install(confirmed: true);
      final second = flow.install(confirmed: true);
      final check = flow.check();
      expect(identical(first, second), isTrue);
      expect(identical(first, check), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(
        native.calls.where((call) => call == 'installerInstructions'),
        hasLength(1),
      );
      expect(native.arguments.last, {'confirmed': true});
      native.pending!.complete({'code': 'authorizationCancelled'});
      expect(await first, MacHelperState.cancelled);
      expect(flow.busy, isFalse);
      expect(flow.canInstall, isTrue);
      expect(
        native.calls.where((call) => call == 'installerInstructions'),
        hasLength(1),
      );
    },
  );

  for (final code in [
    'authorizationDenied',
    'installationFailed',
    'installerPayloadInvalid',
  ]) {
    test('$code is a finished outcome, never automatic retry', () async {
      final native = InstallNative()..result = {'code': code};
      final flow = makeMaintenance(native);
      await flow.check();
      expect(
        await flow.install(confirmed: true),
        code == 'authorizationDenied'
            ? MacHelperState.denied
            : MacHelperState.failed,
      );
      expect(flow.client.failureCode, code);
      expect(
        native.calls.where((call) => call == 'installerInstructions'),
        hasLength(1),
      );
    });
  }

  test(
    'unknown outcome locks installation until trusted status is enabled',
    () async {
      final native = InstallNative()..result = {'code': 'installationUnknown'};
      final flow = makeMaintenance(native);
      await flow.check();
      expect(await flow.install(confirmed: true), MacHelperState.unknown);
      expect(await flow.install(confirmed: true), MacHelperState.unknown);
      expect(
        await flow.client.installerInstructions(confirmed: true),
        MacHelperState.unknown,
      );
      expect(await flow.check(), MacHelperState.unknown);
      expect(
        native.calls.where((call) => call == 'installerInstructions'),
        hasLength(1),
      );
      native.state = 'enabled';
      expect(await flow.check(), MacHelperState.enabled);
    },
  );

  test(
    'cold unknown status preserves approval remediation and install lock',
    () async {
      final native = InstallNative()
        ..state = 'installationUnknown'
        ..installationStatus = 'approvalRequired';
      final flow = makeMaintenance(native);
      expect(await flow.check(), MacHelperState.approvalRequired);
      await flow.openSettings();
      expect(native.calls.last, 'openApprovalSettings');
      expect(flow.canInstall, isFalse);
      expect(
        await flow.client.installerInstructions(confirmed: true),
        MacHelperState.unknown,
      );
      expect(native.calls, ['status', 'openApprovalSettings']);
    },
  );

  test('installer result alone is not readiness', () async {
    final native = InstallNative()..result = {'code': 'enabled'};
    final flow = makeMaintenance(native);
    await flow.check();
    expect(
      await flow.install(confirmed: true),
      MacHelperState.installerRequired,
    );
    expect(native.calls.last, 'status');
  });

  test(
    'unknown with approval opens settings without repeating privilege',
    () async {
      final native = InstallNative()
        ..result = {
          'code': 'installationUnknown',
          'installationStatus': 'approvalRequired',
        };
      final flow = makeMaintenance(native);
      await flow.check();
      expect(
        await flow.install(confirmed: true),
        MacHelperState.approvalRequired,
      );
      await flow.openSettings();
      expect(native.calls.last, 'openApprovalSettings');
      expect(native.arguments.last, isEmpty);
      expect(flow.canInstall, isFalse);
    },
  );

  for (final state in [
    'protectedInstallationRequired',
    'approvalRequired',
    'signingRequired',
    'unsupported',
  ]) {
    test('$state never attempts installation', () async {
      final native = InstallNative()..state = state;
      final flow = makeMaintenance(native);
      await flow.check();
      await flow.install(confirmed: true);
      await flow.client.installerInstructions(confirmed: true);
      expect(native.calls, everyElement('status'));
    });
  }

  test(
    'startup decline persists across launches; passive readiness still runs',
    () async {
      SharedPreferences.setMockInitialValues({});
      await preferences.rebind();
      var prompts = 0;
      final native = InstallNative();
      Future<bool> startup({bool foreground = true}) => prepareMacHelperStartup(
        maintenance: makeMaintenance(native),
        foreground: foreground,
        wasOffered: preferences.getMacHelperInvitationShown,
        markOffered: preferences.markMacHelperInvitationShown,
        show: () async {
          prompts++;
        },
      );
      expect(await startup(foreground: false), isFalse);
      expect(prompts, 0);
      expect(await startup(), isFalse);
      expect(prompts, 1);
      await preferences.rebind();
      expect(await startup(), isFalse);
      expect(prompts, 1);
      expect(native.calls, ['status', 'status', 'status']);
      native.state = 'enabled';
      expect(await startup(), isTrue);
      expect(prompts, 1);
    },
  );

  test(
    'installing from startup does not auto-start original feature',
    () async {
      final native = InstallNative();
      final flow = makeMaintenance(native);
      final ready = await prepareMacHelperStartup(
        maintenance: flow,
        foreground: true,
        wasOffered: () async => false,
        markOffered: () async {},
        show: () async {
          native.state = 'enabled';
          await flow.check();
        },
      );
      expect(ready, isFalse);
      expect(flow.state, MacHelperState.enabled);
    },
  );
}
