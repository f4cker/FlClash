import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:objective_c/objective_c.dart';
import 'package:rust_api/rust_api.dart';
import 'package:sqlite3/sqlite3.dart';

import 'macos_managed_native_library.dart';

const nativeLoadVerificationFlag = '--flash-verify-native-loads';
const nativeLoadVerificationPrefix = 'FLASH_NATIVE_LOADS ';
const nativeLoadVerificationProbeIds = [
  'flutter_pixel',
  'rust_utf8',
  'objective_c_string',
  'sqlite_memory',
];
const _challengePrefix = '--challenge=';
const _timeout = Duration(seconds: 12);
const _flushTimeout = Duration(seconds: 2);

bool isNativeLoadVerificationRequested(List<String> args) => args.any((arg) {
  final lower = arg.toLowerCase();
  return lower.startsWith('--flash') ||
      lower.startsWith('-flash') ||
      lower.startsWith('--challenge') ||
      lower.contains('verify-native-load');
});

String? nativeLoadVerificationChallenge(List<String> args) {
  if (args.length != 2 ||
      args.first != nativeLoadVerificationFlag ||
      !args.last.startsWith(_challengePrefix)) {
    return null;
  }
  final token = args.last.substring(_challengePrefix.length);
  return RegExp(r'^[A-Za-z0-9_-]{16,64}$').stringMatch(token) == token
      ? token
      : null;
}

class NativeLoadVerificationRuntime {
  const NativeLoadVerificationRuntime({
    required this.isMacOS,
    required this.releaseMode,
    required this.managedHelper,
    required this.handshake,
    required this.probes,
    required this.writeLine,
    required this.flush,
    required this.terminate,
    this.timeout = _timeout,
  });

  final bool isMacOS;
  final bool releaseMode;
  final bool managedHelper;
  final Future<bool> Function(String) handshake;
  final List<Future<bool> Function()> probes;
  final void Function(String) writeLine;
  final Future<void> Function() flush;
  final void Function(int) terminate;
  final Duration timeout;
}

// No app-directed Flash config/data/cache/lock/keychain access or Core/helper,
// maintenance, service, login or network work. Cocoa/Flutter/WindowServer may
// still have OS-managed cache effects; this is not a sandbox.
Future<void> runNativeLoadVerification(
  List<String> args, {
  NativeLoadVerificationRuntime? runtime,
}) async {
  final host = runtime ?? _productionRuntime();
  final challenge = nativeLoadVerificationChallenge(args);
  final results = {for (final id in nativeLoadVerificationProbeIds) id: false};
  final done = Completer<void>();
  var finished = false;
  Timer? deadline;

  Future<void> finish(String code) async {
    if (finished) return;
    finished = true;
    deadline?.cancel();
    var status = code == 'ok' ? 0 : 70;
    try {
      host.writeLine(
        '$nativeLoadVerificationPrefix${jsonEncode({'schema': 1, 'challenge': challenge, 'ok': code == 'ok', 'code': code, 'probes': results})}',
      );
      await host.flush().timeout(_flushTimeout);
    } catch (_) {
      status = 70;
    } finally {
      try {
        host.terminate(status);
      } finally {
        done.complete();
      }
    }
  }

  runZonedGuarded(() {
    deadline = Timer(host.timeout, () => unawaited(finish('timeout')));
    unawaited(() async {
      if (challenge == null) {
        await finish('invalid_arguments');
        return;
      }
      if (!host.isMacOS || !host.releaseMode || !host.managedHelper) {
        await finish('unsupported_build');
        return;
      }
      if (!await host.handshake(challenge)) {
        await finish('native_handshake_failed');
        return;
      }
      if (finished) return;
      if (host.probes.length != nativeLoadVerificationProbeIds.length) {
        await finish('probe_failed');
        return;
      }
      for (var i = 0; i < host.probes.length; i++) {
        final passed = await host.probes[i]();
        if (finished) return;
        results[nativeLoadVerificationProbeIds[i]] = passed;
        if (!passed) {
          await finish('probe_failed');
          return;
        }
      }
      await finish('ok');
    }());
  }, (_, _) => unawaited(finish('probe_failed')));
  await done.future;
}

NativeLoadVerificationRuntime _productionRuntime() =>
    NativeLoadVerificationRuntime(
      isMacOS: Platform.isMacOS,
      releaseMode: kReleaseMode,
      managedHelper: const bool.fromEnvironment('MACOS_MANAGED_HELPER'),
      handshake: (challenge) async {
        WidgetsFlutterBinding.ensureInitialized();
        return await const MethodChannel(
              'flash/native_load_verification',
            ).invokeMethod<bool>('confirm', challenge) ==
            true;
      },
      probes: [_flutterPixel, _rustUtf8, _objectiveCString, _sqliteMemory],
      writeLine: stdout.writeln,
      flush: stdout.flush,
      terminate: exit,
    );

Future<bool> _flutterPixel() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xff123456), ui.BlendMode.src);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(1, 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return bytes != null &&
          bytes.lengthInBytes == 4 &&
          bytes.getUint8(0) == 0x12 &&
          bytes.getUint8(1) == 0x34 &&
          bytes.getUint8(2) == 0x56 &&
          bytes.getUint8(3) == 0xff;
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

Future<bool> _rustUtf8() async {
  try {
    await RustLib.init(externalLibrary: loadMacosManagedNativeLibrary());
    const text = 'flash-native-load-✓';
    final bytes = await transcodeCharset(
      bytes: utf8.encode(text),
      label: 'utf-8',
      lossy: false,
    );
    return bytes != null && utf8.decode(bytes) == text;
  } finally {
    if (isRustLibInitialized) RustLib.dispose();
  }
}

Future<bool> _objectiveCString() async => autoReleasePool(() {
  const text = 'flash-native-load-✓';
  final value = NSString(text);
  try {
    return value.toDartString() == text;
  } finally {
    value.ref.release();
  }
});

Future<bool> _sqliteMemory() async {
  final db = sqlite3.openInMemory();
  try {
    db.execute('PRAGMA temp_store = MEMORY');
    db.execute('CREATE TABLE proof (value TEXT NOT NULL)');
    const text = 'flash-native-load-✓';
    db.execute('INSERT INTO proof (value) VALUES (?)', [text]);
    final rows = db.select('SELECT value FROM proof');
    return rows.length == 1 && rows.single['value'] == text;
  } finally {
    db.close();
  }
}
