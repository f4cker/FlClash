import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/views/proxies/node_fields.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import '../helpers/host_scaffold.dart';

const _testUrl = 'https://example.com/generate_204';

class _RecordingProxiesAction extends ProxiesAction {
  static final List<String> tested = [];
  static final List<String> changed = [];

  @override
  void changeProxyDebounce(String groupName, String proxyName) {
    changed.add(proxyName);
  }

  @override
  Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
    tested.add(proxy.name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    _RecordingProxiesAction.tested.clear();
    _RecordingProxiesAction.changed.clear();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        proxiesActionProvider.overrideWith(_RecordingProxiesAction.new),
        delayDataSourceProvider.overrideWithBuild(
          (_, _) => {
            _testUrl: {'proxy 0': 123, 'proxy 1': 456},
          },
        ),
      ],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(900, 600);
  });

  tearDown(() => container.dispose());

  Future<void> pumpCards(
    WidgetTester tester,
    ProxyCardType type, {
    List<Proxy>? proxies,
  }) async {
    final cards =
        proxies ??
        [
          for (var index = 0; index < 2; index++)
            Proxy(name: 'proxy $index', type: 'Shadowsocks'),
        ];
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          homeBuilder: (child) => HostScaffold(body: child),
          child: Column(
            children: [
              for (var index = 0; index < cards.length; index++)
                SizedBox(
                  height: 120,
                  child: ProxyCard(
                    key: ValueKey('proxy $index'),
                    groupName: 'group',
                    testUrl: _testUrl,
                    proxy: cards[index],
                    groupType: GroupType.Selector,
                    type: type,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> focusCard(WidgetTester tester, int index) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context?.findAncestorWidgetOfExactType<ProxyCard>()?.key ==
          ValueKey('proxy $index')) {
        return;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    fail('proxy card $index was not reachable by tab');
  }

  for (final type in ProxyCardType.values) {
    testWidgets('arrow right from a ${type.name} proxy card focuses its '
        'delay control', (tester) async {
      await pumpCards(tester, type);

      for (var index = 0; index < 2; index++) {
        await focusCard(tester, index);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        final focusNode = FocusManager.instance.primaryFocus;
        expect(focusNode, isA<SkipTraversalFocusNode>());
        expect(
          find.descendant(
            of: find.byWidget(focusNode!.context!.widget),
            matching: find.text(index == 0 ? '123 ms' : '456 ms'),
          ),
          findsOneWidget,
        );
      }
    });
  }

  testWidgets('tab walks card to card without stopping on the delay control', (
    tester,
  ) async {
    await pumpCards(tester, ProxyCardType.standard);

    await focusCard(tester, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // The card's own info button comes between, apart from the card.
    final info = FocusManager.instance.primaryFocus?.context;
    expect(info?.findAncestorWidgetOfExactType<InfoButton>(), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final context = FocusManager.instance.primaryFocus?.context;
    expect(
      context?.findAncestorWidgetOfExactType<ProxyCard>()?.key,
      const ValueKey('proxy 1'),
    );
  });

  testWidgets('enter on the delay control runs the delay test', (tester) async {
    await pumpCards(tester, ProxyCardType.standard);

    await focusCard(tester, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isA<SkipTraversalFocusNode>());

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(_RecordingProxiesAction.tested, ['proxy 0']);
  });

  testWidgets('the info button opens the node info without selecting', (
    tester,
  ) async {
    await pumpCards(tester, ProxyCardType.standard);
    final info = find.descendant(
      of: find.byKey(const ValueKey('proxy 1')),
      matching: find.byType(InfoButton),
    );

    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(find.byType(NodeInfoView), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(NodeInfoView), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(NodeInfoView), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(_RecordingProxiesAction.changed, isEmpty);

    // The card around it still selects.
    await tester.tap(find.text('proxy 1').first);
    await tester.pumpAndSettle();
    expect(_RecordingProxiesAction.changed, ['proxy 1']);
  });

  const vless = Proxy(
    name: 'proxy 0',
    type: 'Vless',
    udp: true,
    xudp: true,
    tfo: true,
  );

  Iterable<NodeField> iconsIn(WidgetTester tester, String key) => tester
      .widgetList<NodeFieldIcon>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(NodeFieldIcon),
        ),
      )
      .map((icon) => icon.field);

  testWidgets('arrows step through the icons to the delay and back', (
    tester,
  ) async {
    await pumpCards(tester, ProxyCardType.standard, proxies: [vless]);
    expect(iconsIn(tester, 'proxy 0'), [
      NodeField.udp,
      NodeField.xudp,
      NodeField.tfo,
    ]);
    await focusCard(tester, 0);

    NodeFieldIcon? focusedIcon() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<NodeFieldIcon>();

    // The card hands arrow right to its delay, the rightmost action; arrow
    // left then walks back over the icons to the card.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focusedIcon(), isNull);
    expect(FocusManager.instance.primaryFocus, isA<SkipTraversalFocusNode>());

    for (final field in [NodeField.tfo, NodeField.xudp, NodeField.udp]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(focusedIcon()?.field, field);
      expect(find.text(_tipOf(field)), findsOneWidget);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focusedIcon()?.field, NodeField.xudp);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focusedIcon(), isNull);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(
        isA<Focus>().having(
          (f) => f.focusNode,
          'node',
          isA<SkipTraversalFocusNode>(),
        ),
      ),
    );
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<ProxyCard>(),
      isNotNull,
    );
  });

  testWidgets('a group that disables UDP hides it on its cards', (
    tester,
  ) async {
    container.read(groupsProvider.notifier).value = [
      const Group(
        type: GroupType.Selector,
        name: 'group',
        disableUdp: true,
        all: [vless],
      ),
    ];
    await pumpCards(tester, ProxyCardType.standard, proxies: [vless]);
    expect(iconsIn(tester, 'proxy 0'), [NodeField.tfo]);
  });
}

String _tipOf(NodeField field) => switch (field) {
  NodeField.udp => 'UDP: Enabled in config',
  NodeField.xudp => 'XUDP packet encoding: Enabled in config',
  _ => 'TCP Fast Open (TFO): Enabled in config',
};
