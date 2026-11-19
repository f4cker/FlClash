import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/common/mac_update.dart';

Map<String, dynamic> releasePayload({
  String channel = 'stable',
  int build = 2026111902,
  String version = '1.0.0',
  String? tag,
}) {
  final releaseTag = tag ?? 'v$version';
  const bundleVersion = '1.0.0';
  const name = 'Flash-$bundleVersion-macos-arm64.zip';
  return {
    'schema': channel == 'beta' ? 2 : 1,
    'product': macUpdateProduct,
    'platform': 'macos',
    'channel': channel,
    'version': bundleVersion,
    'build': build,
    'helperBuild': build,
    'minimumSystemVersion': '12.0',
    'notes': 'Fixture notes',
    'published': '2026-11-19T00:00:00Z',
    'release': {
      'repository': macReleaseRepository,
      'tag': releaseTag,
      'version': version,
      'sourceRepository': 'f4cker/FlClash',
      'sourceCommit': 'a' * 40,
      'sourceBranch': 'release/1.0',
    },
    'assets': [
      {
        'arch': 'arm64',
        'name': name,
        'url': macReleaseAssetUri(releaseTag, name).toString(),
        'size': 4,
        'sha256': 'a' * 64,
      },
    ],
  };
}

MacUpdateManifest fakeAuthenticatedManifest(
  List<int> bytes, {
  required Iterable<String> publicKeys,
}) {
  final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  return parseVerifiedMacUpdatePayload(
    payload,
    Uint8List.fromList(bytes),
    payload['schema'] as int,
  );
}

MacUpdateManifest releaseManifest({
  String channel = 'stable',
  int build = 2026111902,
  String version = '1.0.0',
}) => fakeAuthenticatedManifest(
  utf8.encode(
    jsonEncode(
      releasePayload(channel: channel, build: build, version: version),
    ),
  ),
  publicKeys: const [],
);
