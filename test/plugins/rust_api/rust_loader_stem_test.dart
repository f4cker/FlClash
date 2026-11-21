// Regression: the flutter_rust_bridge regeneration in 9867150c emitted
// stem 'UNKNOWN', so the default loader asked dyld for
// 'UNKNOWN.framework/UNKNOWN' and RustLib.init failed. Only a
// MACOS_MANAGED_HELPER release passes its own ExternalLibrary; debug and
// non-managed builds use this default and must name the real crate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust_api/src/rust/frb_generated.dart';

void main() {
  test('the default FRB loader names the rust_api crate', () {
    final cargo = File('plugins/rust_api/rust/Cargo.toml').readAsStringSync();
    final lib = RegExp(
      r'^\[lib\]\s*\nname\s*=\s*"([^"]+)"',
      multiLine: true,
    ).firstMatch(cargo);
    expect(lib, isNotNull, reason: 'Cargo.toml has no [lib] name');
    expect(lib!.group(1), 'rust_api');
    expect(RustLib.kDefaultExternalLibraryLoaderConfig.stem, lib.group(1));
  });

  test('the bundled framework the loader falls back to is rust_api', () {
    // loadExternalLibraryRaw opens '<stem>.framework/<stem>' through the
    // app's rpath (@executable_path/../Frameworks) on macOS.
    final stem = RustLib.kDefaultExternalLibraryLoaderConfig.stem;
    expect('$stem.framework/$stem', 'rust_api.framework/rust_api');
  });
}
