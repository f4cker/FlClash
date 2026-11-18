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

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    return switch (method) {
      'status' || 'approvalStatus' => status,
      'enable' => const {'code': 'requiresApproval'},
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
