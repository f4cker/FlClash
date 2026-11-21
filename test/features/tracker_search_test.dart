import 'dart:async';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

TrackerInfo _tracker(int id, {int round = 0, String? host}) => TrackerInfo(
  id: 'c$id',
  download: round * 100,
  start: DateTime.utc(2026),
  metadata: Metadata(
    network: id.isEven ? 'tcp' : 'udp',
    host: host ?? 'h${id % 13}.example',
    destinationIP: '10.0.${id % 7}.1',
    process: id % 3 == 0 ? 'curl' : 'Safari',
  ),
  chains: [id % 5 == 0 ? 'DIRECT' : 'Proxy'],
  rule: 'DOMAIN',
  rulePayload: 'p${id % 4}',
);

/// What each poll decodes: every connection a new object, 1% replaced.
List<TrackerInfo> _poll(int round, {int n = 1000}) => [
  for (var i = round * 10; i < round * 10 + n; i++) _tracker(i, round: round),
];

const _push =
    '/System/Library/PrivateFrameworks/ApplePushService.framework/'
    'apsd';
const _downloads = '/usr/libexec/nsurlsessiond';
const _browser = '/Applications/Browser.app/Contents/MacOS/Browser';
const _later = '/Applications/Later.app/Contents/MacOS/Later';
const _paths = [_push, _downloads, _browser, _later, ''];

/// A connection with every searched field drawn from [random].
TrackerInfo _random(Random random, int id) {
  final path = _paths[random.nextInt(_paths.length)];
  return TrackerInfo(
    id: 'c$id',
    download: random.nextInt(1 << 20),
    start: DateTime.utc(2026),
    metadata: Metadata(
      network: random.nextBool() ? 'tcp' : 'udp',
      host: 'h${random.nextInt(30)}.example',
      destinationIP: '10.0.${random.nextInt(9)}.1',
      destinationPort: '${400 + random.nextInt(50)}',
      sourcePort: '${50000 + random.nextInt(9)}',
      process: path.isEmpty ? '' : path.split('/').last,
      processPath: path,
      destinationGeoIP: [if (random.nextBool()) 'CN' else 'US'],
    ),
    chains: [random.nextBool() ? 'DIRECT' : 'Proxy${random.nextInt(3)}'],
    rule: random.nextBool() ? 'DOMAIN' : 'MATCH',
    rulePayload: 'p${random.nextInt(5)}',
  );
}

/// [previous] after a poll: some closed, some opened, some changed in one
/// searched field, every one decoded anew.
List<TrackerInfo> _churn(Random random, List<TrackerInfo> previous, int next) {
  final result = <TrackerInfo>[];
  for (final info in previous) {
    final roll = random.nextInt(20);
    if (roll == 0) {
      continue;
    }
    if (roll == 1) {
      final other = _random(random, 0);
      result.add(switch (random.nextInt(4)) {
        0 => info.copyWith(
          metadata: info.metadata.copyWith(host: other.metadata.host),
        ),
        1 => info.copyWith(chains: other.chains),
        2 => info.copyWith(rule: other.rule, rulePayload: other.rulePayload),
        _ => info.copyWith(
          metadata: info.metadata.copyWith(
            process: other.metadata.process,
            processPath: other.metadata.processPath,
          ),
        ),
      });
      continue;
    }
    result.add(
      info.copyWith(
        metadata: info.metadata.copyWith(),
        chains: [...info.chains],
      ),
    );
  }
  for (var i = 0; i < random.nextInt(30); i++) {
    result.add(_random(random, next + i));
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('finds what TrackerInfosState.list finds, across polls and queries', () {
    final search = TrackerSearch();
    addTearDown(search.dispose);
    for (var round = 0; round < 4; round++) {
      final trackerInfos = _poll(round);
      for (final query in ['h3', 'udp curl', 'DIRECT p1', '10.0.2', 'none']) {
        final expected = TrackerInfosState(
          trackerInfos: trackerInfos,
          query: query,
        ).list;
        expect(
          search.apply(trackerInfos, query).map((info) => info.id),
          expected.map((info) => info.id),
          reason: '$query in round $round',
        );
      }
    }
  });

  test('a poll builds the texts of the new and changed connections only', () {
    final search = TrackerSearch();
    addTearDown(search.dispose);
    search.apply(_poll(0), 'example');
    expect(search.textsBuilt, 1000);

    search.textsBuilt = 0;
    final next = _poll(1);
    next[500] = _tracker(510, round: 1, host: 'moved.test');
    final found = search.apply(next, 'moved');
    expect(search.textsBuilt, 11);
    expect(found.map((info) => info.id), ['c510']);
  });

  test('keeps the texts of the last list searched only', () {
    final search = TrackerSearch();
    addTearDown(search.dispose);
    search.apply(_poll(0), 'example');
    search.apply(_poll(0, n: 10), 'example');

    search.textsBuilt = 0;
    search.apply(_poll(0), 'example');
    expect(search.textsBuilt, 990);
  });

  test('the same list and query are not searched again', () {
    final search = TrackerSearch();
    addTearDown(search.dispose);
    final trackerInfos = _poll(0);
    final first = search.apply(trackerInfos, 'h3');
    expect(identical(search.apply(trackerInfos, 'h3'), first), isTrue);
    expect(identical(search.apply(trackerInfos, ''), trackerInfos), isTrue);
  });

  group('with app and service labels', () {
    late ProcessApps previous;

    setUp(() {
      loadAppLocalizations(const Locale('en'));
      previous = processApps;
      processApps = ProcessApps(
        lookupApps: true,
        invoke: (_) async => null,
        readLocalAddresses: () async => const {},
      );
      processApps.seed(
        lookups: {
          _push: const AppLookup.service(
            ServiceMatch(SystemService.pushNotifications),
          ),
          _downloads: const AppLookup.service(
            ServiceMatch(SystemService.backgroundDownloads),
          ),
          _browser: const AppLookup.app(
            MacApp(
              bundleId: 'com.example.browser',
              name: 'Example Browser',
              bundlePath: '/Applications/Browser.app',
            ),
          ),
        },
        local: const {},
      );
    });

    tearDown(() {
      processApps.dispose();
      processApps = previous;
      loadAppLocalizations(const Locale('en'));
    });

    test('a locale switch finds services by their names in the new locale', () {
      final search = TrackerSearch();
      addTearDown(search.dispose);
      List<TrackerInfo> poll() => [
        TrackerInfo(
          id: 'push',
          start: DateTime.utc(2026),
          metadata: const Metadata(process: 'apsd', processPath: _push),
          chains: const ['DIRECT'],
          rule: 'MATCH',
          rulePayload: '',
        ),
        TrackerInfo(
          id: 'web',
          start: DateTime.utc(2026),
          metadata: const Metadata(process: 'Browser', processPath: _browser),
          chains: const ['DIRECT'],
          rule: 'MATCH',
          rulePayload: '',
        ),
      ];
      expect(search.apply(poll(), 'Push Notifications').map((i) => i.id), [
        'push',
      ]);

      loadAppLocalizations(const Locale('zh'));
      final zh = poll();
      expect(
        search.apply(zh, '推送通知').map((i) => i.id),
        TrackerInfosState(
          trackerInfos: zh,
          query: '推送通知',
        ).list.map((i) => i.id),
      );
      expect(search.apply(zh, '推送通知').map((i) => i.id), ['push']);
      expect(search.apply(poll(), 'Push Notifications'), isEmpty);
    });

    test('finds what TrackerInfosState.list finds under random churn, app '
        'lookups and locale switches, keeping no more texts than the list', () {
      final random = Random(20261120);
      final search = TrackerSearch();
      addTearDown(search.dispose);
      const queries = [
        'example',
        'h1',
        'udp 10.0.3',
        'DIRECT',
        'Proxy1 p2',
        'Push',
        '推送',
        'Background',
        '后台下载',
        'Example Browser',
        'Later App',
        'CN',
        'MATCH 44',
      ];
      var next = 0;
      var trackerInfos = [for (; next < 300; next++) _random(random, next)];
      for (var round = 0; round < 60; round++) {
        if (round % 7 == 3) {
          loadAppLocalizations(
            Locale(currentAppLocale.languageCode == 'en' ? 'zh' : 'en'),
          );
        }
        if (round == 20) {
          processApps.seed(
            lookups: {
              _later: const AppLookup.app(
                MacApp(
                  bundleId: 'com.example.later',
                  name: 'Later App',
                  bundlePath: '/Applications/Later.app',
                ),
              ),
            },
          );
        }
        if (round > 0) {
          trackerInfos = _churn(random, trackerInfos, next);
          next += 30;
        }
        for (final query in [
          queries[random.nextInt(queries.length)],
          queries[random.nextInt(queries.length)],
        ]) {
          expect(
            search.apply(trackerInfos, query).map((info) => info.id),
            TrackerInfosState(
              trackerInfos: trackerInfos,
              query: query,
            ).list.map((info) => info.id),
            reason:
                '"$query" in round $round, ${currentAppLocale.languageCode}',
          );
          expect(search.textsKept, lessThanOrEqualTo(trackerInfos.length));
        }
      }
      final shorter = trackerInfos.sublist(0, trackerInfos.length ~/ 3);
      search.apply(shorter, 'example');
      expect(search.textsKept, shorter.length);
    });
  });

  test('the shown list is filtered again when the apps learn a process, '
      'with an app filter on', () {
    final previous = processApps;
    // Lookups never answer: only a seed tells the apps.
    processApps = ProcessApps(
      lookupApps: true,
      invoke: (_) => Completer<Object?>().future,
      readLocalAddresses: () async => const {},
    )..seed(local: const {});
    addTearDown(() {
      processApps.dispose();
      processApps = previous;
    });
    final controller = TrackerInfoListController();
    final filters = RecordFilterController<TrackerInfo>(
      facets: trackerInfoFacets,
      groupers: trackerInfoGroupers,
    );
    addTearDown(controller.dispose);
    addTearDown(filters.dispose);
    final browser = TrackerInfo(
      id: 'web',
      start: DateTime.utc(2026),
      metadata: const Metadata(process: 'Browser', processPath: _browser),
      chains: const ['DIRECT'],
      rule: 'MATCH',
      rulePayload: '',
    );
    controller.setTrackerInfos([browser, _tracker(1)]);
    filters.add(
      const RecordFilter(RecordFacetKind.app, 'app:com.example.browser'),
    );
    final shown = controller.shownBy(filters);
    expect(shown, isEmpty);
    // The same state, filters and apps: nothing is worked out again.
    expect(identical(controller.shownBy(filters), shown), isTrue);

    processApps.seed(
      lookups: {
        _browser: const AppLookup.app(
          MacApp(
            bundleId: 'com.example.browser',
            name: 'Example Browser',
            bundlePath: '/Applications/Browser.app',
          ),
        ),
      },
    );
    expect(controller.shownBy(filters).map((info) => info.id), ['web']);

    filters.remove(
      const RecordFilter(RecordFacetKind.app, 'app:com.example.browser'),
    );
    controller.search('h1');
    final found = controller.list;
    expect(found.map((info) => info.id), ['c1']);
    expect(identical(controller.list, found), isTrue);
    expect(identical(controller.shownBy(filters), found), isTrue);
  });
}
