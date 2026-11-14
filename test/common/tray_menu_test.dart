import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/l10n_labels.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
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
import 'package:intl/intl.dart';
import 'package:riverpod/riverpod.dart';
import 'package:tray/tray.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_profiles.dart';

const _channel = MethodChannel('tray');

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
  );
}

List<Map<Object?, Object?>> _items(MethodCall? call) {
  final menu = (call?.arguments as Map?)?['menu'] as List?;
  return menu?.cast<Map<Object?, Object?>>() ?? const [];
}

Map<Object?, Object?> _item(MethodCall? call, String label) {
  return _items(call).firstWhere((item) => item['label'] == label);
}

List<String> _labels(MethodCall? call) {
  return _items(call).map((item) => item['label']).whereType<String>().toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late ProviderContainer container;
  late AppTray tray;

  late Directory root;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('tray_menu_test');
    await useAppPaths(root);
    await AppLocalizations.load(const Locale('en'));
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
    calls = [];
    tray = AppTray.forPlatform(isMacOS: true, isWindows: false);
    container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWithValue(null),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        currentBrightnessProvider.overrideWithValue(Brightness.light),
      ],
    );
    Tray.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  MethodCall? showCall() {
    for (final call in calls.reversed) {
      if (call.method == 'show') {
        return call;
      }
    }
    return null;
  }

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

  test('builds the stopped menu without the running-only toggles', () async {
    await update(_trayState());

    final labels = _labels(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.show));
    expect(labels, contains(l10n.start));
    expect(labels, contains(l10n.autoLaunch));
    expect(labels, contains(l10n.copyEnvVar));
    expect(labels, contains(l10n.exit));
    expect(labels, isNot(contains(l10n.tun)));
    expect(labels, isNot(contains(l10n.systemProxy)));
  });

  test('adds TUN and system proxy toggles once the core is running', () async {
    await update(_trayState(isStart: true));

    final labels = _labels(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.stop), reason: 'start flips to stop');
    expect(labels, contains(l10n.tun));
    expect(labels, contains(l10n.systemProxy));
  });

  group('safe mode', () {
    test('keeps the full menu', () async {
      await update(_trayState(isStart: true, safeMode: true));

      final labels = _labels(showCall());
      final l10n = currentAppLocalizations;
      expect(labels, contains(l10n.stop));
      expect(labels, contains(l10n.tun));
      expect(labels, contains(l10n.systemProxy));
      expect(labels, contains(l10n.copyEnvVar));
    });

    test('names the mode in the tooltip and ships the safe icon', () async {
      await update(_trayState(isStart: true, safeMode: true));

      final arguments = showCall()!.arguments as Map;
      final l10n = currentAppLocalizations;
      expect(arguments['toolTip'], '$appName (${l10n.safeMode})');
      final reps = ((arguments['icon'] as Map)['reps'] as List).cast<Map>();
      final base = reps.firstWhere((rep) => rep['scale'] == 1.0);
      expect(
        base['bytes'],
        base64Encode(
          File('assets/images/tray/macos/status_4.png').readAsBytesSync(),
        ),
      );
    });
  });

  test('offers every outbound mode as a menu entry', () async {
    await update(_trayState(mode: Mode.global));

    final checkedModes = _items(showCall())
        .where((item) => item['checked'] == true)
        .map((item) => item['label'])
        .toList();
    expect(checkedModes, contains(Intl.message(Mode.global.name)));
  });

  test('sends icon, tooltip and menu in a single show call', () async {
    await update(_trayState(isStart: true, tunEnable: true));

    final showCalls = calls.where((call) => call.method == 'show').toList();
    expect(showCalls, hasLength(1));

    final arguments = showCalls.single.arguments as Map;
    expect(arguments['toolTip'], appName);
    expect(arguments['menu'], isNotEmpty);
    final reps = ((arguments['icon'] as Map)['reps'] as List).cast<Map>();
    expect(reps.map((rep) => rep['scale']), containsAll([1.0, 2.0, 3.0, 4.0]));
    expect(reps.map((rep) => rep['bytes']), everyElement(isNotEmpty));
    expect((arguments['icon'] as Map)['isTemplate'], isTrue);
  });

  test('ships the color status icon once monochrome is off', () async {
    await update(
      _trayState(isStart: true, tunEnable: true, monochromeTrayIcon: false),
    );

    final arguments = showCall()!.arguments as Map;
    expect((arguments['icon'] as Map)['isTemplate'], isFalse);
    final reps = ((arguments['icon'] as Map)['reps'] as List).cast<Map>();
    final base = reps.firstWhere((rep) => rep['scale'] == 1.0);
    expect(
      base['bytes'],
      base64Encode(
        File('assets/images/tray/unix/rule_tun.png').readAsBytesSync(),
      ),
    );
    expect(
      _item(showCall(), currentAppLocalizations.monochromeIcon)['checked'],
      isFalse,
    );
  });

  test('changing the running mode immediately sends its new icon', () async {
    for (final mode in Mode.values) {
      calls.clear();
      await update(_trayState(isStart: true, mode: mode));
      final arguments = showCall()!.arguments as Map;
      final reps = ((arguments['icon'] as Map)['reps'] as List).cast<Map>();
      expect(
        reps.firstWhere((rep) => rep['scale'] == 1.0)['bytes'],
        base64Encode(
          File('assets/images/tray/macos/${mode.name}.png').readAsBytesSync(),
        ),
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
            calls.clear();
            await update(
              _trayState(
                isStart: true,
                mode: mode,
                tunEnable: tun,
                monochromeTrayIcon: mono,
              ),
            );
            final icon = (showCall()!.arguments as Map)['icon'] as Map;
            expect(icon['isTemplate'], mono);
            final reps = (icon['reps'] as List).cast<Map>();
            expect(
              reps.firstWhere((rep) => rep['scale'] == 1.0)['bytes'],
              base64Encode(
                File(
                  'assets/images/tray/$directory/${mode.name}${tun ? '_tun' : ''}.png',
                ).readAsBytesSync(),
              ),
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
          calls.clear();
          await update(state.copyWith(monochromeTrayIcon: mono));
          final icon = (showCall()!.arguments as Map)['icon'] as Map;
          final reps = (icon['reps'] as List).cast<Map>();
          expect(
            reps.firstWhere((rep) => rep['scale'] == 1.0)['bytes'],
            base64Encode(
              File('assets/images/tray/$directory/$name.png').readAsBytesSync(),
            ),
          );
        }
      }
    },
  );

  test('skips the platform call when the tray state is unchanged', () async {
    await update(_trayState(isStart: true));
    await update(_trayState(isStart: true));

    expect(calls.where((call) => call.method == 'show'), hasLength(1));
  });

  test('menu item ids are stable across identical rebuilds', () async {
    await update(_trayState());
    final first = _items(showCall()).map((item) => item['id']).toList();

    Tray.instance.resetForTesting();
    calls.clear();

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
    final children = (submenu['items'] as List).cast<Map<Object?, Object?>>();
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
    expect(_item(call, l10n.tun)['detail'], '⌃⇧T');
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
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('onMenuItemSelected', {
              'id': item['id'],
              'menuGeneration':
                  (showCall()!.arguments as Map)['menuGeneration'],
            }),
          ),
          null,
        );
  }

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
        l10n.stop,
        l10n.speedStatistics,
        l10n.monochromeIcon,
        '|',
        ...Mode.values.map((mode) => mode.label),
        '|',
        'Proxy',
        HotAction.delayTest.label,
        '|',
        l10n.tun,
        l10n.systemProxy,
        '|',
        l10n.autoLaunch,
        l10n.copyEnvVar,
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

      final arguments = showCall()!.arguments as Map;
      expect((arguments['icon'] as Map)['isTemplate'], isFalse);
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

      expect(calls.where((call) => call.method == 'setTitle'), isEmpty);
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
