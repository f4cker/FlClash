import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

TrackerInfo _tracker(String id, {String host = 'example.com'}) => TrackerInfo(
  id: id,
  start: DateTime.utc(2026),
  metadata: Metadata(
    network: 'tcp',
    host: host,
    destinationIP: '1.1.1.1',
    destinationPort: '443',
    process: 'curl',
  ),
  chains: const ['Proxy'],
  rule: 'DOMAIN',
  rulePayload: host,
);

const _zh2000 = '仅搜索已保留的最近 2,000 条记录。';
const _zh4000 = '仅搜索已保留的最近 4,000 条记录。';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  final requests = [
    for (var i = 0; i < 400; i++)
      _tracker('$i', host: i.isEven ? 'alpha$i.test' : 'beta$i.test'),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required RequestFeed feed,
    Locale locale = const Locale('zh', 'CN'),
    Size size = const Size(600, 1000),
    double textScale = 1,
  }) async {
    final notifier = container.read(requestsProvider.notifier);
    notifier.value = FixedList<TrackerInfo>(500);
    for (final request in requests) {
      notifier.addRequest(request);
    }
    container.read(viewSizeProvider.notifier).update((_) => size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: locale,
          child: RequestsView(
            initialFeed: feed,
            connectionsReader: () async => requests,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    if (find.byType(TextField).evaluate().isEmpty) {
      await tester.tap(find.byGlyph(AppGlyphs.search));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  /// Any copy of the note, in any language and with any count.
  final anyNote = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        RegExp(r'仅搜索已保留的最近|most recent').hasMatch(widget.data ?? ''),
  );

  testWidgets('recent requests: the note shows only while searching, with '
      'the cap as the count', (tester) async {
    await pump(tester, feed: RequestFeed.recent);
    expect(anyNote, findsNothing);

    await search(tester, 'alpha');
    expect(find.text(_zh2000), findsOneWidget);
    expect(find.textContaining(RegExp(r'alpha\d+\.test')), findsWidgets);
    // Under the bar, above the results.
    expect(
      tester.getRect(find.text(_zh2000)).bottom,
      lessThanOrEqualTo(
        tester
            .getRect(find.textContaining(RegExp(r'alpha\d+\.test')).first)
            .top,
      ),
    );

    await search(tester, '');
    expect(anyNote, findsNothing);
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('a search that finds nothing still says what it covered', (
    tester,
  ) async {
    await pump(tester, feed: RequestFeed.recent);
    await search(tester, 'no-such-host');
    expect(find.text(_zh2000), findsOneWidget);
    expect(find.byType(NullStatus), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('paused, the note gives the larger cap it keeps then', (
    tester,
  ) async {
    await pump(tester, feed: RequestFeed.recent);
    final box = find.byType(ScrollToEndBox);
    await tester.drag(box, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.widget<ScrollToEndBox>(box).enable, isFalse);

    await search(tester, 'alpha');
    expect(tester.widget<ScrollToEndBox>(box).enable, isFalse);
    expect(find.text(_zh4000), findsOneWidget);
    expect(find.text(_zh2000), findsNothing);
    await teardown(tester);
  });

  testWidgets('running: no note, searching or not', (tester) async {
    await pump(tester, feed: RequestFeed.live);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(anyNote, findsNothing);
    await search(tester, 'alpha');
    expect(find.textContaining(RegExp(r'alpha\d+\.test')), findsWidgets);
    expect(anyNote, findsNothing);
    await teardown(tester);
  });

  testWidgets('the count is grouped as each language writes numbers', (
    tester,
  ) async {
    await pump(tester, feed: RequestFeed.recent, locale: const Locale('en'));
    await search(tester, 'alpha');
    expect(
      find.text('Search covers only the most recent 2,000 retained records.'),
      findsOneWidget,
    );
    await teardown(tester);
    for (final (locale, count) in const [
      (Locale('es'), '2.000'),
      (Locale('fr'), '2\u202f000'),
      (Locale('ja'), '2,000'),
      (Locale('ko'), '2,000'),
      (Locale('ru'), '2\u00a0000'),
    ]) {
      final l = lookupAppLocalizations(locale);
      expect(
        l.requestsSearchScopeHint(maxRequestsLength),
        contains(count),
        reason: '$locale',
      );
    }
  });

  testWidgets('a screen reader hears the note when the search starts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, feed: RequestFeed.recent);
    await search(tester, 'alpha');
    final node = tester.getSemantics(find.text(_zh2000));
    expect(node.label, _zh2000);
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
    await teardown(tester);
  });

  for (final locale in const [Locale('ru'), Locale('fr')]) {
    testWidgets('${locale.languageCode} 360x640 ×2: the note wraps whole, '
        'no overflow', (tester) async {
      await pump(
        tester,
        feed: RequestFeed.recent,
        locale: locale,
        size: const Size(360, 640),
        textScale: 2,
      );
      await search(tester, 'alpha');
      final note = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data ?? '').contains('2') &&
            widget.data!.length > 40,
      );
      expect(note, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: note, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.height, greaterThan(40));
      final rect = tester.getRect(note);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
      await teardown(tester);
    });
  }
}
