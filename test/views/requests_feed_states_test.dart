import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

TrackerInfo _tracker(
  String id, {
  String host = 'example.com',
  String exit = 'Proxy',
}) => TrackerInfo(
  id: id,
  start: DateTime.utc(2026),
  metadata: Metadata(
    network: 'tcp',
    host: host,
    destinationIP: '1.1.1.1',
    destinationPort: '443',
    process: 'curl',
  ),
  chains: [exit],
  rule: 'DOMAIN',
  rulePayload: host,
);

List<TrackerInfo> _trackers(int count, {String prefix = 'r'}) => [
  for (var i = 0; i < count; i++) _tracker('$prefix$i', host: 'host$i.test'),
];

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

  void seed(List<TrackerInfo> requests) {
    final notifier = container.read(requestsProvider.notifier);
    notifier.value = FixedList<TrackerInfo>(maxRequestsLength);
    for (final request in requests) {
      notifier.addRequest(request);
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    required RequestFeed feed,
    required Future<List<TrackerInfo>> Function()? connectionsReader,
    Locale locale = const Locale('en'),
    Size size = const Size(600, 1000),
  }) async {
    container.read(viewSizeProvider.notifier).update((_) => size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: locale,
          child: RequestsView(
            initialFeed: feed,
            connectionsReader: connectionsReader,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  final menu = find.byType(PopupMenu);
  Finder inMenu(Finder finder) => find.descendant(of: menu, matching: finder);

  Future<void> openMenu(WidgetTester tester, String title) async {
    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text(title)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> closeMenu(WidgetTester tester) async {
    await tester.tapAt(const Offset(300, 900));
    await tester.pumpAndSettle();
  }

  /// The counts the menu shows, in its order: recent, then running.
  List<String> counts(WidgetTester tester) => [
    for (final element in inMenu(find.byType(RequestFeedCount)).evaluate())
      tester
          .widget<Text>(
            find.descendant(
              of: find.byWidget(element.widget),
              matching: find.byType(Text),
            ),
          )
          .data!,
  ];

  group('the feed menu', () {
    testWidgets('counts none as 0 once the read of what is open succeeds', (
      tester,
    ) async {
      seed(const []);
      final read = Completer<List<TrackerInfo>>();
      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () => read.future,
      );

      await openMenu(tester, 'Recent requests');
      expect(inMenu(find.text('Recent requests')), findsOneWidget);
      expect(inMenu(find.text('Running')), findsOneWidget);
      expect(counts(tester), ['0', '—']);

      read.complete(const []);
      await tester.pump();
      expect(counts(tester), ['0', '0']);

      await closeMenu(tester);
      await teardown(tester);
    });

    testWidgets('writes four digits grouped as the language does', (
      tester,
    ) async {
      seed(_trackers(maxRequestsLength));
      final running = _trackers(2048, prefix: 'c');
      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () async => running,
      );

      await openMenu(tester, 'Recent requests');
      await tester.pump();
      expect(counts(tester), ['2,000', '2,048']);
      await closeMenu(tester);
      await teardown(tester);

      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () async => running,
        locale: const Locale('ru'),
      );
      final title = tester
          .element(find.byType(RequestsView))
          .appLocalizations
          .recentRequests;
      await openMenu(tester, title);
      await tester.pump();
      final ru = NumberFormat.decimalPattern('ru');
      expect(ru.format(2048), isNot('2,048'));
      expect(counts(tester), [ru.format(2000), ru.format(2048)]);
      await closeMenu(tester);
      await teardown(tester);
    });

    testWidgets('a running read that fails is unknown, read as such', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      seed(_trackers(3));
      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () async => throw Exception('core gone'),
      );

      await openMenu(tester, 'Recent requests');
      await tester.pump();
      expect(counts(tester), ['3', '—']);
      expect(find.bySemanticsLabel(RegExp('Count unknown')), findsOneWidget);

      await closeMenu(tester);
      semantics.dispose();
      await teardown(tester);
    });

    testWidgets('holds its counts while shown, and reads them again when '
        'opened again', (tester) async {
      seed(_trackers(3));
      var reads = 0;
      final running = _trackers(5, prefix: 'c');
      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () async {
          reads++;
          return running;
        },
      );

      await openMenu(tester, 'Recent requests');
      await tester.pump();
      expect(counts(tester), ['3', '5']);
      expect(reads, 1);

      container.read(requestsProvider.notifier).addRequest(_tracker('new'));
      running.add(_tracker('c-new'));
      await tester.pump(const Duration(seconds: 2));
      expect(counts(tester), ['3', '5']);
      expect(reads, 1);

      await closeMenu(tester);
      await openMenu(tester, 'Recent requests');
      await tester.pump();
      expect(counts(tester), ['4', '6']);
      expect(reads, 2);

      await closeMenu(tester);
      await teardown(tester);
    });

    testWidgets('opening it on running takes the fresh snapshot, and builds '
        'no row again', (tester) async {
      seed(const []);
      var reads = 0;
      await pump(
        tester,
        feed: RequestFeed.live,
        connectionsReader: () async {
          reads++;
          return _trackers(2048, prefix: 'c');
        },
      );
      // Until the list has built what it keeps around the view.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump();
      expect(find.byType(TrackerCompactRow), findsWidgets);

      var built = 0;
      debugOnRebuildDirtyWidget = (element, _) {
        if (element.widget is TrackerCompactRow) built++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      final readsBefore = reads;
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Running'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(counts(tester), ['0', '2,048']);
      expect(reads, readsBefore);
      expect(built, 0);
      debugOnRebuildDirtyWidget = null;

      await closeMenu(tester);
      await teardown(tester);
    });

    testWidgets('a running count waits on the read already under way', (
      tester,
    ) async {
      seed(const []);
      var reads = 0;
      Completer<List<TrackerInfo>>? pending;
      await pump(
        tester,
        feed: RequestFeed.live,
        connectionsReader: () {
          reads++;
          return (pending = Completer<List<TrackerInfo>>()).future;
        },
      );
      expect(reads, 1);

      await openMenu(tester, 'Running');
      expect(reads, 1);
      expect(counts(tester), ['0', '—']);

      pending!.complete(_trackers(7, prefix: 'c'));
      await tester.pump();
      expect(counts(tester), ['0', '7']);

      await closeMenu(tester);
      await teardown(tester);
    });

    testWidgets('a running count overtaken by a newer read takes the newer '
        'one\'s', (tester) async {
      seed(const []);
      final reads = <Completer<List<TrackerInfo>>>[];
      await pump(
        tester,
        feed: RequestFeed.live,
        connectionsReader: () {
          final read = Completer<List<TrackerInfo>>();
          reads.add(read);
          return read.future;
        },
      );
      reads.first.completeError(Exception('core gone'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(reads, hasLength(2));

      await openMenu(tester, 'Running');
      expect(counts(tester), ['0', '—']);
      // A retry reads again beside the poll the menu waits on.
      tester.widget<RetryButton>(find.byType(RetryButton)).onRetry();
      await tester.pump();
      expect(reads, hasLength(3));
      reads[2].complete(_trackers(7, prefix: 'c'));
      await tester.pump();
      reads[1].complete(_trackers(3, prefix: 'c'));
      await tester.pump();
      expect(counts(tester), ['0', '7']);

      await closeMenu(tester);
      await teardown(tester);
    });

    for (final (status, count) in const [
      (CoreStatus.connecting, '—'),
      (CoreStatus.disconnected, '0'),
    ]) {
      testWidgets('a running count is $count while the Core is '
          '${status.name}', (tester) async {
        seed(const []);
        container.read(coreStatusProvider.notifier).value = status;
        await pump(tester, feed: RequestFeed.recent, connectionsReader: null);

        await openMenu(tester, 'Recent requests');
        await tester.pump();
        expect(counts(tester), ['0', count]);

        await closeMenu(tester);
        await teardown(tester);
      });
    }

    testWidgets('a count that comes back as the menu closes reaches only '
        'that menu, and the next one reads again', (tester) async {
      seed(const []);
      final reads = <Completer<List<TrackerInfo>>>[];
      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () {
          final read = Completer<List<TrackerInfo>>();
          reads.add(read);
          return read.future;
        },
      );

      await openMenu(tester, 'Recent requests');
      await tester.tapAt(const Offset(300, 900));
      await tester.pump(const Duration(milliseconds: 50));
      expect(menu, findsOneWidget);
      reads.single.complete(_trackers(4, prefix: 'c'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(counts(tester), ['0', '4']);
      await tester.pumpAndSettle();
      expect(menu, findsNothing);

      await openMenu(tester, 'Recent requests');
      expect(counts(tester), ['0', '—']);
      reads.last.complete(_trackers(6, prefix: 'c'));
      await tester.pump();
      expect(reads, hasLength(2));
      expect(counts(tester), ['0', '6']);

      await closeMenu(tester);
      await teardown(tester);
    });

    testWidgets('the title takes a 44dp press at least', (tester) async {
      seed(const []);
      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () async => const [],
        size: const Size(340, 800),
      );

      final title = find.ancestor(
        of: find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Recent requests'),
        ),
        matching: find.byType(PressRegion),
      );
      final size = tester.getSize(title.first);
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));

      await teardown(tester);
    });
  });

  group('an empty feed', () {
    testWidgets('with no request kept says so, a search typed or not', (
      tester,
    ) async {
      seed(const []);
      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () async => const [],
      );
      final none = find.text('No Requests yet');
      expect(none, findsOneWidget);

      await tester.tap(find.byGlyph(AppGlyphs.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(none, findsOneWidget);
      expect(find.text('No matching results'), findsNothing);

      await teardown(tester);
    });

    testWidgets('with nothing open says so', (tester) async {
      seed(const []);
      await pump(
        tester,
        feed: RequestFeed.live,
        connectionsReader: () async => const [],
      );
      await tester.pumpAndSettle();
      expect(find.text('No Connections yet'), findsOneWidget);

      await teardown(tester);
    });

    testWidgets('first loads behind a spinner', (tester) async {
      seed(const []);
      final read = Completer<List<TrackerInfo>>();
      await pump(
        tester,
        feed: RequestFeed.live,
        connectionsReader: () => read.future,
      );
      expect(find.byType(ActivityIndicator), findsOneWidget);
      expect(find.text('No Connections yet'), findsNothing);

      read.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('No Connections yet'), findsOneWidget);

      await teardown(tester);
    });

    testWidgets('searched to nothing clears the search and keeps the feed', (
      tester,
    ) async {
      seed([
        _tracker('a', host: 'alpha.test'),
        _tracker('b', host: 'beta.test', exit: 'Tokyo'),
      ]);
      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () async => const [],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byGlyph(AppGlyphs.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matching results'), findsOneWidget);
      expect(find.text('No Requests yet'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('No matching results'), findsNothing);
      expect(find.textContaining('alpha.test'), findsOneWidget);
      expect(find.textContaining('beta.test'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byType(TrackerCompactRow), findsNWidgets(2));

      await teardown(tester);
    });

    testWidgets('searched and filtered to nothing clears both', (tester) async {
      seed([
        _tracker('a', host: 'alpha.test'),
        _tracker('b', host: 'beta.test', exit: 'Tokyo'),
      ]);
      await pump(
        tester,
        feed: RequestFeed.recent,
        connectionsReader: () async => const [],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TonalChip, 'Tokyo'));
      await tester.pumpAndSettle();
      expect(find.byType(TrackerInfoDetailView), findsNothing);
      expect(find.textContaining('alpha.test'), findsNothing);
      expect(find.widgetWithText(Chip, 'Tokyo'), findsOneWidget);

      await tester.tap(find.byGlyph(AppGlyphs.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pumpAndSettle();
      expect(find.text('No matching results'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(TextButton, 'Clear search and filters'),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Chip, 'Tokyo'), findsNothing);
      expect(find.textContaining('alpha.test'), findsOneWidget);
      expect(find.textContaining('beta.test'), findsOneWidget);

      await teardown(tester);
    });

    testWidgets('filtered to nothing clears the filters', (tester) async {
      seed(const []);
      var running = [
        _tracker('a', host: 'alpha.test'),
        _tracker('b', host: 'beta.test', exit: 'Tokyo'),
      ];
      await pump(
        tester,
        feed: RequestFeed.live,
        connectionsReader: () async => running,
        // Room for speeds and the exit in the test font's full-em glyphs.
        size: const Size(700, 1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TonalChip, 'Tokyo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('alpha.test'), findsNothing);

      running = [_tracker('a', host: 'alpha.test')];
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('No matching results'), findsOneWidget);
      expect(find.text('No Connections yet'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Clear filters'));
      await tester.pumpAndSettle();
      expect(find.textContaining('alpha.test'), findsOneWidget);

      await teardown(tester);
    });

    testWidgets('a refresh that fails keeps the last result under a banner', (
      tester,
    ) async {
      seed(const []);
      var fails = false;
      await pump(
        tester,
        feed: RequestFeed.live,
        connectionsReader: () async {
          if (fails) throw Exception('core gone');
          return [_tracker('a', host: 'alpha.test')];
        },
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('alpha.test'), findsOneWidget);

      fails = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final l10n = currentAppLocalizations;
      expect(find.text(l10n.connectionsRefreshFailedStale), findsOneWidget);
      expect(find.textContaining('alpha.test'), findsOneWidget);
      expect(find.text('No Connections yet'), findsNothing);

      await openMenu(tester, 'Running');
      await tester.pump();
      expect(counts(tester), ['0', '—']);

      await closeMenu(tester);
      await teardown(tester);
    });

    testWidgets('a refresh that fails after an empty read never says there '
        'are none', (tester) async {
      seed(const []);
      var fails = false;
      await pump(
        tester,
        feed: RequestFeed.live,
        connectionsReader: () async {
          if (fails) throw Exception('core gone');
          return const [];
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('No Connections yet'), findsOneWidget);

      fails = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final l10n = currentAppLocalizations;
      expect(find.text(l10n.connectionsRefreshFailedStale), findsOneWidget);
      expect(find.text('No Connections yet'), findsNothing);
      expect(find.text(l10n.connectionsReadFailed), findsOneWidget);
      // One retry, the banner's.
      expect(find.byType(RetryButton), findsOneWidget);

      await teardown(tester);
    });
  });
}
