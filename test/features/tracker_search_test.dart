import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
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
}
