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
      startGate: system.isMacOS
          ? () async {
              final record = await macRepairRecord();
              if (!await record.isPending()) return;
              await lifecycle.exclusiveStartCheck(() async {
                if (managedMac && lifecycle.hasNoCore) {
                  await record.clearAfterVerifiedReboot(
                    verification: _MacRepairVerification(
                      lifecycle,
                      macosHelperClient,
                      readMacBootSession,
                    ),
                  );
                }
                await requireMacRepairComplete(
                  recordFactory: () async => record,
                );
              });
            }
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

  Future<bool> canRetryMacExplicitRepair() async => (await macRepairRecord())
      .canRetryExplicit(readBootSession: readMacBootSession);

  Future<bool> recoverMacRepair() async {
    final record = await macRepairRecord();
    if (!await record.isPending()) return false;
    if (!system.isMacOS ||
        !macosManagedHelperBuild ||
        _lifecycle is! DesktopCoreLifecycle) {
      return true;
    }
    final lifecycle = _lifecycle;
    return recoverMacRepairWithOwner(
      lifecycle: lifecycle,
      client: macosHelperClient,
      record: record,
      readBootSession: readMacBootSession,
    );
  }

  Future<String> registerPendingMacRepair() async {
    if (!system.isMacOS ||
        !macosManagedHelperBuild ||
        _lifecycle is! DesktopCoreLifecycle) {
      throw const MacHelperException('unsupported');
    }
    return registerPendingMacRepairWithOwner(
      lifecycle: _lifecycle,
      client: macosHelperClient,
      record: await macRepairRecord(),
      readBootSession: readMacBootSession,
    );
  }

  Future<String> repairMacHelper({required bool confirmed}) {
    if (!confirmed ||
        !system.isMacOS ||
        !macosManagedHelperBuild ||
        _lifecycle is! DesktopCoreLifecycle) {
      throw const MacHelperException('consentRequired');
    }
    final lifecycle = _lifecycle;
    return performMacExplicitRepair(
      lifecycle: lifecycle,
      client: macosHelperClient,
      recordFactory: macRepairRecord,
      readBootSession: readMacBootSession,
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
Future<String> performMacExplicitRepair({
  required DesktopCoreLifecycle lifecycle,
  required MacHelperClient client,
  required Future<MacRepairRecord> Function() recordFactory,
  required Future<String> Function() readBootSession,
}) => client.maintain(
  () => lifecycle.maintain(() async {
    final record = await recordFactory();
    if (await record.isPending()) {
      await record.setExplicitNotStarted(
        notStarted: false,
        readBootSession: readBootSession,
      );
    } else {
      await record.markPending(readBootSession: readBootSession);
    }
    // Only native's explicit pre-dispatch evidence permits another call.
    // The record is made unknown again before every retry, including crashes.
    for (var attempt = 0; ; attempt++) {
      final result = await client.repairExplicit(confirmed: true);
      if (!client.lastExplicitNotStarted) return result;
      await record.setExplicitNotStarted(
        notStarted: true,
        readBootSession: readBootSession,
      );
      if (attempt == 10) return result;
      await Future<void>.delayed(const Duration(seconds: 1));
      await record.setExplicitNotStarted(
        notStarted: false,
        readBootSession: readBootSession,
      );
    }
  }, allowUnconfirmedStop: true),
);

@visibleForTesting
Future<String> registerPendingMacRepairWithOwner({
  required DesktopCoreLifecycle lifecycle,
  required MacHelperClient client,
  required MacRepairRecord record,
  required Future<String> Function() readBootSession,
}) => client.maintain(
  () => lifecycle.maintain(() async {
    await record.markRegistrationAttemptAfterReboot(
      readBootSession: readBootSession,
    );
    final result = await client.repairRegisterOnly();
    if (client.lastRegistrationSettled) {
      await record.markRegistrationSettled(readBootSession: readBootSession);
    }
    return result;
  }),
);

@visibleForTesting
Future<bool> recoverMacRepairWithOwner({
  required DesktopCoreLifecycle lifecycle,
  required MacHelperClient client,
  required MacRepairRecord record,
  required Future<String> Function() readBootSession,
}) => client.maintain(
  () => lifecycle.maintain(() async {
    await record.clearAfterVerifiedReboot(
      verification: _MacRepairVerification(lifecycle, client, readBootSession),
    );
    return record.isPending();
  }),
);

final class _MacRepairVerification implements MacRepairVerification {
  final DesktopCoreLifecycle lifecycle;
  final MacHelperClient client;
  final Future<String> Function() bootSession;

  const _MacRepairVerification(this.lifecycle, this.client, this.bootSession);

  @override
  Future<String> readBootSession() => bootSession();

  @override
  Future<bool> verifyCurrentSignedAuthenticatedHelperAndNoGuiCore() async {
    if (!lifecycle.hasNoCore || client.hasCoreSession) return false;
    final state = await client.status();
    return state == MacHelperState.enabled &&
        lifecycle.hasNoCore &&
        !client.hasCoreSession;
  }
}
