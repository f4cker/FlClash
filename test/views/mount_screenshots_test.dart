// Renders the mount entry, sheet and dialog states to PNG for review. Off by
// default:
//   MOUNT_SCREENSHOTS=<dir> flutter test test/views/mount_screenshots_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/mount.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart' show ThemeMode;

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'mount_fixtures.dart';

final _outDir = Platform.environment['MOUNT_SCREENSHOTS'];
const _cjkCollection = '/System/Library/Fonts/Hiragino Sans GB.ttc';

/// The window of the review reports, in logical pixels, and its ratio.
const reportSize = Size(1054, 1148 * 1054 / 1568);
const reportRatio = 1568 / 1054;

/// Each face of a TrueType collection as a font of its own, since the engine
/// reads only the first face of a collection.
List<ByteData> _collectionFaces(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final faces = <ByteData>[];
  for (var face = 0; face < data.getUint32(8); face++) {
    final header = data.getUint32(12 + face * 4);
    final tables = data.getUint16(header + 4);
    final out = BytesBuilder()..add(bytes.sublist(header, header + 12));
    final body = BytesBuilder();
    var at = 12 + tables * 16;
    for (var i = 0; i < tables; i++) {
      final entry = header + 12 + i * 16;
      final offset = data.getUint32(entry + 8);
      final length = data.getUint32(entry + 12);
      final record = ByteData(16)
        ..setUint32(0, data.getUint32(entry))
        ..setUint32(4, data.getUint32(entry + 4))
        ..setUint32(8, at)
        ..setUint32(12, length);
      out.add(record.buffer.asUint8List());
      final padded = (length + 3) & ~3;
      body
        ..add(bytes.sublist(offset, offset + length))
        ..add(Uint8List(padded - length));
      at += padded;
    }
    out.add(body.takeBytes());
    faces.add(ByteData.sublistView(out.takeBytes()));
  }
  return faces;
}

Future<void> _loadFont(String family, List<ByteData> fonts) async {
  final loader = FontLoader(family);
  for (final font in fonts) {
    loader.addFont(Future.value(font));
  }
  await loader.load();
}

class _NeverMounts extends FakeMounts {
  _NeverMounts() : super(null);

  final _never = Completer<MountPanel>();

  @override
  Future<MountPanel> loadPanel(int targetId) => _never.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set MOUNT_SCREENSHOTS to an output directory'
      : null;

  setUpAll(() async {
    if (skip != null) {
      return;
    }
    // The shots are for review, not for telling a debug build apart.
    WidgetsApp.debugAllowBannerOverride = false;
    await useAppPaths(Directory.systemTemp.createTempSync('mount_shots'));
    await _loadFont(
      'Roboto',
      _collectionFaces(File(_cjkCollection).readAsBytesSync()),
    );
    Directory(_outDir!).createSync(recursive: true);
  });

  final work = sub('机场 Work');
  final air = sub('Air 订阅');
  final sea = sub('Sea 云');
  final odd = sub('旧格式订阅');
  final fresh = sub('新导入');
  final broken = Profile.normal(label: '备用配置');
  final mine = Profile.custom(label: '自定义');
  final profiles = [target, work, air, sea, odd, fresh, broken, mine];
  // Sheet-only sources, absent from the cards behind it.
  final relayed = sub('中转订阅');
  final relayedSpare = sub('中转备用');
  final legacy = sub('旧格式备用');
  final tailnet = sub('仅 Tailscale');

  final stored = MountTargetState(
    targetId: target.id,
    sourceIds: [air.id, sea.id],
    groups: const ['手动'],
    version: 3,
  );
  final sources = [
    item(air, mounted: true, count: 42, failure: MountSourceFailure.fetch),
    item(sea, mounted: true, count: 18, tailscaleExcluded: 2),
    item(work, state: MountSourceState.empty, count: 0),
    item(odd, state: MountSourceState.unsupported, count: 0),
    item(fresh, state: MountSourceState.notFetched, count: 0),
  ];
  final autoGroups = MountTarget(
    groups: [
      groupInfo(
        '全部节点',
        kind: MountGroupKind.auto,
        collects: MountGroupCollects.all,
      ),
      groupInfo(
        '订阅节点',
        kind: MountGroupKind.auto,
        collects: MountGroupCollects.providers,
      ),
      groupInfo(
        '香港',
        kind: MountGroupKind.auto,
        collects: MountGroupCollects.all,
        filter: true,
      ),
      groupInfo('手动'),
      groupInfo('自动选择', type: 'url-test', filter: true),
      groupInfo('故障转移', type: 'fallback', emptyFallback: 'DIRECT'),
      groupInfo('均衡', type: 'load-balance'),
    ],
  );
  const runtime = MountRuntimeState(
    report: MountReport(
      renamed: 2,
      groups: [
        // Only 订阅节点 holds nothing but providers; the others also hold
        // base proxies, through include-all or 手动's own list.
        MountGroupReport(
          name: '全部节点',
          via: MountGroupVia.auto,
          protection: MountProtection.original,
        ),
        MountGroupReport(
          name: '香港',
          via: MountGroupVia.auto,
          protection: MountProtection.original,
        ),
        MountGroupReport(
          name: '订阅节点',
          via: MountGroupVia.auto,
          protection: MountProtection.reject,
        ),
        MountGroupReport(
          name: '手动',
          via: MountGroupVia.use,
          protection: MountProtection.original,
        ),
      ],
    ),
    groups: [
      MountRuntimeGroup(name: '全部节点', present: true, members: 60),
      MountRuntimeGroup(name: '香港', present: true, empty: true),
      MountRuntimeGroup(name: '订阅节点', present: true, members: 58),
      MountRuntimeGroup(name: '手动', present: true, members: 64),
    ],
  );

  final boundary = GlobalKey();
  late ProviderContainer container;

  Future<void> pumpProfiles(
    WidgetTester tester,
    FakeMounts mounts, {
    Size size = reportSize,
    ThemeMode themeMode = ThemeMode.light,
    Map<int, Future<MountCardSummary?> Function()> summaries = const {},
  }) async {
    await mockPreferences();
    // The card behind the sheet shows what the sheet's own relation counts.
    final panel = mounts.panel;
    final cards = {
      if (panel != null)
        target.id: () async => mountCardSummaryOf(panel.stored, {
          for (final source in panel.sources) source.profile.id: ?source.record,
        }),
      ...summaries,
    };
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(profiles)),
        currentProfileIdProvider.overrideWithBuild((_, _) => target.id),
        mountActionProvider.overrideWith(() => mounts),
        for (final profile in profiles)
          if (profile.type != ProfileType.custom)
            mountCardSummaryProvider(profile.id).overrideWith(
              (_) => cards[profile.id]?.call() ?? Future.value(null),
            ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).update((_) => size);
    tester.view.physicalSize = size * reportRatio;
    tester.view.devicePixelRatio = reportRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: const Locale('zh', 'CN'),
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: themeMode,
              child: const ProfilesView(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await settle(tester);
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  void shot(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, body, skip: skip != null);
  }

  tearDownAll(() => WidgetsApp.debugAllowBannerOverride = true);

  final cardSummaries = <int, Future<MountCardSummary?> Function()>{
    target.id: () async => const MountCardSummary(mounted: 2, failed: 1),
    work.id: () async => const MountCardSummary(mounted: 1, failed: 0),
    broken.id: () async => throw StateError('unreadable'),
  };

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text(target.label),
          matching: find.byType(ProfileItem),
        ),
        matching: find.byType(MountPill),
      ),
    );
    await settle(tester);
  }

  FakeMounts sheetMounts({
    MountTarget? groups,
    MountTargetState? storedState,
    List<MountSourceItem>? items,
    MountRuntimeState? state = runtime,
  }) => FakeMounts(
    panelOf(items ?? sources, groups: groups, stored: storedState ?? stored),
  )..runtime = state;

  Future<void> scrollSheetTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find
          .descendant(
            of: find.byType(MountSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(MountSheet), matching: find.text(text));

  shot('01-cards', (tester) async {
    await pumpProfiles(tester, FakeMounts(null), summaries: cardSummaries);
    await shoot(tester, '01-cards');
  });

  shot('02-cards-narrow', (tester) async {
    await pumpProfiles(
      tester,
      FakeMounts(null),
      size: const Size(380, 700),
      summaries: cardSummaries,
    );
    await shoot(tester, '02-cards-narrow');
  });

  shot('03-sheet-auto', (tester) async {
    await pumpProfiles(tester, sheetMounts(groups: autoGroups));
    await openSheet(tester);
    await shoot(tester, '03-sheet-auto');
  });

  shot('04-sheet-auto-groups', (tester) async {
    await pumpProfiles(tester, sheetMounts(groups: autoGroups));
    await openSheet(tester);
    await scrollSheetTo(tester, '均衡');
    await tester.tap(inSheet('自动选择'));
    await settle(tester);
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(MountSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    position.jumpTo(position.maxScrollExtent);
    await shoot(tester, '04-sheet-auto-groups');
  });

  shot('05-sheet-auto-dark', (tester) async {
    await pumpProfiles(
      tester,
      sheetMounts(groups: autoGroups),
      themeMode: ThemeMode.dark,
    );
    await openSheet(tester);
    await shoot(tester, '05-sheet-auto-dark');
  });

  shot('06-sheet-pick-required', (tester) async {
    await pumpProfiles(
      tester,
      sheetMounts(
        groups: MountTarget(
          groups: [
            groupInfo('节点选择'),
            groupInfo('自动选择', type: 'url-test'),
            groupInfo('故障转移', type: 'fallback'),
          ],
        ),
        storedState: MountTargetState(targetId: target.id, version: 1),
        items: [item(air), item(sea)],
        state: null,
      ),
    );
    await openSheet(tester);
    await tester.tap(inSheet(air.label));
    await scrollSheetTo(tester, '故障转移');
    await shoot(tester, '06-sheet-pick-required');
  });

  shot('07-sheet-no-group', (tester) async {
    await pumpProfiles(
      tester,
      sheetMounts(groups: const MountTarget(), state: null),
    );
    await openSheet(tester);
    await tester.tap(inSheet(sea.label));
    await shoot(tester, '07-sheet-no-group');
  });

  shot('08-sheet-groups-failed', (tester) async {
    await pumpProfiles(tester, sheetMounts(groups: null, state: null));
    await openSheet(tester);
    await shoot(tester, '08-sheet-groups-failed');
  });

  shot('09-sheet-unknown', (tester) async {
    await pumpProfiles(
      tester,
      sheetMounts(
        groups: autoGroups,
        storedState: stored.copyWith(
          pending: const MountOperation(
            kind: MountOperationKind.save,
            version: 3,
          ),
        ),
      ),
    );
    await openSheet(tester);
    await shoot(tester, '09-sheet-unknown');
  });

  shot('10-sheet-saving', (tester) async {
    final mounts = sheetMounts(groups: autoGroups)..saveGate = Completer();
    await pumpProfiles(tester, mounts);
    await openSheet(tester);
    await tester.tap(inSheet(work.label));
    await tester.pump();
    await tester.tap(find.text(currentAppLocalizations.mountSave));
    await shoot(tester, '10-sheet-saving');
    mounts.saveGate!.complete();
  });

  shot('11-sheet-apply-kept', (tester) async {
    final mounts = sheetMounts(groups: autoGroups)
      ..saveResult = const MountSaveResult(
        outcome: MountSaveOutcome.applyFailedKept,
      );
    await pumpProfiles(tester, mounts);
    await openSheet(tester);
    await tester.tap(inSheet(work.label));
    await tester.pump();
    await tester.tap(find.text(currentAppLocalizations.mountSave));
    await shoot(tester, '11-sheet-apply-kept');
  });

  shot('12-sheet-loading', (tester) async {
    await pumpProfiles(tester, _NeverMounts());
    await openSheet(tester);
    await shoot(tester, '12-sheet-loading');
    await tester.pump(mountLoadTimeout);
  });

  shot('13-sheet-load-failed', (tester) async {
    await pumpProfiles(tester, FakeMounts(null)..loadError = StateError('x'));
    await openSheet(tester);
    await shoot(tester, '13-sheet-load-failed');
  });

  shot('14-sheet-empty', (tester) async {
    await pumpProfiles(
      tester,
      FakeMounts(panelOf(const [], groups: autoGroups)),
    );
    await openSheet(tester);
    await shoot(tester, '14-sheet-empty');
  });

  shot('15-dialog-unmount-many', (tester) async {
    await pumpProfiles(tester, sheetMounts(groups: autoGroups));
    await openSheet(tester);
    await tester.tap(inSheet(air.label));
    await tester.tap(inSheet(sea.label));
    await tester.pump();
    await tester.tap(find.text(currentAppLocalizations.mountSave));
    await shoot(tester, '15-dialog-unmount-many');
  });

  shot('16-dialog-mixed', (tester) async {
    await pumpProfiles(tester, sheetMounts(groups: autoGroups));
    await openSheet(tester);
    await tester.tap(inSheet(air.label));
    await tester.tap(inSheet(work.label));
    await tester.pump();
    await tester.tap(find.text(currentAppLocalizations.mountSave));
    await shoot(tester, '16-dialog-mixed');
  });

  shot('20-sheet-relay-banner', (tester) async {
    await pumpProfiles(
      tester,
      sheetMounts(
        groups: autoGroups,
        storedState: stored.copyWith(sourceIds: [air.id, sea.id, relayed.id]),
        items: [
          item(air, mounted: true, count: 42),
          item(sea, mounted: true, count: 18, tailscaleExcluded: 2),
          item(
            relayed,
            state: MountSourceState.relayOnly,
            count: 0,
            mounted: true,
            relayExcluded: 3,
          ),
          item(
            relayedSpare,
            state: MountSourceState.relayOnly,
            count: 0,
            relayExcluded: 5,
          ),
        ],
      ),
    );
    await openSheet(tester);
    await shoot(tester, '20-sheet-relay-banner');
  });

  shot('21-sheet-unmountable-rows', (tester) async {
    await pumpProfiles(
      tester,
      sheetMounts(
        groups: autoGroups,
        storedState: stored.copyWith(sourceIds: [air.id, odd.id, relayed.id]),
        items: [
          item(air, mounted: true, count: 42),
          item(odd, state: MountSourceState.unsupported, mounted: true),
          item(legacy, state: MountSourceState.unsupported, count: 0),
          item(
            relayed,
            state: MountSourceState.relayOnly,
            count: 0,
            mounted: true,
            relayExcluded: 3,
          ),
          item(
            tailnet,
            state: MountSourceState.tailscaleOnly,
            count: 0,
            tailscaleExcluded: 4,
          ),
        ],
        state: null,
      ),
    );
    await openSheet(tester);
    await tester.tap(inSheet(relayed.label));
    await shoot(tester, '21-sheet-unmountable-rows');
  });

  final isolatedGroups = [
    isolatedGroup('Tailscale 分流', MountGroupReason.rule),
    isolatedGroup('DNS 出口', MountGroupReason.dns),
    isolatedGroup('前置跳板', MountGroupReason.dialer),
  ];

  shot('22-groups-excluded', (tester) async {
    await pumpProfiles(
      tester,
      sheetMounts(
        groups: MountTarget(groups: [...autoGroups.groups, ...isolatedGroups]),
      ),
    );
    await openSheet(tester);
    await scrollSheetTo(
      tester,
      currentAppLocalizations.mountGroupsExcluded(isolatedGroups.length),
    );
    await shoot(tester, '22-groups-excluded');
  });

  shot('23-no-group-isolated', (tester) async {
    await pumpProfiles(
      tester,
      sheetMounts(groups: MountTarget(groups: isolatedGroups), state: null),
    );
    await openSheet(tester);
    await tester.tap(inSheet(work.label));
    await scrollSheetTo(
      tester,
      currentAppLocalizations.mountNoGroupIsolatedDesc,
    );
    await shoot(tester, '23-no-group-isolated');
  });

  for (final (name, application) in [
    ('24-update-read-not-applied', MountSaveOutcome.applyFailedKept),
    ('25-update-read-blocked', MountSaveOutcome.applyFailedBlocked),
  ]) {
    shot(name, (tester) async {
      final mounts = sheetMounts(groups: autoGroups)
        ..refreshResult = MountSourceRefresh(
          updated: true,
          item: item(sea, mounted: true, count: 21),
          application: application,
        );
      await pumpProfiles(tester, mounts);
      await openSheet(tester);
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: inSheet(sea.label),
            matching: find.byType(MountSourceRow),
          ),
          matching: find.byTooltip(currentAppLocalizations.mountUpdateNodes),
        ),
      );
      await shoot(tester, name);
    });
  }

  shot('26-blocked-confirmed', (tester) async {
    // The readback reloads the panel with what the update read.
    final read = [
      for (final source in sources)
        source.profile.id == sea.id
            ? source.copyWith(count: 21, tailscaleExcluded: 0)
            : source,
    ];
    final mounts = sheetMounts(groups: autoGroups, items: read)
      ..recheckOutcome = MountSaveOutcome.applyFailedBlocked
      ..refreshResult = MountSourceRefresh(
        updated: true,
        item: item(sea, mounted: true, count: 21),
        application: MountSaveOutcome.applyFailedBlocked,
      );
    await pumpProfiles(tester, mounts);
    await openSheet(tester);
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: inSheet(sea.label),
          matching: find.byType(MountSourceRow),
        ),
        matching: find.byTooltip(currentAppLocalizations.mountUpdateNodes),
      ),
    );
    await settle(tester);
    await tester.tap(inSheet(currentAppLocalizations.mountReadStatus));
    await shoot(tester, '26-blocked-confirmed');
  });

  Future<void> openDelete(WidgetTester tester) async {
    await tester.tap(
      find.text(air.label),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await settle(tester);
    await tester.tap(find.text(currentAppLocalizations.delete));
    await settle(tester);
  }

  shot('17-dialog-delete', (tester) async {
    final mounts = FakeMounts(null)..targets = [target, work, broken];
    await pumpProfiles(tester, mounts);
    await openDelete(tester);
    await shoot(tester, '17-dialog-delete');
  });

  shot('18-dialog-delete-pending', (tester) async {
    final mounts = FakeMounts(null)
      ..targets = [target, Profile.normal(label: target.label)]
      ..pending = true;
    await pumpProfiles(tester, mounts);
    await openDelete(tester);
    await shoot(tester, '18-dialog-delete-pending');
  });

  shot('19-dialog-delete-unknown', (tester) async {
    final mounts = FakeMounts(null)
      ..targets = [target]
      ..deletions = [MountSourceDeletion.unknown];
    await pumpProfiles(tester, mounts);
    await openDelete(tester);
    await tester.tap(
      find.text(currentAppLocalizations.mountDeleteSourceConfirm),
    );
    await shoot(tester, '19-dialog-delete-unknown');
  });
}
