import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('distributor activation cache', () {
    late Directory cache;
    late File lock;
    late File config;
    const pinnedLock = '''
packages:
  flutter_distributor:
    source: git
    description:
      url: https://github.com/chen08209/flutter_distributor.git
      ref: v0.6.11-flclash.5
      path: packages/flutter_distributor
''';

    setUp(() {
      cache = Directory.systemTemp.createTempSync('distributor-test-');
      final packageDir = p.join(
        cache.path,
        'global_packages',
        'flutter_distributor',
      );
      config = File(p.join(packageDir, '.dart_tool', 'package_config.json'));
      config.createSync(recursive: true);
      lock = File(p.join(packageDir, 'pubspec.lock'));
      lock.writeAsStringSync(pinnedLock);
    });

    tearDown(() => cache.deleteSync(recursive: true));

    test('reuses the exact pinned Git package', () {
      expect(setup.isDistributorActivated(cache.path), isTrue);
    });

    for (final entry in {
      'source': ['source: git', 'source: hosted'],
      'repository': ['chen08209/', 'another-owner/'],
      'tag': ['v0.6.11-flclash.5', 'v0.6.11-flclash.4'],
      'package path': ['packages/flutter_distributor', 'packages/other'],
    }.entries) {
      test('reactivates when ${entry.key} differs', () {
        lock.writeAsStringSync(
          pinnedLock.replaceFirst(entry.value[0], entry.value[1]),
        );
        expect(setup.isDistributorActivated(cache.path), isFalse);
      });
    }

    test('reactivates when the package configuration is missing', () {
      config.deleteSync();
      expect(setup.isDistributorActivated(cache.path), isFalse);
    });

    test('reactivates when the lockfile is missing or invalid', () {
      lock.deleteSync();
      expect(setup.isDistributorActivated(cache.path), isFalse);
      lock.writeAsStringSync('packages: [');
      expect(setup.isDistributorActivated(cache.path), isFalse);
      lock.writeAsStringSync('packages: {}');
      expect(setup.isDistributorActivated(cache.path), isFalse);
    });
  });

  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('accepts dev application environment', () {
      final results = setup.createSetupArgParser().parse([
        'android',
        '--env',
        'dev',
      ]);

      expect(results['env'], 'dev');
    });

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {'APP_ENV': 'dev'});
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test('refuses to package while a native build hook is skipped', () {
      const pubspec = '''
hooks:
  user_defines:
    setup:
      build_assets: false
    rust_api:
      build_assets: true
''';

      expect(setup.packagesNotBuildingAssets(pubspec), ['setup']);
      expect(setup.packagesNotBuildingAssets('name: x\n'), isEmpty);
    });

    test('packages every Linux format on every architecture', () {
      expect(setup.createPackageTargets('linux', null), 'deb,appimage,rpm');
      expect(setup.createPackageTargets('linux', 'deb'), 'deb');
      expect(setup.createPackageTargets('macos', null), 'dmg');
    });

    test('downloads the appimagetool build matching the host', () {
      expect(setup.appImageToolArch('arm64'), 'aarch64');
      expect(setup.appImageToolArch('amd64'), 'x86_64');
    });
  });
}
