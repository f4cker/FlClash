import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/release_history.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final ResponseBody Function(RequestOptions) answer;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => answer(options);
  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> row(
  String tag,
  String? date, {
  bool draft = false,
  bool prerelease = false,
  String? body,
}) => {
  'tag_name': tag,
  'published_at': date,
  'draft': draft,
  'prerelease': prerelease,
  'body': body,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final current = PublishedRelease(
    tag: 'v1.0.0',
    published: DateTime.utc(2026, 11, 18),
    body: 'Cached notes',
  );
  final cached = ReleaseHistory([
    current,
  ], fetchedAt: DateTime.utc(2026, 11, 18));

  test('prerelease identity comes only from metadata and survives caching', () {
    final beta = PublishedRelease.fromJson(
      row('v1.0.1-beta.1', '2026-11-20', prerelease: true),
    )!;
    final stable = PublishedRelease.fromJson(row('v1.0.0', '2026-11-19'))!;
    expect(beta.prerelease, isTrue);
    expect(stable.prerelease, isFalse);
    expect(
      PublishedRelease(
        tag: 'v1.0.1-beta.2',
        published: DateTime.utc(2026),
      ).prerelease,
      isNull,
    );
    final decoded = ReleaseHistory.decode(
      ReleaseHistory([beta, stable], fetchedAt: DateTime.utc(2026)).encode(),
    )!;
    expect(decoded.releases.first.prerelease, isTrue);
    expect(decoded.releases.last.prerelease, isFalse);
  });

  test(
    'exact installed identity never guesses latest or strips prerelease',
    () {
      expect(current.matchesInstalled('0.9.15-mitm.12', '42'), isFalse);
      expect(current.matchesInstalled('1.0.0', '42'), isTrue);
      expect(
        PublishedRelease(
          tag: 'v1.0.0+41',
          published: current.published,
        ).matchesInstalled('1.0.0', '42'),
        isFalse,
      );
      expect(
        current.matchesAvailable(const UpdateAvailable({'tag_name': 'v1.0.0'})),
        isTrue,
      );
    },
  );

  test(
    'history sorts by publication date, deduplicates and round trips cache',
    () {
      final history = ReleaseHistory(
        [
          current,
          PublishedRelease(
            tag: 'v0.1.0',
            published: DateTime.utc(2026, 11, 20),
          ),
          current,
        ],
        fetchedAt: DateTime.utc(2026),
        truncated: true,
      );
      final decoded = ReleaseHistory.decode(history.encode())!;
      expect(decoded.releases.map((r) => r.tag), ['v0.1.0', 'v1.0.0']);
      expect(decoded.releases.last.body, 'Cached notes');
      expect(decoded.truncated, isTrue);
      expect(ReleaseHistory.decode('invalid'), isNull);
    },
  );

  test(
    'fetch follows pages, includes published prereleases, excludes drafts and unpublished',
    () async {
      final pages = <int>[];
      final request = Request()
        ..dio.httpClientAdapter = _Adapter((options) {
          final page = options.queryParameters['page'] as int;
          pages.add(page);
          expect(options.uri.host, 'api.github.com');
          expect(options.queryParameters['per_page'], 100);
          return ResponseBody.fromString(
            jsonEncode(
              page == 1
                  ? [
                      row('v1.0.0', '2026-11-18T00:00:00Z'),
                      row('draft', '2026-11-21T00:00:00Z', draft: true),
                      row('unpublished', null),
                    ]
                  : [
                      row(
                        'v0.9.15-mitm.12',
                        '2026-11-19T00:00:00Z',
                        prerelease: true,
                      ),
                    ],
            ),
            200,
            headers: {
              'content-type': ['application/json'],
              if (page == 1) 'link': ['<next>; rel="next"'],
            },
          );
        });
      final history = await request.releaseHistory();
      expect(pages, [1, 2]);
      expect(history.releases.map((r) => r.tag), ['v0.9.15-mitm.12', 'v1.0.0']);
      expect(history.truncated, isFalse);
    },
  );

  test(
    'bounded fetch reports truncation instead of pretending completeness',
    () async {
      var calls = 0;
      final request = Request()
        ..dio.httpClientAdapter = _Adapter((_) {
          calls++;
          return ResponseBody.fromString(
            '[]',
            200,
            headers: {
              'content-type': ['application/json'],
              'link': ['<next>; rel="next"'],
            },
          );
        });
      expect((await request.releaseHistory(pageLimit: 2)).truncated, isTrue);
      expect(calls, 2);
      await expectLater(
        request.releaseHistory(pageLimit: 11),
        throwsRangeError,
      );
    },
  );

  test(
    'failure of a later page fails the snapshot rather than losing cached entries',
    () async {
      final request = Request()
        ..dio.httpClientAdapter = _Adapter(
          (options) => options.queryParameters['page'] == 1
              ? ResponseBody.fromString(
                  jsonEncode([row('v1', '2026-11-18T00:00:00Z')]),
                  200,
                  headers: {
                    'content-type': ['application/json'],
                    'link': ['<next>; rel="next"'],
                  },
                )
              : ResponseBody.fromString('rate limited', 403),
        );
      await expectLater(request.releaseHistory(), throwsA(isA<DioException>()));
    },
  );

  test(
    'refresh retains cached notes on failure, retries and persists success',
    () async {
      var fail = true;
      String? saved;
      final store = ReleaseHistoryStore(
        fetch: () async {
          if (fail) throw StateError('offline');
          return ReleaseHistory([], fetchedAt: DateTime.utc(2026, 11, 19));
        },
        readCache: () async => cached.encode(),
        writeCache: (value) async => saved = value,
      );
      addTearDown(store.dispose);
      await store.refresh();
      expect(store.history!.releases.single.body, 'Cached notes');
      expect(store.failed, isTrue);
      expect(store.stale, isTrue);
      expect(saved, isNull);
      fail = false;
      await store.refresh();
      expect(store.history!.releases, isEmpty);
      expect(store.failed, isFalse);
      expect(store.stale, isFalse);
      expect(saved, isNotNull);
    },
  );

  test(
    'cached entries remain visible during in-flight refresh and duplicate retry coalesces',
    () async {
      final pending = Completer<ReleaseHistory>();
      var calls = 0;
      final store = ReleaseHistoryStore(
        fetch: () {
          calls++;
          return pending.future;
        },
        readCache: () async => cached.encode(),
        writeCache: (_) async {},
      );
      addTearDown(store.dispose);
      final operation = store.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(store.history!.releases.single.tag, 'v1.0.0');
      expect(store.loading, isTrue);
      expect(store.stale, isTrue);
      await store.refresh();
      expect(calls, 1);
      pending.complete(cached);
      await operation;
      expect(store.stale, isFalse);
    },
  );

  test('disposal during fetch does not publish or write cache', () async {
    final pending = Completer<ReleaseHistory>();
    var writes = 0;
    final store = ReleaseHistoryStore(
      fetch: () => pending.future,
      readCache: () async => null,
      writeCache: (_) async {
        writes++;
      },
    );
    final operation = store.refresh();
    store.dispose();
    pending.complete(cached);
    await operation;
    expect(writes, 0);
  });

  test('cache read or write failure does not hide a fresh response', () async {
    final store = ReleaseHistoryStore(
      fetch: () async => cached,
      readCache: () async => throw StateError('read'),
      writeCache: (_) async => throw StateError('write'),
    );
    addTearDown(store.dispose);
    await store.refresh();
    expect(store.history, cached);
    expect(store.failed, isFalse);
  });

  test('history persistence is isolated from consent and settings', () async {
    await mockPreferences({'macHelperInvitationShown': true});
    await preferences.saveReleaseHistoryCache(cached.encode());
    expect(await preferences.getReleaseHistoryCache(), cached.encode());
    expect(await preferences.getMacHelperInvitationShown(), isTrue);
  });
}
