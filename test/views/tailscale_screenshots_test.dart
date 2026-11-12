// Renders the simulated panel states to PNG for review. Off by default:
//   TS_SCREENSHOTS=<dir> flutter test test/views/tailscale_screenshots_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/tailscale/tailscale.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_ui/prism_ui.dart' show ThemeMode;

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'tailscale_fixtures.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

final _outDir = Platform.environment['TS_SCREENSHOTS'];
// Hiragino Sans GB holds a W3 and a W6 face, so emphasized text renders bold.
const _cjkCollection = '/System/Library/Fonts/Hiragino Sans GB.ttc';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set TS_SCREENSHOTS to an output directory'
      : null;

  setUpAll(() async {
    registerFallbackValue(const TailscaleNodeRef(name: '', generation: 0));
    if (skip != null) {
      return;
    }
    // The test platform draws with Roboto; a CJK family stands in for it.
    await _loadFont(
      'Roboto',
      _collectionFaces(File(_cjkCollection).readAsBytesSync()),
    );
    await _loadFont('JetBrainsMono', [
      ByteData.sublistView(
        File('assets/fonts/JetBrainsMono-Regular.ttf').readAsBytesSync(),
      ),
    ]);
    Directory(_outDir!).createSync(recursive: true);
  });

  late ProviderContainer container;
  late _MockCore core;

  setUp(() async {
    await mockPreferences();
    core = _MockCore();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        currentProfileProvider.overrideWithValue(tsProfile),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.read(currentPageLabelProvider.notifier).value =
        PageLabel.tailscale;
  });

  tearDown(() => container.dispose());

  void serve(List<TailscaleNode> nodes, [TailscaleStatus? status]) {
    when(() => core.getTailscaleNodes()).thenAnswer((_) async => nodes);
    if (status != null) {
      when(
        () => core.getTailscaleStatus(any()),
      ).thenAnswer((_) async => status);
    }
  }

  final boundary = GlobalKey();

  Future<void> pumpPanel(
    WidgetTester tester, {
    Size size = const Size(1100, 1300),
    ThemeMode themeMode = ThemeMode.light,
    double pixelRatio = 1,
    Widget? page,
  }) async {
    container.read(viewSizeProvider.notifier).update((_) => size);
    tester.view.physicalSize = size * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
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
              child:
                  page ??
                  TailscaleView(
                    clock: () => tsNow,
                    launcher: (_) async => true,
                  ),
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

  void migrateAnswers(TailscaleMigrateResult result) {
    when(
      () => core.migrateTailscaleLegacy(
        any(),
        offerToken: any(named: 'offerToken'),
      ),
    ).thenAnswer((_) async => result);
  }

  Future<void> confirmMigration(WidgetTester tester) async {
    await tester.tap(find.text('迁移到这个节点'));
    await settle(tester);
    await tester.tap(find.text('确认迁移'));
  }

  shot('01-core-stopped', (tester) async {
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await pumpPanel(tester, size: const Size(1100, 700));
    await shoot(tester, '01-core-stopped');
  });

  shot('02-no-node', (tester) async {
    serve(const []);
    await pumpPanel(tester, size: const Size(1100, 700));
    await shoot(tester, '02-no-node');
  });

  shot('03-signed-out', (tester) async {
    serve([tsSignedOutNode], const TailscaleStatus(node: tsSignedOutNode));
    await pumpPanel(tester);
    await shoot(tester, '03-signed-out');
  });

  shot('04-waiting-browser', (tester) async {
    final waiting = tsSignedOutNode.copyWith(
      started: true,
      backendState: TailscaleBackendState.needsLogin,
    );
    serve([tsSignedOutNode], const TailscaleStatus(node: tsSignedOutNode));
    when(
      () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
    ).thenAnswer((_) async {
      serve([waiting], TailscaleStatus(node: waiting, authUrlReady: true));
      return const TailscaleLoginResult(
        generation: 3,
        state: TailscaleBackendState.needsLogin,
        authUrl: 'https://login.example.test/a/x',
      );
    });
    await pumpPanel(tester);
    await tester.tap(find.text('登录 Tailscale'));
    await shoot(tester, '04-waiting-browser');
  });

  shot('05-connected', (tester) async {
    serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
    await pumpPanel(tester, size: const Size(1100, 1500));
    await shoot(tester, '05-connected');
  });

  shot('06-connected-dark', (tester) async {
    serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
    await pumpPanel(
      tester,
      size: const Size(1100, 1500),
      themeMode: ThemeMode.dark,
    );
    await shoot(tester, '06-connected-dark');
  });

  shot('07-owner-filter-empty', (tester) async {
    serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
    await pumpPanel(tester);
    await tester.tap(find.textContaining('我的'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText), 'no-such-device');
    await shoot(tester, '07-owner-filter-empty');
  });

  shot('08-needs-machine-auth', (tester) async {
    final node = tsConnectedNode.copyWith(
      backendState: TailscaleBackendState.needsMachineAuth,
    );
    serve([node], TailscaleStatus(node: node));
    await pumpPanel(tester);
    await shoot(tester, '08-needs-machine-auth');
  });

  shot('09-needs-relogin', (tester) async {
    final node = tsConnectedNode.copyWith(
      backendState: TailscaleBackendState.needsLogin,
    );
    serve([node], TailscaleStatus(node: node));
    await pumpPanel(tester);
    await shoot(tester, '09-needs-relogin');
  });

  shot('10-expiry-reminder', (tester) async {
    serve([
      tsConnectedNode,
    ], tsConnectedStatus(keyExpiry: tsNow.add(const Duration(days: 3))));
    await pumpPanel(tester);
    await shoot(tester, '10-expiry-reminder');
  });

  shot('11-start-error', (tester) async {
    final node = tsConnectedNode.copyWith(
      started: false,
      backendState: TailscaleBackendState.none,
      startError: const TailscaleError(
        code: 'tailscale_start_failed',
        message: 'listen failed',
      ),
    );
    serve([node], TailscaleStatus(node: node));
    await pumpPanel(tester);
    await shoot(tester, '11-start-error');
  });

  shot('12-status-read-failed', (tester) async {
    serve([tsConnectedNode]);
    when(
      () => core.getTailscaleStatus(any()),
    ).thenThrow(const CoreMethodException(code: 'boom', message: 'boom'));
    await pumpPanel(tester);
    await shoot(tester, '12-status-read-failed');
  });

  shot('13-status-unconfirmed', (tester) async {
    final node = tsConnectedNode.copyWith(
      backendState: TailscaleBackendState.unknown,
    );
    serve([node], TailscaleStatus(node: node));
    await pumpPanel(tester);
    await shoot(tester, '13-status-unconfirmed');
  });

  shot('14-stale-after-failed-refresh', (tester) async {
    serve([tsConnectedNode], tsConnectedStatus());
    await pumpPanel(tester);
    when(
      () => core.getTailscaleStatus(any()),
    ).thenThrow(const CoreMethodException(code: 'boom', message: 'boom'));
    await tester.tap(find.byTooltip('刷新'));
    await shoot(tester, '14-stale-after-failed-refresh');
  });

  shot('15-logout-confirm', (tester) async {
    final node = tsConnectedNode.copyWith(authKey: true);
    serve([node], tsConnectedStatus(node: node));
    await pumpPanel(tester);
    await tester.tap(find.text('退出当前节点'));
    await shoot(tester, '15-logout-confirm');
  });

  shot('16-settings-pending-and-failed', (tester) async {
    serve([tsConnectedNode], tsConnectedStatus());
    when(
      () => core.setTailscalePrefs(
        any(),
        exitNode: any(named: 'exitNode'),
        acceptRoutes: any(named: 'acceptRoutes'),
      ),
    ).thenAnswer((invocation) async {
      if (invocation.namedArguments[#acceptRoutes] != null) {
        throw const CoreMethodException(
          code: 'tailscale_override_ambiguous',
          message: 'locked',
        );
      }
      return const TailscalePrefsResult(
        generation: 3,
        outcome: TailscalePrefsOutcome.unknown,
      );
    });
    await pumpPanel(tester);
    await tester.tap(find.text('不使用出口节点').first);
    await settle(tester);
    await tester.tap(find.text('nas-sg · 100.88.12.4'));
    await settle(tester);
    await tester.tap(find.text('更改出口节点'));
    await settle(tester);
    await tester.tap(find.text('接受子网路由'));
    await settle(tester);
    await tester.tap(find.text('停止接受'));
    await shoot(tester, '16-settings-pending-and-failed');
  });

  shot('17-legacy-offer', (tester) async {
    final node = tsLegacyNode(authKey: true);
    serve([node], TailscaleStatus(node: node));
    await pumpPanel(tester);
    await shoot(tester, '17-legacy-offer');
  });

  shot('18-legacy-confirm', (tester) async {
    serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
    await pumpPanel(tester);
    await tester.tap(find.text('迁移到这个节点'));
    await shoot(tester, '18-legacy-confirm');
  });

  shot('19-legacy-changed', (tester) async {
    serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
    when(
      () => core.migrateTailscaleLegacy(
        any(),
        offerToken: any(named: 'offerToken'),
      ),
    ).thenThrow(
      const CoreMethodException(
        code: 'tailscale_legacy_changed',
        message: 'token',
      ),
    );
    await pumpPanel(tester);
    await confirmMigration(tester);
    await shoot(tester, '19-legacy-changed');
  });

  shot('20-legacy-failed', (tester) async {
    serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
    migrateAnswers(
      tsMigrateResult(
        TailscaleMigrateOutcome.failed,
        targetUntouched: true,
        archiveIntact: true,
      ),
    );
    await pumpPanel(tester);
    await confirmMigration(tester);
    await shoot(tester, '20-legacy-failed');
  });

  shot('21-legacy-archive-error', (tester) async {
    serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
    migrateAnswers(
      tsMigrateResult(
        TailscaleMigrateOutcome.failed,
        targetUntouched: true,
        archiveIntact: false,
        stage: TailscaleMigrateStage.copy,
        error: 'read back differs',
      ),
    );
    await pumpPanel(tester);
    await confirmMigration(tester);
    await shoot(tester, '21-legacy-archive-error');
  });

  shot('22-legacy-unknown', (tester) async {
    serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
    migrateAnswers(
      tsMigrateResult(
        TailscaleMigrateOutcome.unknown,
        archiveIntact: true,
        stage: TailscaleMigrateStage.verify,
      ),
    );
    await pumpPanel(tester);
    await confirmMigration(tester);
    await shoot(tester, '22-legacy-unknown');
  });

  shot('23-legacy-migrated', (tester) async {
    final legacy = tsLegacyNode();
    serve([legacy], TailscaleStatus(node: legacy));
    when(
      () => core.startTailscale(any()),
    ).thenAnswer((_) => Completer<TailscaleNode>().future);
    migrateAnswers(
      tsMigrateResult(
        TailscaleMigrateOutcome.migrated,
        archiveIntact: true,
        node: legacy.copyWith(hasIdentity: true, legacy: null),
      ),
    );
    await pumpPanel(tester);
    await confirmMigration(tester);
    await shoot(tester, '23-legacy-migrated');
  });

  shot('24-legacy-ineligible', (tester) async {
    final node = tsLegacyNode(
      eligibility: TailscaleLegacyEligibility.controlMismatch,
      token: null,
    );
    serve([node], TailscaleStatus(node: node));
    container
        .read(tailscaleLegacyStatesProvider.notifier)
        .change(node.key, (state) => state.copyWith(offered: true));
    await pumpPanel(tester);
    await shoot(tester, '24-legacy-ineligible');
  });

  shot('25-two-nodes-narrow', (tester) async {
    serve([
      tsConnectedNode,
      tsConnectedNode.copyWith(name: 'ts-office'),
    ], tsConnectedStatus());
    await pumpPanel(tester, size: const Size(760, 1700));
    await shoot(tester, '25-two-nodes-narrow');
  });

  shot('26-signed-out-saved', (tester) async {
    final node = tsSignedOutNode.copyWith(
      settings: const TailscaleSettings(
        exitNode: TailscaleExitNodeSetting(
          value: '100.88.12.4',
          source: TailscaleSettingSource.override,
        ),
        acceptRoutes: TailscaleAcceptRoutesSetting(
          value: true,
          source: TailscaleSettingSource.override,
        ),
      ),
    );
    container.listen(tailscaleNodeRecordsProvider, (_, _) {});
    await container
        .read(tailscaleNodeRecordsProvider.notifier)
        .modify(
          node.key,
          (record) =>
              record.copyWith(exitNode: '100.88.12.4', exitNodeName: 'nas-sg'),
        );
    serve([node], TailscaleStatus(node: node));
    await pumpPanel(tester);
    await shoot(tester, '26-signed-out-saved');
  });

  shot('27-provider-node', (tester) async {
    final node = tsConnectedNode.copyWith(
      settings: const TailscaleSettings(
        acceptRoutes: TailscaleAcceptRoutesSetting(
          value: true,
          source: TailscaleSettingSource.provider,
        ),
      ),
    );
    serve([node], tsConnectedStatus(node: node));
    await pumpPanel(tester);
    await shoot(tester, '27-provider-node');
  });

  shot('28-override-ambiguous', (tester) async {
    final node = tsConnectedNode.copyWith(overridable: false);
    serve([node], tsConnectedStatus(node: node));
    await pumpPanel(tester);
    await shoot(tester, '28-override-ambiguous');
  });

  shot('29-device-names-narrow', (tester) async {
    serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
    await pumpPanel(tester, size: const Size(640, 1500));
    await shoot(tester, '29-device-names-narrow');
  });

  shot('30-device-names-520', (tester) async {
    serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
    await pumpPanel(tester, size: const Size(520, 1500));
    await shoot(tester, '30-device-names-520');
  });

  shot('30b-device-owners-menu-520', (tester) async {
    serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
    await pumpPanel(tester, size: const Size(520, 1500));
    await tester.tap(find.textContaining('+'));
    await shoot(tester, '30b-device-owners-menu-520');
  });

  shot('30c-device-owner-checked-520', (tester) async {
    serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
    await pumpPanel(tester, size: const Size(520, 1500));
    await tester.tap(find.textContaining('+'));
    await settle(tester);
    await tester.tap(find.text('归属未知 1'));
    await settle(tester);
    await tester.tap(find.textContaining('+'));
    await shoot(tester, '30c-device-owner-checked-520');
  });

  // Panel-added accounts, design.md §12–§13.

  const records = [
    TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
    TailscaleManagedRecord(id: 'm2', profileId: 42, attached: true),
  ];

  TailscaleStatus workStatus(TailscaleNode node) => TailscaleStatus(
    node: node,
    haveNodeKey: true,
    self: const TailscalePeer(
      id: 'self-work',
      hostName: 'flclash-mac',
      addresses: ['100.80.3.17', 'fd7a:115c:a1e0::5011'],
      userId: '2001',
      online: true,
    ),
    loginUser: const TailscaleUser(
      id: '2001',
      loginName: 'pat@work.test',
      displayName: 'Pat Work',
    ),
    tailnet: const TailscaleTailnet(name: 'work-net.test'),
    peers: const [
      TailscalePeer(
        id: 'w1',
        hostName: 'build-mac',
        dnsName: 'build-mac.work-net.test.',
        os: 'macOS',
        userId: '2001',
        addresses: ['100.94.68.92', 'fd7a:115c:a1e0::77'],
        online: true,
      ),
    ],
  );

  Future<void> seedManaged(
    List<TailscaleNode> nodes, {
    List<TailscaleManagedRecord> saved = records,
    TailscaleRoutes? routes,
  }) async {
    container.listen(currentProfileIdProvider, (_, _) {});
    container.listen(patchClashConfigProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = 42;
    await container
        .read(tailscaleManagedRecordsProvider.notifier)
        .modify((_) => saved);
    when(() => core.getTailscaleNodes()).thenAnswer((_) async => nodes);
    when(() => core.getTailscaleStatus(any())).thenAnswer((invocation) async {
      final ref = invocation.positionalArguments.first as TailscaleNodeRef;
      final node = nodes.firstWhere((node) => node.managedId == ref.managedId);
      if (!node.hasIdentity) {
        return TailscaleStatus(node: node);
      }
      return node.managedId == 'm2'
          ? workStatus(node)
          : tsConnectedStatus(node: node, manyPeers: true);
    });
    when(() => core.getTailscaleRoutes(42)).thenAnswer(
      (_) async =>
          routes ??
          const TailscaleRoutes(
            profileId: 42,
            active: true,
            complete: true,
            accounts: [
              TailscaleRouteAccountReport(
                id: 'm1',
                fresh: true,
                available: true,
                domain: 'example-net.test.ts.net',
                addresses: 9,
              ),
            ],
          ),
    );
  }

  void attachState(String id, TailscaleAttachState attach) {
    container
        .read(tailscaleManagedPanelsProvider.notifier)
        .change(
          tailscaleManagedNodeKey(42, id),
          (state) => state.copyWith(attach: attach),
        );
  }

  shot('31-sign-in-no-node', (tester) async {
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = 42;
    serve(const []);
    await pumpPanel(tester, size: const Size(1100, 700));
    await shoot(tester, '31-sign-in-no-node');
  });

  shot('32-new-account-waiting', (tester) async {
    final draft = tsManagedNode(
      'm1',
      account: null,
      attached: false,
    ).copyWith(started: true, backendState: TailscaleBackendState.needsLogin);
    await seedManaged(
      [draft],
      saved: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
    );
    await pumpPanel(tester);
    await shoot(tester, '32-new-account-waiting');
  });

  shot('33-attaching', (tester) async {
    final node = tsManagedNode('m1', attached: false);
    await seedManaged(
      [node],
      saved: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
    );
    attachState('m1', TailscaleAttachState.attaching);
    await pumpPanel(tester);
    await shoot(tester, '33-attaching');
  });

  shot('34-attach-failed', (tester) async {
    final node = tsManagedNode('m1', attached: false);
    await seedManaged(
      [node],
      saved: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
    );
    attachState('m1', TailscaleAttachState.failed);
    await pumpPanel(tester);
    await shoot(tester, '34-attach-failed');
  });

  shot('35-attach-unknown', (tester) async {
    final node = tsManagedNode('m1', attached: false);
    await seedManaged(
      [node],
      saved: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
    );
    attachState('m1', TailscaleAttachState.unknown);
    await pumpPanel(tester);
    await shoot(tester, '35-attach-unknown');
  });

  shot('36-managed-connected', (tester) async {
    await seedManaged([
      tsManagedNode('m1'),
      tsManagedNode('m2', account: tsWorkAccount),
    ]);
    await pumpPanel(tester, size: const Size(1100, 1500));
    await shoot(tester, '36-managed-connected');
  });

  shot('37-switcher-open', (tester) async {
    await seedManaged([
      tsManagedNode('m1'),
      tsManagedNode('m2', account: tsWorkAccount),
      tsConnectedNode,
    ]);
    await pumpPanel(tester, size: const Size(1100, 900));
    await tester.tap(find.bySemanticsLabel(RegExp('当前查看的 Tailscale 账号')));
    await shoot(tester, '37-switcher-open');
  });

  shot('38-conflict-banner', (tester) async {
    await seedManaged([
      tsManagedNode('m1'),
      tsManagedNode('m2', account: tsWorkAccount),
    ], routes: tsConflictRoutes());
    await pumpPanel(tester, size: const Size(1100, 1500));
    await shoot(tester, '38-conflict-banner');
  });

  shot('39-assign-dialog', (tester) async {
    await seedManaged([
      tsManagedNode('m1'),
      tsManagedNode('m2', account: tsWorkAccount),
    ], routes: tsConflictRoutes());
    await pumpPanel(tester, size: const Size(1100, 900));
    await tester.tap(find.text('指定账号'));
    await settle(tester);
    await tester.tap(find.text('build-mac').last);
    await shoot(tester, '39-assign-dialog');
  });

  shot('40-signed-out-kept', (tester) async {
    final node = tsManagedNode('m2', account: tsWorkAccount, loggedOut: true);
    await seedManaged(
      [tsManagedNode('m1'), node],
      saved: const [
        TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
        TailscaleManagedRecord(
          id: 'm2',
          profileId: 42,
          attached: true,
          loggedOut: true,
        ),
      ],
    );
    container
        .read(tailscaleManagedPanelsProvider.notifier)
        .change(
          node.key,
          (state) => state.copyWith(notice: TailscaleManagedNotice.signedOut),
        );
    await pumpPanel(tester, size: const Size(1100, 900));
    await tester.tap(find.bySemanticsLabel(RegExp('当前查看的 Tailscale 账号')));
    await settle(tester);
    await tester.tap(find.text('tailscale-m2').last);
    await shoot(tester, '40-signed-out-kept');
  });

  shot('41-remove-dialog', (tester) async {
    await seedManaged([
      tsManagedNode('m1'),
      tsManagedNode('m2', account: tsWorkAccount),
    ]);
    await pumpPanel(tester, size: const Size(1100, 900));
    await tester.tap(find.byTooltip('更多'));
    await settle(tester);
    await tester.tap(find.text('退出并移除…'));
    await settle(tester);
    expect(find.text('退出并移除此账号？'), findsOneWidget);
    await shoot(tester, '41-remove-dialog');
  });

  shot('42-direct-mode', (tester) async {
    await seedManaged([tsManagedNode('m1')]);
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: Mode.direct));
    await pumpPanel(tester, size: const Size(1100, 900));
    await shoot(tester, '42-direct-mode');
  });

  shot('43-managed-dark-narrow', (tester) async {
    await seedManaged([
      tsManagedNode('m1'),
      tsManagedNode('m2', account: tsWorkAccount),
    ], routes: tsConflictRoutes());
    await pumpPanel(
      tester,
      size: const Size(640, 1700),
      themeMode: ThemeMode.dark,
    );
    await shoot(tester, '43-managed-dark-narrow');
  });

  shot('44-rules-page', (tester) async {
    final base = tsConflictRoutes();
    await seedManaged(
      [tsManagedNode('m1'), tsManagedNode('m2', account: tsWorkAccount)],
      routes: base.copyWith(
        targets: [
          ...base.targets,
          const TailscaleRouteTargetReport(
            target: TailscaleRouteTarget(
              kind: tailscaleTargetIp,
              value: '100.71.20.5',
            ),
            state: TailscaleRouteState.assigned,
            owner: TailscaleRouteOwner(kind: tailscaleOwnerManaged, id: 'm1'),
            candidates: [
              TailscaleRouteCandidate(
                owner: TailscaleRouteOwner(
                  kind: tailscaleOwnerManaged,
                  id: 'm1',
                ),
              ),
              TailscaleRouteCandidate(
                owner: TailscaleRouteOwner(
                  kind: tailscaleOwnerManaged,
                  id: 'm2',
                ),
              ),
            ],
          ),
          const TailscaleRouteTargetReport(
            target: TailscaleRouteTarget(
              kind: tailscaleTargetIp,
              value: '100.64.0.7',
            ),
            state: TailscaleRouteState.unavailable,
            owner: TailscaleRouteOwner(kind: tailscaleOwnerManaged, id: 'm2'),
            candidates: [
              TailscaleRouteCandidate(
                owner: TailscaleRouteOwner(
                  kind: tailscaleOwnerManaged,
                  id: 'm2',
                ),
              ),
            ],
          ),
        ],
      ),
    );
    await pumpPanel(tester, size: const Size(1100, 1300));
    await tester.tap(find.text('前往规则'));
    await settle(tester);
    await shoot(tester, '44-rules-page');
  });

  shot('45-row-context-menu', (tester) async {
    await seedManaged([
      tsManagedNode('m1'),
      tsManagedNode('m2', account: tsWorkAccount),
    ], routes: tsConflictRoutes());
    await pumpPanel(tester, size: const Size(1100, 1500));
    await tester.tap(
      find.text('studio-mac'),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await settle(tester);
    await shoot(tester, '45-row-context-menu');
  });

  // The window of the user's report: 1054 by 772 dp, saved at 1568 by 1148.
  const reportSize = Size(1054, 1148 * 1054 / 1568);
  const reportRatio = 1568 / 1054;

  shot('46-report-window', (tester) async {
    await seedManaged(
      [tsManagedNode('m1')],
      saved: const [
        TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
      ],
    );
    await pumpPanel(tester, size: reportSize, pixelRatio: reportRatio);
    await shoot(tester, '46-report-window');
  });

  shot('47-report-window-dashboard', (tester) async {
    container.read(currentPageLabelProvider.notifier).value =
        PageLabel.dashboard;
    when(
      () => core.watchRoute(any()),
    ).thenAnswer((_) async => const RouteSnapshot());
    await useAppPaths(Directory.systemTemp.createTempSync('ts_dashboard'));
    await pumpPanel(
      tester,
      size: reportSize,
      pixelRatio: reportRatio,
      page: const DashboardView(platform: SupportPlatform.MacOS),
    );
    await shoot(tester, '47-report-window-dashboard');
  });

  // The quiet-by-default pass, light, saved 1568 wide.
  const quietWidth = 1054.0;

  shot('quiet-01-signed-out', (tester) async {
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = 42;
    serve(const []);
    await pumpPanel(
      tester,
      size: const Size(quietWidth, 720),
      pixelRatio: reportRatio,
    );
    await shoot(tester, 'quiet-01-signed-out');
  });

  shot('quiet-02-connected-full', (tester) async {
    await seedManaged([tsManagedNode('m1')]);
    await pumpPanel(
      tester,
      size: const Size(quietWidth, 1180),
      pixelRatio: reportRatio,
    );
    await shoot(tester, 'quiet-02-connected-full');
  });

  shot('quiet-03-rules-sheet', (tester) async {
    await seedManaged([
      tsManagedNode('m1'),
      tsManagedNode('m2', account: tsWorkAccount),
    ], routes: tsConflictRoutes());
    await pumpPanel(
      tester,
      size: const Size(quietWidth, 900),
      pixelRatio: reportRatio,
    );
    await tester.tap(find.text('前往规则'));
    await shoot(tester, 'quiet-03-rules-sheet');
  });

  shot('quiet-04-popover-open', (tester) async {
    await seedManaged([tsManagedNode('m1')]);
    await pumpPanel(
      tester,
      size: const Size(quietWidth, 900),
      pixelRatio: reportRatio,
    );
    await tester.tap(find.byTooltip('出口设置说明'));
    await shoot(tester, 'quiet-04-popover-open');
  });
}
