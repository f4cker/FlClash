part of '../state.dart';

@riverpod
UpdateParams updateParams(Ref ref) {
  final authentication = ref.watch(
    networkSettingProvider.select((state) => state.authentication),
  );
  final options = ref.watch(coreOptionsProvider);
  return ref.watch(
    patchClashConfigProvider.select(
      (state) => state.toUpdateParams(
        authentication: authentication.credentials,
        options: options,
        layered: true,
      ),
    ),
  );
}

/// The mixed port configured by the in-app control.
@riverpod
int effectiveMixedPort(Ref ref) {
  return ref.watch(patchClashConfigProvider.select((state) => state.mixedPort));
}

@riverpod
PatchClashConfig shownClashConfig(Ref ref) =>
    ref.watch(patchClashConfigProvider);

@riverpod
CoreOptions coreOptions(Ref ref) {
  final (:testUrl, :mitmCapture) = ref.watch(
    patchClashConfigProvider.select(
      (state) => (testUrl: state.testUrl, mitmCapture: state.mitm.capture),
    ),
  );
  final (:checkCertificate, :delayTestTimeout) = ref.watch(
    appSettingProvider.select(
      (state) => (
        checkCertificate: state.checkCertificate,
        delayTestTimeout: state.delayTestTimeout,
      ),
    ),
  );
  return CoreOptions(
    testUrl: testUrl,
    skipCertVerify: !checkCertificate,
    delayTestTimeout: delayTestTimeout,
    mitmCapture: mitmFeature && mitmCapture,
  );
}

/// The current profile's enabled rewrite rules, as the Core takes them;
/// empty while none is selected or they are still being read.
@riverpod
List<MitmRewrite> currentMitmRewrites(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) {
    return const [];
  }
  final rewrites =
      ref.watch(profileMitmRewritesProvider(profileId)).value ?? const [];
  return [
    for (final rewrite in rewrites)
      if (rewrite.enabled && mitmRewriteLists.contains(rewrite.section))
        rewrite,
  ];
}

/// The current profile's enabled scripts; empty while none is selected or
/// they are still being read.
@riverpod
List<MitmScript> currentMitmScripts(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) {
    return const [];
  }
  final scripts =
      ref.watch(profileMitmScriptsProvider(profileId)).value ?? const [];
  return [
    for (final script in scripts)
      if (script.enabled) script,
  ];
}

/// What the enabled modules add, as the Core takes it.
class MitmModuleRules {
  const MitmModuleRules({
    this.hostname = const [],
    this.rewrite = const [],
    this.script = const [],
  });

  static const empty = MitmModuleRules();

  final List<String> hostname;
  final List<Map<String, Object?>> rewrite;
  final List<Map<String, Object?>> script;

  @override
  bool operator ==(Object other) =>
      other is MitmModuleRules &&
      const DeepCollectionEquality().equals(
        [hostname, rewrite, script],
        [other.hostname, other.rewrite, other.script],
      );

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash([hostname, rewrite, script]);
}

MitmModuleRules _moduleRules(
  List<
    ({
      int id,
      String text,
      Map<String, String> values,
      Map<String, String> resources,
    })
  >
  modules,
) {
  final hostname = <String>[];
  final rewrite = <Map<String, Object?>>[];
  final script = <Map<String, Object?>>[];
  for (final module in modules) {
    final content = parseMitmModule(
      module.text,
      values: module.values,
      resources: module.resources,
    );
    final rules = content.mitm;
    hostname.addAll(rules.hostname);
    for (final list in mitmRewriteLists) {
      for (final (index, line) in rules.linesOf(list).indexed) {
        rewrite.add({
          'id': 'm${module.id}.${list.key}.$index',
          'section': list.key,
          'line': line,
        });
      }
    }
    for (final (index, line) in mitmHttpScriptLines(rules.script).indexed) {
      script.add({'id': 'm${module.id}.$index', 'line': line});
    }
  }
  return MitmModuleRules(hostname: hostname, rewrite: rewrite, script: script);
}

/// Read from the enabled modules' files; empty while modules are off.
@riverpod
Future<MitmModuleRules> enabledMitmModuleRules(Ref ref) async {
  if (!mitmModulesFeature) {
    return MitmModuleRules.empty;
  }
  final modules = [
    for (final module in await ref.watch(mitmModulesProvider.future))
      if (module.enabled) module,
  ];
  if (modules.isEmpty) {
    return MitmModuleRules.empty;
  }
  final directory = await appPath.mitmModulesDirPath;
  final sources =
      <
        ({
          int id,
          String text,
          Map<String, String> values,
          Map<String, String> resources,
        })
      >[];
  for (final module in modules) {
    final file = File(join(directory, module.fileName));
    if (!await file.exists()) {
      continue;
    }
    sources.add((
      id: module.id,
      text: await file.readAsString(),
      values: module.arguments,
      resources: module.resources,
    ));
  }
  if (sources.isEmpty) {
    return MitmModuleRules.empty;
  }
  return compute(_moduleRules, sources);
}

/// The setup `mitm.update` takes: the settings, the user's hostnames before
/// the modules', the profile's rewrite rules before the modules', and the
/// same for scripts.
Map<String, Object?> composeMitmSetup(
  Mitm mitm, {
  required List<MitmRewrite> rewrites,
  required List<MitmScript> scripts,
  required MitmModuleRules modules,
}) {
  final base = mitm.coreJson;
  final rewrite = [
    for (final item in rewrites)
      if (item.enabled && mitmRewriteLists.contains(item.section))
        item.coreJson,
    ...modules.rewrite,
  ];
  final script = [
    for (final item in scripts)
      if (item.enabled && !item.unloadable) item.coreJson,
    ...modules.script,
  ];
  return {
    ...base,
    if (modules.hostname.isNotEmpty)
      'hostname': [
        ...?(base['hostname'] as List<String>?),
        ...modules.hostname,
      ],
    if (rewrite.isNotEmpty) 'rewrite': rewrite,
    if (script.isNotEmpty) 'script': script,
  };
}

/// Null, and so no decryption, unless the user turned it on.
@riverpod
Map<String, Object?>? mitmSetup(Ref ref) {
  final mitm = ref.watch(
    patchClashConfigProvider.select((state) => state.mitm),
  );
  if (!mitmFeature || !mitm.enable) {
    return null;
  }
  return composeMitmSetup(
    mitm,
    rewrites: ref.watch(currentMitmRewritesProvider),
    scripts: ref.watch(currentMitmScriptsProvider),
    modules:
        ref.watch(enabledMitmModuleRulesProvider).value ??
        MitmModuleRules.empty,
  );
}

@riverpod
({PatchClashConfig patchConfig, bool appendSystemDns, bool bypassPrivateRoute})
setupPatch(Ref ref) {
  return (
    patchConfig: ref.watch(
      patchClashConfigProvider.select((state) => state.setupOnly),
    ),
    appendSystemDns: ref.watch(
      networkSettingProvider.select((state) => state.appendSystemDns),
    ),
    // Android's VPN service takes it on its next start instead.
    bypassPrivateRoute:
        system.isDesktop &&
        ref.watch(
          networkSettingProvider.select((state) => state.bypassPrivateRoute),
        ),
  );
}

@riverpod
TrayState trayState(Ref ref) {
  final isStart = ref.watch(runTimeProvider.select((state) => state != null));
  final systemProxy = ref.watch(
    networkSettingProvider.select((state) => state.systemProxy),
  );
  final clashConfig = ref.watch(
    patchClashConfigProvider.select(
      (state) => (mode: state.mode, tunEnable: state.tun.enable),
    ),
  );
  final appSetting = ref.watch(
    appSettingProvider.select(
      (state) => (
        autoLaunch: state.autoLaunch,
        showTrayTitle: state.showTrayTitle,
        monochromeTrayIcon: state.monochromeTrayIcon,
      ),
    ),
  );
  final groups = ref.watch(currentGroupsStateProvider).value;
  final selectedMap = ref.watch(selectedMapProvider);
  final safeMode = ref.watch(safeModeProvider);
  final suspended = ref.watch(suspendProvider);
  final hotKeys = _trayHotKeys(ref);

  return TrayState(
    mode: clashConfig.mode,
    port: ref.watch(effectiveMixedPortProvider),
    autoLaunch: appSetting.autoLaunch,
    systemProxy: systemProxy,
    tunEnable: clashConfig.tunEnable,
    isStart: isStart,
    suspended: isStart && suspended,
    groups: groups,
    selectedMap: selectedMap,
    showTrayTitle: appSetting.showTrayTitle,
    monochromeTrayIcon: appSetting.monochromeTrayIcon,
    safeMode: safeMode,
    hotKeys: hotKeys,
    mitmIndicator: ref.watch(mitmIndicatorProvider),
  );
}

Map<HotAction, HotKeyAction> _trayHotKeys(Ref ref) {
  final failures = ref.watch(hotKeyFailuresProvider);
  return {
    for (final hotKeyAction in ref.watch(hotKeyActionsProvider))
      if (isValidHotKey(hotKeyAction.modifiers, hotKeyAction.key) &&
          !failures.containsKey(hotKeyAction.action))
        hotKeyAction.action: hotKeyAction,
  };
}

/// Measured delays of the proxies the tray lists, by group and then proxy
/// name. Resolved like a proxy card, so a nested group shows its selection.
@riverpod
Map<String, Map<String, int>> trayDelays(Ref ref) {
  final delayMap = ref.watch(delayDataSourceProvider);
  if (delayMap.isEmpty) {
    return const {};
  }
  final groups = ref.watch(currentGroupsStateProvider).value;
  final allGroups = ref.watch(groupsProvider);
  final selectedMap = ref.watch(selectedMapProvider);
  final defaultTestUrl = ref.watch(
    patchClashConfigProvider.select((state) => state.testUrl),
  );
  final delays = <String, Map<String, int>>{};
  for (final group in groups) {
    final testUrl = group.testUrl.takeFirstValid([defaultTestUrl]);
    final groupDelays = <String, int>{};
    for (final proxy in group.all) {
      final delay = computeProxyDelayState(
        proxyName: proxy.name,
        testUrl: testUrl,
        groups: allGroups,
        selectedMap: selectedMap,
        delayMap: delayMap,
      ).delay;
      if (delay != 0) {
        groupDelays[proxy.name] = delay;
      }
    }
    if (groupDelays.isNotEmpty) {
      delays[group.name] = groupDelays;
    }
  }
  return delays;
}

@riverpod
TrayTitleState trayTitleState(Ref ref) {
  final showTrayTitle = ref.watch(
    appSettingProvider.select((state) => state.showTrayTitle),
  );
  final traffic = ref.watch(
    trafficsProvider.select((state) => state.list.safeLast(const Traffic())),
  );
  return TrayTitleState(showTrayTitle: showTrayTitle, traffic: traffic);
}

@riverpod
HotKeyAction getHotKeyAction(Ref ref, HotAction hotAction) {
  return ref.watch(
    hotKeyActionsProvider.select((state) {
      final index = state.indexWhere((item) => item.action == hotAction);
      return index != -1 ? state[index] : HotKeyAction(action: hotAction);
    }),
  );
}

@riverpod
SharedState sharedState(Ref ref) {
  ref.watch(loadedLocaleProvider);
  final currentProfile = ref.watch(
    currentProfileProvider.select(
      (state) => CurrentProfileSelectorState(
        label: state?.label ?? '',
        selectedMap: state?.selectedMap ?? {},
      ),
    ),
  );
  final appSetting = ref.watch(
    appSettingProvider.select(
      (state) => (
        onlyStatisticsProxy: state.onlyStatisticsProxy,
        showStopAction: state.showNotificationStopAction,
        checkCertificate: state.checkCertificate,
      ),
    ),
  );
  final currentProfileName = currentProfile.label;
  final selectedMap = currentProfile.selectedMap;
  final onlyStatisticsProxy = appSetting.onlyStatisticsProxy;
  return SharedState(
    currentProfileName: currentProfileName,
    onlyStatisticsProxy: onlyStatisticsProxy,
    showStopAction: appSetting.showStopAction,
    stopText: currentAppLocalizations.stop,
    stopTip: currentAppLocalizations.stopVpn,
    startTip: currentAppLocalizations.startVpn,
    localNetworkTip: currentAppLocalizations.localNetworkDeniedTip,
    setupParams: SetupParams(
      selectedMap: selectedMap,
      options: ref.watch(coreOptionsProvider),
      tailscale: ref.watch(tailscaleSetupProvider),
      mitm: ref.watch(mitmSetupProvider),
    ),
    vpnOptions: ref.watch(vpnOptionsProvider).value,
  );
}

@Riverpod(keepAlive: true)
Future<List<String>> vpnRouteAddress(Ref ref) {
  final routes = ref.watch(
    patchClashConfigProvider.select(
      (state) => Tun(
        routeAddress: state.tun.routeAddress,
        routeExcludeAddress: state.tun.routeExcludeAddress,
      ),
    ),
  );
  final bypassPrivateRoute = ref.watch(
    networkSettingProvider.select((state) => state.bypassPrivateRoute),
  );
  return routes.vpnRouteAddress(bypassPrivateRoute: bypassPrivateRoute);
}

@Riverpod(keepAlive: true)
Future<VpnOptions> vpnOptions(Ref ref) async {
  final networkSetting = ref.watch(
    networkSettingProvider.select(
      (state) => (
        bypassDomain: state.bypassDomain,
        authenticated: state.authentication.credentials.isNotEmpty,
      ),
    ),
  );
  final clashConfig = ref.watch(
    patchClashConfigProvider.select(
      (state) => (tun: state.tun, mixedPort: state.mixedPort),
    ),
  );
  final vpnSetting = ref.watch(vpnSettingProvider);
  final safeMode = ref.watch(safeModeProvider);
  final routeAddress = ref.watch(vpnRouteAddressProvider.future);
  final tun = clashConfig.tun;
  return VpnOptions(
    enable: vpnSetting.enable && !safeMode,
    stack: tun.stack.name,
    // VpnService.setHttpProxy cannot carry credentials, so an authenticated
    // mixed port is left to TUN instead of declared as the system proxy.
    systemProxy:
        vpnSetting.systemProxy && !networkSetting.authenticated && !safeMode,
    port: clashConfig.mixedPort,
    ipv6: vpnSetting.ipv6,
    dnsHijacking: vpnSetting.dnsHijacking,
    accessControlProps: vpnSetting.accessControlProps,
    allowBypass: vpnSetting.allowBypass,
    bypassDomain: networkSetting.bypassDomain,
    routeAddress: await routeAddress,
    mtu: tun.mtu,
    congestionController: tun.congestionController,
  );
}

@riverpod
class AccessControlState extends _$AccessControlState
    with AutoDisposeNotifierMixin {
  /// A draft of the saved props, which the access page edits until it saves.
  @override
  AccessControlProps build() =>
      ref.read(vpnSettingProvider.select((state) => state.accessControlProps));
}

@riverpod
bool suspend(Ref ref) {
  final currentSSID = ref.watch(currentSSIDProvider);
  final excludeSSIDs = ref.watch(excludeSSIDsProvider);
  return excludeSSIDs.contains(currentSSID);
}

/// Keeps a start on screen for [minimumStart] so a fast restart does not flash.
@riverpod
class HeldCoreStatus extends _$HeldCoreStatus {
  static const minimumStart = Duration(milliseconds: 1500);

  Timer? _hold;

  @override
  CoreStatus build() {
    ref.onDispose(() => _hold?.cancel());
    ref.listen(coreStatusProvider, (_, next) {
      switch (next) {
        case CoreStatus.connecting:
          _hold ??= Timer(minimumStart, () {
            _hold = null;
            state = ref.read(coreStatusProvider);
          });
          state = next;
        case CoreStatus.disconnected:
          _hold?.cancel();
          _hold = null;
          state = next;
        case CoreStatus.connected:
          if (_hold == null) state = next;
      }
    });
    return ref.read(coreStatusProvider);
  }
}
