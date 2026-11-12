import 'launcher.dart';
import 'macos_helper_client.dart';
import 'model.dart';

final class MacHelperLauncher
    implements CoreProcessLauncher, DesktopCoreLauncherResolver {
  final MacHelperClient client;

  const MacHelperLauncher(this.client);

  @override
  Future<CoreProcessLauncher> resolve() async {
    final state = await client.status();
    if (state != MacHelperState.enabled) throw MacHelperException(state.name);
    return this;
  }

  @override
  Future<CoreProcessLease> start({
    required String sessionId,
    required String address,
  }) async {
    return MacHelperLease(client, sessionId, await client.start(sessionId));
  }
}

final class MacHelperLease implements CoreProcessLease {
  final MacHelperClient client;
  @override
  final String sessionId;
  @override
  final int pid;
  Future<CoreProcessStopResult>? _stopping;

  MacHelperLease(this.client, this.sessionId, this.pid);

  @override
  CoreProcessOwner get owner => CoreProcessOwner.helper;

  @override
  Future<CoreProcessStopResult> stop(Duration timeout) {
    return _stopping ??= _stop(timeout);
  }

  Future<CoreProcessStopResult> _stop(Duration timeout) async {
    bool confirmed;
    try {
      confirmed = await client.stop(sessionId).timeout(timeout);
    } on Exception {
      confirmed = false;
    }
    if (!confirmed) _stopping = null;
    return CoreProcessStopResult(stopped: confirmed, exitConfirmed: confirmed);
  }
}
