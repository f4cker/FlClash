import 'macos_helper_client.dart';
import 'model.dart';

final class MacHelperMaintenance {
  final MacHelperClient client;
  final Future<CoreLifecycleResult> Function() _stop;
  bool _busy = false;

  MacHelperMaintenance(
    this.client, {
    required Future<CoreLifecycleResult> Function() stop,
  }) : _stop = stop;

  Future<MacHelperState> turnOff({required bool confirmed}) async {
    if (!confirmed) throw const MacHelperException('consentRequired');
    if (_busy) throw const MacHelperException('maintenance');
    _busy = true;
    try {
      return await client.maintain(() async {
        final stopped = await _stop();
        if (stopped.outcome == CoreLifecycleOutcome.superseded) {
          return MacHelperState.exitUnconfirmed;
        }
        return client.installerInstructions(confirmed: true);
      });
    } on Exception {
      return MacHelperState.exitUnconfirmed;
    } finally {
      _busy = false;
    }
  }
}
