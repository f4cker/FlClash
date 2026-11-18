import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:typed_data';

import 'ed25519.dart';

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
    required this.build,
    required this.helperBuild,
    required this.minimumSystemVersion,
    required this.notes,
    required this.published,
    required this.assets,
    required this.envelope,
  });

  String get tag => 'v$version';

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
  if (envelope['schema'] != 1) {
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
  return _parsePayload(payload, Uint8List.fromList(bytes));
}

MacUpdateManifest _parsePayload(List<int> payload, Uint8List envelope) {
  final data = _json(payload);
  if (data is! Map<String, dynamic>) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'payload',
    );
  }
  if (data['schema'] != 1) {
    throw const MacUpdateManifestException(MacUpdateRejection.unknownSchema);
  }
  if (data['product'] != macUpdateProduct) {
    throw const MacUpdateManifestException(MacUpdateRejection.wrongProduct);
  }
  final version = _string(data, 'version', pattern: _versionPattern);
  final assets = data['assets'];
  if (assets is! List || assets.isEmpty || assets.length > 8) {
    throw const MacUpdateManifestException(
      MacUpdateRejection.malformed,
      'assets',
    );
  }
  return MacUpdateManifest(
    version: version,
    build: _build(data, 'build'),
    helperBuild: _build(data, 'helperBuild'),
    minimumSystemVersion: _string(
      data,
      'minimumSystemVersion',
      pattern: RegExp(r'^[0-9]{1,3}(\.[0-9]{1,3}){0,2}$'),
    ),
    notes: _string(data, 'notes', maxLength: _maxNotesLength, allowEmpty: true),
    published: _string(data, 'published', maxLength: 64),
    assets: [for (final asset in assets) _asset(asset, version)],
    envelope: envelope,
  );
}

final _versionPattern = RegExp(r'^[0-9A-Za-z.+-]{1,64}$');

MacUpdateAsset _asset(Object? value, String version) {
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
  if (value is! int || value <= 0) {
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
