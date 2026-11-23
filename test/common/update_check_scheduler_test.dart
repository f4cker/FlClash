import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _FakeTimer implements Timer {
  _FakeTimer(this.interval, this.onTick);

  final Duration interval;
  final void Function(Timer timer) onTick;
  bool cancelled = false;
  int ticks = 0;

  void fire() {
    if (cancelled) return;
    ticks++;
    onTick(this);
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
  final created = <_FakeTimer>[];

  Timer create(Duration interval, void Function(Timer timer) onTick) {
    final timer = _FakeTimer(interval, onTick);
    created.add(timer);
    return timer;
  }

  _FakeTimer get single => created.single;
}

class _CountingAction extends CommonAction {
  int checks = 0;

  @override
  Future<UpdateCheck> checkForAppUpdate() async {
    checks++;
    return const UpdateUpToDate();
  }
}

void main() {
  group('UpdateCheckScheduler', () {
    late _Clock clock;
    late _Timers timers;
    late bool enabled;
    late int checks;
    late UpdateCheckScheduler scheduler;

    UpdateCheckScheduler build({Future<void> Function()? check}) {
      final scheduler = UpdateCheckScheduler(
        check: check ?? () async => checks++,
        enabled: () => enabled,
        now: clock.now,
        periodicTimer: timers.create,
      );
      addTearDown(scheduler.dispose);
      return scheduler;
    }

    setUp(() {
      clock = _Clock();
      timers = _Timers();
      enabled = true;
      checks = 0;
      scheduler = build();
    });

    test('checks at start and creates one six-hour timer once', () async {
      scheduler
        ..start()
        ..start();
      await pumpEventQueue();
      expect(checks, 1);
      expect(timers.created, hasLength(1));
      expect(timers.single.interval, const Duration(hours: 6));
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

    test(
      'wake requests within thirty minutes of a check are skipped',
      () async {
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
      },
    );

    test('a request before start does nothing', () async {
      scheduler.requestCheck('network');
      await pumpEventQueue();
      expect(checks, 0);
      expect(timers.created, isEmpty);
    });

    test('a check in flight absorbs further requests', () async {
      final hold = Completer<void>();
      scheduler = build(
        check: () async {
          checks++;
          await hold.future;
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

    test('a failing check stays silent and later checks still run', () async {
      scheduler = build(
        check: () async {
          checks++;
          throw StateError('offline');
        },
      )..start();
      await pumpEventQueue();
      clock.advance(const Duration(hours: 6));
      timers.single.fire();
      await pumpEventQueue();
      expect(checks, 2);
    });

    test('dispose cancels the timer and stops checks', () async {
      scheduler.start();
      await pumpEventQueue();
      scheduler.dispose();
      expect(timers.single.cancelled, isTrue);
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

    void setAutoCheck(bool value) => container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(autoCheckUpdate: value));

    test('checks at launch, on the timer and after a wake', () async {
      action.startUpdateChecks(now: clock.now, periodicTimer: timers.create);
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

    test('turning the setting off stops checks, on resumes them', () async {
      setAutoCheck(false);
      action.startUpdateChecks(now: clock.now, periodicTimer: timers.create);
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
      expect(timers.created, hasLength(1));
    });

    test('disposing the container cancels the timer', () async {
      action.startUpdateChecks(now: clock.now, periodicTimer: timers.create);
      await pumpEventQueue();
      container.dispose();
      expect(timers.single.cancelled, isTrue);
    });
  });
}
