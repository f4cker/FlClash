import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

const _chromePath =
    '/Applications/Example Browser.app/Contents/Frameworks/Helpers/'
    'Example Browser Helper.app/Contents/MacOS/Example Browser Helper';

TrackerInfo _info(Metadata metadata) => TrackerInfo(
  id: '1',
  start: DateTime(2026, 11, 12, 10, 30),
  metadata: metadata.copyWith(
    network: 'tcp',
    host: 'example.com',
    destinationPort: '443',
  ),
  chains: const ['DIRECT'],
  rule: 'MATCH',
  rulePayload: '',
);

final _app = _info(
  const Metadata(
    process: 'Example Browser Helper',
    processPath: _chromePath,
    sourceIP: '127.0.0.1',
    sourcePort: '51234',
  ),
);
final _core = _info(
  const Metadata(process: 'core-abc', processPath: '/core-fixture'),
);
final _cli = _info(
  const Metadata(
    process: 'ssh',
    processPath: '/usr/bin/ssh',
    sourceIP: '127.0.0.1',
    sourcePort: '50022',
  ),
);
final _unknown = _info(
  const Metadata(sourceIP: '198.18.0.1', sourcePort: '50100'),
);
final _remote = _info(
  const Metadata(
    type: 'HTTP',
    sourceIP: '192.168.1.20',
    sourcePort: '50200',
    inboundIP: '192.168.1.5',
  ),
);
const _apsd =
    '/System/Library/PrivateFrameworks/ApplePushService.framework/apsd';
const _daemon = '/Library/PrivilegedHelperTools/com.example.daemon';
final _push = _info(
  const Metadata(process: 'apsd', processPath: _apsd, sourcePort: '50300'),
);
final _downloads = _info(
  const Metadata(
    process: 'nsurlsessiond',
    processPath: '/usr/libexec/nsurlsessiond',
    sourcePort: '50400',
  ),
);
final _helper = _info(
  const Metadata(process: 'com.example.daemon', processPath: _daemon),
);
final _unreadable = _info(
  const Metadata(process: 'Gone', processPath: '/Applications/Gone.app/g'),
);

void main() {
  late ProcessApps previous;

  setUp(() {
    loadAppLocalizations(const Locale('en'));
    previous = processApps;
    processApps = ProcessApps(
      lookupApps: true,
      invoke: (_) async => null,
      readLocalAddresses: () async => {'127.0.0.1', '192.168.1.5'},
    );
    processApps.seed(
      lookups: {
        _chromePath: AppLookup.app(
          MacApp(
            bundleId: 'com.example.browser',
            name: 'Example Browser',
            bundlePath: '/Applications/Example Browser.app',
            icon: _pixel,
            isHelper: true,
          ),
        ),
        '/core-fixture': AppLookup.app(
          MacApp(
            bundleId: 'com.layoute.flash',
            name: 'Flash',
            bundlePath: '/Applications/Flash.app',
            icon: _pixel,
            isCore: true,
          ),
        ),
        '/usr/bin/ssh': AppLookup.none,
        '/Applications/Gone.app/g': AppLookup.unreadable,
        _apsd: AppLookup.service(
          ServiceMatch(SystemService.pushNotifications, icon: _pixel),
        ),
        '/usr/libexec/nsurlsessiond': const AppLookup.service(
          ServiceMatch(SystemService.backgroundDownloads),
        ),
        _daemon: AppLookup.app(
          MacApp(
            bundleId: 'com.example.app',
            name: 'Example',
            bundlePath: '/Applications/Example.app',
            icon: _pixel,
            launchdLabel: 'com.example.daemon',
            isHelper: true,
          ),
        ),
      },
      local: {'127.0.0.1', '192.168.1.5'},
    );
  });

  tearDown(() {
    processApps.dispose();
    processApps = previous;
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => HostScaffold(body: child),
        child: child,
      ),
    );
    await tester.pump();
  }

  group('list row', () {
    testWidgets('an app shows its icon and name and filters by bundle', (
      tester,
    ) async {
      final filters = <RecordFilter>[];
      await pump(
        tester,
        RecordFilterScope(
          onFilter: filters.add,
          child: TrackerInfoItem(trackerInfo: _app, detailTitle: 'detail'),
        ),
      );
      expect(
        find.text('Example Browser · Helper  ·  127.0.0.1:51234'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byType(ProcessFilterIcon));
      expect(filters, const [
        RecordFilter(RecordFacetKind.app, 'app:com.example.browser'),
      ]);
    });

    testWidgets('helper and core rows show badges and attributed names', (
      tester,
    ) async {
      await pump(
        tester,
        Column(
          children: [
            TrackerInfoItem(trackerInfo: _app, detailTitle: 'detail'),
            TrackerInfoItem(trackerInfo: _core, detailTitle: 'detail'),
          ],
        ),
      );
      expect(
        find.byKey(const ValueKey('process-kind-badge')),
        findsNWidgets(2),
      );
      expect(find.textContaining('Example Browser · Helper'), findsOneWidget);
      expect(find.textContaining('Flash · Core'), findsOneWidget);
    });

    testWidgets('table omits helper and core badges', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            ProcessCell(metadata: _app.metadata),
            ProcessCell(metadata: _core.metadata),
          ],
        ),
      );
      expect(find.byKey(const ValueKey('process-kind-badge')), findsNothing);
      expect(find.text('Flash · Core'), findsOneWidget);
    });

    testWidgets('a command-line tool shows its name and a glyph', (
      tester,
    ) async {
      final filters = <RecordFilter>[];
      await pump(
        tester,
        RecordFilterScope(
          onFilter: filters.add,
          child: TrackerInfoItem(trackerInfo: _cli, detailTitle: 'detail'),
        ),
      );
      expect(find.text('ssh  ·  127.0.0.1:50022'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byGlyph(AppGlyphs.question), findsNothing);
      expect(find.byType(ProcessFilterIcon), findsOneWidget);
      await tester.tap(find.byType(ProcessFilterIcon));
      expect(filters, const [
        RecordFilter(RecordFacetKind.app, 'exe:/usr/bin/ssh'),
      ]);
    });

    testWidgets('no process info keeps the icon room, empty', (tester) async {
      Future<double> titleLeft(TrackerInfo info) async {
        await pump(
          tester,
          TrackerInfoItem(trackerInfo: info, detailTitle: 'detail'),
        );
        return tester.getTopLeft(find.textContaining('example.com')).dx;
      }

      final withIcon = await titleLeft(_app);
      final cli = await titleLeft(_cli);
      final without = await titleLeft(_unknown);
      expect(find.text('Unknown process  ·  198.18.0.1:50100'), findsOneWidget);
      expect(find.byType(ProcessFilterIcon), findsNothing);
      expect(find.byType(ProcessIcon), findsOneWidget);
      expect(tester.getSize(find.byType(ProcessIcon)), const Size(24, 24));
      expect(find.byGlyph(AppGlyphs.question), findsNothing);
      expect(without, withIcon);
      expect(cli, withIcon);
    });

    testWidgets('a feature service shows its icon, label and raw name', (
      tester,
    ) async {
      final filters = <RecordFilter>[];
      await pump(
        tester,
        RecordFilterScope(
          onFilter: filters.add,
          child: TrackerInfoItem(trackerInfo: _push, detailTitle: 'detail'),
        ),
      );
      expect(find.textContaining('Push Notifications'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byTooltip('Filter by this process\napsd'), findsOneWidget);
      await tester.tap(find.byType(ProcessFilterIcon));
      expect(filters, const [
        RecordFilter(RecordFacetKind.app, 'svc:pushNotifications'),
      ]);
    });

    testWidgets('a shared service says what it does under a glyph', (
      tester,
    ) async {
      await pump(
        tester,
        TrackerInfoItem(trackerInfo: _downloads, detailTitle: 'detail'),
      );
      expect(
        find.textContaining('System service: Background downloads'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byType(ProcessFilterIcon), findsOneWidget);
    });

    testWidgets('a LAN client of this Mac reads as another device', (
      tester,
    ) async {
      await pump(
        tester,
        TrackerInfoItem(trackerInfo: _remote, detailTitle: 'detail'),
      );
      expect(find.text('Other device  ·  192.168.1.20:50200'), findsOneWidget);
      expect(find.byType(ProcessFilterIcon), findsNothing);
      expect(find.byType(ProcessIcon), findsOneWidget);
    });

    testWidgets('CLI and unknown processes do not use the generic app icon', (
      tester,
    ) async {
      processApps.dispose();
      var reads = 0;
      processApps = ProcessApps(
        lookupApps: true,
        invoke: (_) async => null,
        readGenericIcon: () async {
          reads++;
          return _pixel;
        },
        readLocalAddresses: () async => {'127.0.0.1'},
      )..seed(lookups: {'/usr/bin/ssh': AppLookup.none});
      await pump(
        tester,
        Column(
          children: [
            TrackerInfoItem(trackerInfo: _cli, detailTitle: 'detail'),
            TrackerInfoItem(trackerInfo: _unknown, detailTitle: 'detail'),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('ssh  ·  127.0.0.1:50022'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(reads, 0);
    });
  });

  group('table cell', () {
    testWidgets('names the app with the process and path on hover', (
      tester,
    ) async {
      await pump(tester, ProcessCell(metadata: _app.metadata));
      expect(find.text('Example Browser · Helper'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Example Browser Helper\n$_chromePath');
    });

    testWidgets('names a service with the process and path on hover', (
      tester,
    ) async {
      await pump(tester, ProcessCell(metadata: _downloads.metadata));
      expect(find.text('System service: Background downloads'), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'nsurlsessiond\n/usr/libexec/nsurlsessiond');
    });

    testWidgets('an unknown process lines up with named ones', (tester) async {
      await pump(tester, ProcessCell(metadata: _app.metadata));
      final named = tester.getTopLeft(find.text('Example Browser · Helper')).dx;
      await pump(tester, ProcessCell(metadata: _unknown.metadata));
      expect(find.text('Unknown process'), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
      expect(tester.getTopLeft(find.text('Unknown process')).dx, named);
    });
  });

  testWidgets('the table shows the whole start time', (tester) async {
    tester.view.physicalSize = const Size(1000, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(
      tester,
      Builder(
        builder: (context) => RecordTableFrame<TrackerInfo>(
          tableId: 'process-time',
          items: [_app, _unknown],
          columnsOf: (width) =>
              trackerInfoColumns(context, width: width, isLive: false),
          builder: (context, table, items) => TrackerInfoList(
            trackerInfos: items,
            table: table,
            detailTitle: 'detail',
          ),
        ),
      ),
    );
    final time = _app.start.showTime.trim();
    final cells = find.text(time);
    expect(cells, findsNWidgets(2));
    for (final cell in cells.evaluate()) {
      final paragraph = cell.renderObject! as RenderParagraph;
      expect(paragraph.didExceedMaxLines, isFalse);
    }
  });

  group('detail', () {
    Future<void> pumpDetail(WidgetTester tester, TrackerInfo info) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(
        tester,
        SheetProvider(
          type: SheetType.page,
          child: TrackerInfoDetailView(trackerInfo: info),
        ),
      );
    }

    testWidgets('an app lists app, process and a copyable path', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpDetail(tester, _app);
      expect(find.text('App'), findsOneWidget);
      expect(find.text('Example Browser'), findsOneWidget);
      expect(find.text('Process'), findsOneWidget);
      expect(find.text('Example Browser Helper'), findsOneWidget);
      expect(find.text('Process path'), findsOneWidget);
      expect(find.byTooltip(_chromePath), findsOneWidget);
      expect(find.textContaining('…'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy path'));
      await tester.pump();
      expect(copied, _chromePath);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a command-line tool has no app row', (tester) async {
      await pumpDetail(tester, _cli);
      expect(find.text('App'), findsNothing);
      expect(find.text('ssh'), findsOneWidget);
      expect(find.byTooltip('/usr/bin/ssh'), findsOneWidget);
      expect(find.textContaining('/usr/bin/ssh'), findsOneWidget);
    });

    testWidgets('no process info says so', (tester) async {
      await pumpDetail(tester, _unknown);
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('Process information is unavailable.'), findsOneWidget);
      expect(find.text('Process path'), findsNothing);
      expect(find.byTooltip('Copy path'), findsNothing);
    });

    testWidgets('another device says where it came from', (tester) async {
      await pumpDetail(tester, _remote);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        find.text(
          'This connection is from another device. Its process information '
          'cannot be obtained on this Mac.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a feature service lists service, process and path', (
      tester,
    ) async {
      await pumpDetail(tester, _push);
      expect(find.text('System service'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(
        find.text('An Apple system process, recognized by its path'),
        findsOneWidget,
      );
      expect(find.text('App'), findsNothing);
      expect(find.text('apsd'), findsOneWidget);
      expect(find.byTooltip(_apsd), findsOneWidget);
    });

    testWidgets('a shared service says no one app is behind it', (
      tester,
    ) async {
      await pumpDetail(tester, _downloads);
      expect(find.text('System service: Background downloads'), findsOneWidget);
      expect(
        find.text(
          'Many apps go through this system service; the app behind this '
          'request is not known',
        ),
        findsOneWidget,
      );
      expect(find.text('nsurlsessiond'), findsOneWidget);
    });

    testWidgets('a launchd daemon names its app and the job', (tester) async {
      await pumpDetail(tester, _helper);
      expect(find.text('App'), findsOneWidget);
      expect(find.text('Example'), findsOneWidget);
      expect(
        find.text('Tied to this app by its launchd job com.example.daemon'),
        findsOneWidget,
      );
      expect(find.text('com.example.daemon'), findsOneWidget);
      expect(find.byTooltip(_daemon), findsOneWidget);
    });

    testWidgets('an unreadable app keeps the process', (tester) async {
      await pumpDetail(tester, _unreadable);
      expect(find.text('App'), findsNothing);
      expect(find.text('Gone'), findsOneWidget);
      expect(find.text('Could not read app information'), findsOneWidget);
      expect(find.byTooltip('/Applications/Gone.app/g'), findsOneWidget);
    });
  });

  group('path ellipsis', () {
    const style = TextStyle(fontSize: 10);

    test('keeps a path that fits whole', () {
      expect(
        middleEllipsisPath('/usr/bin/ssh', style: style, maxWidth: 400),
        '/usr/bin/ssh',
      );
    });

    test('cuts the middle and keeps both ends', () {
      final shown = middleEllipsisPath(
        _chromePath,
        style: style,
        maxWidth: 120,
        maxLines: 2,
        trailing: const Size(26, 20),
      );
      expect(shown.length, lessThan(_chromePath.length));
      final [head, tail] = shown.split('…');
      expect(head, isNotEmpty);
      expect(tail, isNotEmpty);
      expect(_chromePath.startsWith(head), isTrue);
      expect(_chromePath.endsWith(tail), isTrue);
      expect((head.length - tail.length).abs(), lessThanOrEqualTo(1));
    });
  });

  group('lookup off notice', () {
    test('shows only for a confirmed off mode and no process anywhere', () {
      expect(ProcessLookupOffNotice.showsFor('off', [_unknown]), isTrue);
      expect(ProcessLookupOffNotice.showsFor('off', [_unknown, _cli]), isFalse);
      expect(ProcessLookupOffNotice.showsFor('off', const []), isFalse);
      expect(ProcessLookupOffNotice.showsFor(null, [_unknown]), isFalse);
      expect(ProcessLookupOffNotice.showsFor('strict', [_unknown]), isFalse);
      expect(ProcessLookupOffNotice.showsFor('always', [_unknown]), isFalse);
    });

    testWidgets('reads the running mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      container.read(runningFindProcessModeProvider.notifier).value = 'off';
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            homeBuilder: (child) => HostScaffold(body: child),
            child: SizedBox(
              height: 400,
              child: ProcessLookupOffNotice(
                visible: [_unknown],
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Process lookup is currently disabled.'),
        findsOneWidget,
      );
      container.read(runningFindProcessModeProvider.notifier).value = null;
      await tester.pump();
      expect(find.text('Process lookup is currently disabled.'), findsNothing);
    });
  });
}
