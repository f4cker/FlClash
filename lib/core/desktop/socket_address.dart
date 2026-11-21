import 'dart:ffi';
import 'dart:math';

import 'package:fl_clash/common/constant.dart' show packageName;
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// macOS `sun_path` holds 104 bytes, the terminating NUL included.
const maxUnixSocketPathLength = 103;

/// Fresh names tried when a bind finds its name taken.
const unixSocketBindAttempts = 8;

const _maxAppIdLength = 40;
const _nameBytes = 16;

/// `/tmp/<app id>-<uid>`: one owner-only directory per app copy and user, so
/// release (`com.layoute.flash`), debug (`….debug`) and the isolated test copy
/// (`….isolatedtest`) never share one. The Rust server creates it 0700 when it
/// is absent and refuses one that is a symlink, someone else's, or not 0700.
String unixSocketDirectory({required String appId, required int uid}) {
  var safe = appId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (safe.length > _maxAppIdLength) safe = safe.substring(0, _maxAppIdLength);
  if (safe.isEmpty || safe.startsWith('.')) safe = 'app$safe';
  return '/tmp/$safe-$uid';
}

/// 128 bits from a CSPRNG, as 32 hex digits.
String randomSocketName([Random? random]) {
  final source = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < _nameBytes; i++) {
    buffer.write(source.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return '$buffer.sock';
}

String unixSocketAddress(String directory, [Random? random]) {
  final address = '$directory/${randomSocketName(random)}';
  if (address.length > maxUnixSocketPathLength) {
    throw StateError(
      'IPC socket path is ${address.length} bytes, over the '
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

int _currentUid() => DynamicLibrary.process()
    .lookupFunction<Uint32 Function(), int Function()>('getuid')();

final Future<String> _directory = Future(
  () async => unixSocketDirectory(appId: await _appId(), uid: _currentUid()),
);

/// A new address for every bind attempt (macOS non-helper builds).
Future<String> nextUnixSocketAddress() async =>
    unixSocketAddress(await _directory);
