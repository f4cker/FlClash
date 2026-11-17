import 'dart:async';

import 'package:flutter/foundation.dart';

import 'macos_helper_client.dart';
import 'model.dart';

enum MacHelperProgress { idle, checking, updating, opening }

/// Drives the single "Helper" card: one operation at a time, a bounded
/// start-up wait, and a re-check when the user returns from System Settings.
final class MacHelperMaintenance extends ChangeNotifier {
  final MacHelperClient client;
  final Future<CoreLifecycleResult> Function() _stop;
  final Duration startTimeout;
  final Duration startPoll;
  final Duration stalePoll;
  Future<MacHelperState>? _operation;
  MacHelperState? _state;
  MacHelperProgress _progress = MacHelperProgress.idle;
  bool _stopUnknown = false;
  bool _awaitingSettings = false;
  bool _startSlow = false;
  Timer? _startTimer;
  Timer? _pollTimer;
  bool _disposed = false;

  MacHelperMaintenance(
    this.client, {
    required Future<CoreLifecycleResult> Function() stop,
    this.startTimeout = const Duration(seconds: 10),
    this.startPoll = const Duration(seconds: 2),
    this.stalePoll = const Duration(seconds: 42),
  }) : _stop = stop;

  MacHelperState? get state => _state;
  MacHelperProgress get progress => _progress;
  bool get busy => _operation != null;

  /// The start-up wait exceeded [startTimeout]. This is not a failure: the
  /// daemon may still come up, so the card offers "Check again".
  bool get startSlow => _startSlow;

  /// True while the app waits for the user to come back from System Settings.
  bool get awaitingSettings => _awaitingSettings;
  MacHelperFailure? get failure => client.failure;
  String? get lastCode => client.lastCode;

  bool get needsApproval => switch (_state) {
    MacHelperState.requiresApproval ||
    MacHelperState.disabledByUser ||
    MacHelperState.notRegistered => true,
    _ => false,
  };

  Future<MacHelperState> _singleFlight(
    MacHelperProgress progress,
    Future<MacHelperState> Function() action,
  ) {
    final active = _operation;
    if (active != null) return active;
    final completion = Completer<MacHelperState>();
    _operation = completion.future;
    _progress = progress;
    notifyListeners();
    unawaited(() async {
      try {
        _setState(await action());
      } catch (_) {
        _setState(MacHelperState.unavailable);
      } finally {
        _progress = MacHelperProgress.idle;
        _operation = null;
        completion.complete(_state!);
        _notify();
      }
    }());
    return completion.future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setState(MacHelperState next) {
    _state = next;
    final waiting =
        next == MacHelperState.starting || next == MacHelperState.staleHelper;
    if (!waiting) {
      _startTimer?.cancel();
      _startTimer = null;
      _pollTimer?.cancel();
      _pollTimer = null;
      _startSlow = false;
      return;
    }
    _startTimer ??= Timer(startTimeout, () {
      _startSlow = true;
      _pollTimer?.cancel();
      _pollTimer = null;
      if (_state == MacHelperState.staleHelper) _scheduleStalePoll();
      _notify();
    });
    _pollTimer?.cancel();
    if (next == MacHelperState.staleHelper) {
      _scheduleStalePoll();
    } else if (!_startSlow) {
      _pollTimer = Timer(startPoll, () {
        _pollTimer = null;
        if (!busy && !_startSlow) unawaited(check());
      });
    }
  }

  void _scheduleStalePoll() {
    _pollTimer = Timer(stalePoll, () {
      _pollTimer = null;
      if (!busy) unawaited(check());
    });
  }

  Future<MacHelperState> _status() async {
    final next = await client.status();
    return _stopUnknown ? MacHelperState.exitUnconfirmed : next;
  }

  Future<MacHelperState> check() =>
      _singleFlight(MacHelperProgress.checking, _status);

  /// Explicit re-check from the card: restarts the bounded start-up wait.
  Future<MacHelperState> recheck() {
    if (!busy) {
      _startTimer?.cancel();
      _startTimer = null;
      _startSlow = false;
    }
    return check();
  }

  /// Remove the old helper (administrator prompt) and register the daemon.
  /// Also the retry path after a failed update/registration step.
  Future<MacHelperState> migrate({required bool confirmed}) {
    if (!confirmed) throw const MacHelperException('consentRequired');
    return _singleFlight(MacHelperProgress.updating, () async {
      if (_stopUnknown) return MacHelperState.exitUnconfirmed;
      return client.maintain(() async {
        try {
          final stopped = await _stop();
          if (stopped.outcome == CoreLifecycleOutcome.superseded ||
              stopped.session != null) {
            _stopUnknown = true;
          }
        } catch (_) {
          _stopUnknown = true;
        }
        if (_stopUnknown) return MacHelperState.exitUnconfirmed;
        return client.migrate(confirmed: true);
      });
    });
  }

  /// Repair from "Core state unconfirmed" (and the like): stop the Core through
  /// the app, then re-check the native state.
  Future<MacHelperState> repair() {
    return _singleFlight(MacHelperProgress.updating, () async {
      return client.maintain(() async {
        try {
          final stopped = await _stop();
          if (stopped.outcome != CoreLifecycleOutcome.superseded &&
              stopped.session == null) {
            _stopUnknown = false;
          }
        } catch (_) {
          // The native repair still runs; the daemon answers for the Core.
        }
        final next = await client.repair();
        return _stopUnknown ? MacHelperState.exitUnconfirmed : next;
      });
    });
  }

  /// Retry after "update did not complete": the native side resumes from
  /// whatever residue remains, or only registers when nothing old is left.
  Future<MacHelperState> retry() => migrate(confirmed: true);

  /// Register if needed, then open Login Items & Extensions. The card re-checks
  /// automatically when Flash returns to the foreground.
  Future<void> openSettings() async {
    if (busy || !needsApproval) return;
    await _singleFlight(MacHelperProgress.opening, () async {
      var next = _state!;
      if (next == MacHelperState.notRegistered) {
        next = await client.enable();
        if (!{
          MacHelperState.requiresApproval,
          MacHelperState.disabledByUser,
        }.contains(next)) {
          return next;
        }
      }
      _awaitingSettings = true;
      try {
        await client.openSettings();
      } on Exception {
        // The written steps remain usable when Settings cannot be opened.
      }
      return next;
    });
  }

  /// Called when Flash becomes the active app again.
  void resumed() {
    if (_awaitingSettings || needsApproval) {
      _awaitingSettings = false;
      unawaited(check());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _startTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

/// Startup gate: the Core starts through the daemon only when it is ready.
/// TUN and other privileged features stay off until then.
Future<bool> prepareMacHelperStartup({
  required MacHelperMaintenance maintenance,
  required bool foreground,
  required void Function() onBlocked,
  required Future<bool> Function() wasOffered,
  required Future<void> Function() markOffered,
  required Future<void> Function() show,
}) async {
  final alreadyBusy = maintenance.busy;
  final state = await maintenance.check();
  if (state == MacHelperState.enabled && !alreadyBusy) return true;
  onBlocked();
  final offer = switch (state) {
    MacHelperState.migrationRequired ||
    MacHelperState.notRegistered ||
    MacHelperState.requiresApproval => true,
    _ => false,
  };
  if (foreground && offer && !await wasOffered()) {
    await markOffered();
    await show();
  }
  return false;
}
