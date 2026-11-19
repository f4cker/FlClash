import 'dart:async';

import 'package:flutter/widgets.dart';

import 'macos_helper_client.dart';
import 'macos_repair_record.dart';
import 'model.dart';

enum MacHelperProgress { idle, checking, updating, opening, repairingRecord }

/// Drives the single "Helper" card: one operation at a time, a bounded
/// start-up wait, and a re-check when the user returns from System Settings.
///
/// It also recovers a stale registration without the user: when the helper
/// reports that launchd cannot start this build (`registrationStale`), the app
/// stops its Core and re-registers the daemon, at most [maxAutoRecoveries]
/// times per launch; later attempts come from the card's button. Re-adding a
/// daemon needs the user to allow it once in System Settings, which is the
/// only thing the user is asked to do. Once the helper answers, a pending
/// recovery is settled by the helper's own sweep of old Cores.
///
/// After an app update the previous build's helper may still run
/// (`staleHelper`). The native side asks it to exit (never a re-registration)
/// and says so (`retiring`); for at most [switchWindow] the card then shows
/// the switch to the new helper and checks every [switchPoll], and the Core
/// starts by itself ([runOnceReady]) once the new helper answers. A switch
/// that does not complete falls back to the "taking longer" card.
final class MacHelperMaintenance extends ChangeNotifier {
  final MacHelperClient client;
  final Future<CoreLifecycleResult> Function() _stop;
  final Future<MacHelperState> Function()? _recover;
  final Future<bool> Function()? _settleRepair;
  final Future<bool> Function()? _repairIsPending;
  final Duration startTimeout;
  final Duration startPoll;
  final Duration stalePoll;
  final Duration switchWindow;
  final Duration switchPoll;
  final Duration approvalPoll;
  final int maxApprovalPolls;
  final Duration recoveryRetryDelay;
  final int maxAutoRecoveries;
  final int maxResumeEnables;
  Future<MacHelperState>? _operation;
  MacHelperState? _state;
  MacHelperProgress _progress = MacHelperProgress.idle;
  bool _stopUnknown = false;
  bool _awaitingSettings = false;
  bool _startSlow = false;
  bool _resumeCheckPending = false;
  bool _resumeChecking = false;
  bool _repairPending = false;

  /// A switch to the bundled helper is under way (see [switchingHelper]).
  bool _switching = false;

  /// The switch for the helper now running ran out or failed: it is not
  /// started again by itself, only by the user's "Check again".
  bool _switchSpent = false;
  Timer? _switchTimer;

  /// A repair from [MacHelperState.serviceNotFound] ended still notFound: a
  /// later read of the same state keeps the failure (with its details)
  /// instead of offering the same repair again by itself.
  bool _serviceRepairFailed = false;

  /// The one automatic registration of this launch for serviceNotFound.
  bool _autoRegisterTried = false;
  int _autoRecoveries = 0;
  bool _enableOnResume = false;
  int _resumeEnables = 0;
  int _approvalPolls = 0;
  String? _repairDetail;
  final List<Future<void> Function()> _onReady = [];
  AppLifecycleListener? _lifecycle;
  Timer? _startTimer;
  Timer? _pollTimer;
  Timer? _approvalTimer;
  bool _disposed = false;

  MacHelperMaintenance(
    this.client, {
    required Future<CoreLifecycleResult> Function() stop,
    Future<MacHelperState> Function()? recover,
    Future<bool> Function()? settleRepair,
    Future<bool> Function()? repairPending,
    this.startTimeout = const Duration(seconds: 10),
    this.startPoll = const Duration(seconds: 2),
    this.stalePoll = const Duration(seconds: 42),
    this.switchWindow = const Duration(seconds: 45),
    this.switchPoll = const Duration(seconds: 2),
    this.approvalPoll = const Duration(seconds: 2),
    this.maxApprovalPolls = 90,
    this.recoveryRetryDelay = const Duration(seconds: 2),
    this.maxAutoRecoveries = 2,
    this.maxResumeEnables = 2,
    bool observeLifecycle = false,
  }) : _stop = stop,
       _recover = recover,
       _settleRepair = settleRepair,
       _repairIsPending = repairPending {
    if (observeLifecycle) _lifecycle = AppLifecycleListener(onResume: resumed);
  }

  MacHelperState? get state => _state;
  MacHelperProgress get progress => _progress;
  bool get busy => _operation != null;

  /// Only re-reading a helper that was ready (a config apply or start asks
  /// again): nothing about it is in doubt until the answer says otherwise, so
  /// views keep showing the running Core instead of a waiting state.
  bool get routineCheck =>
      busy &&
      _progress == MacHelperProgress.checking &&
      _state == MacHelperState.enabled;

  /// A recovery is not settled yet; Core starts stay blocked.
  bool get repairPending => _repairPending;

  /// Automatic recoveries used in this launch.
  int get autoRecoveries => _autoRecoveries;

  /// Registrations repeated by themselves on returning to the foreground in
  /// this launch (see [resumed]).
  int get resumeEnables => _resumeEnables;

  /// The start-up wait exceeded [startTimeout]. This is not a failure: the
  /// daemon may still come up, so the card offers "Check again".
  bool get startSlow => _startSlow;

  /// The previous build's helper was asked to exit and the bundled one is
  /// awaited: a transition, not a problem. Bounded by [switchWindow].
  bool get switchingHelper => _switching;

  /// True while the app waits for the user to come back from System Settings.
  bool get awaitingSettings => _awaitingSettings;
  MacHelperFailure? get failure => client.failure;
  String? get lastCode => client.lastCode;

  /// Copyable raw text for "View details"; never shown elsewhere.
  String get rawDetail => [
    if (client.lastDetail?.isNotEmpty == true) client.lastDetail!,
    if (failure?.detail.isNotEmpty == true) failure!.detail,
    if (_repairDetail?.isNotEmpty == true) _repairDetail!,
    if (lastCode != null) 'status: $lastCode',
  ].join('\n');

  /// Evidence that turning Flash's switch off and back on is the step that
  /// can help now, all from the recovery's own answer, which is still the
  /// latest one:
  /// (a) SMAppService.status read `enabled` (the native side only waits for
  ///     the new helper after that read, and reports `serviceStatus`);
  /// (b) the new helper then did not answer (`helperNotReady`), so the state
  ///     is [MacHelperState.notReady];
  /// (c) the user can act on it now: nothing is running and no recovery is
  ///     in progress.
  /// Without all three the card shows its state and "View details" only.
  bool get switchResetMayHelp =>
      _state == MacHelperState.notReady &&
      client.lastCode == 'helperNotReady' &&
      client.lastServiceStatus == 'enabled' &&
      !busy;

  bool get needsApproval => switch (_state) {
    MacHelperState.requiresApproval ||
    MacHelperState.disabledByUser ||
    MacHelperState.notRegistered => true,
    _ => false,
  };

  /// Runs [action] once, the first time a check ends with the helper ready
  /// and no recovery pending (for example the Core start that was skipped at
  /// launch because the helper was not ready).
  void runOnceReady(Future<void> Function() action) {
    if (_state == MacHelperState.enabled && !busy && !_repairPending) {
      unawaited(action());
      return;
    }
    _onReady.add(action);
  }

  Future<MacHelperState> _singleFlight(
    MacHelperProgress progress,
    Future<MacHelperStatus> Function() action,
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
      } catch (error) {
        _repairDetail = _describe(error);
        _setState(const MacHelperStatus(MacHelperState.unavailable));
      }
      final initialState = _state!;
      if (_resumeCheckPending && !_disposed) {
        _resumeCheckPending = false;
        _resumeChecking = true;
        try {
          _setState(await _resumeStatus());
        } catch (error) {
          _repairDetail = _describe(error);
          _setState(const MacHelperStatus(MacHelperState.unavailable));
        } finally {
          _resumeChecking = false;
        }
      }
      _progress = MacHelperProgress.idle;
      _operation = null;
      // A later ready answer must not unblock a startup that saw a failure.
      completion.complete(
        initialState != MacHelperState.enabled &&
                _state == MacHelperState.enabled
            ? initialState
            : _state!,
      );
      _notify();
      if (_state == MacHelperState.enabled &&
          !_repairPending &&
          _onReady.isNotEmpty &&
          !_disposed) {
        final ready = List.of(_onReady);
        _onReady.clear();
        for (final action in ready) {
          unawaited(action());
        }
      }
    }());
    return completion.future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Raw text of an error for "View details" only.
  static String _describe(Object error) => error.toString();

  void _setState(MacHelperStatus answer) {
    var next = answer.state;
    if (next == MacHelperState.serviceRepairFailed) {
      _serviceRepairFailed = true;
    } else if (next == MacHelperState.serviceNotFound && _serviceRepairFailed) {
      next = MacHelperState.serviceRepairFailed;
    } else if (next != MacHelperState.serviceNotFound) {
      _serviceRepairFailed = false;
    }
    _state = next;
    if (!needsApproval) _enableOnResume = false;
    _scheduleApprovalPoll();
    _trackSwitch(next, retiring: answer.retiring);
    final waiting =
        next == MacHelperState.starting ||
        next == MacHelperState.staleHelper ||
        next == MacHelperState.repairing;
    if (!waiting) {
      _startTimer?.cancel();
      _startTimer = null;
      _pollTimer?.cancel();
      _pollTimer = null;
      _startSlow = false;
      return;
    }
    if (_switching) {
      _startTimer?.cancel();
      _startTimer = null;
    } else if (!_startSlow) {
      _startTimer ??= Timer(startTimeout, () {
        _startTimer = null;
        _startSlow = true;
        _pollTimer?.cancel();
        _pollTimer = null;
        if (_state == MacHelperState.staleHelper) _scheduleStalePoll();
        _notify();
      });
    }
    _pollTimer?.cancel();
    if (_switching) {
      _pollTimer = Timer(switchPoll, () {
        _pollTimer = null;
        if (!busy && _switching) unawaited(check());
      });
    } else if (next == MacHelperState.staleHelper) {
      _scheduleStalePoll();
    } else if (!_startSlow) {
      // Polls only inside the bounded start-up window; afterwards the card
      // waits for the user (or the app returning to the foreground).
      _pollTimer = Timer(startPoll, () {
        _pollTimer = null;
        if (!busy && !_startSlow) unawaited(check());
      });
    }
  }

  /// Starts a switch when the native side asked the previous build's helper
  /// to exit, keeps it while the bundled helper is starting, and ends it on
  /// any other answer: ready, a real problem (shown as is), or `staleHelper`
  /// without a new exit request (the tries are used up), which reads as
  /// "taking longer".
  void _trackSwitch(MacHelperState next, {required bool retiring}) {
    if (next == MacHelperState.staleHelper && retiring) {
      if (!_switching && !_switchSpent) {
        _switching = true;
        _switchTimer = Timer(switchWindow, _switchTimedOut);
      }
      return;
    }
    if (!_switching) {
      if (next == MacHelperState.enabled) _switchSpent = false;
      return;
    }
    if (next == MacHelperState.starting) return;
    _switchTimer?.cancel();
    _switchTimer = null;
    _switching = false;
    if (next == MacHelperState.staleHelper) {
      _switchSpent = true;
      _startSlow = true;
    }
  }

  void _switchTimedOut() {
    _switchTimer = null;
    if (!_switching || _disposed) return;
    _switching = false;
    _switchSpent = true;
    if (_state == MacHelperState.staleHelper ||
        _state == MacHelperState.starting) {
      _startSlow = true;
      _pollTimer?.cancel();
      _pollTimer = null;
      if (_state == MacHelperState.staleHelper) _scheduleStalePoll();
    }
    _notify();
  }

  void _scheduleStalePoll() {
    _pollTimer = Timer(stalePoll, () {
      _pollTimer = null;
      if (!busy) unawaited(check());
    });
  }

  /// Only after the user opened System Settings (and until Flash is active
  /// again, which re-checks by itself), read SMAppService.status every
  /// [approvalPoll], at most [maxApprovalPolls] times; once it reads enabled,
  /// a full check (trust gate and authenticated hello) continues by itself.
  /// Nothing polls while the card merely shows the approval step.
  void _scheduleApprovalPoll() {
    final registered =
        _state == MacHelperState.requiresApproval ||
        _state == MacHelperState.disabledByUser;
    if (!registered ||
        !_awaitingSettings ||
        _approvalPolls >= maxApprovalPolls ||
        _disposed) {
      _approvalTimer?.cancel();
      _approvalTimer = null;
      return;
    }
    _approvalTimer ??= Timer(approvalPoll, () async {
      _approvalTimer = null;
      _approvalPolls++;
      if (_disposed || busy) {
        _scheduleApprovalPoll();
        return;
      }
      final system = await client.approvalStatus();
      if (_disposed) return;
      if (system == MacHelperState.enabled && !busy) {
        unawaited(check());
      } else {
        _scheduleApprovalPoll();
      }
    });
  }

  Future<MacHelperStatus> _status() async {
    var next = await client.statusResult();
    if (next.state == MacHelperState.registrationStale) {
      next = MacHelperStatus(await _recoverWithinBudget(automatic: true));
    } else if (next.state == MacHelperState.serviceNotFound) {
      next = MacHelperStatus(await _autoRegister());
    }
    return _settle(next);
  }

  /// SMAppService has no record of the intact, trusted bundle (typically the
  /// helper was never registered under its current name, e.g. a drag-over
  /// install from an older build): register it by itself, once per launch,
  /// so the user at most allows it once in System Settings. Only `enable`
  /// (the native trust gate runs first; nothing is unregistered and no Core
  /// is touched). If that does not help, the card's "Repair" (the full
  /// user-triggered recovery) is the fallback; nothing repeats by itself.
  Future<MacHelperState> _autoRegister() async {
    if (_autoRegisterTried || _serviceRepairFailed) {
      return MacHelperState.serviceNotFound;
    }
    _autoRegisterTried = true;
    _progress = MacHelperProgress.updating;
    _notify();
    final next = await client.enable();
    _noteRegisterAnswer(next);
    // Register refused while the system still has no record: the Repair card,
    // with the register error and code behind "View details".
    if (next == MacHelperState.updateFailed &&
        client.lastServiceStatus == 'notFound') {
      return MacHelperState.serviceNotFound;
    }
    return next;
  }

  /// Whether this launch already registered by itself for serviceNotFound.
  bool get autoRegisterTried => _autoRegisterTried;

  /// One recovery, repeated while the system keeps reporting a stale
  /// registration and the automatic budget allows. Each automatic attempt
  /// (and every repeat) counts; a repeat waits [recoveryRetryDelay].
  Future<MacHelperState> _recoverWithinBudget({required bool automatic}) async {
    final recover = _recover;
    if (recover == null) return MacHelperState.registrationStale;
    var next = MacHelperState.registrationStale;
    var first = true;
    while (next == MacHelperState.registrationStale) {
      if (automatic || !first) {
        if (_autoRecoveries >= maxAutoRecoveries) break;
        _autoRecoveries++;
      }
      if (!first) await Future<void>.delayed(recoveryRetryDelay);
      first = false;
      _progress = MacHelperProgress.updating;
      _notify();
      try {
        next = await recover();
      } catch (error) {
        _repairDetail = _describe(error);
        return MacHelperState.notReady;
      }
    }
    _noteRegisterAnswer(next);
    return next;
  }

  /// Registering was refused until the user allows Flash (EPERM) while the
  /// system still reported the daemon as not registered: once the user has
  /// turned Flash on in Login Items, the registration has to be made again.
  /// [resumed] does that once by itself instead of asking for another click.
  void _noteRegisterAnswer(MacHelperState next) {
    if (next == MacHelperState.requiresApproval &&
        client.lastServiceStatus == 'notRegistered') {
      _enableOnResume = true;
    }
  }

  /// The check on returning to the foreground. When armed by
  /// [_noteRegisterAnswer] and the daemon still reads "not registered", one
  /// `enable` follows (at most [maxResumeEnables] per launch). Its own answer
  /// never arms another one, so this cannot repeat by itself.
  Future<MacHelperStatus> _resumeStatus() async {
    if (!_enableOnResume) return _status();
    _enableOnResume = false;
    var next = await client.statusResult();
    if (next.state == MacHelperState.notRegistered &&
        _resumeEnables < maxResumeEnables) {
      _resumeEnables++;
      next = MacHelperStatus(await client.enable());
    } else if (next.state == MacHelperState.registrationStale) {
      next = MacHelperStatus(await _recoverWithinBudget(automatic: true));
    }
    return _settle(next);
  }

  /// A pending recovery is settled only when the helper is ready: it stops
  /// every old Core it finds by signature and confirms they exited.
  Future<MacHelperStatus> _settle(MacHelperStatus next) async {
    final settle = _settleRepair;
    if (settle != null) {
      try {
        _repairPending = next.state == MacHelperState.enabled
            ? await settle()
            : await (_repairIsPending?.call() ?? Future.value(false));
      } catch (error) {
        _repairPending = true;
        _repairDetail = _describe(error);
      }
      if (next.state == MacHelperState.enabled && _repairPending) {
        return const MacHelperStatus(MacHelperState.staleCore);
      }
    }
    return _stopUnknown
        ? const MacHelperStatus(MacHelperState.exitUnconfirmed)
        : next;
  }

  Future<MacHelperState> check() =>
      _singleFlight(MacHelperProgress.checking, _status);

  /// Explicit re-check from the card: restarts the bounded start-up wait.
  /// For the previous build's helper this asks it to exit once more (native
  /// `repair`, which never re-registers), allowing one more switch.
  Future<MacHelperState> recheck() {
    if (!busy) {
      _startTimer?.cancel();
      _startTimer = null;
      _startSlow = false;
      if (_state == MacHelperState.staleHelper) {
        _switchSpent = false;
        return _singleFlight(MacHelperProgress.checking, _retireStale);
      }
    }
    return check();
  }

  /// Native `repair`: the status, with one more exit request for a stale
  /// helper. Refused while a Core session runs: then only the status.
  Future<MacHelperStatus> _retireStale() async {
    var next = await client.repairResult();
    if (next.code == 'sessionBusy') next = await client.statusResult();
    return _settle(next);
  }

  /// The card's button after the helper did not become ready, or "Repair"
  /// when SMAppService has no record of the intact bundle (serviceNotFound):
  /// one more recovery (stop the Core, unregister, register, then approval or
  /// the new helper's hello), whatever the automatic budget says. Only ever
  /// called from a user's tap; [check] and [resumed] never recover
  /// serviceNotFound (only [_autoRegister]'s single `enable` per launch).
  Future<MacHelperState> retryRecovery() {
    return _singleFlight(MacHelperProgress.updating, () async {
      _repairDetail = null;
      var next = await client.statusResult();
      if (next.state == MacHelperState.registrationStale ||
          next.state == MacHelperState.notReady ||
          next.state == MacHelperState.starting ||
          next.state == MacHelperState.serviceNotFound) {
        next = MacHelperStatus(await _recoverWithinBudget(automatic: false));
      } else if (next.state == MacHelperState.staleHelper) {
        // The previous build's helper: ask it to exit, never re-register
        // (that would turn the approval in System Settings off).
        _switchSpent = false;
        return _retireStale();
      }
      return _settle(next);
    });
  }

  /// Remove the old helper (administrator prompt) and register the daemon.
  /// Also the retry path after a failed update/registration step.
  Future<MacHelperState> migrate({required bool confirmed}) {
    if (!confirmed) throw const MacHelperException('consentRequired');
    return _singleFlight(MacHelperProgress.updating, () async {
      if (_stopUnknown) {
        return const MacHelperStatus(MacHelperState.exitUnconfirmed);
      }
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
        if (_stopUnknown) {
          return const MacHelperStatus(MacHelperState.exitUnconfirmed);
        }
        final next = await client.migrate(confirmed: true);
        _noteRegisterAnswer(next);
        return MacHelperStatus(next);
      });
    });
  }

  /// Repair from "Core state unconfirmed" (and the like): stop the Core through
  /// the app, then re-check the native state.
  Future<MacHelperState> repair() {
    return _singleFlight(MacHelperProgress.updating, () async {
      final next = await client.maintain(() async {
        try {
          final stopped = await _stop();
          if (stopped.outcome != CoreLifecycleOutcome.superseded &&
              stopped.session == null) {
            _stopUnknown = false;
          }
        } catch (_) {
          // The native repair still runs; the daemon answers for the Core.
        }
        return client.repairResult();
      });
      return _settle(next);
    });
  }

  /// The launcher's version record is unreadable: rebuild it (administrator
  /// prompt) and ask the helper again; a successful repair reads as a start.
  Future<MacHelperState> repairRecord() {
    return _singleFlight(MacHelperProgress.repairingRecord, () async {
      _repairDetail = null;
      return _settle(
        MacHelperStatus(await client.repairLauncherRecord(confirmed: true)),
      );
    });
  }

  /// Outcome of the last record repair, while its card is still shown.
  String? get recordRepair => client.lastRecordRepair;

  /// Retry after "update did not complete": the native side resumes from
  /// whatever residue remains, or only registers when nothing old is left.
  Future<MacHelperState> retry() => migrate(confirmed: true);

  /// Register if needed, then open Login Items & Extensions. The card re-checks
  /// when Flash returns to the foreground and while it waits.
  Future<void> openSettings() async {
    if (busy || !needsApproval) return;
    await _singleFlight(MacHelperProgress.opening, () async {
      var next = _state!;
      if (next == MacHelperState.notRegistered) {
        next = await client.enable();
        _noteRegisterAnswer(next);
        if (!{
          MacHelperState.requiresApproval,
          MacHelperState.disabledByUser,
        }.contains(next)) {
          return MacHelperStatus(next);
        }
      }
      _awaitingSettings = true;
      _approvalPolls = 0;
      try {
        await client.openSettings();
      } on Exception {
        // The written steps remain usable when Settings cannot be opened.
      }
      return MacHelperStatus(next);
    });
  }

  /// Called when Flash becomes the active app again.
  void resumed() {
    final retry = switch (_state) {
      MacHelperState.notReady ||
      MacHelperState.staleCore ||
      MacHelperState.registrationStale ||
      MacHelperState.launcherCheckFailed ||
      MacHelperState.launcherDowngrade ||
      MacHelperState.launcherFailed ||
      MacHelperState.launcherRecordDamaged ||
      // Re-read only (one hello); never a recovery.
      MacHelperState.untrustedReply ||
      MacHelperState.unavailable => true,
      MacHelperState.starting => _startSlow,
      _ => false,
    };
    if (_awaitingSettings || needsApproval || retry) {
      _awaitingSettings = false;
      _approvalTimer?.cancel();
      _approvalTimer = null;
      if (_resumeChecking) return;
      if (busy) {
        _resumeCheckPending = true;
      } else {
        _resumeChecking = true;
        unawaited(
          _singleFlight(
            MacHelperProgress.checking,
            _resumeStatus,
          ).whenComplete(() => _resumeChecking = false),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    _startTimer?.cancel();
    _pollTimer?.cancel();
    _approvalTimer?.cancel();
    _switchTimer?.cancel();
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
    MacHelperState.requiresApproval ||
    MacHelperState.disabledByUser => true,
    _ => false,
  };
  // A recovery that needs the user to allow Flash again is always shown.
  final recovered = maintenance.autoRecoveries > 0 && maintenance.needsApproval;
  if (foreground && offer && (recovered || !await wasOffered())) {
    await markOffered();
    await show();
  }
  return false;
}

/// Whether a failed Core start only means that the helper is not ready (or is
/// being recovered). Those are shown by the helper card, never as a banner.
bool isMacHelperStartFailure(Object error) => switch (error) {
  MacHelperException() || MacRepairPendingException() => true,
  DesktopCoreFailure(code: 'maintenance' || 'maintenance_stop_unconfirmed') =>
    true,
  DesktopCoreFailure(:final cause?) => isMacHelperStartFailure(cause),
  _ => false,
};
