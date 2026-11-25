import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

TrackerInfo _info({
  String host = 'example.com',
  String ip = '1.1.1.1',
  List<String> chains = const ['DIRECT'],
  String rule = 'MATCH',
  String network = 'tcp',
  String routeReason = '',
  int? uploadSpeed,
  int? downloadSpeed,
}) => TrackerInfo(
  id: '1',
  start: DateTime(2026, 11, 25, 10, 30),
  uploadSpeed: uploadSpeed,
  downloadSpeed: downloadSpeed,
  metadata: Metadata(
    network: network,
    host: host,
    destinationIP: ip,
    destinationPort: '443',
    process: 'ssh',
    processPath: '/usr/bin/ssh',
    routeReason: routeReason,
  ),
  chains: chains,
  rule: rule,
  rulePayload: '',
);

void main() {
  late ProcessApps previous;

  setUp(() {
    loadAppLocalizations(const Locale('en'));
    previous = processApps;
    processApps = ProcessApps(
      lookupApps: true,
      invoke: (_) async => null,
      readLocalAddresses: () async => const {},
    );
    processApps.seed(lookups: {'/usr/bin/ssh': AppLookup.none}, local: {});
  });

  tearDown(() {
    processApps.dispose();
    processApps = previous;
  });

  group('layout', () {
    // 24 of padding, 28 of icon, 4 after the name; the name's column is 50 to
    // 90 wide, the host keeps 60 and 8 stand before what trails.
    ({Set<TrackerTrailing> trailing, double? processWidth}) layout(
      double width, {
      double marksWidth = 0,
      double rewriteWidth = 0,
      bool live = false,
    }) => layoutTrackerCompactRow(
      width: width,
      leadWidth: 28,
      marksWidth: marksWidth,
      rewriteWidth: rewriteWidth,
      hostMinWidth: 60,
      processMinWidth: 50,
      processMaxWidth: 90,
      speedWidth: live ? 150 : null,
      exitWidth: 90,
      noteWidth: live ? null : 40,
    );

    test('drops the note, then the exit, then the speeds, each whole', () {
      // At 300 the row's 30% share sets the name's column to 82.8.
      expect(layout(300).processWidth, closeTo(82.8, 0.01));
      for (final (width, parts) in [
        (500.0, {TrackerTrailing.exit, TrackerTrailing.note}),
        (330.0, {TrackerTrailing.exit}),
        (240.0, <TrackerTrailing>{}),
      ]) {
        expect(layout(width).trailing, parts, reason: '$width');
      }
      for (final (width, parts) in [
        (600.0, {TrackerTrailing.speed, TrackerTrailing.exit}),
        (400.0, {TrackerTrailing.speed}),
        (300.0, <TrackerTrailing>{}),
      ]) {
        expect(layout(width, live: true).trailing, parts, reason: '$width');
      }
    });

    test('the name column keeps its width as parts go, so hosts line up', () {
      expect(layout(1000).processWidth, 90);
      expect(layout(500).processWidth, layout(500, live: true).processWidth);
      expect(layout(190).processWidth, 50);
    });

    test('a live list\'s name column gives way so speeds fit', () {
      expect(layout(360, live: true).processWidth, 86);
      expect(layout(360, live: true).trailing, {TrackerTrailing.speed});
      expect(layout(360).processWidth, 90);
      // Never under its least, and alike whatever marks one row carries.
      expect(layout(310, live: true).processWidth, 50);
      expect(layout(310, live: true).trailing, isEmpty);
      final rewritten = layout(360, live: true, rewriteWidth: 18);
      expect(rewritten.processWidth, 86);
      expect(rewritten.trailing, isEmpty);
    });

    test('only a row too narrow for both shrinks the name, then the host, '
        'and drops the name last', () {
      // The name and the host share what is past 56 of padding, icon and gap.
      expect(layout(56 + 60 + 50).processWidth, 50);
      expect(layout(56 + 60 + 45).processWidth, closeTo(105 * 50 / 110, 0.01));
      expect(layout(56 + 60 + 45).trailing, isEmpty);
      expect(layout(56 + 60).processWidth, closeTo(60 * 50 / 110, 0.01));
      expect(layout(56 + 40).processWidth, isNull);
    });
  });

  test('speeds read whole numbers in the larger one\'s unit', () {
    expect(trackerCompactSpeeds(2048, 14336), ('2', '14', 'KB/s'));
    expect(trackerCompactSpeeds(0, 12288), ('0', '12', 'KB/s'));
    expect(trackerCompactSpeeds(100, 900), ('100', '900', 'B/s'));
    expect(trackerCompactSpeeds(300, 1024 * 1024), ('<1', '1', 'MB/s'));
    expect(trackerCompactSpeeds(1024 * 1023.9, 0), ('1024', '0', 'KB/s'));
  });

  Future<List<RecordFilter>> pump(
    WidgetTester tester,
    TrackerInfo info, {
    bool isLive = false,
    double width = 360,
    double textScale = 1,
    String? process,
  }) async {
    final filters = <RecordFilter>[];
    if (process != null) {
      info = info.copyWith(
        metadata: info.metadata.copyWith(
          process: process,
          processPath: '/usr/local/bin/$process',
        ),
      );
      processApps.seed(
        lookups: {'/usr/local/bin/$process': AppLookup.none},
        local: {},
      );
    }
    tester.view.physicalSize = Size(math.max(800, width), 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => HostScaffold(body: child),
        child: RecordFilterScope(
          onFilter: filters.add,
          child: SizedBox(
            width: width,
            child: Builder(
              builder: (context) => TrackerCompactRow(
                trackerInfo: info,
                isLive: isLive,
                detailTitle: 'detail',
                metrics: TrackerCompactMetrics.of(context),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return filters;
  }

  bool shows(Finder finder) => finder.evaluate().isNotEmpty;
  final exitChip = find.byType(TonalChip);
  final speeds = find.textContaining('/s');

  testWidgets('a recent row reads icon, host and port, exit and network', (
    tester,
  ) async {
    // The test font sets every glyph a full em wide.
    await pump(tester, _info(), width: 600);

    expect(find.byType(ProcessFilterIcon), findsOneWidget);
    expect(find.text('ssh'), findsOneWidget);
    expect(find.text('example.com:443'), findsOneWidget);
    expect(find.widgetWithText(TonalChip, 'DIRECT'), findsOneWidget);
    expect(find.text('TCP'), findsOneWidget);
    expect(speeds, findsNothing);
    final host = tester.getRect(find.text('example.com:443'));
    final exit = tester.getRect(exitChip);
    final note = tester.getRect(find.text('TCP'));
    final process = tester.getRect(find.text('ssh'));
    expect(
      tester.getRect(find.byType(ProcessFilterIcon)).right,
      lessThan(process.left),
    );
    expect(process.right + 4, lessThanOrEqualTo(host.left));
    expect(process.center.dy, closeTo(host.center.dy, 1));
    // The exit, kept longest, ends the row in line with the rows around it.
    expect(host.right + 8, lessThanOrEqualTo(note.left));
    expect(note.right, lessThan(exit.left));
    expect(exit.right, 600 - 4 - 12);
    final row = tester.getRect(find.byType(TrackerCompactRow));
    expect(host.center.dy, row.center.dy);
    expect(exit.center.dy, closeTo(row.center.dy, 1));
  });

  testWidgets('a row no rule matched shows the short route reason', (
    tester,
  ) async {
    await pump(tester, _info(rule: '', routeReason: 'no-rule-matched'));

    expect(find.text('TCP'), findsNothing);
  });

  testWidgets('a live row ends on its speeds, after the exit', (tester) async {
    await pump(
      tester,
      _info(uploadSpeed: 1024, downloadSpeed: 1024 * 1024 * 900),
      isLive: true,
      width: 800,
    );

    expect(find.text('TCP'), findsNothing);
    expect(find.text('<1'), findsOneWidget);
    expect(find.text('900 MB/s'), findsOneWidget);
    expect(
      tester.getRect(exitChip).right,
      lessThan(tester.getRect(find.text('<1')).left),
    );
    expect(tester.getRect(speeds).right, 800 - 4 - 12);
  });

  for (final textScale in const [1.0, 2.0]) {
    for (final isLive in const [false, true]) {
      testWidgets('at ${textScale}x text a ${isLive ? 'live' : 'recent'} row '
          'drops what trails in order and keeps the host', (tester) async {
        final dropped = <int>[];
        for (final width in const <double>[
          1800,
          1000,
          720,
          480,
          360,
          320,
          280,
          240,
          200,
        ]) {
          await pump(
            tester,
            _info(
              host: 'a-very-long-subdomain.example-cdn.com',
              chains: const ['Long exit node name'],
              uploadSpeed: 1024 * 1024 * 1000,
              downloadSpeed: 1024 * 1024 * 1000,
            ),
            isLive: isLive,
            width: width,
            textScale: textScale,
          );
          expect(tester.takeException(), isNull);
          final metrics = TrackerCompactMetrics.of(
            tester.element(find.byType(TrackerCompactRow)),
          );
          final host = find.textContaining('a-very-long');
          // Only a row too narrow for the host alone gives it less.
          expect(
            tester.getSize(host).width,
            greaterThanOrEqualTo(
              math.min(metrics.hostMinWidth, (width - 8 - 24 - 28 - 4) * 0.45) -
                  0.5,
            ),
          );
          final note = shows(find.text('TCP'));
          final exit = shows(exitChip);
          final speed = shows(speeds);
          // A part shows only while every part kept longer than it does,
          // and the process name outlasts them all.
          if (note || exit || speed) {
            expect(find.text('ssh'), findsOneWidget);
          }
          expect(find.byType(ProcessFilterIcon), findsOneWidget);
          if (isLive) {
            expect(!exit || speed, isTrue, reason: 'exit without speeds');
            dropped.add([speed, exit].where((part) => part).length);
          } else {
            expect(!note || exit, isTrue, reason: 'note without the exit');
            dropped.add([exit, note].where((part) => part).length);
          }
          expect(
            tester.getSize(find.byType(TrackerCompactRow)).height,
            metrics.rowHeight,
          );
        }
        expect(dropped.first, 2);
        expect(dropped.last, 0);
        for (var i = 1; i < dropped.length; i++) {
          expect(dropped[i], lessThanOrEqualTo(dropped[i - 1]));
        }
      });
    }
  }

  testWidgets('rows stand at 48dp, and taller as the text grows', (
    tester,
  ) async {
    await pump(tester, _info());
    expect(tester.getSize(find.byType(TrackerCompactRow)).height, 48);

    await pump(tester, _info(), textScale: 3);
    final context = tester.element(find.byType(TrackerCompactRow));
    final metrics = TrackerCompactMetrics.of(context);
    final tallest = MeasureScope.of(
      context,
    ).computeTextSize(Text('Hg', style: metrics.host)).height;
    expect(metrics.rowHeight, tallest + 12);
    expect(tester.getSize(find.byType(TrackerCompactRow)).height, tallest + 12);
  });

  testWidgets('the largest text keeps the icon and the host', (tester) async {
    await pump(tester, _info(), width: 200, textScale: 3.2);

    expect(tester.takeException(), isNull);
    expect(find.byType(ProcessFilterIcon), findsOneWidget);
    expect(find.text('example.com:443'), findsOneWidget);
  });

  testWidgets('a long process name and a long host each end in an ellipsis, '
      'neither taking the other', (tester) async {
    await pump(
      tester,
      _info(host: '', ip: '2001:db8:85a3::8a2e:370:7334'),
      process: 'com.example.very-long-helper-process-name',
    );
    expect(tester.takeException(), isNull);
    final metrics = TrackerCompactMetrics.of(
      tester.element(find.byType(TrackerCompactRow)),
    );
    final name = find.text('com.example.very-long-helper-process-name');
    final host = find.text('2001:db8:85a3::8a2e:370:7334:443');
    expect(tester.widget<Text>(name).overflow, TextOverflow.ellipsis);
    expect(
      tester.getSize(name).width,
      inInclusiveRange(metrics.processMinWidth, metrics.processMaxWidth),
    );
    expect(
      tester.getSize(host).width,
      greaterThanOrEqualTo(metrics.hostMinWidth),
    );
  });

  testWidgets('a process without an icon shows its own name by the fallback '
      'icon', (tester) async {
    await pump(tester, _info(), process: 'daemon-without-icon');
    expect(find.text('daemon-without-icon'), findsOneWidget);
    expect(find.byType(ProcessIcon), findsOneWidget);
  });

  testWidgets('a long name or an IPv6 address ends in an ellipsis', (
    tester,
  ) async {
    await pump(tester, _info(host: '', ip: '2001:db8:85a3::8a2e:370:7334'));
    expect(tester.takeException(), isNull);
    expect(find.text('2001:db8:85a3::8a2e:370:7334:443'), findsOneWidget);
    final text = tester.widget<Text>(
      find.text('2001:db8:85a3::8a2e:370:7334:443'),
    );
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  testWidgets('the icon and the exit filter without opening the detail', (
    tester,
  ) async {
    final filters = await pump(tester, _info());

    await tester.tap(find.byType(ProcessFilterIcon));
    await tester.pumpAndSettle();
    expect(filters, const [
      RecordFilter(RecordFacetKind.app, 'exe:/usr/bin/ssh'),
    ]);
    expect(find.byType(TrackerInfoDetailView), findsNothing);

    await tester.tap(exitChip);
    await tester.pumpAndSettle();
    expect(filters.last, const RecordFilter(RecordFacetKind.proxy, 'DIRECT'));
    expect(find.byType(TrackerInfoDetailView), findsNothing);

    await tester.tap(find.text('example.com:443'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackerInfoDetailView), findsOneWidget);
    expect(filters, hasLength(2));
  });

  Future<void> openContextMenu(WidgetTester tester) async {
    await tester.tap(
      find.text('example.com:443'),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  Finder inMenu(Finder finder) =>
      find.descendant(of: find.byType(PopupMenu), matching: finder);

  testWidgets('the menu filters by the process and the one node', (
    tester,
  ) async {
    final filters = await pump(tester, _info());

    await openContextMenu(tester);
    expect(inMenu(find.text('Filter by this process')), findsOneWidget);
    expect(inMenu(find.text('Filter by this node')), findsOneWidget);
    await tester.tap(inMenu(find.text('Filter by this node')));
    await tester.pumpAndSettle();
    expect(filters, const [RecordFilter(RecordFacetKind.proxy, 'DIRECT')]);

    await openContextMenu(tester);
    await tester.tap(inMenu(find.text('Filter by this process')));
    await tester.pumpAndSettle();
    expect(
      filters.last,
      const RecordFilter(RecordFacetKind.app, 'exe:/usr/bin/ssh'),
    );
    expect(find.byType(TrackerInfoDetailView), findsNothing);
  });

  testWidgets('the menu of a chain offers each node of it', (tester) async {
    final filters = await pump(
      tester,
      _info(chains: const ['Tokyo 01', 'Relay', 'Proxy']),
    );

    await openContextMenu(tester);
    expect(inMenu(find.text('Filter by this node')), findsNothing);
    await tester.tap(inMenu(find.text('Filter by node')));
    await tester.pumpAndSettle();
    for (final node in const ['Tokyo 01', 'Relay', 'Proxy']) {
      expect(inMenu(find.text(node)), findsOneWidget);
    }
    await tester.tap(inMenu(find.text('Relay')));
    await tester.pumpAndSettle();
    expect(filters, const [RecordFilter(RecordFacetKind.proxy, 'Relay')]);
  });

  testWidgets('a row outside a filtered list offers no filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => HostScaffold(body: child),
        child: SizedBox(
          width: 360,
          child: Builder(
            builder: (context) => TrackerCompactRow(
              trackerInfo: _info(),
              isLive: false,
              detailTitle: 'detail',
              metrics: TrackerCompactMetrics.of(context),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await openContextMenu(tester);
    expect(find.byType(PopupMenu), findsOneWidget);
    expect(inMenu(find.text('Filter by this node')), findsNothing);
    expect(inMenu(find.text('Filter by this process')), findsNothing);
  });

  testWidgets('a screen reader hears the target, marks and exit, no speed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      _info(uploadSpeed: 2048, downloadSpeed: 4096),
      isLive: true,
      width: 600,
    );

    final row = tester.getSemantics(find.byType(TrackerCompactRow));
    expect(row.label, contains('example.com:443'));
    expect(row.label, contains('Exit DIRECT'));
    expect(row.label, contains('ssh'));
    expect(row.label, isNot(contains('/s')));
    expect(find.bySemanticsLabel(RegExp(r'/s')), findsNothing);
    semantics.dispose();
  });
}
