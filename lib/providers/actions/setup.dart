part of '../action.dart';

String _mountProjectionConfig(
  ({
    List<ProxyGroup> groups,
    List<CustomProxy> proxies,
    Map<int, String> dialers,
    Map<String, dynamic> providers,
  })
  data,
) => json.encode({
  'proxies': appProxiesPayload(
    data.proxies,
    dialers: data.dialers,
    groups: data.groups,
  ),
  'proxy-groups': [for (final group in data.groups) group.definition],
  'proxy-providers': data.providers,
});

enum _SetupTaskResult { completed, handoffToCoreRestart, failed }

typedef _SetupInputs = (
  SetupState,
  PatchClashConfig,
  NetworkProps,
  SetupParams,
);

typedef BuiltProfile = ({
  String yaml,
  String md5,
  ConfigCounts counts,
  SetupBase? base,
});

typedef _CompositionCandidate = ({
  Profile profile,
  SetupState state,
  PatchClashConfig patch,
  NetworkProps network,
  SetupParams params,
  BuiltProfile built,
  String materialized,
  String fingerprint,
  Set<String> basePaths,
});

class _RunRequest {
  final bool running;
  final bool initialize;

  /// Adopts a run the Android service has, config and groups alike.
  final bool resume;
  final DateTime? previousStartTime;

  const _RunRequest({
    required this.running,
    required this.initialize,
    required this.resume,
    required this.previousStartTime,
  });
}

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  Timer? _runtimeTimer;
  int _trayModeRevision = 0;
  final _setupScheduler = SerialTaskScheduler();
  final _compositionReview = CompositionReviewGate();
  bool _compositionAdoptedThisSession = false;
  bool _deferRunningPublication = false;

  Future<bool> get _compositionPending async =>
      !_compositionAdoptedThisSession &&
      await preferences.getCompositionRevision() < 1;
  final _listenerScheduler = SerialTaskScheduler();
  _RunRequest? _latestRunRequest;
  DateTime? _startTime;
  _SetupInputs? _appliedInputs;
  var _lastPushDuration = Duration.zero;
  var _pendingForceApply = false;
  List<String> _lostMountSelections = const [];

  /// Groups whose mounted selection the last apply dropped.
  List<String> get lostMountSelections => _lostMountSelections;

  bool get _isRunning => _startTime != null && _startTime!.isBeforeNow;

  @override
  void build() {
    ref.onDispose(_stopRuntimeTicker);
    ref.listen(
      patchClashConfigProvider.select((value) => value.mode),
      (_, _) => _invalidateTrayMode(),
    );
    ref.listen(currentProfileIdProvider, (_, _) => _invalidateTrayMode());
    ref.listen(coreStatusProvider, (_, _) => _invalidateTrayMode());
    ref.listen(appVisibleProvider, (_, _) => _syncRuntimeTicker());
    ref.listen(
      appSettingProvider.select((state) => state.showTrayTitle),
      (_, _) => _syncRuntimeTicker(),
    );
  }

  void _invalidateTrayMode() {
    _trayModeRevision++;
    ref.read(trayModeMenuStateProvider.notifier).set(const TrayModeMenuState());
  }

  bool get _isTrafficShown =>
      ref.read(appVisibleProvider) ||
      (system.isMacOS &&
          !ref.read(safeModeProvider) &&
          ref.read(appSettingProvider).showTrayTitle);

  SetupParams get _setupParams => SetupParams(
    selectedMap: ref.read(selectedMapProvider),
    options: ref.read(coreOptionsProvider),
    tailscale: ref.read(tailscaleSetupProvider),
  );

  // The selection reaches the Core through changeProxy, not through an apply.
  SetupParams get _appliedParams =>
      _setupParams.copyWith(selectedMap: const {});

  Future<bool> fullSetup() async {
    if (!ref.read(initProvider)) return true;
    ref.read(proxiesActionProvider.notifier).cancelDelayTests();
    ref.read(delayDataSourceProvider.notifier).value = {};
    final setupResult = _applyAutomatic(force: true);
    ref.read(logsProvider.notifier).value = FixedList(maxLogsLength);
    ref.read(requestsProvider.notifier).value = FixedList(maxRequestsLength);
    ref.read(dnsQueriesProvider.notifier).value = FixedList(
      maxDnsQueriesLength,
    );
    ref.read(dnsQueryCountProvider.notifier).value = 0;
    ref.read(requestCountProvider.notifier).value = 0;
    try {
      return await setupResult;
    } catch (e, s) {
      commonPrint.log('fullSetup ===> ${compactError(e)}, $s');
      return false;
    }
  }

  void _setLocalRunning(bool running) {
    _deferRunningPublication = false;
    _stopRuntimeTicker();
    ref.read(listeningMixedPortProvider.notifier).value = null;
    if (!running) {
      _startTime = null;
      debouncer.cancel(FunctionTag.applyProfile);
      _pendingForceApply = false;
      _updateRunTime();
      return;
    }

    if (_startTime == null) {
      _systemProxyMark = systemProxyStartCount();
    }
    _startTime ??= DateTime.now();
    _updateRunTime();
    _syncRuntimeTicker();
  }

  void _syncRuntimeTicker() {
    if (_deferRunningPublication) return;
    if (_startTime == null || !_isTrafficShown) {
      _stopRuntimeTicker();
      return;
    }
    if (_runtimeTimer != null) {
      return;
    }
    _refreshRunningState();
    _runtimeTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshRunningState(),
    );
  }

  void _stopRuntimeTicker() {
    _runtimeTimer?.cancel();
    _runtimeTimer = null;
  }

  void _refreshRunningState() {
    if (_deferRunningPublication) return;
    _updateRunTime();
    unawaited(ref.read(commonActionProvider.notifier).updateTraffic());
  }

  void _updateRunTime() {
    final startTime = _startTime;
    ref.read(runTimeProvider.notifier).value = startTime == null
        ? null
        : DateTime.now().millisecondsSinceEpoch -
              startTime.millisecondsSinceEpoch;
  }

  @protected
  Future<DateTime?> serviceStartTime() async => service?.getRunTime();

  Future<void> initStatus() async {
    if (!globalState.needInitStatus) {
      return;
    }
    // Visibility observers must not publish a resumed start during review.
    _deferRunningPublication = true;
    _startTime = await serviceStartTime();
    if (_isRunning) {
      globalState.lastConfigMd5 = await preferences.getAppliedConfigMd5();
      await _run(true, initialize: true, resume: true);
    } else if (ref.read(appSettingProvider).autoRun) {
      await setRunning(true, initialize: true);
    } else {
      await globalState.safeRun(() => _applyAutomatic(force: true));
    }
  }

  @protected
  bool get usesManagedMacHelper => system.isMacOS && macosManagedHelperBuild;

  @protected
  bool get macHelperBusy => macHelperMaintenance.busy;

  @protected
  Future<MacHelperState> checkMacHelper() => macHelperMaintenance.check();

  @protected
  Future<void> presentMacHelper() => showMacHelperFlow();

  int _tunHelperRevision = 0;

  Future<bool> prepareTunEnable(bool enabled) async {
    final revision = ++_tunHelperRevision;
    if (!enabled || !usesManagedMacHelper || ref.read(safeModeProvider)) {
      return true;
    }
    if (macHelperBusy) {
      await presentMacHelper();
      return false;
    }
    final state = await checkMacHelper();
    if (revision != _tunHelperRevision) return false;
    if (state == MacHelperState.enabled) return true;
    await presentMacHelper();
    return false;
  }

  int _helperRunRevision = 0;

  Future<bool> setRunning(bool running, {bool initialize = false}) async {
    final revision = ++_helperRunRevision;
    if (running && !initialize && !ref.read(initProvider)) {
      return true;
    }
    if (running && usesManagedMacHelper && !ref.read(safeModeProvider)) {
      if (macHelperBusy) {
        if (!initialize) await presentMacHelper();
        return false;
      }
      final state = await checkMacHelper();
      if (revision != _helperRunRevision) return false;
      if (state != MacHelperState.enabled) {
        if (!initialize) await presentMacHelper();
        return false;
      }
      if (ref.read(coreStatusProvider) != CoreStatus.connected) {
        await ref.read(coreActionProvider.notifier).startCore();
        if (revision != _helperRunRevision ||
            ref.read(coreStatusProvider) != CoreStatus.connected) {
          return false;
        }
        initialize = true;
      }
    }
    return _run(running, initialize: running && initialize);
  }

  Future<bool> _run(
    bool running, {
    required bool initialize,
    bool resume = false,
  }) {
    final request = _RunRequest(
      running: running,
      initialize: initialize,
      resume: resume,
      previousStartTime: _startTime,
    );
    _latestRunRequest = request;
    if (!running) {
      _setLocalRunning(false);
      return _stop(request);
    }
    _deferRunningPublication = true;
    return _beginStart(request);
  }

  Future<bool> _beginStart(_RunRequest request) async {
    if (await _compositionPending) {
      // Do not publish running/system-DNS state or open listeners while first
      // adoption is being reviewed. A declined resume leaves its service alone.
      final applied = await _runSetup(
        automatic: request.initialize,
        force: !request.resume,
      );
      if (!_isCurrent(request)) return true;
      if (applied != _SetupTaskResult.completed) return false;
      _setLocalRunning(true);
      if (request.initialize) globalState.needInitStatus = false;
      try {
        await _startCoreRunning(request);
      } catch (_) {
        _rollbackRunning(request);
        rethrow;
      }
      return _confirmMixedListener(request);
    }
    if (!_isCurrent(request)) return true;
    _setLocalRunning(true);
    if (request.initialize) globalState.needInitStatus = false;
    return _start(request);
  }

  Future<bool> _start(_RunRequest request) async {
    if (request.initialize) {
      var applied = false;
      try {
        applied = await applyProfile(
          force: !request.resume,
          preloadInvoke: () => _startCoreRunning(request),
        );
      } catch (_) {
        applied = false;
      }
      if (!applied && _isCurrent(request)) {
        await globalState.safeRun(() => setRunning(false));
      }
      return applied && await _confirmMixedListener(request);
    }

    try {
      await _startCoreRunning(request);
    } catch (_) {
      _rollbackRunning(request);
      rethrow;
    }
    if (!await _confirmMixedListener(request)) {
      return false;
    }
    final applied = await inputsApplied();
    if (_isCurrent(request) && !applied) {
      applyProfileDebounce(force: true, silence: true);
    }
    return true;
  }

  Future<bool> _confirmMixedListener(_RunRequest request) async {
    if (!_isCurrent(request)) {
      return true;
    }
    return checkMixedListener();
  }

  /// Ends the run when the Core does not hold the mixed port: mihomo only
  /// logs a bind failure, and the port may belong to another app, so the
  /// system proxy must not point there and the run must not look healthy.
  /// No other port is picked and nothing else is stopped. An unanswered
  /// query leaves the port unconfirmed, which keeps the system proxy off.
  @visibleForTesting
  Future<bool> checkMixedListener({bool Function()? owns}) async {
    if (!(owns?.call() ?? true) || !_mixedListenerExpected) {
      return true;
    }
    final port = ref.read(effectiveMixedPortProvider);
    if (port == 0) {
      return true;
    }
    final int listening;
    try {
      listening = await listeningMixedPort();
    } catch (error) {
      commonPrint.log(
        'mixed listener check failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return true;
    }
    if (!(owns?.call() ?? true) ||
        !_mixedListenerExpected ||
        port != ref.read(effectiveMixedPortProvider)) {
      return true;
    }
    if (listening == port) {
      ref.read(listeningMixedPortProvider.notifier).value = listening;
      return true;
    }
    commonPrint.log(
      'mixed port $port is not held by the Core, stopping',
      logLevel: LogLevel.error,
    );
    await globalState.safeRun(() => setRunning(false));
    // Saying the system proxy was not changed needs proof: an earlier part
    // of this run may have pointed it at Flash, and a restore may not have
    // finished or may have left a service alone.
    final unchanged = await systemProxyUnchangedSince(_systemProxyMark);
    if (!(owns?.call() ?? true)) return false;
    dialogs.showBanner(
      unchanged
          ? currentAppLocalizations.mixedPortUnavailableProxyUnchanged('$port')
          : currentAppLocalizations.mixedPortUnavailable('$port'),
      level: BannerLevel.error,
    );
    return false;
  }

  /// [SystemProxyQueue.startCount] when the current run began.
  int _systemProxyMark = 0;

  @protected
  int systemProxyStartCount() => systemProxyQueue?.startCount ?? 0;

  /// Without a queue Flash never writes the system proxy at all.
  @protected
  Future<bool> systemProxyUnchangedSince(int mark) =>
      systemProxyQueue?.unchangedSince(mark) ?? Future.value(true);

  bool get _mixedListenerExpected =>
      system.isDesktop &&
      !ref.read(safeModeProvider) &&
      ref.read(isStartProvider) &&
      !ref.read(suspendProvider);

  @protected
  Future<int> listeningMixedPort() => _core.getListeningMixedPort();

  @protected
  Future<Map<String, Object?>> listeningPorts() => _core.getListeningPorts();

  /// mihomo only logs an inbound it cannot open, so each one the built
  /// config asks for, besides the mixed port, is checked against the Core.
  /// A port of 0 is an inbound turned off, not one that failed.
  @visibleForTesting
  Future<void> checkInbounds() async {
    if (!_mixedListenerExpected) {
      return;
    }
    final requested = ref.read(builtInboundsProvider);
    final appLocalizations = currentAppLocalizations;
    final noProxyPort =
        ref.read(networkSettingProvider).systemProxy &&
        ref.read(effectiveMixedPortProvider) == 0 &&
        switch (requested['port']) {
          final int port => port == 0,
          _ => true,
        };
    final Map<String, Object?> held;
    try {
      held = await listeningPorts();
    } catch (error) {
      commonPrint.log(
        'inbound check failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      if (noProxyPort) {
        dialogs.showBanner(
          appLocalizations.systemProxyNoPort,
          level: BannerLevel.warning,
        );
      }
      return;
    }
    final labels = {
      PageConfigKey.port: appLocalizations.listenerHttp,
      PageConfigKey.socksPort: appLocalizations.listenerSocks,
      PageConfigKey.redirPort: appLocalizations.listenerRedir,
      PageConfigKey.tproxyPort: appLocalizations.listenerTproxy,
    };
    final messages = [
      for (final MapEntry(:key, value: label) in labels.entries)
        if (requested[key.path] case final int port
            when port != 0 && held[key.path] != port)
          appLocalizations.inboundNotListening(label, '$port'),
      if (requested['tun.enable'] == true &&
          held['tun'] != true &&
          ref.read(authorizedTunEnableProvider) !=
              TunAuthorizationState.authorized)
        appLocalizations.tunMissingAuthorization,
      if (noProxyPort) appLocalizations.systemProxyNoPort,
    ];
    if (messages.isNotEmpty) {
      dialogs.showBanner(messages.join('\n'), level: BannerLevel.warning);
    }
  }

  Future<void> _startCoreRunning(_RunRequest request) async {
    try {
      await _setCoreRunning(request);
    } catch (error) {
      if (_isCurrent(request) || !_isUnanswered(error)) {
        rethrow;
      }
    }
  }

  Future<bool> _stop(_RunRequest request) async {
    (Object, StackTrace)? unanswered;
    try {
      await _setCoreRunning(request);
    } catch (error, stackTrace) {
      if (!_isUnanswered(error)) {
        _rollbackRunning(request);
        rethrow;
      }
      unanswered = (error, stackTrace);
    }
    if (!_isCurrent(request)) {
      return true;
    }
    resetCoreTraffic();
    ref.read(trafficsProvider.notifier).clear();
    ref.read(totalTrafficProvider.notifier).value = const Traffic();
    // A silent Core is gone or hung; running again would proxy traffic to it.
    if (unanswered case (final error, final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    return true;
  }

  Future<void> _setCoreRunning(_RunRequest request) {
    return _listenerScheduler.run(() async {
      if (!_isCurrent(request) ||
          request.running && ref.read(suspendProvider) ||
          ref.read(safeModeProvider)) {
        return;
      }
      await _setListening(request.running);
    });
  }

  Future<void> _setListening(bool running) async {
    ref.read(listeningMixedPortProvider.notifier).value = null;
    final vpnOptions = await ref.read(vpnOptionsProvider.future);
    try {
      await setCoreRunning(running);
    } catch (error) {
      if (_isUnanswered(error)) {
        ref.read(runningVpnOptionsProvider.notifier).value = null;
      }
      rethrow;
    }
    ref.read(runningVpnOptionsProvider.notifier).value = running
        ? vpnOptions
        : null;
  }

  bool _isUnanswered(Object error) =>
      isUnansweredCoreError(error) ||
      error is CoreMethodException && error.code == 'service_refused';

  /// An excluded SSID parks the listener without ending the run.
  void syncSuspend() {
    debouncer.call(FunctionTag.suspend, () {
      return _listenerScheduler.run(() async {
        if (!ref.read(isStartProvider) || ref.read(safeModeProvider)) {
          return;
        }
        final running = !ref.read(suspendProvider);
        try {
          await _setListening(running);
        } catch (error) {
          if (!_isUnanswered(error)) {
            rethrow;
          }
          return;
        }
        if (running) {
          unawaited(checkMixedListener());
        }
      });
    });
  }

  Future<void> restartVpn() async {
    if (!ref.read(isStartProvider)) {
      return;
    }
    await setRunning(false);
    await setRunning(true);
  }

  void _rollbackRunning(_RunRequest request) {
    if (!_isCurrent(request)) {
      return;
    }
    _startTime = request.previousStartTime;
    _setLocalRunning(!request.running);
  }

  bool _isCurrent(_RunRequest request) => identical(_latestRunRequest, request);

  Future<void> updateConfigDebounce() async {
    debouncer.call(FunctionTag.updateConfig, updateConfig);
  }

  @protected
  Future<void> setCoreRunning(bool running) {
    return running ? _core.startListener() : _core.stopListener();
  }

  @protected
  void resetCoreTraffic() {
    _core.resetTraffic();
  }

  @visibleForTesting
  Future<void> updateConfig() async {
    await _updateConfig();
  }

  Future<bool> _updateConfig({
    Mode? trayMode,
    bool Function()? isCurrent,
    VoidCallback? onApplied,
  }) async {
    Future<T?> run<T>(Future<T> Function() operation) async =>
        trayMode == null ? globalState.safeRun(operation) : operation();
    final adoptionPending = await _compositionPending;
    if (!(isCurrent?.call() ?? true)) return false;
    if (adoptionPending) {
      // A patch cannot acknowledge first adoption or bypass the review.
      final result = await run(
        () => _runSetup(
          automatic: true,
          silence: true,
          owns: isCurrent,
          trayMode: trayMode != null,
        ),
      );
      if (trayMode == null || result != _SetupTaskResult.completed) {
        return false;
      }
    }
    var restart = false;
    var applied = false;
    await _setupScheduler.run(
      () => run(() async {
        if (isCurrent != null && !isCurrent()) return;
        final configured = ref.read(patchClashConfigProvider);
        final patchConfig = trayMode == null
            ? configured
            : configured.copyWith(mode: trayMode);
        _effectivePatchConfig(patchConfig);
        final shouldContinueSetup = trayMode == null
            ? await requestAdmin(patchConfig.pageTunEnable)
            : await _requestAdmin(patchConfig.pageTunEnable, owns: isCurrent);
        if (!(isCurrent?.call() ?? true)) return;
        if (!shouldContinueSetup) {
          restart = true;
          return;
        }
        if (patchConfig.pageTunEnable &&
            !ref.read(safeModeProvider) &&
            ref.read(authorizedTunEnableProvider) !=
                TunAuthorizationState.authorized) {
          throw MessageException(
            currentAppLocalizations.tunAuthorizationFailed,
          );
        }
        if (isCurrent != null && !isCurrent()) return;
        final networkSetting = ref.read(networkSettingProvider);
        final effective = _effectivePatchConfig(patchConfig);
        try {
          await _core.updateConfig(
            effective.toUpdateParams(
              authentication: networkSetting.authentication.credentials,
              options: ref.read(coreOptionsProvider),
              layered: true,
            ),
          );
        } catch (error) {
          if (isCurrent != null && !isCurrent()) return;
          final kept =
              error is CoreMethodException &&
              error.code == 'config_rejected' &&
              error.details is Map &&
              (error.details as Map)['outcome'] == 'kept';
          if (!kept) await _forgetConfirmedComposition();
          rethrow;
        }
        if (isCurrent != null && !isCurrent()) return;
        if (ref.read(isStartProvider)) {
          await checkMixedListener(owns: isCurrent);
        }
        if (isCurrent == null || isCurrent()) {
          ref.read(runningFindProcessModeProvider.notifier).value =
              effective.findProcessMode.name;
          onApplied?.call();
          applied = true;
        }
      }),
    );
    if (restart && (isCurrent?.call() ?? true)) {
      await _restartCoreAfterAuthorization();
    }
    return applied;
  }

  @protected
  Duration get trayModeDeadline => const Duration(seconds: 15);

  Future<void> changeModeForTray(Mode mode) async {
    if (ref.read(trayModeMenuStateProvider).pendingMode != null ||
        ref.read(patchClashConfigProvider).mode == mode) {
      return;
    }
    if (!ref.read(isStartProvider)) {
      changeMode(mode);
      return;
    }
    final revision = ++_trayModeRevision;
    final handler = _core;
    bool isCurrent() =>
        ref.mounted &&
        revision == _trayModeRevision &&
        identical(handler, _core);
    final menu = ref.read(trayModeMenuStateProvider.notifier);
    final runningSubscription = ref.listen(
      isStartProvider,
      (_, _) => _invalidateTrayMode(),
    );
    final handlerSubscription = ref.listen(
      coreHandlerProvider,
      (_, _) => _invalidateTrayMode(),
    );
    menu.set(TrayModeMenuState(pendingMode: mode));
    try {
      // Only the UI wait expires; the scheduler retains the actual operation.
      final applied =
          await _updateConfig(
            trayMode: mode,
            isCurrent: isCurrent,
            onApplied: () => _publishMode(mode),
          ).timeout(
            trayModeDeadline,
            onTimeout: () {
              if (isCurrent()) {
                _trayModeRevision++;
                menu.set(
                  TrayModeMenuState(
                    error: currentAppLocalizations.traySwitchUnconfirmed,
                  ),
                );
              }
              return false;
            },
          );
      if (isCurrent()) {
        menu.set(
          TrayModeMenuState(
            error: applied
                ? null
                : currentAppLocalizations.traySwitchUnconfirmed,
          ),
        );
      }
    } catch (error) {
      if (!isCurrent()) return;
      final reason = userFacingErrorMessage(error, currentAppLocalizations);
      menu.set(
        TrayModeMenuState(
          error: [
            error is CoreMethodException &&
                    error.code == 'config_rejected' &&
                    error.details is Map &&
                    (error.details as Map)['outcome'] == 'kept'
                ? currentAppLocalizations.trayCouldNotSwitch
                : currentAppLocalizations.traySwitchUnconfirmed,
            if (reason.isNotEmpty) reason,
          ].join(': '),
        ),
      );
    } finally {
      if (isCurrent()) {
        _trayModeRevision++;
        if (ref.read(trayModeMenuStateProvider).pendingMode != null) {
          menu.set(
            TrayModeMenuState(
              error: currentAppLocalizations.traySwitchUnconfirmed,
            ),
          );
        }
      }
      runningSubscription.close();
      handlerSubscription.close();
    }
  }

  @protected
  Duration get minApplyDebounce => const Duration(seconds: 2);

  /// A push held up by a rule-set download or a Core timeout says little
  /// about the load, yet would hold back every apply after it.
  @protected
  Duration get maxApplyDebounce => const Duration(seconds: 10);

  void applyProfileDebounce({bool silence = false, bool force = false}) {
    _pendingForceApply |= force;
    debouncer.call(
      FunctionTag.applyProfile,
      (silence) {
        final force = _pendingForceApply;
        _pendingForceApply = false;
        _applyAutomatic(silence: silence, force: force);
      },
      args: [silence],
      duration: Duration(
        microseconds: _lastPushDuration.inMicroseconds.clamp(
          minApplyDebounce.inMicroseconds,
          maxApplyDebounce.inMicroseconds,
        ),
      ),
    );
  }

  void changeMode(Mode mode) {
    final supersedesTray =
        ref.read(trayModeMenuStateProvider).pendingMode != null;
    _invalidateTrayMode();
    _publishMode(mode);
    if (supersedesTray) unawaited(updateConfig());
  }

  void _publishMode(Mode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode == Mode.global) {
      ref
          .read(proxiesActionProvider.notifier)
          .updateCurrentGroupName(GroupName.GLOBAL.name);
    }
  }

  /// For leaving an editor: a profile whose inputs match the config the Core
  /// already runs is not rebuilt, which on a large profile takes a while.
  void autoApplyProfile() {
    runAfterFrame(() async {
      if (!await inputsApplied()) {
        await _applyAutomatic();
      }
    });
  }

  void applyIfGlobalRulesUsed() {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || profile.type == ProfileType.custom) {
      return;
    }
    applyProfileDebounce(silence: true);
  }

  /// Whether the Core runs what the current profile and settings make now.
  Future<bool> inputsApplied() async {
    final applied = _appliedInputs;
    if (applied == null) {
      return false;
    }
    final profileId = ref.read(currentProfileIdProvider);
    final SetupState setupState;
    try {
      setupState = await ref.read(setupStateProvider(profileId).future);
    } catch (_) {
      return false;
    }
    return applied ==
        (
          setupState,
          _effectivePatchConfig(ref.read(patchClashConfigProvider)),
          ref.read(networkSettingProvider),
          _appliedParams,
        );
  }

  // Failed builds and cancelled reviews never reach the Core setup step.
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    bool Function()? owns,
    Future<void> Function()? preloadInvoke,
  }) async {
    final result = await _runSetup(
      force: force,
      owns: owns,
      silence: silence,
      preloadInvoke: preloadInvoke,
    );
    return result != _SetupTaskResult.failed;
  }

  Future<bool> _applyAutomatic({
    bool silence = false,
    bool force = false,
  }) async {
    return await _runSetup(automatic: true, silence: silence, force: force) !=
        _SetupTaskResult.failed;
  }

  Future<_SetupTaskResult> _runSetup({
    bool trayMode = false,
    bool automatic = false,
    bool silence = false,
    bool force = false,
    bool Function()? owns,
    Future<void> Function()? preloadInvoke,
  }) async {
    final result = await _setupScheduler.run(() {
      if (!(owns?.call() ?? true)) return Future.value(_SetupTaskResult.failed);
      return _setupConfig(
        trayMode: trayMode,
        owns: owns,
        automatic: automatic,
        force: force,
        silence: silence,
        preloadInvoke: preloadInvoke,
        onUpdated: () async {
          if (ref.exists(tailscaleNodesProvider)) {
            ref.invalidate(tailscaleNodesProvider);
          }
          await ref.read(proxiesActionProvider.notifier).updateGroups();
          await ref.read(providersProvider.notifier).syncProviders();
        },
      );
    });
    if (!(owns?.call() ?? true)) return _SetupTaskResult.failed;
    if (result != _SetupTaskResult.handoffToCoreRestart) {
      return result;
    }
    // Release the current serial task before restartCore reapplies the profile.
    final restarted = await _restartCoreAfterAuthorization();
    return restarted ? _SetupTaskResult.completed : _SetupTaskResult.failed;
  }

  Future<bool> _restartCoreAfterAuthorization() async {
    try {
      return await ref.read(coreActionProvider.notifier).restartCore();
    } catch (_) {
      ref.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.none;
      rethrow;
    }
  }

  /// With a base, [BuiltProfile.yaml] is only the overlay the Core applies.
  Future<BuiltProfile> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    final profileId = setupState.profileId;
    if (profileId == null) {
      final yaml = await encodeYamlTask(
        inboundConfigOf(
          patchConfig,
          authentication: ref
              .read(networkSettingProvider)
              .authentication
              .credentials,
        ),
      );
      return (
        yaml: yaml,
        md5: yaml.toMd5(),
        counts: configCountsOf(const {}),
        base: null,
      );
    }
    final defaultUA = globalState.packageInfo.ua;
    final networkSetting = ref.read(
      networkSettingProvider.select(
        (state) => (
          appendSystemDns: state.appendSystemDns,
          bypassPrivateRoute: state.bypassPrivateRoute,
          authentication: state.authentication,
        ),
      ),
    );
    final appendSystemDns = networkSetting.appendSystemDns;
    final isCustom = setupState.profileType == ProfileType.custom;
    final scriptContent = isCustom ? null : await setupState.script?.content;
    final hasScript = scriptContent?.isNotEmpty == true;
    final profileBase = !isCustom && !hasScript
        ? await _core.getProfileBase(profileId)
        : null;
    Map<String, dynamic> rawConfig = isCustom
        ? {
            'proxies': appProxiesPayload(
              setupState.appProxies,
              dialers: setupState.proxyDialers,
              groups: setupState.proxyGroups,
            ),
          }
        : profileBase?.base.config ?? await _core.readConfig(profileId);
    final proxyGroups = isCustom ? setupState.proxyGroups : <ProxyGroup>[];
    final rules = isCustom ? setupState.rules : <Rule>[];
    if (hasScript) {
      rawConfig = await handleEvaluate(scriptContent!, rawConfig);
    }
    if (profileId == ref.read(currentProfileIdProvider)) {
      ref.read(profileSettingsProvider.notifier).value = Map.of(rawConfig);
    }
    if (!patchConfig.usesPage(
          PageConfigKey.externalController,
          layered: true,
        ) &&
        !ref.read(safeModeProvider) &&
        exposesControllerWithoutSecret(rawConfig)) {
      throw MessageException(
        currentAppLocalizations.controllerExposedWithoutSecret(
          controllerHostPort('${rawConfig['external-controller']}'),
        ),
      );
    }
    final directory = await appPath.profilesPath;
    final injected = await _resolveInjectedProviders(
      setupState,
      proxyGroups: proxyGroups,
      rules: rules,
    );
    final res = await makeRealProfileTask(
      MakeRealProfileState(
        rules: rules,
        proxyGroups: proxyGroups,
        injectedProxyProviders: injected.proxies,
        injectedRuleProviders: injected.rules,
        profilesPath: directory,
        profileId: profileId,
        rawConfig: rawConfig,
        realPatchConfig: patchConfig,
        overrides: setupState.overrides,
        bypassPrivateRoute: networkSetting.bypassPrivateRoute,
        appendSystemDns: appendSystemDns,
        // sing-tun points the system resolver at the TUN by default with
        // auto-route everywhere but macOS, where native does it through a
        // dynamic store entry that configd drops when the Core exits.
        defaultTunDnsMode: system.isMacOS ? 'native' : null,
        addedRules: setupState.addedRules,
        defaultUA: defaultUA,
        authentication: networkSetting.authentication.credentials,
        matchTarget:
            profileBase == null ||
                setupState.matchTarget?.trim().isNotEmpty == true
            ? setupState.matchTarget
            : lastMatchTarget(profileBase.base.matchRules),
        safeMode: ref.read(safeModeProvider),
        mitmModules: setupState.mitmModules,
      ),
    );
    if (profileBase == null) {
      return (yaml: res.yaml, md5: res.md5, counts: res.counts, base: null);
    }
    final (:base, :path) = profileBase;
    return (
      yaml: res.yaml,
      md5: '${res.md5}${base.digest}'.toMd5(),
      counts: (
        groups: res.counts.groups + base.proxyGroups,
        proxies: res.counts.proxies + base.proxies,
        rules: res.counts.rules + base.rules,
      ),
      base: SetupBase(path: path, overlay: res.yaml),
    );
  }

  /// Only what the custom profile actually references is injected, so an
  /// app-level provider costs nothing in the profiles that never name it.
  Future<({Map<String, dynamic> proxies, Map<String, dynamic> rules})>
  _resolveInjectedProviders(
    SetupState setupState, {
    required List<ProxyGroup> proxyGroups,
    required List<Rule> rules,
  }) async {
    final usedProxyProviders = <String>{
      for (final proxyGroup in proxyGroups) ...?proxyGroup.use,
    };
    final usedRuleProviders = <String>{
      for (final rule in rules) ...rule.ruleSets,
      if (setupState.profileType == ProfileType.custom)
        ...setupState.overrides.ruleSets,
    };
    if (usedProxyProviders.isEmpty && usedRuleProviders.isEmpty) {
      return (
        proxies: const <String, dynamic>{},
        rules: const <String, dynamic>{},
      );
    }
    final options = setupState.overrides.proxyProviders;
    final proxies = <String, dynamic>{};
    for (final entry in setupState.profileProviders.entries) {
      if (!usedProxyProviders.contains(entry.key)) {
        continue;
      }
      proxies[entry.key] = {
        'type': 'file',
        'path': await appPath.getProfilePath(entry.value.toString()),
        ...?options[entry.key]?.definition,
      };
    }
    final clashProvidersAction = ref.read(
      clashProvidersActionProvider.notifier,
    );
    final ruleProviders = <String, dynamic>{};
    for (final provider in setupState.clashProviders) {
      if (!usedRuleProviders.contains(provider.label)) {
        continue;
      }
      final prepared = await clashProvidersAction.prepare(provider);
      ruleProviders[prepared.label] = prepared.definition(
        await prepared.corePath,
      );
    }
    return (proxies: proxies, rules: ruleProviders);
  }

  Future<String> getProfileWithId(int profileId) async {
    try {
      final setupState = await ref.read(setupStateProvider(profileId).future);
      final res = await getProfile(
        setupState: setupState,
        patchConfig: _effectivePatchConfig(ref.read(patchClashConfigProvider)),
      );
      // The viewer shows what the Core runs, so the mounts go in as they
      // do on apply.
      final mounts = setupState.mounts;
      if (mounts == null) {
        return await _annotateTailscale(profileId, switch (res.base) {
          final base? => await _core.buildProfile(base: base),
          null => res.yaml,
        });
      }
      final String yaml;
      try {
        yaml = switch (res.base) {
          final base? => await _core.buildProfile(base: base, mounts: mounts),
          null => await _core.buildProfile(config: res.yaml, mounts: mounts),
        };
      } catch (e) {
        // A failed mount check still leaves the profile itself to show.
        dialogs.showBanner(e.toString(), level: BannerLevel.error);
        return await _annotateTailscale(profileId, switch (res.base) {
          final base? => await _core.buildProfile(base: base),
          null => res.yaml,
        });
      }
      MountRuntimeState? runtime;
      try {
        runtime = await _core.getMountState();
      } catch (error) {
        commonPrint.log(
          'mount state unread: ${compactError(error)}',
          logLevel: coreFailureLogLevel(error),
        );
      }
      return await _annotateTailscale(
        profileId,
        annotateMountProviders(yaml, mounts, runtime, currentAppLocalizations),
      );
    } catch (e) {
      dialogs.showBanner(e.toString(), level: BannerLevel.error);
    }
    return '';
  }

  /// Always asks the Core, so a profile without Flash's rules says so too.
  Future<String> _annotateTailscale(int profileId, String yaml) async {
    final setup = ref.read(tailscaleSetupProvider);
    TailscaleRuntimeRules runtime;
    try {
      runtime = await _core.getTailscaleRuntimeRules(profileId);
    } catch (error) {
      commonPrint.log(
        'tailscale runtime rules unread: ${compactError(error)}',
        logLevel: coreFailureLogLevel(error),
      );
      runtime = TailscaleRuntimeRules.readFailed(profileId);
    }
    TailscaleExitReport exit;
    try {
      exit = await _core.getTailscaleExit(profileId);
    } catch (error) {
      commonPrint.log(
        'tailscale exit group unread: ${compactError(error)}',
        logLevel: coreFailureLogLevel(error),
      );
      exit = TailscaleExitReport.readFailed(profileId);
    }
    return annotateTailscaleExit(
      annotateTailscaleRuntime(yaml, runtime, setup, currentAppLocalizations),
      exit,
      currentAppLocalizations,
    );
  }

  /// Keeps the profile on the names the Core followed, unless changed since.
  Future<void> _followMountSelections(
    int targetId,
    Map<String, String> sent,
  ) async {
    final MountRuntimeState state;
    try {
      state = await _core.getMountState();
    } catch (error) {
      commonPrint.log(
        'mount selections unread: ${compactError(error)}',
        logLevel: coreFailureLogLevel(error),
      );
      return;
    }
    final profile = ref.read(profilesProvider).getProfile(targetId);
    if (profile == null ||
        state.report?.target != targetId ||
        state.moved.isEmpty && state.lost.isEmpty) {
      return;
    }
    final selectedMap = Map<String, String>.from(profile.selectedMap);
    for (final MapEntry(key: group, value: name) in state.moved.entries) {
      if (selectedMap[group] == sent[group]) selectedMap[group] = name;
    }
    for (final group in state.lost) {
      if (selectedMap[group] == sent[group]) selectedMap.remove(group);
    }
    ref
        .read(profilesProvider.notifier)
        .put(profile.copyWith(selectedMap: selectedMap));
    _lostMountSelections = state.lost;
  }

  /// Display only: never use this projection for preflight or apply.
  Future<({SetupBase? base, String? config})> mountTargetProjectionInput(
    int profileId,
  ) async {
    final profile = ref.read(profileProvider(profileId));
    if (profile == null) throw StateError('Mount target is unavailable');
    if (profile.type != ProfileType.custom) {
      if (profile.scriptId != null) {
        throw StateError('Mount groups are unavailable for a script profile');
      }
      return (
        base: SetupBase(
          path: await appPath.getProfilePath(profileId.toString()),
          overlay: '{}',
        ),
        config: null,
      );
    }
    final groups = await database.proxyGroupsDao.query(profileId).get();
    final proxies = await database.customProxiesDao.query().get();
    final dialers = {
      for (final dialer
          in await database.proxyDialersDao.query(profileId).get())
        dialer.proxyId: dialer.target,
    };
    final used = {for (final group in groups) ...?group.use};
    final providers = <String, dynamic>{};
    for (final entry in ref.read(profileProvidersProvider).entries) {
      if (!used.contains(entry.key)) continue;
      providers[entry.key] = {
        'type': 'file',
        'path': await appPath.getProfilePath(entry.value.toString()),
        ...?profile.overrides.proxyProviders[entry.key]?.definition,
      };
    }
    final config = await compute(_mountProjectionConfig, (
      groups: groups,
      proxies: proxies,
      dialers: dialers,
      providers: providers,
    ));
    return (base: null, config: config);
  }

  /// The complete candidate used by mount preflight, never a display projection.
  Future<({SetupBase? base, String? config})> mountTargetInput(
    int profileId,
  ) async {
    final setupState = await ref.read(setupStateProvider(profileId).future);
    final built = await getProfile(
      setupState: setupState,
      patchConfig: _effectivePatchConfig(ref.read(patchClashConfigProvider)),
    );
    return switch (built.base) {
      final base? => (base: base, config: null),
      null => (base: null, config: built.yaml),
    };
  }

  PatchClashConfig _effectivePatchConfig(
    PatchClashConfig patchConfig, {
    bool preserveRequestedTun = false,
  }) {
    if (ref.read(safeModeProvider)) {
      return patchConfig.copyWith(
        tun: patchConfig.tun.copyWith(enable: false),
        externalController: ExternalControllerStatus.close,
      );
    }
    if (patchConfig.externalController != ExternalControllerStatus.close &&
        patchConfig.secret.isEmpty) {
      throw StateError('External controller requires authentication');
    }
    final authorized =
        ref.read(authorizedTunEnableProvider) ==
        TunAuthorizationState.authorized;
    return patchConfig.copyWith(
      tun: patchConfig.tun.copyWith(
        enable: patchConfig.tun.enable && (preserveRequestedTun || authorized),
      ),
    );
  }

  @protected
  Future<AuthorizeCode> authorizeCore() {
    return system.authorizeCore();
  }

  @visibleForTesting
  Future<bool> requestAdmin(bool enableTun) => _requestAdmin(enableTun);

  Future<bool> _requestAdmin(bool enableTun, {bool Function()? owns}) async {
    if (!(owns?.call() ?? true)) return false;
    if (!enableTun || ref.read(safeModeProvider)) {
      return true;
    }
    if (usesManagedMacHelper) {
      final state = await checkMacHelper();
      if (!(owns?.call() ?? true)) return false;
      if (state != MacHelperState.enabled) {
        throw MessageException(
          currentAppLocalizations.macHelperUnavailableDetail,
        );
      }
      ref.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.authorized;
      return true;
    }
    final authorizationState = ref.read(authorizedTunEnableProvider);
    if (authorizationState != TunAuthorizationState.none) {
      return true;
    }

    final authorizationNotifier = ref.read(
      authorizedTunEnableProvider.notifier,
    );
    if (owns == null) {
      authorizationNotifier.value = TunAuthorizationState.unauthorized;
    }

    final code = await authorizeCore();
    if (!(owns?.call() ?? true)) return false;

    switch (code) {
      case AuthorizeCode.success:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return false;
      case AuthorizeCode.none:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return true;
      case AuthorizeCode.error:
        authorizationNotifier.value = TunAuthorizationState.none;
        dialogs.showBanner(
          currentAppLocalizations.tunAuthorizationFailed,
          level: BannerLevel.error,
        );
        return true;
    }
  }

  /// An empty profile list is left alone: it is the first-run state, and it is
  /// what the profile stream holds before its first emission.
  @visibleForTesting
  Profile? recoverMissingProfile() {
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return null;
    final profiles = ref.read(profilesProvider);
    if (profiles.isEmpty) return null;
    final fallback = profiles.first;
    commonPrint.log(
      'profile $profileId is missing, falling back to ${fallback.id}',
      logLevel: LogLevel.warning,
    );
    ref.read(currentProfileIdProvider.notifier).value = fallback.id;
    return fallback;
  }

  Future<void> _forgetConfirmedComposition({
    bool defaultRuntime = false,
  }) async {
    _appliedInputs = null;
    ref.read(runningFindProcessModeProvider.notifier).value = null;
    globalState.lastConfigMd5 = null;
    globalState.lastConfigCounts = defaultRuntime
        ? configCountsOf(const {})
        : null;
    if (system.isAndroid) await preferences.saveAppliedConfigMd5(null);
  }

  Future<_CompositionCandidate> _readCompositionCandidate() async {
    final profile = ref.read(currentProfileProvider) ?? recoverMissingProfile();
    if (profile == null) throw StateError('No saved profile to review');
    final state = await ref.read(setupStateProvider(profile.id).future);
    final patch = _effectivePatchConfig(
      ref.read(patchClashConfigProvider),
      preserveRequestedTun: true,
    );
    final network = ref.read(networkSettingProvider);
    final params = _setupParams.copyWith(mounts: state.mounts);
    final built = await getProfile(setupState: state, patchConfig: patch);
    final source = compositionReviewValues(
      ref.read(profileSettingsProvider) ?? const {},
    );
    // Normal-profile YAML is only an overlay, never a complete candidate.
    final materialized = await _core.buildProfile(
      base: built.base,
      config: built.base == null ? built.yaml : null,
      mounts: state.mounts,
    );
    final decoded = materialized.trim().isEmpty ? null : loadYaml(materialized);
    if (decoded is! Map) {
      throw StateError('Empty or unreadable composition candidate');
    }
    final fingerprint = json.encode([
      profile.id,
      state.hashCode,
      built.md5,
      materialized,
      patch.toJson(),
      network.toJson(),
      params.toJson(),
      ref.read(safeModeProvider),
    ]).toMd5();
    return (
      profile: profile,
      state: state,
      patch: patch,
      network: network,
      params: params,
      built: built,
      materialized: materialized,
      fingerprint: fingerprint,
      basePaths: {
        if (state.profileType != ProfileType.custom && state.script == null)
          for (final entry in compositionReviewValues(decoded).entries)
            if (source.containsKey(entry.key) &&
                json.encode(source[entry.key]) == json.encode(entry.value))
              entry.key,
      },
    );
  }

  /// The existing setup scheduler owns this gate, including live-patch entry.
  /// Source refresh is deliberately excluded until first adoption completes.
  Future<_CompositionCandidate?> _reviewComposition() =>
      _reviewOwnedComposition();

  Future<_CompositionCandidate?> _reviewOwnedComposition({
    bool Function()? owns,
  }) async {
    try {
      var candidate = await _readCompositionCandidate();
      for (var attempts = 0; attempts < 3; attempts++) {
        if (!(owns?.call() ?? true)) return null;
        if (_compositionReview.approves(candidate.fingerprint)) {
          return candidate;
        }
        final approved = await reviewComposition(
          candidate.materialized,
          basePaths: candidate.basePaths,
          pagePaths: {
            ...PageConfigKey.values.map((key) => key.path),
            ...candidate.patch.geoXUrl.raw.keys.map((key) => 'geox-url.$key'),
            'secret',
            'interface-name',
            ...GeneralOverrideKey.values
                .where((key) => key != GeneralOverrideKey.testUrl)
                .map((key) => key.path),
            ...DnsOverrideKey.normalProfileKeys.map((key) => 'dns.${key.path}'),
            ...candidate.state.overrides.dnsOverrideKeys.map(
              (key) => 'dns.${key.path}',
            ),
            ...candidate.state.overrides.ntpOverrideKeys.map(
              (key) => 'ntp.${key.path}',
            ),
            ...candidate.state.overrides.snifferOverrideKeys.map(
              (key) => 'sniffer.${key.path}',
            ),
            ...candidate.state.overrides.tunOverrideKeys.map(
              (key) => 'tun.${key.path}',
            ),
            ...TunOverrideKey.values
                .where(
                  (key) => switch (key) {
                    TunOverrideKey.strictRoute =>
                      Platform.isLinux || Platform.isWindows,
                    TunOverrideKey.gso ||
                    TunOverrideKey.includeInterface ||
                    TunOverrideKey.excludeInterface ||
                    TunOverrideKey.includeUid ||
                    TunOverrideKey.excludeUid ||
                    TunOverrideKey.excludeSrcPort ||
                    TunOverrideKey.excludeDstPort => Platform.isLinux,
                    _ => true,
                  },
                )
                .map((key) => 'tun.${key.path}'),
            if (Platform.isLinux) 'routing-mark',
          },
        );
        if (!(owns?.call() ?? true)) return null;
        if (!approved) {
          _compositionReview.cancel();
          return null;
        }
        final checked = await _readCompositionCandidate();
        if (!(owns?.call() ?? true)) return null;
        if (checked.fingerprint == candidate.fingerprint) {
          _compositionReview.approve(candidate.fingerprint);
          return checked;
        }
        // Apply to a stale preview is not consent to new settings/source.
        candidate = checked;
      }
      throw StateError('Configuration kept changing during review');
    } catch (error) {
      if (!(owns?.call() ?? true)) return null;
      commonPrint.log(
        'composition review preparation failed (${error.runtimeType})',
      );
      dialogs.showBanner(
        currentAppLocalizations.compositionReadFailed,
        level: BannerLevel.error,
      );
      return null;
    }
  }

  @protected
  Future<bool> reviewComposition(
    String yaml, {
    required Set<String> pagePaths,
    required Set<String> basePaths,
  }) async {
    final strings = currentAppLocalizations;
    final values = compositionReviewValues(loadYaml(yaml) as Map);
    return await dialogs.showMessage(
          title: strings.compositionReviewTitle,
          confirmText: strings.applyAction,
          cancelText: strings.cancel,
          dismissible: false,
          width: 640,
          body: SizedBox(
            width: 640,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Text(strings.compositionBaselineUnknown),
                  Text(strings.compositionCandidateNote),
                  for (final entry in values.entries)
                    Text(
                      '${entry.key}: ${json.encode(entry.value)} · '
                      '${pagePaths.contains(entry.key)
                          ? strings.sourcePage
                          : basePaths.contains(entry.key)
                          ? strings.sourceBase
                          : strings.compositionSourceUnconfirmed}',
                    ),
                ],
              ),
            ),
          ),
        ) ==
        true;
  }

  Future<_SetupTaskResult> _setupConfig({
    bool trayMode = false,
    bool automatic = false,
    bool force = false,
    bool Function()? owns,
    bool silence = false,
    Future<void> Function()? preloadInvoke,
    FutureOr Function()? onUpdated,
  }) async {
    if (!(owns?.call() ?? true)) return _SetupTaskResult.failed;
    final adoptionPending = await _compositionPending;
    if (!(owns?.call() ?? true)) return _SetupTaskResult.failed;
    if (adoptionPending &&
        _compositionReview.suppressed(automatic: automatic)) {
      return _SetupTaskResult.failed;
    }
    final adoption = adoptionPending
        ? owns == null
              ? await _reviewComposition()
              : await _reviewOwnedComposition(owns: owns)
        : null;
    if (!(owns?.call() ?? true) || (adoptionPending && adoption == null)) {
      return _SetupTaskResult.failed;
    }
    _lostMountSelections = const [];
    var profile =
        adoption?.profile ??
        ref.read(currentProfileProvider) ??
        recoverMissingProfile();
    final sourceIdentity = profile;
    bool sourceCurrent() {
      final latest = ref.read(currentProfileProvider);
      return (owns?.call() ?? true) &&
          ref.read(currentProfileIdProvider) == sourceIdentity?.id &&
          latest?.id == sourceIdentity?.id &&
          latest?.type == sourceIdentity?.type &&
          latest?.url == sourceIdentity?.url &&
          latest?.ageSecretKey == sourceIdentity?.ageSecretKey;
    }

    // A refresh failure is surfaced by safeRun; setup keeps the old profile.
    final nextProfile = adoptionPending
        ? null
        : await globalState.safeRun(() async {
            final current = profile;
            if (current == null) {
              return null;
            }
            return ref
                .read(profilesActionProvider.notifier)
                .ensureSource(current);
          });
    if (nextProfile != null) {
      final committed = ref
          .read(profilesActionProvider.notifier)
          .commitSourceUpdate(nextProfile);
      if (committed == null) return _SetupTaskResult.failed;
      profile = committed;
    }
    if (!sourceCurrent()) return _SetupTaskResult.failed;
    profile = ref.read(currentProfileProvider);
    commonPrint.log('setup ===> ${profile?.realLabel}');
    final patchConfig = ref.read(patchClashConfigProvider);
    _effectivePatchConfig(patchConfig);
    final shouldContinueSetup = trayMode
        ? await _requestAdmin(patchConfig.pageTunEnable, owns: owns)
        : await requestAdmin(patchConfig.pageTunEnable);
    if (!(owns?.call() ?? true)) return _SetupTaskResult.failed;
    if (!shouldContinueSetup) return _SetupTaskResult.handoffToCoreRestart;
    if (!sourceCurrent()) return _SetupTaskResult.failed;
    if (patchConfig.pageTunEnable &&
        !ref.read(safeModeProvider) &&
        ref.read(authorizedTunEnableProvider) !=
            TunAuthorizationState.authorized) {
      return _SetupTaskResult.failed;
    }
    final pushWatch = Stopwatch()..start();
    final realPatchConfig = _effectivePatchConfig(patchConfig);
    final networkSetting = ref.read(networkSettingProvider);
    SetupState? setupState = adoption?.state;
    final realProfile =
        adoption?.built ??
        await globalState.safeRun(() async {
          final state = await ref.read(setupStateProvider(profile?.id).future);
          if (!sourceCurrent()) throw StateError('Profile setup superseded');
          setupState = state;
          return getProfile(setupState: state, patchConfig: realPatchConfig);
        }, title: 'build profile');
    final profileFailed = realProfile == null;
    if (profileFailed || !sourceCurrent()) {
      return _SetupTaskResult.failed;
    }
    var setupParams = _setupParams.copyWith(
      base: realProfile.base,
      mounts: setupState?.mounts,
    );
    final inputs = switch (setupState) {
      final state? when !profileFailed => (
        state,
        realPatchConfig,
        networkSetting,
        _appliedParams,
      ),
      _ => null,
    };
    final yamlString = realProfile.yaml;
    // The panel-added accounts are not in the YAML, yet change what runs.
    final managed = setupParams.tailscale?.managed ?? const [];
    final mountRevision = setupParams.mounts?.revision ?? '';
    final yamlMd5 = (managed.isEmpty && mountRevision.isEmpty)
        ? realProfile.md5
        : '${realProfile.md5}${json.encode(managed)}$mountRevision'.toMd5();
    if (!adoptionPending && yamlMd5 == globalState.lastConfigMd5 && !force) {
      _appliedInputs = inputs;
      ref.read(builtInboundsProvider.notifier).value = builtInboundsOf(
        realProfile.yaml,
      );
      globalState.lastConfigCounts = realProfile.counts;
      ref.read(runningFindProcessModeProvider.notifier).value =
          builtFindProcessModeOf(yamlString);
      await preloadInvoke?.call();
      return _SetupTaskResult.completed;
    }
    // Confirmed metadata stays unchanged until the full setup acknowledges.
    // The Core owns candidate validation and running-file commit.
    if (system.isAndroid) {
      await ref.read(vpnOptionsProvider.future);
      await preferences.saveShareState(ref.read(sharedStateProvider));
    }
    // Recaptured so _start's catch can roll back after safeRun swallows it.
    (Object, StackTrace)? handoffFailure;
    var setupFailed = false;
    await globalState.loadingRun(
      () async {
        Directory? stagedDirectory;
        var releaseCandidate = true;
        var rpcStarted = false;
        var definitelyKept = false;
        var defaultRuntime = false;
        try {
          if (setupParams.base == null) {
            // The agreed full-candidate contract clears only overlay rules:
            // bulk and rules come from this private source, settings from overlay.
            // createTemp gives each attempt a nonshared, private directory.
            // Ambiguous RPCs retain it: Core may still be reading that path.
            stagedDirectory = await Directory(
              await appPath.homeDirPath,
            ).createTemp('.composition-');
            final stagedSource = File(
              join(stagedDirectory.path, 'candidate.yaml'),
            );
            await stagedSource.writeAsStringAtomically(yamlString);
            final overlay = Map<String, dynamic>.from(
              loadYaml(yamlString) as Map,
            );
            overlay['rules'] = <String>[];
            final settingsYaml = await encodeYamlTask(overlay);
            setupParams = setupParams.copyWith(
              base: SetupBase(path: stagedSource.path, overlay: settingsYaml),
            );
          }
          final profileId = profile?.id;
          if (profileId != null) {
            // A Core that ran elevated may have left these root-owned; it
            // reclaims them once it runs elevated again, so the config goes on.
            try {
              await appPath.ensureProviderDirs(profileId);
            } on FileSystemException catch (error) {
              commonPrint.log(
                'provider directories unavailable: ${compactError(error)}',
                logLevel: LogLevel.warning,
              );
            }
          }
          try {
            if (adoption != null &&
                (await _readCompositionCandidate()).fingerprint !=
                    adoption.fingerprint) {
              throw StateError('Reviewed configuration changed; review again');
            }
            if (!sourceCurrent()) {
              throw StateError('Profile setup superseded');
            }
            rpcStarted = true;
            releaseCandidate = false;
            await _core.setupConfig(
              params: setupParams,
              preloadInvoke: preloadInvoke,
            );
            releaseCandidate = true;
            if (!(owns?.call() ?? true)) {
              setupFailed = true;
              return;
            }
            if (adoptionPending) {
              if (_deferRunningPublication && _isRunning) {
                _deferRunningPublication = false;
                _updateRunTime();
                _syncRuntimeTicker();
              }
            }
          } on CoreMethodException catch (error) {
            if (!(owns?.call() ?? true)) {
              setupFailed = true;
              return;
            }
            final configOutcome =
                error.code == 'config_rejected' && error.details is Map
                ? (error.details as Map)['outcome']
                : null;
            if (error.code == 'config_rejected' ||
                error.code == 'mount_rejected') {
              releaseCandidate = true;
            }
            definitelyKept = configOutcome == 'kept';
            defaultRuntime = configOutcome == 'default';
            final outcome = mountRejectedOutcome(error);
            if (outcome == MountRejectedOutcome.kept) {
              definitelyKept = true;
              throw MessageException(currentAppLocalizations.mountApplyKept);
            }
            if (error.code != 'config_rejected' && outcome == null) {
              rethrow;
            }
            if (outcome == MountRejectedOutcome.blocked) {
              defaultRuntime = true;
              await _forgetConfirmedComposition(defaultRuntime: true);
              await globalState.safeRun(() => onUpdated?.call());
            }
            throw MessageException(
              outcome == MountRejectedOutcome.blocked
                  ? currentAppLocalizations.mountApplyBlocked
                  : error.message,
            );
          }
        } catch (e, s) {
          setupFailed = true;
          if (!(owns?.call() ?? true)) return;
          if (rpcStarted && !definitelyKept) {
            await _forgetConfirmedComposition(defaultRuntime: defaultRuntime);
          }
          if (preloadInvoke != null) {
            handoffFailure = (e, s);
          }
          rethrow;
        } finally {
          if (releaseCandidate) {
            try {
              await stagedDirectory?.safeDelete(recursive: true);
            } catch (_) {
              // The Core acknowledgement must survive local cleanup failure.
              commonPrint.log('composition candidate cleanup failed');
            }
          }
        }
        if (!(owns?.call() ?? true)) {
          setupFailed = true;
          return;
        }
        ref.read(builtInboundsProvider.notifier).value = builtInboundsOf(
          realProfile.yaml,
        );
        globalState.lastConfigMd5 = yamlMd5;
        ref.read(runningFindProcessModeProvider.notifier).value =
            builtFindProcessModeOf(yamlString);
        ref.read(appliedFollowKeysProvider.notifier).value = const {};
        globalState.lastConfigCounts = realProfile.counts;
        _appliedInputs = inputs;
        if (system.isAndroid) {
          await preferences.saveAppliedConfigMd5(yamlMd5);
        }
        if (adoptionPending) {
          // The runtime acknowledgement is real even if recording the one-time
          // revision fails. Do not convert that into a claimed apply rollback.
          _compositionAdoptedThisSession = true;
          var recorded = false;
          try {
            recorded = await preferences.saveCompositionRevision();
          } catch (_) {
            // Report separately; confirmed runtime metadata is already committed.
          }
          if (!recorded) {
            dialogs.showBanner(
              currentAppLocalizations.compositionRecordFailed,
              level: BannerLevel.error,
            );
          }
        }
        if (setupParams.mounts case final mounts?) {
          await _followMountSelections(mounts.target, setupParams.selectedMap);
        }
        await onUpdated?.call();
      },
      silence: true,
      tag: !silence ? LoadingTag.proxies : null,
    );
    _lastPushDuration = pushWatch.elapsed;
    if (handoffFailure != null) {
      Error.throwWithStackTrace(handoffFailure!.$1, handoffFailure!.$2);
    }
    if (setupFailed || profileFailed) {
      return _SetupTaskResult.failed;
    }
    if (ref.mounted && ref.read(isStartProvider)) {
      unawaited(checkMixedListener().then((_) => checkInbounds()));
    }
    return _SetupTaskResult.completed;
  }
}
