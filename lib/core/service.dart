import 'dart:async';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';
import 'package:flutter/foundation.dart';

import 'desktop/helper_client.dart';
import 'desktop/launcher.dart';
import 'desktop/lifecycle.dart';
import 'desktop/model.dart';
import 'desktop/macos_helper_client.dart';
import 'desktop/macos_boot_session.dart';
import 'desktop/macos_helper_launcher.dart';
import 'desktop/macos_helper_transport.dart';
import 'desktop/macos_repair_record.dart';
import 'desktop/rpc_client.dart';
import 'desktop/transport.dart';
import 'event.dart';
import 'interface.dart';
import 'method.dart';
import 'spill.dart';

class CoreService extends CoreHandlerInterface {
  static CoreService? _instance;

  final DesktopCoreLifecycleController _lifecycle;
  final CoreRpcChannel _rpcClient;
  late final StreamSubscription<DesktopCoreFailure> _crashSubscription;
  Future<CoreLifecycleResult>? _closeOperation;

  factory CoreService() {
    return _instance ??= CoreService._create();
  }

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  factory CoreService._create() {
    final address = system.isWindows ? windowsPipeName : unixSocketPath;
    final directLauncher = DirectCoreLauncher();

    final managedMac = system.isMacOS && macosManagedHelperBuild;
    late final DesktopCoreLifecycle lifecycle;
    lifecycle = DesktopCoreLifecycle(
      transport: managedMac
          ? MacHelperTransport(macosHelperClient)
          : IpcCoreTransport(address: address),
      launcherResolver: managedMac
          ? MacHelperLauncher(macosHelperClient)
          : HelperLauncherResolver(
              hasHelper: system.hasHelperService && !safeModeBuild,
              directLauncher: directLauncher,
              helperLauncher: HelperLauncher(helperClient),
              helperReady: () => helperClient.readiness(),
            ),
      verifyPeerPid: system.isWindows,
      startBlocked: system.isMacOS
          ? () => macosHelperClient.maintenanceInProgress
          : null,
      // A pending helper recovery blocks the start; only the helper card
      // settles it (the new helper confirms that no old Core runs).
      startGate: system.isMacOS
          ? () => lifecycle.exclusiveStartCheck(requireMacRepairComplete)
          : null,
    );
    return CoreService._(
      lifecycle: lifecycle,
      rpcClient: CoreRpcClient(lifecycle.transport),
    );
  }

  @visibleForTesting
  CoreService.forTesting({
    required DesktopCoreLifecycleController lifecycle,
    required CoreRpcChannel rpcClient,
  }) : this._(lifecycle: lifecycle, rpcClient: rpcClient);

  CoreService._({
    required DesktopCoreLifecycleController lifecycle,
    required CoreRpcChannel rpcClient,
  }) : _lifecycle = lifecycle,
       _rpcClient = rpcClient {
    _crashSubscription = _lifecycle.crashEvents.listen((failure) {
      coreEventManager.sendEvent(
        CoreEvent(
          type: CoreEventType.crash,
          data: failure.cause?.toString() ?? 'core done',
        ),
      );
    });
  }

  bool get _managedMac =>
      system.isMacOS &&
      macosManagedHelperBuild &&
      _lifecycle is DesktopCoreLifecycle;

  Future<bool> macRepairPending() async =>
      (await macRepairRecord()).isPending();

  /// Re-registers a stale helper registration: stops the Core, records the
  /// recovery, then lets native unregister/register and wait for the helper.
  Future<MacHelperState> recoverMacHelper() async {
    if (!_managedMac) throw const MacHelperException('unsupported');
    return recoverMacHelperWithOwner(
      lifecycle: _lifecycle as DesktopCoreLifecycle,
      client: macosHelperClient,
      record: await macRepairRecord(),
      readBootSession: readMacBootSession,
    );
  }

  /// Settles a pending recovery; returns whether it is still pending.
  Future<bool> settleMacRepair() async {
    final record = await macRepairRecord();
    if (!await record.isPending()) return false;
    if (!_managedMac) return true;
    return settleMacRepairWithOwner(
      lifecycle: _lifecycle as DesktopCoreLifecycle,
      client: macosHelperClient,
      record: record,
    );
  }

  @override
  Future<CoreLifecycleResult> start() => _lifecycle.start();

  @override
  Future<CoreLifecycleResult> restart() => _lifecycle.restart();

  @override
  Future<CoreLifecycleResult> stop() => _lifecycle.stop();

  @override
  Future<CoreLifecycleResult> close() {
    return _closeOperation ??= _close();
  }

  Future<CoreLifecycleResult> _close() async {
    try {
      return await _lifecycle.close();
    } finally {
      await _rpcClient.close();
      await _crashSubscription.cancel();
    }
  }

  @override
  Future<Object?> invokeMethod({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
    CoreResultModel? model,
  }) {
    return _rpcClient.invoke(
      method: method,
      arguments: arguments,
      timeout: timeout,
      model: model,
    );
  }
}

final coreService = system.isDesktop ? CoreService() : null;

@visibleForTesting
Future<MacHelperState> recoverMacHelperWithOwner({
  required DesktopCoreLifecycle lifecycle,
  required MacHelperClient client,
  required MacRepairRecord record,
  Future<String> Function()? readBootSession,
}) => client.maintain(
  () => lifecycle.maintain(() async {
    // The boot session is a diagnostic field only; it decides nothing.
    String? boot;
    try {
      boot = await readBootSession?.call();
    } catch (_) {}
    await record.markPending(diagnostics: {'boot': ?boot});
    return client.recover();
  }, allowUnconfirmedStop: true),
  // The Core may be unreachable while the helper is broken; the new helper
  // stops it by signature, and the record blocks starts until it confirms.
);

/// Asks the ready helper to stop every old Core (found by signature) and
/// clears the record only when it confirms none runs. Returns whether the
/// recovery is still pending.
@visibleForTesting
Future<bool> settleMacRepairWithOwner({
  required DesktopCoreLifecycle lifecycle,
  required MacHelperClient client,
  required MacRepairRecord record,
}) async {
  if (!await record.isPending()) return false;
  if (client.maintenanceInProgress) return true;
  final cleared = await client.maintain(
    () => lifecycle.maintain(
      () => record.clearIf(() async {
        if (!lifecycle.hasNoCore || client.hasCoreSession) return false;
        final code = await client.retireStaleCores();
        return (code == 'noStaleCore' || code == 'staleCoreStopped') &&
            lifecycle.hasNoCore &&
            !client.hasCoreSession;
      }),
    ),
  );
  return !cleared;
}
