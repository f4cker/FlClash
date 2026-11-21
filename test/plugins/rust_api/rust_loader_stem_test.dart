import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/macos_managed_native_library.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:rust_api/src/rust/frb_generated.dart';

class _ExternalLibrary extends Mock implements ExternalLibrary {}

Directory _rustApiPackage() {
  for (var dir = Directory.current.absolute; ; dir = dir.parent) {
    final config = File(p.join(dir.path, '.dart_tool', 'package_config.json'));
    if (config.existsSync()) {
      final packages =
          (jsonDecode(config.readAsStringSync()) as Map)['packages'];
      for (final package in packages as List) {
        if (package['name'] == 'rust_api') {
          final rootUri = (package['rootUri'] as String).replaceAll(
            RegExp(r'/$'),
            '',
          );
          return Directory.fromUri(config.uri.resolve('$rootUri/'));
        }
      }
    }
    if (dir.parent.path == dir.path) {
      fail(
        'no package_config.json above ${Directory.current.path} has rust_api',
      );
    }
  }
}

String _cargoLibName() {
  final package = _rustApiPackage().path;
  final cargo = File(p.join(package, 'rust', 'Cargo.toml')).readAsStringSync();
  final lib = RegExp(
    r'^\[lib\]\s*\nname\s*=\s*"([^"]+)"',
    multiLine: true,
  ).firstMatch(cargo);
  expect(lib, isNotNull, reason: 'rust/Cargo.toml has no [lib] name');
  return lib!.group(1)!;
}

void main() {
  test('the default FRB loader stem is the Cargo [lib] name', () {
    final stem = RustLib.kDefaultExternalLibraryLoaderConfig.stem;

    expect(stem, isNot('UNKNOWN'));
    expect(stem, _cargoLibName());
    expect(stem, 'rust_api');
  });

  test('the default stem names the framework the managed loader opens', () {
    final opened = <String>[];
    loadMacosManagedNativeLibrary(
      managedHelper: true,
      isMacOS: true,
      releaseMode: true,
      resolvedExecutable: () => '/Applications/Flash.app/Contents/MacOS/Flash',
      canonicalize: (path) => path,
      isFile: (_) => true,
      openLibrary: (path) {
        opened.add(path);
        return _ExternalLibrary();
      },
    );

    final stem = RustLib.kDefaultExternalLibraryLoaderConfig.stem;
    expect(opened, hasLength(1));
    expect(p.basename(opened.single), stem);
    expect(p.basename(p.dirname(opened.single)), '$stem.framework');
  });
}
