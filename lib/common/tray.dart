import 'dart:async';
import 'dart:typed_data';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/tray_menu.dart';
import 'package:fl_clash/ui/delay_color.dart';
import 'package:fl_clash/widgets/icon.dart' show groupMonogram;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:prism_ui/prism_ui.dart';
import 'package:rust_api/tray.dart';

import 'app_localizations.dart';
import 'app_update.dart';
import 'app_ports.dart';
import 'compute.dart';
import 'constant.dart';
import 'keyboard.dart';
import 'l10n_labels.dart';
import 'mitm_indicator.dart';
import 'mac_update.dart';
import 'print.dart';
import 'provider_reader.dart';
import 'string.dart';
import 'system.dart';
import 'tray_icon.dart';
import 'window.dart';

class AppTray implements TrayPort {
  static AppTray? _instance;

  final bool isMacOS;
  final bool isWindows;
  final Future<Uint8List?> Function(String) _readIcon;

  bool _isShutDown = false;
  (int?, Mode, bool)? _groupCacheScope;
  List<Group> _lastVisibleGroups = const [];

  AppTray._internal({
    required this.isMacOS,
    required this.isWindows,
    Future<Uint8List?> Function(String) iconReader = readTrayIconPng,
  }) : _readIcon = iconReader;

  factory AppTray() {
    _instance ??= AppTray._internal(
      isMacOS: system.isMacOS,
      isWindows: system.isWindows,
    );
    return _instance!;
  }

  @visibleForTesting
  factory AppTray.forPlatform({
    required bool isMacOS,
    required bool isWindows,
    Future<Uint8List?> Function(String)? iconReader,
  }) {
    return AppTray._internal(
      isMacOS: isMacOS,
      isWindows: isWindows,
      iconReader: iconReader ?? readTrayIconPng,
    );
  }

  String get _trayIconSuffix {
    return isWindows ? 'ico' : 'png';
  }

  bool _isTemplate(bool monochrome) => isMacOS && monochrome;

  String _trayIconDir(bool monochrome) {
    if (isWindows) {
      return 'assets/images/tray/windows';
    }
    return _isTemplate(monochrome)
        ? 'assets/images/tray/macos'
        : 'assets/images/tray/unix';
  }

  String getTrayIcon({
    required bool isStart,
    required bool tunEnable,
    required bool safeMode,
    bool monochrome = true,
    bool updateAvailable = false,
    Mode mode = Mode.rule,
  }) {
    final name = safeMode
        ? 'status_4'
        : !isStart
        ? 'stopped'
        : '${mode.name}${tunEnable ? '_tun' : ''}';
    final update = isMacOS && updateAvailable ? '_update' : '';
    return '${_trayIconDir(monochrome)}/$name$update.$_trayIconSuffix';
  }

  @override
  Future<void> shutdown() async {
    _isShutDown = true;
    // Removing a status item makes macOS forget where the user dragged it in
    // the menu bar; one that goes away with the process keeps its place.
    if (isMacOS) {
      return;
    }
    await Tray.instance.hide();
  }

  @override
  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
    required ProviderReader read,
  }) async {
    if (_isShutDown) {
      return;
    }
    final menu = await _buildMenu(trayState: trayState, read: read);
    if (_isShutDown) return;
    final available = isMacOS ? read(availableUpdateStateProvider) : null;
    final appTitle = trayState.safeMode
        ? currentAppLocalizations.safeModeAppTitle(appName)
        : appName;
    await Tray.instance.show(
      TraySpec(
        icon: TrayIcon.asset(
          getTrayIcon(
            isStart: trayState.isStart && !trayState.suspended,
            tunEnable: trayState.tunEnable,
            safeMode: trayState.safeMode,
            monochrome: trayState.monochromeTrayIcon,
            mode: trayState.mode,
            updateAvailable: available != null,
          ),
          isTemplate: _isTemplate(trayState.monochromeTrayIcon),
          size: isMacOS ? 18 : 16,
          dot: isMacOS ? mitmTrayDot(trayState.mitmIndicator) : null,
        ),
        toolTip: available == null
            ? appTitle
            : '$appTitle, ${currentAppLocalizations.trayUpdateAvailable(displayVersionLabel(available.versionLabel))}',
        menu: menu,
      ),
    );
    await updateTitle(showTrayTitle: trayState.showTrayTitle, traffic: traffic);
  }

  Future<void> updateTitle({
    required bool showTrayTitle,
    required Traffic traffic,
  }) async {
    if (_isShutDown || !isMacOS) {
      return;
    }
    await Tray.instance.setTitle(showTrayTitle ? traffic.trayTitle : '');
  }

  Future<List<TrayMenuItem>> _buildMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) async {
    final groupMenu = isMacOS
        ? await _buildGroupMenu(trayState: trayState, read: read)
        : const <TrayMenuItem>[];
    final commonAction = read(commonActionProvider.notifier);
    final systemAction = read(systemActionProvider.notifier);
    final setupAction = read(setupActionProvider.notifier);
    final appLocalizations = currentAppLocalizations;
    final modeState = isMacOS
        ? read(trayModeMenuStateProvider)
        : const TrayModeMenuState();
    String? shortcut(HotAction action) => _shortcut(trayState, action);
    final showItem = TrayMenuAction(
      label: appLocalizations.show,
      detail: shortcut(HotAction.view),
      onSelected: () {
        window?.show();
      },
    );
    final exitItem = TrayMenuAction(
      label: appLocalizations.exit,
      detail: shortcut(HotAction.exit),
      onSelected: () {
        systemAction.handleExit();
      },
    );

    final corePending =
        read(trayCoreTogglePendingProvider) ||
        read(coreStatusProvider) == CoreStatus.connecting;
    final mitmIndicator = trayState.mitmIndicator;
    return [
      // Decryption is said first, whenever it is on.
      if (mitmIndicator != null) ...[
        TrayMenuAction(
          label: mitmIndicatorText(appLocalizations, mitmIndicator),
          onSelected: () {
            if (mitmSettingsPort case final open?) unawaited(open());
          },
        ),
        const TrayMenuSeparator(),
      ],
      showItem,
      TrayMenuCheckbox(
        label: corePending
            ? appLocalizations.trayCoreProcessing
            : read(coreStatusProvider) == CoreStatus.connected
            ? appLocalizations.trayStopCore
            : appLocalizations.trayStartCore,
        checked: false,
        enabled: !corePending,
        detail: shortcut(HotAction.start),
        onSelected: () => _observe(commonAction.toggleRunningForTray()),
      ),
      if (isMacOS) ...[
        TrayMenuCheckbox(
          label: appLocalizations.speedStatistics,
          checked: trayState.showTrayTitle,
          onSelected: commonAction.updateSpeedStatistics,
        ),
        TrayMenuCheckbox(
          label: appLocalizations.monochromeIcon,
          checked: trayState.monochromeTrayIcon,
          onSelected: commonAction.updateMonochromeTrayIcon,
        ),
      ],
      const TrayMenuSeparator(),
      for (final mode in Mode.values)
        TrayMenuCheckbox(
          label: mode.label,
          segmentGroup: isMacOS ? 'outbound-mode' : null,
          segmentError: modeState.error,
          enabled: modeState.pendingMode == null,
          checked: mode == trayState.mode,
          detail: shortcut(switch (mode) {
            Mode.rule => HotAction.ruleMode,
            Mode.global => HotAction.globalMode,
            Mode.direct => HotAction.directMode,
          }),
          onSelected: () {
            if (isMacOS) {
              _observe(setupAction.changeModeForTray(mode));
            } else {
              setupAction.changeMode(mode);
            }
          },
        ),
      const TrayMenuSeparator(),
      if (modeState.pendingMode case final pending?)
        TrayMenuAction.status(
          statusKey: 'outbound-mode',
          label: appLocalizations.traySwitchingTo(pending.label),
        )
      else if (modeState.error case final error?)
        TrayMenuAction.status(
          statusKey: 'outbound-mode',
          label: error,
          accessibilityLabel: error,
        ),
      ...groupMenu,
      if (trayState.isStart) ...[
        TrayMenuCheckbox(
          label: appLocalizations.systemProxy,
          checked: trayState.systemProxy,
          detail: shortcut(HotAction.proxy),
          onSelected: systemAction.updateSystemProxy,
        ),
        TrayMenuCheckbox(
          label: appLocalizations.trayTunMode,
          checked: trayState.tunEnable,
          detail: shortcut(HotAction.tun),
          onSelected: systemAction.updateTun,
        ),
        if (isMacOS && mitmFeature)
          ..._buildMitmItems(read: read, showsStatus: mitmIndicator != null),
        const TrayMenuSeparator(),
      ],
      TrayMenuCheckbox(
        label: appLocalizations.autoLaunch,
        checked: trayState.autoLaunch,
        onSelected: systemAction.updateAutoLaunch,
      ),
      TrayMenuAction(
        label: appLocalizations.trayCopyProxyCommand,
        detail: shortcut(HotAction.copyEnv),
        onSelected: systemAction.copyProxyEnv,
      ),
      if (isMacOS)
        if (read(availableUpdateStateProvider) case final available?)
          TrayMenuAction(
            label: switch (read(updateDownloadStateProvider)) {
              UpdateDownloading() => appLocalizations.downloadingUpdate,
              UpdateReady() when read(updateInstallBusyProvider) =>
                appLocalizations.macUpdateInstalling,
              _ when read(updateInstallBusyProvider) =>
                appLocalizations.trayCoreProcessing,
              _ => appLocalizations.updateImmediately,
            },
            detail:
                '${appLocalizations.updateMenuVersion(displayVersionLabel(available.versionLabel))}${available.manifest?.channel == ReleaseChannel.beta ? ' · ${appLocalizations.releaseBeta}' : ''}',
            enabled:
                !read(updateInstallBusyProvider) &&
                read(updateDownloadStateProvider) is! UpdateDownloading,
            onSelected: () => _observe(commonAction.updateFromTray(available)),
          ),
      const TrayMenuSeparator(),
      exitItem,
    ];
  }

  String? _shortcut(TrayState trayState, HotAction action) {
    final hotKey = trayState.hotKeys[action];
    final key = hotKey?.key;
    if (hotKey == null || key == null) {
      return null;
    }
    return ShortcutLabels(
      isMacOS: isMacOS,
      isWindows: isWindows,
    ).text(hotKey.modifiers, key);
  }

  Future<List<TrayMenuItem>> _buildGroupMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) async {
    final scope = (
      read(currentProfileIdProvider),
      trayState.mode,
      read(proxiesStyleSettingProvider).showHiddenGroups,
    );
    if (_groupCacheScope != scope) {
      _groupCacheScope = scope;
      _lastVisibleGroups = const [];
    }
    final readFailed = read(trayGroupsReadFailedProvider);
    final rawGroups = read(groupsProvider);
    if (trayState.mode == Mode.direct) {
      _lastVisibleGroups = const [];
      return const [];
    }
    if (!readFailed) {
      _lastVisibleGroups = [
        for (final group in trayState.groups)
          group.copyWith(now: rawGroups.getGroup(group.name)?.now),
      ];
    }
    final groups = readFailed ? _lastVisibleGroups : trayState.groups;
    if (groups.isEmpty) {
      return readFailed
          ? [
              TrayMenuAction(
                label: currentAppLocalizations.trayCouldNotLoad,
                enabled: false,
              ),
              const TrayMenuSeparator(),
            ]
          : const [];
    }
    final scheme = read(
      genColorSchemeProvider(read(currentBrightnessProvider)),
    );
    final menuStates = read(trayGroupMenuStatesProvider);
    final delays = read(trayDelaysProvider);
    final pendingTests = read(pendingDelayTestsProvider);
    final testingGroups = read(delayTestingGroupsProvider);
    final selectedMap = read(selectedMapProvider);
    final defaultTestUrl = read(patchClashConfigProvider).testUrl;
    final proxiesAction = read(proxiesActionProvider.notifier);
    final connected = read(coreStatusProvider) == CoreStatus.connected;
    bool isCurrentScope() =>
        read(currentProfileIdProvider) == scope.$1 &&
        read(patchClashConfigProvider).mode == scope.$2 &&
        read(proxiesStyleSettingProvider).showHiddenGroups == scope.$3;
    final hasMountedNodes = groups.any(
      (group) => group.all.any(
        (proxy) => proxy.providerName?.startsWith(mountProviderPrefix) ?? false,
      ),
    );
    final sourceLabels = {
      for (final profile
          in hasMountedNodes ? read(profilesProvider) : <Profile>[])
        mountProviderName(profile.id): profile.realLabel,
    };
    final icons = await _readMenuIcons(groups);
    return [
      for (final group in groups)
        _buildGroupSubmenu(
          group,
          rawGroup: readFailed ? group : rawGroups.getGroup(group.name),
          menuState: menuStates[group.name],
          configuredName: trayState.selectedMap[group.name],
          isStart: trayState.isStart,
          canSelect: !readFailed && (!trayState.isStart || connected),
          readFailed: readFailed,
          testing: testingGroups.contains(group.name),
          delays: delays[group.name] ?? const {},
          pendingNames: {
            for (final proxy in group.all)
              if (_isDelayPending(
                proxy.name,
                testUrl: group.testUrl.takeFirstValid([defaultTestUrl]),
                rawGroups: rawGroups,
                selectedMap: selectedMap,
                pendingTests: pendingTests,
              ))
                proxy.name,
          },
          scheme: scheme,
          icons: icons,
          sourceLabels: sourceLabels,
          onTest: () {
            if (!isCurrentScope()) return;
            _observe(
              proxiesAction.delayTestPageGroup(group.name, matchSearch: false),
            );
          },
          onSelected: (proxyName) {
            if (!isCurrentScope()) return;
            _observe(
              proxiesAction.changeProxyForTray(
                groupName: group.name,
                proxyName: proxyName,
              ),
            );
          },
        ),
      TrayMenuAction(
        label: HotAction.delayTest.label,
        detail: _shortcut(trayState, HotAction.delayTest),
        enabled: !readFailed,
        onSelected: () {
          if (!isCurrentScope()) return;
          _observe(proxiesAction.delayTestGroups(groups));
        },
      ),
      const TrayMenuSeparator(),
    ];
  }

  bool _isDelayPending(
    String proxyName, {
    required String testUrl,
    required List<Group> rawGroups,
    required Map<String, String> selectedMap,
    required Map<String, DelayTestPhase> pendingTests,
  }) {
    if (pendingTests.isEmpty) return false;
    final target = computeRealSelectedProxyState(
      proxyName,
      groups: rawGroups,
      selectedMap: selectedMap,
    );
    return pendingTests.containsKey(
      delayTestKey(target.testUrl.takeFirstValid([testUrl]), target.proxyName),
    );
  }

  Future<Map<String, Uint8List?>> _readMenuIcons(List<Group> groups) async {
    final sources = <String>{for (final group in groups) group.icon}
      ..remove('');
    final icons = <String, Uint8List?>{};
    final iterator = sources.iterator;
    Future<void> readNext() async {
      while (iterator.moveNext()) {
        final source = iterator.current;
        var timedOut = false;
        // Normalize covariant readers before timeout accepts a null fallback.
        icons[source] = await _readIcon(source)
            .then<Uint8List?>((bytes) => bytes)
            .timeout(
              const Duration(milliseconds: 150),
              onTimeout: () {
                timedOut = true;
                return null;
              },
            );
        // A timeout leaves the helper's acquisition running in this slot.
        if (timedOut) return;
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) readNext()]);
    return icons;
  }

  /// Decryption and recording request content, as saved: the settings
  /// page's switches, and their reasons when one cannot be used from here.
  List<TrayMenuItem> _buildMitmItems({
    required ProviderReader read,
    required bool showsStatus,
  }) {
    final l10n = currentAppLocalizations;
    final systemAction = read(systemActionProvider.notifier);
    final mitm = read(patchClashConfigProvider).mitm;
    final idle = read(trayMitmPendingProvider) == null;
    final trusted = mitm.trustedFingerprint != null;
    return [
      TrayMenuCheckbox(
        label: l10n.trayMitm,
        checked: mitm.enable,
        enabled: idle,
        onSelected: () => _observe(systemAction.toggleMitmForTray()),
      ),
      TrayMenuCheckbox(
        label: l10n.trayMitmCapture,
        checked: mitm.capture,
        enabled: idle && mitm.enable,
        onSelected: () => _observe(systemAction.toggleMitmCaptureForTray()),
      ),
      if (!mitm.enable) ...[
        if (!trusted)
          TrayMenuAction.status(
            statusKey: 'mitm-trust',
            label: l10n.mitmPauseNotTrusted,
          ),
        TrayMenuAction.status(
          statusKey: 'mitm-capture',
          label: l10n.trayMitmCaptureNeedsMitm,
        ),
      ],
      // While on, the status that leads the menu opens the settings.
      if (!showsStatus)
        TrayMenuAction(
          label: l10n.mitmIndicatorOpenSettings,
          onSelected: () {
            if (mitmSettingsPort case final open?) unawaited(open());
          },
        ),
    ];
  }

  void _observe(Future<void> operation) {
    unawaited(
      operation.onError<Object>((error, stackTrace) {
        commonPrint.log(
          'Tray action failed: ${compactError(error)}',
          logLevel: LogLevel.error,
        );
      }),
    );
  }

  TrayMenuBadge _badge(
    int? delay,
    bool pending,
    Proxy proxy,
    ColorScheme scheme,
  ) {
    final l10n = currentAppLocalizations;
    final value = pending || delay == 0 ? null : delay;
    final label = pending
        ? l10n.trayTesting
        : value == null
        ? switch (proxy.type.toLowerCase()) {
            'direct' => l10n.direct,
            'reject' || 'rejectdrop' => l10n.trayReject,
            _ => '—',
          }
        : value > 0
        ? l10n.trayLatencyBadge(value)
        : value == -1
        ? l10n.timeout
        : l10n.delayFailed;
    final status = scheme.delayColor(value);
    final (background, foreground) = status == null
        ? (SurfaceLevel.inset.colorOf(scheme), scheme.onSurfaceVariant)
        : value! < 0
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : value < 600
        ? (scheme.successContainer, scheme.onSuccessContainer)
        : (scheme.warningContainer, scheme.onWarningContainer);
    return TrayMenuBadge(
      label: label,
      background: background.toARGB32(),
      foreground: foreground.toARGB32(),
    );
  }

  TrayMenuSubmenu _buildGroupSubmenu(
    Group group, {
    required Group? rawGroup,
    required TrayGroupMenuState? menuState,
    required String? configuredName,
    required bool isStart,
    required bool canSelect,
    required bool readFailed,
    required bool testing,
    required Map<String, int> delays,
    required Set<String> pendingNames,
    required ColorScheme scheme,
    required Map<String, Uint8List?> icons,
    required Map<String, String> sourceLabels,
    required void Function() onTest,
    required void Function(String proxyName) onSelected,
  }) {
    final l10n = currentAppLocalizations;
    final members = {for (final proxy in group.all) proxy.name};
    final pending = menuState?.pendingName;
    final failure = menuState?.switchFailure;
    final candidate = menuState != null
        ? menuState.confirmedName
        : isStart
        ? rawGroup?.now
        : members.contains(configuredName)
        ? configuredName
        : (rawGroup ?? group).now;
    final selected = members.contains(candidate) ? candidate : null;
    String displayName(String name) {
      for (final proxy in group.all) {
        if (proxy.name == name) return _memberLabel(proxy, sourceLabels);
      }
      return name;
    }

    final selection = group.type == GroupType.LoadBalance
        ? l10n.trayMultipleNodes
        : selected == null
        ? '—'
        : displayName(selected);
    final status = readFailed
        ? l10n.trayCouldNotLoad
        : switch (failure) {
            TraySwitchFailure.failed => l10n.trayCouldNotSwitch,
            TraySwitchFailure.unconfirmed => l10n.traySwitchUnconfirmed,
            null =>
              pending == null
                  ? null
                  : l10n.traySwitchingTo(displayName(pending)),
          };
    TrayMenuIcon icon(String name, String source, SurfaceLevel level) =>
        TrayMenuIcon(
          monogram: groupMonogram(name),
          background: level.colorOf(scheme).toARGB32(),
          foreground: scheme.onSurfaceVariant.toARGB32(),
          pngBytes: icons[source],
        );
    return TrayMenuSubmenu(
      label: group.name,
      detail: status ?? selection,
      icon: icon(group.name, group.icon, SurfaceLevel.block),
      accessibilityLabel: [
        group.name,
        group.type == GroupType.LoadBalance
            ? l10n.trayMultipleNodes
            : selected == null
            ? l10n.traySelectionUnknown
            : l10n.trayCurrentSelection(displayName(selected)),
        if (status != null) status,
      ].join(', '),
      items: [
        TrayMenuAction(
          label: l10n.trayTestLatency,
          enabled: !readFailed && !testing && group.all.isNotEmpty,
          onSelected: onTest,
        ),
        const TrayMenuSeparator(),
        if (status != null) TrayMenuAction(label: status, enabled: false),
        if (group.all.isEmpty)
          TrayMenuAction(label: l10n.trayNoAvailableMembers, enabled: false),
        for (final proxy in group.all)
          _buildMember(
            label: _memberLabel(proxy, sourceLabels),
            checked:
                group.type != GroupType.LoadBalance && selected == proxy.name,
            enabled:
                canSelect &&
                pending == null &&
                group.type != GroupType.LoadBalance &&
                group.type != GroupType.Relay,
            badge: _badge(
              delays[proxy.name],
              pendingNames.contains(proxy.name),
              proxy,
              scheme,
            ),
            measuredDelay: delays[proxy.name],
            testing: pendingNames.contains(proxy.name),
            onSelected: () => onSelected(proxy.name),
          ),
      ],
    );
  }

  String _memberLabel(Proxy proxy, Map<String, String> sourceLabels) {
    final source = sourceLabels[proxy.providerName];
    if (source == null || source.isEmpty) return proxy.name;
    final prefix = '$source · ';
    return proxy.name.startsWith(prefix) ? proxy.name : '$prefix${proxy.name}';
  }

  TrayMenuCheckbox _buildMember({
    required String label,
    required bool checked,
    required bool enabled,
    required TrayMenuBadge badge,
    required int? measuredDelay,
    required bool testing,
    required void Function() onSelected,
  }) {
    return TrayMenuCheckbox(
      label: label,
      checked: checked,
      enabled: enabled,
      badge: badge,
      accessibilityLabel: [
        label,
        if (checked) currentAppLocalizations.traySelected,
        testing
            ? currentAppLocalizations.trayTesting
            : measuredDelay != null && measuredDelay > 0
            ? currentAppLocalizations.trayLatencyMilliseconds(measuredDelay)
            : badge.label == '—'
            ? currentAppLocalizations.trayLatencyUnknown
            : badge.label,
      ].join(', '),
      onSelected: onSelected,
    );
  }
}

final appTray = system.isDesktop ? AppTray() : null;

const mitmDotRed = 0xFFFF3B30;
const mitmDotAmber = 0xFFFF9F0A;

/// The menu bar dot for the MITM status: red and breathing while decryption
/// is on and healthy (the dot says "MITM mode enabled"; nothing is polled for
/// it, and with reduce motion the native side holds it still), amber and
/// still while paused or unconfirmed, and none while off.
TrayDot? mitmTrayDot(MitmIndicator? indicator) => switch (indicator?.kind) {
  null => null,
  MitmIndicatorKind.on || MitmIndicatorKind.decrypting => const TrayDot(
    color: mitmDotRed,
    breathing: true,
  ),
  MitmIndicatorKind.paused || MitmIndicatorKind.unconfirmed => const TrayDot(
    color: mitmDotAmber,
    breathing: false,
  ),
};
