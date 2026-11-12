import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

TrackerInfo _info(String id, Metadata metadata) => TrackerInfo(
  id: id,
  start: DateTime(2026, 11, 12),
  metadata: metadata,
  chains: const ['DIRECT'],
  rule: 'MATCH',
  rulePayload: '',
);

Map<String, Object?> _app(String bundleId, String name, String bundlePath) => {
  'status': 'app',
  'bundleId': bundleId,
  'name': name,
  'bundlePath': bundlePath,
};

void main() {
  late ProcessApps previous;
  late List<String> asked;
  late Map<String, Object?> answers;

  setUp(() {
    previous = processApps;
    asked = [];
    answers = {
      '/Applications/Notes.app/Contents/MacOS/Notes': _app(
        'com.example.notes',
        'Notes',
        '/Applications/Notes.app',
      ),
      '/Users/me/Notes.app/Contents/MacOS/Notes': _app(
        'org.other.notes',
        'Notes',
        '/Users/me/Notes.app',
      ),
      '/usr/bin/ssh': {'status': 'none'},
    };
    processApps = ProcessApps(
      lookupApps: true,
      invoke: (path) async {
        asked.add(path);
        return answers[path];
      },
      readLocalAddresses: () async => {'127.0.0.1', '192.168.1.5'},
    );
  });

  tearDown(() {
    processApps.dispose();
    processApps = previous;
  });

  test('each path is asked once and answers are cached', () async {
    const path = '/usr/bin/ssh';
    expect(processApps.lookupOf(path), isNull);
    expect(processApps.lookupOf(path), isNull);
    await pumpEventQueue();
    expect(processApps.lookupOf(path)?.status, AppLookupStatus.none);
    expect(asked, [path]);
  });

  test('a listener hears each answer', () async {
    var heard = 0;
    processApps.addListener(() => heard++);
    processApps.lookupOf('/usr/bin/ssh');
    await pumpEventQueue();
    expect(heard, greaterThan(0));
  });

  test('the cache keeps only the most recent paths', () async {
    processApps.dispose();
    processApps = ProcessApps(
      lookupApps: true,
      capacity: 2,
      invoke: (path) async {
        asked.add(path);
        return {'status': 'none'};
      },
    );
    for (final path in ['/a', '/b', '/c']) {
      processApps.lookupOf(path);
      await pumpEventQueue();
    }
    processApps.lookupOf('/a');
    await pumpEventQueue();
    expect(asked, ['/a', '/b', '/c', '/a']);
  });

  test('a failed lookup reads as no app until retried', () async {
    processApps.dispose();
    processApps = ProcessApps(
      lookupApps: true,
      invoke: (path) => Future.error(StateError('no channel')),
    );
    processApps.lookupOf('/x');
    await pumpEventQueue();
    final process = processApps.processOf(
      const Metadata(process: 'x', processPath: '/x'),
    );
    expect(process.kind, ProcessKind.process);
    expect(process.pending, isFalse);
  });

  test('other platforms never ask', () {
    final apps = ProcessApps(
      lookupApps: false,
      invoke: (path) async => fail('asked'),
    );
    expect(apps.lookupOf('/usr/bin/ssh'), AppLookup.none);
    apps.dispose();
  });

  test('same-named apps group and filter apart', () async {
    final infos = [
      _info(
        '1',
        const Metadata(
          process: 'Notes',
          processPath: '/Applications/Notes.app/Contents/MacOS/Notes',
        ),
      ),
      _info(
        '2',
        const Metadata(
          process: 'Notes',
          processPath: '/Users/me/Notes.app/Contents/MacOS/Notes',
        ),
      ),
      _info('3', const Metadata(sourceIP: '192.168.1.20')),
      _info('4', const Metadata(process: 'ssh', processPath: '/usr/bin/ssh')),
    ];
    for (final info in infos) {
      info.processKey;
    }
    await pumpEventQueue();
    final grouper = trackerInfoGroupers.firstWhere(
      (grouper) => grouper.grouping == RecordGrouping.app,
    );
    final groups = groupRecords(infos, grouper.keyOf, sinks: grouper.sinks);
    expect(groups.map((group) => group.key), [
      'app:com.example.notes',
      'app:org.other.notes',
      'exe:/usr/bin/ssh',
      '',
    ]);
    final facet = trackerInfoFacets.firstWhere(
      (facet) => facet.kind == RecordFacetKind.app,
    );
    final filtered = infos.whereFilters(trackerInfoFacets, const [
      RecordFilter(RecordFacetKind.app, 'app:org.other.notes'),
    ]);
    expect(filtered.map((info) => info.id), ['2']);
    expect(facet.label('app:org.other.notes'), 'Notes');
    expect(facet.label('exe:/usr/bin/ssh'), 'ssh');
  });

  test('another device is told apart only with local addresses read', () async {
    const metadata = Metadata(
      type: 'HTTP',
      sourceIP: '192.168.1.20',
      inboundIP: '192.168.1.5',
    );
    expect(processApps.processOf(metadata).kind, ProcessKind.unknown);
    await pumpEventQueue();
    expect(processApps.processOf(metadata).kind, ProcessKind.otherDevice);
  });
}
