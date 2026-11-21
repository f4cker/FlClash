import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/core_connections.dart';
import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

TrackerInfo _tracker(
  String id, {
  String? host,
  bool mitm = false,
  int download = 0,
}) {
  return TrackerInfo(
    id: id,
    download: download,
    start: DateTime.utc(2026),
    metadata: Metadata(
      network: 'tcp',
      host: host ?? '$id.test',
      destinationIP: '1.1.1.1',
      destinationPort: '443',
      process: 'curl',
      mitm: mitm,
    ),
    chains: const ['Proxy'],
    rule: 'DOMAIN',
    rulePayload: host ?? '$id.test',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockCore core;
  late ProviderContainer container;
  late List<TrackerInfo> live;
  late int reads;

  setUpAll(() => core = _MockCore());

  setUp(() {
    reset(core);
    reads = 0;
    live = [_tracker('a'), _tracker('b')];
    whenConnections<RankedTrackerInfos>(core, () async {
      reads++;
      return live;
    });
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
  });

  tearDown(() => container.dispose());

  Requests requests() => container.read(requestsProvider.notifier);

  Future<void> pumpLive(WidgetTester tester, {double width = 1400}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          child: RequestsView(initialFeed: RequestFeed.live),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(commonDuration);
  }

  Future<void> teardownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  Finder badgeOf(String id) => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is TrackerTargetText && widget.trackerInfo.id == id,
    ),
    matching: find.byGlyph(MitmBadge.decrypted.glyph),
  );

  testWidgets('a live row is marked decrypted in place once the Core says so, '
      'without waiting for the next read', (tester) async {
    await pumpLive(tester);
    expect(find.byType(TrackerInfoTableRow), findsNWidgets(2));
    expect(find.byGlyph(MitmBadge.decrypted.glyph), findsNothing);

    final before = reads;
    // The request event may not have come yet: the report alone marks it.
    requests().setMitmOutcome('a', 'decrypted');
    await tester.pump(renderThrottleDuration);
    await tester.pump();

    expect(reads, before);
    expect(badgeOf('a'), findsOneWidget);
    expect(badgeOf('b'), findsNothing);

    // The next read, whose snapshot never carries it, keeps the mark.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(reads, greaterThan(before));
    expect(badgeOf('a'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await teardownView(tester);
  });

  testWidgets('the mark outlives the request leaving the request list while '
      'the connection stays open', (tester) async {
    final notifier = requests();
    notifier.value = FixedList<TrackerInfo>(2);
    notifier.addRequest(_tracker('a'));
    notifier.setMitmOutcome('a', 'decrypted');
    notifier.addRequest(_tracker('x'));
    notifier.addRequest(_tracker('y'));
    expect(
      container.read(requestsProvider).list.map((request) => request.id),
      isNot(contains('a')),
    );

    await pumpLive(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(badgeOf('a'), findsOneWidget);
    expect(badgeOf('b'), findsNothing);

    await teardownView(tester);
  });

  testWidgets('the decrypted filter keeps the live rows the Core decrypted', (
    tester,
  ) async {
    await pumpLive(tester);
    requests().setMitmOutcome('a', 'decrypted');
    await tester.pump(renderThrottleDuration);
    await tester.pump();

    RecordFilterScope.add(
      tester.element(find.byType(TrackerInfoTableRow).first),
      const RecordFilter(RecordFacetKind.mitm, 'MITM'),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(commonDuration);

    expect(find.byType(TrackerInfoTableRow), findsOneWidget);
    expect(badgeOf('a'), findsOneWidget);
    expect(find.textContaining('b.test'), findsNothing);

    await teardownView(tester);
  });

  testWidgets('a report other than decrypted never marks a row decrypted', (
    tester,
  ) async {
    await pumpLive(tester);
    requests().setMitmOutcome('a', 'paused', pauseReason: 'liveness');
    requests().setMitmOutcome('b', 'nonsense');
    await tester.pump(renderThrottleDuration);
    await tester.pump();

    expect(find.byGlyph(MitmBadge.decrypted.glyph), findsNothing);
    expect(find.byGlyph(MitmBadge.passedThrough.glyph), findsOneWidget);

    await teardownView(tester);
  });

  testWidgets('a traffic-only read rebuilds the traffic cells of a row, and '
      'a report after it still marks the kept target', (tester) async {
    live = [_tracker('a', download: 100), _tracker('b', download: 100)];
    await pumpLive(tester);

    final rebuilt = <Type, int>{};
    debugOnRebuildDirtyWidget = (element, _) {
      final type = element.widget.runtimeType;
      rebuilt[type] = (rebuilt[type] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    live = [_tracker('a', download: 4096), _tracker('b', download: 100)];
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(commonDuration);
    debugOnRebuildDirtyWidget = null;

    expect(rebuilt[TrackerInfoTableRow], greaterThan(0));
    expect(rebuilt[ProcessCell], isNull);
    expect(rebuilt[TrackerTargetText], isNull);
    expect(rebuilt[TrackerRuleText], isNull);
    expect(find.text(4096.traffic.show), findsOneWidget);

    requests().setMitmOutcome('a', 'decrypted');
    await tester.pump(renderThrottleDuration);
    await tester.pump();
    expect(badgeOf('a'), findsOneWidget);
    expect(badgeOf('b'), findsNothing);

    await teardownView(tester);
  });

  testWidgets('over thousands of churning connections the rows marked '
      'decrypted are exactly the reported ones on screen', (tester) async {
    List<TrackerInfo> poll(int round) => [
      for (var i = round * 30; i < round * 30 + 3000; i++)
        _tracker('c$i', download: (i * 7919) % 100000),
    ];
    final reported = {for (var i = 0; i < 3100; i += 7) 'c$i'};
    for (final id in reported) {
      requests().setMitmOutcome(id, 'decrypted');
    }
    live = poll(0);
    await pumpLive(tester);

    for (var round = 1; round <= 3; round++) {
      live = poll(round);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(commonDuration);

      final rows = [
        for (final element in find.byType(TrackerInfoTableRow).evaluate())
          (element.widget as TrackerInfoTableRow).trackerInfo.id,
      ];
      final marked = {
        for (final element
            in find.byGlyph(MitmBadge.decrypted.glyph).evaluate())
          element
              .findAncestorWidgetOfExactType<TrackerTargetText>()!
              .trackerInfo
              .id,
      };
      expect(rows, isNotEmpty);
      expect(marked, isNotEmpty);
      expect(marked, rows.where(reported.contains).toSet());
    }

    await teardownView(tester);
  });

  test('the kept reports are bounded and forgotten for closed connections', () {
    final notifier = requests();
    container.listen(requestsProvider, (_, _) {});
    for (var i = 0; i <= 2048; i++) {
      notifier.setMitmOutcome('c$i', 'decrypted');
    }
    var index = notifier.mitmStatusIndex(container.read(requestsProvider));
    expect(index.length, 2048);
    expect(index.containsKey('c0'), isFalse);
    expect(index['c2048']?.decrypted, isTrue);

    // Still within the grace a snapshot may predate: kept.
    notifier.retainMitmStatuses(const ['c1']);
    index = notifier.mitmStatusIndex(container.read(requestsProvider));
    expect(index.length, 2048);

    final now = DateTime.now();
    Requests.mitmStatusClock = () => now.add(const Duration(minutes: 1));
    addTearDown(() => Requests.mitmStatusClock = DateTime.now);
    notifier.retainMitmStatuses(const ['c1', 'c2048']);
    index = notifier.mitmStatusIndex(container.read(requestsProvider));
    expect(index.keys, unorderedEquals(['c1', 'c2048']));
  });
}
