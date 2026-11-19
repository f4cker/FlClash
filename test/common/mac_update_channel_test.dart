import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/mac_update.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mac_release.dart';

class Routes implements HttpClientAdapter {
  Routes(this.answer);
  final FutureOr<ResponseBody> Function(RequestOptions) answer;
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return answer(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(
  Object value, {
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(jsonEncode(value), 200, headers: headers);
Map<String, Object> locator(String tag, {bool beta = false}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': beta,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('persisted opt-in defaults false including migration', () {
    expect(const AppSettingProps().receiveBetaUpdates, isFalse);
    expect(AppSettingProps.fromJson({}).receiveBetaUpdates, isFalse);
    const enabled = AppSettingProps(receiveBetaUpdates: true);
    expect(
      AppSettingProps.fromJson(
        jsonDecode(jsonEncode(enabled)) as Map<String, dynamic>,
      ).receiveBetaUpdates,
      isTrue,
    );
  });
  test('installed beta identity is independent from preference', () {
    final identity = MacInstalledIdentity.fromAnswer({
      'channel': 'beta',
      'version': '1.1.0-beta.1',
      'build': 2026111903,
    })!;
    expect(identity.fullVersion, '1.1.0-beta.1+2026111903');
    expect(identity.channel, ReleaseChannel.beta);
    expect(
      MacInstalledIdentity.fromAnswer({
        'version': '1.0.0',
        'build': 2026111902,
      }),
      isNull,
    );
    expect(
      MacInstalledIdentity.fromAnswer({
        'channel': 'dev',
        'version': '1.0.0',
        'build': 2026111902,
      }),
      isNull,
    );
  });
  group('authenticated payload policy', () {
    test('channel comes from signed field, not version or tag', () {
      expect(
        releaseManifest(channel: 'stable', version: '1.1.0-beta.1').channel,
        ReleaseChannel.stable,
      );
      expect(
        releaseManifest(channel: 'beta', version: '1.1.0').channel,
        ReleaseChannel.beta,
      );
    });
    for (final change in <String, void Function(Map<String, dynamic>)>{
      'missing channel': (p) => p.remove('channel'),
      'unknown channel': (p) => p['channel'] = 'dev',
      'null channel': (p) => p['channel'] = null,
      'wrong channel type': (p) => p['channel'] = true,
      'schema1 beta': (p) => p['channel'] = 'beta',
      'schema2 stable': (p) => p['schema'] = 2,
      'wrong platform': (p) => p['platform'] = 'ios',
      'wrong product': (p) => p['product'] = 'other',
      'wrong repository': (p) => p['release']['repository'] = 'f4cker/FlClash',
      'wrong source': (p) => p['release']['sourceRepository'] = 'other/other',
      'bad commit': (p) => p['release']['sourceCommit'] = 'A' * 40,
      'traversal tag': (p) => p['release']['tag'] = '../v1',
      'bad semantic': (p) => p['release']['version'] = '1.0.0-beta.01',
      'cross tag url': (p) => p['assets'][0]['url'] = macReleaseAssetUri(
        'other',
        p['assets'][0]['name'],
      ).toString(),
      'query url': (p) => p['assets'][0]['url'] += '?x=1',
      'userinfo url': (p) =>
          p['assets'][0]['url'] = (p['assets'][0]['url'] as String)
              .replaceFirst('https://', 'https://user@'),
      'duplicate arch': (p) => p['assets'].add(p['assets'][0]),
    }.entries) {
      test('rejects ${change.key}', () {
        final p = releasePayload();
        change.value(p);
        expect(
          () => fakeAuthenticatedManifest(
            utf8.encode(jsonEncode(p)),
            publicKeys: const [],
          ),
          throwsA(isA<MacUpdateManifestException>()),
        );
      });
    }
    test('inner and outer schemas must agree', () {
      expect(
        () => parseVerifiedMacUpdatePayload(
          {...releasePayload(), 'schema': 1.0},
          Uint8List(0),
          1,
        ),
        throwsA(isA<MacUpdateManifestException>()),
      );
      expect(
        () => parseVerifiedMacUpdatePayload(releasePayload(), Uint8List(0), 2),
        throwsA(isA<MacUpdateManifestException>()),
      );
    });
    test('strict semantic order includes numeric prerelease ordering', () {
      final versions = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.2',
        '1.0.0-alpha.10',
        '1.0.0-beta',
        '1.0.0',
        '1.0.1',
      ];
      for (var i = 1; i < versions.length; i++) {
        expect(
          ReleaseSemVer.tryParse(
            versions[i],
          )!.compareTo(ReleaseSemVer.tryParse(versions[i - 1])!),
          greaterThan(0),
        );
      }
      expect(
        ReleaseSemVer.tryParse(
          '1.0.0+2',
        )!.compareTo(ReleaseSemVer.tryParse('1.0.0+1')!),
        0,
      );
      for (final value in ['01.0.0', '1.0', '1.0.0-01', '1.0.0-', 'v1.0.0']) {
        expect(ReleaseSemVer.tryParse(value), isNull);
      }
    });
    test('global build and semantic floors both hold across channels', () {
      bool eligible(MacUpdateManifest m, {bool beta = true}) =>
          macUpdateEligible(
            m,
            installedBuild: 2026111903,
            installedVersion: '1.1.0-beta.2',
            allowBeta: beta,
          );
      expect(
        eligible(releaseManifest(build: 2026111904, version: '1.0.0')),
        isFalse,
      );
      expect(
        eligible(releaseManifest(build: 2026111903, version: '1.1.0')),
        isFalse,
      );
      expect(
        eligible(releaseManifest(build: 2026111902, version: '2.0.0')),
        isFalse,
      );
      expect(
        eligible(
          releaseManifest(
            channel: 'beta',
            build: 2026111904,
            version: '1.1.0-beta.3',
          ),
          beta: false,
        ),
        isFalse,
      );
      expect(
        eligible(
          releaseManifest(build: 2026111904, version: '1.1.0'),
          beta: false,
        ),
        isTrue,
      );
    });
  });
  group('bounded discovery with fake authentication boundary', () {
    late Request request;
    late Routes routes;
    final stable = releasePayload();
    final beta = releasePayload(
      channel: 'beta',
      build: 2026111903,
      version: '1.1.0-beta.1',
    );
    Future<UpdateCheck> check({bool allowBeta = true, int pageLimit = 5}) =>
        request.checkForMacUpdate(
          installedBuild: 2026111901,
          installedVersion: '0.9.15-mitm.12',
          arch: 'arm64',
          allowBeta: allowBeta,
          pageLimit: pageLimit,
          systemVersion: '14.0',
        );
    void use(FutureOr<ResponseBody> Function(RequestOptions) answer) {
      routes = Routes(answer);
      request = Request(openMacManifest: fakeAuthenticatedManifest)
        ..releaseDio.httpClientAdapter = routes;
    }

    test('default stable does not discover beta', () async {
      use((o) {
        expect(o.uri.path, contains('/latest/'));
        return jsonBody(stable);
      });
      expect(
        (await check(allowBeta: false) as UpdateAvailable).manifest!.channel,
        ReleaseChannel.stable,
      );
      expect(routes.calls, hasLength(1));
    });
    test(
      'beta is discovered on second page despite arbitrary API ordering',
      () async {
        use((o) {
          if (o.uri.path.contains('/latest/')) return jsonBody(stable);
          if (o.uri.host == 'api.github.com') {
            return jsonBody(
              o.uri.queryParameters['page'] == '1'
                  ? List.generate(100, (_) => {'draft': true})
                  : [locator('v1.1.0-beta.1', beta: true)],
            );
          }
          return jsonBody(beta);
        });
        final result = await check() as UpdateAvailable;
        expect(result.manifest!.channel, ReleaseChannel.beta);
        expect(result.discoveryIncomplete, isFalse);
        expect(
          routes.calls.any((c) => c.uri.queryParameters['page'] == '2'),
          isTrue,
        );
      },
    );
    test('stable union beta selects newer stable, not beta-only', () async {
      use(
        (o) => o.uri.path.contains('/latest/')
            ? jsonBody(releasePayload(build: 2026111904, version: '1.2.0'))
            : o.uri.host == 'api.github.com'
            ? jsonBody([locator('v1.1.0-beta.1', beta: true)])
            : jsonBody(beta),
      );
      expect(
        (await check() as UpdateAvailable).manifest!.channel,
        ReleaseChannel.stable,
      );
    });
    test('complete empty beta list still offers stable', () async {
      use(
        (o) => o.uri.host == 'api.github.com' ? jsonBody([]) : jsonBody(stable),
      );
      expect((await check() as UpdateAvailable).discoveryIncomplete, isFalse);
    });
    for (final failure in [
      'rate limit',
      'page bound',
      'locator mismatch',
      'tag mismatch',
    ]) {
      test(
        '$failure preserves stable with partial warning, not false latest',
        () async {
          use((o) {
            if (o.uri.path.contains('/latest/')) return jsonBody(stable);
            if (o.uri.host == 'api.github.com') {
              return switch (failure) {
                'rate limit' => ResponseBody.fromString('', 403),
                'page bound' => jsonBody(
                  List.generate(100, (_) => {'draft': true}),
                ),
                'tag mismatch' => jsonBody([locator('different', beta: true)]),
                _ => jsonBody([locator('v1.1.0-beta.1')]),
              };
            }
            return jsonBody(beta);
          });
          final result = await check(pageLimit: 1) as UpdateAvailable;
          expect(result.manifest!.channel, ReleaseChannel.stable);
          expect(result.discoveryIncomplete, isTrue);
        },
      );
    }
    test('partial without candidate is failure, never up-to-date', () async {
      use(
        (o) => o.uri.host == 'api.github.com'
            ? ResponseBody.fromString('', 403)
            : jsonBody(releasePayload(build: 2026111901)),
      );
      expect(await check(), isA<UpdateCheckFailed>());
    });
    test('beta at stable endpoint fails even for opted-in user', () async {
      use(
        (o) => o.uri.host == 'api.github.com' ? jsonBody([]) : jsonBody(beta),
      );
      expect(await check(), isA<UpdateCheckFailed>());
    });
    test(
      'ETag only reuses authenticated bytes and changed identity fails closed',
      () async {
        var count = 0;
        use((o) {
          count++;
          if (count == 2) {
            expect(o.headers[HttpHeaders.ifNoneMatchHeader], 'fixture-etag');
            return ResponseBody.fromString('', 304);
          }
          return jsonBody(
            count == 3 ? {...stable, 'notes': 'replaced'} : stable,
            headers: {
              'etag': ['fixture-etag'],
            },
          );
        });
        expect(await check(allowBeta: false), isA<UpdateAvailable>());
        expect(await check(allowBeta: false), isA<UpdateAvailable>());
        expect(await check(allowBeta: false), isA<UpdateCheckFailed>());
      },
    );
    test('global same-build conflicting channels fail closed', () async {
      use(
        (o) => o.uri.path.contains('/latest/')
            ? jsonBody(stable)
            : o.uri.host == 'api.github.com'
            ? jsonBody([locator('v1.1.0-beta.1', beta: true)])
            : jsonBody(
                releasePayload(
                  channel: 'beta',
                  build: 2026111902,
                  version: '1.1.0-beta.1',
                ),
              ),
      );
      expect(await check(), isA<UpdateCheckFailed>());
    });
    test('response bytes are capped before parsing', () async {
      use(
        (_) => ResponseBody.fromBytes(
          List.filled(macUpdateManifestMaxBytes + 1, 65),
          200,
        ),
      );
      expect(await check(allowBeta: false), isA<UpdateCheckFailed>());
    });
  });
}
