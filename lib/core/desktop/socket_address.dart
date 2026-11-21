import 'dart:convert';
import 'dart:ffi';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/constant.dart' show packageName;
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// macOS `sun_path` holds 104 bytes, the terminating NUL included.
const maxUnixSocketPathLength = 103;

/// Fresh names tried when a bind finds its name taken.
const unixSocketBindAttempts = 8;

/// `_CS_DARWIN_USER_TEMP_DIR` from `<unistd.h>`.
const _csDarwinUserTempDir = 65537;
const _nameBytes = 16;
const _nameSuffix = '.sock';
const _base32 = 'abcdefghijklmnopqrstuvwxyz234567';

/// 128 bits from a CSPRNG, base32 (26 characters).
String randomSocketName([Random? random]) {
  final source = random ?? Random.secure();
  var bits = 0;
  var pending = 0;
  final buffer = StringBuffer();
  for (var i = 0; i < _nameBytes; i++) {
    pending = (pending << 8) | source.nextInt(256);
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      buffer.write(_base32[(pending >> bits) & 31]);
    }
    pending &= (1 << bits) - 1;
  }
  if (bits > 0) buffer.write(_base32[(pending << (5 - bits)) & 31]);
  return '$buffer$_nameSuffix';
}

/// The length of every name [randomSocketName] returns.
final int _nameLength = (_nameBytes * 8 / 5).ceil() + _nameSuffix.length;

int _bytes(String value) => utf8.encode(value).length;

/// Validates what `confstr(_CS_DARWIN_USER_TEMP_DIR)` returned and drops the
/// trailing slash. Nothing else is ever used as the base: no `$TMPDIR`, no
/// `/tmp`.
String userTempDirFrom(String? raw) {
  if (raw == null || raw.isEmpty) {
    throw StateError(
      'The per-user temp dir is unavailable: '
      'confstr(_CS_DARWIN_USER_TEMP_DIR) failed; not falling back to /tmp',
    );
  }
  if (!raw.startsWith('/')) {
    throw StateError(
      'The per-user temp dir "$raw" is not an absolute path; '
      'not falling back to /tmp',
    );
  }
  var base = raw;
  while (base.length > 1 && base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return base;
}

typedef _ConfstrNative = Size Function(Int32, Pointer<Utf8>, Size);
typedef _Confstr = int Function(int, Pointer<Utf8>, int);

/// `confstr(_CS_DARWIN_USER_TEMP_DIR)`: `/var/folders/…/T`, owned by this
/// user and 0700.
String darwinUserTempDir() {
  final confstr = DynamicLibrary.process()
      .lookupFunction<_ConfstrNative, _Confstr>('confstr');
  final needed = confstr(_csDarwinUserTempDir, nullptr, 0);
  if (needed <= 0) return userTempDirFrom(null);
  final buffer = calloc<Uint8>(needed);
  try {
    final written = confstr(_csDarwinUserTempDir, buffer.cast(), needed);
    if (written <= 0 || written > needed) return userTempDirFrom(null);
    return userTempDirFrom(buffer.cast<Utf8>().toDartString());
  } finally {
    calloc.free(buffer);
  }
}

/// 32-bit FNV-1a, as 8 hex digits.
String _shortTag(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// One directory per app copy inside [base]: the sanitised bundle id when the
/// whole socket path then fits, otherwise `fl-<hash of the id>`. The name's
/// 128 bits are never shortened; if even the short form does not fit, this
/// fails instead of truncating or falling back.
String unixSocketSubdir({required String base, required String appId}) {
  final safe = appId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final candidates = [
    if (safe.isNotEmpty && !safe.startsWith('.')) safe,
    'fl-${_shortTag(appId)}',
  ];
  for (final subdir in candidates) {
    if (_bytes(base) + 1 + _bytes(subdir) + 1 + _nameLength <=
        maxUnixSocketPathLength) {
      return subdir;
    }
  }
  throw StateError(
    'The per-user temp dir $base (${_bytes(base)} bytes) leaves no room for '
    'a socket name with 128 random bits under the '
    '$maxUnixSocketPathLength-byte sun_path limit',
  );
}

String unixSocketAddress(String directory, [Random? random]) {
  final address = '$directory/${randomSocketName(random)}';
  if (_bytes(address) > maxUnixSocketPathLength) {
    throw StateError(
      'IPC socket path is ${_bytes(address)} bytes, over the '
      '$maxUnixSocketPathLength-byte sun_path limit: $address',
    );
  }
  return address;
}

/// The Rust server's marker for a bind that found its name taken.
bool isAddressInUse(Object error) => error.toString().startsWith('EADDRINUSE');

Future<String> _appId() async {
  var id = '';
  try {
    id = (await PackageInfo.fromPlatform()).packageName;
  } catch (_) {}
  if (id.isEmpty) id = packageName;
  if (kDebugMode && !id.endsWith('.debug')) id = '$id.debug';
  return id;
}

final Future<String> _directory = Future(() async {
  final base = darwinUserTempDir();
  return '$base/${unixSocketSubdir(base: base, appId: await _appId())}';
});

/// A new address for every bind attempt (macOS non-helper builds).
Future<String> nextUnixSocketAddress() async =>
    unixSocketAddress(await _directory);
