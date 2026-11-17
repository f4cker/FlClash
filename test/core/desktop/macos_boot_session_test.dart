import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:fl_clash/core/desktop/macos_boot_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uuid = '12345678-1234-ABCD-9876-1234567890AB';
  int write(
    Pointer<Utf8> name,
    Pointer<Void> output,
    Pointer<Size> length,
    Pointer<Void> newValue,
    int newLength,
  ) {
    expect(name.toDartString(), 'kern.bootsessionuuid');
    expect(length.value, 37);
    expect(newValue, nullptr);
    expect(newLength, 0);
    output.cast<Uint8>().asTypedList(37).setAll(0, [...ascii.encode(uuid), 0]);
    return 0;
  }

  test('validates and canonicalizes the boot UUID', () {
    expect(readMacBootSessionWithSysctl(write), uuid.toLowerCase());
    expect(
      () => readMacBootSessionWithSysctl((a, b, c, d, e) => -1),
      throwsStateError,
    );
    expect(
      () => readMacBootSessionWithSysctl((a, b, c, d, e) {
        c.value = 36;
        return 0;
      }),
      throwsStateError,
    );
    expect(
      () => readMacBootSessionWithSysctl((a, b, c, d, e) {
        write(a, b, c, d, e);
        b.cast<Uint8>()[36] = 1;
        return 0;
      }),
      throwsStateError,
    );
    expect(
      () => readMacBootSessionWithSysctl((a, b, c, d, e) {
        write(a, b, c, d, e);
        b.cast<Uint8>()[8] = 48;
        return 0;
      }),
      throwsFormatException,
    );
    expect(
      () => readMacBootSessionWithSysctl((a, b, c, d, e) {
        write(a, b, c, d, e);
        b.cast<Uint8>()[0] = 0;
        return 0;
      }),
      throwsFormatException,
    );
  });

  test('local macOS boot UUID is readable and stable', () async {
    if (!Platform.isMacOS) return;
    final first = await readMacBootSession();
    expect(
      first,
      matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')),
    );
    expect(await readMacBootSession(), first);
    final result = await Process.run('sysctl', ['-n', 'kern.bootsessionuuid']);
    expect(result.exitCode, 0);
    expect(first, (result.stdout as String).trim().toLowerCase());
  });
}
