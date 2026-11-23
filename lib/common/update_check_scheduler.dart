import 'dart:async';

import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/enum/enum.dart';

typedef PeriodicTimerFactory =
    Timer Function(Duration interval, void Function(Timer timer) onTick);

class UpdateCheckScheduler {
  UpdateCheckScheduler({
    required Future<void> Function() check,
    required bool Function() enabled,
    DateTime Function()? now,
    PeriodicTimerFactory? periodicTimer,
    this.interval = const Duration(hours: 6),
    this.minGap = const Duration(minutes: 30),
  }) : _check = check,
       _enabled = enabled,
       _now = now ?? DateTime.now,
       _periodicTimer = periodicTimer ?? Timer.periodic;

  final Future<void> Function() _check;
  final bool Function() _enabled;
  final DateTime Function() _now;
  final PeriodicTimerFactory _periodicTimer;
  final Duration interval;
  final Duration minGap;

  Timer? _timer;
  DateTime? _lastCheck;
  bool _checking = false;
  bool _disposed = false;

  bool get started => _timer != null;

  void start() {
    if (_disposed || _timer != null) return;
    _timer = _periodicTimer(interval, (_) => unawaited(_run('periodic')));
    unawaited(_run('launch'));
  }

  void requestCheck(String reason) {
    if (_timer == null) return;
    unawaited(_run(reason));
  }

  Future<void> _run(String reason) async {
    if (_disposed || _checking || !_enabled()) return;
    // A Timer runs on the monotonic clock, which stops while the Mac sleeps;
    // the gap is measured on the wall clock, which does not.
    final now = _now();
    final last = _lastCheck;
    if (last != null && now.difference(last).abs() < minGap) return;
    _lastCheck = now;
    _checking = true;
    try {
      await _check();
    } catch (error) {
      commonPrint.log(
        'Background update check ($reason) failed: $error',
        logLevel: LogLevel.warning,
      );
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
