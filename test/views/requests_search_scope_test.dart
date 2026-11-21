import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  chains: [id.hashCode.isEven ? 'Tokyo' : 'Proxy'],
  rule: 'DOMAIN',
  rulePayload: host,
);

/// The note in Chinese, as a reader sees it.
String _zh(String count, String limit) =>
    '搜索、筛选和排序仅作用于已保留的记录。当前保留 $count 条，上限 $limit 条。';

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

  List<TrackerInfo> trackers(int from, int count) => [
    for (var i = from; i < from + count; i++)
      _tracker('$i', host: i.isEven ? 'alpha$i.test' : 'beta$i.test'),
  ];

  final requests = trackers(0, 400);

  void add(List<TrackerInfo> trackers) {
    final notifier = container.read(requestsProvider.notifier);
    for (final request in trackers) {
      notifier.addRequest(request);
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    required RequestFeed feed,
    Locale locale = const Locale('zh', 'CN'),
    Size size = const Size(600, 1000),
    double textScale = 1,
  }) async {
    container.read(requestsProvider.notifier).value = FixedList<TrackerInfo>(
      maxRequestsLength,
    );
    add(requests);
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

  /// What the source sends reaches the list a throttle later.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(renderThrottleDuration);
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

  final box = find.byType(ScrollToEndBox);
  bool following(WidgetTester tester) =>
      tester.widget<ScrollToEndBox>(box).enable;

  Future<void> pause(WidgetTester tester) async {
    await tester.drag(box, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(following(tester), isFalse);
  }

  /// Back to the list's head, however far the requests kept while paused
  /// pushed it: most of the way at once, the rest as a reader drags it.
  Future<void> resume(WidgetTester tester) async {
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: box, matching: find.byType(Scrollable)).first,
        )
        .position;
    for (var i = 0; i < 20 && !following(tester); i++) {
      position.jumpTo(max(0, position.maxScrollExtent - 300));
      await tester.pump();
      await tester.drag(box, const Offset(0, 600));
      await tester.pumpAndSettle();
    }
    expect(following(tester), isTrue);
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  /// Any copy of the note, in any language and with any numbers.
  final anyNote = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        RegExp(
          r'仅作用于已保留的记录|apply only to retained',
        ).hasMatch(widget.data ?? ''),
  );

  testWidgets('recent requests: the note is there before any search, gives '
      'what is kept against the limit, and stays through a search', (
    tester,
  ) async {
    await pump(tester, feed: RequestFeed.recent);
    // Fewer kept than the limit: says so, never the limit as what is kept.
    expect(find.text(_zh('400', '2,000')), findsOneWidget);
    expect(anyNote, findsOneWidget);

    await search(tester, 'alpha');
    // The search narrows what is shown, not what is kept.
    expect(find.text(_zh('400', '2,000')), findsOneWidget);
    final hit = find.textContaining(RegExp(r'alpha\d+\.test')).first;
    // Under the bar, above the results.
    expect(
      tester.getRect(find.text(_zh('400', '2,000'))).bottom,
      lessThanOrEqualTo(tester.getRect(hit).top),
    );

    await search(tester, 'no-such-host');
    expect(find.byType(NullStatus), findsOneWidget);
    expect(find.text(_zh('400', '2,000')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('filtered with no search: the note is there unchanged', (
    tester,
  ) async {
    await pump(tester, feed: RequestFeed.recent);
    RecordFilterScope.add(
      tester.element(box),
      const RecordFilter(RecordFacetKind.proxy, 'Tokyo'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text(_zh('400', '2,000')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('kept follows the source up to the limit, live', (tester) async {
    await pump(tester, feed: RequestFeed.recent);
    add(trackers(400, 1000));
    await settle(tester);
    expect(find.text(_zh('1,400', '2,000')), findsOneWidget);
    add(trackers(1400, 1000));
    await settle(tester);
    expect(find.text(_zh('2,000', '2,000')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('paused: the limit is the larger one, kept the real count; '
      'resumed: back to the source, both clamped', (tester) async {
    await pump(tester, feed: RequestFeed.recent);
    await pause(tester);
    // Nothing new kept yet: never the paused limit as the count.
    expect(find.text(_zh('400', '4,000')), findsOneWidget);
    expect(anyNote, findsOneWidget);

    // The source moves past all it held; paused, the list keeps both.
    add(trackers(400, 2000));
    await settle(tester);
    expect(following(tester), isFalse);
    expect(find.text(_zh('2,400', '4,000')), findsOneWidget);

    await resume(tester);
    expect(find.text(_zh('2,000', '2,000')), findsOneWidget);
    expect(anyNote, findsOneWidget);
    await teardown(tester);
  });

  for (final paused in [false, true]) {
    testWidgets('cleared ${paused ? 'paused' : 'following'}: '
        'nothing kept, the limit stays', (tester) async {
      await pump(tester, feed: RequestFeed.recent);
      if (paused) await pause(tester);
      // As the app clears them when the Core restarts.
      container.read(requestsProvider.notifier).value = FixedList(
        maxRequestsLength,
      );
      await settle(tester);
      final limit = paused ? '4,000' : '2,000';
      expect(find.text(_zh('0', limit)), findsOneWidget);
      expect(find.byType(NullStatus), findsOneWidget);

      add(trackers(400, 3));
      await settle(tester);
      expect(find.text(_zh('3', limit)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await teardown(tester);
    });
  }

  testWidgets('running: no note, searched, filtered or not', (tester) async {
    await pump(tester, feed: RequestFeed.live);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'alpha\d+\.test')), findsWidgets);
    expect(anyNote, findsNothing);
    await search(tester, 'alpha');
    expect(find.textContaining(RegExp(r'alpha\d+\.test')), findsWidgets);
    expect(anyNote, findsNothing);
    await teardown(tester);
  });

  testWidgets('both numbers are grouped as each language writes them', (
    tester,
  ) async {
    await pump(tester, feed: RequestFeed.recent, locale: const Locale('en'));
    expect(
      find.text(
        'Search, filters and sorting apply only to retained records. '
        'Retained: 400; limit: 2,000.',
      ),
      findsOneWidget,
    );
    await teardown(tester);
    for (final (locale, count, limit) in const [
      (Locale('es'), '1.400', '4.000'),
      (Locale('fr'), '1\u202f400', '4\u202f000'),
      (Locale('ja'), '1,400', '4,000'),
      (Locale('ko'), '1,400', '4,000'),
      (Locale('ru'), '1\u00a0400', '4\u00a0000'),
      (Locale('zh'), '1,400', '4,000'),
    ]) {
      final text = lookupAppLocalizations(
        locale,
      ).requestsSearchScopeHint(1400, pausedMaxRequestsLength);
      expect(text, contains(count), reason: '$locale');
      expect(text, contains(limit), reason: '$locale');
      expect(text.indexOf(count), lessThan(text.indexOf(limit)));
    }
  });

  testWidgets('a screen reader reads the note whole, before the list, '
      'and its current numbers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, feed: RequestFeed.recent);
    final node = tester.getSemantics(find.text(_zh('400', '2,000')));
    expect(node.label, _zh('400', '2,000'));
    // Not a live region: the count moves with each request while following.
    expect(node.flagsCollection.isLiveRegion, isFalse);
    // Its own node, not merged into a row or the bar.
    final row = tester.getSemantics(
      find.textContaining(RegExp(r'(alpha|beta)\d+\.test')).first,
    );
    expect(row.id, isNot(node.id));
    expect(row.label, isNot(contains(_zh('400', '2,000'))));

    await pause(tester);
    expect(
      tester.getSemantics(find.text(_zh('400', '4,000'))).label,
      _zh('400', '4,000'),
    );
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
      final text = lookupAppLocalizations(
        locale,
      ).requestsSearchScopeHint(400, maxRequestsLength);
      final note = find.text(text);
      expect(note, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: note, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.height, greaterThan(40));
      final rect = tester.getRect(note);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.bottom, lessThan(640));
      expect(tester.takeException(), isNull);
      await search(tester, 'alpha');
      expect(note, findsOneWidget);
      expect(tester.takeException(), isNull);
      await teardown(tester);
    });
  }
}
