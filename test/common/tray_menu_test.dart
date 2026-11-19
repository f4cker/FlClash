import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/l10n_labels.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/tray_menu.dart';
import 'package:fl_clash/common/compute.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:rust_api/tray.dart';

import '../helpers/app_paths.dart';
import '../helpers/fake_tray_host.dart';
import '../helpers/test_profiles.dart';

const _proxyGroup = Group(
  name: 'Proxy',
  type: GroupType.Selector,
  all: [
    Proxy(name: 'A', type: 'Direct'),
    Proxy(name: 'B', type: 'Direct'),
    Proxy(name: 'C', type: 'Direct'),
  ],
);

HotKeyAction _bind(HotAction action, PhysicalKeyboardKey key) {
  return HotKeyAction(
    action: action,
    key: key.usbHidUsage,
    modifiers: const {KeyboardModifier.control, KeyboardModifier.shift},
  );
}

TrayState _trayState({
  bool isStart = false,
  bool tunEnable = false,
  bool systemProxy = false,
  bool autoLaunch = false,
  bool showTrayTitle = false,
  bool monochromeTrayIcon = true,
  bool safeMode = false,
  Mode mode = Mode.rule,
  List<Group> groups = const [],
  Map<HotAction, HotKeyAction> hotKeys = const {},
  Map<String, String> selectedMap = const {},
  MitmIndicator? mitmIndicator,
}) {
  return TrayState(
    mode: mode,
    port: 7890,
    autoLaunch: autoLaunch,
    systemProxy: systemProxy,
    tunEnable: tunEnable,
    isStart: isStart,
    groups: groups,
    selectedMap: selectedMap,
    showTrayTitle: showTrayTitle,
    monochromeTrayIcon: monochromeTrayIcon,
    safeMode: safeMode,
    hotKeys: hotKeys,
    mitmIndicator: mitmIndicator,
  );
}

Map<String, Object?> _describe(TrayItem item) {
  return {
    'id': item.id,
    'type': item.kind.name,
    if (item.kind != TrayItemKind.separator) 'label': item.label,
    if (item.detail != null) 'detail': item.detail,
    'enabled': item.enabled,
    'checked': item.checked,
    'transientStatusKey': ?item.transientStatusKey,
    'segmentGroup': ?item.segmentGroup,
    'segmentError': ?item.segmentError,
    if (item.icon case final icon?)
      'icon': {
        'monogram': icon.monogram,
        'background': icon.background,
        'foreground': icon.foreground,
        if (icon.png case final png?) 'png': base64Encode(png),
      },
    if (item.badge case final badge?)
      'badge': {
        'label': badge.label,
        'background': badge.background,
        'foreground': badge.foreground,
      },
    'accessibilityLabel': ?item.accessibilityLabel,
    'items': item.items.map(_describe).toList(),
  };
}

List<Map<String, Object?>> _items(TrayContent? content) {
  return content?.menu.map(_describe).toList() ?? const [];
}

Map<String, Object?> _item(TrayContent? content, String label) {
  return _items(content).firstWhere((item) => item['label'] == label);
}

List<String> _labels(TrayContent? content) {
  return _items(
    content,
  ).map((item) => item['label']).whereType<String>().toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTrayHost host;
  late ProviderContainer container;
  late AppTray tray;

  late Directory root;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('tray_menu_test');
    await useAppPaths(root);
    loadAppLocalizations(const Locale('en'));
  });

  tearDownAll(() {
    // The shared system temp dir is not exclusively ours; another suite running
    // alongside this one can take the tree out from under the teardown, either
    // before the check or between the check and the delete.
    try {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    } on FileSystemException {
      return;
    }
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    host = FakeTrayHost();
    tray = AppTray.forPlatform(isMacOS: true, isWindows: false);
    container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWithValue(null),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        currentBrightnessProvider.overrideWithValue(Brightness.light),
      ],
    );
    Tray.instance.resetForTesting(host);
  });

  tearDown(() {
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  TrayContent? showCall() => host.lastShown;

  Future<void> update(TrayState trayState, {AppTray? on}) {
    return (on ?? tray).update(
      trayState: trayState,
      traffic: const Traffic(),
      read: container.read,
    );
  }

  test(
    'SystemAction.updateTray builds the menu without reading itself',
    () async {
      globalState.container = container;
      trayPort = tray;
      addTearDown(() => trayPort = null);

      await container.read(systemActionProvider.notifier).updateTray();

      expect(showCall(), isNotNull);
      expect(_labels(showCall()), contains(currentAppLocalizations.exit));
    },
  );

  test(
    'update row carries full target in a separate clickable detail column',
    () async {
      container.listen(availableUpdateStateProvider, (_, _) {});
      container.listen(updateInstallBusyProvider, (_, _) {});
      container.listen(lastUpdateCheckStateProvider, (_, _) {});
      container.read(availableUpdateStateProvider.notifier).value =
          const UpdateAvailable({'tag_name': 'v1.0.0+2026111902'});
      await update(_trayState());
      final row = showCall()!.menu.firstWhere(
        (item) => item.label == 'Update now',
      );
      expect(row.detail, 'NEW 1.0.0 (2026111902)');
      expect(row.enabled, isTrue);
      container.read(updateInstallBusyProvider.notifier).value = true;
      await update(_trayState());
      expect(
        showCall()!.menu
            .firstWhere((item) => item.label == 'Processing')
            .enabled,
        isFalse,
      );
      container.read(updateDownloadStateProvider.notifier).value =
          const UpdateReady('v1.0.0', '/tmp/update');
      await update(_trayState());
      expect(
        showCall()!.menu
            .firstWhere(
              (item) =>
                  item.label == currentAppLocalizations.macUpdateInstalling,
            )
            .enabled,
        isFalse,
      );
      container.read(updateDownloadStateProvider.notifier).value = null;
      container.read(updateInstallBusyProvider.notifier).value = false;
      container.read(lastUpdateCheckStateProvider.notifier).value =
          UpdateCheckFailed(Exception('offline'));
      await update(_trayState());
      expect(
        _labels(showCall()),
        contains(currentAppLocalizations.updateCheckFailed),
      );
      expect(_labels(showCall()), contains('Update now'));
      container.read(availableUpdateStateProvider.notifier).value = null;
      await update(_trayState());
      expect(_labels(showCall()), isNot(contains('Update now')));
    },
  );

  test(
    'pending core transition disables the row without changing running state',
    () async {
      container.listen(trayCoreTogglePendingProvider, (_, _) {});
      container.read(trayCoreTogglePendingProvider.notifier).value = true;
      await update(_trayState(isStart: true));
      final pending = showCall()!.menu.firstWhere(
        (item) => item.label == 'Processing',
      );
      expect(pending.enabled, isFalse);
      expect(_labels(showCall()), isNot(contains('Start core')));
      container.read(trayCoreTogglePendingProvider.notifier).value = false;
      await update(_trayState(isStart: true));
      expect(_labels(showCall()), contains('Stop core'));
      container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      await update(_trayState());
      expect(
        showCall()!.menu
            .firstWhere((item) => item.label == 'Processing')
            .enabled,
        isFalse,
      );
    },
  );

  test('Core row uses connection state even when listeners disagree', () async {
    await update(_trayState(isStart: false));
    expect(_labels(showCall()), contains('Stop core'));
    expect(_labels(showCall()), isNot(contains('Start core')));
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await update(_trayState(isStart: true));
    expect(_labels(showCall()), contains('Start core'));
    expect(_labels(showCall()), isNot(contains('Stop core')));
  });

  test('builds the stopped menu without the running-only toggles', () async {
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await update(_trayState());

    final labels = _labels(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.show));
    expect(labels, contains(l10n.trayStartCore));
    expect(labels, contains(l10n.autoLaunch));
    expect(labels, contains(l10n.trayCopyProxyCommand));
    expect(labels, contains(l10n.exit));
    expect(labels, isNot(contains(l10n.trayTunMode)));
    expect(labels, isNot(contains(l10n.systemProxy)));
  });

  test('adds TUN and system proxy toggles once the core is running', () async {
    await update(_trayState(isStart: true));

    final labels = _labels(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.trayStopCore), reason: 'start flips to stop');
    expect(labels, contains(l10n.trayTunMode));
    expect(labels, contains(l10n.systemProxy));
  });

  group('safe mode', () {
    test('keeps the full menu', () async {
      await update(_trayState(isStart: true, safeMode: true));

      final labels = _labels(showCall());
      final l10n = currentAppLocalizations;
      expect(labels, contains(l10n.trayStopCore));
      expect(labels, contains(l10n.trayTunMode));
      expect(labels, contains(l10n.systemProxy));
      expect(labels, contains(l10n.trayCopyProxyCommand));
    });

    test('names the mode in the tooltip and ships the safe icon', () async {
      await update(_trayState(isStart: true, safeMode: true));

      final content = showCall()!;
      final l10n = currentAppLocalizations;
      expect(content.toolTip, '$appName (${l10n.safeMode})');
      expect(
        content.image.pngs.first,
        File('assets/images/tray/macos/status_4.png').readAsBytesSync(),
      );
    });
  });

  group('decryption status', () {
    test('is absent while decryption is off', () async {
      await update(_trayState());

      final l10n = currentAppLocalizations;
      expect(_labels(showCall()).first, l10n.show);
    });

    test('leads the menu, paused with its reason', () async {
      await update(
        _trayState(
          mitmIndicator: const MitmIndicator.paused(MitmPauseReason.liveness),
        ),
      );

      final l10n = currentAppLocalizations;
      final items = _items(showCall());
      expect(
        items.first['label'],
        l10n.mitmIndicatorPausedBecause(l10n.mitmPauseLiveness),
      );
      expect(items.first['enabled'], isTrue);
      expect(items[1]['type'], 'separator');
      expect(items[2]['label'], l10n.show);
    });

    test('says when it decrypts', () async {
      await update(_trayState(mitmIndicator: const MitmIndicator.decrypting()));

      expect(
        _labels(showCall()).first,
        currentAppLocalizations.mitmIndicatorDecrypting,
      );
    });
  });

  test('offers every outbound mode as a menu entry', () async {
    await update(_trayState(mode: Mode.global));

    final checkedModes = _items(showCall())
        .where((item) => item['checked'] == true)
        .map((item) => item['label'])
        .toList();
    expect(checkedModes, contains(currentAppLocalizations.global));
  });

  test(
    'macOS mode segments reuse localized labels and keep confirmed selection while pending',
    () async {
      container
          .read(trayModeMenuStateProvider.notifier)
          .set(const TrayModeMenuState(pendingMode: Mode.direct));
      await update(_trayState(mode: Mode.global));
      final segments = _items(
        showCall(),
      ).where((item) => item['segmentGroup'] == 'outbound-mode').toList();
      expect(
        segments.map((item) => item['label']),
        Mode.values.map((mode) => mode.label),
      );
      expect(segments.map((item) => item['enabled']), everyElement(false));
      expect(
        segments.where((item) => item['checked'] == true).single['label'],
        Mode.global.label,
      );
      expect(
        _labels(showCall()),
        contains(currentAppLocalizations.traySwitchingTo(Mode.direct.label)),
      );
    },
  );

  test(
    'failed mode keeps selection, enables retry, and carries the full reason',
    () async {
      const reason = 'fixture mode failure';
      container
          .read(trayModeMenuStateProvider.notifier)
          .set(const TrayModeMenuState(error: reason));
      await update(_trayState());
      final selected = _item(showCall(), Mode.rule.label);
      expect(selected['checked'], isTrue);
      expect(selected['enabled'], isTrue);
      expect(selected['segmentError'], reason);
      expect(_item(showCall(), reason)['accessibilityLabel'], reason);
    },
  );

  test(
    'mode status uses one semantic slot through pending, error and success',
    () async {
      final state = container.read(trayModeMenuStateProvider.notifier);
      state.set(const TrayModeMenuState(pendingMode: Mode.global));
      await update(_trayState());
      final pending = _items(
        showCall(),
      ).singleWhere((item) => item['transientStatusKey'] == 'outbound-mode');
      expect(
        pending['label'],
        currentAppLocalizations.traySwitchingTo(Mode.global.label),
      );
      expect(pending['enabled'], isFalse);

      const reason = 'fixture mode failure';
      state.set(const TrayModeMenuState(error: reason));
      await update(_trayState());
      final failed = _items(showCall()).singleWhere(
        (item) => item['transientStatusKey'] == pending['transientStatusKey'],
      );
      expect(failed['label'], reason);
      expect(failed['accessibilityLabel'], reason);
      expect(failed['enabled'], isFalse);
      expect(_labels(showCall()), isNot(contains(pending['label'])));

      state.set(const TrayModeMenuState());
      await update(_trayState(mode: Mode.global));
      expect(
        _items(
          showCall(),
        ).where((item) => item.containsKey('transientStatusKey')),
        isEmpty,
      );
      expect(_labels(showCall()), isNot(contains(pending['label'])));
      expect(_labels(showCall()), isNot(contains(reason)));
      expect(_item(showCall(), Mode.global.label)['checked'], isTrue);
    },
  );

  test('non-macOS keeps the ordinary mode checkboxes', () async {
    await update(
      _trayState(),
      on: AppTray.forPlatform(isMacOS: false, isWindows: true),
    );
    expect(
      _items(showCall()).where((item) => item.containsKey('segmentGroup')),
      isEmpty,
    );
  });

  void expectUpdateIcon(String name, {bool mono = true}) {
    final icon = showCall()!.image;
    expect(icon.size, 18);
    expect(icon.template, mono);
    expect(icon.pngs, hasLength(4));
    for (var index = 0; index < 4; index++) {
      final variant = index == 0 ? '' : '${index + 1}.0x/';
      expect(
        icon.pngs[index],
        File(
          'assets/images/tray/${mono ? 'macos' : 'unix'}/$variant$name.png',
        ).readAsBytesSync(),
      );
    }
  }

  test(
    'confirmed update selects every mode, safe and stopped variant',
    () async {
      container.listen(availableUpdateStateProvider, (_, _) {});
      container.read(availableUpdateStateProvider.notifier).value =
          const UpdateAvailable({'tag_name': 'v1.0.0+2026111902'});
      for (final mono in [false, true]) {
        for (final (state, name) in [
          (_trayState(tunEnable: true), 'stopped'),
          (
            _trayState(
              isStart: true,
              tunEnable: true,
            ).copyWith(suspended: true),
            'stopped',
          ),
          (
            _trayState(isStart: true, tunEnable: true, safeMode: true),
            'status_4',
          ),
          for (final mode in Mode.values)
            for (final tun in [false, true])
              (
                _trayState(isStart: true, mode: mode, tunEnable: tun),
                '${mode.name}${tun ? '_tun' : ''}',
              ),
        ]) {
          await update(state.copyWith(monochromeTrayIcon: mono));
          expectUpdateIcon('${name}_update', mono: mono);
        }
      }
    },
  );

  test(
    'only confirmed availability controls the arrow through failure and preparation',
    () async {
      container.listen(availableUpdateStateProvider, (_, _) {});
      container.listen(lastUpdateCheckStateProvider, (_, _) {});
      container.listen(updateDownloadStateProvider, (_, _) {});
      container.listen(updateInstallBusyProvider, (_, _) {});
      const candidate = UpdateAvailable({'tag_name': 'v1.0.0+2026111902'});
      final available = container.read(availableUpdateStateProvider.notifier);
      final check = container.read(lastUpdateCheckStateProvider.notifier);
      final download = container.read(updateDownloadStateProvider.notifier);
      final busy = container.read(updateInstallBusyProvider.notifier);
      check.value = UpdateCheckFailed(Exception('offline before confirmation'));
      busy.value = true;
      await update(_trayState());
      expectUpdateIcon('stopped');
      expect(showCall()!.toolTip, appName);
      available.value = candidate;
      for (final change in <void Function()>[
        () => check.value = candidate,
        () => check.value = UpdateCheckFailed(
          Exception('offline after confirmation'),
        ),
        () => download.value = const UpdateDownloading('v1.0.0+2026111902'),
        () => download.value = const UpdateReady(
          'v1.0.0+2026111902',
          'fixture.dmg',
        ),
        () => download.value = null,
        () => busy.value = false,
      ]) {
        change();
        await update(_trayState());
        expectUpdateIcon('stopped_update');
        expect(
          showCall()!.toolTip,
          '$appName, Update available: 1.0.0 (2026111902)',
        );
      }
      check.value = const UpdateUpToDate();
      available.value = null;
      await update(_trayState());
      expectUpdateIcon('stopped');
      expect(showCall()!.toolTip, appName);
      available.value = candidate;
      await update(_trayState());
      expectUpdateIcon('stopped_update');
      available.value = null;
      await update(_trayState());
      expectUpdateIcon('stopped');
      expect(showCall()!.toolTip, appName);
    },
  );

  test(
    'available update accessibility keeps the full target and safe mode in every locale',
    () async {
      container.listen(availableUpdateStateProvider, (_, _) {});
      container.read(availableUpdateStateProvider.notifier).value =
          const UpdateAvailable({'tag_name': 'v1.0.0+2026111902'});
      try {
        for (final language in ['en', 'zh', 'ja', 'ru', 'fr', 'es', 'ko']) {
          final l10n = loadAppLocalizations(Locale(language));
          await update(_trayState(safeMode: true));
          expect(
            showCall()!.toolTip,
            '${l10n.safeModeAppTitle(appName)}, ${l10n.trayUpdateAvailable('1.0.0 (2026111902)')}',
          );
          expect(showCall()!.toolTip, contains('1.0.0 (2026111902)'));
          if (language == 'zh') expect(showCall()!.toolTip, contains('可用更新'));
        }
      } finally {
        loadAppLocalizations(const Locale('en'));
      }
    },
  );

  test('update arrow preserves both native MITM dot states', () async {
    container.listen(availableUpdateStateProvider, (_, _) {});
    container.read(availableUpdateStateProvider.notifier).value =
        const UpdateAvailable({'tag_name': 'v1.0.0+2026111902'});
    for (final indicator in [
      const MitmIndicator.decrypting(),
      const MitmIndicator.paused(MitmPauseReason.liveness),
    ]) {
      for (final mono in [false, true]) {
        final state = _trayState(
          isStart: true,
          tunEnable: true,
          monochromeTrayIcon: mono,
          mitmIndicator: indicator,
        );
        await update(state);
        expectUpdateIcon('rule_tun_update', mono: mono);
        final dot = showCall()!.image.dot;
        expect(dot, isNotNull);
        container.read(availableUpdateStateProvider.notifier).value = null;
        await update(state);
        expect(showCall()!.image.dot, dot);
        container.read(availableUpdateStateProvider.notifier).value =
            const UpdateAvailable({'tag_name': 'v1.0.0+2026111902'});
      }
    }
  });

  test('other platforms do not select macOS update assets', () async {
    for (final windows in [false, true]) {
      final other = AppTray.forPlatform(isMacOS: false, isWindows: windows);
      expect(
        other.getTrayIcon(
          isStart: true,
          tunEnable: true,
          safeMode: false,
          updateAvailable: true,
        ),
        'assets/images/tray/${windows ? 'windows' : 'unix'}/rule_tun.${windows ? 'ico' : 'png'}',
      );
    }
  });

  test('sends icon, tooltip and menu in a single show call', () async {
    await update(_trayState(isStart: true, tunEnable: true));

    expect(host.shown, hasLength(1));

    final content = host.shown.single;
    expect(content.toolTip, appName);
    expect(content.menu, isNotEmpty);
    expect(content.image.pngs, hasLength(Tray.variantScales.length));
    expect(content.image.pngs, everyElement(isNotEmpty));
    expect(content.image.template, isTrue);
  });

  test('ships the color status icon once monochrome is off', () async {
    await update(
      _trayState(isStart: true, tunEnable: true, monochromeTrayIcon: false),
    );

    final content = showCall()!;
    expect(content.image.template, isFalse);
    expect(
      content.image.pngs.first,
      File('assets/images/tray/unix/rule_tun.png').readAsBytesSync(),
    );
    expect(
      _item(showCall(), currentAppLocalizations.monochromeIcon)['checked'],
      isFalse,
    );
  });

  test('changing the running mode immediately sends its new icon', () async {
    for (final mode in Mode.values) {
      host.clear();
      await update(_trayState(isStart: true, mode: mode));
      expect(
        showCall()!.image.pngs.first,
        File('assets/images/tray/macos/${mode.name}.png').readAsBytesSync(),
      );
    }
  });

  test(
    'running mode updates select independent color and template TUN variants',
    () async {
      for (final mono in [false, true]) {
        final directory = mono ? 'macos' : 'unix';
        for (final mode in [Mode.rule, Mode.global, Mode.direct, Mode.rule]) {
          for (final tun in [false, true]) {
            host.clear();
            await update(
              _trayState(
                isStart: true,
                mode: mode,
                tunEnable: tun,
                monochromeTrayIcon: mono,
              ),
            );
            final icon = showCall()!.image;
            expect(icon.template, mono);
            expect(
              icon.pngs.first,
              File(
                'assets/images/tray/$directory/${mode.name}${tun ? '_tun' : ''}.png',
              ).readAsBytesSync(),
            );
          }
        }
      }
    },
  );

  test(
    'stored TUN never adds a running dot when stopped, suspended or safe',
    () async {
      for (final mono in [false, true]) {
        final directory = mono ? 'macos' : 'unix';
        for (final (state, name) in [
          (_trayState(tunEnable: true), 'stopped'),
          (
            _trayState(
              isStart: true,
              tunEnable: true,
            ).copyWith(suspended: true),
            'stopped',
          ),
          (
            _trayState(isStart: true, tunEnable: true, safeMode: true),
            'status_4',
          ),
        ]) {
          host.clear();
          await update(state.copyWith(monochromeTrayIcon: mono));
          expect(
            showCall()!.image.pngs.first,
            File('assets/images/tray/$directory/$name.png').readAsBytesSync(),
          );
        }
      }
    },
  );

  test('skips the platform call when the tray state is unchanged', () async {
    await update(_trayState(isStart: true));
    await update(_trayState(isStart: true));

    expect(host.shown, hasLength(1));
  });

  test('menu item ids are stable across identical rebuilds', () async {
    await update(_trayState());
    final first = _items(showCall()).map((item) => item['id']).toList();

    host = FakeTrayHost();
    Tray.instance.resetForTesting(host);

    await update(_trayState());
    final second = _items(showCall()).map((item) => item['id']).toList();

    expect(second, first);
    expect(first.first, 1024);
  });

  test('group submenus carry their proxies as nested items', () async {
    await update(
      _trayState(
        groups: [
          const Group(
            name: 'Proxy',
            type: GroupType.Selector,
            all: [Proxy(name: 'A', type: 'Direct')],
          ),
        ],
      ),
    );

    final submenu = _items(
      showCall(),
    ).firstWhere((item) => item['type'] == 'submenu');
    expect(submenu['label'], 'Proxy');
    final children = (submenu['items'] as List).cast<Map<String, Object?>>();
    expect(children.map((item) => item['label']), contains('A'));
  });

  test('shows each bound hotkey dimmed beside its entry', () async {
    await update(
      _trayState(
        isStart: true,
        hotKeys: {
          HotAction.view: _bind(HotAction.view, PhysicalKeyboardKey.keyV),
          HotAction.globalMode: _bind(
            HotAction.globalMode,
            PhysicalKeyboardKey.keyG,
          ),
          HotAction.tun: _bind(HotAction.tun, PhysicalKeyboardKey.keyT),
        },
      ),
    );

    final l10n = currentAppLocalizations;
    final call = showCall();
    expect(_item(call, l10n.show)['detail'], '⌃⇧V');
    expect(_item(call, Mode.global.label)['detail'], '⌃⇧G');
    expect(_item(call, l10n.trayTunMode)['detail'], '⌃⇧T');
    expect(_item(call, l10n.exit), isNot(contains('detail')));
    expect(_item(call, Mode.rule.label), isNot(contains('detail')));
  });

  test(
    'group parents show the immediate selection and members carry badges',
    () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWithValue(null),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          currentBrightnessProvider.overrideWithValue(Brightness.light),
          trayDelaysProvider.overrideWithValue({
            'Proxy': {'A': 120, 'B': -1, 'C': -2},
          }),
        ],
      );
      const group = Group(
        name: 'Proxy',
        type: GroupType.Selector,
        all: [
          Proxy(name: 'A', type: 'Direct'),
          Proxy(name: 'B', type: 'Direct'),
          Proxy(name: 'C', type: 'Direct'),
          Proxy(name: 'D', type: 'Direct'),
        ],
      );
      await update(_trayState(groups: [group], selectedMap: {'Proxy': 'A'}));

      final submenu = _item(showCall(), 'Proxy');
      expect(submenu['detail'], 'A');
      final children = (submenu['items'] as List).cast<Map>().where(
        (item) => item['type'] == 'checkbox',
      );
      expect(children.map((item) => (item['badge'] as Map)['label']), [
        currentAppLocalizations.trayLatencyBadge(120),
        currentAppLocalizations.timeout,
        currentAppLocalizations.delayFailed,
        currentAppLocalizations.direct,
      ]);
    },
  );

  test('a delay test entry follows the groups', () async {
    await update(
      _trayState(
        groups: [_proxyGroup],
        hotKeys: {
          HotAction.delayTest: _bind(
            HotAction.delayTest,
            PhysicalKeyboardKey.keyD,
          ),
        },
      ),
    );

    final items = _items(showCall());
    final index = items.indexWhere((item) => item['type'] == 'submenu');
    expect(items[index + 1]['label'], HotAction.delayTest.label);
    expect(items[index + 1]['detail'], '⌃⇧D');
  });

  List<Map> children(String groupName) =>
      (_item(showCall(), groupName)['items'] as List).cast<Map>();

  List<Map> members(String groupName) =>
      children(groupName).where((item) => item['type'] == 'checkbox').toList();

  Future<void> select(Map item) async {
    host.emit(
      TraySignalKind.itemSelected,
      item['id'] as int,
      showCall()!.menuGeneration,
    );
    await pumpEventQueue();
  }

  test('the decryption status opens the MITM settings', () async {
    var opened = 0;
    mitmSettingsPort = () async => opened++;
    addTearDown(() => mitmSettingsPort = null);
    await update(_trayState(mitmIndicator: const MitmIndicator.decrypting()));

    await select(_items(showCall()).first);

    expect(opened, 1);
  });

  test('members have no icons, including subgroup members and flags', () async {
    final nested = _proxyGroup.copyWith(name: 'Nested', icon: 'nested-icon');
    final group = _proxyGroup.copyWith(
      all: const [
        Proxy(name: '🇭🇰 Hong Kong ✨', type: 'Shadowsocks'),
        Proxy(name: 'Nested', type: 'Selector'),
        Proxy(name: 'DIRECT', type: 'Direct'),
      ],
    );
    final readIcons = <String>[];
    final localTray = AppTray.forPlatform(
      isMacOS: true,
      isWindows: false,
      iconReader: (source) async {
        readIcons.add(source);
        return null;
      },
    );
    container.read(groupsProvider.notifier).value = [group, nested];
    await update(
      _trayState(groups: [group], selectedMap: {'Proxy': '🇭🇰 Hong Kong ✨'}),
      on: localTray,
    );
    expect(members('Proxy').map((item) => item['label']), [
      '🇭🇰 Hong Kong ✨',
      'Nested',
      'DIRECT',
    ]);
    expect(members('Proxy').map((item) => item['icon']), everyElement(isNull));
    expect(members('Proxy').first['checked'], isTrue);
    expect(_item(showCall(), 'Proxy')['icon'], isNotNull);
    expect(_item(showCall(), 'Proxy')['detail'], '🇭🇰 Hong Kong ✨');
    expect(readIcons, isEmpty);
  });

  test(
    'mounted labels use exact source metadata and select raw node ids',
    () async {
      final recorded = <String>[];
      container.dispose();
      container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWithValue(null),
          profilesProvider.overrideWith(
            () => TestProfiles(const [
              Profile(
                id: 7,
                label: 'Source 🇭🇰',
                type: ProfileType.url,
                autoUpdateDuration: Duration.zero,
              ),
              Profile(
                id: 8,
                label: 'Other',
                type: ProfileType.url,
                autoUpdateDuration: Duration.zero,
              ),
            ]),
          ),
          proxiesActionProvider.overrideWith(
            () => _RecordingProxiesAction(recorded),
          ),
        ],
      );
      const raw = '🇯🇵 Tokyo ✨ (Source 🇭🇰)';
      const label = 'Source 🇭🇰 · $raw';
      final group = _proxyGroup.copyWith(
        all: const [
          Proxy(name: raw, type: 'Shadowsocks', providerName: 'flash-mount-7'),
          Proxy(
            name: 'Source 🇭🇰 · already prefixed',
            type: 'Shadowsocks',
            providerName: 'flash-mount-7',
          ),
          Proxy(
            name: '🇯🇵 Tokyo ✨',
            type: 'Shadowsocks',
            providerName: 'flash-mount-8',
          ),
          Proxy(name: 'ordinary', type: 'Direct', providerName: 'subscription'),
          Proxy(
            name: 'unknown source',
            type: 'Direct',
            providerName: 'flash-mount-99',
          ),
        ],
      );
      await update(_trayState(groups: [group], selectedMap: {'Proxy': raw}));
      expect(members('Proxy').map((item) => item['label']), [
        label,
        'Source 🇭🇰 · already prefixed',
        'Other · 🇯🇵 Tokyo ✨',
        'ordinary',
        'unknown source',
      ]);
      expect(members('Proxy').first['checked'], isTrue);
      expect(members('Proxy').first['accessibilityLabel'], contains(label));
      expect(_item(showCall(), 'Proxy')['detail'], label);
      expect(_item(showCall(), 'Proxy')['accessibilityLabel'], contains(label));
      await select(members('Proxy').first);
      expect(recorded, ['switch:Proxy:$raw']);
      container
          .read(trayGroupMenuStatesProvider.notifier)
          .set(
            'Proxy',
            const TrayGroupMenuState(confirmedName: raw, pendingName: raw),
          );
      await update(_trayState(groups: [group]));
      expect(
        _item(showCall(), 'Proxy')['detail'],
        currentAppLocalizations.traySwitchingTo(label),
      );
    },
  );

  test(
    'tray follows proxy-page hidden setting, default and failed-read scope',
    () async {
      final recorded = <String>[];
      container.dispose();
      container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWithValue(null),
          profilesProvider.overrideWith(TestProfiles.new),
          proxiesActionProvider.overrideWith(
            () => _RecordingProxiesAction(recorded),
          ),
        ],
      );
      container.read(groupsProvider.notifier).value = [
        _proxyGroup.copyWith(hidden: false),
        _proxyGroup.copyWith(name: 'Hidden', hidden: true),
        _proxyGroup.copyWith(name: 'GLOBAL', hidden: true),
      ];
      Future<void> refresh() => update(container.read(trayStateProvider));
      List<String> groupNames() => _items(showCall())
          .where((item) => item['type'] == 'submenu')
          .map((item) => item['label'] as String)
          .toList();
      expect(
        container.read(proxiesStyleSettingProvider).showHiddenGroups,
        isFalse,
      );
      await refresh();
      expect(groupNames(), ['Proxy']);
      container
          .read(proxiesStyleSettingProvider.notifier)
          .update((state) => state.copyWith(showHiddenGroups: true));
      await refresh();
      expect(groupNames(), ['Proxy', 'Hidden']);
      expect(
        groupNames(),
        container
            .read(currentGroupsStateProvider)
            .value
            .map((group) => group.name),
      );
      final hiddenMember = members('Hidden').first;
      final hiddenTest = children('Hidden').first;
      final allTest = _item(showCall(), HotAction.delayTest.label);
      container
          .read(proxiesStyleSettingProvider.notifier)
          .update((state) => state.copyWith(showHiddenGroups: false));
      await select(hiddenMember);
      await select(hiddenTest);
      await select(allTest);
      expect(recorded, isEmpty);
      container.read(trayGroupsReadFailedProvider.notifier).set(true);
      await refresh();
      expect(groupNames(), isEmpty);
      container.read(trayGroupsReadFailedProvider.notifier).set(false);
      await refresh();
      expect(groupNames(), ['Proxy']);
      for (final mode in [Mode.global, Mode.direct]) {
        container
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(mode: mode));
        await refresh();
        expect(
          groupNames(),
          container
              .read(currentGroupsStateProvider)
              .value
              .map((group) => group.name),
        );
      }
    },
  );

  test(
    'preserves the complete main menu order and flat member order',
    () async {
      await update(_trayState(isStart: true, groups: [_proxyGroup]));
      final l10n = currentAppLocalizations;
      expect(_items(showCall()).map((item) => item['label'] ?? '|'), [
        l10n.show,
        l10n.trayStopCore,
        l10n.speedStatistics,
        l10n.monochromeIcon,
        '|',
        ...Mode.values.map((mode) => mode.label),
        '|',
        'Proxy',
        HotAction.delayTest.label,
        '|',
        l10n.trayTunMode,
        l10n.systemProxy,
        '|',
        l10n.autoLaunch,
        l10n.trayCopyProxyCommand,
        '|',
        l10n.exit,
      ]);
      expect(children('Proxy').map((item) => item['label'] ?? '|'), [
        l10n.trayTestLatency,
        '|',
        'A',
        'B',
        'C',
      ]);
      expect(
        children('Proxy').where((item) => item['type'] == 'submenu'),
        isEmpty,
      );
    },
  );

  test(
    'uses raw immediate confirmation rather than optimistic or leaf names',
    () async {
      final raw = _proxyGroup.copyWith(now: 'B');
      container.read(groupsProvider.notifier).value = [raw];
      await update(
        _trayState(
          isStart: true,
          groups: [_proxyGroup],
          selectedMap: {'Proxy': 'A'},
        ),
      );
      expect(_item(showCall(), 'Proxy')['detail'], 'B');
      expect(
        members(
          'Proxy',
        ).where((item) => item['checked'] == true).single['label'],
        'B',
      );
      container.read(groupsProvider.notifier).value = [
        raw.copyWith(now: 'not-a-member'),
      ];
      await update(
        _trayState(
          isStart: true,
          groups: [_proxyGroup],
          selectedMap: {'Proxy': 'A'},
        ),
      );
      expect(_item(showCall(), 'Proxy')['detail'], '—');
      expect(
        members('Proxy').where((item) => item['checked'] == true),
        isEmpty,
      );
      expect(
        _item(showCall(), 'Proxy')['accessibilityLabel'],
        contains(currentAppLocalizations.traySelectionUnknown),
      );
    },
  );

  for (final type in [
    GroupType.Selector,
    GroupType.URLTest,
    GroupType.Fallback,
  ]) {
    test('stopped $type prefers the valid configured choice', () async {
      expect(container.read(isStartProvider), isFalse);
      final group = _proxyGroup.copyWith(type: type, now: 'B');
      container.read(groupsProvider.notifier).value = [group];
      await update(_trayState(groups: [group], selectedMap: {'Proxy': 'A'}));
      expect(_item(showCall(), 'Proxy')['detail'], 'A');
      expect(members('Proxy').first['checked'], isTrue);
      expect(members('Proxy')[1]['checked'], isFalse);

      await update(
        _trayState(groups: [group], selectedMap: {'Proxy': 'removed'}),
      );
      expect(_item(showCall(), 'Proxy')['detail'], 'B');
      expect(members('Proxy').first['checked'], isFalse);
      expect(members('Proxy')[1]['checked'], isTrue);
    });
  }

  test(
    'nested groups stay flat and the parent names the immediate group',
    () async {
      const nested = Group(
        name: 'Nested',
        type: GroupType.URLTest,
        now: 'Leaf',
        all: [Proxy(name: 'Leaf', type: 'Shadowsocks')],
      );
      const parent = Group(
        name: 'Parent',
        type: GroupType.Selector,
        now: 'Nested',
        all: [Proxy(name: 'Nested', type: 'URLTest')],
      );
      container.read(groupsProvider.notifier).value = [parent, nested];
      await update(_trayState(isStart: true, groups: [parent]));
      expect(_item(showCall(), 'Parent')['detail'], 'Nested');
      expect(members('Parent').single['label'], 'Nested');
      expect(_labels(showCall()), isNot(contains('Nested')));
      expect(
        children('Parent').where((item) => item['type'] == 'submenu'),
        isEmpty,
      );
    },
  );

  test('load balancing and empty groups have honest visible states', () async {
    final balancing = _proxyGroup.copyWith(
      type: GroupType.LoadBalance,
      now: 'A',
    );
    final empty = _proxyGroup.copyWith(name: 'Empty', all: []);
    container.read(groupsProvider.notifier).value = [balancing, empty];
    await update(_trayState(isStart: true, groups: [balancing, empty]));
    expect(
      _item(showCall(), 'Proxy')['detail'],
      currentAppLocalizations.trayMultipleNodes,
    );
    expect(members('Proxy').where((item) => item['checked'] == true), isEmpty);
    final emptyRow = children('Empty').last;
    expect(emptyRow['label'], currentAppLocalizations.trayNoAvailableMembers);
    expect(emptyRow['enabled'], isFalse);
    expect(children('Empty').first['enabled'], isFalse);
  });

  test('pending and failed switches retain the confirmed check', () async {
    container.read(groupsProvider.notifier).value = [
      _proxyGroup.copyWith(now: 'B'),
    ];
    final states = container.read(trayGroupMenuStatesProvider.notifier);
    states.set(
      'Proxy',
      const TrayGroupMenuState(confirmedName: 'A', pendingName: 'B'),
    );
    await update(_trayState(isStart: true, groups: [_proxyGroup]));
    expect(
      _item(showCall(), 'Proxy')['detail'],
      currentAppLocalizations.traySwitchingTo('B'),
    );
    expect(members('Proxy').first['checked'], isTrue);
    expect(
      members('Proxy').map((item) => item['enabled']),
      everyElement(isFalse),
    );
    for (final failure in TraySwitchFailure.values) {
      states.set(
        'Proxy',
        TrayGroupMenuState(
          confirmedName: 'A',
          switchFailure: failure,
          pendingName: failure == TraySwitchFailure.unconfirmed ? 'B' : null,
        ),
      );
      await update(_trayState(isStart: true, groups: [_proxyGroup]));
      expect(members('Proxy').first['checked'], isTrue);
      expect(
        children('Proxy')[2]['label'],
        failure == TraySwitchFailure.failed
            ? currentAppLocalizations.trayCouldNotSwitch
            : currentAppLocalizations.traySwitchUnconfirmed,
      );
      expect(children('Proxy')[2]['enabled'], isFalse);
      expect(
        _item(showCall(), 'Proxy')['detail'],
        failure == TraySwitchFailure.failed
            ? currentAppLocalizations.trayCouldNotSwitch
            : currentAppLocalizations.traySwitchUnconfirmed,
      );
      if (failure == TraySwitchFailure.unconfirmed) {
        expect(
          members('Proxy').map((item) => item['enabled']),
          everyElement(isFalse),
        );
      }
    }
  });

  test(
    'a failed read keeps only previously visible groups, disabled',
    () async {
      final hidden = _proxyGroup.copyWith(name: 'Hidden', hidden: true);
      container.read(groupsProvider.notifier).value = [
        _proxyGroup.copyWith(now: 'A'),
        hidden,
      ];
      await update(_trayState(isStart: true, groups: [_proxyGroup]));
      container.read(trayGroupsReadFailedProvider.notifier).set(true);
      container.read(groupsProvider.notifier).value = [];
      await update(_trayState(isStart: true));
      expect(_labels(showCall()), contains('Proxy'));
      expect(_labels(showCall()), isNot(contains('Hidden')));
      expect(
        _item(showCall(), 'Proxy')['detail'],
        currentAppLocalizations.trayCouldNotLoad,
      );
      expect(
        children('Proxy')[2]['label'],
        currentAppLocalizations.trayCouldNotLoad,
      );
      expect(
        members('Proxy').map((item) => item['enabled']),
        everyElement(isFalse),
      );
      expect(members('Proxy').first['checked'], isTrue);
      await update(_trayState(mode: Mode.direct));
      await update(_trayState());
      expect(_labels(showCall()), isNot(contains('Proxy')));
    },
  );

  test(
    'profile changes and successful no-data clear the failed-read cache',
    () async {
      await update(_trayState(groups: [_proxyGroup]));
      container.read(trayGroupsReadFailedProvider.notifier).set(true);
      container.read(currentProfileIdProvider.notifier).value = 9;
      await update(_trayState());
      expect(_labels(showCall()), isNot(contains('Proxy')));
      container.read(trayGroupsReadFailedProvider.notifier).set(false);
      await update(_trayState(groups: [_proxyGroup]));
      await update(_trayState());
      container.read(trayGroupsReadFailedProvider.notifier).set(true);
      await update(_trayState());
      expect(_labels(showCall()), isNot(contains('Proxy')));
    },
  );

  test(
    'badges normalize zero, preserve DIRECT results and use scheme color pairs',
    () async {
      final cases = <(String, String, int?)>[
        ('unknown', 'Shadowsocks', null),
        ('zero', 'Shadowsocks', 0),
        ('direct', 'Direct', null),
        ('reject', 'Reject', null),
        ('direct-result', 'Direct', 120),
        ('reject-result', 'Reject', -1),
        ('fast', 'Shadowsocks', 599),
        ('slow', 'Shadowsocks', 600),
        ('failed', 'Shadowsocks', -2),
      ];
      final group = _proxyGroup.copyWith(
        all: [
          for (final (name, type, _) in cases) Proxy(name: name, type: type),
        ],
      );
      final delays = {
        for (final (name, _, value) in cases)
          if (value != null) name: value,
      };
      container.dispose();
      container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWithValue(null),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          trayDelaysProvider.overrideWithValue({'Proxy': delays}),
        ],
      );
      for (final brightness in Brightness.values) {
        container
            .read(themeSettingProvider.notifier)
            .update(
              (state) => state.copyWith(
                themeMode: brightness == Brightness.light
                    ? ThemeMode.light
                    : ThemeMode.dark,
              ),
            );
        final scheme = container.read(genColorSchemeProvider(brightness));
        await update(_trayState(groups: [group]));
        final badges = members(
          'Proxy',
        ).map((item) => item['badge'] as Map).toList();
        final l10n = currentAppLocalizations;
        expect(badges.map((badge) => badge['label']), [
          '—',
          '—',
          l10n.direct,
          l10n.trayReject,
          l10n.trayLatencyBadge(120),
          l10n.timeout,
          l10n.trayLatencyBadge(599),
          l10n.trayLatencyBadge(600),
          l10n.delayFailed,
        ]);
        for (final i in [0, 1, 2, 3]) {
          expect(
            badges[i]['background'],
            SurfaceLevel.inset.colorOf(scheme).toARGB32(),
          );
          expect(badges[i]['foreground'], scheme.onSurfaceVariant.toARGB32());
        }
        expect(
          members('Proxy')[6]['accessibilityLabel'],
          contains(l10n.trayLatencyMilliseconds(599)),
        );
        expect(badges[6]['background'], scheme.successContainer.toARGB32());
        expect(badges[6]['foreground'], scheme.onSuccessContainer.toARGB32());
        expect(badges[7]['background'], scheme.warningContainer.toARGB32());
        expect(badges[7]['foreground'], scheme.onWarningContainer.toARGB32());
        expect(badges[8]['background'], scheme.errorContainer.toARGB32());
        expect(badges[8]['foreground'], scheme.onErrorContainer.toARGB32());
        expect(
          (members('Proxy').first['accessibilityLabel'] as String),
          contains(l10n.trayLatencyUnknown),
        );
      }
    },
  );

  test(
    'pending badges resolve nested actual target and ignore stale values',
    () async {
      const nested = Group(
        name: 'Nested',
        type: GroupType.URLTest,
        now: 'Leaf',
        testUrl: 'https://nested.test',
        all: [Proxy(name: 'Leaf', type: 'Shadowsocks')],
      );
      final parent = _proxyGroup.copyWith(
        all: [const Proxy(name: 'Nested', type: 'URLTest')],
      );
      container.read(groupsProvider.notifier).value = [parent, nested];
      container
          .read(pendingDelayTestsProvider.notifier)
          .apply(acquired: [delayTestKey('https://nested.test', 'Leaf')]);
      await update(_trayState(groups: [parent]));
      final badge = members('Proxy').single['badge'] as Map;
      final scheme = container.read(genColorSchemeProvider(Brightness.light));
      expect(badge['label'], currentAppLocalizations.trayTesting);
      expect(
        badge['background'],
        SurfaceLevel.inset.colorOf(scheme).toARGB32(),
      );
      expect(badge['foreground'], scheme.onSurfaceVariant.toARGB32());
    },
  );

  test(
    'group testing is scoped and disabled only for that running group',
    () async {
      final recorded = <String>[];
      container.dispose();
      container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWithValue(null),
          proxiesActionProvider.overrideWith(
            () => _RecordingProxiesAction(recorded),
          ),
        ],
      );
      final other = _proxyGroup.copyWith(name: 'Other');
      await update(_trayState(groups: [_proxyGroup, other]));
      await select(children('Proxy').first);
      expect(recorded, ['Proxy:false']);
      container.read(delayTestingGroupsProvider.notifier).start('Proxy');
      await update(_trayState(groups: [_proxyGroup, other]));
      expect(children('Proxy').first['enabled'], isFalse);
      expect(children('Other').first['enabled'], isTrue);
      expect(_item(showCall(), HotAction.delayTest.label)['enabled'], isTrue);
      await select(children('Proxy').first);
      expect(recorded, ['Proxy:false']);
    },
  );

  test('only selectable group classes activate members', () async {
    final recorded = <String>[];
    container.dispose();
    container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWithValue(null),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        proxiesActionProvider.overrideWith(
          () => _RecordingProxiesAction(recorded),
        ),
      ],
    );
    final groups = [
      for (final type in GroupType.values)
        _proxyGroup.copyWith(name: type.name, type: type, now: 'A'),
    ];
    container.read(groupsProvider.notifier).value = groups;
    await update(_trayState(isStart: true, groups: groups));
    for (final type in GroupType.values) {
      final enabled = type != GroupType.LoadBalance && type != GroupType.Relay;
      expect(members(type.name).last['enabled'], enabled);
      await select(members(type.name).last);
    }
    expect(recorded, [
      'switch:Selector:C',
      'switch:URLTest:C',
      'switch:Fallback:C',
    ]);
  });

  test(
    'stopped configured choices can activate a different raw member',
    () async {
      final recorded = <String>[];
      container.dispose();
      container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWithValue(null),
          proxiesActionProvider.overrideWith(
            () => _RecordingProxiesAction(recorded),
          ),
        ],
      );
      container.read(groupsProvider.notifier).value = [
        _proxyGroup.copyWith(now: 'B'),
      ];
      await update(
        _trayState(groups: [_proxyGroup], selectedMap: {'Proxy': 'A'}),
      );
      expect(members('Proxy').first['checked'], isTrue);
      expect(members('Proxy')[1]['checked'], isFalse);
      expect(members('Proxy')[1]['enabled'], isTrue);
      await select(members('Proxy')[1]);
      expect(recorded, ['switch:Proxy:B']);
    },
  );

  test('retained group callbacks reject profile and mode changes', () async {
    final recorded = <String>[];
    container.dispose();
    container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWithValue(null),
        proxiesActionProvider.overrideWith(
          () => _RecordingProxiesAction(recorded),
        ),
      ],
    );
    container.read(currentProfileIdProvider.notifier).value = 1;
    await update(_trayState(groups: [_proxyGroup]));
    final oldMember = members('Proxy')[1];
    final oldTest = children('Proxy').first;
    final oldAllGroupsTest = _item(showCall(), HotAction.delayTest.label);
    container.read(currentProfileIdProvider.notifier).value = 2;
    await select(oldMember);
    await select(oldTest);
    await select(oldAllGroupsTest);
    expect(recorded, isEmpty);
    container.read(currentProfileIdProvider.notifier).value = 1;
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: Mode.global));
    await select(oldMember);
    await select(oldTest);
    await select(oldAllGroupsTest);
    expect(recorded, isEmpty);
  });

  test(
    'icon workers prepare every source without starving after four',
    () async {
      var active = 0;
      var maximumActive = 0;
      final prepared = <String>[];
      final groups = [
        for (var i = 0; i < 11; i++)
          _proxyGroup.copyWith(name: 'Group $i', icon: 'icon-$i'),
      ];
      final withIcons = AppTray.forPlatform(
        isMacOS: true,
        isWindows: false,
        iconReader: (source) async {
          active++;
          if (active > maximumActive) maximumActive = active;
          await Future<void>.delayed(Duration.zero);
          prepared.add(source);
          active--;
          return Uint8List.fromList([1, 2, 3]);
        },
      );
      await update(_trayState(groups: groups), on: withIcons);
      expect(prepared.toSet(), groups.map((group) => group.icon).toSet());
      expect(maximumActive, 4);
      expect(active, 0);
      for (final group in groups) {
        expect((_item(showCall(), group.name)['icon'] as Map)['png'], 'AQID');
      }
    },
  );

  test(
    'a timed-out nonnullable icon reader does not overlap its next acquisition',
    () async {
      final admitted = <Completer<Uint8List>>[];
      final groups = [
        for (var i = 0; i < 9; i++)
          _proxyGroup.copyWith(name: 'Group $i', icon: 'icon-$i'),
      ];
      final withIcons = AppTray.forPlatform(
        isMacOS: true,
        isWindows: false,
        iconReader: (source) {
          final result = Completer<Uint8List>();
          admitted.add(result);
          return result.future;
        },
      );
      try {
        await update(_trayState(groups: groups), on: withIcons);
        expect(admitted, hasLength(4));
        for (final group in groups) {
          expect(
            _item(showCall(), group.name)['icon'] as Map,
            isNot(contains('png')),
          );
        }
      } finally {
        for (final result in admitted) {
          result.complete(Uint8List(0));
        }
      }
    },
  );

  group('a platform that is not macOS', () {
    late AppTray windows;

    setUp(() {
      windows = AppTray.forPlatform(isMacOS: false, isWindows: true);
    });

    test('gets a plain icon, no group submenus and no speed toggle', () async {
      await update(
        _trayState(
          isStart: true,
          groups: [
            const Group(
              name: 'Proxy',
              type: GroupType.Selector,
              all: [Proxy(name: 'A', type: 'Direct')],
            ),
          ],
        ),
        on: windows,
      );

      expect(showCall()!.image.template, isFalse);
      expect(
        _items(showCall()).where((item) => item['type'] == 'submenu'),
        isEmpty,
      );
      expect(
        _labels(showCall()),
        isNot(contains(currentAppLocalizations.speedStatistics)),
      );
      expect(
        _labels(showCall()),
        isNot(contains(currentAppLocalizations.monochromeIcon)),
      );
      expect(_labels(showCall()), isNot(contains(HotAction.delayTest.label)));
    });

    test('joins modifiers with + in the hotkey hints', () async {
      await update(
        _trayState(
          hotKeys: {
            HotAction.view: _bind(HotAction.view, PhysicalKeyboardKey.keyV),
          },
        ),
        on: windows,
      );

      expect(
        _item(showCall(), currentAppLocalizations.show)['detail'],
        'Ctrl+Shift+V',
      );
    });

    test('never pushes a tray title', () async {
      await windows.updateTitle(showTrayTitle: true, traffic: const Traffic());

      expect(host.titles, isEmpty);
    });
  });
}

class _RecordingProxiesAction extends ProxiesAction {
  _RecordingProxiesAction(this.recorded);

  final List<String> recorded;

  @override
  Future<void> changeProxyForTray({
    required String groupName,
    required String proxyName,
  }) async {
    recorded.add('switch:$groupName:$proxyName');
  }

  @override
  Future<void> delayTestGroups(List<Group> groups) async {
    recorded.add('all-groups');
  }

  @override
  Future<void> delayTestPageGroup(
    String groupName, {
    bool matchSearch = true,
  }) async {
    recorded.add('$groupName:$matchSearch');
  }
}
