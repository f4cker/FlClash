import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _NativeSysctlByName =
    Int32 Function(
      Pointer<Utf8>,
      Pointer<Void>,
      Pointer<Size>,
      Pointer<Void>,
      Size,
    );
typedef MacBootSysctlByName =
    int Function(
      Pointer<Utf8>,
      Pointer<Void>,
      Pointer<Size>,
      Pointer<Void>,
      int,
    );

/// Reads the kernel boot-session UUID. Recorded in the helper repair record as
/// a diagnostic field only: no decision depends on it (nothing waits for a
/// reboot). The kern.bootsessionuuid name is not declared in the public SDK;
/// an unavailable or malformed value throws and is simply not recorded.
Future<String> readMacBootSession() async {
  if (!Platform.isMacOS) throw UnsupportedError('macOS sysctl required');
  final sysctl = DynamicLibrary.process()
      .lookupFunction<_NativeSysctlByName, MacBootSysctlByName>('sysctlbyname');
  return readMacBootSessionWithSysctl(sysctl);
}

/// Injects the native call for tests; does not use a boot-time fallback.
String readMacBootSessionWithSysctl(MacBootSysctlByName sysctl) {
  final name = 'kern.bootsessionuuid'.toNativeUtf8();
  final value = calloc<Uint8>(37);
  final length = calloc<Size>();
  try {
    length.value = 37;
    if (sysctl(name, value.cast(), length, nullptr, 0) != 0 ||
        length.value != 37 ||
        value[36] != 0) {
      throw StateError('Cannot read macOS boot-session UUID');
    }
    final uuid = ascii.decode(value.asTypedList(36));
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(uuid)) {
      throw const FormatException('Invalid macOS boot-session UUID');
    }
    return uuid.toLowerCase();
  } finally {
    calloc.free(length);
    calloc.free(value);
    malloc.free(name);
  }
}
