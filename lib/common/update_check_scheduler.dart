import 'dart:async';

import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/enum/enum.dart';

typedef PeriodicTimerFactory =
    Timer Function(Duration interval, void Function(Timer timer) onTick);

/// Keeps checking for app updates while the app stays open.
///
/// One periodic timer, created by [start], re-checks every [interval]; the
/// setting is read when it fires, so turning automatic checks off stops them
/// without tearing the timer down. [requestCheck] asks for a check after an
/// event such as the Mac waking up. Every check, whichever its trigger, is
/// skipped while one runs or when the last one started less than [minGap]
/// ago, so the triggers together never check more often than that.
///
/// The wall clock ([now]) measures the gap: the monotonic clock a [Timer]
/// runs on stops while the Mac sleeps, the wall clock does not.
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

  /// Checks now and starts the periodic timer; later calls do nothing.
  void start() {
    if (_disposed || _timer != null) return;
    _timer = _periodicTimer(interval, (_) => unawaited(_run('periodic')));
    unawaited(_run('launch'));
  }

  /// Checks unless a check ran within [minGap]; does nothing before [start].
  void requestCheck(String reason) {
    if (_timer == null) return;
    unawaited(_run(reason));
  }

  Future<void> _run(String reason) async {
    if (_disposed || _checking || !_enabled()) return;
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
