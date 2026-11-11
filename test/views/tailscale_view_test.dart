import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/tailscale/tailscale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/preferences.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'tailscale_fixtures.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

const _size = Size(1100, 1400);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const TailscaleNodeRef(name: '', generation: 0));
  });

  late ProviderContainer container;
  late _MockCore core;
  late List<Uri> opened;
  late bool browserOpens;

  setUp(() async {
    await mockPreferences();
    core = _MockCore();
    opened = [];
    browserOpens = true;
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        currentProfileProvider.overrideWithValue(tsProfile),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).update((_) => _size);
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

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: const Locale('zh', 'CN'),
          child: TailscaleView(
            clock: () => tsNow,
            launcher: (url) async {
              opened.add(url);
              return browserOpens;
            },
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

  Future<void> teardownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  group('page states', () {
    testWidgets('core stopped shows its own page', (tester) async {
      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      await pumpPanel(tester);

      expect(find.text('内核未运行'), findsOneWidget);
      expect(find.text('启动内核'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('no node shows the empty page with 前往配置', (tester) async {
      serve(const []);
      await pumpPanel(tester);

      expect(find.text('尚无 Tailscale 节点'), findsOneWidget);
      expect(find.text('前往配置'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a failed node list is a load failure, not an empty page', (
      tester,
    ) async {
      when(
        () => core.getTailscaleNodes(),
      ).thenThrow(const CoreMethodException(code: 'boom', message: 'boom'));
      await pumpPanel(tester);

      expect(find.text('状态加载失败'), findsOneWidget);
      expect(find.text('重新读取状态'), findsOneWidget);
      expect(find.text('尚无 Tailscale 节点'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('the node picker shows only with two nodes or more', (
      tester,
    ) async {
      serve([tsSignedOutNode, tsSignedOutNode.copyWith(name: 'ts-office')]);
      when(
        () => core.getTailscaleStatus(any()),
      ).thenAnswer((_) async => const TailscaleStatus(node: tsSignedOutNode));
      await pumpPanel(tester);

      expect(find.text('ts-home · 当前节点'), findsOneWidget);
      await teardownView(tester);
    });
  });

  group('device card states', () {
    testWidgets('未登录 offers 登录 Tailscale and locks the settings', (
      tester,
    ) async {
      serve([tsSignedOutNode], const TailscaleStatus(node: tsSignedOutNode));
      await pumpPanel(tester);

      expect(find.text('未登录'), findsWidgets);
      expect(find.text('在浏览器中登录，完成此节点的认证。'), findsOneWidget);
      expect(find.text('登录 Tailscale'), findsOneWidget);
      expect(find.text('登录后可选'), findsNWidgets(2));
      expect(find.text('登录后可查看'), findsOneWidget);
      expect(find.text('设备'), findsNothing);
      expect(find.text('前往规则'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('已连接 shows address, identity and the device table', (
      tester,
    ) async {
      serve([tsConnectedNode], tsConnectedStatus());
      await pumpPanel(tester);

      expect(find.text('已连接'), findsWidgets);
      expect(find.text('100.101.7.58'), findsOneWidget);
      expect(find.text('pat@example.test'), findsOneWidget);
      expect(find.text('example-net.test'), findsOneWidget);
      expect(find.text('设备'), findsOneWidget);
      expect(find.text('归属'), findsOneWidget);
      expect(find.text('我'), findsWidgets);
      expect(find.text('退出当前节点'), findsOneWidget);
      expect(find.text('当前显示 4 台设备'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('the owner filter and its empty result', (tester) async {
      serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
      await pumpPanel(tester);

      expect(find.text('设备归属'), findsOneWidget);
      await tester.tap(find.textContaining('我的'));
      await settle(tester);
      expect(find.text('当前显示 2 台设备'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'no-such-device');
      await settle(tester);
      expect(find.text('没有符合当前筛选条件的设备'), findsOneWidget);
      expect(find.text('没有符合当前归属的设备'), findsNothing);
      await tester.tap(find.text('清除归属筛选'));
      await settle(tester);
      expect(find.text('没有符合当前筛选条件的设备'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('等待管理员批准 offers only a read', (tester) async {
      final node = tsConnectedNode.copyWith(
        backendState: TailscaleBackendState.needsMachineAuth,
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('等待管理员批准'), findsWidgets);
      expect(find.text('浏览器认证已完成。请等待 Tailscale 网络管理员批准此设备。'), findsOneWidget);
      expect(find.text('重新读取状态'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('需要重新登录 when a login on disk needs the browser again', (
      tester,
    ) async {
      final node = tsConnectedNode.copyWith(
        backendState: TailscaleBackendState.needsLogin,
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('需要重新登录'), findsWidgets);
      expect(find.text('重新登录'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('已停止 keeps its own label', (tester) async {
      final node = tsConnectedNode.copyWith(
        backendState: TailscaleBackendState.stopped,
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('已停止'), findsWidgets);
      expect(find.text('重新读取状态'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a reliable expiry within 7 days stays 已连接 with a reminder', (
      tester,
    ) async {
      serve([
        tsConnectedNode,
      ], tsConnectedStatus(keyExpiry: tsNow.add(const Duration(days: 3))));
      await pumpPanel(tester);

      expect(find.text('已连接'), findsWidgets);
      expect(find.textContaining('认证将于'), findsOneWidget);
      expect(find.text('需要重新登录'), findsNothing);
      await teardownView(tester);
    });
  });

  group('addendum B', () {
    testWidgets('start-error is 启动失败 with 重试 and 重新读取状态', (tester) async {
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

      expect(find.text('启动失败'), findsWidgets);
      expect(find.text('此节点未能启动，请重试。'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('重新读取状态'), findsOneWidget);
      expect(find.text('未登录'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('a failed status read is 状态加载失败, then a read recovers', (
      tester,
    ) async {
      serve([tsConnectedNode]);
      when(
        () => core.getTailscaleStatus(any()),
      ).thenThrow(const CoreMethodException(code: 'boom', message: 'boom'));
      await pumpPanel(tester);

      expect(find.text('状态加载失败'), findsOneWidget);
      expect(find.text('暂时无法读取此节点的状态，请重试。'), findsOneWidget);
      expect(find.text('账号与网络信息加载失败'), findsOneWidget);
      expect(find.text('未登录'), findsNothing);
      expect(find.text('重新读取状态'), findsOneWidget);

      when(
        () => core.getTailscaleStatus(any()),
      ).thenAnswer((_) async => tsConnectedStatus());
      await tester.tap(find.text('重新读取状态'));
      await settle(tester);
      expect(find.text('已连接'), findsWidgets);
      await teardownView(tester);
    });

    testWidgets('a failed re-read keeps the last status marked stale', (
      tester,
    ) async {
      serve([tsConnectedNode], tsConnectedStatus());
      await pumpPanel(tester);
      when(
        () => core.getTailscaleStatus(any()),
      ).thenThrow(const CoreMethodException(code: 'boom', message: 'boom'));
      await tester.tap(find.byTooltip('刷新'));
      await settle(tester);

      expect(find.text('100.101.7.58'), findsOneWidget);
      expect(find.text('设备列表可能已过期。刷新失败，以下为上次读取的结果。'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('an unknown backend state is 状态待确认 with 重新读取状态', (
      tester,
    ) async {
      final node = tsConnectedNode.copyWith(
        backendState: TailscaleBackendState.unknown,
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('状态待确认'), findsWidgets);
      expect(find.text('暂时无法确认此节点是否已连接，请重新读取状态。'), findsOneWidget);
      expect(find.text('重新读取状态'), findsOneWidget);
      expect(find.text('未登录'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('a login without an answer is 状态待确认, not 未登录', (tester) async {
      serve([tsSignedOutNode], const TailscaleStatus(node: tsSignedOutNode));
      when(
        () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
      ).thenAnswer(
        (_) async => const TailscaleLoginResult(generation: 3, pending: true),
      );
      await pumpPanel(tester);
      await tester.tap(find.text('登录 Tailscale'));
      await settle(tester);

      expect(find.text('状态待确认'), findsWidgets);
      expect(find.text('尚未确认登录结果，请重新读取节点状态。'), findsOneWidget);
      expect(find.text('登录 Tailscale'), findsNothing);
      expect(opened, isEmpty);
      await teardownView(tester);
    });
  });

  group('login and logout', () {
    testWidgets('a login URL opens once and the card waits for the browser', (
      tester,
    ) async {
      serve([tsSignedOutNode], const TailscaleStatus(node: tsSignedOutNode));
      when(
        () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
      ).thenAnswer((_) async {
        final waiting = tsSignedOutNode.copyWith(
          started: true,
          backendState: TailscaleBackendState.needsLogin,
        );
        serve([waiting], TailscaleStatus(node: waiting, authUrlReady: true));
        return const TailscaleLoginResult(
          generation: 3,
          state: TailscaleBackendState.needsLogin,
          authUrl: 'https://login.example.test/a/secret',
        );
      });
      await pumpPanel(tester);
      await tester.tap(find.text('登录 Tailscale'));
      await settle(tester);

      expect(opened, hasLength(1));
      expect(find.text('等待浏览器登录'), findsWidgets);
      expect(find.text('重新打开登录页'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);

      await tester.pump(const Duration(seconds: 7));
      expect(opened, hasLength(1), reason: 'polling never opens a browser');
      await teardownView(tester);
    });

    testWidgets('a browser that does not open says so', (tester) async {
      browserOpens = false;
      serve([tsSignedOutNode], const TailscaleStatus(node: tsSignedOutNode));
      when(
        () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
      ).thenAnswer(
        (_) async => const TailscaleLoginResult(
          generation: 3,
          state: TailscaleBackendState.needsLogin,
          authUrl: 'https://login.example.test/a/secret',
        ),
      );
      await pumpPanel(tester);
      await tester.tap(find.text('登录 Tailscale'));
      await settle(tester);

      expect(find.text('无法打开登录页，请重试。'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a rejected URL points to the profile, never opens it', (
      tester,
    ) async {
      serve([tsSignedOutNode], const TailscaleStatus(node: tsSignedOutNode));
      when(
        () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
      ).thenThrow(
        const CoreMethodException(
          code: 'tailscale_auth_url_rejected',
          message: 'host',
        ),
      );
      await pumpPanel(tester);
      await tester.tap(find.text('登录 Tailscale'));
      await settle(tester);

      expect(find.text('无法安全打开此登录页，请检查当前节点的控制服务器配置。'), findsOneWidget);
      expect(find.text('前往配置'), findsOneWidget);
      expect(opened, isEmpty);
      await teardownView(tester);
    });

    testWidgets('logout asks first, names the auth key and keeps an unknown '
        'result pending', (tester) async {
      final node = tsConnectedNode.copyWith(authKey: true);
      serve([node], tsConnectedStatus(node: node));
      when(
        () => core.logoutTailscale(any()),
      ).thenAnswer((_) async => const TailscaleLogoutResult(generation: 3));
      await pumpPanel(tester);
      await tester.tap(find.text('退出当前节点'));
      await settle(tester);

      expect(find.text('退出此 Tailscale 节点？'), findsOneWidget);
      expect(
        find.textContaining('再次点击登录时，将使用配置中的登录密钥注册新的设备身份。'),
        findsOneWidget,
      );
      await tester.tap(find.text('退出当前节点').last);
      await settle(tester);

      expect(find.text('退出结果待确认，请重新读取节点状态，确认前请勿重复操作。'), findsOneWidget);
      expect(find.text('状态待确认'), findsWidgets);
      await teardownView(tester);
    });
  });

  group('exit node and subnet routes', () {
    testWidgets('an exit node change asks first and an unanswered one stays '
        'pending', (tester) async {
      serve([tsConnectedNode], tsConnectedStatus());
      when(
        () => core.setTailscalePrefs(
          any(),
          exitNode: any(named: 'exitNode'),
          acceptRoutes: any(named: 'acceptRoutes'),
        ),
      ).thenAnswer(
        (_) async => const TailscalePrefsResult(
          generation: 3,
          outcome: TailscalePrefsOutcome.unknown,
        ),
      );
      await pumpPanel(tester);
      await tester.tap(find.text('不使用出口节点').first);
      await settle(tester);
      await tester.tap(find.text('nas-sg · 100.88.12.4'));
      await settle(tester);

      expect(find.text('更改出口节点？'), findsOneWidget);
      await tester.tap(find.text('更改出口节点'));
      await settle(tester);

      verify(
        () => core.setTailscalePrefs(any(), exitNode: '100.88.12.4'),
      ).called(1);
      expect(find.text('出口节点的更改结果待确认，请重新读取当前设置。'), findsOneWidget);
      expect(find.text('重新读取设置'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a refused routes change offers 重试', (tester) async {
      serve([tsConnectedNode], tsConnectedStatus());
      when(
        () => core.setTailscalePrefs(
          any(),
          exitNode: any(named: 'exitNode'),
          acceptRoutes: any(named: 'acceptRoutes'),
        ),
      ).thenThrow(
        const CoreMethodException(
          code: 'tailscale_not_overridable',
          message: 'locked',
        ),
      );
      await pumpPanel(tester);
      await tester.tap(find.text('接受子网路由'));
      await settle(tester);

      expect(find.text('停止接受子网路由？'), findsOneWidget);
      await tester.tap(find.text('停止接受'));
      await settle(tester);

      verify(
        () => core.setTailscalePrefs(any(), acceptRoutes: false),
      ).called(1);
      expect(find.text('子网路由设置未更改，请重试。'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a cancelled change never reaches the Core', (tester) async {
      serve([tsConnectedNode], tsConnectedStatus());
      await pumpPanel(tester);
      await tester.tap(find.text('接受子网路由'));
      await settle(tester);
      await tester.tap(find.text('取消'));
      await settle(tester);

      verifyNever(
        () => core.setTailscalePrefs(
          any(),
          exitNode: any(named: 'exitNode'),
          acceptRoutes: any(named: 'acceptRoutes'),
        ),
      );
      await teardownView(tester);
    });
  });

  group('legacy migration', () {
    testWidgets('the offer shows the account, server and both choices', (
      tester,
    ) async {
      serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
      await pumpPanel(tester);

      expect(find.text('未登录'), findsWidgets);
      expect(find.text('发现旧版登录记录'), findsOneWidget);
      expect(find.text('legacy@example.test'), findsOneWidget);
      expect(find.text('迁移到这个节点'), findsOneWidget);
      expect(find.text('重新登录'), findsOneWidget);
      expect(find.text('登录 Tailscale'), findsNothing);
      expect(find.textContaining('此节点配置了登录密钥'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('an auth key adds its note', (tester) async {
      final node = tsLegacyNode(authKey: true);
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(
        find.text('此节点配置了登录密钥，重新登录将使用该密钥注册新的设备身份，旧登录记录仍保留。'),
        findsOneWidget,
      );
      await teardownView(tester);
    });

    testWidgets('the confirmation lists profile, node, account and server', (
      tester,
    ) async {
      serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
      await pumpPanel(tester);
      await tester.tap(find.text('迁移到这个节点'));
      await settle(tester);

      expect(find.text('将旧登录迁移到此节点？'), findsOneWidget);
      expect(find.textContaining('配置：Home'), findsOneWidget);
      expect(find.textContaining('节点：ts-home'), findsOneWidget);
      expect(find.textContaining('登录账号：legacy@example.test'), findsOneWidget);
      expect(
        find.textContaining('控制服务器：controlplane.tailscale.com'),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await settle(tester);
      verifyNever(
        () => core.migrateTailscaleLegacy(
          any(),
          offerToken: any(named: 'offerToken'),
        ),
      );
      await teardownView(tester);
    });

    Future<void> migrate(WidgetTester tester) async {
      await pumpPanel(tester);
      await tester.tap(find.text('迁移到这个节点'));
      await settle(tester);
      await tester.tap(find.text('确认迁移'));
      await settle(tester);
    }

    testWidgets('the confirmed token is what the Core receives', (
      tester,
    ) async {
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
      await migrate(tester);

      verify(
        () => core.migrateTailscaleLegacy(any(), offerToken: 'offer-1'),
      ).called(1);
      expect(find.text('迁移信息已变化，请重新核对后确认。'), findsOneWidget);
      await teardownView(tester);
    });

    for (final (stage, text) in [
      (TailscaleMigrateStage.copy, '登录记录未迁移，原记录仍保留。请重试，或选择重新登录。'),
      (TailscaleMigrateStage.claim, '登录记录未迁移，迁移信息未能保存。请重试，或选择重新登录。'),
    ]) {
      testWidgets('an explicit failure at ${stage.name} keeps both choices', (
        tester,
      ) async {
        serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
        when(
          () => core.migrateTailscaleLegacy(
            any(),
            offerToken: any(named: 'offerToken'),
          ),
        ).thenAnswer(
          (_) async => tsMigrateResult(
            TailscaleMigrateOutcome.failed,
            targetUntouched: true,
            archiveIntact: true,
            stage: stage,
            error: 'permission denied',
          ),
        );
        await migrate(tester);

        expect(find.text(text), findsOneWidget);
        expect(find.textContaining('permission denied'), findsNothing);
        expect(find.text('重试迁移'), findsOneWidget);
        expect(find.text('重新登录'), findsOneWidget);
        await teardownView(tester);
      });
    }

    for (final (name, answer, text) in [
      (
        'a failure whose archive no longer verifies',
        () async => tsMigrateResult(
          TailscaleMigrateOutcome.failed,
          targetUntouched: true,
          archiveIntact: false,
          stage: TailscaleMigrateStage.copy,
          error: 'disk full',
        ),
        '迁移结果待确认，原登录记录暂时无法核验。请先重新读取状态，确认前请勿重复迁移或重新登录。',
      ),
      (
        'a copy that did not read back',
        () async => tsMigrateResult(
          TailscaleMigrateOutcome.unknown,
          archiveIntact: true,
          stage: TailscaleMigrateStage.verify,
          error: 'the copy did not read back as written',
        ),
        '迁移结果待确认，尚未确认目标节点的登录记录。请先重新读取状态，确认前请勿重复迁移或重新登录。',
      ),
      (
        'a failed copy write with the target left',
        () async => tsMigrateResult(
          TailscaleMigrateOutcome.unknown,
          archiveIntact: true,
          stage: TailscaleMigrateStage.copy,
          error: 'sync failed',
        ),
        '迁移结果待确认，迁移信息未能保存。请先重新读取状态，确认前请勿重复迁移或重新登录。',
      ),
      (
        'an unconfirmed copy whose archive changed',
        () async => tsMigrateResult(
          TailscaleMigrateOutcome.unknown,
          archiveIntact: false,
          stage: TailscaleMigrateStage.verify,
        ),
        '迁移结果待确认，原登录记录暂时无法核验。请先重新读取状态，确认前请勿重复迁移或重新登录。',
      ),
      (
        'no answer',
        () async => throw TimeoutException('migrate'),
        '迁移结果待确认。请先重新读取状态，确认前请勿重复迁移或重新登录。',
      ),
    ]) {
      testWidgets('$name names only what the Core proved', (tester) async {
        serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
        when(
          () => core.migrateTailscaleLegacy(
            any(),
            offerToken: any(named: 'offerToken'),
          ),
        ).thenAnswer((_) => answer());
        await migrate(tester);

        expect(find.text(text), findsOneWidget);
        expect(find.textContaining('原记录仍保留'), findsNothing);
        expect(find.text('重新读取状态'), findsOneWidget);
        expect(find.text('重试迁移'), findsNothing);
        expect(find.text('重新登录'), findsNothing);
        await teardownView(tester);
      });
    }

    testWidgets('an archive unreadable at the migration says nothing moved', (
      tester,
    ) async {
      serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
      when(
        () => core.migrateTailscaleLegacy(
          any(),
          offerToken: any(named: 'offerToken'),
        ),
      ).thenThrow(
        const CoreMethodException(
          code: 'tailscale_legacy_unreadable',
          message: 'decode',
        ),
      );
      await migrate(tester);

      expect(find.text('登录记录未迁移，无法读取旧登录记录。请重新核对。'), findsOneWidget);
      expect(find.textContaining('decode'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('an unknown outcome offers only 重新读取状态 and outlives the '
        'page', (tester) async {
      serve([tsLegacyNode()], TailscaleStatus(node: tsLegacyNode()));
      when(
        () => core.migrateTailscaleLegacy(
          any(),
          offerToken: any(named: 'offerToken'),
        ),
      ).thenAnswer(
        (_) async => tsMigrateResult(
          TailscaleMigrateOutcome.unknown,
          archiveIntact: true,
        ),
      );
      await migrate(tester);

      void expectPending() {
        expect(find.textContaining('迁移结果待确认'), findsOneWidget);
        expect(find.text('重新读取状态'), findsOneWidget);
        expect(find.text('迁移到这个节点'), findsNothing);
        expect(find.text('重试迁移'), findsNothing);
        expect(find.text('重新登录'), findsNothing);
        expect(find.text('登录 Tailscale'), findsNothing);
      }

      expectPending();
      await teardownView(tester);
      await pumpPanel(tester);
      expectPending();
      await teardownView(tester);
    });

    testWidgets('success says the record moved and follows the real state', (
      tester,
    ) async {
      final legacy = tsLegacyNode();
      serve([legacy], TailscaleStatus(node: legacy));
      when(
        () => core.startTailscale(any()),
      ).thenAnswer((_) => Completer<TailscaleNode>().future);
      when(
        () => core.migrateTailscaleLegacy(
          any(),
          offerToken: any(named: 'offerToken'),
        ),
      ).thenAnswer(
        (_) async => tsMigrateResult(
          TailscaleMigrateOutcome.migrated,
          archiveIntact: true,
          node: legacy.copyWith(hasIdentity: true, legacy: null),
        ),
      );
      await migrate(tester);

      expect(find.text('登录记录已迁移，正在读取节点状态。'), findsOneWidget);
      expect(find.text('正在启动…'), findsWidgets);
      expect(find.text('已连接'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('a reason shows only after an offer was made', (tester) async {
      final node = tsLegacyNode(
        eligibility: TailscaleLegacyEligibility.controlMismatch,
        token: null,
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);
      expect(find.textContaining('控制服务器与此节点不一致'), findsNothing);
      expect(find.text('登录 Tailscale'), findsOneWidget);
      await teardownView(tester);

      container
          .read(tailscaleLegacyStatesProvider.notifier)
          .change(node.key, (state) => state.copyWith(offered: true));
      await pumpPanel(tester);
      expect(find.text('旧登录记录的控制服务器与此节点不一致，无法迁移。'), findsOneWidget);
      expect(find.text('登录 Tailscale'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('an unreadable eligibility is said, not hidden', (
      tester,
    ) async {
      final node = tsLegacyNode(
        eligibility: TailscaleLegacyEligibility.unconfirmed,
        token: null,
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('旧登录记录的可用状态尚未确认，请重新读取状态。'), findsOneWidget);
      await teardownView(tester);
    });
  });
}
