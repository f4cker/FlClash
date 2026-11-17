import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/rules/add_rule_dialog.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/rules/rule_rows.dart';
import 'package:fl_clash/views/rules/rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

const _size = Size(1100, 1000);

final _ruleSet = RuleSetView(
  name: 'YouTube',
  behavior: 'domain',
  count: 86,
  updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
  interval: 86400,
);

final _list = RuleList(
  coreEpoch: 3,
  mode: 'rule',
  total: 4,
  rules: [
    const CoreRule(
      index: 0,
      type: 'DOMAIN-SUFFIX',
      ruleType: 'DomainSuffix',
      payload: 'github.com',
      target: 'GitHub',
    ),
    CoreRule(
      index: 1,
      type: 'RULE-SET',
      ruleType: 'RuleSet',
      payload: 'YouTube',
      target: 'YouTube',
      ruleSet: _ruleSet,
    ),
    const CoreRule(
      index: 2,
      type: 'DOMAIN-KEYWORD',
      ruleType: 'DomainKeyword',
      payload: 'youtube',
      target: 'Proxy',
    ),
    const CoreRule(index: 3, type: 'MATCH', ruleType: 'Match', target: 'Proxy'),
  ],
);

const _sources = [
  RuleSource(
    kind: RuleSourceKind.addedProfile,
    text: 'DOMAIN-SUFFIX,github.com,GitHub',
  ),
  RuleSource(
    kind: RuleSourceKind.subscription,
    text: 'RULE-SET,YouTube,YouTube',
  ),
  RuleSource(
    kind: RuleSourceKind.script,
    name: 'Enhance',
    text: 'DOMAIN-KEYWORD,youtube,Proxy',
  ),
  RuleSource(kind: RuleSourceKind.subscription, text: 'MATCH,Proxy'),
];

RuleLookup _lookup() => RuleLookup(
  coreEpoch: 3,
  mode: 'rule',
  host: 'www.youtube.com',
  ip: '142.250.1.1',
  ipSource: 'dns',
  resolveWanted: true,
  port: 443,
  total: 4,
  winner: RuleHit(
    index: 1,
    type: 'RULE-SET',
    ruleType: 'RuleSet',
    payload: 'YouTube',
    target: 'YouTube',
    ruleSet: _ruleSet,
    status: RuleHitStatus.winner,
    entry: 'DOMAIN-SUFFIX,youtube.com',
  ),
  chain: const [
    ChainHop(name: 'YouTube', type: 'Selector'),
    ChainHop(name: 'Japan 03', type: 'Vmess'),
  ],
  matches: [
    RuleHit(
      index: 1,
      type: 'RULE-SET',
      ruleType: 'RuleSet',
      payload: 'YouTube',
      target: 'YouTube',
      ruleSet: _ruleSet,
      status: RuleHitStatus.winner,
      entry: 'DOMAIN-SUFFIX,youtube.com',
    ),
    const RuleHit(
      index: 2,
      type: 'DOMAIN-KEYWORD',
      ruleType: 'DomainKeyword',
      payload: 'youtube',
      target: 'Proxy',
      status: RuleHitStatus.shadowed,
    ),
  ],
  ruleSets: [_ruleSet],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const RuleLookupParams(host: ''));
  });

  late ProviderContainer container;
  late _MockCore core;
  final profile = Profile.normal(label: 'Airport A');

  setUp(() {
    core = _MockCore();
    when(
      () => core.listRules(filter: any(named: 'filter')),
    ).thenAnswer((_) async => _list);
    when(() => core.lookupRule(any())).thenAnswer((_) async => _lookup());
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        groupsProvider.overrideWithValue([
          const Group(
            name: 'YouTube',
            type: GroupType.Selector,
            now: 'Japan 03',
            all: [Proxy(name: 'Japan 03', type: 'Vmess')],
          ),
        ]),
      ],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).update((_) => _size);
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container
        .read(appliedRuleSourcesStateProvider.notifier)
        .applied(profile.id, _sources);
  });

  tearDown(() => container.dispose());

  Future<void> pumpRules(
    WidgetTester tester, {
    Future<String?> Function(Profile profile, String text)? writeRule,
    Size size = _size,
  }) async {
    container.read(viewSizeProvider.notifier).update((_) => size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: const Locale('en'),
          child: RulesView(writeRule: writeRule),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('lists the running rules with where each came from', (
    tester,
  ) async {
    await pumpRules(tester);

    expect(
      find.text('Profile “Airport A” · 4 rules, in the order they apply'),
      findsOneWidget,
    );
    expect(find.text('DOMAIN-SUFFIX,github.com'), findsOneWidget);
    expect(find.text('RULE-SET,YouTube'), findsOneWidget);
    expect(find.text('MATCH'), findsOneWidget);
    // Badges and chips both name the sources.
    expect(find.text('Added rule'), findsNWidgets(2));
    expect(find.text('Extension script'), findsOneWidget);
    expect(find.text('Extension script · Enhance'), findsOneWidget);
    expect(find.textContaining('86 · updated'), findsOneWidget);
    expect(find.text('→ Japan 03'), findsOneWidget);
    // The Core's list was matched to the build, so the sources bind to it.
    expect(container.read(appliedRuleSourcesStateProvider).epoch, 3);

    await teardown(tester);
  });

  testWidgets('a source chip keeps only that source', (tester) async {
    await pumpRules(tester);

    await tester.tap(find.text('Added rule').first);
    await tester.pump();

    expect(find.text('DOMAIN-SUFFIX,github.com'), findsOneWidget);
    expect(find.text('MATCH'), findsNothing);

    await teardown(tester);
  });

  testWidgets('a link offers a lookup, and enter shows the rule it takes', (
    tester,
  ) async {
    await pumpRules(tester);

    await tester.enterText(
      find.byType(EditableText),
      'https://www.youtube.com/watch?v=abc',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(
      find.text('Look up which rule www.youtube.com takes'),
      findsOneWidget,
    );

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final params =
        verify(() => core.lookupRule(captureAny())).captured.single
            as RuleLookupParams;
    expect(params.host, 'www.youtube.com');
    expect(params.port, 443);
    expect(find.text('Lookup result'), findsOneWidget);
    expect(find.text('Matches rule #2'), findsOneWidget);
    expect(find.text('Japan 03'), findsOneWidget);
    expect(find.text('Rule #2 matches first'), findsOneWidget);
    expect(find.text('DOMAIN-SUFFIX,youtube.com'), findsWidgets);
    expect(find.text('Profile “Airport A”'), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('a request opens a lookup compared with the rule it took', (
    tester,
  ) async {
    container
        .read(rulesLookupRequestProvider.notifier)
        .ask('www.youtube.com', rule: 'RuleSet', rulePayload: 'YouTube');
    await pumpRules(tester);
    await tester.pump(const Duration(milliseconds: 200));

    expect(container.read(rulesLookupRequestProvider), isNull);
    expect(
      find.text(
        'The rule this connection matched then agrees with this lookup.',
      ),
      findsOneWidget,
    );

    await teardown(tester);
  });

  testWidgets('says so when the Core stops', (tester) async {
    await pumpRules(tester);

    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await tester.pump();

    expect(
      find.text(
        'The core is not running, so rules cannot be looked up for now. '
        'Start the core and try again.',
      ),
      findsOneWidget,
    );

    await teardown(tester);
  });

  testWidgets('a result shown when the Core stops dims and rests its actions', (
    tester,
  ) async {
    await pumpRules(tester);
    await tester.enterText(find.byType(EditableText), 'www.youtube.com');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Lookup result'), findsOneWidget);

    double cardOpacity() => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.text('Lookup result'),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(cardOpacity(), 1);

    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await tester.pump();

    expect(cardOpacity(), 0.45);
    for (final label in ['Change node', 'Add to added rules', 'Copy rule']) {
      final button = find.text(label);
      if (button.evaluate().isEmpty) continue;
      await tester.tap(button.first, warnIfMissed: false);
      await tester.pump();
    }
    expect(find.byType(AddRuleDialog), findsNothing);
    expect(
      tester.getSemantics(find.text('Add to added rules')),
      isSemantics(isButton: true, isEnabled: false, hasEnabledState: true),
    );

    await teardown(tester);
  });

  /// Adds youtube.com through the card's dialog; the lookup after it has
  /// an earlier rule [first] match, listing the added rule as passed over
  /// by it when [listed].
  Future<void> addBeaten(
    WidgetTester tester, {
    required bool listed,
    Size size = _size,
  }) async {
    await pumpRules(
      tester,
      size: size,
      writeRule: (_, text) async {
        const first = RuleHit(
          index: 0,
          type: 'DOMAIN-KEYWORD',
          ruleType: 'DomainKeyword',
          payload: 'youtube',
          target: 'Proxy',
          status: RuleHitStatus.winner,
        );
        when(() => core.lookupRule(any())).thenAnswer(
          (_) async => _lookup().copyWith(
            total: 5,
            winner: first,
            chain: const [ChainHop(name: 'Proxy', type: 'Selector')],
            matches: [
              first,
              if (listed)
                const RuleHit(
                  index: 1,
                  type: 'DOMAIN-SUFFIX',
                  ruleType: 'DomainSuffix',
                  payload: 'youtube.com',
                  target: 'YouTube',
                  status: RuleHitStatus.shadowed,
                ),
            ],
          ),
        );
        return null;
      },
    );
    await tester.enterText(find.byType(EditableText), 'www.youtube.com');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Add to added rules'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  testWidgets('an added rule another one beats names it and shows it', (
    tester,
  ) async {
    await addBeaten(tester, listed: true);

    expect(
      find.text(
        'The rule was added, but this lookup does not match it.'
        'Rule #1 matches first.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('View that rule'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Show all rules')),
      isSemantics(isButton: true, isSelected: true, hasSelectedState: true),
    );

    await teardown(tester);
  });

  testWidgets('an added rule not hit for no confirmed reason names none', (
    tester,
  ) async {
    await addBeaten(tester, listed: false);

    expect(
      find.text('The rule was added, but this lookup does not match it.'),
      findsOneWidget,
    );
    expect(find.text('View that rule'), findsNothing);

    await teardown(tester);
  });

  group('the title and search box stay clear of the scrolled rules', () {
    const short = Size(1100, 560);

    void expectClear(WidgetTester tester, Rect search) {
      final title = tester.getRect(find.text('Rules').first);
      final field = tester.getRect(find.byType(EditableText).first);
      final results = tester.getRect(find.byKey(RulesView.resultsKey));
      expect(field, search, reason: 'the search box stays put');
      expect(title.bottom, lessThanOrEqualTo(field.top));
      expect(results.top, greaterThanOrEqualTo(field.bottom));
      // Whatever the results show is clipped to their own box.
      final clip = tester.renderObject<RenderBox>(
        find.byKey(RulesView.resultsKey),
      );
      expect(clip.paintBounds.top, 0);
      // The header, gap below the info line included, is opaque and the
      // results start exactly where it ends, clipped right there.
      final header = find.byKey(RulesView.headerKey);
      expect(tester.widget<ColoredBox>(header).color.a, 1);
      final headerRect = tester.getRect(header);
      expect(headerRect.bottom, results.top);
      expect(headerRect.bottom, greaterThan(field.bottom));
      final cut = find
          .ancestor(
            of: find.byKey(RulesView.resultsKey),
            matching: find.byType(ClipRect),
          )
          .first;
      expect(tester.getRect(cut).top, headerRect.bottom);
      // A hairline marks the cut while the results are scrolled.
      expect(find.byKey(RulesView.scrollEdgeKey), findsOneWidget);
      expect(
        tester.getRect(find.byKey(RulesView.scrollEdgeKey)).top,
        results.top,
      );
    }

    Future<Rect> lookUp(WidgetTester tester) async {
      await tester.enterText(
        find.byType(EditableText).first,
        'www.youtube.com',
      );
      await tester.pump(const Duration(milliseconds: 250));
      final search = tester.getRect(find.byType(EditableText).first);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      return search;
    }

    double offset(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(RulesView.resultsKey),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;

    testWidgets('after showing all rules at the one taken', (tester) async {
      await pumpRules(tester, size: short);
      final search = await lookUp(tester);

      await tester.tap(find.text('Show all rules'));
      await tester.pumpAndSettle();

      expect(offset(tester), greaterThan(0));
      expectClear(tester, search);
      await teardown(tester);
    });

    testWidgets('after the jump to the rule that beat an added one', (
      tester,
    ) async {
      await addBeaten(tester, listed: true, size: short);
      final search = tester.getRect(find.byType(EditableText).first);
      await tester.drag(
        find.byKey(RulesView.resultsKey),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View that rule'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View that rule'));
      await tester.pumpAndSettle();

      expectClear(tester, search);
      await teardown(tester);
    });

    testWidgets('on a lookup opened from a request', (tester) async {
      container
          .read(rulesLookupRequestProvider.notifier)
          .ask('www.youtube.com', rule: 'RuleSet', rulePayload: 'YouTube');
      await pumpRules(tester, size: short);
      await tester.pump(const Duration(milliseconds: 200));
      final search = tester.getRect(find.byType(EditableText).first);
      await tester.drag(
        find.byKey(RulesView.resultsKey),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(offset(tester), greaterThan(0));
      expectClear(tester, search);
      await teardown(tester);
    });
  });

  group('a rule set row with entries showing reads as open', () {
    Glyph chevronOf(WidgetTester tester) {
      final row = find.ancestor(
        of: find.text('RULE-SET,YouTube'),
        matching: find.byType(RuleRow),
      );
      return tester
          .widget<GlyphIcon>(
            find.descendant(of: row, matching: find.byType(GlyphIcon)).first,
          )
          .glyph;
    }

    Future<void> lookUp(WidgetTester tester) async {
      await tester.enterText(
        find.byType(EditableText).first,
        'www.youtube.com',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    setUp(() {
      when(
        () => core.getRuleSetEntries(
          'YouTube',
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer(
        (_) async => const RuleSetEntries(
          name: 'YouTube',
          total: 3,
          entries: [
            'DOMAIN-SUFFIX,googlevideo.com',
            'DOMAIN-SUFFIX,youtube.com',
            'DOMAIN-SUFFIX,ytimg.com',
          ],
        ),
      );
    });

    for (final all in [false, true]) {
      testWidgets(all ? 'among all rules' : 'among the matching rules', (
        tester,
      ) async {
        await pumpRules(tester);
        await lookUp(tester);
        if (all) {
          await tester.tap(find.text('Show all rules'));
          await tester.pumpAndSettle();
        }
        expect(find.byType(RuleEntryRow), findsOneWidget);
        expect(chevronOf(tester), AppGlyphs.chevronDown);

        // Open: every entry, the matched one still marked.
        await tester.tap(find.text('RULE-SET,YouTube'));
        await tester.pumpAndSettle();
        expect(find.byType(RuleEntryRow), findsNWidgets(3));
        expect(find.text('DOMAIN-SUFFIX,ytimg.com'), findsOneWidget);
        expect(chevronOf(tester), AppGlyphs.chevronDown);
        final matched = tester.widget<RuleEntryRow>(
          find.ancestor(
            of: find.text('DOMAIN-SUFFIX,youtube.com').last,
            matching: find.byType(RuleEntryRow),
          ),
        );
        expect(matched.highlighted, isTrue);

        // Closed again: back to the matched entry alone.
        await tester.tap(find.text('RULE-SET,YouTube'));
        await tester.pumpAndSettle();
        expect(find.byType(RuleEntryRow), findsOneWidget);
        expect(find.text('DOMAIN-SUFFIX,ytimg.com'), findsNothing);
        expect(chevronOf(tester), AppGlyphs.chevronDown);
        await teardown(tester);
      });
    }

    testWidgets('and without a lookup it opens and closes plainly', (
      tester,
    ) async {
      await pumpRules(tester);
      expect(find.byType(RuleEntryRow), findsNothing);
      expect(chevronOf(tester), AppGlyphs.chevronForward);

      await tester.tap(find.text('RULE-SET,YouTube'));
      await tester.pumpAndSettle();
      expect(find.byType(RuleEntryRow), findsNWidgets(3));
      expect(chevronOf(tester), AppGlyphs.chevronDown);

      await tester.tap(find.text('RULE-SET,YouTube'));
      await tester.pumpAndSettle();
      expect(find.byType(RuleEntryRow), findsNothing);
      expect(chevronOf(tester), AppGlyphs.chevronForward);
      await teardown(tester);
    });
  });

  group('AddRuleDialog', () {
    Future<void> pumpDialog(
      WidgetTester tester,
      Future<String?> Function(String text) onAdd,
    ) async {
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          child: Center(
            child: AddRuleDialog(
              host: 'api.example.com',
              profileLabel: 'Airport A',
              targets: const ['Proxy', 'DIRECT', 'REJECT'],
              initialTarget: 'Proxy',
              onAdd: onAdd,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('previews the rule as the choices change', (tester) async {
      await pumpDialog(tester, (_) async => null);

      expect(find.text('DOMAIN-SUFFIX,example.com,Proxy'), findsOneWidget);
      await tester.tap(find.text('Only api.example.com'));
      await tester.pump();
      expect(find.text('DOMAIN,api.example.com,Proxy'), findsOneWidget);
    });

    testWidgets('stays open with the reason when adding fails', (tester) async {
      final added = <String>[];
      await pumpDialog(tester, (text) async {
        added.add(text);
        return 'disk full';
      });

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(added, ['DOMAIN-SUFFIX,example.com,Proxy']);
      expect(find.text('disk full'), findsOneWidget);
      expect(find.byType(AddRuleDialog), findsOneWidget);
    });
  });
}
