import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
final _unreadable = _info(
  const Metadata(process: 'Gone', processPath: '/Applications/Gone.app/g'),
);

void main() {
  late ProcessApps previous;

  setUp(() {
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
          ),
        ),
        '/usr/bin/ssh': AppLookup.none,
        '/Applications/Gone.app/g': AppLookup.unreadable,
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
      expect(find.text('Example Browser  ·  127.0.0.1:51234'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byType(ProcessFilterIcon));
      expect(filters, const [
        RecordFilter(RecordFacetKind.app, 'app:com.example.browser'),
      ]);
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
      expect(find.byType(ProcessFilterIcon), findsOneWidget);
      await tester.tap(find.byType(ProcessFilterIcon));
      expect(filters, const [
        RecordFilter(RecordFacetKind.app, 'exe:/usr/bin/ssh'),
      ]);
    });

    testWidgets('no process info keeps the row without an icon', (
      tester,
    ) async {
      await pump(
        tester,
        TrackerInfoItem(trackerInfo: _unknown, detailTitle: 'detail'),
      );
      expect(find.text('Unknown process  ·  198.18.0.1:50100'), findsOneWidget);
      expect(find.byType(ProcessFilterIcon), findsNothing);
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
    });
  });

  group('table cell', () {
    testWidgets('names the app with the process and path on hover', (
      tester,
    ) async {
      await pump(tester, ProcessCell(metadata: _app.metadata));
      expect(find.text('Example Browser'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Example Browser Helper\n$_chromePath');
    });

    testWidgets('an unknown process is muted text alone', (tester) async {
      await pump(tester, ProcessCell(metadata: _unknown.metadata));
      expect(find.text('Unknown process'), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
    });
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
      expect(find.text(_chromePath), findsOneWidget);
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
      expect(find.text('/usr/bin/ssh'), findsOneWidget);
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

    testWidgets('an unreadable app keeps the process', (tester) async {
      await pumpDetail(tester, _unreadable);
      expect(find.text('App'), findsNothing);
      expect(find.text('Gone'), findsOneWidget);
      expect(find.text('Could not read app information'), findsOneWidget);
      expect(find.text('/Applications/Gone.app/g'), findsOneWidget);
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
