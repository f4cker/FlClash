import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/tailscale/tailscale.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/tailscale/device_card.dart';
import 'package:fl_clash/views/tailscale/rules_view.dart';
import 'package:fl_clash/views/tailscale/settings_cards.dart';
import 'package:fl_clash/views/tailscale/state.dart';
import 'package:fl_clash/views/tailscale/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_ui/icons/icons.dart' show GlyphIcon, Glyphs;
import 'package:prism_ui/prism_ui.dart'
    show
        BuildContextExtension,
        Chip,
        ColorSchemeExtension,
        PopupAnchor,
        PopupMenuCard,
        SearchField,
        Switch,
        TonalButton,
        Tooltip;

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

  Future<void> pumpPanel(WidgetTester tester, {Size size = _size}) async {
    container.read(viewSizeProvider.notifier).update((_) => size);
    tester.view.physicalSize = size;
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

    testWidgets('no node offers sign-in from the panel, never 前往配置', (
      tester,
    ) async {
      serve(const []);
      await pumpPanel(tester);

      expect(find.text('登录 Tailscale'), findsWidgets);
      expect(find.text('登录后自动添加节点和专用规则。'), findsOneWidget);
      expect(find.textContaining('不会自动开启系统代理或虚拟网卡。'), findsNothing);
      expect(find.text('前往配置'), findsNothing);
      await tester.tap(find.byTooltip('Tailscale 说明'));
      await settle(tester);
      expect(find.text('不会自动开启系统代理或虚拟网卡。'), findsOneWidget);
      expect(find.textContaining('原配置文件保持不变'), findsOneWidget);
      verifyNever(
        () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
      );
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

    testWidgets('the account switcher shows from one node on', (tester) async {
      serve([tsSignedOutNode]);
      when(
        () => core.getTailscaleStatus(any()),
      ).thenAnswer((_) async => const TailscaleStatus(node: tsSignedOutNode));
      await pumpPanel(tester);

      expect(find.text('ts-home'), findsWidgets);
      expect(find.text('· 未登录'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('当前查看的 Tailscale 账号：ts-home')),
        findsOneWidget,
      );
      await teardownView(tester);
    });
  });

  group('page layout', () {
    testWidgets(
      'the first card opens under the bar on the title\'s line, barless',
      (tester) async {
        serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
        await pumpPanel(tester, size: const Size(1054, 772));

        final card = find.byType(TailscaleDeviceCard);
        final cardBox = tester.getRect(card);
        expect(cardBox.top, tester.element(card).contentTopPadding);
        expect(cardBox.left, tester.getRect(find.text('Tailscale')).left);
        expect(
          find.descendant(
            of: find.byType(TailscaleRulesCard),
            matching: find.byType(DashboardCardHeader),
          ),
          findsOneWidget,
        );

        await tester.drag(card, const Offset(0, -200));
        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.foregroundPainter is ScrollbarPainter,
          ),
          findsNothing,
        );
        await teardownView(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  group('panel-added accounts', () {
    // Held, so the values set here outlive the gap before the page watches.
    void hold() {
      container.listen(currentProfileIdProvider, (_, _) {});
      container.listen(patchClashConfigProvider, (_, _) {});
    }

    Future<void> seed(List<TailscaleManagedRecord> records) async {
      hold();
      container.read(currentProfileIdProvider.notifier).value = 42;
      await container
          .read(tailscaleManagedRecordsProvider.notifier)
          .modify((_) => records);
    }

    const records = [
      TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
      TailscaleManagedRecord(id: 'm2', profileId: 42, attached: true),
    ];

    void serveAccounts({TailscaleRoutes? routes}) {
      serve([
        tsManagedNode('m1'),
        tsManagedNode('m2', account: tsWorkAccount),
      ], tsConnectedStatus(node: tsManagedNode('m1')));
      when(
        () => core.getTailscaleRoutes(42),
      ).thenAnswer((_) async => routes ?? const TailscaleRoutes(profileId: 42));
    }

    testWidgets('the switcher lists every account and the add row', (
      tester,
    ) async {
      await seed(records);
      serveAccounts();
      await pumpPanel(tester);

      final pill = find.bySemanticsLabel(
        RegExp('当前查看的 Tailscale 账号：pat@example.test，已连接，共 2 项'),
      );
      expect(pill, findsOneWidget);
      await tester.tap(pill);
      await settle(tester);

      expect(find.text('当前配置中的 Tailscale 账号'), findsOneWidget);
      expect(find.text('添加 Tailscale 账号'), findsOneWidget);
      expect(find.text('面板添加'), findsNothing);
      expect(find.text('设为默认账号'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('an attached account names its own rules and blocks the rest', (
      tester,
    ) async {
      await seed(records);
      serveAccounts(routes: tsConflictRoutes());
      await pumpPanel(tester);

      expect(find.text('example-net.test.ts.net · 9 个设备地址'), findsOneWidget);
      expect(find.text('网络域名：example-net.test.ts.net'), findsNothing);
      expect(find.textContaining('会被拦截，不会改用其他账号或直连'), findsNothing);
      expect(find.textContaining('Flash 会按此账号'), findsNothing);
      expect(find.text('退出此账号'), findsOneWidget);
      await tester.tap(find.byTooltip('规则说明'));
      await settle(tester);
      expect(find.textContaining('会被拦截，不会改用其他账号或直连'), findsOneWidget);
      expect(find.textContaining('Flash 会按此账号'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets(
      'a conflict is a banner, a row tag and a choice the Core gets',
      (tester) async {
        await seed(records);
        serveAccounts(routes: tsConflictRoutes());
        when(() => core.assignTailscaleRoutes(42, any())).thenAnswer(
          (_) async => const TailscaleAssignResult(outcome: 'applied'),
        );
        await pumpPanel(tester);

        expect(find.textContaining('1 个目标需要指定账号'), findsOneWidget);
        expect(find.text('地址冲突'), findsOneWidget);
        await tester.tap(find.text('指定账号'));
        await settle(tester);

        expect(find.text('地址：100.94.68.92'), findsOneWidget);
        expect(find.text('build-mac'), findsOneWidget);
        await tester.tap(find.text('build-mac'));
        await tester.pump();
        await tester.tap(find.text('保存选择'));
        await settle(tester);

        final sent =
            verify(
                  () => core.assignTailscaleRoutes(42, captureAny()),
                ).captured.single
                as List<TailscaleRouteAssignment>;
        expect(sent, const [
          TailscaleRouteAssignment(
            target: tsConflictTarget,
            owner: TailscaleRouteOwner(kind: tailscaleOwnerManaged, id: 'm2'),
          ),
        ]);
        await teardownView(tester);
      },
    );

    testWidgets('a conflicting row offers the choice for its own target', (
      tester,
    ) async {
      await seed(records);
      serveAccounts(routes: tsConflictRoutes());
      await pumpPanel(tester);

      final press = tester.getCenter(find.text('地址冲突'));
      await tester.longPressAt(press);
      await settle(tester);
      expect(find.text('指定访问账号'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(PopupMenuCard)), press);
      await tester.tap(find.text('指定访问账号'));
      await settle(tester);

      expect(find.text('指定目标的访问账号'), findsOneWidget);
      expect(find.text('地址：100.94.68.92'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('the rules page groups rules by account and lists choices', (
      tester,
    ) async {
      await seed(records);
      final base = tsConflictRoutes();
      serveAccounts(
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
      await pumpPanel(tester);

      await tester.tap(find.text('前往规则'));
      await settle(tester);

      expect(find.text('pat@example.test'), findsWidgets);
      expect(find.text('网络域名：work-net.test.ts.net'), findsOneWidget);
      expect(find.text('已指定的目标'), findsOneWidget);
      final warning = tester.element(find.text('已指定的目标')).colorScheme.warning;
      for (final status in [
        '尚未指定',
        '已指定：pat@work.test 指定账号暂不可用，此目标不会改用其他账号。',
      ]) {
        final row = find.textContaining(status);
        expect(row, findsOneWidget);
        expect(tester.widget<Text>(row).style?.color, warning);
        final icon = tester.widget<GlyphIcon>(
          find.descendant(of: row, matching: find.byType(GlyphIcon)),
        );
        expect((icon.size, icon.color), (12.0, warning));
      }
      final assigned = find.text('已指定：pat@example.test');
      expect(tester.widget<Text>(assigned).style, isNull);
      expect(
        find.descendant(of: assigned, matching: find.byType(GlyphIcon)),
        findsNothing,
      );
      expect(find.text('重新指定账号'), findsNWidgets(2));
      await teardownView(tester);
    });

    testWidgets('the rules sheet keeps its state rows and moves the rest '
        'behind info', (tester) async {
      await seed(records);
      serveAccounts(routes: tsConflictRoutes());
      await pumpPanel(tester);
      await tester.tap(find.text('前往规则'));
      await settle(tester);

      expect(find.text('面板添加'), findsNothing);
      expect(find.text('已接入当前配置'), findsWidgets);
      expect(find.text('网络域名：example-net.test.ts.net'), findsOneWidget);
      expect(find.text('设备地址：9 个'), findsOneWidget);
      expect(find.textContaining('Tailscale 流量使用专用规则'), findsNothing);
      expect(find.textContaining('面板添加的专用规则'), findsNothing);
      expect(find.textContaining('未匹配到可靠归属'), findsNothing);

      await tester.tap(
        find
            .descendant(
              of: find.byType(TailscaleRulesView),
              matching: find.byTooltip('说明'),
            )
            .first,
      );
      await settle(tester);
      expect(find.textContaining('未匹配到可靠归属'), findsOneWidget);
      await tester.tapAt(
        tester.getRect(find.byType(TailscaleRulesView)).bottomLeft +
            const Offset(24, -24),
      );
      await settle(tester);
      expect(find.textContaining('未匹配到可靠归属'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(TailscaleRulesView),
          matching: find.byTooltip('规则说明'),
        ),
      );
      await settle(tester);
      expect(find.textContaining('面板添加的专用规则'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a blocked target of the account stays inline on the rules '
        'card', (tester) async {
      await seed(records);
      serveAccounts(
        routes: tsConflictRoutes().copyWith(
          targets: const [
            TailscaleRouteTargetReport(
              target: TailscaleRouteTarget(
                kind: tailscaleTargetIp,
                value: '100.64.0.7',
              ),
              state: TailscaleRouteState.unavailable,
              owner: TailscaleRouteOwner(kind: tailscaleOwnerManaged, id: 'm1'),
            ),
          ],
        ),
      );
      await pumpPanel(tester);

      expect(find.text('example-net.test.ts.net · 9 个设备地址'), findsOneWidget);
      expect(find.text('指定账号暂不可用，此目标不会改用其他账号。'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a stale account report says so and locks nothing', (
      tester,
    ) async {
      await seed(records);
      serveAccounts(
        routes: const TailscaleRoutes(
          profileId: 42,
          active: true,
          accounts: [TailscaleRouteAccountReport(id: 'm1', addresses: 9)],
        ),
      );
      await pumpPanel(tester);

      expect(find.textContaining('个设备地址'), findsNothing);
      expect(find.text('域名和地址信息待确认'), findsOneWidget);
      expect(find.byTooltip('规则说明'), findsOneWidget);
      await tester.tap(find.text('前往规则'));
      await settle(tester);
      final sheet = find.byType(TailscaleRulesView);
      expect(sheet, findsOneWidget);
      Finder inSheet(String text) =>
          find.descendant(of: sheet, matching: find.text(text));
      final attached = inSheet('已接入当前配置');
      final unconfirmed = inSheet('域名和地址信息待确认');
      expect(attached, findsNWidgets(2));
      expect(unconfirmed, findsNWidgets(2));
      for (var index = 0; index < 2; index++) {
        expect(
          tester.getTopLeft(unconfirmed.at(index)).dy,
          greaterThan(tester.getTopLeft(attached.at(index)).dy),
        );
      }
      expect(
        find.descendant(of: sheet, matching: find.textContaining('网络域名：')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('设备地址：')),
        findsNothing,
      );
      await teardownView(tester);
    });

    testWidgets('a panel-added account goes untagged on its card', (
      tester,
    ) async {
      await seed(records);
      serveAccounts();
      await pumpPanel(tester);

      expect(find.text('面板添加'), findsNothing);
      expect(find.text('已连接'), findsWidgets);
      await teardownView(tester);
    });

    testWidgets('a cancelled choice never reaches the Core', (tester) async {
      await seed(records);
      serveAccounts(routes: tsConflictRoutes());
      await pumpPanel(tester);

      await tester.tap(find.text('指定账号'));
      await settle(tester);
      await tester.tap(find.text('build-mac'));
      await tester.pump();
      await tester.tap(find.text('取消'));
      await settle(tester);

      verifyNever(() => core.assignTailscaleRoutes(any(), any()));
      await teardownView(tester);
    });

    testWidgets('直连 mode says the routing is not in effect', (tester) async {
      await seed(records);
      serveAccounts();
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(mode: Mode.direct));
      await pumpPanel(tester);

      expect(find.textContaining('当前为直连模式'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('退出并移除 sits in the more menu and asks first', (tester) async {
      await seed(records);
      serveAccounts();
      await pumpPanel(tester);

      await tester.tap(find.byTooltip('更多'));
      await settle(tester);
      await tester.tap(find.text('退出并移除…'));
      await settle(tester);

      expect(find.text('退出并移除此账号？'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.excludeSemantics &&
              (widget.properties.label ?? '').startsWith(
                '将退出“pat@example.test”（节点“tailscale-m1”）',
              ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await settle(tester);
      verifyNever(() => core.logoutTailscale(any()));
      await teardownView(tester);
    });

    testWidgets('a draft signed in before a restart waits for 重试接入', (
      tester,
    ) async {
      await seed(const [TailscaleManagedRecord(id: 'm1', profileId: 42)]);
      final draft = tsManagedNode('m1', attached: false);
      serve([draft], tsConnectedStatus(node: draft));
      when(
        () => core.getTailscaleRoutes(42),
      ).thenAnswer((_) async => const TailscaleRoutes(profileId: 42));
      await pumpPanel(tester);
      await settle(tester);

      expect(find.text('重试接入'), findsOneWidget);
      expect(
        container.read(tailscaleManagedRecordsProvider)!.single.attached,
        isFalse,
      );
      verifyNever(() => core.startTailscale(any()));
      await teardownView(tester);
    });

    testWidgets('no node: the tap is what adds an account, then signs in', (
      tester,
    ) async {
      hold();
      container.read(currentProfileIdProvider.notifier).value = 42;
      serve(const []);
      await pumpPanel(tester);
      verifyNever(
        () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
      );
      expect(container.read(tailscaleManagedRecordsProvider), isEmpty);
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
      expect(find.text('登录并连接后可更改'), findsNWidgets(2));
      expect(find.textContaining('已保存'), findsNothing);
      expect(find.text('不使用出口节点'), findsNothing);
      expect(find.text('登录后可查看'), findsOneWidget);
      expect(find.text('设备'), findsNothing);
      expect(find.text('前往规则'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('未登录 names a saved choice as saved, never as in effect', (
      tester,
    ) async {
      final node = tsSignedOutNode.copyWith(
        settings: const TailscaleSettings(
          exitNode: TailscaleExitNodeSetting(
            source: TailscaleSettingSource.override,
          ),
          acceptRoutes: TailscaleAcceptRoutesSetting(
            value: true,
            source: TailscaleSettingSource.override,
          ),
        ),
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('登录并连接后可更改'), findsNWidgets(2));
      expect(find.text('已保存：不使用出口节点'), findsOneWidget);
      expect(find.text('已保存：已开启'), findsOneWidget);
      expect(find.text('本机设置'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('已连接 shows address, identity and the device table', (
      tester,
    ) async {
      serve([tsConnectedNode], tsConnectedStatus());
      await pumpPanel(tester);

      expect(find.text('已连接'), findsWidgets);
      expect(find.text('100.101.7.58'), findsOneWidget);
      expect(find.text('pat@example.test'), findsWidgets);
      expect(find.text('example-net.test'), findsOneWidget);
      expect(find.text('设备'), findsOneWidget);
      expect(find.text('归属'), findsOneWidget);
      expect(find.text('我'), findsWidgets);
      expect(find.text('退出当前节点'), findsOneWidget);
      expect(find.text('当前显示 4 台设备'), findsNothing);
      expect(find.textContaining('显示 4 / 4'), findsNothing);
      expect(find.text('显示当前节点可见的设备，不代表管理后台中的全部设备'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('the owner filter and its empty result', (tester) async {
      serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
      await pumpPanel(tester);

      expect(find.text('设备归属'), findsNothing);
      expect(find.text('显示 8 / 8 台'), findsNothing);
      await tester.tap(find.textContaining('我的'));
      await settle(tester);
      expect(find.text('显示 2 / 8 台'), findsOneWidget);

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
    testWidgets('the cards show title, value and control; the rest opens '
        'from info', (tester) async {
      serve([tsConnectedNode], tsConnectedStatus());
      await pumpPanel(tester);

      expect(find.text('不使用出口节点'), findsOneWidget);
      expect(find.text('不使用出口节点不会退出 Tailscale'), findsNothing);
      expect(find.textContaining('只影响经此 Tailscale 节点转发的流量'), findsNothing);
      expect(find.text('接受子网路由'), findsOneWidget);
      expect(find.text('已开启'), findsNothing);
      expect(find.text('已关闭'), findsNothing);
      expect(find.textContaining('允许此节点使用'), findsNothing);
      expect(find.text('显示当前节点可见的设备，不代表管理后台中的全部设备'), findsNothing);

      await tester.tap(find.byTooltip('出口设置说明'));
      await settle(tester);
      expect(find.textContaining('只影响经此 Tailscale 节点转发的流量'), findsOneWidget);
      await tester.tap(find.byTooltip('子网路由说明'));
      await settle(tester);
      expect(find.textContaining('只影响经此 Tailscale 节点转发的流量'), findsNothing);
      expect(find.textContaining('允许此节点使用'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.textContaining('允许此节点使用'), findsNothing);

      await tester.tap(find.byTooltip('说明'));
      await settle(tester);
      expect(find.text('显示当前节点可见的设备，不代表管理后台中的全部设备'), findsOneWidget);
      await teardownView(tester);
    });

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
          code: 'tailscale_override_ambiguous',
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

    testWidgets('a provider node says where its setting comes from', (
      tester,
    ) async {
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

      expect(find.text('来自代理集合'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a name shared with another source locks both settings', (
      tester,
    ) async {
      final node = tsConnectedNode.copyWith(overridable: false);
      serve([node], tsConnectedStatus(node: node));
      await pumpPanel(tester);

      expect(
        find.text('当前配置中有多个同名节点使用同一控制服务器，暂时无法分别保存设置。请在配置中为它们使用不同名称。'),
        findsNWidgets(2),
      );
      await tester.tap(find.text('接受子网路由'));
      await settle(tester);
      expect(find.text('停止接受子网路由？'), findsNothing);
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

  group('design review', () {
    test('a system reads as its vendor writes it', () {
      expect(tailscaleSystemName('linux'), 'Linux');
      expect(tailscaleSystemName('darwin'), 'macOS');
      expect(tailscaleSystemName('iOS'), 'iOS');
      expect(tailscaleSystemName('ipados'), 'iPadOS');
      expect(tailscaleSystemName('tvos'), 'tvOS');
      expect(tailscaleSystemName('freebsd'), 'FreeBSD');
      expect(tailscaleSystemName('haiku'), 'Haiku');
    });

    testWidgets('the table names systems properly', (tester) async {
      serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
      await pumpPanel(tester);

      expect(find.text('Linux'), findsWidgets);
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('linux'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('a long name keeps its line and the tag goes under it', (
      tester,
    ) async {
      const name = 'nas-sg-exit-0001';
      final status = tsConnectedStatus();
      serve([
        tsConnectedNode,
      ], status.copyWith(peers: [status.peers[1].copyWith(hostName: name)]));
      await pumpPanel(tester);

      final nameBox = tester.getRect(find.text(name));
      final tagBox = tester.getRect(find.text('可作出口节点'));
      expect(tagBox.top, greaterThanOrEqualTo(nameBox.bottom));
      expect(
        tester.renderObject<RenderParagraph>(find.text(name)).didExceedMaxLines,
        isFalse,
      );
      await teardownView(tester);
    });

    Future<void> seedRecord(TailscaleNodeRecord record) async {
      container.listen(tailscaleNodeRecordsProvider, (_, _) {});
      await container
          .read(tailscaleNodeRecordsProvider.notifier)
          .modify(record.key, (_) => record);
    }

    TailscaleNode savedExit(String value) => tsSignedOutNode.copyWith(
      settings: TailscaleSettings(
        exitNode: TailscaleExitNodeSetting(
          value: value,
          source: TailscaleSettingSource.override,
        ),
      ),
    );

    testWidgets('a saved exit node shows the name kept with it', (
      tester,
    ) async {
      final node = savedExit('100.88.12.4');
      await seedRecord(
        TailscaleNodeRecord(
          profileId: node.profileId,
          name: node.name,
          controlUrl: node.controlUrl,
          exitNode: '100.88.12.4',
          exitNodeName: 'nas-sg',
        ),
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('已保存：nas-sg'), findsOneWidget);
      expect(find.text('已保存：100.88.12.4'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('a saved exit node without a matching name shows its address', (
      tester,
    ) async {
      final node = savedExit('100.88.12.4');
      await seedRecord(
        TailscaleNodeRecord(
          profileId: node.profileId,
          name: node.name,
          controlUrl: node.controlUrl,
          exitNode: '100.88.12.9',
          exitNodeName: 'nas-old',
        ),
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('已保存：100.88.12.4'), findsOneWidget);
      expect(find.textContaining('nas-old'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('an old record without a name shows the address', (
      tester,
    ) async {
      final node = savedExit('100.88.12.4');
      await seedRecord(
        TailscaleNodeRecord.fromJson({
          'profile-id': node.profileId,
          'name': node.name,
          'control-url': node.controlUrl,
          'exit-node': '100.88.12.4',
        }),
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('已保存：100.88.12.4'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a value the profile sets is never shown as saved', (
      tester,
    ) async {
      final node = tsSignedOutNode.copyWith(
        settings: const TailscaleSettings(
          exitNode: TailscaleExitNodeSetting(
            value: '100.88.12.4',
            source: TailscaleSettingSource.profile,
          ),
        ),
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.textContaining('已保存'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('signed in but not connected asks only to connect', (
      tester,
    ) async {
      final node = tsConnectedNode.copyWith(
        backendState: TailscaleBackendState.needsMachineAuth,
      );
      serve([node], TailscaleStatus(node: node));
      await pumpPanel(tester);

      expect(find.text('此节点连接后可更改设置。'), findsNWidgets(2));
      expect(find.text('登录并连接后可更改'), findsNothing);
      await teardownView(tester);
    });

    testWidgets('a narrow table drops 系统 and keeps status and copy', (
      tester,
    ) async {
      serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
      await pumpPanel(tester, size: const Size(520, 1400));

      expect(find.text('状态'), findsOneWidget);
      expect(find.text('系统'), findsNothing);
      final page = tester.getRect(find.byType(TailscaleView));
      for (final finder in [
        find.text('在线'),
        find.text('离线'),
        find.byTooltip('复制地址'),
      ]) {
        expect(finder, findsWidgets);
        for (var i = 0; i < finder.evaluate().length; i++) {
          expect(
            tester.getRect(finder.at(i)).right,
            lessThanOrEqualTo(page.right),
          );
        }
      }
      for (final element in find.text('在线').evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      await teardownView(tester);
    });

    final moreChip = find.textContaining(RegExp(r'^\+\d+$'));

    void expectCompactHeader(WidgetTester tester) {
      final title = tester.getRect(find.text('设备'));
      final search = tester.getRect(find.byType(SearchField));
      expect(search.center.dy, moreOrLessEquals(title.center.dy, epsilon: 1));
      expect(search.height, 32);
      expect(search.width, inInclusiveRange(160, 220));
      expect(find.text('设备归属'), findsNothing);
      final chips = [
        for (var i = 0; i < find.byType(Chip).evaluate().length; i++)
          tester.getRect(find.byType(Chip).at(i)),
        if (moreChip.evaluate().isNotEmpty) tester.getRect(moreChip),
      ];
      final page = tester.getRect(find.byType(TailscaleView));
      for (final chip in chips) {
        expect(chip.center.dy, moreOrLessEquals(chips.first.center.dy));
        expect(chip.right, lessThanOrEqualTo(page.right));
      }
      final row = chips.first;
      final table = tester.getRect(
        find
            .ancestor(
              of: find.text('Tailscale 地址'),
              matching: find.byType(TailscaleCard),
            )
            .first,
      );
      expect(row.top - search.bottom, moreOrLessEquals(10, epsilon: 0.5));
      expect(table.top - row.bottom, moreOrLessEquals(12, epsilon: 0.5));
    }

    for (final width in [520.0, 640.0]) {
      testWidgets('at $width the header keeps search beside the title and '
          'the owners on one line', (tester) async {
        serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
        await pumpPanel(tester, size: Size(width, 1400));

        expectCompactHeader(tester);
        expect(find.text('全部 8'), findsOneWidget);
        expect(find.text('我的 2'), findsOneWidget);
        expect(find.textContaining('仅显示此账号可见的设备'), findsNothing);
        expect(find.textContaining('台设备'), findsNothing);
        expect(find.textContaining('显示 8 / 8'), findsNothing);
        await teardownView(tester);
      });
    }

    Finder checkIn(Finder menu) => find.descendant(
      of: menu,
      matching: find.byWidgetPredicate(
        (widget) => widget is GlyphIcon && widget.glyph == Glyphs.check,
      ),
    );

    void expectMenuUnderChip(WidgetTester tester) {
      final chip = tester.getRect(
        find.ancestor(of: moreChip, matching: find.byType(PopupAnchor)),
      );
      final menu = tester.getRect(find.byType(PopupMenuCard));
      final content = tester.getRect(
        find
            .ancestor(
              of: find.text('Tailscale 地址'),
              matching: find.byType(TailscaleCard),
            )
            .first,
      );
      expect(menu.top - chip.bottom, moreOrLessEquals(4, epsilon: 0.5));
      expect(
        menu.left,
        moreOrLessEquals(math.min(chip.left, content.right - menu.width)),
      );
      expect(menu.right, lessThanOrEqualTo(content.right + 0.5));
    }

    testWidgets('owners that do not fit open from +N and stay in view once '
        'chosen', (tester) async {
      serve([tsConnectedNode], tsConnectedStatus(manyPeers: true));
      await pumpPanel(tester, size: const Size(520, 1400));

      expect(moreChip, findsOneWidget);
      expect(find.text('归属未知 1'), findsNothing);
      final hidden = int.parse(
        tester.widget<Text>(moreChip).data!.substring(1),
      );
      await tester.tap(moreChip);
      await settle(tester);
      expect(find.text('归属未知 1'), findsOneWidget);
      expectMenuUnderChip(tester);
      expect(checkIn(find.byType(PopupMenuCard)), findsNothing);

      await tester.tap(find.text('归属未知 1'));
      await settle(tester);
      expect(find.text('显示 1 / 8 台'), findsOneWidget);
      final chosen = find.ancestor(
        of: find.text('归属未知 1'),
        matching: find.byType(Chip),
      );
      expect(tester.widget<Chip>(chosen).selected, isTrue);
      expect(tester.widget<Text>(moreChip).data, '+$hidden');
      expect(
        tester.getRect(chosen).center.dy,
        moreOrLessEquals(tester.getRect(moreChip).center.dy),
      );

      await tester.tap(moreChip);
      await settle(tester);
      expectMenuUnderChip(tester);
      final menu = find.byType(PopupMenuCard);
      final checked = find.descendant(of: menu, matching: find.text('归属未知 1'));
      expect(checked, findsOneWidget);
      expect(checkIn(menu), findsOneWidget);
      expect(
        tester.getRect(checkIn(menu)).center.dy,
        moreOrLessEquals(tester.getRect(checked).center.dy, epsilon: 1),
      );
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);

      await tester.enterText(find.byType(EditableText), 'printer');
      await settle(tester);
      expect(find.text('显示 1 / 8 台'), findsOneWidget);
      await teardownView(tester);
    });

    testWidgets('a locked switch keeps its look and fades as a whole', (
      tester,
    ) async {
      serve([tsSignedOutNode], const TailscaleStatus(node: tsSignedOutNode));
      await pumpPanel(tester);

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(Switch),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.45);
      await teardownView(tester);
    });

    testWidgets('a name wider than the line is cut in its middle, whole '
        'on hover', (tester) async {
      const name = 'a-very-long-account-name@a-very-long-tailnet.example.test';
      await tester.pumpWidget(
        TestApp(
          child: Center(
            child: SizedBox(
              width: 160,
              child: TailscaleNamedText(
                fill: (names) => '将退出“${names[0]}”。',
                names: const [name],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final shown = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == name,
      );
      expect(shown, findsOneWidget);
      expect(tester.getSize(shown).width, lessThanOrEqualTo(160));
      final full = find.descendant(of: shown, matching: find.text('“$name”。'));
      expect(full, findsOneWidget);
    });

    testWidgets('前往规则 puts its chevron after the label', (tester) async {
      serve([tsSignedOutNode], const TailscaleStatus(node: tsSignedOutNode));
      await pumpPanel(tester);

      final button = find.byType(TonalButton);
      final label = tester.getRect(
        find.descendant(of: button, matching: find.text('前往规则')),
      );
      final glyph = tester.getRect(
        find.descendant(of: button, matching: find.byType(GlyphIcon)),
      );
      expect(glyph.left - label.right, moreOrLessEquals(4, epsilon: 0.5));
      await teardownView(tester);
    });
  });
}
