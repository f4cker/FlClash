import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
    // 24 of padding, 28 of icon, 4 after the name; the name's least is 50,
    // the host keeps 60 at least and 120 before anything trails it, and 8
    // stand before what trails.
    ({Set<TrackerTrailing> trailing, double? processWidth}) layout(
      double width, {
      double? process = 40,
      double marksWidth = 0,
      bool live = false,
    }) => layoutTrackerCompactRow(
      width: width,
      leadWidth: 28,
      marksWidth: marksWidth,
      processWidth: process,
      processMinWidth: 50,
      hostReadableWidth: 120,
      hostMinWidth: 60,
      speedWidth: live ? 150 : null,
      exitWidth: 90,
      noteWidth: live ? null : 40,
    );

    test('the name takes its own width, at most 30% of the row', () {
      expect(layout(600).processWidth, 40);
      expect(layout(300, process: 200).processWidth, closeTo(82.8, 0.01));
      expect(layout(600, process: null).processWidth, isNull);
    });

    test('what trails waits for the host\'s readable least, and goes note '
        'first, then the exit, then the speeds, each whole', () {
      // 224 of the row stand before anything trails: 52, 44, 120 and 8.
      for (final (width, parts) in [
        (400.0, {TrackerTrailing.exit, TrackerTrailing.note}),
        (358.0, {TrackerTrailing.exit, TrackerTrailing.note}),
        (357.0, {TrackerTrailing.exit}),
        (314.0, {TrackerTrailing.exit}),
        (313.0, <TrackerTrailing>{}),
      ]) {
        expect(layout(width).trailing, parts, reason: '$width');
      }
      for (final (width, parts) in [
        (500.0, {TrackerTrailing.speed, TrackerTrailing.exit}),
        (400.0, {TrackerTrailing.speed}),
        (373.0, <TrackerTrailing>{}),
      ]) {
        expect(layout(width, live: true).trailing, parts, reason: '$width');
      }
      // A mark beside the host takes from what trails, not from the host.
      expect(layout(400, marksWidth: 30, live: true).trailing, isEmpty);
    });

    test('a short name leaves its room to the host and what trails', () {
      expect(layout(400).trailing, {
        TrackerTrailing.exit,
        TrackerTrailing.note,
      });
      final long = layout(400, process: 100);
      expect(long.processWidth, 100);
      expect(long.trailing, {TrackerTrailing.exit});
      expect(layout(400, process: null).trailing, {
        TrackerTrailing.exit,
        TrackerTrailing.note,
      });
    });

    test('only a row too narrow for both shrinks the name, then the host, '
        'and drops the name last', () {
      // The name and the host share what is past 52 of padding and icon.
      expect(layout(146, process: 30).processWidth, 30);
      expect(layout(140, process: 30).processWidth, closeTo(84 * 30 / 90, .01));
      expect(layout(140, process: 30).trailing, isEmpty);
      expect(layout(90, process: 30).processWidth, isNull);
    });
  });

  test('speeds read whole numbers in the larger one\'s unit', () {
    expect(trackerCompactSpeeds(2048, 14336), ('2', '14', 'KB/s'));
    expect(trackerCompactSpeeds(0, 12288), ('0', '12', 'KB/s'));
    expect(trackerCompactSpeeds(100, 900), ('100', '900', 'B/s'));
    expect(trackerCompactSpeeds(300, 1024 * 1024), ('<1', '1', 'MB/s'));
    expect(trackerCompactSpeeds(1024 * 999.4, 0), ('999', '0', 'KB/s'));
    expect(trackerCompactSpeeds(1024 * 999.5, 0), ('1', '0', 'MB/s'));
    expect(trackerCompactSpeeds(1000, 10), ('1', '<1', 'KB/s'));
  });

  Future<List<RecordFilter>> pump(
    WidgetTester tester,
    TrackerInfo info, {
    bool isLive = false,
    double width = 360,
    double textScale = 1,
    String? process,
    bool boldText = false,
    Locale? locale,
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
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(boldText: boldText);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      TestApp(
        locale: locale,
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

    expect(find.byType(TrackerProcessFilter), findsOneWidget);
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
      tester.getRect(find.byType(ProcessIcon)).right,
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
            // Nothing trails a host cut short of its readable start.
            final context = tester.element(find.byType(TrackerCompactRow));
            expect(
              tester.getSize(host).width,
              greaterThanOrEqualTo(
                metrics.hostReadableWidthOf(
                      context,
                      'a-very-long-subdomain.example-cdn.com:443',
                      host: 'a-very-long-subdomain.example-cdn.com',
                      live: isLive,
                    ) -
                    0.5,
              ),
            );
          }
          expect(find.byType(TrackerProcessFilter), findsOneWidget);
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
    expect(find.byType(TrackerProcessFilter), findsOneWidget);
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
      inInclusiveRange(metrics.processMinWidth, (360 - 8 - 24) * 0.3),
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

  testWidgets('the icon and the exit filter without opening the detail, '
      'pressed anywhere up the row\'s height', (tester) async {
    final filters = await pump(tester, _info(), width: 600);
    final row = tester.getRect(find.byType(TrackerCompactRow));

    await tester.tap(find.byType(TrackerProcessFilter));
    await tester.pumpAndSettle();
    expect(filters, const [
      RecordFilter(RecordFacetKind.app, 'exe:/usr/bin/ssh'),
    ]);
    expect(find.byType(TrackerInfoDetailView), findsNothing);

    await tester.tap(exitChip);
    await tester.pumpAndSettle();
    expect(filters.last, const RecordFilter(RecordFacetKind.proxy, 'DIRECT'));
    expect(find.byType(TrackerInfoDetailView), findsNothing);

    // A near miss, above or below either, still filters.
    final icon = tester.getRect(find.byType(ProcessIcon));
    final chip = tester.getRect(exitChip);
    expect(chip.height, lessThan(row.height - 20));
    await tester.tapAt(Offset(icon.center.dx, row.top + 3));
    await tester.tapAt(Offset(chip.center.dx, row.bottom - 3));
    // Beside the icon too, over the start padding and the gap after it.
    await tester.tapAt(Offset(row.left + 4 + 2, row.center.dy));
    await tester.tapAt(Offset(icon.right + 2, row.center.dy));
    await tester.pumpAndSettle();
    expect(filters, hasLength(6));
    expect(filters[2].kind, RecordFacetKind.app);
    expect(filters[3].kind, RecordFacetKind.proxy);
    expect(filters[4].kind, RecordFacetKind.app);
    expect(filters[5].kind, RecordFacetKind.app);
    expect(find.byType(TrackerInfoDetailView), findsNothing);

    await tester.tap(find.text('example.com:443'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackerInfoDetailView), findsOneWidget);
    expect(filters, hasLength(6));
  });

  testWidgets('a short name leaves its room to the host, and the host reads '
      'its start whole before anything trails it', (tester) async {
    const target = 'www.example.com:443';
    final info = _info(
      host: 'www.example.com',
      uploadSpeed: 1,
      downloadSpeed: 1,
    );
    // In the test font www.exampl… reads 165 and the speeds 175: only the
    // short name leaves room for them.
    await pump(tester, info, isLive: true, width: 500);
    final context = tester.element(find.byType(TrackerCompactRow));
    final readable = TrackerCompactMetrics.of(
      context,
    ).hostReadableWidthOf(context, target, host: 'www.example.com', live: true);
    final short = tester.getRect(find.text(target));
    expect(shows(speeds), isTrue);
    expect(short.width, greaterThanOrEqualTo(readable - 0.5));

    await pump(tester, info, isLive: true, width: 500, process: 'ssh-agent');
    final long = tester.getRect(find.text(target));
    expect(long.left, greaterThan(short.left));
    expect(shows(speeds), isFalse);
    expect(long.width, greaterThanOrEqualTo(readable - 0.5));
  });

  testWidgets('an Android app without an icon shows the fallback glyph, which '
      'filters', (tester) async {
    final filters = <RecordFilter>[];
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => HostScaffold(body: child),
        child: RecordFilterScope(
          onFilter: filters.add,
          child: const Row(
            children: [
              TrackerPackageIcon(packageName: 'com.example', targetHeight: 48),
              TrackerPackageIcon(packageName: '', targetHeight: 48),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ProcessGlyphWell), findsOneWidget);
    await tester.tap(find.byType(ProcessGlyphWell));
    expect(filters, const [RecordFilter(RecordFacetKind.app, 'com.example')]);
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

  SemanticsNode rowNode(WidgetTester tester) => tester.getSemantics(
    find
        .descendant(
          of: find.byType(TrackerCompactRow),
          matching: find.byType(CardSurface),
        )
        .first,
  );

  testWidgets('a screen reader hears the target, marks and exit on the node '
      'that opens the detail, and no speed', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      _info(uploadSpeed: 2048, downloadSpeed: 4096),
      isLive: true,
      width: 600,
    );

    final row = rowNode(tester);
    expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(row.label, contains('example.com:443'));
    expect(row.label, contains('Exit DIRECT'));
    expect(row.label, contains('ssh'));
    expect(row.label, isNot(contains('/s')));
    expect(find.bySemanticsLabel(RegExp(r'/s')), findsNothing);

    tester.semantics.tap(find.semantics.byLabel(row.label));
    await tester.pumpAndSettle();
    expect(find.byType(TrackerInfoDetailView), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a decrypted, rewritten row names each once', (tester) async {
    final semantics = tester.ensureSemantics();
    final info = _info().copyWith(
      metadata: _info().metadata.copyWith(mitm: true),
      mitmRewrite: const MitmConnectionRewrite(applied: true),
    );
    await pump(tester, info, width: 600);
    final context = tester.element(find.byType(TrackerCompactRow));
    final decrypted = MitmBadge.of(info)!.semanticsLabel(context);
    final rewritten = MitmRewriteBadge.of(info)!.semanticsLabel(context);

    final label = rowNode(tester).label;
    expect(decrypted.allMatches(label), hasLength(1));
    expect(rewritten.allMatches(label), hasLength(1));
    expect(find.bySemanticsLabel(decrypted), findsNothing);
    expect(find.bySemanticsLabel(rewritten), findsNothing);
    semantics.dispose();
  });

  testWidgets('the exit is a button to a screen reader that names its node '
      'and filters by it', (tester) async {
    final semantics = tester.ensureSemantics();
    final filters = await pump(tester, _info(), width: 600);

    final exit = tester.getSemantics(
      find.ancestor(of: exitChip, matching: find.byType(Semantics)).first,
    );
    expect(exit.label, 'Filter by this node, DIRECT');
    expect(exit.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel(exit.label));
    await tester.pumpAndSettle();
    expect(filters, const [RecordFilter(RecordFacetKind.proxy, 'DIRECT')]);
    expect(find.byType(TrackerInfoDetailView), findsNothing);
    semantics.dispose();
  });

  testWidgets('outside a filtered list the exit offers no filter', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => HostScaffold(body: child),
        child: SizedBox(
          width: 600,
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

    expect(exitChip, findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Filter by this node')), findsNothing);
    expect(rowNode(tester).label, contains('Exit DIRECT'));
    semantics.dispose();
  });

  TrackerCompactMetrics metricsOf(WidgetTester tester) =>
      TrackerCompactMetrics.of(tester.element(find.byType(TrackerCompactRow)));

  bool cutShort(WidgetTester tester, Finder text) =>
      tester.renderObject<RenderParagraph>(text).didExceedMaxLines;

  testWidgets('under Bold Text widths are measured again, bold, so a name '
      'reads whole', (tester) async {
    await pump(tester, _info(), width: 600);
    final regular = metricsOf(tester);

    await pump(tester, _info(), width: 600, boldText: true);
    final context = tester.element(find.byType(TrackerCompactRow));
    final bold = metricsOf(tester);
    expect(bold, isNot(same(regular)));
    // The test font sets bold as wide as regular, so this holds the layout
    // to what Text draws; the wider bold itself was checked on real fonts.
    expect(cutShort(tester, find.text('ssh')), isFalse);
    expect(
      tester.getSize(find.text('ssh')).width,
      lessThanOrEqualTo(bold.processWidthOf(context, 'ssh')),
    );
    expect(find.widgetWithText(TonalChip, 'DIRECT'), findsOneWidget);
    expect(
      tester.getSize(find.text('example.com:443')).width,
      greaterThanOrEqualTo(
        bold.hostReadableWidthOf(
          context,
          'example.com:443',
          host: 'example.com',
        ),
      ),
    );
  });

  testWidgets('widths round up to whole points, so a name never ellipsizes '
      'in the width it was measured at', (tester) async {
    await pump(tester, _info(), width: 600, textScale: 1.15);
    final metrics = metricsOf(tester);
    final width = metrics.processWidthOf(
      tester.element(find.byType(TrackerCompactRow)),
      'ssh',
    );
    expect(width, width.ceilToDouble());
    expect(width, greaterThan(tester.getSize(find.text('ssh')).width - 1));
    expect(cutShort(tester, find.text('ssh')), isFalse);
  });

  testWidgets('widths are measured again in another language', (tester) async {
    await pump(tester, _info(), locale: const Locale('en'));
    final english = metricsOf(tester);
    await pump(tester, _info(), locale: const Locale('ja'));
    expect(metricsOf(tester), isNot(same(english)));
  });

  testWidgets('a running host holds its width as the speeds change', (
    tester,
  ) async {
    Future<Rect> hostAt(int speed) async {
      await pump(
        tester,
        _info(
          host: 'www.example.com',
          uploadSpeed: speed,
          downloadSpeed: speed,
        ),
        isLive: true,
        width: 500,
      );
      expect(shows(speeds), isTrue);
      return tester.getRect(find.byType(MitmHostLine));
    }

    final idle = await hostAt(0);
    expect(await hostAt(1024 * 1024 * 900), idle);
  });

  testWidgets('a name or host cut short ends at its ellipsis, the rest given '
      'to what follows it', (tester) async {
    final info = _info(
      host: 'a-very-long-subdomain.example-cdn.com',
    ).copyWith(mitmRewrite: const MitmConnectionRewrite(applied: true));
    await pump(
      tester,
      info,
      process: 'com.example.very-long-helper-process-name',
    );
    final name = find.text('com.example.very-long-helper-process-name');
    final host = find.text('a-very-long-subdomain.example-cdn.com:443');
    expect(cutShort(tester, name), isTrue);
    expect(cutShort(tester, host), isTrue);
    // Test-font glyphs are an em wide: a line ending at its ellipsis is too.
    final metrics = metricsOf(tester);
    final nameWidth = tester.getSize(name).width;
    expect(nameWidth % metrics.process.fontSize!, 0);
    expect(nameWidth, lessThan((360 - 24) * 0.3));
    expect(tester.getSize(host).width % metrics.host.fontSize!, 0);
    final hostRect = tester.getRect(host);
    expect(hostRect.left - tester.getRect(name).right, 4);
    expect(
      tester.getRect(find.byType(MitmRewriteIcon)).left - hostRect.right,
      MitmBadge.gap,
    );
  });

  testWidgets('a recent row\'s summary names its network or route reason', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, _info(), width: 600);
    expect(rowNode(tester).label, 'ssh, example.com:443, TCP, Exit DIRECT');

    await pump(tester, _info(rule: '', routeReason: 'no-rule-matched'));
    final context = tester.element(find.byType(TrackerCompactRow));
    final reason = trackerCompactNote(
      context,
      _info(rule: '', routeReason: 'no-rule-matched'),
    );
    expect(reason, isNot('TCP'));
    expect(rowNode(tester).label, contains(reason));
    semantics.dispose();
  });

  group('the process', () {
    const long = 'com.example.very-long-helper-process-name';
    final processFilter = find.byType(TrackerProcessFilter);

    testWidgets('its icon and name are one press that filters by the whole '
        'process, the name cut short or not, and leave the host to the '
        'detail', (tester) async {
      final filters = await pump(tester, _info(), process: long);
      final name = find.text(long);
      expect(
        tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
        isTrue,
      );
      final target = tester.getRect(processFilter);
      final host = tester.getRect(find.text('example.com:443'));
      expect(target.right, lessThanOrEqualTo(host.left));
      expect(
        target.contains(tester.getRect(find.byType(ProcessIcon)).center),
        isTrue,
      );

      await tester.tap(name);
      await tester.pumpAndSettle();
      expect(filters, const [
        RecordFilter(RecordFacetKind.app, 'exe:/usr/local/bin/$long'),
      ]);
      expect(find.byType(TrackerInfoDetailView), findsNothing);

      // Between the name and the host the row opens the detail again.
      await tester.tapAt(Offset(host.left - 1, host.center.dy));
      await tester.pumpAndSettle();
      expect(find.byType(TrackerInfoDetailView), findsOneWidget);
      expect(filters, hasLength(1));
    });

    testWidgets('it is a button to a screen reader that names the process '
        'and filters by it, as the exit is', (tester) async {
      final semantics = tester.ensureSemantics();
      final filters = await pump(tester, _info(), width: 600);

      final node = tester.getSemantics(
        find
            .ancestor(
              of: find.byType(ProcessIcon),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.label, 'Filter by this process, ssh');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      tester.semantics.tap(find.semantics.byLabel(node.label));
      await tester.pumpAndSettle();
      expect(filters, const [
        RecordFilter(RecordFacetKind.app, 'exe:/usr/bin/ssh'),
      ]);
      expect(find.byType(TrackerInfoDetailView), findsNothing);
      // The row's own summary still names it.
      expect(rowNode(tester).label, startsWith('ssh, '));
      semantics.dispose();
    });

    testWidgets('a key press filters by it once it has the focus', (
      tester,
    ) async {
      final filters = await pump(tester, _info(), width: 600);

      Focus.of(tester.element(find.byType(ProcessIcon))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(filters, const [
        RecordFilter(RecordFacetKind.app, 'exe:/usr/bin/ssh'),
      ]);
      expect(find.byType(TrackerInfoDetailView), findsNothing);
    });

    testWidgets('an unknown process offers no filter, and its room opens the '
        'detail', (tester) async {
      final semantics = tester.ensureSemantics();
      final info = _info();
      final filters = await pump(
        tester,
        info.copyWith(
          metadata: info.metadata.copyWith(process: '', processPath: ''),
        ),
        width: 600,
      );

      expect(processFilter, findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Filter by this (app|process)')),
        findsNothing,
      );
      await tester.tapAt(tester.getRect(find.byType(ProcessIcon)).center);
      await tester.pumpAndSettle();
      expect(filters, isEmpty);
      expect(find.byType(TrackerInfoDetailView), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('outside a filtered list it offers no filter', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          homeBuilder: (child) => HostScaffold(body: child),
          child: SizedBox(
            width: 600,
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

      expect(processFilter, findsNothing);
      expect(find.text('ssh'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Filter by this process')),
        findsNothing,
      );
      semantics.dispose();
    });
  });
}
