// Times the rules page on large profiles, from the Core's answer to the
// first frame that lists them, and a rebuild after a source chip changes.
// The bounds are loose debug-mode limits; a build that grows with the square
// of the rule count blows through them at 20000 rules.
import 'dart:convert';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/rules/rules.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

const _size = Size(1100, 900);

final _set = RuleSetView(
  name: 'Big',
  behavior: 'domain',
  count: 40000,
  updatedAt: DateTime(2026),
  interval: 86400,
);

CoreRule _ruleAt(int index, int count) => index == count - 1
    ? CoreRule(index: index, type: 'MATCH', ruleType: 'Match', target: 'Proxy')
    : index % 100 == 50
    ? CoreRule(
        index: index,
        type: 'RULE-SET',
        ruleType: 'RuleSet',
        payload: 'Big',
        target: 'Proxy',
        ruleSet: _set,
      )
    : CoreRule(
        index: index,
        type: 'DOMAIN-SUFFIX',
        ruleType: 'DomainSuffix',
        payload: 'host$index.example.com',
        target: index.isEven ? 'Proxy' : 'DIRECT',
      );

RuleList _listOf(int count) => RuleList(
  coreEpoch: 1,
  mode: 'rule',
  total: count,
  rules: [for (var i = 0; i < count; i++) _ruleAt(i, count)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes the Core answer for 5000 rules', () {
    final json = jsonEncode(_listOf(5000).toJson());
    final watch = Stopwatch()..start();
    final decoded = RuleList.fromJson(jsonDecode(json) as Map<String, Object?>);
    watch.stop();
    expect(decoded.rules, hasLength(5000));
    debugPrint(
      'rules benchmark: decode 5000 in ${watch.elapsedMilliseconds} ms',
    );
  });

  for (final count in [5000, 20000]) {
    testWidgets('lists $count rules of a subscription without stalling', (
      tester,
    ) async {
      final list = _listOf(count);
      final core = _MockCore();
      when(
        () => core.listRules(filter: any(named: 'filter')),
      ).thenAnswer((_) async => list);
      final profile = Profile.normal(label: 'Big');
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          groupsProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).update((_) => _size);
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      container
          .read(appliedRuleSourcesStateProvider.notifier)
          .applied(profile.id, [
            for (final rule in list.rules)
              RuleSource(kind: RuleSourceKind.subscription, text: rule.text),
          ]);
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> mount() => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(locale: Locale('en'), child: RulesView()),
        ),
      );

      // The first mount compiles the row widgets; the timed one does not.
      await mount();
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      final first = Stopwatch()..start();
      await mount();
      await tester.pump();
      await tester.pump();
      first.stop();
      expect(find.textContaining('host3.example.com'), findsOneWidget);

      final rebuilds = <int>[];
      for (final chip in ['Subscription · Big', 'All']) {
        await tester.tap(find.text(chip).first);
        final watch = Stopwatch()..start();
        await tester.pump();
        watch.stop();
        rebuilds.add(watch.elapsedMilliseconds);
      }
      debugPrint(
        'rules benchmark: $count rules, first list frame '
        '${first.elapsedMilliseconds} ms, chip rebuilds $rebuilds ms',
      );
      expect(first.elapsedMilliseconds, lessThan(600));
      expect(rebuilds, everyElement(lessThan(300)));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
