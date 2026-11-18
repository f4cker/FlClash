import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/macos_repair_record.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Native side: `status` and `approvalStatus` answer [status]; everything else
/// is recorded.
final class _Native implements MacHelperNativeApi {
  final calls = <String>[];
  Map<Object?, Object?> status = const {'code': 'enabled'};
  Map<Object?, Object?> recover = const {'code': 'enabled'};
  Map<Object?, Object?> enable = const {'code': 'requiresApproval'};

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    return switch (method) {
      'status' || 'approvalStatus' => status,
      'enable' => enable,
      'recover' => recover,
      'openApprovalSettings' => const {'code': 'settingsOpened'},
      _ => throw StateError('Unexpected native call: $method'),
    };
  }
}

const _applied = CoreLifecycleResult(
  revision: 1,
  outcome: CoreLifecycleOutcome.applied,
);

void main() {
  late _Native native;
  late MacHelperClient client;
  late List<String> steps;
  late List<MacHelperState> recoverAnswers;
  late bool pending;
  late bool settleStillPending;

  MacHelperMaintenance flowWith({
    int maxAutoRecoveries = 2,
    int maxApprovalPolls = 90,
  }) => MacHelperMaintenance(
    client,
    stop: () async => _applied,
    recover: () async {
      steps.add('recover');
      pending = true;
      return recoverAnswers.isEmpty
          ? MacHelperState.registrationStale
          : recoverAnswers.removeAt(0);
    },
    settleRepair: () async {
      steps.add('settle');
      pending = settleStillPending;
      return pending;
    },
    repairPending: () async => pending,
    startPoll: const Duration(hours: 1),
    startTimeout: const Duration(hours: 1),
    approvalPoll: const Duration(milliseconds: 5),
    recoveryRetryDelay: Duration.zero,
    maxAutoRecoveries: maxAutoRecoveries,
    maxApprovalPolls: maxApprovalPolls,
  );

  setUp(() {
    native = _Native();
    client = MacHelperClient(native: native, safeMode: () => false);
    steps = [];
    recoverAnswers = [];
    pending = false;
    settleStillPending = false;
  });

  Future<void> settle([int rounds = 20]) async {
    for (var i = 0; i < rounds; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('a stale registration recovers by itself, then needs one approval '
      'that continues after the user returns', () async {
    native.status = const {'code': 'registrationStale', 'launchd': 'exit 78'};
    recoverAnswers = [MacHelperState.requiresApproval];
    final flow = flowWith();
    var started = 0;
    flow.runOnceReady(() async => started++);

    expect(await flow.check(), MacHelperState.requiresApproval);
    expect(steps, ['recover']);
    expect(flow.autoRecoveries, 1);
    expect(flow.repairPending, isTrue);
    final l = lookupAppLocalizations(const Locale('zh'));
    final view = macHelperCardView(l, flow);
    expect(view.kind, MacHelperCardKind.approval);
    expect(view.primary, MacHelperCardAction.openSettings);
    expect(view.secondary, isNull);
    expect(view.detail, contains('关掉再打开'));

    // Nothing polls while the card only shows the step.
    native.calls.clear();
    await settle();
    expect(native.calls, isEmpty);

    native.status = const {'code': 'requiresApproval'};
    await flow.openSettings();
    expect(native.calls, ['openApprovalSettings']);
    expect(flow.awaitingSettings, isTrue);
    // The user turns the switch off and on; Flash is still in the background.
    native.status = const {'code': 'enabled'};
    await settle();
    expect(native.calls, containsAllInOrder(['approvalStatus', 'status']));
    expect(flow.state, MacHelperState.enabled);
    // The ready helper confirmed no old Core runs; only then the Core starts.
    expect(steps, ['recover', 'settle']);
    expect(flow.repairPending, isFalse);
    expect(started, 1);

    // Back in the foreground: nothing more to do, the Core is not started
    // again.
    flow.resumed();
    await settle();
    expect(started, 1);
    flow.dispose();
  });

  test(
    'a registration under the retired name is moved by the same recovery; '
    'the new name needing approval continues after the user returns',
    () async {
      native.status = const {
        'code': 'retiredRegistration',
        'detail': 'com.layoute.flash.daemon: enabled',
      };
      recoverAnswers = [MacHelperState.requiresApproval];
      final flow = flowWith();
      var started = 0;
      flow.runOnceReady(() async => started++);

      expect(await flow.check(), MacHelperState.requiresApproval);
      expect(steps, ['recover']);
      expect(flow.failure, isNull);
      expect(flow.rawDetail, contains('com.layoute.flash.daemon'));
      final view = macHelperCardView(
        lookupAppLocalizations(const Locale('zh')),
        flow,
      );
      expect(view.kind, MacHelperCardKind.approval);
      expect(view.primary, MacHelperCardAction.openSettings);
      expect(view.detail, contains('关掉再打开'));
      expect(started, 0);

      // The retired name is gone; the new one waits for the user.
      native.status = const {'code': 'requiresApproval'};
      await flow.openSettings();
      native.status = const {'code': 'enabled'};
      flow.resumed();
      await settle();
      expect(flow.state, MacHelperState.enabled);
      expect(steps, ['recover', 'settle']);
      expect(started, 1);
      flow.dispose();
    },
  );

  test('without a retired name nothing is recovered', () async {
    native.status = const {'code': 'notRegistered'};
    final flow = flowWith();
    expect(await flow.check(), MacHelperState.notRegistered);
    expect(steps, isEmpty);
    await flow.openSettings();
    expect(
      native.calls,
      containsAllInOrder(['enable', 'openApprovalSettings']),
    );
    expect(steps, isEmpty);
    flow.dispose();
  });

  test('a retired unregister that timed out or failed is only a detail of '
      'the new registration', () async {
    native.recover = const {
      'code': 'enabled',
      'retiredUnregister': 'timeout',
      'detail':
          'retired com.layoute.flash.daemon (enabled): unregister: no '
          'completion within 15 s; status: enabled\nnew helper answered',
    };
    expect(
      await client.maintain(() => client.recover()),
      MacHelperState.enabled,
    );
    expect(client.failure, isNull);
    expect(client.lastDetail, contains('no completion within 15 s'));

    native.recover = const {
      'code': 'requiresApproval',
      'retiredUnregister': 'failed',
      'domain': 'SMAppServiceErrorDomain',
      'error': 1,
      'detail':
          'retired com.layoute.flash.daemon (enabled): unregister: '
          'SMAppServiceErrorDomain 1; status: enabled\n'
          'register: SMAppServiceErrorDomain 1; status: requiresApproval',
    };
    expect(
      await client.maintain(() => client.recover()),
      MacHelperState.requiresApproval,
    );
    expect(client.failure, isNull);
    expect(client.lastDetail, contains('unregister: SMAppServiceErrorDomain'));
  });

  group('register refused (EPERM) while the system says notRegistered', () {
    const refused = {
      'code': 'requiresApproval',
      'serviceStatus': 'notRegistered',
      'domain': 'SMAppServiceErrorDomain',
      'error': 1,
    };

    MacHelperMaintenance flowThroughClient() => MacHelperMaintenance(
      client,
      stop: () async => _applied,
      recover: () => client.maintain(() => client.recover()),
      startPoll: const Duration(hours: 1),
      startTimeout: const Duration(hours: 1),
      approvalPoll: const Duration(milliseconds: 5),
      maxApprovalPolls: 0,
    );

    int count(String method) => native.calls.where((c) => c == method).length;

    test('mitm.3: after the user turned Flash on, returning to the '
        'foreground registers once by itself', () async {
      native.status = const {
        'code': 'retiredRegistration',
        'detail': 'com.layoute.flash.daemon: enabled',
      };
      native.recover = refused;
      final flow = flowThroughClient();
      var started = 0;
      flow.runOnceReady(() async => started++);
      expect(await flow.check(), MacHelperState.requiresApproval);
      expect(client.lastServiceStatus, 'notRegistered');

      native.status = const {'code': 'requiresApproval'};
      await flow.openSettings();
      expect(count('enable'), 0);
      // The switch is on now, but the new name is still not registered.
      native.status = const {'code': 'notRegistered'};
      native.enable = const {'code': 'enabled'};
      native.calls.clear();
      flow.resumed();
      await settle();
      expect(native.calls, ['status', 'enable']);
      expect(flow.state, MacHelperState.enabled);
      expect(flow.resumeEnables, 1);
      expect(started, 1);

      // Nothing more on later returns.
      native.calls.clear();
      flow.resumed();
      await settle();
      expect(count('enable'), 0);
      flow.dispose();
    });

    test('the same from the card\'s enable; only once, never a loop', () async {
      native.status = const {'code': 'notRegistered'};
      native.enable = refused;
      final flow = flowThroughClient();
      expect(await flow.check(), MacHelperState.notRegistered);
      await flow.openSettings();
      expect(count('enable'), 1);
      expect(flow.state, MacHelperState.requiresApproval);

      // The user came back without turning it on: one more register, which
      // is refused the same way and does not arm another one.
      native.calls.clear();
      flow.resumed();
      await settle();
      expect(native.calls, ['status', 'enable']);
      expect(flow.state, MacHelperState.requiresApproval);
      for (var i = 0; i < 3; i++) {
        native.calls.clear();
        flow.resumed();
        await settle();
        expect(native.calls, ['status']);
      }
      expect(flow.resumeEnables, 1);
      expect(flow.state, MacHelperState.notRegistered);
      flow.dispose();
    });

    test('not armed when the system already counts it registered, or when '
        'the daemon got registered meanwhile', () async {
      native.status = const {'code': 'notRegistered'};
      native.enable = const {
        'code': 'requiresApproval',
        'serviceStatus': 'requiresApproval',
      };
      var flow = flowThroughClient();
      await flow.check();
      await flow.openSettings();
      native.calls.clear();
      flow.resumed();
      await settle();
      expect(native.calls, ['status']);
      flow.dispose();

      native.enable = refused;
      flow = flowThroughClient();
      await flow.check();
      await flow.openSettings();
      native.status = const {'code': 'enabled'};
      native.calls.clear();
      flow.resumed();
      await settle();
      expect(native.calls, ['status']);
      expect(flow.state, MacHelperState.enabled);
      expect(flow.resumeEnables, 0);
      flow.dispose();
    });

    test('a launch budget bounds it', () async {
      native.status = const {'code': 'notRegistered'};
      native.enable = refused;
      final flow = MacHelperMaintenance(
        client,
        stop: () async => _applied,
        startPoll: const Duration(hours: 1),
        startTimeout: const Duration(hours: 1),
        maxApprovalPolls: 0,
        maxResumeEnables: 1,
      );
      await flow.check();
      for (var i = 0; i < 3; i++) {
        await flow.check();
        await flow.openSettings();
        flow.resumed();
        await settle();
      }
      expect(flow.resumeEnables, 1);
      // 3 from the card, 1 by itself.
      expect(count('enable'), 4);
      flow.dispose();
    });
  });

  test('versionStale is not a stale registration: staleHelper and timeout '
      'wait, nothing is recovered', () async {
    final flow = flowWith();
    native.status = const {
      'code': 'staleHelper',
      'launchd': 'state=running parentVersion=2026111710 current=2026111711',
    };
    expect(await flow.check(), MacHelperState.staleHelper);
    native.status = const {
      'code': 'timeout',
      'launchd':
          'state=not running parentVersion=2026111710 current=2026111711',
    };
    expect(await flow.check(), MacHelperState.starting);
    expect(steps, isEmpty);
    expect(flow.autoRecoveries, 0);
    flow.dispose();
  });

  test('refusal cards (79, launcher 81–87) are not recovered', () async {
    final flow = flowWith();
    for (final code in [
      'launcherCheckFailed',
      'launcherDowngrade',
      'launcherFailed',
    ]) {
      native.status = {
        'code': code,
        'detail': 'last exit code: 79: the helper refused to run',
      };
      expect(await flow.check(), MacHelperState.parse(code));
    }
    expect(steps, isEmpty);
    expect(flow.rawDetail, contains('last exit code: 79'));
    flow.dispose();
  });

  test('the retired registration reads as a stale registration', () {
    expect(
      MacHelperState.parse('retiredRegistration'),
      MacHelperState.registrationStale,
    );
  });

  test('returning to the foreground continues without any poll', () async {
    native.status = const {'code': 'requiresApproval'};
    final flow = flowWith(maxApprovalPolls: 0);
    await flow.check();
    await flow.openSettings();
    native.calls.clear();
    await settle();
    expect(native.calls, isEmpty, reason: 'poll budget is zero');
    native.status = const {'code': 'enabled'};
    flow.resumed();
    await settle();
    expect(native.calls, ['status']);
    expect(flow.state, MacHelperState.enabled);
    flow.dispose();
  });

  test('the Settings poll is bounded and ends on return', () async {
    native.status = const {'code': 'requiresApproval'};
    final flow = flowWith(maxApprovalPolls: 3);
    await flow.check();
    await flow.openSettings();
    native.calls.clear();
    await settle(30);
    expect(native.calls, [
      'approvalStatus',
      'approvalStatus',
      'approvalStatus',
    ]);
    flow.resumed();
    await settle();
    expect(native.calls.last, 'status');
    native.calls.clear();
    await settle();
    expect(native.calls, isEmpty);
    flow.dispose();
  });

  test('automatic recoveries are bounded; the card then offers one more '
      'and the raw text only behind details', () async {
    native.status = const {
      'code': 'registrationStale',
      'launchd': 'state = spawn failed, last exit code = 78',
    };
    final flow = flowWith(maxAutoRecoveries: 2);
    var started = 0;
    flow.runOnceReady(() async => started++);
    expect(await flow.check(), MacHelperState.registrationStale);
    expect(steps, ['recover', 'recover']);
    // A later check does not recover again by itself.
    expect(await flow.check(), MacHelperState.registrationStale);
    expect(steps, ['recover', 'recover']);
    final l = lookupAppLocalizations(const Locale('zh'));
    final view = macHelperCardView(l, flow);
    expect(view.kind, MacHelperCardKind.notReady);
    expect(view.title, '辅助程序暂未就绪');
    expect(view.primary, MacHelperCardAction.recover);
    expect(view.secondary, MacHelperCardAction.viewDetails);
    expect(view.detail, isNot(contains('78')));
    expect(view.rawDetail, contains('last exit code = 78'));
    for (final text in [view.title, view.detail]) {
      expect(text, isNot(contains('重启')));
    }

    recoverAnswers = [MacHelperState.enabled];
    expect(await flow.retryRecovery(), MacHelperState.enabled);
    expect(steps, ['recover', 'recover', 'recover', 'settle']);
    expect(started, 1);
    flow.dispose();
  });

  test('a recovery is settled only when the ready helper confirms old Cores '
      'stopped; until then no Core starts', () async {
    native.status = const {'code': 'registrationStale'};
    recoverAnswers = [MacHelperState.enabled];
    settleStillPending = true;
    final flow = flowWith();
    var started = 0;
    flow.runOnceReady(() async => started++);
    expect(await flow.check(), MacHelperState.staleCore);
    expect(flow.repairPending, isTrue);
    expect(started, 0);
    final view = macHelperCardView(
      lookupAppLocalizations(const Locale('zh')),
      flow,
    );
    expect(view.kind, MacHelperCardKind.notReady);
    expect(view.detail, '旧内核尚未确认停止，请查看详情。');

    native.status = const {'code': 'enabled'};
    settleStillPending = false;
    flow.resumed();
    await settle();
    expect(flow.state, MacHelperState.enabled);
    expect(started, 1);
    flow.dispose();
  });

  test(
    'a recovery that throws reads "not ready" with its text in details',
    () async {
      native.status = const {'code': 'registrationStale'};
      final flow = MacHelperMaintenance(
        client,
        stop: () async => _applied,
        recover: () async => throw const MacHelperException('timeout'),
        startPoll: const Duration(hours: 1),
        startTimeout: const Duration(hours: 1),
      );
      expect(await flow.check(), MacHelperState.notReady);
      expect(flow.rawDetail, contains('timeout'));
      flow.dispose();
    },
  );

  test('helper start failures are not banners', () {
    expect(isMacHelperStartFailure(const MacHelperException('x')), isTrue);
    expect(isMacHelperStartFailure(const MacRepairPendingException()), isTrue);
    expect(
      isMacHelperStartFailure(
        const DesktopCoreFailure(
          code: 'maintenance',
          phase: DesktopCorePhase.idle,
          revision: 1,
        ),
      ),
      isTrue,
    );
    expect(
      isMacHelperStartFailure(
        const DesktopCoreFailure(
          code: 'start_failed',
          phase: DesktopCorePhase.starting,
          revision: 1,
          cause: MacHelperException('starting'),
        ),
      ),
      isTrue,
    );
    expect(isMacHelperStartFailure(StateError('config')), isFalse);
    expect(
      isMacHelperStartFailure(
        const DesktopCoreFailure(
          code: 'start_failed',
          phase: DesktopCorePhase.failed,
          revision: 1,
        ),
      ),
      isFalse,
    );
  });
}
