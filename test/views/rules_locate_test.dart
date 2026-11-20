import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/rules/rule_rows.dart';
import 'package:fl_clash/views/rules/rules.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

class _NoAddedRules extends AddedRulesAction {
  @override
  Future<AddedRulesState> load(Profile profile) async =>
      (rules: const <Rule>[], sets: const <AddedRuleSet>[]);
}

const _github = CoreRule(
  index: 2,
  type: 'DOMAIN-SUFFIX',
  ruleType: 'DomainSuffix',
  payload: 'github.com',
  target: 'Proxy',
);

/// A profile rule that names the managed payload, to show rows are told by
/// the Core's flag and prefix, never by their text.
const _lookalike = CoreRule(
  index: 3,
  type: 'IP-CIDR',
  ruleType: 'IPCIDR',
  payload: 'tailscale-managed-addresses',
  target: 'DIRECT',
);

RuleList _managedList({int managed = 2}) {
  final rules = [
    if (managed > 0)
      const CoreRule(
        type: 'DOMAIN-SUFFIX',
        ruleType: 'DomainSuffix',
        payload: 'tailscale-managed-domains',
        target: 'Tailscale (Flash)',
        managed: true,
      ),
    if (managed > 1)
      const CoreRule(
        index: 1,
        type: 'IP-CIDR',
        ruleType: 'IPCIDR',
        payload: 'tailscale-managed-addresses',
        target: 'Tailscale (Flash)',
        managed: true,
      ),
    _github,
    _lookalike,
    const CoreRule(index: 4, type: 'MATCH', ruleType: 'Match', target: 'Proxy'),
  ];
  return RuleList(
    coreEpoch: 1,
    mode: 'rule',
    managedPrefix: managed,
    total: rules.length,
    rules: [
      for (final (index, rule) in rules.indexed) rule.copyWith(index: index),
    ],
  );
}

final _searchField = find.descendant(
  of: find.byType(SearchField),
  matching: find.byType(EditableText),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _MockCore core;
  final profile = Profile.normal(label: 'Airport A');
  late RuleList Function() list;
  Exception? failure;
  Completer<void>? gate;

  setUp(() {
    list = _managedList;
    failure = null;
    gate = null;
    core = _MockCore();
    when(() => core.listRules(filter: any(named: 'filter'))).thenAnswer((
      invocation,
    ) async {
      await gate?.future;
      if (failure case final error?) throw error;
      final filter = invocation.namedArguments[#filter] as String?;
      final current = list();
      if (filter == null || filter.isEmpty) return current;
      return current.copyWith(
        filtered: [
          for (final rule in current.rules)
            if (rule.text.contains(filter)) rule.index,
        ],
      );
    });
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        addedRulesActionProvider.overrideWith(_NoAddedRules.new),
      ],
    );
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
  });

  tearDown(() => container.dispose());

  Future<void> pumpRules(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    const size = Size(1000, 900);
    container.read(viewSizeProvider.notifier).update((_) => size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('zh', 'CN'), child: RulesView()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> locate(WidgetTester tester) async {
    container
        .read(rulesLocateRequestProvider.notifier)
        .ask(RulesLocateSource.tailscaleManaged);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String text) async {
    if (_searchField.evaluate().isEmpty) {
      await tester.tap(find.byGlyph(AppGlyphs.search).first);
      await tester.pumpAndSettle();
    }
    await tester.enterText(_searchField, text);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  Iterable<RuleRow> rows(WidgetTester tester) =>
      tester.widgetList<RuleRow>(find.byType(RuleRow));

  String searchText(WidgetTester tester) =>
      tester.widget<EditableText>(_searchField).controller.text;

  testWidgets('a locate shows the managed rows only, labelled and counted', (
    tester,
  ) async {
    await pumpRules(tester);
    expect(rows(tester), hasLength(5));
    await locate(tester);

    expect(container.read(rulesLocateRequestProvider), isNull);
    expect(container.read(currentPageLabelProvider), PageLabel.rules);
    expect(find.byKey(RulesView.locateKey), findsOneWidget);
    expect(find.text('当前设备的规则'), findsOneWidget);
    expect(find.text('已找到 2 条关联规则'), findsOneWidget);
    expect(find.textContaining('已命中'), findsNothing);
    expect([for (final row in rows(tester)) row.rule.index], [0, 1]);
    expect(rows(tester).every((row) => row.association == '关联规则'), isTrue);
    // The label is the only mark: no outline and no selected look.
    expect(rows(tester).every((row) => !row.highlighted), isTrue);
    expect(
      find.descendant(
        of: find.byType(RuleRow),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is ShapeDecoration &&
              ((widget.decoration as ShapeDecoration).shape as OutlinedBorder?)
                      ?.side
                      .style !=
                  BorderStyle.none,
        ),
      ),
      findsNothing,
    );
    expect(find.text('关联规则'), findsNWidgets(2));
    expect(find.text('DOMAIN-SUFFIX,github.com'), findsNothing);
    final showAll = tester.getSize(find.byKey(RulesView.locateShowAllKey));
    expect(showAll.height, greaterThanOrEqualTo(44));
    expect(showAll.width, greaterThanOrEqualTo(44));

    await tester.tap(find.byKey(RulesView.locateShowAllKey));
    await tester.pump();
    expect(find.byKey(RulesView.locateKey), findsNothing);
    expect(rows(tester), hasLength(5));
    expect(rows(tester).every((row) => row.association == null), isTrue);
    await teardown(tester);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the strip is a 6% primary tint and its link reads at '
        '4.5:1 (${mode.name})', (tester) async {
      await pumpRules(tester, themeMode: mode);
      await locate(tester);

      final context = tester.element(find.byKey(RulesView.locateKey));
      final colorScheme = context.colorScheme;
      final fill = Color.alphaBlend(
        colorScheme.primary.withValues(alpha: 0.06),
        SurfaceLevel.page.colorOf(colorScheme),
      );
      final strip = tester.widget<Container>(find.byKey(RulesView.locateKey));
      expect((strip.decoration! as ShapeDecoration).color, fill);
      for (final text in ['当前设备的规则', '已找到 2 条关联规则']) {
        expect(
          tester.widget<Text>(find.text(text)).style?.color,
          colorScheme.onSurface,
        );
      }
      final link = DefaultTextStyle.of(
        tester.element(find.text('显示全部')),
      ).style.color!;
      expect(link, locateLinkColor(colorScheme, fill));
      expect(contrastRatio(link, fill), greaterThanOrEqualTo(4.5));
      await teardown(tester);
    });
  }

  testWidgets('one managed row reads as one', (tester) async {
    list = () => _managedList(managed: 1);
    await pumpRules(tester);
    await locate(tester);

    expect(find.text('已找到 1 条关联规则'), findsOneWidget);
    expect([for (final row in rows(tester)) row.rule.index], [0]);
    await teardown(tester);
  });

  testWidgets('a search and filter step aside for a locate and come back', (
    tester,
  ) async {
    await pumpRules(tester);
    await type(tester, 'github');
    await tester.tap(find.text('规则集'));
    await tester.pump();
    expect(rows(tester), isEmpty);
    await tester.tap(find.text('全部'));
    await tester.pump();
    expect([for (final row in rows(tester)) row.rule.index], [2]);

    await locate(tester);
    expect(searchText(tester), isEmpty);
    expect(find.text('已找到 2 条关联规则'), findsOneWidget);
    expect([for (final row in rows(tester)) row.rule.index], [0, 1]);
    expect(find.text('未找到对应规则'), findsNothing);

    await tester.tap(find.byKey(RulesView.locateShowAllKey));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(searchText(tester), 'github');
    expect([for (final row in rows(tester)) row.rule.index], [2]);
    await teardown(tester);
  });

  testWidgets('a source chip set before a locate is put back', (tester) async {
    await pumpRules(tester);
    await tester.tap(find.text('规则集'));
    await tester.pump();
    expect(rows(tester), isEmpty);

    await locate(tester);
    expect([for (final row in rows(tester)) row.rule.index], [0, 1]);
    await tester.tap(find.byKey(RulesView.locateShowAllKey));
    await tester.pump();
    expect(rows(tester), isEmpty);
    expect(find.textContaining('没有找到匹配的规则'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('no managed rows says not found, never a count', (tester) async {
    list = () => _managedList(managed: 0);
    await pumpRules(tester);
    await locate(tester);

    expect(find.text('未找到对应规则'), findsOneWidget);
    expect(find.text('当前配置可能已变化。'), findsOneWidget);
    expect(find.textContaining('已找到'), findsNothing);
    expect(find.text('关联规则'), findsNothing);
    expect(rows(tester), isEmpty);
    expect(find.byKey(RulesView.locateShowAllKey), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('a failed read says the rules could not be read', (tester) async {
    await pumpRules(tester);
    failure = Exception('pipe closed');
    await locate(tester);

    expect(find.text('无法读取规则'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('未找到对应规则'), findsNothing);
    expect(find.textContaining('已找到'), findsNothing);
    expect(rows(tester), isEmpty);

    failure = null;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();
    expect(find.text('已找到 2 条关联规则'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('while reading it says so and shows no count', (tester) async {
    await pumpRules(tester);
    gate = Completer<void>();
    await locate(tester);

    expect(find.text('正在读取规则…'), findsOneWidget);
    expect(find.textContaining('已找到'), findsNothing);
    expect(find.text('未找到对应规则'), findsNothing);
    expect(rows(tester), isEmpty);

    gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('正在读取规则…'), findsNothing);
    expect(find.text('已找到 2 条关联规则'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('a second locate starts over and keeps the first stash', (
    tester,
  ) async {
    await pumpRules(tester);
    await type(tester, 'github');
    await locate(tester);
    expect(find.text('已找到 2 条关联规则'), findsOneWidget);

    list = () => _managedList(managed: 0);
    gate = Completer<void>();
    await locate(tester);
    expect(find.text('正在读取规则…'), findsOneWidget);
    expect(find.textContaining('已找到'), findsNothing);
    expect(rows(tester), isEmpty);
    gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('未找到对应规则'), findsOneWidget);

    await tester.tap(find.byKey(RulesView.locateShowAllKey));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(searchText(tester), 'github');
    await teardown(tester);
  });

  testWidgets('focus goes to the strip once, not on a later refresh', (
    tester,
  ) async {
    await pumpRules(tester);
    await locate(tester);
    await tester.pump();

    final strip = find.ancestor(
      of: find.byKey(RulesView.locateKey),
      matching: find.byType(Focus),
    );
    final node = tester.widget<Focus>(strip.first).focusNode!;
    expect(node.hasFocus, isTrue);

    node.unfocus();
    await tester.pump();
    container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    await tester.pump();
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    await tester.pump();
    await tester.pump();
    await tester.pump();
    verify(() => core.listRules(filter: any(named: 'filter'))).called(3);
    expect(find.text('已找到 2 条关联规则'), findsOneWidget);
    expect(node.hasFocus, isFalse);
    await teardown(tester);
  });

  testWidgets('leaving the page ends the locate and restores the search', (
    tester,
  ) async {
    container.listen(shownPageLabelProvider, (_, _) {});
    await pumpRules(tester);
    await type(tester, 'github');
    await locate(tester);
    expect(find.byKey(RulesView.locateKey), findsOneWidget);

    container
        .read(currentPageLabelProvider.notifier)
        .toPage(PageLabel.tailscale);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byKey(RulesView.locateKey), findsNothing);
    expect(searchText(tester), 'github');
    await teardown(tester);
  });
}
