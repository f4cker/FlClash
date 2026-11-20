part of '../action.dart';

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  bool _isUpdatingTraffic = false;
  CancelToken? _updateCancelToken;
  _MacStagedUpdate? _macStaged;
  MacUpdateManifest? _macActiveManifest;
  int _updateCheckRevision = 0;
  bool _isInstallingUpdate = false;
  bool _trayUpdateReserved = false;

  @override
  void build() {
    ref.listen(appSettingProvider.select((s) => s.receiveBetaUpdates), (
      previous,
      next,
    ) {
      if (!system.isMacOS || previous == next) return;
      ++_updateCheckRevision;
      ref.read(lastUpdateCheckStateProvider.notifier).value = null;
      if (!next) {
        if (ref.read(availableUpdateStateProvider)?.manifest?.channel ==
            ReleaseChannel.beta) {
          ref.read(availableUpdateStateProvider.notifier).value = null;
        }
        if ((_macActiveManifest ?? _macStaged?.manifest)?.channel ==
                ReleaseChannel.beta &&
            !ref.read(updateInstallCommittedProvider)) {
          _updateCancelToken?.cancel();
          _macStaged = null;
          ref.read(updateDownloadStateProvider.notifier).value = null;
          unawaited(macUpdater?.invalidate());
        }
      }
    });
  }

  bool get _allowBeta => ref.read(appSettingProvider).receiveBetaUpdates;

  bool _manifestAllowed(MacUpdateManifest manifest) {
    final identity = ref.read(installedMacReleaseProvider).value;
    final build =
        identity?.build ?? macBuildNumber(globalState.packageInfo.buildNumber);
    final version =
        identity?.version ??
        (build != null && build <= macLegacyBuildCeiling
            ? globalState.packageInfo.version
            : null);
    return build != null &&
        version != null &&
        macUpdateEligible(
          manifest,
          installedBuild: build,
          installedVersion: version,
          allowBeta: _allowBeta,
        );
  }

  void toggleRunning() => unawaited(_toggleRunning());

  Future<void> _toggleRunning() async {
    final running = !ref.read(isStartProvider);
    if (running && ref.read(coreStatusProvider) == CoreStatus.disconnected) {
      ref.read(setupActionProvider.notifier).resumeOnRestart();
      await globalState.safeRun(
        ref.read(coreActionProvider.notifier).restartCore,
      );
      return;
    }
    await globalState.safeRun(
      () => ref
          .read(setupActionProvider.notifier)
          .setRunning(running, initialize: running && !ref.read(initProvider)),
    );
  }

  Future<void> toggleRunningForTray() async {
    final pending = ref.read(trayCoreTogglePendingProvider.notifier);
    if (pending.value ||
        ref.read(coreStatusProvider) == CoreStatus.connecting) {
      return;
    }
    pending.value = true;
    try {
      final core = ref.read(coreActionProvider.notifier);
      await globalState.safeRun(() async {
        if (ref.read(coreStatusProvider) == CoreStatus.connected) {
          await core.stopCore();
        } else {
          ref.read(setupActionProvider.notifier).resumeOnRestart();
          await core.restartCore();
        }
      });
    } finally {
      pending.value = false;
    }
  }

  void updateSpeedStatistics() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: !state.showTrayTitle));
  }

  void updateMonochromeTrayIcon() {
    ref
        .read(appSettingProvider.notifier)
        .update(
          (state) =>
              state.copyWith(monochromeTrayIcon: !state.monochromeTrayIcon),
        );
  }

  void updateMode() {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = Mode.values.indexWhere((item) => item == state.mode);
      if (index == -1) return state;
      final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
      return state.copyWith(mode: Mode.values[nextIndex]);
    });
  }

  Future<void> updateTraffic() async {
    if (_isUpdatingTraffic) {
      return;
    }
    _isUpdatingTraffic = true;
    try {
      final onlyStatisticsProxy = ref.read(
        appSettingProvider.select((state) => state.onlyStatisticsProxy),
      );
      final [traffic, totalTraffic] = await Future.wait([
        _readTraffic(() => _core.getTraffic(onlyStatisticsProxy)),
        _readTraffic(() => _core.getTotalTraffic(onlyStatisticsProxy)),
      ]);
      if (traffic != null) {
        ref.read(trafficsProvider.notifier).addTraffic(traffic);
      }
      if (totalTraffic != null) {
        ref.read(totalTrafficProvider.notifier).value = totalTraffic;
      }
    } finally {
      _isUpdatingTraffic = false;
    }
  }

  Future<Traffic?> _readTraffic(Future<Traffic> Function() request) async {
    try {
      return await request();
    } catch (error) {
      commonPrint.log(
        'updateTraffic error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  Future<bool> autoCheckUpdate() async {
    if (!ref.read(appSettingProvider).autoCheckUpdate) return false;
    final result = await checkForAppUpdate();
    await checkUpdateResultHandle(result);
    return result is UpdateAvailable;
  }

  /// macOS reads the signed manifest and compares build numbers; elsewhere
  /// the latest GitHub release and its version are compared.
  Future<UpdateCheck> checkForAppUpdate() async {
    final revision = ++_updateCheckRevision;
    final allowBeta = _allowBeta;
    final identity = system.isMacOS
        ? await ref.read(installedMacReleaseProvider.future)
        : null;
    final installedBuild =
        identity?.build ?? macBuildNumber(globalState.packageInfo.buildNumber);
    final installedVersion =
        identity?.version ??
        (installedBuild != null && installedBuild <= macLegacyBuildCeiling
            ? globalState.packageInfo.version
            : null);
    var result = system.isMacOS
        ? await ref
              .read(appUpdateRequestProvider)
              .checkForMacUpdate(
                installedBuild: installedBuild,
                installedVersion: installedVersion,
                allowBeta: allowBeta,
                arch: macUpdateArch(Abi.current()),
              )
        : await request.checkForUpdate(
            version: globalState.packageInfo.version,
            assetSuffix: releaseAssetSuffix,
          );
    if (revision != _updateCheckRevision ||
        (system.isMacOS && allowBeta != _allowBeta)) {
      return const UpdateCheckSuperseded();
    }
    final previous = ref.read(availableUpdateStateProvider);
    final previousManifest = previous?.manifest;
    if (result is UpdateAvailable &&
        result.discoveryIncomplete &&
        previousManifest != null &&
        _manifestAllowed(previousManifest) &&
        previousManifest.build > (result.manifest?.build ?? 0)) {
      result = UpdateAvailable(
        previous!.release,
        manifest: previousManifest,
        discoveryIncomplete: true,
      );
    }
    if (revision == _updateCheckRevision) {
      ref.read(lastUpdateCheckStateProvider.notifier).value = result;
      if (result is! UpdateCheckFailed) {
        ref.read(availableUpdateStateProvider.notifier).value =
            result is UpdateAvailable ? result : null;
      }
    }
    return result;
  }

  Future<void> updateFromTray(UpdateAvailable expected) async {
    final busy = ref.read(updateInstallBusyProvider.notifier);
    if (busy.value ||
        _isInstallingUpdate ||
        ref.read(updateDownloadStateProvider) is UpdateDownloading ||
        !identical(ref.read(availableUpdateStateProvider), expected)) {
      return;
    }
    _trayUpdateReserved = true;
    busy.value = true;
    try {
      final result = await checkForAppUpdate();
      if (result is! UpdateAvailable) {
        await checkUpdateResultHandle(result, isUser: true);
        return;
      }
      final manifest = result.manifest;
      final previous = expected.manifest;
      if (manifest == null ||
          previous == null ||
          !listEquals(manifest.envelope, previous.envelope) ||
          !identical(ref.read(availableUpdateStateProvider), result)) {
        return;
      }
      final asset = manifest.assetFor(macUpdateArch(Abi.current()) ?? '');
      if (asset == null ||
          _isInstallingUpdate ||
          ref.read(updateDownloadStateProvider) is UpdateDownloading) {
        return;
      }
      await discardUpdate();
      await _downloadMacUpdate(manifest, asset, installWhenReady: true);
    } finally {
      _trayUpdateReserved = false;
      busy.value = _isInstallingUpdate;
    }
  }

  String get _currentVersionLabel => appVersionLabel(
    ref.read(installedMacReleaseProvider).value?.version ??
        globalState.packageInfo.version,
    globalState.packageInfo.buildNumber,
  );

  TextSpan _updateVersions(String available, {bool beta = false}) {
    final l10n = currentAppLocalizations;
    String summary(String current, String available) =>
        l10n.updateVersionSummary(
          current,
          beta ? '$available · ${l10n.releaseBeta}' : available,
        );
    final context = globalState.navigatorKey.currentContext;
    final InlineSpan versions = context == null
        ? TextSpan(
            text: summary(
              displayVersionLabel(_currentVersionLabel),
              displayVersionLabel(available),
            ),
          )
        : versionMessageSpan(
            (slots) => summary(slots[0], slots[1]),
            [_currentVersionLabel, available],
            buildStyle: AppTextStyle.caption1
                .of(context)
                .copyWith(color: _dialogMessageColor(context.colorScheme)),
          );
    return TextSpan(
      children: [
        versions,
        const TextSpan(text: '\n\n'),
      ],
    );
  }

  // The message colour prism_ui's Dialog sets on its body text.
  static Color _dialogMessageColor(ColorScheme colorScheme) => colorScheme
      .onSurfaceVariant
      .withValues(alpha: colorScheme.brightness == Brightness.dark ? 1 : 0.85);

  TextSpan _releaseSpan(BuildContext context, String tagName, String? body) {
    return TextSpan(
      text: '$tagName \n',
      style: AppTextStyle.title2.of(context),
      children: releaseNotesSpans(context, body),
    );
  }

  /// Only a manual check reports that it found nothing to install.
  Future<void> checkUpdateResultHandle(
    UpdateCheck result, {
    bool isUser = false,
  }) async {
    if (result is UpdateCheckSuperseded) return;
    if (result case UpdateAvailable(:final MacUpdateManifest manifest)) {
      if (!_manifestAllowed(manifest)) return;
      await _offerMacUpdate(manifest, isUser: isUser);
    } else if (result case UpdateAvailable(release: final data)) {
      final context = globalState.navigatorKey.currentContext!;
      final tag = data['tag_name'] as String;
      final asset = selfUpdateAsset;
      final res = await dialogs.showMessage(
        title: currentAppLocalizations.discoverNewVersion,
        message: TextSpan(
          children: [
            _updateVersions(result.versionLabel),
            _releaseSpan(context, tag, data['body'] as String?),
          ],
        ),
        confirmText: asset == null
            ? currentAppLocalizations.goDownload
            : currentAppLocalizations.update,
        cancelText: isUser ? null : currentAppLocalizations.noLongerRemind,
      );
      if (res == true) {
        if (asset == null) {
          _openReleasePage();
        } else {
          unawaited(_downloadUpdate(tag, updateAssetName(tag, asset)));
        }
      } else if (!isUser && res == false) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoCheckUpdate: false));
      }
    } else if (isUser) {
      final message = switch (result) {
        UpdateNoRelease() => currentAppLocalizations.updateNoReleaseFound,
        UpdateCheckFailed(
          error: MacUpdateManifestException(
            reason: MacUpdateRejection.notConfigured,
          ),
        ) =>
          currentAppLocalizations.macUpdateNotConfigured,
        UpdateCheckFailed() => currentAppLocalizations.updateCheckFailed,
        UpdateUpToDate()
            when system.isMacOS &&
                !_allowBeta &&
                ref.read(installedMacReleaseProvider).value?.channel ==
                    ReleaseChannel.beta =>
          currentAppLocalizations.updateNoNewerStable,
        UpdateCheckSuperseded() ||
        UpdateUpToDate() ||
        UpdateAvailable() => currentAppLocalizations.checkUpdateError,
      };
      unawaited(
        dialogs.showAlert(
          title: currentAppLocalizations.checkUpdate,
          message: TextSpan(text: message),
        ),
      );
    }
  }

  void _openReleasePage() {
    unawaited(
      launchUrl(
        Uri.parse(
          system.isMacOS
              ? macUpdateReleasesPage
              : 'https://github.com/$updateRepository/releases/latest',
        ),
      ),
    );
  }

  String _macVersionLabel(MacUpdateManifest manifest) =>
      '${displayVersionLabel(manifest.fullVersion)}${manifest.channel == ReleaseChannel.beta ? ' · ${currentAppLocalizations.releaseBeta}' : ''}';

  TextSpan _macUpdateVersions(MacUpdateManifest manifest) => _updateVersions(
    manifest.fullVersion,
    beta: manifest.channel == ReleaseChannel.beta,
  );

  Future<void> _offerMacUpdate(
    MacUpdateManifest manifest, {
    required bool isUser,
  }) async {
    if (!_manifestAllowed(manifest)) return;
    final showDetails = await dialogs.showMessage(
      title: currentAppLocalizations.discoverNewVersion,
      message: _macUpdateVersions(manifest),
      confirmText: currentAppLocalizations.viewUpdate,
      cancelText: isUser ? null : currentAppLocalizations.noLongerRemind,
    );
    if (showDetails != true) {
      if (!isUser && showDetails == false) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoCheckUpdate: false));
      }
      return;
    }
    final context = globalState.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final asset = manifest.assetFor(macUpdateArch(Abi.current()) ?? '')!;
    final res = await dialogs.showMessage(
      title: currentAppLocalizations.discoverNewVersion,
      message: TextSpan(
        children: [
          _macUpdateVersions(manifest),
          _releaseSpan(context, manifest.tag, manifest.notes),
          TextSpan(
            text:
                '\n${currentAppLocalizations.macUpdateSize(asset.size.traffic.show)}',
            style: AppTextStyle.subheadline.of(context),
          ),
        ],
      ),
      confirmText: currentAppLocalizations.macUpdateDownloadAndInstall,
      cancelText: isUser ? null : currentAppLocalizations.noLongerRemind,
    );
    if (res == true) {
      unawaited(_downloadMacUpdate(manifest, asset));
    } else if (!isUser && res == false) {
      ref
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(autoCheckUpdate: false));
    }
  }

  Future<void> _downloadMacUpdate(
    MacUpdateManifest manifest,
    MacUpdateAsset asset, {
    bool installWhenReady = false,
  }) async {
    final updater = macUpdater;
    final download = ref.read(updateDownloadStateProvider.notifier);
    if (updater == null ||
        download.value != null ||
        _updateCancelToken != null ||
        !_manifestAllowed(manifest)) {
      return;
    }
    _macActiveManifest = manifest;
    final cancelToken = CancelToken();
    _updateCancelToken = cancelToken;
    _macStaged = null;
    final tag = manifest.tag;
    download.value = UpdateDownloading(tag, total: asset.size);
    dialogs.showBanner(currentAppLocalizations.updateDownloadStarted);
    try {
      final directory = await appPath.updateDirPath;
      await clearUpdateDownloads();
      await Directory(directory).create(recursive: true);
      var shown = 0;
      final path = await request.downloadMacUpdate(
        asset: asset,
        directory: directory,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (cancelToken.isCancelled || !_manifestAllowed(manifest)) return;
          if (received - shown < total / 100 && received != total) return;
          shown = received;
          download.value = UpdateDownloading(
            tag,
            received: received,
            total: total,
          );
        },
      );
      if (cancelToken.isCancelled || !_manifestAllowed(manifest)) {
        cancelToken.cancel();
        throw cancelToken.cancelError!;
      }
      final prepared = await updater.prepare(
        manifest: manifest.envelope,
        archive: path,
        allowBeta: _allowBeta,
      );
      if (cancelToken.isCancelled || !_manifestAllowed(manifest)) {
        cancelToken.cancel();
        throw cancelToken.cancelError!;
      }
      if (prepared.needsManualInstall) {
        download.value = null;
        await _revealMacUpdate(updater, path, manifest.version, prepared);
        return;
      }
      if (!prepared.ok || prepared.staged == null || prepared.ticket == null) {
        throw _MacUpdateFailure(prepared);
      }
      _macStaged = _MacStagedUpdate(
        manifest,
        prepared.staged!,
        path,
        prepared.ticket!,
      );
      download.value = UpdateReady(tag, path);
      if (installWhenReady) {
        await _installUpdate(fromTray: true);
        return;
      }
      dialogs.showBanner(
        currentAppLocalizations.updateReadyTip,
        level: BannerLevel.success,
        onTap: () => unawaited(installUpdate()),
      );
      final res = await dialogs.showMessage(
        title: currentAppLocalizations.macUpdateReadyTitle,
        message: TextSpan(
          text: macUpdateReadyText(
            prepared,
            _macVersionLabel(manifest),
            currentAppLocalizations,
          ),
        ),
        confirmText: currentAppLocalizations.macUpdateRestartNow,
        cancelText: currentAppLocalizations.macUpdateLater,
      );
      if (res == true) await installUpdate();
    } catch (error) {
      download.value = null;
      _macStaged = null;
      await clearUpdateDownloads();
      unawaited(updater.cleanup());
      if (error is DioException && CancelToken.isCancel(error)) {
        return;
      }
      commonPrint.log(
        'Update download failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      await _showUpdateFailure(
        error is _MacUpdateFailure
            ? macUpdateMessage(error.result, currentAppLocalizations)
            : userFacingErrorMessage(error, currentAppLocalizations),
        details: error is _MacUpdateFailure ? error.result.details : null,
      );
    } finally {
      if (identical(_updateCancelToken, cancelToken)) {
        _updateCancelToken = null;
        _macActiveManifest = null;
      }
    }
  }

  Future<void> _revealMacUpdate(
    MacUpdater updater,
    String archive,
    String version,
    MacUpdateResult reason,
  ) async {
    final shown = await updater.reveal(archive: archive, version: version);
    commonPrint.log(
      'Update shown in Finder (${reason.code}): ${shown.code} ${shown.detail}',
      logLevel: LogLevel.warning,
    );
    if (!shown.ok) {
      await _showUpdateFailure(currentAppLocalizations.updateInstallFailed);
      return;
    }
    await dialogs.showAlert(
      title: currentAppLocalizations.checkUpdate,
      message: TextSpan(
        text: macUpdateMessage(reason, currentAppLocalizations),
      ),
    );
  }

  /// Stops the Core first: once the bundle changes, the helper no longer
  /// accepts this (old) app's requests, a stop request included.
  Future<void> _installMacUpdate(UpdateReady download) async {
    final staged = _macStaged;
    final updater = macUpdater;
    if (staged == null ||
        updater == null ||
        staged.archive != download.path ||
        !_manifestAllowed(staged.manifest)) {
      return;
    }
    dialogs.showBanner(currentAppLocalizations.macUpdateInstalling);
    try {
      await _core.stop();
    } catch (error) {
      commonPrint.log(
        'Core stop before update failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      await _restartAfterFailedMacUpdate();
      await _showUpdateFailure(
        currentAppLocalizations.macUpdateCoreStopFailed,
        details: compactError(error),
      );
      return;
    }
    if (!_manifestAllowed(staged.manifest) ||
        !identical(_macStaged, staged) ||
        !identical(ref.read(updateDownloadStateProvider), download) ||
        _updateCancelToken?.isCancelled == true) {
      await _restartAfterFailedMacUpdate();
      return;
    }
    ref.read(updateInstallCommittedProvider.notifier).value = true;
    final result = await updater.install(
      staged.path,
      ticket: staged.ticket,
      allowBeta: _allowBeta,
    );
    if (result.ok) {
      _macStaged = null;
      ref.read(updateDownloadStateProvider.notifier).value = null;
      ref.read(availableUpdateStateProvider.notifier).value = null;
      await updater.relaunchAfterExit();
      await ref.read(systemActionProvider.notifier).handleExit();
      return;
    }
    commonPrint.log(
      'Update install failed: ${result.code} ${result.detail}',
      logLevel: LogLevel.warning,
    );
    _macStaged = null;
    ref.read(updateDownloadStateProvider.notifier).value = null;
    await _restartAfterFailedMacUpdate();
    if (result.needsManualInstall) {
      await _revealMacUpdate(
        updater,
        staged.archive,
        staged.manifest.version,
        result,
      );
    } else {
      await _showUpdateFailure(
        macUpdateMessage(result, currentAppLocalizations),
        details: result.details,
      );
    }
    if (result.code != 'rollbackFailed') {
      await clearUpdateDownloads();
      unawaited(updater.cleanup());
    }
  }

  Future<void> _restartAfterFailedMacUpdate() async {
    await ref.read(coreActionProvider.notifier).restartCore();
  }

  /// Downloads the latest release for this build even when it is not newer.
  Future<void> testUpdateDownload() async {
    final asset = selfUpdateAsset;
    if (asset == null || ref.read(updateDownloadStateProvider) != null) {
      return;
    }
    final release = await globalState.loadingRun(
      request.latestRelease,
      title: currentAppLocalizations.updateDownloadTest,
      tag: LoadingTag.checkUpdate,
    );
    if (release == null) return;
    final tag = release['tag_name'] as String;
    await _downloadUpdate(tag, updateAssetName(tag, asset));
  }

  Future<void> _downloadUpdate(String tag, String name) async {
    final download = ref.read(updateDownloadStateProvider.notifier);
    if (download.value != null) return;
    final cancelToken = CancelToken();
    _updateCancelToken = cancelToken;
    download.value = UpdateDownloading(tag);
    dialogs.showBanner(currentAppLocalizations.updateDownloadStarted);
    try {
      final directory = await appPath.updateDirPath;
      await clearUpdateDownloads();
      await Directory(directory).create(recursive: true);
      var shown = 0;
      final path = await request.downloadVerifiedRelease(
        tag: tag,
        name: name,
        directory: directory,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          // Every chunk would otherwise rebuild the status on its own frame.
          final step = total > 0 ? total / 100 : 1 << 20;
          if (received - shown < step && received != total) return;
          shown = received;
          download.value = UpdateDownloading(
            tag,
            received: received,
            total: total,
          );
        },
      );
      download.value = UpdateReady(tag, path);
      dialogs.showBanner(
        currentAppLocalizations.updateReadyTip,
        level: BannerLevel.success,
        onTap: () => unawaited(installUpdate()),
      );
    } catch (error) {
      download.value = null;
      await clearUpdateDownloads();
      if (error is DioException && CancelToken.isCancel(error)) {
        return;
      }
      commonPrint.log(
        'Update download failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      await _showUpdateFailure(
        userFacingErrorMessage(error, currentAppLocalizations),
      );
    } finally {
      if (identical(_updateCancelToken, cancelToken)) {
        _updateCancelToken = null;
      }
    }
  }

  void cancelUpdateDownload() {
    _updateCancelToken?.cancel();
  }

  Future<void> discardUpdate() async {
    if (ref.read(updateInstallCommittedProvider) ||
        ref.read(updateDownloadStateProvider) is! UpdateReady) {
      return;
    }
    _updateCancelToken?.cancel();
    _macStaged = null;
    ref.read(updateDownloadStateProvider.notifier).value = null;
    unawaited(macUpdater?.invalidate());
    await clearUpdateDownloads();
  }

  Future<void> installUpdate() => _installUpdate();

  Future<void> _installUpdate({bool fromTray = false}) async {
    final download = ref.read(updateDownloadStateProvider);
    if (download is! UpdateReady ||
        _isInstallingUpdate ||
        (_trayUpdateReserved && !fromTray)) {
      return;
    }
    _isInstallingUpdate = true;
    final busy = ref.read(updateInstallBusyProvider.notifier);
    busy.value = true;
    try {
      if (system.isMacOS) {
        await _installMacUpdate(download);
        return;
      }
      ref.read(updateInstallCommittedProvider.notifier).value = true;
      if (system.isAndroid) {
        ref.read(updateDownloadStateProvider.notifier).value = null;
        final status = await app?.installPackage(download.path);
        await clearUpdateDownloads();
        if (status != null && packageInstallFailed(status)) {
          await _showUpdateFailure(currentAppLocalizations.updateInstallFailed);
        }
        return;
      }
      final started = windows?.runas(
        download.path,
        windowsUpdateArguments(pid),
      );
      if (started == true) {
        await ref.read(systemActionProvider.notifier).handleExit();
      } else if (started == false) {
        await _showUpdateFailure(currentAppLocalizations.updateInstallFailed);
      }
    } finally {
      ref.read(updateInstallCommittedProvider.notifier).value = false;
      _isInstallingUpdate = false;
      busy.value = _trayUpdateReserved;
    }
  }

  /// [details] (codes, paths, what failed) stays folded under a Details
  /// toggle below the message.
  Future<void> _showUpdateFailure(String message, {String? details}) async {
    final res = await dialogs.showMessage(
      title: currentAppLocalizations.updateFailed,
      message: TextSpan(text: message),
      body: details == null || details.isEmpty
          ? null
          : UpdateFailureBody(message: message, details: details),
      confirmText: currentAppLocalizations.goDownload,
    );
    if (res == true) {
      _openReleasePage();
    }
  }
}

final class _MacStagedUpdate {
  final MacUpdateManifest manifest;
  final String path;
  final String archive;

  final String ticket;

  const _MacStagedUpdate(this.manifest, this.path, this.archive, this.ticket);
}

final class _MacUpdateFailure implements Exception {
  final MacUpdateResult result;

  const _MacUpdateFailure(this.result);

  @override
  String toString() => 'MacUpdateFailure(${result.code}): ${result.detail}';
}
