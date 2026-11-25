import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/core_connections.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

TrackerInfo _tracker({
  required String id,
  String host = 'example.com',
  String process = 'curl',
  List<String> chains = const ['Proxy'],
  int upload = 0,
  int download = 0,
  DateTime? start,
  bool mitm = false,
  String rule = 'DOMAIN',
  String? rulePayload,
  String destinationPort = '443',
}) {
  return TrackerInfo(
    id: id,
    upload: upload,
    download: download,
    start: start ?? DateTime.utc(2026),
    metadata: Metadata(
      network: 'tcp',
      host: host,
      destinationIP: '1.1.1.1',
      destinationPort: destinationPort,
      process: process,
      mitm: mitm,
    ),
    chains: chains,
    rule: rule,
    rulePayload: rulePayload ?? host,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCoreHandlerInterface core;
  late ProviderContainer container;

  setUpAll(() {
    core = MockCoreHandlerInterface();
  });

  setUp(() {
    reset(core);
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

  Future<void> pumpConnections(
    WidgetTester tester, {
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
  }

  Future<void> pumpSettled(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(commonDuration);
  }

  Future<void> teardownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('shows the empty state when core reports no connections', (
    tester,
  ) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => const <TrackerInfo>[],
    );

    await pumpConnections(tester);

    expect(find.byType(NullStatus), findsOneWidget);
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('shows nothing until core answers, then its rows at once', (
    tester,
  ) async {
    final pending = Completer<List<TrackerInfo>>();
    whenConnections<RankedTrackerInfos>(core, () => pending.future);

    await pumpConnections(tester);
    expect(find.byType(NullStatus), findsNothing);
    expect(find.textContaining('alpha.test'), findsNothing);

    pending.complete([_tracker(id: 'a', host: 'alpha.test')]);
    await tester.pump();
    await tester.pump();

    expect(find.byType(NullStatus), findsNothing);
    expect(find.textContaining('alpha.test'), findsWidgets);
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('opens at once behind a spinner, then shows its first '
      'connections', (tester) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [_tracker(id: 'a', host: 'alpha.test')],
    );
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                HostPageRoute<void>(
                  builder: (_) =>
                      const RequestsView(initialFeed: RequestFeed.live),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    final route = ModalRoute.of(tester.element(find.byType(RequestsView)))!;
    expect(route.animation!.isAnimating, isTrue);
    expect(find.byType(ActivityIndicator), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('alpha.test'), findsWidgets);

    await teardownView(tester);
  });

  testWidgets('renders one row per reported connection', (tester) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [
        _tracker(id: 'a', host: 'alpha.test'),
        _tracker(id: 'b', host: 'beta.test'),
      ],
    );

    await pumpConnections(tester);
    await pumpSettled(tester);

    expect(find.byType(NullStatus), findsNothing);
    expect(find.textContaining('alpha.test'), findsWidgets);
    expect(find.textContaining('beta.test'), findsWidgets);
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('orders rows by total traffic, then newest first', (
    tester,
  ) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [
        _tracker(id: 'a', host: 'alpha.test', download: 100),
        _tracker(id: 'b', host: 'beta.test', upload: 300, download: 300),
        _tracker(
          id: 'c',
          host: 'gamma.test',
          download: 100,
          start: DateTime.utc(2026, 2),
        ),
      ],
    );

    await pumpConnections(tester);
    await pumpSettled(tester);

    double topOf(String host) =>
        tester.getTopLeft(find.textContaining(host).first).dy;
    expect(topOf('beta.test'), lessThan(topOf('gamma.test')));
    expect(topOf('gamma.test'), lessThan(topOf('alpha.test')));
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('a wide page lays the connections out as a table and closes '
      'a row from its menu', (tester) async {
    var connections = [
      _tracker(id: 'a', host: 'alpha.test', chains: const ['Tokyo', 'Proxy']),
      _tracker(id: 'b', host: 'beta.test'),
    ];
    whenConnections<RankedTrackerInfos>(core, () async => connections);
    when(() => core.closeConnection(any())).thenAnswer((_) async {});

    await pumpConnections(tester);
    await pumpSettled(tester);

    for (final label in [
      'Process',
      'Target',
      'Protocol',
      'Rule',
      'Exit',
      'Download',
      'Upload',
      'Downloaded',
      'Uploaded',
      'Duration',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(TrackerInfoTableRow), findsNWidgets(2));
    expect(find.byType(Divider), findsNothing);
    expect(
      tester
          .widgetList<TrackerInfoTableRow>(find.byType(TrackerInfoTableRow))
          .map((row) => row.striped)
          .toSet(),
      {true, false},
    );
    expect(find.text('Tokyo'), findsOneWidget);

    await tester.longPress(find.textContaining('alpha.test').first);
    await tester.pumpAndSettle();
    connections = [connections.last];
    await tester.tap(find.text('Close connection'));
    await tester.pumpAndSettle();

    verify(() => core.closeConnection('a')).called(1);
    expect(find.textContaining('alpha.test'), findsNothing);
    expect(find.textContaining('beta.test'), findsWidgets);
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('a live table keeps the totals ahead of protocol and duration', (
    tester,
  ) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [
        _tracker(id: 'a', host: 'alpha.test', upload: 512, download: 1536),
      ],
    );

    await pumpConnections(tester, width: 1100);
    await pumpSettled(tester);

    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Uploaded'), findsOneWidget);
    expect(find.text('1.5KB'), findsOneWidget);
    expect(find.text('512B'), findsOneWidget);
    expect(find.text('Protocol'), findsNothing);
    expect(find.text('Duration'), findsNothing);

    tester.view.physicalSize = const Size(900, 1000);
    await tester.pump();

    expect(find.text('Traffic'), findsOneWidget);
    expect(find.text('2KB'), findsOneWidget);
    expect(find.text('Downloaded'), findsNothing);
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('a table marks a decrypted connection in its target', (
    tester,
  ) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [
        _tracker(id: 'a', host: 'alpha.test', mitm: true),
        _tracker(id: 'b', host: 'beta.test'),
      ],
    );

    await pumpConnections(tester, width: 900);
    await pumpSettled(tester);

    expect(find.byType(TrackerInfoTableRow), findsNWidgets(2));
    final label = find.byGlyph(MitmBadge.decrypted.glyph);
    expect(label, findsOneWidget);
    expect(
      find.ancestor(
        of: label,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is TrackerTargetText && widget.trackerInfo.id == 'a',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('a sorted table keeps its order across polls', (tester) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [
        _tracker(id: 'a', host: 'alpha.test', process: 'zsh', download: 300),
        _tracker(id: 'b', host: 'beta.test', process: 'curl', download: 200),
        _tracker(id: 'c', host: 'gamma.test', process: 'make', download: 100),
      ],
    );

    await pumpConnections(tester);
    await pumpSettled(tester);

    double topOf(String host) =>
        tester.getTopLeft(find.textContaining(host).first).dy;
    expect(topOf('alpha.test'), lessThan(topOf('beta.test')));

    await tester.tap(find.text('Process'));
    await tester.pumpAndSettle();
    expect(topOf('beta.test'), lessThan(topOf('gamma.test')));
    expect(topOf('gamma.test'), lessThan(topOf('alpha.test')));

    await pumpSettled(tester);
    expect(topOf('beta.test'), lessThan(topOf('gamma.test')));
    expect(topOf('gamma.test'), lessThan(topOf('alpha.test')));

    await teardownView(tester);
  });

  testWidgets('over a long list a search runs at once, then at most once '
      'per interval with the last query typed', (tester) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [
        _tracker(id: 'needle', host: 'needle.test', download: 1),
        _tracker(id: 'pin', host: 'pin.test', download: 2),
        for (var i = 0; i < throttledSearchLength; i++)
          _tracker(id: 'c$i', host: 'h$i.test', download: 1000 + i),
      ],
    );

    await pumpConnections(tester);
    await pumpSettled(tester);
    expect(find.textContaining('needle.test'), findsNothing);

    await tester.tap(find.byGlyph(AppGlyphs.search));
    await tester.pump(commonDuration);
    await tester.pump(commonDuration);
    // The first keystroke after a pause is searched at once.
    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pump();
    expect(find.byType(TrackerInfoTableRow), findsOneWidget);
    expect(find.textContaining('needle.test'), findsWidgets);

    // Within the interval only the last query typed is kept, for its end.
    await tester.enterText(find.byType(TextField), 'p');
    await tester.enterText(find.byType(TextField), 'pin');
    await tester.pump(searchThrottle ~/ 2);
    expect(find.textContaining('needle.test'), findsWidgets);
    expect(find.textContaining('pin.test'), findsNothing);

    await tester.pump(searchThrottle);
    await tester.pump();
    await pumpSettled(tester);
    expect(find.byType(TrackerInfoTableRow), findsOneWidget);
    expect(find.textContaining('pin.test'), findsWidgets);

    // Clearing the query is never held back, and drops a query kept for the
    // end of the interval.
    await tester.enterText(find.byType(TextField), 'h1');
    await tester.enterText(find.byType(TextField), 'pin');
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.pump();
    expect(find.byType(TrackerInfoTableRow).evaluate().length, greaterThan(1));
    await pumpSettled(tester);
    expect(find.byType(TrackerInfoTableRow).evaluate().length, greaterThan(1));

    await teardownView(tester);
  });

  testWidgets('a kept table cell follows a change of only the exit, the '
      'rule or one metadata field', (tester) async {
    var row = _tracker(id: 'a', host: 'a.test', rulePayload: 'p.test');
    whenConnections<RankedTrackerInfos>(core, () async => [row]);
    await pumpConnections(tester);
    await pumpSettled(tester);
    expect(find.text('Proxy'), findsOneWidget);
    expect(find.text('curl'), findsWidgets);

    Future<void> poll(TrackerInfo next) async {
      row = next;
      await pumpSettled(tester);
    }

    await poll(row.copyWith(chains: const ['Backup', 'Proxy']));
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Proxy'), findsNothing);

    await poll(row.copyWith(rule: 'GEOSITE', rulePayload: 'cn'));
    expect(
      find.textContaining('GEOSITE cn', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('DOMAIN', findRichText: true), findsNothing);

    await poll(row.copyWith(metadata: row.metadata.copyWith(process: 'wget')));
    expect(find.text('wget'), findsWidgets);
    expect(find.text('curl'), findsNothing);

    await poll(
      row.copyWith(metadata: row.metadata.copyWith(host: 'moved.test')),
    );
    expect(find.textContaining('moved.test'), findsWidgets);
    expect(find.textContaining('a.test'), findsNothing);

    await teardownView(tester);
  });

  testWidgets('kept table cells follow a theme and a locale switch', (
    tester,
  ) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [_tracker(id: 'a', process: '', download: 1)],
    );
    final look = ValueNotifier((const Locale('en'), ThemeMode.light));
    addTearDown(look.dispose);
    addTearDown(() => loadAppLocalizations(const Locale('en')));
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ValueListenableBuilder(
          valueListenable: look,
          builder: (_, look, _) => Consumer(
            builder: (_, ref, _) => TestApp(
              locale: look.$1,
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: look.$2,
              child: const RequestsView(initialFeed: RequestFeed.live),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await pumpSettled(tester);

    Color? colorOf(Finder cell) => tester
        .widget<RichText>(
          find.descendant(of: cell, matching: find.byType(RichText)).first,
        )
        .text
        .style
        ?.color;
    final time = find.byType(RecordCellText).first;
    final light = colorOf(time);
    expect(find.text('Unknown process'), findsWidgets);

    look.value = (const Locale('en'), ThemeMode.dark);
    await pumpSettled(tester);
    expect(colorOf(time), isNot(light));

    look.value = (const Locale('zh'), ThemeMode.dark);
    await pumpSettled(tester);
    expect(find.text('未知进程'), findsWidgets);
    expect(find.text('Unknown process'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('over a long list the first key after a clear is searched at '
      'once, even within the interval', (tester) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [
        _tracker(id: 'needle', host: 'needle.test', download: 1),
        _tracker(id: 'pin', host: 'pin.test', download: 2),
        for (var i = 0; i < throttledSearchLength; i++)
          _tracker(id: 'c$i', host: 'h$i.test', download: 1000 + i),
      ],
    );
    await pumpConnections(tester);
    await pumpSettled(tester);
    await tester.tap(find.byGlyph(AppGlyphs.search));
    await tester.pump(commonDuration);
    await tester.pump(commonDuration);

    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(searchThrottle ~/ 3);
    await tester.enterText(find.byType(TextField), 'pin');
    await tester.pump();
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TrackerInfoTableRow && widget.trackerInfo.id == 'pin',
      ),
      findsOneWidget,
    );

    await teardownView(tester);
  });

  testWidgets('a query kept for the end of the interval is dropped with the '
      'view', (tester) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [
        for (var i = 0; i < throttledSearchLength; i++)
          _tracker(id: 'c$i', host: 'h$i.test', download: 1000 + i),
      ],
    );
    await pumpConnections(tester);
    await pumpSettled(tester);
    await tester.tap(find.byGlyph(AppGlyphs.search));
    await tester.pump(commonDuration);
    await tester.pump(commonDuration);

    await tester.enterText(find.byType(TextField), 'h1');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'h12');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(searchThrottle * 2);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('shows the read failure, never the empty state, when core '
      'throws before any read succeeded', (tester) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => throw StateError('core down'),
    );

    await pumpConnections(tester);

    final l10n = currentAppLocalizations;
    expect(find.byType(NullStatus), findsOneWidget);
    expect(find.text(l10n.connectionsReadFailed), findsOneWidget);
    expect(find.text(l10n.nullTip(l10n.connections)), findsNothing);
    expect(find.textContaining('core down'), findsNothing);
    expect(tester.takeException(), null);

    await teardownView(tester);
  });

  testWidgets('stops polling once the view is disposed', (tester) async {
    whenConnections<RankedTrackerInfos>(
      core,
      () async => const <TrackerInfo>[],
    );

    await pumpConnections(tester);
    await teardownView(tester);
    clearInteractions(core);

    await tester.pump(const Duration(seconds: 3));

    verifyNever(() => core.getConnectionsWith<RankedTrackerInfos>(any()));
  });

  testWidgets('one page switches between recent requests and what is open, '
      'polling only for the latter', (tester) async {
    final requests = container.read(requestsProvider.notifier);
    requests.value = FixedList<TrackerInfo>(500);
    requests.addRequest(_tracker(id: 'old', host: 'finished.test'));
    whenConnections<RankedTrackerInfos>(
      core,
      () async => [_tracker(id: 'open', host: 'open.test')],
    );
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          child: RequestsView(initialFeed: RequestFeed.recent),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('finished.test'), findsWidgets);
    expect(find.byTooltip('Close connections'), findsNothing);
    verifyNever(() => core.getConnectionsWith<RankedTrackerInfos>(any()));

    await tester.tap(find.text('Recent requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('open.test'), findsWidgets);
    expect(find.textContaining('finished.test'), findsNothing);
    expect(find.byTooltip('Close connections'), findsOneWidget);

    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recent requests'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    clearInteractions(core);
    await tester.pump(const Duration(seconds: 3));

    expect(find.textContaining('finished.test'), findsWidgets);
    verifyNever(() => core.getConnectionsWith<RankedTrackerInfos>(any()));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  group('read failures', () {
    late List<String> announced;
    late Future<List<TrackerInfo>> Function() reader;
    var reads = 0;

    setUp(() {
      announced = [];
      reads = 0;
      reader = () async => const <TrackerInfo>[];
      whenConnections<RankedTrackerInfos>(core, () {
        reads++;
        return reader();
      });
    });

    Future<void> pumpAnnounced(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message as Map<Object?, Object?>;
            if (map['type'] == 'announce') {
              final data = map['data'] as Map<Object?, Object?>;
              announced.add(data['message'] as String);
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await pumpConnections(tester);
    }

    Future<void> nextPoll(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(commonDuration);
    }

    Finder banner() => find.byType(ReadFailureBanner);
    Finder retryButton() => find.text(currentAppLocalizations.retry);

    /// Every fade above the first row, and the colors its text paints in:
    /// stale rows must look exactly like live ones.
    (List<double>, List<Color?>) rowsLook(WidgetTester tester) {
      final row = find.textContaining('alpha.test').first;
      final fades = [
        for (final opacity in tester.widgetList<Opacity>(
          find.ancestor(of: row, matching: find.byType(Opacity)),
        ))
          opacity.opacity,
        for (final opacity in tester.widgetList<AnimatedOpacity>(
          find.ancestor(of: row, matching: find.byType(AnimatedOpacity)),
        ))
          opacity.opacity,
      ];
      final colors = <Color?>[];
      for (final text in tester.widgetList<RichText>(
        find.descendant(
          of: find
              .ancestor(
                of: row,
                matching: find.byType(RecordTableFrame<TrackerInfo>),
              )
              .first,
          matching: find.byType(RichText),
        ),
      )) {
        text.text.visitChildren((span) {
          colors.add(span.style?.color);
          return true;
        });
        colors.add(text.text.style?.color);
      }
      return (fades, colors);
    }

    testWidgets('a first failure retries in place, once however often it is '
        'tapped, then a successful empty read is the normal empty state', (
      tester,
    ) async {
      final l10n = currentAppLocalizations;
      reader = () async => throw StateError('down');
      await pumpAnnounced(tester);
      await tester.pump(commonDuration);

      expect(find.text(l10n.connectionsReadFailed), findsOneWidget);
      expect(find.text(l10n.connectionsReadFailedDesc), findsOneWidget);
      expect(find.text(l10n.nullTip(l10n.connections)), findsNothing);
      expect(banner(), findsNothing);
      expect(announced, [l10n.connectionsReadFailed]);

      // Polls that keep failing say nothing more.
      await nextPoll(tester);
      await nextPoll(tester);
      expect(announced, [l10n.connectionsReadFailed]);

      final pending = Completer<List<TrackerInfo>>();
      reader = () => pending.future;
      final before = reads;
      await tester.tap(retryButton());
      await tester.pump();
      expect(find.text(l10n.retrying), findsOneWidget);
      expect(tester.widget<RetryButton>(find.byType(RetryButton)).busy, isTrue);
      await tester.tap(find.byType(RetryLabel), warnIfMissed: false);
      await tester.pump();
      expect(reads, before + 1);

      pending.complete(const []);
      await tester.pump();
      await tester.pump(commonDuration);
      await tester.pump(commonDuration);
      expect(find.text(l10n.connectionsReadFailed), findsNothing);
      expect(find.text(l10n.nullTip(l10n.connections)), findsOneWidget);
      expect(banner(), findsNothing);
      expect(announced, [
        l10n.connectionsReadFailed,
        l10n.connectionsRefreshed,
      ]);
      expect(tester.takeException(), null);

      await teardownView(tester);
    });

    testWidgets('a failure after rows keeps them, stale, under a hint that '
        'goes once a read succeeds', (tester) async {
      final l10n = currentAppLocalizations;
      reader = () async => [_tracker(id: 'a', host: 'alpha.test')];
      await pumpAnnounced(tester);
      await nextPoll(tester);
      final live = rowsLook(tester);
      expect(live.$1, everyElement(1.0));

      reader = () async => throw StateError('down');
      await nextPoll(tester);
      expect(banner(), findsOneWidget);
      expect(find.text(l10n.connectionsRefreshFailedStale), findsOneWidget);
      expect(find.textContaining('alpha.test'), findsWidgets);
      // The banner alone says the rows are stale: no dimming, no recolouring.
      final stale = rowsLook(tester);
      expect(stale.$1, everyElement(1.0));
      expect(stale.$2, live.$2);
      // The hint takes room of its own instead of covering the rows.
      final bannerBottom = tester.getBottomLeft(banner()).dy;
      expect(
        tester.getTopLeft(find.textContaining('alpha.test').first).dy,
        greaterThanOrEqualTo(bannerBottom),
      );

      // Failing again keeps one hint and says nothing more.
      await nextPoll(tester);
      expect(banner(), findsOneWidget);
      expect(announced, [l10n.connectionsRefreshFailedStale]);

      reader = () async => [
        _tracker(id: 'a', host: 'alpha.test'),
        _tracker(id: 'b', host: 'beta.test'),
      ];
      await nextPoll(tester);
      await tester.pump(commonDuration);
      expect(banner(), findsNothing);
      expect(find.textContaining('beta.test'), findsWidgets);
      expect(rowsLook(tester).$1, everyElement(1.0));
      expect(announced, [
        l10n.connectionsRefreshFailedStale,
        l10n.connectionsRefreshed,
      ]);
      expect(tester.takeException(), null);

      await teardownView(tester);
    });

    testWidgets('recovery is announced once per error-to-success '
        'transition, an empty result included, never on later successes', (
      tester,
    ) async {
      final l10n = currentAppLocalizations;
      await pumpAnnounced(tester);
      await nextPoll(tester);
      // Successful polls before any failure say nothing.
      await nextPoll(tester);
      expect(announced, isEmpty);

      reader = () async => throw StateError('down');
      await nextPoll(tester);
      await nextPoll(tester);
      expect(announced, [l10n.connectionsRefreshFailedStale]);

      // Recovering to an empty result still says so, once.
      reader = () async => const <TrackerInfo>[];
      await nextPoll(tester);
      await nextPoll(tester);
      await nextPoll(tester);
      await nextPoll(tester);
      expect(banner(), findsNothing);
      expect(find.text(l10n.nullTip(l10n.connections)), findsOneWidget);
      expect(announced, [
        l10n.connectionsRefreshFailedStale,
        l10n.connectionsRefreshed,
      ]);

      // A second failure and recovery: one more of each, and no more.
      reader = () async => throw StateError('down');
      await nextPoll(tester);
      reader = () async => [_tracker(id: 'a', host: 'alpha.test')];
      await nextPoll(tester);
      await nextPoll(tester);
      await nextPoll(tester);
      expect(announced, [
        l10n.connectionsRefreshFailedStale,
        l10n.connectionsRefreshed,
        l10n.connectionsRefreshFailedStale,
        l10n.connectionsRefreshed,
      ]);
      expect(
        announced.where((message) => message == l10n.connectionsRefreshed),
        hasLength(2),
      );
      expect(tester.takeException(), null);

      await teardownView(tester);
    });

    testWidgets('retry from the hint runs one read and clears it', (
      tester,
    ) async {
      final l10n = currentAppLocalizations;
      reader = () async => [_tracker(id: 'a', host: 'alpha.test')];
      await pumpAnnounced(tester);
      await nextPoll(tester);
      reader = () async => throw StateError('down');
      await nextPoll(tester);
      expect(banner(), findsOneWidget);

      final pending = Completer<List<TrackerInfo>>();
      reader = () => pending.future;
      final before = reads;
      await tester.tap(retryButton());
      await tester.pump();
      expect(
        find.descendant(of: banner(), matching: find.text(l10n.retrying)),
        findsOneWidget,
      );
      await tester.tap(find.byType(RetryLabel), warnIfMissed: false);
      await tester.pump();
      expect(reads, before + 1);

      pending.complete([_tracker(id: 'a', host: 'alpha.test')]);
      await tester.pump();
      await tester.pump(commonDuration);
      expect(banner(), findsNothing);
      expect(find.textContaining('alpha.test'), findsWidgets);
      expect(tester.takeException(), null);

      await teardownView(tester);
    });

    testWidgets('polling waits while a retry reads, then carries on', (
      tester,
    ) async {
      reader = () async => [_tracker(id: 'a', host: 'alpha.test')];
      await pumpAnnounced(tester);
      await nextPoll(tester);
      reader = () async => throw StateError('down');
      await nextPoll(tester);
      expect(banner(), findsOneWidget);

      final pending = Completer<List<TrackerInfo>>();
      reader = () => pending.future;
      final before = reads;
      await tester.tap(retryButton());
      await tester.pump();
      for (var tick = 0; tick < 3; tick++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(reads, before + 1);

      pending.complete([_tracker(id: 'a', host: 'alpha.test')]);
      await tester.pump();
      await tester.pump(commonDuration);
      expect(banner(), findsNothing);
      reader = () async => [_tracker(id: 'a', host: 'alpha.test')];
      await nextPoll(tester);
      expect(reads, greaterThan(before + 1));
      expect(tester.takeException(), null);

      await teardownView(tester);
    });

    testWidgets('a read that fails after the page is gone touches nothing', (
      tester,
    ) async {
      reader = () async => [_tracker(id: 'a', host: 'alpha.test')];
      await pumpAnnounced(tester);
      await nextPoll(tester);

      final pending = Completer<List<TrackerInfo>>();
      reader = () => pending.future;
      await tester.pump(const Duration(seconds: 1));
      await teardownView(tester);
      // Polling swallows what a poll throws, saying so in the log.
      final printed = <String>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = print);
      pending.completeError(StateError('down'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      debugPrint = print;
      expect(printed.where((line) => line.contains('poll error')), isEmpty);
      expect(tester.takeException(), null);
    });

    testWidgets('a failure after an empty read keeps the empty state under '
        'the hint', (tester) async {
      final l10n = currentAppLocalizations;
      await pumpAnnounced(tester);
      await nextPoll(tester);
      expect(find.text(l10n.nullTip(l10n.connections)), findsOneWidget);

      reader = () async => throw StateError('down');
      await nextPoll(tester);
      expect(banner(), findsOneWidget);
      expect(find.text(l10n.nullTip(l10n.connections)), findsOneWidget);
      expect(find.text(l10n.connectionsReadFailed), findsNothing);
      expect(tester.takeException(), null);

      await teardownView(tester);
    });

    testWidgets('a stopped core is no connections, not a failure', (
      tester,
    ) async {
      final l10n = currentAppLocalizations;
      reader = () async => [_tracker(id: 'a', host: 'alpha.test')];
      await pumpAnnounced(tester);
      await nextPoll(tester);

      // The core stops under a read, which then throws.
      final pending = Completer<List<TrackerInfo>>();
      reader = () => pending.future;
      await tester.pump(const Duration(seconds: 1));
      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      pending.completeError(StateError('stopped'));
      await tester.pump();
      await nextPoll(tester);
      await nextPoll(tester);

      expect(banner(), findsNothing);
      expect(find.text(l10n.connectionsReadFailed), findsNothing);
      expect(find.text(l10n.nullTip(l10n.connections)), findsOneWidget);
      expect(announced, isEmpty);
      expect(tester.takeException(), null);

      await teardownView(tester);
    });

    testWidgets('an older read failing after a newer success shows no hint', (
      tester,
    ) async {
      when(() => core.closeConnections()).thenAnswer((_) async {});
      reader = () async => [_tracker(id: 'a', host: 'alpha.test')];
      await pumpAnnounced(tester);
      await nextPoll(tester);

      final slow = Completer<List<TrackerInfo>>();
      reader = () => slow.future;
      await tester.pump(const Duration(seconds: 1));
      reader = () async => [_tracker(id: 'b', host: 'beta.test')];
      await tester.tap(
        find.byTooltip(currentAppLocalizations.closeConnections),
      );
      await tester.pump();
      await tester.pump(commonDuration);
      expect(find.textContaining('beta.test'), findsWidgets);

      slow.completeError(StateError('late'));
      await tester.pump();
      await tester.pump(commonDuration);
      expect(banner(), findsNothing);
      expect(find.textContaining('beta.test'), findsWidgets);
      expect(tester.takeException(), null);

      await teardownView(tester);
    });

    testWidgets('leaving a failing page stops reading', (tester) async {
      reader = () async => throw StateError('down');
      await pumpAnnounced(tester);
      await nextPoll(tester);
      await teardownView(tester);
      final after = reads;

      await tester.pump(const Duration(seconds: 3));
      expect(reads, after);
      expect(tester.takeException(), null);
    });
  });
}
