import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/common/added_rule_edit.dart';
import 'package:fl_clash/common/process_apps.dart';
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart';
import 'package:fl_clash/views/rules/hit_card.dart';
import 'package:fl_clash/views/rules/widgets.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/rules/rule_rows.dart';
import 'package:fl_clash/views/rules/rules.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

/// The added rules of the page, kept in memory; records what it was asked.
class _FakeAddedRules extends AddedRulesAction {
  static var rules = <Rule>[];
  static var sets = <AddedRuleSet>[];
  static final calls = <String>[];

  @override
  Future<AddedRulesState> load(Profile profile) async =>
      (rules: rules, sets: sets);

  @override
  Set<String> takenRuleSetNames(Profile profile) => const {'YouTube'};

  @override
  Future<AddedRulesSave> putRule(
    Profile profile,
    Rule rule, {
    Rule? previous,
    bool last = false,
  }) async {
    calls.add('put ${rule.rawValue}${last ? ' last' : ''}');
    return (error: null, pending: false, ruleId: rule.id);
  }

  @override
  Future<AddedRulesSave> deleteRule(Profile profile, Rule rule) async {
    calls.add('delete ${rule.rawValue}');
    return (error: null, pending: false, ruleId: null);
  }

  @override
  Future<AddedRulesSave> deleteSet(
    Profile profile,
    AddedRuleSet set, {
    required Rule rule,
  }) async {
    calls.add('delete-set ${set.id} rule ${rule.id}');
    return (error: null, pending: false, ruleId: null);
  }

  @override
  Future<AddedRulesSave> moveRule(
    Profile profile,
    Rule rule, {
    required bool up,
    required List<Rule> expectedOrder,
  }) async {
    calls.add('move ${rule.rawValue} ${up ? 'up' : 'down'}');
    return (error: null, pending: false, ruleId: rule.id);
  }
}

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
    registerFallbackValue(const Metadata());
  });

  late ProviderContainer container;
  late _MockCore core;
  final profile = Profile.normal(label: 'Airport A');

  setUp(() {
    _FakeAddedRules.rules = [];
    _FakeAddedRules.sets = [];
    _FakeAddedRules.calls.clear();
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
        addedRulesActionProvider.overrideWith(_FakeAddedRules.new),
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

  /// Types [text] into the title bar's search, opening it first.
  Future<void> type(WidgetTester tester, String text) async {
    if (_searchField.evaluate().isEmpty) {
      await tester.tap(find.byGlyph(AppGlyphs.search).first);
      await tester.pumpAndSettle();
    }
    await tester.enterText(_searchField, text);
    await tester.pump();
  }

  /// Types [text] and lets the lookup it starts once typing stops answer.
  Future<void> lookUp(WidgetTester tester, String text) async {
    await type(tester, text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
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
    // Badges and chips both name the sources, and which one each is.
    expect(find.text('Added rule · Airport A'), findsNWidgets(2));
    expect(find.text('Extension script · Enhance'), findsNWidgets(2));
    expect(find.text('Subscription · Airport A'), findsNWidgets(2));
    expect(find.text('Rule set · YouTube'), findsOneWidget);
    expect(find.textContaining('86 · updated'), findsOneWidget);
    expect(find.text('→ Japan 03'), findsOneWidget);
    // The Core's list was matched to the build, so the sources bind to it.
    expect(container.read(appliedRuleSourcesStateProvider).epoch, 3);

    await teardown(tester);
  });

  testWidgets('a source chip keeps only that source', (tester) async {
    await pumpRules(tester);

    await tester.tap(find.text('Added rule · Airport A').first);
    await tester.pump();

    expect(find.text('DOMAIN-SUFFIX,github.com'), findsOneWidget);
    expect(find.text('MATCH'), findsNothing);

    await teardown(tester);
  });

  testWidgets('a link looks itself up once typing stops', (tester) async {
    final answer = Completer<RuleLookup>();
    when(() => core.lookupRule(any())).thenAnswer((_) => answer.future);
    await pumpRules(tester);

    await type(tester, 'https://www.youtube.com/watch?v=abc');
    await tester.pump(const Duration(milliseconds: 300));
    verifyNever(() => core.lookupRule(any()));

    await tester.pump(const Duration(milliseconds: 100));
    final params =
        verify(() => core.lookupRule(captureAny())).captured.single
            as RuleLookupParams;
    expect(params.host, 'www.youtube.com');
    expect(params.port, 443);
    // While it is on its way: a spinner in the field, a line in the page.
    expect(find.byKey(RulesView.queryingKey), findsOneWidget);
    expect(find.text('Looking up www.youtube.com…'), findsOneWidget);

    answer.complete(_lookup());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(RulesView.queryingKey), findsNothing);
    expect(find.text('Looking up www.youtube.com…'), findsNothing);
    expect(find.text('Lookup result'), findsOneWidget);
    expect(find.text('Matches rule #2'), findsOneWidget);
    expect(find.text('Japan 03'), findsOneWidget);
    expect(find.text('Rule #2 matches first'), findsOneWidget);
    expect(find.text('DOMAIN-SUFFIX,youtube.com'), findsWidgets);
    expect(find.text('Profile “Airport A”'), findsOneWidget);
    // What was asked, and that it may resolve, sits above the card.
    final info = tester.getRect(find.byKey(RulesView.infoKey));
    expect(
      info.bottom,
      lessThan(tester.getRect(find.text('Lookup result')).top),
    );
    expect(
      find.textContaining('www.youtube.com:443 · A lookup may resolve DNS'),
      findsOneWidget,
    );

    await teardown(tester);
  });

  testWidgets('plain text only filters', (tester) async {
    await pumpRules(tester);

    await type(tester, 'github');
    await tester.pump(const Duration(seconds: 1));

    verifyNever(() => core.lookupRule(any()));
    verify(() => core.listRules(filter: 'github')).called(1);
    expect(find.text('Lookup result'), findsNothing);

    await teardown(tester);
  });

  testWidgets('enter looks up at once, and only once', (tester) async {
    await pumpRules(tester);

    await type(tester, 'www.youtube.com');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    verify(() => core.lookupRule(any())).called(1);

    await tester.pump(const Duration(seconds: 1));
    verifyNever(() => core.lookupRule(any()));
    expect(find.text('Lookup result'), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('only the latest query answers', (tester) async {
    final answers = <String, Completer<RuleLookup>>{};
    when(() => core.lookupRule(any())).thenAnswer((call) {
      final params = call.positionalArguments.single as RuleLookupParams;
      return (answers[params.host] = Completer<RuleLookup>()).future;
    });
    await pumpRules(tester);

    await type(tester, 'www.youtube.com');
    await tester.pump(const Duration(milliseconds: 400));
    await type(tester, 'github.com');
    await tester.pump(const Duration(milliseconds: 400));
    expect(answers.keys, ['www.youtube.com', 'github.com']);

    answers['github.com']!.complete(
      _lookup().copyWith(
        host: 'github.com',
        winner: const RuleHit(
          index: 0,
          type: 'DOMAIN-SUFFIX',
          ruleType: 'DomainSuffix',
          payload: 'github.com',
          target: 'GitHub',
          status: RuleHitStatus.winner,
        ),
        chain: const [ChainHop(name: 'GitHub', type: 'Selector')],
        matches: const [],
      ),
    );
    await tester.pump();
    // The older answer, late, is dropped.
    answers['www.youtube.com']!.complete(_lookup());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Matches rule #1'), findsOneWidget);
    expect(find.text('Matches rule #2'), findsNothing);
    expect(find.text('Japan 03'), findsNothing);

    await teardown(tester);
  });

  testWidgets('a failed lookup says so', (tester) async {
    when(
      () => core.lookupRule(any()),
    ).thenThrow(const CoreMethodException(code: 'x', message: 'boom'));
    await pumpRules(tester);

    await lookUp(tester, 'www.youtube.com');

    expect(find.text('Lookup failed: boom'), findsOneWidget);
    expect(find.byKey(RulesView.queryingKey), findsNothing);

    await teardown(tester);
  });

  testWidgets('undecided rules stay out of the matched rules', (tester) async {
    const fallback = RuleHit(
      index: 4,
      type: 'MATCH',
      ruleType: 'Match',
      target: 'Final',
      status: RuleHitStatus.winner,
    );
    when(() => core.listRules(filter: any(named: 'filter'))).thenAnswer(
      (_) async => _list.copyWith(
        total: 5,
        rules: [
          ..._list.rules.take(3),
          const CoreRule(
            index: 3,
            type: 'PROCESS-NAME',
            ruleType: 'Process',
            payload: 'Telegram',
            target: 'Proxy',
          ),
          const CoreRule(
            index: 4,
            type: 'MATCH',
            ruleType: 'Match',
            target: 'Final',
          ),
        ],
      ),
    );
    when(() => core.lookupRule(any())).thenAnswer(
      (_) async => _lookup().copyWith(
        total: 5,
        host: 'example.org',
        winner: fallback,
        chain: const [ChainHop(name: 'Final', type: 'Selector')],
        matches: const [fallback],
        uncertain: const [
          RuleHit(
            index: 3,
            type: 'PROCESS-NAME',
            ruleType: 'Process',
            payload: 'Telegram',
            target: 'Proxy',
            status: RuleHitStatus.uncertain,
            reason: 'process',
          ),
        ],
      ),
    );
    await pumpRules(tester);

    await lookUp(tester, 'example.org');

    // The card: its usual title and one amber line say the result may differ.
    expect(find.text('Lookup result'), findsOneWidget);
    expect(find.byKey(RuleHitCard.uncertainKey), findsOneWidget);
    expect(
      find.text(
        'An earlier rule may match first depending on the app; '
        'the actual result may differ.',
      ),
      findsOneWidget,
    );
    // Hovering it names the rules it means.
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(
              of: find.byKey(RuleHitCard.uncertainKey),
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      '#4 PROCESS-NAME,Telegram,Proxy',
    );
    // The fallback taken needs no line of its own.
    expect(find.textContaining('No earlier rule'), findsNothing);
    // The list: the fallback taken, marked; the undecided rule left out.
    expect(find.text('Matching rules 1'), findsOneWidget);
    expect(find.text('PROCESS-NAME,Telegram'), findsNothing);
    expect(find.text('May or may not match'), findsNothing);
    final row = tester.widget<RuleRow>(
      find.ancestor(of: find.text('MATCH'), matching: find.byType(RuleRow)),
    );
    expect(row.highlighted, isTrue);
    expect(row.hit?.status, RuleHitStatus.winner);
    expect(find.text('Matched'), findsOneWidget);

    // All rules: the undecided one shows as a plain row.
    await tester.tap(find.text('Show all rules'));
    await tester.pumpAndSettle();
    expect(find.text('PROCESS-NAME,Telegram'), findsOneWidget);
    expect(find.text('May or may not match'), findsNothing);

    await teardown(tester);
  });

  testWidgets('rule sets not whole share one line with one update action', (
    tester,
  ) async {
    when(() => core.lookupRule(any())).thenAnswer(
      (_) async => _lookup().copyWith(
        ruleSets: [
          RuleSetView(
            name: 'Netflix',
            updatedAt: DateTime.now().subtract(const Duration(days: 5)),
            interval: 86400,
          ),
          const RuleSetView(name: 'Apple', status: 'failed'),
          _ruleSet,
        ],
      ),
    );
    await pumpRules(tester);

    await lookUp(tester, 'www.youtube.com');

    expect(find.byKey(RulesView.ruleSetNoticeKey), findsOneWidget);
    expect(
      find.text(
        'Rule sets not ready: “Netflix” has expired, “Apple” failed to '
        'download. The result may be incomplete.',
      ),
      findsOneWidget,
    );
    expect(find.text('Update'), findsOneWidget);

    await teardown(tester);
  });

  for (final ipRule in [false, true]) {
    testWidgets(
      ipRule
          ? 'a failed DNS names IP when an IP rule comes first'
          : 'a failed DNS says nothing of IP with no IP rule first',
      (tester) async {
        when(() => core.lookupRule(any())).thenAnswer(
          (_) async => _lookup().copyWith(
            ip: '',
            ipSource: '',
            resolveError: 'i/o timeout',
            uncertain: [
              const RuleHit(
                index: 0,
                type: 'PROCESS-NAME',
                ruleType: 'Process',
                payload: 'Telegram',
                target: 'Proxy',
                status: RuleHitStatus.uncertain,
                reason: 'process',
              ),
              if (ipRule)
                const RuleHit(
                  index: 0,
                  type: 'IP-CIDR',
                  ruleType: 'IPCIDR',
                  payload: '10.0.0.0/8',
                  target: 'DIRECT',
                  status: RuleHitStatus.uncertain,
                  reason: 'ip',
                ),
            ],
          ),
        );
        await pumpRules(tester);

        await lookUp(tester, 'www.youtube.com');

        // No notice of its own: the card's one hint says it, if anything.
        expect(find.textContaining('could not be resolved'), findsNothing);
        expect(find.byKey(RuleHitCard.uncertainKey), findsOneWidget);
        expect(
          find.text(
            ipRule
                ? 'An earlier rule may match first depending on the app or IP; '
                      'the actual result may differ.'
                : 'An earlier rule may match first depending on the app; '
                      'the actual result may differ.',
          ),
          findsOneWidget,
        );
        // The hint follows every detail and comes right before the buttons.
        final hint = tester.getRect(find.byKey(RuleHitCard.uncertainKey));
        expect(
          hint.top,
          greaterThan(
            tester.getRect(find.text('Rule set · YouTube').first).bottom,
          ),
        );
        expect(
          tester.getRect(find.text('Add to added rules')).top - hint.bottom,
          closeTo(6 + 8, 8),
        );

        await teardown(tester);
      },
    );
  }

  testWidgets('a narrow window wraps rule text, never cutting it', (
    tester,
  ) async {
    const long =
        'very-long-subdomain-name.another-long-label.example-company.co.uk';
    when(() => core.listRules(filter: any(named: 'filter'))).thenAnswer(
      (_) async => _list.copyWith(
        rules: [
          const CoreRule(
            index: 0,
            type: 'DOMAIN-SUFFIX',
            ruleType: 'DomainSuffix',
            payload: long,
            target: 'GitHub',
          ),
          ..._list.rules.skip(1),
        ],
      ),
    );
    await pumpRules(tester, size: const Size(380, 900));

    final text = find.text('DOMAIN-SUFFIX,$long');
    expect(text, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, greaterThan(30), reason: 'it wraps');
    expect(tester.getRect(text).right, lessThanOrEqualTo(380));

    await teardown(tester);
  });

  testWidgets('the undecided kinds share one line, the general one unsaid', (
    tester,
  ) async {
    RuleHit undecided(int index, String reason) => RuleHit(
      index: index,
      type: 'DOMAIN-KEYWORD',
      ruleType: 'DomainKeyword',
      payload: 'youtube',
      target: 'Proxy',
      status: RuleHitStatus.uncertain,
      reason: reason,
    );
    when(() => core.lookupRule(any())).thenAnswer(
      (_) async => _lookup().copyWith(
        uncertain: [
          undecided(0, 'port'),
          undecided(2, 'process'),
          undecided(3, 'other'),
        ],
      ),
    );
    await pumpRules(tester);

    await lookUp(tester, 'www.youtube.com');

    expect(find.byKey(RuleHitCard.uncertainKey), findsOneWidget);
    expect(
      find.text(
        'An earlier rule may match first depending on the app or port; '
        'the actual result may differ.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Earlier rules need more about the connection, '
        'so the actual result may differ.',
      ),
      findsNothing,
    );

    await teardown(tester);
  });

  testWidgets('a long source name is cut, the whole name on hover', (
    tester,
  ) async {
    container
        .read(appliedRuleSourcesStateProvider.notifier)
        .applied(container.read(currentProfileIdProvider)!, [
          ..._sources.take(2),
          const RuleSource(
            kind: RuleSourceKind.script,
            name: 'A very long script name indeed',
            text: 'DOMAIN-KEYWORD,youtube,Proxy',
          ),
          _sources.last,
        ]);
    await pumpRules(tester);

    const short = 'Extension script · A very long scri…';
    expect(find.text(short), findsNWidgets(2));
    expect(
      tester
          .widget<RuleBadge>(
            find.ancestor(
              of: find.text(short).last,
              matching: find.byType(RuleBadge),
            ),
          )
          .tooltip,
      'Extension script · A very long script name indeed',
    );

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
    // The title bar's search opens with the host in it.
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(_searchField).controller.text,
      'www.youtube.com',
    );
    expect(
      find.text(
        'The rule this connection matched then agrees with this lookup.',
      ),
      findsOneWidget,
    );

    await teardown(tester);
  });

  testWidgets('a request lookup preserves process, ports and network', (
    tester,
  ) async {
    const metadata = Metadata(
      process: 'browser',
      processPath: '/fixture/browser',
      sourceIP: '192.0.2.5',
      sourcePort: '51234',
      destinationPort: '8443',
      network: 'udp',
    );
    final previous = processApps;
    processApps = ProcessApps(lookupApps: true, invoke: (_) async => null)
      ..seed(
        lookups: {
          '/fixture/browser': const AppLookup.app(
            MacApp(
              bundleId: 'test.browser',
              name: 'Browser',
              bundlePath: '/fixture/Browser.app',
            ),
          ),
        },
      );
    addTearDown(() {
      processApps.dispose();
      processApps = previous;
    });
    when(
      () => core.lookupRule(any(), metadata: any(named: 'metadata')),
    ).thenAnswer((_) async => _lookup());
    container
        .read(rulesLookupRequestProvider.notifier)
        .ask(
          'www.youtube.com',
          rule: 'RuleSet',
          rulePayload: 'YouTube',
          metadata: metadata,
        );
    await pumpRules(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final captured = verify(
      () => core.lookupRule(
        captureAny(),
        metadata: captureAny(named: 'metadata'),
      ),
    ).captured;
    final params = captured[0] as RuleLookupParams;
    expect(params.port, 8443);
    expect(params.network, 'udp');
    expect(captured[1], metadata);
    expect(find.text('Browser'), findsOneWidget);
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
    await lookUp(tester, 'www.youtube.com');
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
    expect(find.byType(RuleEditDialog), findsNothing);
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
    await lookUp(tester, 'www.youtube.com');
    await tester.tap(find.text('Add to added rules'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add'));
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

  group('the rules scroll under the shared bar, which keeps its search', () {
    const short = Size(1100, 560);

    void expectClear(WidgetTester tester, Rect search) {
      final field = tester.getRect(_searchField);
      final results = tester.getRect(find.byKey(RulesView.resultsKey));
      expect(field, search, reason: 'the search box stays put');
      // No header of the page's own: the scroll view starts at the top of
      // the window and runs under the bar, whose fade covers what scrolled.
      expect(results.top, 0);
      final bar = tester.getRect(find.byType(ScaffoldBar));
      expect(bar.bottom, greaterThan(field.bottom));
      final subtitle = find.byKey(RulesView.subtitleKey);
      if (subtitle.evaluate().isNotEmpty) {
        expect(tester.getRect(subtitle).top, lessThan(bar.bottom));
      }
    }

    Future<Rect> lookUpAt(WidgetTester tester) async {
      await lookUp(tester, 'www.youtube.com');
      await tester.pumpAndSettle();
      return tester.getRect(_searchField);
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
      final search = await lookUpAt(tester);

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
      await tester.pumpAndSettle();
      final search = tester.getRect(_searchField);
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
      await tester.pumpAndSettle();
      final search = tester.getRect(_searchField);
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
        await lookUp(tester, 'www.youtube.com');
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

  group('added rules on the page', () {
    const github = Rule(
      id: 11,
      profileId: 1,
      ruleAction: RuleAction.DOMAIN_SUFFIX,
      content: 'github.com',
      ruleTarget: 'GitHub',
      order: 'a',
    );

    void bindAdded() {
      _FakeAddedRules.rules = [github];
      container.read(appliedRuleSourcesStateProvider.notifier).applied(
        profile.id,
        [_sources.first.copyWith(ruleId: github.id), ..._sources.skip(1)],
      );
    }

    testWidgets('a line parts the added rules from the profile’s own', (
      tester,
    ) async {
      await pumpRules(tester);
      expect(
        find.text(
          'Rules below come from the profile and scripts and can only be '
          'viewed here',
        ),
        findsOneWidget,
      );
      final divider = tester.getRect(find.byType(RulesDividerRow));
      expect(
        divider.top,
        greaterThan(
          tester.getRect(find.text('DOMAIN-SUFFIX,github.com')).bottom,
        ),
      );
      expect(
        divider.bottom,
        lessThan(tester.getRect(find.text('RULE-SET,YouTube')).top),
      );

      await teardown(tester);
    });

    testWidgets('hovering an added rule shows edit and delete', (tester) async {
      bindAdded();
      await pumpRules(tester);
      await tester.pump();

      expect(find.byType(RuleRowAction), findsNothing);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(
        tester.getCenter(find.text('DOMAIN-SUFFIX,github.com')),
      );
      await tester.pump();
      expect(find.byType(RuleRowAction), findsNWidgets(2));
      expect(find.bySemanticsLabel('Edit rule 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Delete rule 1'), findsOneWidget);
      // A subscription rule has none.
      await gesture.moveTo(tester.getCenter(find.text('MATCH')));
      await tester.pump();
      expect(find.byType(RuleRowAction), findsNothing);

      await gesture.moveTo(
        tester.getCenter(find.text('DOMAIN-SUFFIX,github.com')),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Delete rule 1'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this rule?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(_FakeAddedRules.calls, ['delete DOMAIN-SUFFIX,github.com,GitHub']);
      expect(find.text('Deleted.'), findsOneWidget);

      await teardown(tester);
    });

    testWidgets('double-clicking an added rule edits it', (tester) async {
      bindAdded();
      await pumpRules(tester);
      await tester.pump();

      final row = find.text('DOMAIN-SUFFIX,github.com');
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Edit Added Rule'), findsOneWidget);
      expect(find.text('No. 1 · Added rule'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await teardown(tester);
    });

    testWidgets('the add button offers a rule and a rule set', (tester) async {
      await pumpRules(tester);

      expect(find.bySemanticsLabel('Add a rule or rule set'), findsOneWidget);
      await tester.tap(find.byKey(RulesView.addKey));
      await tester.pumpAndSettle();
      expect(find.text('Add Rule'), findsOneWidget);
      expect(find.text('Add Rule Set'), findsOneWidget);
      await tester.tap(find.text('Add Rule'));
      await tester.pumpAndSettle();
      expect(find.byType(RuleEditDialog), findsOneWidget);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RuleEditField),
              matching: find.byType(EditableText),
            )
            .first,
        'example.org',
      );
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(_FakeAddedRules.calls, ['put DOMAIN-SUFFIX,example.org,YouTube']);
      expect(
        find.text(
          'Rule “DOMAIN-SUFFIX,example.org,YouTube” was added and is in effect.',
        ),
        findsOneWidget,
      );
      expect(find.text('Look Up a URL'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(RulesView.bannerKey), findsNothing);

      await teardown(tester);
    });

    testWidgets('command-N adds a rule', (tester) async {
      await pumpRules(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();
      expect(find.byType(RuleEditDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await teardown(tester);
    });

    for (final kind in ['paired', 'other-profile-rule', 'global-rule']) {
      testWidgets('deleting $kind dispatches to the correct owner only', (
        tester,
      ) async {
        final set = AddedRuleSet(
          id: 12,
          profileId: profile.id,
          name: 'YouTube',
          url: 'https://example.com/youtube.yaml',
        );
        final pair = Rule(
          id: 12,
          profileId: profile.id,
          ruleAction: RuleAction.RULE_SET,
          ruleProvider: 'YouTube',
          ruleTarget: 'YouTube',
          order: 'b',
        );
        final selected = kind == 'paired'
            ? pair
            : pair.copyWith(
                id: 13,
                profileId: kind == 'global-rule' ? null : profile.id,
              );
        _FakeAddedRules.rules = kind == 'paired' ? [pair] : [pair, selected];
        _FakeAddedRules.sets = [set];
        container
            .read(appliedRuleSourcesStateProvider.notifier)
            .applied(profile.id, [
              _sources.first,
              RuleSource(
                kind: kind == 'global-rule'
                    ? RuleSourceKind.addedGlobal
                    : RuleSourceKind.addedProfile,
                text: 'RULE-SET,YouTube,YouTube',
                ruleId: selected.id,
              ),
              ..._sources.skip(2),
            ]);
        await pumpRules(tester);
        await tester.pump();
        final rowWidget = tester.widget<RuleRow>(
          find.ancestor(
            of: find.text('RULE-SET,YouTube'),
            matching: find.byType(RuleRow),
          ),
        );
        expect(rowWidget.onDelete, isNotNull, reason: kind);
        rowWidget.onDelete!();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        expect(
          _FakeAddedRules.calls,
          kind == 'paired'
              ? ['delete-set 12 rule 12']
              : ['delete RULE-SET,YouTube,YouTube'],
        );
        await teardown(tester);
      });
    }

    testWidgets('an added rule set reads as one', (tester) async {
      final setRule = Rule(
        id: 12,
        profileId: profile.id,
        ruleAction: RuleAction.RULE_SET,
        ruleProvider: 'YouTube',
        ruleTarget: 'YouTube',
        order: 'b',
      );
      _FakeAddedRules.rules = [setRule];
      _FakeAddedRules.sets = [
        AddedRuleSet(
          id: 12,
          profileId: profile.id,
          name: 'YouTube',
          url: 'https://example.com/youtube.yaml',
        ),
      ];
      container
          .read(appliedRuleSourcesStateProvider.notifier)
          .applied(profile.id, [
            _sources.first,
            RuleSource(
              kind: RuleSourceKind.addedProfile,
              text: 'RULE-SET,YouTube,YouTube',
              ruleId: setRule.id,
            ),
            ..._sources.skip(2),
          ]);
      await pumpRules(tester);
      await tester.pump();

      expect(find.text('Added rule set · YouTube'), findsOneWidget);
      final row = find.text('RULE-SET,YouTube');
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Edit Added Rule Set'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await teardown(tester);
    });
  });

  group('RuleEditDialog', () {
    Future<List<(Rule, Rule?, bool)>> pumpDialog(
      WidgetTester tester, {
      String? error,
      Rule? rule,
      List<Rule> existing = const [],
      RuleAction? type,
      String? value,
      bool coreRunning = true,
      Size size = const Size(900, 900),
      Future<RuleEditSave> Function()? onDelete,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <(Rule, Rule?, bool)>[];
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          child: Center(
            child: RuleEditDialog(
              profileLabel: 'Airport A',
              coreRunning: coreRunning,
              targets: const ['Proxy', 'DIRECT', 'REJECT'],
              existing: existing,
              rule: rule,
              number: rule == null ? null : 2,
              initialType: type,
              initialValue: value,
              initialTarget: 'Proxy',
              processNames: const ['Safari', 'curl'],
              onSave: (rule, {previous, last = false}) async {
                saved.add((rule, previous, last));
                return (error: error, pending: false, ruleId: rule.id);
              },
              onDelete: onDelete,
            ),
          ),
        ),
      );
      await tester.pump();
      return saved;
    }

    Finder field() => find
        .descendant(
          of: find.byType(RuleEditField),
          matching: find.byType(EditableText),
        )
        .first;

    testWidgets('previews the rule as it is typed', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Add Rule'), findsOneWidget);
      expect(find.text('Adds to profile “Airport A”.'), findsOneWidget);
      expect(find.text('DOMAIN-SUFFIX,…,Proxy'), findsOneWidget);
      await tester.enterText(field(), 'https://www.example.com/a?b=1');
      await tester.pump(const Duration(milliseconds: 400));
      // A pasted link gives its host.
      expect(find.text('DOMAIN-SUFFIX,www.example.com,Proxy'), findsOneWidget);
      await tester.tap(find.text('Full Domain'));
      await tester.pump();
      expect(find.text('DOMAIN,www.example.com,Proxy'), findsOneWidget);
    });

    testWidgets('a single address becomes its own range', (tester) async {
      await pumpDialog(tester, type: RuleAction.IP_CIDR, value: '10.1.2.3');

      expect(find.text('IP-CIDR,10.1.2.3/32,Proxy'), findsOneWidget);
    });

    testWidgets('a bad value says why and cannot be added', (tester) async {
      final saved = await pumpDialog(tester);

      await tester.enterText(field(), 'not a domain');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Not a valid domain'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(saved, isEmpty);
    });

    testWidgets('a rule already added offers to update its group', (
      tester,
    ) async {
      const existing = Rule(
        id: 7,
        ruleAction: RuleAction.DOMAIN_SUFFIX,
        content: 'example.com',
        ruleTarget: 'DIRECT',
      );
      final saved = await pumpDialog(
        tester,
        existing: [existing],
        value: 'example.com',
      );

      expect(
        find.text('This rule is already there (No. 1), through Direct.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Update Group'));
      await tester.pump();
      expect(saved.single.$1.id, 7);
      expect(saved.single.$1.ruleTarget, 'Proxy');
      expect(saved.single.$2, existing);
    });

    testWidgets('adds last when asked', (tester) async {
      final saved = await pumpDialog(tester, value: 'example.com');

      await tester.tap(find.text('Last of added rules'));
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(saved.single.$3, isTrue);
      expect(saved.single.$1.rawValue, 'DOMAIN-SUFFIX,example.com,Proxy');
    });

    testWidgets('stays open with the reason when adding fails', (tester) async {
      final saved = await pumpDialog(
        tester,
        value: 'example.com',
        error: 'disk full',
      );

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(saved.single.$1.rawValue, 'DOMAIN-SUFFIX,example.com,Proxy');
      expect(find.text('disk full'), findsOneWidget);
      expect(find.byType(RuleEditDialog), findsOneWidget);
    });

    testWidgets('says when the Core is not running', (tester) async {
      await pumpDialog(tester, coreRunning: false);

      expect(find.text('Takes effect once the core starts'), findsOneWidget);
    });

    testWidgets('edits a rule, saving only a change', (tester) async {
      const rule = Rule(
        id: 3,
        ruleAction: RuleAction.DOMAIN,
        content: 'a.example.com',
        ruleTarget: 'Proxy',
      );
      final saved = await pumpDialog(tester, rule: rule);

      expect(find.text('Edit Added Rule'), findsOneWidget);
      expect(find.text('No. 2 · Added rule'), findsOneWidget);
      // Unchanged, it does not save.
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved, isEmpty);
      await tester.enterText(field(), 'b.example.com');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved.single.$1.content, 'b.example.com');
      expect(saved.single.$2, rule);
    });

    testWidgets('deletes a rule after asking', (tester) async {
      var deleted = 0;
      await pumpDialog(
        tester,
        rule: const Rule(
          id: 3,
          ruleAction: RuleAction.DOMAIN,
          content: 'a.example.com',
          ruleTarget: 'Proxy',
        ),
        onDelete: () async {
          deleted++;
          return (error: null, pending: false, ruleId: null);
        },
      );

      await tester.ensureVisible(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this rule?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(deleted, 1);
    });

    testWidgets('a narrow window picks the type from a menu', (tester) async {
      await pumpDialog(tester, size: const Size(420, 800));

      expect(find.byType(SegmentedControl<RuleAction?>), findsNothing);
      expect(
        find.descendant(
          of: find.byType(RuleEditDropdown<RuleAction>),
          matching: find.text('Domain Suffix'),
        ),
        findsOneWidget,
      );
    });
  });

  group('RuleSetEditDialog', () {
    Future<List<(AddedRuleSet, String)>> pumpSetDialog(
      WidgetTester tester, {
      required Future<RuleSetCheck> Function(String url) onCheck,
      Set<String> taken = const {},
      AddedRuleSet? set,
    }) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <(AddedRuleSet, String)>[];
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          child: Center(
            child: RuleSetEditDialog(
              profileLabel: 'Airport A',
              coreRunning: true,
              targets: const ['Proxy', 'DIRECT', 'REJECT'],
              takenNames: taken,
              set: set,
              setTarget: set == null ? null : 'DIRECT',
              number: set == null ? null : 1,
              initialTarget: 'Proxy',
              onCheck: onCheck,
              onSave: (set, {required target, check}) async {
                saved.add((set, target));
                return (error: null, pending: false, ruleId: 1);
              },
              onRefresh: () async => null,
            ),
          ),
        ),
      );
      await tester.pump();
      return saved;
    }

    Finder urlField() => find
        .descendant(
          of: find.byType(RuleEditField),
          matching: find.byType(EditableText),
        )
        .first;

    testWidgets('checks the link as typing stops and names the set', (
      tester,
    ) async {
      final checked = <String>[];
      final saved = await pumpSetDialog(
        tester,
        onCheck: (url) async {
          checked.add(url);
          return const RuleSetCheck(
            behavior: RuleProviderBehavior.ipcidr,
            format: RuleProviderFormat.text,
            count: 1234,
          );
        },
      );

      await tester.enterText(
        urlField(),
        'https://example.com/lists/telegram.txt',
      );
      await tester.pump();
      // Nothing is downloaded until typing rests, and adding waits for it.
      expect(checked, isEmpty);
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(saved, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(checked, ['https://example.com/lists/telegram.txt']);
      expect(
        find.text('Downloaded: IP Ranges rules, Text format, 1,234 entries'),
        findsOneWidget,
      );
      expect(find.text('RULE-SET,telegram,Proxy'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(saved.single.$1.name, 'telegram');
      expect(saved.single.$1.behavior, RuleProviderBehavior.ipcidr);
      expect(saved.single.$1.format, RuleProviderFormat.text);
      expect(saved.single.$1.interval, 86400);
      expect(saved.single.$2, 'Proxy');
    });

    testWidgets('a failed check says why and blocks adding', (tester) async {
      final saved = await pumpSetDialog(
        tester,
        onCheck: (_) async =>
            const RuleSetCheck.failed(RuleSetCheckFailure.notFound),
      );

      await tester.enterText(urlField(), 'https://example.com/missing.yaml');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.text('Not found (404)'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(saved, isEmpty);
    });

    testWidgets('takes only web links, and no name already taken', (
      tester,
    ) async {
      var checks = 0;
      await pumpSetDialog(
        tester,
        taken: {'ads'},
        onCheck: (_) async {
          checks++;
          return const RuleSetCheck(
            behavior: RuleProviderBehavior.domain,
            format: RuleProviderFormat.yaml,
            count: 1,
          );
        },
      );

      await tester.enterText(urlField(), 'file:///etc/ads.yaml');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Only http or https links'), findsOneWidget);
      expect(checks, 0);
      await tester.enterText(urlField(), 'https://example.com/ads.yaml');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(
        find.text('A rule set of this name already exists'),
        findsOneWidget,
      );
    });

    testWidgets('editing keeps the link checked until it changes', (
      tester,
    ) async {
      var checks = 0;
      final saved = await pumpSetDialog(
        tester,
        set: const AddedRuleSet(
          id: 5,
          profileId: 1,
          name: 'ads',
          url: 'https://example.com/ads.yaml',
        ),
        onCheck: (_) async {
          checks++;
          return const RuleSetCheck.failed(RuleSetCheckFailure.timeout);
        },
      );

      expect(find.text('Edit Added Rule Set'), findsOneWidget);
      expect(find.text('No. 1 · Added rule set'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      await tester.tap(find.text('Every day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(checks, 0);
      expect(saved.single.$1.interval, 604800);
      expect(saved.single.$1.id, 5);
      expect(saved.single.$2, 'DIRECT');
    });
  });
}

/// The text field of the title bar's search.
final _searchField = find.descendant(
  of: find.byType(SearchField),
  matching: find.byType(EditableText),
);
