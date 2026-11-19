import 'dart:async';
import 'dart:typed_data';

import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = '0123456789abcdef0123456789abcdef';
const _next = '1123456789abcdef0123456789abcdef';

// The client's back-off cap, and the time the Core gives a MITM sign
// request that goes through the relay (mitmConnectionLeafWait).
const _idlePauseMax = Duration(milliseconds: 250);
const _coreLeafSignWait = Duration(milliseconds: 500);

/// A daemon that holds an empty `receive` for its `wait` (as Supervisor.m),
/// or with [waits] false one from before `wait` that answers at once.
final class _WaitingNative implements MacHelperNativeApi {
  bool waits;
  final clock = Stopwatch()..start();
  final receives = <Map<String, Object?>>[];
  final receivedAt = <Duration>[];
  final _queued = <Uint8List>[];
  int _base = 0;
  Completer<Map<Object?, Object?>>? _held;
  Timer? _heldTimer;

  /// When set, every relay request is answered with it (a restarted daemon
  /// that does not know the session).
  String? relayCode;

  /// Whether `stop` answers a held receive (a daemon that is gone does not).
  bool answersOnStop = true;

  _WaitingNative({this.waits = true});

  bool get holding => _held != null;

  Map<Object?, Object?> _batch() => {
    'code': 'ok',
    'seq': _base,
    'frames': List<Object>.of(_queued),
  };

  void _release(Map<Object?, Object?> answer) {
    _heldTimer?.cancel();
    _heldTimer = null;
    final held = _held;
    _held = null;
    held?.complete(answer);
  }

  void push(List<int> frame) {
    _queued.add(Uint8List.fromList(frame));
    if (_held != null) _release(_batch());
  }

  void drop(String code) => _release({'code': code});

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    switch (method) {
      case 'status':
        return {'code': 'enabled'};
      case 'start':
        relayCode = null;
        _queued.clear();
        _base = 0;
        return {'code': 'ok', 'protocol': 1, 'pid': 42};
      case 'stop':
        if (answersOnStop) _release({'code': 'disconnected'});
        return {'code': 'ok', 'pid': 0, 'exitConfirmed': true};
      case 'send':
        return relayCode != null ? {'code': relayCode} : {'code': 'ok'};
      case 'receive':
        receives.add(arguments);
        receivedAt.add(clock.elapsed);
        if (relayCode case final code?) return {'code': code};
        final ack = arguments['ack']! as int;
        _queued.removeRange(0, ack - _base);
        _base = ack;
        final wait = arguments['wait'];
        if (_queued.isNotEmpty || !waits || wait is! int || wait <= 0) {
          return _batch();
        }
        final held = _held = Completer();
        _heldTimer = Timer(Duration(milliseconds: wait), () {
          if (identical(_held, held)) _release(_batch());
        });
        return held.future;
      default:
        return {'code': 'ok'};
    }
  }
}

/// Runs [body] where every timer the client (and the fake) creates is kept
/// in [timers], to show that none is left running.
Future<T> _tracked<T>(List<Timer> timers, Future<T> Function() body) =>
    runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createTimer(zone, duration, callback);
          timers.add(timer);
          return timer;
        },
      ),
    );

Future<void> _wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

Future<void> _until(bool Function() condition) async {
  final elapsed = Stopwatch()..start();
  while (!condition()) {
    if (elapsed.elapsed > const Duration(seconds: 2)) {
      fail('Relay did not progress within two seconds');
    }
    await _wait(1);
  }
}

MacHelperClient _client(
  _WaitingNative native, {
  Duration relayWait = const Duration(seconds: 3),
}) => MacHelperClient(
  native: native,
  safeMode: () => false,
  relayRetryDelay: Duration.zero,
  relayWait: relayWait,
);

void main() {
  test('an idle relay waits in the daemon instead of polling', () async {
    final native = _WaitingNative();
    final client = _client(
      native,
      relayWait: const Duration(milliseconds: 300),
    );
    await client.start(_session);
    await _wait(1500);
    // About one receive per wait (was one per 16 ms: ~78 in 1.5 s).
    expect(native.receives.length, inInclusiveRange(4, 7));
    expect(native.receives.map((call) => call['wait']), everyElement(300));
    expect(await client.stop(_session), isTrue);
  });

  test('the pause for a daemon from before `wait` stops at 250 ms', () async {
    final native = _WaitingNative(waits: false);
    final client = _client(native);
    final pauses = <Timer>[];
    final durations = <Duration>[];
    // Only the relay loop runs in this zone: the waits below stay outside.
    await runZoned(
      () => client.start(_session),
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          if (duration > Duration.zero) durations.add(duration);
          final timer = parent.createTimer(zone, duration, callback);
          pauses.add(timer);
          return timer;
        },
      ),
    );
    await _wait(2500);
    expect(await client.stop(_session), isTrue);
    expect(durations.length, greaterThanOrEqualTo(8));
    expect(durations, everyElement(lessThanOrEqualTo(_idlePauseMax)));
    expect(durations.last, greaterThan(const Duration(milliseconds: 200)));
    expect(_idlePauseMax, lessThan(_coreLeafSignWait));
    expect(pauses.where((timer) => timer.isActive), isEmpty);
  });

  test('a daemon from before `wait` is polled with a growing pause', () async {
    final native = _WaitingNative(waits: false);
    final client = _client(native);
    await client.start(_session);
    await _wait(1500);
    // 16, 32, ... 250 ms between empty answers instead of 16 ms each.
    expect(native.receives.length, inInclusiveRange(6, 14));
    final gaps = [
      for (var i = 1; i < native.receivedAt.length; i++)
        native.receivedAt[i] - native.receivedAt[i - 1],
    ];
    expect(gaps.first, lessThan(const Duration(milliseconds: 100)));
    expect(gaps.last, greaterThanOrEqualTo(const Duration(milliseconds: 225)));
    expect(gaps, everyElement(lessThan(_coreLeafSignWait)));
    final frames = <Uint8List>[];
    final subscription = client.events.listen((event) {
      if (event is MacHelperFrame) frames.add(event.data);
    });
    native.push([1]);
    native.push([2]);
    await _until(() => frames.length == 2);
    await _until(() => native.receives.last['ack'] == 2);
    expect(frames, [
      [1],
      [2],
    ]);
    // A frame ends the back-off: the next empty answer is asked again soon.
    final count = native.receives.length;
    await _until(() => native.receives.length > count);
    expect(
      native.receivedAt.last - native.receivedAt[count - 1],
      lessThan(const Duration(milliseconds: 100)),
    );
    await subscription.cancel();
    expect(await client.stop(_session), isTrue);
  });

  test('a frame arriving during a wait is delivered at once', () async {
    final native = _WaitingNative();
    final client = _client(native);
    final arrived = Completer<Uint8List>();
    final subscription = client.events.listen((event) {
      if (event is MacHelperFrame && !arrived.isCompleted) {
        arrived.complete(event.data);
      }
    });
    await client.start(_session);
    await _until(() => native.holding);
    await _wait(50);
    final latency = Stopwatch()..start();
    native.push([7, 7]);
    expect(await arrived.future, [7, 7]);
    expect(latency.elapsed, lessThan(const Duration(milliseconds: 100)));
    await _until(() => native.holding);
    expect(native.receives.last['ack'], 1);
    expect(native.receives, hasLength(2));
    await subscription.cancel();
    expect(await client.stop(_session), isTrue);
  });

  test('a send ends the old daemon back-off at once', () async {
    final native = _WaitingNative(waits: false);
    final client = _client(native);
    await client.start(_session);
    await _wait(1200);
    final count = native.receives.length;
    final latency = Stopwatch()..start();
    client.send([1]);
    await _until(() => native.receives.length > count);
    expect(latency.elapsed, lessThan(const Duration(milliseconds: 100)));
    expect(await client.stop(_session), isTrue);
  });

  test('an expired wait is asked again without a pause', () async {
    final native = _WaitingNative();
    final client = _client(
      native,
      relayWait: const Duration(milliseconds: 100),
    );
    await client.start(_session);
    await _until(() => native.receives.length >= 5);
    for (var i = 1; i < native.receivedAt.length; i++) {
      final gap = native.receivedAt[i] - native.receivedAt[i - 1];
      expect(gap, greaterThanOrEqualTo(const Duration(milliseconds: 95)));
      expect(gap, lessThan(const Duration(milliseconds: 300)));
    }
    expect(native.receives.map((call) => call['ack']), everyElement(0));
    native.push([3]);
    await _until(() => native.receives.last['ack'] == 1);
    expect(client.relayLive, isTrue);
    expect(await client.stop(_session), isTrue);
  });

  for (final answersOnStop in [true, false]) {
    test('stop during a wait returns promptly and leaves no timer '
        '(daemon answers the held receive: $answersOnStop)', () async {
      final timers = <Timer>[];
      final native = _WaitingNative()..answersOnStop = answersOnStop;
      final events = <MacHelperEvent>[];
      await _tracked(timers, () async {
        final client = _client(native);
        final subscription = client.events.listen(events.add);
        await client.start(_session);
        await _until(() => native.holding);
        final elapsed = Stopwatch()..start();
        expect(await client.stop(_session), isTrue);
        expect(elapsed.elapsed, lessThan(const Duration(milliseconds: 200)));
        expect(client.relayLive, isFalse);
        expect(client.hasCoreSession, isFalse);
        // A reply that comes after all is ignored and asks nothing again.
        native.drop('disconnected');
        await _wait(100);
        expect(native.receives, hasLength(1));
        await subscription.cancel();
      });
      expect(events.whereType<MacHelperFrame>(), isEmpty);
      expect(timers.where((timer) => timer.isActive), isEmpty);
    });
  }

  test('stop during an old daemon back-off cancels the pause timer', () async {
    final timers = <Timer>[];
    final native = _WaitingNative(waits: false);
    await _tracked(timers, () async {
      final client = _client(native);
      await client.start(_session);
      await _wait(1200);
      final count = native.receives.length;
      expect(await client.stop(_session), isTrue);
      // The pause (up to 250 ms) ends with the stop, not by running out.
      expect(timers.where((timer) => timer.isActive), isEmpty);
      await _wait(600);
      expect(native.receives, hasLength(count));
    });
    expect(timers.where((timer) => timer.isActive), isEmpty);
  });

  test('a connection dropped mid-wait is resumed with the same ack', () async {
    final native = _WaitingNative();
    final client = _client(native);
    final events = <MacHelperEvent>[];
    final subscription = client.events.listen(events.add);
    await client.start(_session);
    native.push([1]);
    await _until(() => native.holding && native.receives.last['ack'] == 1);
    native.drop('unavailable');
    await _until(() => native.holding && native.receives.length == 3);
    expect(native.receives.last['ack'], 1);
    expect(native.receives.last['wait'], 3000);
    native.push([2]);
    await _until(() => events.whereType<MacHelperFrame>().length == 2);
    expect(events.whereType<MacHelperDisconnected>(), isEmpty);
    expect(client.relayLive, isTrue);
    await subscription.cancel();
    expect(await client.stop(_session), isTrue);
  });

  test('a restarted daemon ends the relay; the next session waits again, '
      'also after a swap from a daemon from before `wait`', () async {
    final native = _WaitingNative(waits: false);
    final client = _client(native);
    final events = <MacHelperEvent>[];
    final subscription = client.events.listen(events.add);
    await client.start(_session);
    await _wait(100);
    // A restarted (swapped) daemon no longer knows the session.
    native.relayCode = 'wrongOwner';
    native.waits = true;
    await _until(() => events.whereType<MacHelperDisconnected>().isNotEmpty);
    expect(client.relayLive, isFalse);
    expect(await client.stop(_session), isTrue);
    final before = native.receives.length;
    await client.start(_next);
    await _until(() => native.holding);
    await _wait(300);
    expect(native.receives.length - before, 1);
    expect(native.receives.last['wait'], 3000);
    native.push([9]);
    await _until(() => events.whereType<MacHelperFrame>().isNotEmpty);
    expect(events.whereType<MacHelperConnected>(), hasLength(2));
    await subscription.cancel();
    expect(await client.stop(_next), isTrue);
  });
}
