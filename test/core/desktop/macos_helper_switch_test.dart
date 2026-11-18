// After an in-app update the previous build's helper may still run
// (`staleHelper`). The bridge asks it to exit (`retiring`) and the app shows a
// bounded "switching" wait instead of the "taking longer" card; nothing ever
// re-registers the daemon for it.

import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// The bridge with a helper of the previous build still running. `status`
/// behaves like ManagedHelperBridge.m: a reply refused for its cdhash sends
/// one `exit` (at most [maxExits]) and answers `staleHelper` with `retiring`;
/// once the old helper left, launchd starts the bundled one and `status`
/// reads enabled.
final class _Bridge implements MacHelperNativeApi {
  final calls = <String>[];

  /// The old helper is still running.
  bool oldHelper = true;

  /// It owns a Core and refuses to exit (`sessionBusy`).
  bool oldHelperBusy = false;

  /// The bundled helper needs this many more status reads to answer
  /// (launcher copy and signature check): `timeout` meanwhile.
  int slowStarts = 0;
  int exits = 0;
  int maxExits = 3;

  /// Overrides every status answer when set.
  Map<Object?, Object?>? fixed;

  Map<Object?, Object?> _status() {
    if (fixed case final answer?) return answer;
    if (oldHelper) {
      final retiring = exits < maxExits;
      if (retiring) {
        exits++;
        calls.add('exit');
        if (!oldHelperBusy) oldHelper = false;
      }
      return {
        'code': 'staleHelper',
        'retiring': retiring,
        'detail':
            'helper reply rejected by the app\'s verification: '
            'failed:cdhash running=aa bundled=bb',
      };
    }
    if (slowStarts > 0) {
      slowStarts--;
      return const {'code': 'timeout', 'detail': 'helper reply: none'};
    }
    return const {
      'code': 'enabled',
      'protocol': 1,
      'pid': 0,
      'exitConfirmed': true,
    };
  }

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    return switch (method) {
      'status' || 'repair' => _status(),
      _ => throw StateError('Unexpected native call: $method'),
    };
  }
}

const _applied = CoreLifecycleResult(
  revision: 1,
  outcome: CoreLifecycleOutcome.applied,
);

MacHelperMaintenance _flow(
  _Bridge bridge, {
  Duration switchWindow = const Duration(milliseconds: 400),
  Duration switchPoll = const Duration(milliseconds: 20),
  Duration startTimeout = const Duration(milliseconds: 30),
  Duration stalePoll = const Duration(hours: 1),
}) => MacHelperMaintenance(
  MacHelperClient(native: bridge, safeMode: () => false),
  stop: () async => _applied,
  recover: () async => throw StateError('never re-registered'),
  startTimeout: startTimeout,
  startPoll: const Duration(milliseconds: 20),
  stalePoll: stalePoll,
  switchWindow: switchWindow,
  switchPoll: switchPoll,
);

Future<void> _wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

Future<void> _until(bool Function() done, {int limit = 2000}) async {
  for (var waited = 0; !done(); waited += 5) {
    if (waited > limit) fail('condition not reached within $limit ms');
    await _wait(5);
  }
}

void _neverRegisters(_Bridge bridge) {
  for (final method in ['recover', 'enable', 'disable', 'migrate']) {
    expect(bridge.calls, isNot(contains(method)));
  }
}

void main() {
  final l = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('the client reads `retiring` only with staleHelper', () async {
    final bridge = _Bridge()..fixed = {'code': 'staleHelper', 'retiring': true};
    final client = MacHelperClient(native: bridge, safeMode: () => false);
    expect(await client.status(), MacHelperState.staleHelper);
    expect(client.lastRetiring, isTrue);
    bridge.fixed = {'code': 'staleHelper', 'retiring': false};
    await client.status();
    expect(client.lastRetiring, isFalse);
    bridge.fixed = {'code': 'staleHelper'};
    await client.status();
    expect(client.lastRetiring, isFalse);
    bridge.fixed = {'code': 'timeout', 'retiring': true};
    await client.status();
    expect(client.lastRetiring, isFalse);
  });

  test('simulation: stale helper -> one exit -> next status ready -> Core '
      'starts by itself', () async {
    final bridge = _Bridge();
    final flow = _flow(bridge);
    var coreStarts = 0;
    flow.runOnceReady(() async => coreStarts++);
    expect(await flow.check(), MacHelperState.staleHelper);
    expect(flow.switchingHelper, isTrue);
    expect(flow.startSlow, isFalse);
    expect(bridge.exits, 1);
    expect(macHelperCardView(l, flow).kind, MacHelperCardKind.switchingHelper);
    await _until(() => flow.state == MacHelperState.enabled && !flow.busy);
    await _wait(10);
    expect(flow.switchingHelper, isFalse);
    expect(macHelperCardView(l, flow).kind, MacHelperCardKind.ready);
    expect(coreStarts, 1);
    expect(bridge.exits, 1);
    expect(bridge.calls, ['status', 'exit', 'status']);
    _neverRegisters(bridge);
    flow.dispose();
  });

  test('a slow start of the new helper stays a switch past the start-up '
      'wait, never "taking longer"', () async {
    final bridge = _Bridge()..slowStarts = 4;
    final flow = _flow(bridge);
    var coreStarts = 0;
    flow.runOnceReady(() async => coreStarts++);
    await flow.check();
    final kinds = <MacHelperCardKind>{};
    void watch() => kinds.add(macHelperCardView(l, flow).kind);
    flow.addListener(watch);
    await _until(() => flow.state == MacHelperState.enabled && !flow.busy);
    await _wait(10);
    expect(kinds, isNot(contains(MacHelperCardKind.startSlow)));
    expect(kinds, isNot(contains(MacHelperCardKind.starting)));
    expect(kinds, contains(MacHelperCardKind.switchingHelper));
    expect(coreStarts, 1);
    _neverRegisters(bridge);
    flow.dispose();
  });

  test('a switch that does not finish in its window falls back to the '
      '"taking longer" card with details', () async {
    // The old helper keeps answering, and the bridge keeps saying it asked.
    final bridge = _Bridge()
      ..fixed = {
        'code': 'staleHelper',
        'retiring': true,
        'detail': 'failed:cdhash running=aa bundled=bb',
      };
    final flow = _flow(bridge, switchWindow: const Duration(milliseconds: 150));
    await flow.check();
    expect(flow.switchingHelper, isTrue);
    await _wait(60);
    // The start-up wait (30 ms) is over, the switch is not.
    expect(flow.startSlow, isFalse);
    expect(macHelperCardView(l, flow).kind, MacHelperCardKind.switchingHelper);
    await _until(() => !flow.switchingHelper);
    await _until(() => !flow.busy);
    expect(flow.startSlow, isTrue);
    final card = macHelperCardView(l, flow);
    expect(card.kind, MacHelperCardKind.startSlow);
    expect(card.title, l.macHelperStartSlowTitle);
    expect(card.secondary, MacHelperCardAction.viewDetails);
    expect(card.rawDetail, contains('cdhash running=aa'));
    // Polling falls back to the slow stale poll: no more checks here.
    final polls = bridge.calls.length;
    await _wait(80);
    expect(bridge.calls.length, polls);
    // Not started again by itself.
    await flow.check();
    expect(flow.switchingHelper, isFalse);
    _neverRegisters(bridge);
    flow.dispose();
  });

  test('used-up exit requests end the switch at once', () async {
    final bridge = _Bridge()
      ..oldHelperBusy = true
      ..maxExits = 3;
    final flow = _flow(bridge, switchWindow: const Duration(seconds: 30));
    await flow.check();
    expect(flow.switchingHelper, isTrue);
    await _until(() => !flow.switchingHelper);
    await _until(() => !flow.busy);
    expect(bridge.exits, 3);
    expect(flow.state, MacHelperState.staleHelper);
    expect(flow.startSlow, isTrue);
    expect(macHelperCardView(l, flow).kind, MacHelperCardKind.startSlow);
    _neverRegisters(bridge);
    flow.dispose();
  });

  test('a stale helper the bridge did not ask to exit is no switch', () async {
    final bridge = _Bridge()..fixed = {'code': 'staleHelper'};
    final flow = _flow(bridge);
    await flow.check();
    expect(flow.switchingHelper, isFalse);
    expect(macHelperCardView(l, flow).kind, MacHelperCardKind.starting);
    await _wait(60);
    expect(flow.startSlow, isTrue);
    expect(macHelperCardView(l, flow).kind, MacHelperCardKind.startSlow);
    flow.dispose();
  });

  test('a real problem during a switch is shown as itself', () async {
    final bridge = _Bridge()..fixed = {'code': 'staleHelper', 'retiring': true};
    final flow = _flow(bridge, switchPoll: const Duration(hours: 1));
    await flow.check();
    expect(flow.switchingHelper, isTrue);
    bridge.fixed = {'code': 'launcherDowngrade', 'detail': 'launcher: older'};
    await flow.check();
    expect(flow.switchingHelper, isFalse);
    expect(
      macHelperCardView(l, flow).kind,
      MacHelperCardKind.launcherDowngrade,
    );
    flow.dispose();
  });

  test('"Check again" and "Try again" ask the stale helper to exit '
      '(native repair), never re-register', () async {
    final bridge = _Bridge()..fixed = {'code': 'staleHelper'};
    final flow = _flow(bridge, switchPoll: const Duration(hours: 1));
    await flow.check();
    bridge.fixed = {'code': 'staleHelper', 'retiring': true};
    expect(await flow.recheck(), MacHelperState.staleHelper);
    expect(bridge.calls.last, 'repair');
    expect(flow.switchingHelper, isTrue);
    bridge.fixed = null;
    bridge.oldHelper = false;
    // The old helper left: "Try again" reads ready, with nothing but status.
    expect(await flow.retryRecovery(), MacHelperState.enabled);
    expect(flow.switchingHelper, isFalse);
    expect(bridge.calls.toSet(), {'status', 'repair'});
    _neverRegisters(bridge);
    flow.dispose();
  });

  test('retryRecovery for staleHelper calls repair, not recover', () async {
    final bridge = _Bridge()..fixed = {'code': 'staleHelper'};
    final flow = _flow(bridge, switchPoll: const Duration(hours: 1));
    await flow.check();
    await flow.retryRecovery();
    expect(bridge.calls, ['status', 'status', 'repair']);
    flow.dispose();
  });

  test('a repair refused for a running session reads the status', () async {
    final calls = <String>[];
    final native = _Script((method) {
      calls.add(method);
      return method == 'repair'
          ? const {'code': 'sessionBusy'}
          : const {'code': 'staleHelper'};
    });
    final flow = MacHelperMaintenance(
      MacHelperClient(native: native, safeMode: () => false),
      stop: () async => _applied,
      startTimeout: const Duration(hours: 1),
      stalePoll: const Duration(hours: 1),
    );
    await flow.check();
    expect(await flow.recheck(), MacHelperState.staleHelper);
    expect(calls, ['status', 'repair', 'status']);
    flow.dispose();
  });

  group('the switching card', () {
    test('kind, copy and bar', () async {
      expect(
        macHelperCardKind(MacHelperState.staleHelper, false, switching: true),
        MacHelperCardKind.switchingHelper,
      );
      expect(
        macHelperCardKind(MacHelperState.starting, true, switching: true),
        MacHelperCardKind.switchingHelper,
      );
      expect(
        macHelperCardKind(MacHelperState.enabled, false, switching: true),
        MacHelperCardKind.ready,
      );
      expect(
        macHelperCardKind(MacHelperState.repairing, false, switching: true),
        MacHelperCardKind.starting,
      );
      expect(l.macHelperSwitchingTitle, '正在切换到新版辅助程序…');
      expect(en.macHelperSwitchingTitle, 'Switching to the new helper…');
      final bridge = _Bridge()
        ..fixed = {'code': 'staleHelper', 'retiring': true};
      final flow = _flow(bridge, switchPoll: const Duration(hours: 1));
      await flow.check();
      final card = macHelperCardView(l, flow);
      expect(card.title, l.macHelperSwitchingTitle);
      expect(card.isProblem, isFalse);
      expect(card.primary, isNull);
      expect(card.secondary, isNull);
      final bar = macHelperBarView(l, flow)!;
      expect(bar.kind, MacHelperBarKind.starting);
      expect(bar.tone, MacHelperBarTone.waiting);
      expect(bar.title, l.macHelperSwitchingTitle);
      flow.dispose();
    });

    testWidgets('shows a calm wait, then the ready card', (tester) async {
      final bridge = _Bridge();
      late MacHelperMaintenance flow;
      await tester.runAsync(() async {
        flow = _flow(bridge, switchPoll: const Duration(hours: 1));
        await flow.check();
      });
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('zh', 'CN'),
          child: MacHelperCard(maintenance: flow),
        ),
      );
      await tester.pump();
      expect(find.text(l.macHelperSwitchingTitle), findsOneWidget);
      expect(find.text(l.macHelperStartSlowTitle), findsNothing);
      expect(find.text(l.macHelperViewDetails), findsNothing);
      await tester.runAsync(() => flow.check());
      await tester.pump();
      expect(find.text(l.macHelperSwitchingTitle), findsNothing);
      expect(find.text(l.macHelperOn), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      flow.dispose();
    });
  });
}

final class _Script implements MacHelperNativeApi {
  final Map<Object?, Object?> Function(String) answer;
  _Script(this.answer);

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async => answer(method);
}
