// Renders the simulated panel states to PNG for review. Off by default:
//   TS_SCREENSHOTS=<dir> flutter test test/views/tailscale_screenshots_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/tailscale/tailscale.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_ui/prism_ui.dart' show ThemeMode;

import '../helpers/preferences.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'tailscale_fixtures.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

final _outDir = Platform.environment['TS_SCREENSHOTS'];
const _cjkFont = '/System/Library/Fonts/Supplemental/Arial Unicode.ttf';

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
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
    // The test platform draws with Roboto; a CJK font stands in for it.
    await _loadFont('Roboto', _cjkFont);
    await _loadFont('JetBrainsMono', 'assets/fonts/JetBrainsMono-Regular.ttf');
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
  }) async {
    container.read(viewSizeProvider.notifier).update((_) => size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
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
              child: TailscaleView(
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
      final image = await render.toImage();
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
          code: 'tailscale_not_overridable',
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
      tsMigrateResult(TailscaleMigrateOutcome.unknown, archiveIntact: true),
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
}
