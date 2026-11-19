import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:typed_data';

import 'ed25519.dart';

const macReleaseRepository = 'f4cker/flash-releases';
const macLegacyBuildCeiling = 2026111901;

enum ReleaseChannel { stable, beta }

const macUpdateProduct = 'com.layoute.flash';
const macUpdateManifestMaxBytes = 256 * 1024;
const _maxAssetBytes = 2 * 1024 * 1024 * 1024;
const _maxNotesLength = 20000;

enum MacUpdateRejection {
  notConfigured,
  malformed,
  unknownSchema,
  badSignature,
  wrongProduct,
  insecureUrl,
}

final class MacUpdateManifestException implements Exception {
  final MacUpdateRejection reason;
  final String detail;

  const MacUpdateManifestException(this.reason, [this.detail = '']);

  @override
  String toString() => 'MacUpdateManifestException(${reason.name}): $detail';
}

final class MacUpdateAsset {
  final String arch;
  final String name;
  final Uri url;
  final int size;
  final String sha256;

  const MacUpdateAsset({
    required this.arch,
    required this.name,
    required this.url,
    required this.size,
    required this.sha256,
  });
}

final class MacUpdateManifest {
  final String version;
  final ReleaseChannel? channel;
  final String? releaseVersion;
  final String? releaseTag;
  final int build;
  final int helperBuild;
  final String minimumSystemVersion;
  final String notes;
  final String published;
  final List<MacUpdateAsset> assets;

  /// The signed bytes as fetched; the native installer verifies them again.
  final Uint8List envelope;

  const MacUpdateManifest({
    required this.version,
    this.channel,
    this.releaseVersion,
    this.releaseTag,
    required this.build,
    required this.helperBuild,
    required this.minimumSystemVersion,
    required this.notes,
    required this.published,
    required this.assets,
    required this.envelope,
  });

  String get tag => releaseTag ?? 'v$version';

  String get fullVersion => '${releaseVersion ?? version}+$build';

  bool permitted(bool allowBeta) =>
      channel == ReleaseChannel.stable ||
      (allowBeta && channel == ReleaseChannel.beta);

  MacUpdateAsset? assetFor(String arch) {
    for (final asset in assets) {
      if (asset.arch == arch) return asset;
    }
    return null;
  }
}

String? macUpdateArch(Abi abi) => switch (abi) {
  Abi.macosArm64 => 'arm64',
  Abi.macosX64 => 'amd64',
  _ => null,
};

String macUpdateAssetName(String version, String arch) =>
    'Flash-$version-macos-$arch.zip';

/// Whether [publicKey] is a pinned Ed25519 key (base64 of 32 bytes).
bool macUpdateKeyPinned(String publicKey) => _base64(publicKey)?.length == 32;

/// Whether any of [publicKeys] is a pinned Ed25519 key.
bool macUpdateKeysPinned(Iterable<String> publicKeys) =>
    publicKeys.any(macUpdateKeyPinned);

/// Opens a manifest.json envelope `{schema, payload, signature}`: the
/// signature covers the payload's raw bytes, so nothing is canonicalized.
/// The signature has to verify with one of [publicKeys] (the primary and
/// backup release keys); entries that are not 32-byte keys are ignored.
MacUpdateManifest openMacUpdateManifest(
  List<int> bytes, {
  required Iterable<String> publicKeys,
}) {
  final keys = [
    for (final publicKey in publicKeys)
      if (_base64(publicKey) case final key? when key.length == 32) key,
  ];
  if (keys.isEmpty) {
    throw const MacUpdateManifestException(MacUpdateRejection.notConfigured);
  }
  if (bytes.length > macUpdateManifestMaxBytes) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'too large',
    );
  }
  final envelope = _json(bytes);
  if (envelope is! Map<String, dynamic> ||
      !_sameKeys(envelope, const {'schema', 'payload', 'signature'})) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'envelope',
    );
  }
  if (envelope['schema'] is! int ||
      (envelope['schema'] != 1 && envelope['schema'] != 2)) {
    throw const MacUpdateManifestException(MacUpdateRejection.unknownSchema);
  }
  final payload = _base64(envelope['payload']);
  final signature = _base64(envelope['signature']);
  if (payload == null || signature == null || signature.length != 64) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'encoding',
    );
  }
  if (!keys.any(
    (key) =>
        ed25519Verify(publicKey: key, message: payload, signature: signature),
  )) {
    throw const MacUpdateManifestException(MacUpdateRejection.badSignature);
  }
  return parseVerifiedMacUpdatePayload(
    _json(payload),
    Uint8List.fromList(bytes),
    envelope['schema'] as int,
  );
}

MacUpdateManifest parseVerifiedMacUpdatePayload(
  Object? data,
  Uint8List envelope,
  int schema,
) {
  if (data is! Map<String, dynamic>) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'payload',
    );
  }
  if (data['schema'] is! int ||
      data['schema'] != schema ||
      (schema != 1 && schema != 2)) {
    throw const MacUpdateManifestException(MacUpdateRejection.unknownSchema);
  }
  if (data['product'] != macUpdateProduct) {
    throw const MacUpdateManifestException(MacUpdateRejection.wrongProduct);
  }
  final version = _string(data, 'version', pattern: _versionPattern);
  final build = _build(data, 'build');
  ReleaseChannel? channel;
  String? releaseVersion;
  String? releaseTag;
  if (data.containsKey('channel')) {
    channel = switch (data['channel']) {
      'stable' when schema == 1 => ReleaseChannel.stable,
      'beta' when schema == 2 => ReleaseChannel.beta,
      _ => throw const MacUpdateManifestException(
        MacUpdateRejection.malformed,
        'channel/schema',
      ),
    };
    final release = data['release'];
    if (data['platform'] != 'macos' ||
        release is! Map<String, dynamic> ||
        release['repository'] != macReleaseRepository ||
        release['sourceRepository'] != 'f4cker/FlClash') {
      throw const MacUpdateManifestException(
        MacUpdateRejection.malformed,
        'release identity',
      );
    }
    releaseTag = _string(
      release,
      'tag',
      pattern: RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$'),
    );
    releaseVersion = _string(release, 'version', maxLength: 128);
    if (ReleaseSemVer.tryParse(releaseVersion) == null) {
      throw const MacUpdateManifestException(
        MacUpdateRejection.malformed,
        'release version',
      );
    }
    _string(release, 'sourceCommit', pattern: RegExp(r'^[0-9a-f]{40}$'));
    _string(
      release,
      'sourceBranch',
      pattern: RegExp(r'^[A-Za-z0-9][A-Za-z0-9/._+-]{0,127}$'),
    );
  } else if (schema != 1 || build > macLegacyBuildCeiling) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'missing channel',
    );
  }
  final assets = data['assets'];
  if (assets is! List || assets.isEmpty || assets.length > 8) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'assets',
    );
  }
  final parsedAssets = [
    for (final asset in assets) _asset(asset, version, releaseTag),
  ];
  if (parsedAssets.map((a) => a.arch).toSet().length != parsedAssets.length) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'duplicate architecture',
    );
  }
  return MacUpdateManifest(
    version: version,
    channel: channel,
    releaseVersion: releaseVersion,
    releaseTag: releaseTag,
    build: build,
    helperBuild: _build(data, 'helperBuild'),
    minimumSystemVersion: _string(
      data,
      'minimumSystemVersion',
      pattern: RegExp(r'^[0-9]{1,3}(\.[0-9]{1,3}){0,2}$'),
    ),
    notes: _string(data, 'notes', maxLength: _maxNotesLength, allowEmpty: true),
    published: _string(data, 'published', maxLength: 64),
    assets: parsedAssets,
    envelope: envelope,
  );
}

final _versionPattern = RegExp(r'^[0-9A-Za-z.+-]{1,64}$');

MacUpdateAsset _asset(Object? value, String version, String? tag) {
  if (value is! Map<String, dynamic>) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'asset',
    );
  }
  final arch = _string(value, 'arch', pattern: RegExp(r'^(arm64|amd64)$'));
  final name = _string(value, 'name');
  if (name != macUpdateAssetName(version, arch)) {
    throw MacUpdateManifestException(MacUpdateRejection.malformed, name);
  }
  final url = Uri.tryParse(_string(value, 'url', maxLength: 2048));
  if (url == null || url.scheme != 'https' || url.host.isEmpty) {
    throw const MacUpdateManifestException(MacUpdateRejection.insecureUrl);
  }
  if (tag != null && (url != macReleaseAssetUri(tag, name))) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.insecureUrl,
      'asset identity',
    );
  }
  final size = value['size'];
  if (size is! int || size <= 0 || size > _maxAssetBytes) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'size',
    );
  }
  return MacUpdateAsset(
    arch: arch,
    name: name,
    url: url,
    size: size,
    sha256: _string(value, 'sha256', pattern: RegExp(r'^[0-9a-f]{64}$')),
  );
}

Object? _json(List<int> bytes) {
  try {
    return jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'json',
    );
  }
}

Uint8List? _base64(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return base64.decode(value);
  } on FormatException {
    return null;
  }
}

bool _sameKeys(Map<String, dynamic> map, Set<String> keys) =>
    map.length == keys.length && keys.every(map.containsKey);

String _string(
  Map<String, dynamic> map,
  String key, {
  RegExp? pattern,
  int maxLength = 256,
  bool allowEmpty = false,
}) {
  final value = map[key];
  if (value is! String ||
      (value.isEmpty && !allowEmpty) ||
      value.length > maxLength ||
      (pattern != null && !pattern.hasMatch(value))) {
    throw MacUpdateManifestException(MacUpdateRejection.malformed, key);
  }
  return value;
}

int _build(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! int || value <= 0 || value > 999999999999999999) {
    throw MacUpdateManifestException(MacUpdateRejection.malformed, key);
  }
  return value;
}

/// The installed CFBundleVersion; null when it is not a build number, which
/// leaves nothing to compare a manifest with.
int? macBuildNumber(String value) {
  if (!RegExp(r'^[1-9][0-9]{0,17}$').hasMatch(value)) return null;
  return int.parse(value);
}

/// Only a strictly higher build is an update: an equal or older one is not
/// offered, whatever its version string says.
bool macUpdateIsNewer(MacUpdateManifest manifest, int installedBuild) =>
    manifest.build > installedBuild;

Uri macReleaseAssetUri(String tag, String name) => Uri.https(
  'github.com',
  '/$macReleaseRepository/releases/download/$tag/$name',
);

final class ReleaseSemVer implements Comparable<ReleaseSemVer> {
  const ReleaseSemVer(this.numbers, this.pre);
  final List<int> numbers;
  final List<String> pre;
  static ReleaseSemVer? tryParse(String value) {
    final match = RegExp(
      r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
    ).firstMatch(value);
    if (match == null || value.length > 128) return null;
    const offset = 1;
    final numbers = [
      for (var i = offset; i < offset + 3; i++) int.tryParse(match[i]!),
    ];
    if (numbers.any((n) => n == null)) return null;
    final pre = match[offset + 3]?.split('.') ?? const <String>[];
    if (pre.any((p) => RegExp(r'^0[0-9]+$').hasMatch(p))) return null;
    return ReleaseSemVer(numbers.cast<int>(), pre);
  }

  @override
  int compareTo(ReleaseSemVer other) {
    for (var i = 0; i < 3; i++) {
      final order = numbers[i].compareTo(other.numbers[i]);
      if (order != 0) return order;
    }
    if (pre.isEmpty || other.pre.isEmpty) {
      return pre.isEmpty == other.pre.isEmpty ? 0 : (pre.isEmpty ? 1 : -1);
    }
    for (var i = 0; i < pre.length && i < other.pre.length; i++) {
      final a = pre[i], b = other.pre[i];
      final numericA = RegExp(r'^[0-9]+$').hasMatch(a);
      final numericB = RegExp(r'^[0-9]+$').hasMatch(b);
      final order = numericA && numericB
          ? (a.length == b.length
                ? a.compareTo(b)
                : a.length.compareTo(b.length))
          : numericA != numericB
          ? (numericA ? -1 : 1)
          : a.compareTo(b);
      if (order != 0) return order;
    }
    return pre.length.compareTo(other.pre.length);
  }
}

bool macUpdateEligible(
  MacUpdateManifest manifest, {
  required int installedBuild,
  required String installedVersion,
  required bool allowBeta,
}) {
  final current = ReleaseSemVer.tryParse(installedVersion);
  final candidate = ReleaseSemVer.tryParse(manifest.releaseVersion ?? '');
  return manifest.permitted(allowBeta) &&
      manifest.build > installedBuild &&
      current != null &&
      candidate != null &&
      candidate.compareTo(current) >= 0;
}

final class MacInstalledIdentity {
  const MacInstalledIdentity({
    required this.version,
    required this.build,
    this.channel,
  });
  final String version;
  final int build;
  final ReleaseChannel? channel;
  String get fullVersion => '$version+$build';
  static MacInstalledIdentity? fromAnswer(Object? value) {
    if (value is! Map ||
        value['version'] is! String ||
        value['build'] is! int) {
      return null;
    }
    final version = value['version'] as String;
    final build = value['build'] as int;
    final channel = switch (value['channel']) {
      'stable' => ReleaseChannel.stable,
      'beta' => ReleaseChannel.beta,
      _ => null,
    };
    if (ReleaseSemVer.tryParse(version) == null ||
        build <= 0 ||
        (channel == null &&
            (value.containsKey('channel') || build > macLegacyBuildCeiling))) {
      return null;
    }
    return MacInstalledIdentity(
      version: version,
      build: build,
      channel: channel,
    );
  }
}

bool macSystemSupports(String minimum, String current) {
  List<int>? parts(String value) {
    final match = RegExp(
      r'([0-9]+)\.([0-9]+)(?:\.([0-9]+))?',
    ).firstMatch(value);
    return match == null
        ? null
        : [
            int.parse(match[1]!),
            int.parse(match[2]!),
            int.parse(match[3] ?? '0'),
          ];
  }

  final requiredVersion = parts(minimum.contains('.') ? minimum : '$minimum.0');
  final systemVersion = parts(current);
  if (requiredVersion == null || systemVersion == null) return false;
  for (var i = 0; i < 3; i++) {
    if (systemVersion[i] != requiredVersion[i]) {
      return systemVersion[i] > requiredVersion[i];
    }
  }
  return true;
}
