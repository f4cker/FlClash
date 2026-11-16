import 'dart:async';

import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake SMAppService bridge: `status`, `migrate`, `enable`, `repair`,
/// `openApprovalSettings`.
class InstallNative implements MacHelperNativeApi {
  Map<Object?, Object?> statusAnswer = const {'code': 'migrationRequired'};
  Map<Object?, Object?> migrateAnswer = const {'code': 'enabled'};
  Map<Object?, Object?> enableAnswer = const {'code': 'requiresApproval'};
  Map<Object?, Object?> repairAnswer = const {'code': 'enabled'};
  Completer<Map<Object?, Object?>>? pending;
  final calls = <String>[];
  final arguments = <Map<String, Object?>>[];

  set state(String code) => statusAnswer = {'code': code};

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    this.arguments.add(arguments);
    return switch (method) {
      'status' => statusAnswer,
      'migrate' => pending?.future ?? migrateAnswer,
      'enable' => enableAnswer,
      'repair' => repairAnswer,
      'openApprovalSettings' => const {'code': 'requiresApproval'},
      _ => throw StateError('Unexpected native call: $method'),
    };
  }
}

class _ThrowingNative implements MacHelperNativeApi {
  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async => throw Exception('channel closed');
}

MacHelperMaintenance makeMaintenance(
  InstallNative native, {
  Future<CoreLifecycleResult> Function()? stop,
}) => MacHelperMaintenance(
  MacHelperClient(native: native, safeMode: () => false),
  stop:
      stop ??
      () async => const CoreLifecycleResult(
        revision: 1,
        outcome: CoreLifecycleOutcome.applied,
      ),
  // Keep the start-up poll out of these tests' way.
  startPoll: const Duration(hours: 1),
  startTimeout: const Duration(hours: 1),
);

const nativeCodes = [
  'enabled',
  'requiresApproval',
  'notRegistered',
  'migrationRequired',
  'migrationIncomplete',
  'migrationFailed',
  'registrationFailed',
  'signingRequired',
  'notFound',
  'incompatible',
  'moveRequired',
  'unsupported',
  'unavailable',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('state mapping', () {
    test('native codes map to the card states', () {
      expect(MacHelperState.parse('enabled'), MacHelperState.enabled);
      expect(
        MacHelperState.parse('requiresApproval'),
        MacHelperState.requiresApproval,
      );
      expect(
        MacHelperState.parse('requiresApproval', true),
        MacHelperState.disabledByUser,
      );
      expect(
        MacHelperState.parse('notRegistered'),
        MacHelperState.notRegistered,
      );
      expect(
        MacHelperState.parse('migrationRequired'),
        MacHelperState.migrationRequired,
      );
      for (final code in [
        'migrationIncomplete',
        'migrationFailed',
        'registrationFailed',
        'authorizationDenied',
      ]) {
        expect(MacHelperState.parse(code), MacHelperState.updateFailed);
      }
      expect(
        MacHelperState.parse('signingRequired'),
        MacHelperState.signatureFailed,
      );
      expect(
        MacHelperState.parse('notFound'),
        MacHelperState.reinstallRequired,
      );
      expect(
        MacHelperState.parse('incompatible'),
        MacHelperState.reinstallRequired,
      );
      expect(MacHelperState.parse('moveRequired'), MacHelperState.moveRequired);
      expect(MacHelperState.parse('staleHelper'), MacHelperState.staleHelper);
      expect(MacHelperState.parse('unavailable'), MacHelperState.starting);
      expect(MacHelperState.parse('garbage'), MacHelperState.unavailable);
      expect(MacHelperState.parse(null), MacHelperState.unavailable);
    });

    test('failed step and raw detail survive a generic incomplete', () async {
      final native = InstallNative()
        ..migrateAnswer = {
          'code': 'migrationFailed',
          'step': 'removeOld',
          'detail': 'rm: Operation not permitted',
          'residue': ['/Library/LaunchDaemons/old.plist'],
        };
      final flow = makeMaintenance(native);
      await flow.check();
      expect(await flow.migrate(confirmed: true), MacHelperState.updateFailed);
      expect(flow.failure!.step, MacHelperFailedStep.removeOld);
      expect(flow.failure!.detail, contains('Operation not permitted'));
      expect(flow.failure!.detail, contains('old.plist'));
      expect(flow.lastCode, 'migrationFailed');
      native.state = 'migrationIncomplete';
      expect(await flow.check(), MacHelperState.updateFailed);
      expect(flow.failure!.step, MacHelperFailedStep.removeOld);
      native.state = 'enabled';
      expect(await flow.check(), MacHelperState.enabled);
      expect(flow.failure, isNull);
    });

    test('registration failure reports the register step', () async {
      final native = InstallNative()
        ..migrateAnswer = {
          'code': 'registrationFailed',
          'domain': 'SMAppServiceErrorDomain',
          'error': 1,
        };
      final flow = makeMaintenance(native);
      expect(await flow.migrate(confirmed: true), MacHelperState.updateFailed);
      expect(flow.failure!.step, MacHelperFailedStep.registerNew);
      expect(flow.failure!.detail, contains('SMAppServiceErrorDomain'));
    });

    test(
      'cancelled administrator prompt returns to migration required',
      () async {
        final native = InstallNative()
          ..migrateAnswer = {'code': 'authorizationCancelled'};
        final flow = makeMaintenance(native);
        expect(
          await flow.migrate(confirmed: true),
          MacHelperState.migrationRequired,
        );
        expect(flow.failure, isNull);
      },
    );

    test('channel error is unavailable with a copyable code', () async {
      final client = MacHelperClient(
        native: _ThrowingNative(),
        safeMode: () => false,
      );
      expect(await client.status(), MacHelperState.unavailable);
      expect(client.lastCode, 'channelError');
    });
  });

  for (final code in nativeCodes) {
    test(
      'silent startup settles connecting for $code without effects',
      () async {
        final container = ProviderContainer(
          overrides: [
            coreStatusProvider.overrideWithBuild(
              (_, _) => CoreStatus.connecting,
            ),
          ],
        );
        addTearDown(container.dispose);
        final native = InstallNative()..state = code;
        final flow = makeMaintenance(native);
        addTearDown(flow.dispose);
        final ready = await prepareMacHelperStartup(
          maintenance: flow,
          foreground: false,
          onBlocked: () => container.read(coreStatusProvider.notifier).value =
              CoreStatus.disconnected,
          wasOffered: () async =>
              fail('Silent startup must not inspect invitation history'),
          markOffered: () async =>
              fail('Silent startup must not mark an invitation'),
          show: () async => fail('Silent startup must not open a dialog'),
        );
        expect(ready, code == 'enabled');
        expect(
          container.read(coreStatusProvider),
          ready ? CoreStatus.connecting : CoreStatus.disconnected,
        );
        expect(native.calls, ['status']);
      },
    );
  }

  test('stale helper is asked to exit once, then waits', () async {
    final native = InstallNative()
      ..state = 'staleHelper'
      ..repairAnswer = {'code': 'staleHelper'};
    final flow = makeMaintenance(native);
    addTearDown(flow.dispose);
    expect(await flow.check(), MacHelperState.staleHelper);
    expect(await flow.check(), MacHelperState.staleHelper);
    expect(native.calls, ['status', 'repair', 'status']);
    native.state = 'enabled';
    expect(await flow.check(), MacHelperState.enabled);
  });

  test('stale helper replaced by repair is ready', () async {
    final native = InstallNative()..state = 'staleHelper';
    final flow = makeMaintenance(native);
    expect(await flow.check(), MacHelperState.enabled);
    expect(native.calls, ['status', 'repair']);
  });

  test('startup joining migration cannot resume the feature', () async {
    final native = InstallNative()..pending = Completer();
    final flow = makeMaintenance(native);
    await flow.check();
    final migration = flow.migrate(confirmed: true);
    await Future<void>.delayed(Duration.zero);
    var blocked = false;
    final startup = prepareMacHelperStartup(
      maintenance: flow,
      foreground: false,
      onBlocked: () => blocked = true,
      wasOffered: () async => false,
      markOffered: () async => fail('No invitation while joining maintenance'),
      show: () async => fail('No popup while joining maintenance'),
    );
    native.pending!.complete({'code': 'enabled'});
    expect(await migration, MacHelperState.enabled);
    expect(await startup, isFalse);
    expect(blocked, isTrue);
  });

  test('no consent means no stop and no privileged call', () async {
    var stops = 0;
    final native = InstallNative();
    final flow = makeMaintenance(
      native,
      stop: () async {
        stops++;
        return const CoreLifecycleResult(
          revision: 1,
          outcome: CoreLifecycleOutcome.applied,
        );
      },
    );
    expect(
      () => flow.migrate(confirmed: false),
      throwsA(isA<MacHelperException>()),
    );
    expect(
      () => flow.client.migrate(confirmed: false),
      throwsA(isA<MacHelperException>()),
    );
    expect(native.calls, isEmpty);
    expect(stops, 0);
  });

  test('migration stops the Core first and sends consent', () async {
    final order = <String>[];
    final native = InstallNative();
    final flow = makeMaintenance(
      native,
      stop: () async {
        order.add('stop');
        return const CoreLifecycleResult(
          revision: 1,
          outcome: CoreLifecycleOutcome.applied,
        );
      },
    );
    expect(await flow.migrate(confirmed: true), MacHelperState.enabled);
    order.addAll(native.calls);
    expect(order, ['stop', 'migrate']);
    expect(native.arguments.last, {'confirmed': true});
  });

  test('unconfirmed Core stop blocks the privileged step', () async {
    final native = InstallNative();
    final flow = makeMaintenance(
      native,
      stop: () async => throw StateError('stop failed'),
    );
    expect(await flow.migrate(confirmed: true), MacHelperState.exitUnconfirmed);
    expect(native.calls, isEmpty);
    expect(await flow.retry(), MacHelperState.exitUnconfirmed);
    expect(native.calls, isEmpty);
  });

  test('concurrent migrate and check join one operation', () async {
    final native = InstallNative()..pending = Completer();
    final flow = makeMaintenance(native);
    await flow.check();
    final first = flow.migrate(confirmed: true);
    final second = flow.retry();
    final check = flow.check();
    expect(identical(first, second), isTrue);
    expect(identical(first, check), isTrue);
    expect(flow.progress, MacHelperProgress.updating);
    await Future<void>.delayed(Duration.zero);
    expect(native.calls.where((call) => call == 'migrate'), hasLength(1));
    native.pending!.complete({'code': 'authorizationCancelled'});
    expect(await first, MacHelperState.migrationRequired);
    expect(flow.busy, isFalse);
    expect(flow.progress, MacHelperProgress.idle);
    expect(native.calls.where((call) => call == 'migrate'), hasLength(1));
  });

  test('failed update is never retried automatically', () async {
    final native = InstallNative()
      ..migrateAnswer = {'code': 'migrationFailed', 'step': 'stopOld'};
    final flow = makeMaintenance(native);
    expect(await flow.migrate(confirmed: true), MacHelperState.updateFailed);
    native.statusAnswer = {'code': 'migrationIncomplete'};
    await flow.check();
    await flow.check();
    expect(native.calls.where((call) => call == 'migrate'), hasLength(1));
    expect(flow.failure!.step, MacHelperFailedStep.stopOld);
    native.migrateAnswer = {'code': 'enabled'};
    expect(await flow.retry(), MacHelperState.enabled);
    expect(native.calls.where((call) => call == 'migrate'), hasLength(2));
  });

  test(
    'not registered: open settings registers, then opens settings',
    () async {
      final native = InstallNative()..state = 'notRegistered';
      final flow = makeMaintenance(native);
      expect(await flow.check(), MacHelperState.notRegistered);
      expect(flow.needsApproval, isTrue);
      await flow.openSettings();
      expect(native.calls, ['status', 'enable', 'openApprovalSettings']);
      expect(flow.state, MacHelperState.requiresApproval);
      expect(flow.awaitingSettings, isTrue);
    },
  );

  test('registration that is immediately enabled skips settings', () async {
    final native = InstallNative()
      ..state = 'notRegistered'
      ..enableAnswer = {'code': 'enabled'};
    final flow = makeMaintenance(native);
    await flow.check();
    await flow.openSettings();
    expect(native.calls, ['status', 'enable']);
    expect(flow.state, MacHelperState.enabled);
    expect(flow.awaitingSettings, isFalse);
  });

  test('returning from settings re-checks once', () async {
    final native = InstallNative()
      ..statusAnswer = {'code': 'requiresApproval', 'previouslyEnabled': true};
    final flow = makeMaintenance(native);
    expect(await flow.check(), MacHelperState.disabledByUser);
    await flow.openSettings();
    expect(native.calls, ['status', 'openApprovalSettings']);
    native.state = 'enabled';
    flow.resumed();
    await Future<void>.delayed(Duration.zero);
    expect(flow.busy, isFalse);
    expect(flow.state, MacHelperState.enabled);
    expect(flow.awaitingSettings, isFalse);
    flow.resumed();
    await Future<void>.delayed(Duration.zero);
    expect(native.calls.where((call) => call == 'status'), hasLength(2));
  });

  for (final code in [
    'enabled',
    'migrationRequired',
    'signingRequired',
    'notFound',
    'moveRequired',
    'unsupported',
  ]) {
    test('$code never opens settings or registers', () async {
      final native = InstallNative()..state = code;
      final flow = makeMaintenance(native);
      await flow.check();
      await flow.openSettings();
      expect(native.calls, ['status']);
    });
  }

  test('signature failure offers no startup bypass', () async {
    final native = InstallNative()..state = 'signingRequired';
    var stops = 0;
    var prompts = 0;
    final flow = makeMaintenance(
      native,
      stop: () async {
        stops++;
        return const CoreLifecycleResult(
          revision: 1,
          outcome: CoreLifecycleOutcome.applied,
        );
      },
    );
    expect(await flow.check(), MacHelperState.signatureFailed);
    expect(
      await prepareMacHelperStartup(
        maintenance: flow,
        foreground: true,
        onBlocked: () {},
        wasOffered: () async => false,
        markOffered: () async => prompts++,
        show: () async => prompts++,
      ),
      isFalse,
    );
    expect(stops, 0);
    expect(prompts, 0);
    expect(native.calls, everyElement('status'));
  });

  test(
    'approved daemon that does not answer is "starting", then slow',
    () async {
      final native = InstallNative()..state = 'unavailable';
      final flow = MacHelperMaintenance(
        MacHelperClient(native: native, safeMode: () => false),
        stop: () async => const CoreLifecycleResult(
          revision: 1,
          outcome: CoreLifecycleOutcome.applied,
        ),
        startPoll: const Duration(milliseconds: 5),
        startTimeout: const Duration(milliseconds: 40),
      );
      addTearDown(flow.dispose);
      expect(await flow.check(), MacHelperState.starting);
      expect(flow.startSlow, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(flow.startSlow, isTrue);
      final polls = native.calls.length;
      expect(polls, greaterThan(1));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(native.calls.length, polls, reason: 'polling stops once slow');
      native.state = 'enabled';
      expect(await flow.recheck(), MacHelperState.enabled);
      expect(flow.startSlow, isFalse);
    },
  );

  test(
    'startup invitation persists across launches; passive check still runs',
    () async {
      SharedPreferences.setMockInitialValues({});
      await preferences.rebind();
      var prompts = 0;
      final native = InstallNative();
      Future<bool> startup({bool foreground = true}) => prepareMacHelperStartup(
        maintenance: makeMaintenance(native),
        foreground: foreground,
        onBlocked: () {},
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

  test('migrating from startup does not auto-start the feature', () async {
    final native = InstallNative();
    final flow = makeMaintenance(native);
    var blocked = false;
    final ready = await prepareMacHelperStartup(
      maintenance: flow,
      foreground: true,
      onBlocked: () => blocked = true,
      wasOffered: () async => false,
      markOffered: () async {},
      show: () async {
        expect(blocked, isTrue);
        await flow.migrate(confirmed: true);
      },
    );
    expect(ready, isFalse);
    expect(flow.state, MacHelperState.enabled);
  });
}
