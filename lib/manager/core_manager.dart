import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/route_state.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/tailscale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/banner.dart';

class CoreManager extends ConsumerStatefulWidget {
  final Widget child;

  const CoreManager({super.key, required this.child});

  @override
  ConsumerState<CoreManager> createState() => _CoreContainerState();
}

class _CoreContainerState extends ConsumerState<CoreManager>
    with CoreEventListener {
  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  DateTime? _mitmReapplied;

  void _applyMitm({bool throttled = false}) {
    final now = DateTime.now();
    final last = _mitmReapplied;
    if (throttled &&
        last != null &&
        now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _mitmReapplied = now;
    ref
        .read(setupActionProvider.notifier)
        .applyProfileDebounce(force: true, silence: false);
  }

  @override
  void initState() {
    super.initState();
    coreEventManager.addListener(this);
    ref.read(updatingActionProvider.notifier);
    // A rejected profile stays selected on purpose: silently reverting to
    // the previous one hides the error and looks like the switch was lost.
    ref.listenManual(currentProfileIdProvider, (prev, next) {
      if (prev == next) return;
      runAfterFrame(() {
        unawaited(ref.read(setupActionProvider.notifier).fullSetup());
      });
    });
    ref.listenManual(updateParamsProvider, (prev, next) {
      if (prev != next) {
        ref.read(setupActionProvider.notifier).updateConfigDebounce();
      }
    });
    ref.listenManual(setupPatchProvider, (prev, next) {
      if (prev != next) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true);
      }
    });
    ref.listenManual(globalRulesProvider, (prev, next) {
      if (prev?.value != null && next.hasValue) {
        ref.read(setupActionProvider.notifier).applyIfGlobalRulesUsed();
      }
    });
    ref.listenManual(
      patchClashConfigProvider.select((state) => state.mitm.enable),
      (prev, next) {
        if (prev == false && next) {
          unawaited(ref.read(mitmModulesActionProvider.notifier).autoUpdate());
        }
        // Turning decryption on or off is applied visibly: a setup that
        // fails says so instead of leaving the Core without it.
        if (mitmFeature && prev != null && prev != next) _applyMitm();
        // Off is also told to the Core on its own, so it holds even when
        // that setup cannot be made or is refused.
        if (mitmFeature && prev == true && !next) unawaited(_assertMitmOff());
      },
    );
    ref.listenManual(mitmTrustGainedProvider, (prev, next) {
      if (mitmFeature &&
          prev != next &&
          ref.read(patchClashConfigProvider).mitm.enable) {
        _applyMitm();
      }
    });
    // Trusted, hosts listed, yet the Core does not decrypt: its settings did
    // not arrive. Apply them again, at most once a while, so a failing setup
    // is reported rather than retried in a loop.
    ref.listenManual(
      mitmIndicatorProvider.select(
        (indicator) => indicator?.reason == MitmPauseReason.notApplied,
      ),
      (prev, next) {
        if (next && prev != true) _applyMitm(throttled: true);
      },
    );
    ref.listenManual(mitmModulesProvider, (prev, next) {
      if (mitmFeature &&
          mitmModulesFeature &&
          prev?.value != null &&
          next.hasValue &&
          ref.read(patchClashConfigProvider).mitm.enable) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true);
      }
    });
    ref.listenManual(appSettingProvider.select((state) => state.openLogs), (
      prev,
      next,
    ) {
      if (prev != next) {
        _syncLogStream();
      }
    });
    // Every Core process starts without a log stream.
    ref.listenManual(coreStatusProvider, (prev, next) {
      if (next == CoreStatus.connected && prev != CoreStatus.connected) {
        _syncLogStream();
        // A Core reached again may be one that kept decrypting while the
        // app was away; with decryption off here, it is told so.
        if (mitmFeature && !ref.read(patchClashConfigProvider).mitm.enable) {
          unawaited(_assertMitmOff());
        }
      }
    }, fireImmediately: true);
  }

  Future<void> _assertMitmOff() async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      // The next connection asserts it.
      return;
    }
    try {
      await _core.disableMitm();
    } catch (error) {
      commonPrint.log('mitm.disable failed: $error', logLevel: LogLevel.error);
      if (!mounted || ref.read(patchClashConfigProvider).mitm.enable) {
        return;
      }
      dialogs.showBanner(
        currentAppLocalizations.mitmTurnOffFailed,
        level: BannerLevel.error,
      );
    }
  }

  void _syncLogStream() {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    if (ref.read(appSettingProvider).openLogs) {
      _core.startLog();
    } else {
      _core.stopLog();
    }
  }

  @override
  void dispose() {
    coreEventManager.removeListener(this);
    super.dispose();
  }

  @override
  void onMitmConnection(String id, String outcome) {
    ref.read(requestsProvider.notifier).setMitmOutcome(id, outcome);
  }

  @override
  void onMitmSign(MitmSignRequest request) {
    unawaited(ref.read(mitmSignActionProvider.notifier).answer(request));
  }

  @override
  Future<void> onDelay(Delay delay) async {
    super.onDelay(delay);
    final proxiesAction = ref.read(proxiesActionProvider.notifier);
    proxiesAction.setDelay(delay);
    debouncer.call(FunctionTag.updateDelay, () async {
      proxiesAction.updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
  }

  @override
  void onLog(Log log) {
    ref.read(logsProvider.notifier).add(log);
    if (log.logLevel == LogLevel.error) {
      throttler.call(
        FunctionTag.coreErrorNotifier,
        () => dialogs.showBanner(log.payload, level: BannerLevel.error),
        duration: const Duration(seconds: 3),
        fire: true,
      );
    }
    super.onLog(log);
  }

  @override
  void onDialerLoop(String proxyName) {
    throttler.call(
      FunctionTag.dialerLoopNotifier,
      () => dialogs.showBanner(
        currentAppLocalizations.dialerProxyLoopStopped(proxyName),
        level: BannerLevel.error,
      ),
      duration: const Duration(seconds: 3),
      fire: true,
    );
    super.onDialerLoop(proxyName);
  }

  @override
  void onRequest(TrackerInfo trackerInfo) async {
    ref.read(requestsProvider.notifier).addRequest(trackerInfo);
    ref.read(requestCountProvider.notifier).update((count) => count + 1);
    super.onRequest(trackerInfo);
  }

  @override
  void onRequestTraffic(Map<String, RequestTraffic> traffic) {
    ref.read(requestsProvider.notifier).updateTraffic(traffic);
    super.onRequestTraffic(traffic);
  }

  @override
  void onDns(DnsQuery dnsQuery) {
    ref.read(dnsQueriesProvider.notifier).addQuery(dnsQuery);
    ref.read(dnsQueryCountProvider.notifier).update((count) => count + 1);
    super.onDns(dnsQuery);
  }

  @override
  Future<void> onLoaded(String providerName) async {
    final provider = await _core.getExternalProvider(providerName);
    if (!mounted) {
      return;
    }
    ref.read(providersProvider.notifier).setProvider(provider);
    debouncer.call(FunctionTag.loadedProvider, () async {
      if (!mounted) {
        return;
      }
      ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
    super.onLoaded(providerName);
  }

  @override
  Future<void> onCrash(String message) async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      dialogs.showBanner(message, level: BannerLevel.error);
    }
    super.onCrash(message);
  }

  @override
  void onGeoUpdate(String geoType, bool updating, bool skipped, String? error) {
    ref
        .read(geoResourceActionProvider.notifier)
        .handleCoreUpdate(geoType, updating, skipped, error);
    super.onGeoUpdate(geoType, updating, skipped, error);
  }

  @override
  void onTailscaleState(TailscaleStateEvent event) {
    ref.read(tailscaleStateEventsProvider.notifier).add(event);
    if (ref.exists(tailscaleNodesProvider)) {
      ref.read(tailscaleNodesProvider.notifier).applyEvent(event);
    }
    super.onTailscaleState(event);
  }

  @override
  void onTailscaleRoutes(TailscaleRoutesEvent event) {
    if (ref.exists(tailscaleRoutesReportProvider) &&
        event.profileId == ref.read(currentProfileIdProvider)) {
      ref.invalidate(tailscaleRoutesReportProvider);
    }
    super.onTailscaleRoutes(event);
  }

  @override
  void onRouteChanged(RouteSnapshot snapshot) {
    ref.read(routeTrackerProvider.notifier).applySnapshot(snapshot);
    super.onRouteChanged(snapshot);
  }
}
