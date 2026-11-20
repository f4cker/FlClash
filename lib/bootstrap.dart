import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/boot_guard.dart';
import 'package:fl_clash/common/boot_record.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/launch.dart';
import 'package:fl_clash/common/migration.dart';
import 'package:fl_clash/common/restore_journal.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/mac_updater.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm_status.dart';
import 'package:fl_clash/views/disclaimer.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Bootstrap {
  static Bootstrap? _instance;

  Bootstrap._internal();

  factory Bootstrap() {
    _instance ??= Bootstrap._internal();
    return _instance!;
  }

  BootDecision _bootDecision = const BootDecision();
  Object? _resetMixedPort;

  Future<ProviderContainer> init(int version) async {
    globalState.appEnv = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'pre',
    );
    windowPort = window;
    trayPort = appTray;
    navigationPort = navigation;
    mitmSettingsPort = openMitmSettingsFromTray;
    final dynamicColor = await _initDynamicColor();
    return _initData(version, dynamicColor);
  }

  Future<DynamicColorSeeds> _initDynamicColor() async {
    ({Color light, Color dark})? systemSeeds;
    Color? accentColor;
    try {
      systemSeeds = await DynamicColorPlugin.getSystemSeeds();
    } catch (error) {
      commonPrint.log(
        'Failed to get core palette: $error',
        logLevel: LogLevel.warning,
      );
    }
    try {
      accentColor = await DynamicColorPlugin.getAccentColor();
    } catch (error) {
      commonPrint.log(
        'Failed to get accent color: $error',
        logLevel: LogLevel.warning,
      );
    }
    return (
      lightSeed: systemSeeds?.light,
      darkSeed: systemSeeds?.dark,
      accentColor: accentColor ?? const Color(defaultPrimaryColor),
    );
  }

  /// Runs before migration and the database: a copy started from another
  /// install path gets past the platform's single-instance hand-off.
  Future<void> _claimDataDirectory() async {
    if (!system.isDesktop || await singleInstanceLock.acquire()) {
      return;
    }
    commonPrint.log('another instance owns the data directory, exiting');
    exit(0);
  }

  Future<ProviderContainer> _initData(
    int version,
    DynamicColorSeeds dynamicColor,
  ) async {
    await _claimDataDirectory();
    globalState.packageInfo = await PackageInfo.fromPlatform();
    // Before the settings are read: a restore that committed may still owe
    // them, and one that did not must take its files back first.
    await _recoverInterruptedRestore();
    final storedConfig = await preferences.getConfigMap();
    _resetMixedPort = unusableMixedPort(storedConfig?['patchClashConfig']);
    var config = await migration.run();
    if (_resetMixedPort != null) {
      await preferences.saveConfig(config);
    }
    _bootDecision = await bootGuard.evaluate(
      profileId: config.currentProfileId,
    );
    if (_bootDecision.recovery == BootRecovery.clearProfile) {
      config = config.copyWith(currentProfileId: null);
      await preferences.saveConfig(config);
    }
    final patchClashConfig = config.patchClashConfig.ensureControllerSecret();
    if (patchClashConfig != config.patchClashConfig) {
      config = config.copyWith(patchClashConfig: patchClashConfig);
      await preferences.saveConfig(config);
    }
    final appState = AppState(
      brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
      version: version,
      viewSize: Size.zero,
      requests: FixedList(maxRequestsLength),
      logs: FixedList(maxLogsLength),
      traffics: FixedList(trafficSampleLength),
      totalTraffic: const Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    final appStateOverrides = buildAppStateOverrides(appState);
    final configOverrides = buildConfigOverrides(config);
    final tailscaleNodeRecords = await preferences.getTailscaleNodeRecords();
    final tailscaleLegacyMigration = await preferences
        .getTailscaleLegacyMigration();
    final tailscaleManagedRecords = await preferences
        .getTailscaleManagedRecords();
    final container = ProviderContainer(
      overrides: [
        ...appStateOverrides,
        ...configOverrides,
        tailscaleNodeRecordsProvider.overrideWithBuild(
          (_, _) => tailscaleNodeRecords,
        ),
        tailscaleLegacyMigratedProvider.overrideWithBuild(
          (_, _) => tailscaleLegacyMigration,
        ),
        tailscaleManagedRecordsProvider.overrideWithBuild(
          (_, _) => tailscaleManagedRecords,
        ),
      ],
    );
    globalState.container = container;
    container
        .read(dynamicColorProvider.notifier)
        .seed(
          lightSeed: dynamicColor.lightSeed,
          darkSeed: dynamicColor.darkSeed,
          accentColor: dynamicColor.accentColor,
        );
    final profiles = await database.profilesDao.query().get();
    container.read(profilesProvider.notifier).reorder(profiles);
    loadAppLocalizations(
      getLocaleForString(config.appSettingProps.locale) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );
    await window?.init(version, config.windowProps);
    if (system.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    return container;
  }

  Future<void> attach() async {
    if (globalState.isAttach == true) {
      return;
    }
    await _initApp();
    globalState.isAttach = true;
  }

  ProviderContainer get _container => globalState.container;

  Future<void> _initApp() async {
    await restoreRecovery.completeAtStartup(
      mitm: () =>
          _container.read(mitmModulesActionProvider.notifier).recheckRestored(),
      startBackgroundWork: _startBackgroundWork,
      show: (report) => dialogs.showAlert(
        title: currentAppLocalizations.tip,
        message: TextSpan(
          text: restoreRecoveryMessage(report, currentAppLocalizations),
        ),
        // Nothing to act on: the only way out says so.
        confirmText:
            report.outcome == RestoreRecoveryOutcome.committedUnconfirmed
            ? currentAppLocalizations.close
            : null,
      ),
    );
    await _handleFailedPreference();
    if (!await _handlerDisclaimer()) {
      return;
    }
    await _showCrashRecoveryTip();
    if (_resetMixedPort case final value?) {
      dialogs.showMixedPortReset(
        value,
        _container.read(patchClashConfigProvider).mixedPort,
      );
    }
    final helperReady =
        !system.isMacOS ||
        !macosManagedHelperBuild ||
        _container.read(safeModeProvider) ||
        await prepareMacHelperStartup(
          maintenance: macHelperMaintenance,
          onBlocked: () {
            _container.read(coreStatusProvider.notifier).value =
                CoreStatus.disconnected;
            // The helper kept the Core from starting: its card says why.
            _container.read(coreStoppedForHelperProvider.notifier).value = true;
          },
          foreground: !_container.read(appSettingProvider).silentLaunch,
          wasOffered: preferences.getMacHelperInvitationShown,
          markOffered: preferences.markMacHelperInvitationShown,
          show: showMacHelperFlow,
        );
    Future<void> startCore() async {
      await _container.read(coreActionProvider.notifier).startCore();
      if (!_bootDecision.isDegraded) {
        await _container.read(setupActionProvider.notifier).initStatus();
      }
    }

    if (helperReady) {
      await startCore();
    } else if (!_container.read(safeModeProvider)) {
      // The helper was not ready at launch (waiting for the user to allow it,
      // or being recovered): start the Core once, as soon as it is.
      macHelperMaintenance.runOnceReady(startCore);
    }
    _container.read(initProvider.notifier).value = true;
    unawaited(_container.read(resourcesActionProvider.notifier).autoUpdate());
    unawaited(_container.read(mitmModulesActionProvider.notifier).autoUpdate());
    await bootGuard.markRunning();
    unawaited(_container.read(locationPermissionsProvider.notifier).refresh());
  }

  void _startBackgroundWork() {
    unawaited(_container.read(systemActionProvider.notifier).updateTray());
    unawaited(
      _container.read(profilesActionProvider.notifier).autoUpdateProfiles(),
    );
    unawaited(clearUpdateDownloads());
    unawaited(macUpdater?.cleanup());
    unawaited(_container.read(commonActionProvider.notifier).autoCheckUpdate());
    if (system.isMacOS) {
      unawaited(
        globalState.safeRun(() async {
          await autoLaunch?.refreshStatus((enabled) {
            _container
                .read(appSettingProvider.notifier)
                .update((state) => state.copyWith(autoLaunch: enabled));
          });
        }),
      );
    } else {
      unawaited(
        autoLaunch?.updateStatus(
          _container.read(appSettingProvider).autoLaunch,
        ),
      );
    }
    if (!_container.read(appSettingProvider).silentLaunch) {
      unawaited(window?.show());
    } else {
      unawaited(window?.hide());
    }
  }

  Future<void> _recoverInterruptedRestore() async {
    try {
      await restoreRecovery.run();
    } catch (error) {
      commonPrint.log(
        'restore recovery failed: $error',
        logLevel: LogLevel.error,
      );
      restoreRecovery.reports.add(
        const RestoreRecoveryReport(RestoreRecoveryOutcome.failed),
      );
    }
  }

  Future<void> _showCrashRecoveryTip() async {
    switch (_bootDecision.recovery) {
      case BootRecovery.none:
        return;
      case BootRecovery.skipAutoSetup:
        await dialogs.showAlert(
          title: currentAppLocalizations.launchInterrupted,
          dismissible: false,
          message: TextSpan(text: currentAppLocalizations.launchInterruptedTip),
        );
      case BootRecovery.clearProfile:
        await dialogs.showAlert(
          title: currentAppLocalizations.crashDetected,
          dismissible: false,
          message: TextSpan(
            text: currentAppLocalizations.crashDetectedTip(_failedProfileLabel),
          ),
        );
    }
  }

  String get _failedProfileLabel {
    final profileId = _bootDecision.failedProfileId;
    if (profileId == null) {
      return '';
    }
    final profile = _container.read(profilesProvider).getProfile(profileId);
    return profile?.label.takeFirstValid(['$profileId']) ?? '$profileId';
  }

  Future<void> _handleFailedPreference() async {
    if (await preferences.isInit) return;
    final res = await dialogs.showMessage(
      title: currentAppLocalizations.tip,
      message: TextSpan(text: currentAppLocalizations.cacheCorrupt),
    );
    if (res == true) {
      final file = File(await appPath.sharedPreferencesPath);
      await file.safeDelete();
    }
    // Saving here would rewrite the preferences file the user just chose to delete.
    await _container.read(systemActionProvider.notifier).handleExit(false);
  }

  /// Unattended desktop installs, such as a container nobody watches, accept
  /// up front: the core only starts after the disclaimer is accepted.
  bool get _isDisclaimerAcceptedByEnvironment =>
      system.isDesktop &&
      Platform.environment['FLCLASH_ACCEPT_DISCLAIMER'] == '1';

  /// Android's exit only finishes the activity, so Dart keeps running after
  /// [SystemAction.handleExit] returns and must not go on to start the app.
  Future<bool> _handlerDisclaimer() async {
    final acceptedVersion = _container.read(
      appSettingProvider.select((state) => state.acceptedDisclaimerVersion),
    );
    if (acceptedVersion >= disclaimerVersion) {
      return true;
    }
    final isDisclaimerAccepted =
        _isDisclaimerAcceptedByEnvironment || await requestDisclaimerConsent();
    if (!isDisclaimerAccepted) {
      await _container.read(systemActionProvider.notifier).handleExit();
      return false;
    }
    _container
        .read(appSettingProvider.notifier)
        .update(
          (state) =>
              state.copyWith(acceptedDisclaimerVersion: disclaimerVersion),
        );
    return true;
  }
}

final bootstrap = Bootstrap();
