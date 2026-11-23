import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.onFire);

  final Duration duration;
  final void Function() onFire;
  bool cancelled = false;
  int ticks = 0;

  void fire() {
    if (cancelled) return;
    ticks++;
    onFire();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => ticks;
}

class _Clock {
  DateTime value = DateTime(2026, 11, 22, 9);

  DateTime now() => value;

  void advance(Duration duration) => value = value.add(duration);
}

class _Timers {
  final periodic = <_FakeTimer>[];
  final oneShot = <_FakeTimer>[];

  Timer createPeriodic(Duration interval, void Function(Timer timer) onTick) {
    late final _FakeTimer timer;
    timer = _FakeTimer(interval, () => onTick(timer));
    periodic.add(timer);
    return timer;
  }

  Timer createOneShot(Duration delay, void Function() callback) {
    final timer = _FakeTimer(delay, () {
      callback();
    });
    oneShot.add(timer);
    return timer;
  }

  _FakeTimer get single => periodic.single;

  Iterable<_FakeTimer> get pendingOneShots =>
      oneShot.where((timer) => !timer.cancelled && timer.ticks == 0);
}

class _CountingAction extends CommonAction {
  int checks = 0;
  UpdateCheck answer = const UpdateUpToDate();

  @override
  Future<UpdateCheck> checkForAppUpdate({bool automatic = false}) async {
    checks++;
    return answer;
  }
}

void main() {
  group('UpdateCheckScheduler', () {
    late _Clock clock;
    late _Timers timers;
    late bool enabled;
    late int checks;
    late BackgroundCheckOutcome outcome;
    late UpdateCheckScheduler scheduler;

    UpdateCheckScheduler build({
      Future<BackgroundCheckOutcome> Function()? check,
    }) {
      final scheduler = UpdateCheckScheduler(
        check:
            check ??
            () async {
              checks++;
              return outcome;
            },
        enabled: () => enabled,
        now: clock.now,
        periodicTimer: timers.createPeriodic,
        oneShotTimer: timers.createOneShot,
      );
      addTearDown(scheduler.dispose);
      return scheduler;
    }

    setUp(() {
      clock = _Clock();
      timers = _Timers();
      enabled = true;
      checks = 0;
      outcome = BackgroundCheckOutcome.completed;
      scheduler = build();
    });

    test('checks at start and creates one six-hour timer once', () async {
      scheduler
        ..start()
        ..start();
      await pumpEventQueue();
      expect(checks, 1);
      expect(timers.periodic, hasLength(1));
      expect(timers.single.duration, const Duration(hours: 6));
    });

    test('a restart without checkNow only arms the timer', () async {
      scheduler.start(checkNow: false);
      await pumpEventQueue();
      expect(checks, 0);
      timers.single.fire();
      await pumpEventQueue();
      expect(checks, 1);
    });

    test('the timer firing checks again', () async {
      scheduler.start();
      await pumpEventQueue();
      for (var round = 2; round <= 4; round++) {
        clock.advance(const Duration(hours: 6));
        timers.single.fire();
        await pumpEventQueue();
        expect(checks, round);
      }
    });

    test('with the setting off neither start nor the timer checks', () async {
      enabled = false;
      scheduler.start();
      await pumpEventQueue();
      clock.advance(const Duration(hours: 6));
      timers.single.fire();
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 0);
      enabled = true;
      clock.advance(const Duration(hours: 6));
      timers.single.fire();
      await pumpEventQueue();
      expect(checks, 1);
    });

    test('requests within thirty minutes of a success are skipped', () async {
      scheduler.start();
      await pumpEventQueue();
      clock.advance(const Duration(minutes: 29));
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 1);
      clock.advance(const Duration(minutes: 1));
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 2);
      clock.advance(const Duration(minutes: 10));
      timers.single.fire();
      await pumpEventQueue();
      expect(checks, 2, reason: 'the timer is throttled too');
    });

    test('a failure backs off for minutes, not the full gap', () async {
      outcome = BackgroundCheckOutcome.failed;
      scheduler.start();
      await pumpEventQueue();
      clock.advance(const Duration(minutes: 2));
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 1);
      outcome = BackgroundCheckOutcome.completed;
      clock.advance(const Duration(minutes: 1));
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 2, reason: 'a request after the back-off goes through');
      clock.advance(const Duration(minutes: 5));
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 2, reason: 'the success starts the thirty minutes');
    });

    test('a thrown check counts as a failure', () async {
      scheduler = build(
        check: () async {
          checks++;
          throw StateError('offline');
        },
      )..start();
      await pumpEventQueue();
      clock.advance(const Duration(minutes: 3));
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 2);
    });

    test('a skipped check does not start the gap', () async {
      outcome = BackgroundCheckOutcome.skipped;
      scheduler.start();
      await pumpEventQueue();
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 2);
    });

    test('delayed requests collapse into one check after the delay', () async {
      scheduler.start(checkNow: false);
      for (var i = 0; i < 3; i++) {
        scheduler.requestCheck('network', delay: const Duration(seconds: 8));
      }
      await pumpEventQueue();
      expect(checks, 0);
      final pending = timers.pendingOneShots.toList();
      expect(pending, hasLength(1));
      expect(pending.single.duration, const Duration(seconds: 8));
      pending.single.fire();
      await pumpEventQueue();
      expect(checks, 1);
    });

    test('a storm of requests never pushes the pending check back', () async {
      scheduler.start(checkNow: false);
      scheduler.requestCheck('network', delay: const Duration(seconds: 8));
      final first = timers.oneShot.single;
      for (var i = 0; i < 50; i++) {
        clock.advance(const Duration(seconds: 1));
        scheduler.requestCheck('network', delay: const Duration(seconds: 8));
      }
      expect(timers.oneShot, [same(first)]);
      expect(first.cancelled, isFalse);
      first.fire();
      await pumpEventQueue();
      expect(checks, 1);
      clock.advance(const Duration(hours: 1));
      scheduler.requestCheck('network', delay: const Duration(seconds: 8));
      expect(timers.pendingOneShots, hasLength(1));
      expect(timers.oneShot, hasLength(2));
    });

    test('stop keeps the history and start arms the timer again', () async {
      scheduler.start();
      await pumpEventQueue();
      scheduler.stop();
      expect(timers.single.cancelled, isTrue);
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 1);
      scheduler.start(checkNow: false);
      expect(timers.periodic, hasLength(2));
      clock.advance(const Duration(minutes: 10));
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 1, reason: 'the success before stop still counts');
      clock.advance(const Duration(minutes: 20));
      timers.periodic.last.fire();
      await pumpEventQueue();
      expect(checks, 2);
    });

    test('a request before start does nothing', () async {
      scheduler.requestCheck('network');
      scheduler.requestCheck('network', delay: const Duration(seconds: 8));
      await pumpEventQueue();
      expect(checks, 0);
      expect(timers.periodic, isEmpty);
      expect(timers.oneShot, isEmpty);
    });

    test('a check in flight absorbs further requests', () async {
      final hold = Completer<void>();
      scheduler = build(
        check: () async {
          checks++;
          await hold.future;
          return BackgroundCheckOutcome.completed;
        },
      )..start();
      await pumpEventQueue();
      clock.advance(const Duration(hours: 7));
      timers.single.fire();
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 1);
      hold.complete();
      await pumpEventQueue();
      timers.single.fire();
      await pumpEventQueue();
      expect(checks, 2);
    });

    test('dispose cancels the timers and stops checks', () async {
      scheduler.start();
      await pumpEventQueue();
      scheduler.requestCheck('network', delay: const Duration(seconds: 8));
      scheduler.dispose();
      expect(timers.single.cancelled, isTrue);
      expect(timers.oneShot.single.cancelled, isTrue);
      clock.advance(const Duration(hours: 6));
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 1);
    });
  });

  group('CommonAction.startUpdateChecks', () {
    late _Clock clock;
    late _Timers timers;
    late _CountingAction action;
    late ProviderContainer container;

    setUp(() {
      clock = _Clock();
      timers = _Timers();
      action = _CountingAction();
      container = ProviderContainer(
        overrides: [
          commonActionProvider.overrideWith(() => action),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(_Core())),
        ],
      );
      globalState.container = container;
      addTearDown(container.dispose);
      container.read(commonActionProvider.notifier);
    });

    void start() => action.startUpdateChecks(
      now: clock.now,
      periodicTimer: timers.createPeriodic,
      oneShotTimer: timers.createOneShot,
    );

    void setAutoCheck(bool value) => container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(autoCheckUpdate: value));

    test('checks at launch, on the timer and after a wake', () async {
      start();
      await pumpEventQueue();
      expect(action.checks, 1);
      clock.advance(const Duration(hours: 6));
      timers.single.fire();
      await pumpEventQueue();
      expect(action.checks, 2);
      clock.advance(const Duration(minutes: 5));
      action.requestUpdateCheck('network');
      await pumpEventQueue();
      expect(action.checks, 2);
      clock.advance(const Duration(minutes: 30));
      action.requestUpdateCheck('network');
      await pumpEventQueue();
      expect(action.checks, 3);
    });

    test('a failed check lets the next network change through', () async {
      action.answer = UpdateCheckFailed(StateError('offline'));
      start();
      await pumpEventQueue();
      expect(action.checks, 1);
      action.answer = const UpdateUpToDate();
      clock.advance(const Duration(minutes: 4));
      action.requestUpdateCheck('network', delay: const Duration(seconds: 8));
      timers.pendingOneShots.single.fire();
      await pumpEventQueue();
      expect(action.checks, 2);
    });

    test('turning the setting off stops checks, on resumes them', () async {
      setAutoCheck(false);
      start();
      await pumpEventQueue();
      clock.advance(const Duration(hours: 6));
      timers.single.fire();
      await pumpEventQueue();
      expect(action.checks, 0);
      setAutoCheck(true);
      await pumpEventQueue();
      expect(action.checks, 1, reason: 'turning it on checks right away');
      clock.advance(const Duration(hours: 6));
      timers.single.fire();
      await pumpEventQueue();
      expect(action.checks, 2);
      expect(timers.periodic, hasLength(1));
    });

    test('pending user or tray work holds automatic checks back', () async {
      container.listen(loadingProvider(LoadingTag.checkUpdate), (_, _) {});
      container.listen(updateInstallBusyProvider, (_, _) {});
      container.read(loadingProvider(LoadingTag.checkUpdate).notifier).value =
          true;
      expect(await action.autoCheckUpdate(), BackgroundCheckOutcome.skipped);
      container.read(loadingProvider(LoadingTag.checkUpdate).notifier).value =
          false;
      container.read(updateInstallBusyProvider.notifier).value = true;
      expect(await action.autoCheckUpdate(), BackgroundCheckOutcome.skipped);
      container.read(updateInstallBusyProvider.notifier).value = false;
      expect(action.checks, 0);
      expect(await action.autoCheckUpdate(), BackgroundCheckOutcome.completed);
      expect(action.checks, 1);
    });

    test('a rebuild keeps the timer running without an extra check', () async {
      start();
      await pumpEventQueue();
      container.invalidate(commonActionProvider);
      container.read(commonActionProvider.notifier);
      expect(timers.periodic.first.cancelled, isTrue);
      expect(timers.periodic, hasLength(2));
      await pumpEventQueue();
      expect(action.checks, 1);
      clock.advance(const Duration(minutes: 10));
      action.requestUpdateCheck('network');
      await pumpEventQueue();
      expect(action.checks, 1, reason: 'the throttle survives the rebuild');
      clock.advance(const Duration(hours: 6));
      timers.periodic.last.fire();
      await pumpEventQueue();
      expect(action.checks, 2);
    });

    test('disposing the container cancels the timer', () async {
      start();
      await pumpEventQueue();
      container.dispose();
      expect(timers.single.cancelled, isTrue);
    });
  });
}
