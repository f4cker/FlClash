import 'dart:async';

import 'package:flutter/foundation.dart';

import 'macos_helper_client.dart';
import 'model.dart';

enum MacHelperProgress { idle, checking, authorizing, installing, updating }

final class MacHelperMaintenance extends ChangeNotifier {
  final MacHelperClient client;
  final Future<CoreLifecycleResult> Function() _stop;
  Future<MacHelperState>? _operation;
  MacHelperState? _state;
  MacHelperProgress _progress = MacHelperProgress.idle;
  bool _update = false;
  bool _stopUnknown = false;

  MacHelperMaintenance(
    this.client, {
    required Future<CoreLifecycleResult> Function() stop,
  }) : _stop = stop;

  MacHelperState? get state => _state;
  MacHelperProgress get progress => _progress;
  bool get busy => _operation != null;
  bool get isUpdate => _update;

  bool get canInstall => switch (_state) {
    MacHelperState.off ||
    MacHelperState.installerRequired ||
    MacHelperState.updateRequired ||
    MacHelperState.incompatible ||
    MacHelperState.cancelled ||
    MacHelperState.denied ||
    MacHelperState.failed => true,
    _ => false,
  };

  Future<MacHelperState> _singleFlight(
    Future<MacHelperState> Function() action,
  ) {
    final active = _operation;
    if (active != null) return active;
    final completion = Completer<MacHelperState>();
    _operation = completion.future;
    unawaited(() async {
      try {
        _state = await action();
        completion.complete(_state!);
      } catch (_) {
        _state = MacHelperState.unknown;
        completion.complete(_state!);
      } finally {
        _progress = MacHelperProgress.idle;
        _operation = null;
        notifyListeners();
      }
    }());
    return completion.future;
  }

  void _setProgress(MacHelperProgress value) {
    _progress = value;
    notifyListeners();
  }

  Future<MacHelperState> check() => _singleFlight(() async {
    _setProgress(MacHelperProgress.checking);
    final next = await client.status();
    return _stopUnknown ? MacHelperState.exitUnconfirmed : next;
  });

  Future<MacHelperState> install({required bool confirmed}) {
    if (!confirmed) throw const MacHelperException('consentRequired');
    return _singleFlight(() async {
      if (_stopUnknown) return MacHelperState.exitUnconfirmed;
      if (!canInstall) return _state ?? MacHelperState.unknown;
      _update = switch (_state) {
        MacHelperState.updateRequired || MacHelperState.incompatible => true,
        MacHelperState.cancelled ||
        MacHelperState.failed ||
        MacHelperState.denied => _update,
        _ => false,
      };
      return client.maintain(() async {
        _setProgress(MacHelperProgress.checking);
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
        _setProgress(MacHelperProgress.authorizing);
        final result = client.installerInstructions(confirmed: true);
        _setProgress(
          _update ? MacHelperProgress.updating : MacHelperProgress.installing,
        );
        return result;
      });
    });
  }

  Future<void> openSettings() async {
    if (busy || _state != MacHelperState.approvalRequired) return;
    try {
      await client.openSettings();
    } on Exception {
      // The approval instruction remains usable when Settings cannot be opened.
    }
  }
}

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
  if (foreground && maintenance.canInstall && !await wasOffered()) {
    await markOffered();
    await show();
  }
  return false;
}
