part of '../action.dart';

@Riverpod(keepAlive: true)
class SystemAction extends _$SystemAction {
  static const localIpUpdateKey = 'local-ip';

  CoreController get _core => ref.read(coreHandlerProvider);

  SystemExitCoordinator? _exitCoordinator;
  int _localIpRequest = 0;

  @override
  void build() {}

  Future<List<Package>> getPackages() async {
    final packages = await app?.getPackages() ?? [];
    if (!listEquals(packages, ref.read(packagesProvider))) {
      ref.read(packagesProvider.notifier).value = packages;
    }
    return ref.read(packagesProvider);
  }

  Future<List<String>> getChinaPackageNames() async {
    return await app?.getChinaPackageNames() ?? [];
  }

  Future<bool> isInstalledAppsPermissionGranted() async {
    return await app?.isInstalledAppsPermissionGranted() ?? true;
  }

  Future<bool> requestInstalledAppsPermission() async {
    return await app?.requestInstalledAppsPermission() ?? false;
  }

  Future<void> handleExit([bool needSave = true]) {
    final coordinator = _exitCoordinator ??= SystemExitCoordinator(
      watchdogDuration: exitWatchdogDuration,
      closeWindow: closeWindow,
      closeCore: closeCore,
      exitApplication: exitApplication,
    );
    return coordinator.exit(cleanup: () => cleanupExitResources(needSave));
  }

  @protected
  Duration get exitWatchdogDuration => const Duration(seconds: 3);

  @protected
  Future<void> cleanupExitResources(bool needSave) async {
    final saveOperation = needSave ? _savePreferencesSafely() : null;
    // The relay may outlive the app for a while: the Core signs nothing
    // more once this replies.
    if (mitmFeature && ref.read(patchClashConfigProvider).mitm.coreCa != null) {
      await ref.read(mitmCoreCaProvider.notifier).stopSigning();
    }
    final tray = trayPort;
    if (tray != null) {
      await tray.shutdown().onError<Object>((error, stackTrace) {
        commonPrint.log(
          'Tray shutdown failed: ${compactError(error)}',
          logLevel: LogLevel.error,
        );
      });
    }
    await Future.wait([
      ?saveOperation,
      bootGuard.markClosed(),
      ?systemProxyQueue?.close(),
    ]);
  }

  Future<void> _savePreferencesSafely() async {
    try {
      await savePreferences();
    } catch (error) {
      commonPrint.log(
        'Preferences save failed: ${compactError(error)}',
        logLevel: LogLevel.error,
      );
    }
  }

  @protected
  Future<void> savePreferences() async {
    final port = windowPort;
    if (port != null) {
      try {
        final current = ref.read(windowSettingProvider);
        final geometry = await port.captureNormalGeometry(current);
        if (geometry != null) {
          ref.read(windowSettingProvider.notifier).value = geometry;
        }
      } catch (error) {
        commonPrint.log(
          'Window geometry capture failed: ${compactError(error)}',
          logLevel: LogLevel.warning,
        );
      }
    }
    await preferences.saveConfig(ref.read(configProvider));
  }

  @protected
  Future<void> closeWindow() async {
    await windowPort?.close();
  }

  @protected
  Future<void> closeCore() async {
    await _core.close();
    commonPrint.log('exit');
  }

  @protected
  Future<void> exitApplication() async {
    await system.exit();
    windowPort?.forceExit();
  }

  Future<void> handleClose([bool exit = true]) async {
    if (ref.read(appSettingProvider).minimizeOnExit || !exit) {
      if (system.isDesktop) {
        await _savePreferencesSafely();
      }
      await system.back();
      await windowPort?.hide();
    } else {
      await handleExit();
    }
  }

  Future<void> updateVisible() async {
    await windowPort?.toggle();
  }

  void updateTun() async {
    final enabled = !ref.read(patchClashConfigProvider).tun.enable;
    if (system.isMacOS &&
        macosManagedHelperBuild &&
        !await ref
            .read(setupActionProvider.notifier)
            .prepareTunEnable(enabled)) {
      return;
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.tun(enable: enabled));
  }

  /// Turns decryption on or off the way its settings switch does, for the
  /// page and the tray alike: turning it on asks first and makes the
  /// certificate when there is none; turning it off does not ask. True once
  /// saved.
  Future<bool> setMitmEnabled(
    bool value, {
    AppLocalizations? localizations,
  }) async {
    final config = ref.read(patchClashConfigProvider.notifier);
    if (value) {
      final appLocalizations = localizations ?? currentAppLocalizations;
      final ca = ref.read(mitmCaProvider.notifier);
      final hasCertificate = ref.read(mitmCaProvider).value != null;
      final res = await dialogs.showMessage(
        title: appLocalizations.httpsDecryption,
        message: TextSpan(text: appLocalizations.mitmEnableTip),
      );
      if (res != true) {
        return false;
      }
      if (!hasCertificate) {
        final generated = await globalState.loadingRun<bool>(
          () async {
            await ca.generate();
            return true;
          },
          tag: LoadingTag.mitm,
          title: appLocalizations.generateCertificate,
        );
        if (generated != true) {
          return false;
        }
      }
    }
    config.update(
      (state) => state.copyWith(mitm: state.mitm.copyWith(enable: value)),
    );
    return true;
  }

  /// Saves whether request content is recorded, the way its settings switch
  /// does: only while decryption is on. The choice outlives turning
  /// decryption off.
  bool setMitmCapture(bool value) {
    if (!ref.read(patchClashConfigProvider).mitm.enable) {
      return false;
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(mitm: state.mitm.copyWith(capture: value)),
        );
    return true;
  }

  /// The tray's decryption switch. It goes the settings switch's way
  /// ([setMitmEnabled]), never around it: without a trusted certificate it
  /// does not turn on and opens the settings instead, and turning on brings
  /// the settings forward for the switch's own question. Clicks while one
  /// is in flight are ignored; the menu shows the saved setting throughout.
  Future<void> toggleMitmForTray() async {
    final pending = ref.read(trayMitmPendingProvider.notifier);
    if (pending.value != null) {
      return;
    }
    final mitm = ref.read(patchClashConfigProvider).mitm;
    final enable = !mitm.enable;
    if (enable && mitm.trustedFingerprint == null) {
      await mitmSettingsPort?.call();
      return;
    }
    pending.value = TrayMitmToggle.mitm;
    try {
      if (enable) {
        await mitmSettingsPort?.call();
      }
      await globalState.safeRun(() => setMitmEnabled(enable));
    } finally {
      if (ref.mounted) pending.value = null;
    }
  }

  /// The tray's recording switch: the settings switch's write, only while
  /// decryption is on; otherwise it opens the settings.
  Future<void> toggleMitmCaptureForTray() async {
    final pending = ref.read(trayMitmPendingProvider.notifier);
    if (pending.value != null) {
      return;
    }
    final mitm = ref.read(patchClashConfigProvider).mitm;
    if (!mitm.enable) {
      await mitmSettingsPort?.call();
      return;
    }
    pending.value = TrayMitmToggle.capture;
    try {
      await globalState.safeRun(() => setMitmCapture(!mitm.capture));
    } finally {
      if (ref.mounted) pending.value = null;
    }
  }

  void updateSystemProxy() {
    ref
        .read(networkSettingProvider.notifier)
        .update((state) => state.copyWith(systemProxy: !state.systemProxy));
  }

  Future<void> copyProxyEnv() async {
    final port = ref.read(effectiveMixedPortProvider);
    await Clipboard.setData(
      ClipboardData(text: proxyEnvCommand(port, isWindows: system.isWindows)),
    );
  }

  void updateAutoLaunch() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(autoLaunch: !state.autoLaunch));
  }

  Future<void> updateTray() async {
    await trayPort?.update(
      trayState: ref.read(trayStateProvider),
      traffic: ref.read(
        trafficsProvider.select(
          (state) => state.list.safeLast(const Traffic()),
        ),
      ),
      read: globalState.container.read,
    );
  }

  Future<void> updateLocalIp() async {
    final request = ++_localIpRequest;
    final updating = ref.read(updatingKeysProvider.notifier);
    final operation = updating.start(localIpUpdateKey);
    try {
      String address;
      try {
        address = await getLocalIpAddress() ?? '';
      } catch (error) {
        commonPrint.log('Local IP lookup failed: ${compactError(error)}');
        address = '';
      }
      if (ref.mounted && request == _localIpRequest) {
        ref.read(localIpProvider.notifier).value = address;
      }
    } finally {
      if (ref.mounted) {
        updating.stop(localIpUpdateKey, operation);
      }
    }
  }
}
