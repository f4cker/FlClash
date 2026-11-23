import 'dart:async';

import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/enum/enum.dart';

typedef PeriodicTimerFactory =
    Timer Function(Duration interval, void Function(Timer timer) onTick);

typedef OneShotTimerFactory =
    Timer Function(Duration delay, void Function() callback);

enum BackgroundCheckOutcome { skipped, failed, completed }

class UpdateCheckScheduler {
  UpdateCheckScheduler({
    required Future<BackgroundCheckOutcome> Function() check,
    required bool Function() enabled,
    DateTime Function()? now,
    PeriodicTimerFactory? periodicTimer,
    OneShotTimerFactory? oneShotTimer,
    this.interval = const Duration(hours: 6),
    this.minGap = const Duration(minutes: 30),
    this.failureBackoff = const Duration(minutes: 3),
  }) : _check = check,
       _enabled = enabled,
       _now = now ?? DateTime.now,
       _periodicTimer = periodicTimer ?? Timer.periodic,
       _oneShotTimer = oneShotTimer ?? Timer.new;

  final Future<BackgroundCheckOutcome> Function() _check;
  final bool Function() _enabled;
  final DateTime Function() _now;
  final PeriodicTimerFactory _periodicTimer;
  final OneShotTimerFactory _oneShotTimer;
  final Duration interval;
  final Duration minGap;
  final Duration failureBackoff;

  Timer? _timer;
  Timer? _delayed;
  DateTime? _lastSuccess;
  DateTime? _lastFailure;
  bool _checking = false;
  bool _disposed = false;

  bool get started => _timer != null;

  void start({bool checkNow = true}) {
    if (_disposed || _timer != null) return;
    _timer = _periodicTimer(interval, (_) => unawaited(_run('periodic')));
    if (checkNow) unawaited(_run('launch'));
  }

  /// Delayed requests join one already pending instead of pushing it back,
  /// so a stream of them still checks [delay] after the first.
  void requestCheck(String reason, {Duration delay = Duration.zero}) {
    if (_disposed || _timer == null) return;
    if (delay <= Duration.zero) {
      unawaited(_run(reason));
      return;
    }
    if (_delayed != null) return;
    _delayed = _oneShotTimer(delay, () {
      _delayed = null;
      unawaited(_run(reason));
    });
  }

  static bool _within(DateTime now, DateTime? since, Duration gap) {
    if (since == null) return false;
    final elapsed = now.difference(since);
    return !elapsed.isNegative && elapsed < gap;
  }

  Future<void> _run(String reason) async {
    if (_disposed || _checking || !_enabled()) return;
    // A Timer runs on the monotonic clock, which stops while the Mac sleeps;
    // the gaps are measured on the wall clock, which does not.
    final started = _now();
    if (_within(started, _lastSuccess, minGap) ||
        _within(started, _lastFailure, failureBackoff)) {
      return;
    }
    _checking = true;
    var outcome = BackgroundCheckOutcome.failed;
    try {
      outcome = await _check();
    } catch (error) {
      commonPrint.log(
        'Background update check ($reason) failed: $error',
        logLevel: LogLevel.warning,
      );
    } finally {
      _checking = false;
    }
    switch (outcome) {
      case BackgroundCheckOutcome.completed:
        _lastSuccess = started;
        _lastFailure = null;
      case BackgroundCheckOutcome.failed:
        _lastFailure = started;
      case BackgroundCheckOutcome.skipped:
        break;
    }
  }

  /// Cancels the timers but keeps the history; [start] arms them again.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _delayed?.cancel();
    _delayed = null;
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}
