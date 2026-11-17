import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/rules/add_rule_dialog.dart';
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

  Future<void> pumpRules(WidgetTester tester) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: RulesView()),
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
    expect(find.text('Extension script'), findsNWidgets(2));
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
      find.text('See which rule www.youtube.com actually takes'),
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
    expect(find.text('Actually taken'), findsOneWidget);
    expect(find.text('#2 / 4'), findsOneWidget);
    expect(find.text('Japan 03'), findsOneWidget);
    expect(find.text('Taken first by #2'), findsOneWidget);
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
      find.text('This connection took RuleSet(YouTube) too; they agree.'),
      findsOneWidget,
    );

    await teardown(tester);
  });

  testWidgets('says so when the Core stops', (tester) async {
    await pumpRules(tester);

    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await tester.pump();

    expect(
      find.text('The Core is not running; the rules stopped updating'),
      findsOneWidget,
    );

    await teardown(tester);
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
