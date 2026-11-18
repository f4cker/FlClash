import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/ed25519.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/common/mac_update.dart';
import 'package:fl_clash/common/package.dart';
import 'package:fl_clash/common/request.dart';
import 'package:flutter_test/flutter_test.dart';

// The fixtures are signed with a throwaway test key kept outside the
// repository (tool/macos/make_update_manifest.py); only its public half is here.
const _fixtures = 'test/fixtures/mac_update';
const _installedBuild = 2026111803;
const _rfcPublicKey = '11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=';

String _key() =>
    File('$_fixtures/test_public_key.txt').readAsStringSync().trim();

Uint8List _fixture(String name) =>
    File('$_fixtures/$name.json').readAsBytesSync();

List<int> _hex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];

class _RouteAdapter implements HttpClientAdapter {
  _RouteAdapter(this.answer);

  final ResponseBody Function(Uri uri) answer;
  final requested = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri);
    return answer(options.uri);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _redirect(String location) => ResponseBody.fromString(
  '',
  302,
  headers: {
    HttpHeaders.locationHeader: [location],
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ed25519Verify', () {
    test('accepts the RFC 8032 vectors and nothing altered', () {
      final emptySignature = _hex(
        'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155'
        '5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
      );
      final key = base64.decode(_rfcPublicKey);
      expect(
        ed25519Verify(publicKey: key, message: [], signature: emptySignature),
        isTrue,
      );
      expect(
        ed25519Verify(
          publicKey: _hex(
            '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
          ),
          message: [0x72],
          signature: _hex(
            '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da'
            '085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
          ),
        ),
        isTrue,
      );
      expect(
        ed25519Verify(publicKey: key, message: [0], signature: emptySignature),
        isFalse,
      );
      final flipped = [...emptySignature]..[40] ^= 1;
      expect(
        ed25519Verify(publicKey: key, message: [], signature: flipped),
        isFalse,
      );
    });

    test('refuses an identity key, a short key and a non-canonical S', () {
      final identity = [1, ...List.filled(31, 0)];
      expect(
        ed25519Verify(
          publicKey: identity,
          message: [],
          signature: [...identity, ...List.filled(32, 0)],
        ),
        isFalse,
      );
      expect(
        ed25519Verify(
          publicKey: List.filled(31, 0),
          message: [],
          signature: List.filled(64, 0),
        ),
        isFalse,
      );
      expect(
        ed25519Verify(
          publicKey: base64.decode(_rfcPublicKey),
          message: [],
          signature: [...List.filled(32, 0), ...List.filled(32, 0xff)],
        ),
        isFalse,
      );
    });
  });

  group('openMacUpdateManifest', () {
    test('reads a manifest signed with the pinned key', () {
      final manifest = openMacUpdateManifest(
        _fixture('newer'),
        publicKeys: [_key()],
      );
      expect(manifest.version, '0.9.15-mitm.7');
      expect(manifest.build, 2026111901);
      expect(manifest.helperBuild, 2026111901);
      expect(manifest.tag, 'v0.9.15-mitm.7');
      expect(manifest.notes, contains('新增应用内更新'));
      final asset = manifest.assetFor('arm64')!;
      expect(asset.name, 'Flash-0.9.15-mitm.7-macos-arm64.zip');
      expect(asset.url.scheme, 'https');
      expect(asset.size, 7);
      expect(manifest.envelope, _fixture('newer'));
    });

    MacUpdateRejection rejection(
      List<int> bytes, {
      String? key,
      List<String>? keys,
    }) {
      try {
        openMacUpdateManifest(bytes, publicKeys: keys ?? [key ?? _key()]);
      } on MacUpdateManifestException catch (error) {
        return error.reason;
      }
      fail('accepted');
    }

    // The fixtures' test key stands in for either pinned key; the other
    // slot holds a key that did not sign them.
    test('accepts a manifest signed by the primary key', () {
      final manifest = openMacUpdateManifest(
        _fixture('newer'),
        publicKeys: [_key(), _rfcPublicKey],
      );
      expect(manifest.build, 2026111901);
    });

    test('accepts a manifest signed by the backup key', () {
      final manifest = openMacUpdateManifest(
        _fixture('newer'),
        publicKeys: [_rfcPublicKey, _key()],
      );
      expect(manifest.build, 2026111901);
      expect(
        openMacUpdateManifest(
          _fixture('newer'),
          publicKeys: ['', _key()],
        ).build,
        2026111901,
      );
    });

    test('refuses a manifest signed by neither pinned key', () {
      expect(
        rejection(_fixture('newer'), keys: [_rfcPublicKey, macUpdatePublicKey]),
        MacUpdateRejection.badSignature,
      );
      expect(
        rejection(
          _fixture('newer'),
          keys: [macUpdatePublicKey, macUpdateBackupPublicKey],
        ),
        MacUpdateRejection.badSignature,
      );
      expect(
        rejection(_fixture('newer'), keys: const []),
        MacUpdateRejection.notConfigured,
      );
      expect(
        rejection(_fixture('newer'), keys: const ['', 'AAAA']),
        MacUpdateRejection.notConfigured,
      );
    });

    test('pins two distinct release keys', () {
      expect(macUpdatePublicKeys, hasLength(2));
      expect(macUpdatePublicKeys.every(macUpdateKeyPinned), isTrue);
      expect(macUpdatePublicKeys.toSet(), hasLength(2));
      expect(macUpdatePublicKeys, isNot(contains(_key())));
    });

    test('refuses a changed payload', () {
      final envelope =
          jsonDecode(utf8.decode(_fixture('newer'))) as Map<String, dynamic>;
      final payload = utf8
          .decode(base64.decode(envelope['payload'] as String))
          .replaceAll('2026111901', '2026111999');
      envelope['payload'] = base64.encode(utf8.encode(payload));
      expect(
        rejection(utf8.encode(jsonEncode(envelope))),
        MacUpdateRejection.badSignature,
      );
    });

    test('refuses a manifest signed with another key', () {
      expect(
        rejection(_fixture('newer'), key: _rfcPublicKey),
        MacUpdateRejection.badSignature,
      );
    });

    test('stays off without a pinned key', () {
      expect(
        rejection(_fixture('newer'), key: ''),
        MacUpdateRejection.notConfigured,
      );
    });

    test('refuses signed content it must not act on', () {
      expect(
        rejection(_fixture('wrong_product')),
        MacUpdateRejection.wrongProduct,
      );
      expect(
        rejection(_fixture('insecure_url')),
        MacUpdateRejection.insecureUrl,
      );
      expect(
        rejection(_fixture('unknown_schema')),
        MacUpdateRejection.unknownSchema,
      );
      expect(rejection(utf8.encode('{')), MacUpdateRejection.malformed);
      expect(
        rejection(utf8.encode('{"schema":1,"payload":"","signature":""}')),
        MacUpdateRejection.malformed,
      );
    });

    test('offers only a strictly higher build', () {
      bool newer(String name) => macUpdateIsNewer(
        openMacUpdateManifest(_fixture(name), publicKeys: [_key()]),
        _installedBuild,
      );
      expect(newer('newer'), isTrue);
      expect(newer('equal'), isFalse);
      expect(newer('older'), isFalse);
    });
  });

  group('checkForMacUpdate', () {
    Future<(UpdateCheck, _RouteAdapter)> check(
      ResponseBody Function(Uri uri) answer, {
      String arch = 'arm64',
    }) async {
      final adapter = _RouteAdapter(answer);
      final request = Request()..releaseDio.httpClientAdapter = adapter;
      final result = await request.checkForMacUpdate(
        installedBuild: _installedBuild,
        arch: arch,
        url:
            'https://github.com/f4cker/flash-releases/releases/latest/download/manifest.json',
        publicKeys: [_key()],
      );
      return (result, adapter);
    }

    test('asks nothing of the network without a pinned key', () async {
      final adapter = _RouteAdapter((_) => throw StateError('fetched'));
      final request = Request()..releaseDio.httpClientAdapter = adapter;
      final result = await request.checkForMacUpdate(
        installedBuild: _installedBuild,
        arch: 'arm64',
        publicKeys: const [''],
      );
      expect(
        result,
        isA<UpdateCheckFailed>().having(
          (failed) => failed.error,
          'error',
          isA<MacUpdateManifestException>().having(
            (error) => error.reason,
            'reason',
            MacUpdateRejection.notConfigured,
          ),
        ),
      );
      expect(adapter.requested, isEmpty);
    });

    test('follows HTTPS redirects to the manifest', () async {
      final (result, adapter) = await check(
        (uri) => switch (uri.host) {
          'github.com' => _redirect(
            'https://objects.example.com/manifest.json?token=1',
          ),
          _ => ResponseBody.fromBytes(_fixture('newer'), 200),
        },
      );
      expect(result, isA<UpdateAvailable>());
      final available = result as UpdateAvailable;
      expect(available.manifest!.build, 2026111901);
      expect(available.release['tag_name'], 'v0.9.15-mitm.7');
      expect(adapter.requested.last.host, 'objects.example.com');
    });

    test('is up to date for an equal or older build', () async {
      for (final name in ['equal', 'older']) {
        final (result, _) = await check(
          (_) => ResponseBody.fromBytes(_fixture(name), 200),
        );
        expect(result, isA<UpdateUpToDate>(), reason: name);
      }
    });

    test('finds no release without an asset for this Mac', () async {
      final (result, _) = await check(
        (_) => ResponseBody.fromBytes(_fixture('newer'), 200),
        arch: 'riscv64',
      );
      expect(result, isA<UpdateNoRelease>());
    });

    test('fails on a redirect to plain HTTP or a bad signature', () async {
      final (insecure, adapter) = await check(
        (uri) => uri.scheme == 'https'
            ? _redirect('http://mirror.example.com/manifest.json')
            : ResponseBody.fromBytes(_fixture('newer'), 200),
      );
      expect(insecure, isA<UpdateCheckFailed>());
      expect(adapter.requested, hasLength(1));
      final (forged, _) = await check(
        (_) => ResponseBody.fromBytes(_fixture('newer')..[60] ^= 1, 200),
      );
      expect(forged, isA<UpdateCheckFailed>());
    });
  });

  group('downloadMacUpdate', () {
    late Directory directory;
    final package = utf8.encode('package');

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('mac-update');
    });

    tearDown(() => directory.delete(recursive: true));

    MacUpdateAsset asset({String? digest}) => MacUpdateAsset(
      arch: 'arm64',
      name: 'Flash-1.0.0-macos-arm64.zip',
      url: Uri.parse('https://github.com/f4cker/flash-releases/a.zip'),
      size: package.length,
      sha256: digest ?? sha256.convert(package).toString(),
    );

    Future<String> download(List<int> body, {String? digest}) {
      final request = Request()
        ..releaseDio.httpClientAdapter = _RouteAdapter(
          (uri) => uri.host == 'github.com'
              ? _redirect('https://cdn.example.com/a.zip')
              : ResponseBody.fromBytes(body, 200),
        );
      return request.downloadMacUpdate(
        asset: asset(digest: digest),
        directory: directory.path,
      );
    }

    test('keeps an archive matching the signed size and digest', () async {
      final path = await download(package);
      expect(await File(path).readAsBytes(), package);
    });

    test('deletes an archive whose digest or size differs', () async {
      for (final body in [utf8.encode('packagf'), utf8.encode('package+')]) {
        await expectLater(
          download(body),
          throwsA(isA<ReleaseNotVerifiedException>()),
        );
      }
      await expectLater(
        download(package, digest: '0' * 64),
        throwsA(isA<ReleaseNotVerifiedException>()),
      );
      expect(directory.listSync(), isEmpty);
    });
  });

  group('versions', () {
    test('compareVersions orders pre-releases without throwing', () {
      expect(compareVersions('0.9.15-mitm.6', '0.9.15-mitm.7'), lessThan(0));
      expect(
        compareVersions('0.9.15-mitm.10', '0.9.15-mitm.9'),
        greaterThan(0),
      );
      expect(compareVersions('0.9.15', '0.9.15-mitm.6'), greaterThan(0));
      expect(compareVersions('0.9.16-mitm.1', '0.9.15'), greaterThan(0));
      expect(
        compareVersions('0.9.15-mitm.6+2026111803', '0.9.15-mitm.6+2026111901'),
        lessThan(0),
      );
      expect(compareVersions('0.9.15-mitm.6', '0.9.15-mitm.6'), 0);
      expect(compareVersions('x.y', '1'), lessThan(0));
    });

    test('macBuildNumber takes only a plain build number', () {
      expect(macBuildNumber('2026111803'), 2026111803);
      expect(macBuildNumber(''), isNull);
      expect(macBuildNumber('0123'), isNull);
      expect(macBuildNumber('1.2'), isNull);
    });
  });
}
