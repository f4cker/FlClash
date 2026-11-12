import 'dart:io';

import 'package:fl_clash/common/macos_managed_native_library.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class _ExternalLibrary extends Mock implements ExternalLibrary {}

void main() {
  late Directory temporary;
  late String contents;
  late String executable;
  late String framework;
  late String library;
  late ExternalLibrary openedLibrary;
  late List<String> openedPaths;

  void createFile(String path) {
    File(path).parent.createSync(recursive: true);
    File(path).writeAsStringSync('fixture, not executable native code');
  }

  ExternalLibrary openLibrary(String path) {
    openedPaths.add(path);
    return openedLibrary;
  }

  ExternalLibrary? load({String? executablePath}) {
    return loadMacosManagedNativeLibrary(
      managedHelper: true,
      isMacOS: true,
      releaseMode: true,
      resolvedExecutable: () => executablePath ?? executable,
      openLibrary: openLibrary,
    );
  }

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('managed_native_library_');
    final root = temporary.resolveSymbolicLinksSync();
    contents = p.join(root, 'Renamed App.app', 'Contents');
    executable = p.join(contents, 'MacOS', 'Renamed App');
    framework = p.join(contents, 'Frameworks', 'rust_api.framework');
    library = p.join(framework, 'rust_api');
    createFile(executable);
    createFile(library);
    openedLibrary = _ExternalLibrary();
    openedPaths = [];
  });

  tearDown(() {
    temporary.deleteSync(recursive: true);
  });

  test(
    'the default flag preserves legacy loading without filesystem access',
    () {
      expect(
        loadMacosManagedNativeLibrary(
          isMacOS: true,
          resolvedExecutable: () => throw StateError('must not resolve'),
          canonicalize: (_) => throw StateError('must not inspect'),
          openLibrary: (_) => throw StateError('must not open'),
        ),
        isNull,
      );
    },
  );

  test('non-macOS platforms retain the default loader even with the flag', () {
    expect(
      loadMacosManagedNativeLibrary(
        managedHelper: true,
        isMacOS: false,
        resolvedExecutable: () => throw StateError('must not resolve'),
        canonicalize: (_) => throw StateError('must not inspect'),
        openLibrary: (_) => throw StateError('must not open'),
      ),
      isNull,
    );
  });

  test(
    'managed Debug and Profile fail before path lookup or native opening',
    () {
      expect(
        () => loadMacosManagedNativeLibrary(
          managedHelper: true,
          isMacOS: true,
          releaseMode: false,
          resolvedExecutable: () => throw StateError('must not resolve'),
          openLibrary: openLibrary,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('release build'),
          ),
        ),
      );
      expect(openedPaths, isEmpty);
    },
  );

  test('opens only the absolute library next to the actual app executable', () {
    expect(load(), same(openedLibrary));
    expect(openedPaths, [library]);
    expect(p.isAbsolute(openedPaths.single), isTrue);
  });

  test('accepts Flutter native-assets Versions/Current framework links', () {
    File(library).deleteSync();
    final binary = p.join(framework, 'Versions', 'A', 'rust_api');
    createFile(binary);
    Link(p.join(framework, 'Versions', 'Current')).createSync('A');
    Link(library).createSync('Versions/Current/rust_api');

    expect(load(), same(openedLibrary));
    expect(openedPaths, [binary]);
  });

  test('canonicalizes an app alias to the actual app bundle', () {
    final alias = p.join(temporary.path, 'App Alias.app');
    Link(alias).createSync(p.dirname(contents));

    expect(
      load(executablePath: p.join(alias, 'Contents', 'MacOS', 'Renamed App')),
      same(openedLibrary),
    );
    expect(openedPaths, [library]);
  });

  test('does not consult a working-directory development library', () {
    final cwd = Directory(p.join(temporary.path, 'untrusted'));
    cwd.createSync();
    createFile(
      p.join(cwd.path, 'rust', 'target', 'release', 'librust_api.dylib'),
    );
    final original = Directory.current;
    try {
      Directory.current = cwd;
      expect(load(), same(openedLibrary));
      expect(openedPaths, [library]);
      File(library).deleteSync();
      expect(load, throwsA(isA<FileSystemException>()));
      expect(openedPaths, [library]);
    } finally {
      Directory.current = original;
    }
  });

  for (final path in [
    'Flash.app/Contents/MacOS/Flash',
    '/usr/bin/dart',
    '/Flash.app/Contents/Resources/Flash',
    '/Flash.app/Contents/MacOS/../MacOS/Flash',
    '/Flash.app/Contents/MacOS/Flash/',
    '/Flash.app/Contents/MacOS/Flash\u0000',
    '/.app/Contents/MacOS/Flash',
  ]) {
    test(
      'rejects malformed executable path ${path.replaceAll('\u0000', 'NUL')}',
      () {
        expect(() => load(executablePath: path), throwsStateError);
        expect(openedPaths, isEmpty);
      },
    );
  }

  test('rejects a missing app executable', () {
    File(executable).deleteSync();
    expect(load, throwsA(isA<FileSystemException>()));
    expect(openedPaths, isEmpty);
  });

  test('rejects a directory in place of the app executable', () {
    File(executable).deleteSync();
    Directory(executable).createSync();
    expect(load, throwsStateError);
    expect(openedPaths, isEmpty);
  });

  test('rejects an executable link to a different app bundle', () {
    final other = p.join(
      temporary.path,
      'Other.app',
      'Contents',
      'MacOS',
      'Other',
    );
    createFile(other);
    File(executable).deleteSync();
    Link(executable).createSync(other);
    expect(load, throwsStateError);
    expect(openedPaths, isEmpty);
  });

  test('rejects a missing framework without a loader fallback', () {
    Directory(framework).deleteSync(recursive: true);
    expect(load, throwsA(isA<FileSystemException>()));
    expect(openedPaths, isEmpty);
  });

  test('rejects a directory in place of the library', () {
    File(library).deleteSync();
    Directory(library).createSync();
    expect(load, throwsStateError);
    expect(openedPaths, isEmpty);
  });

  test('rejects a dangling framework binary link', () {
    File(library).deleteSync();
    Link(library).createSync('Versions/Current/rust_api');
    expect(load, throwsA(isA<FileSystemException>()));
    expect(openedPaths, isEmpty);
  });

  test('rejects cyclic framework binary links', () {
    File(library).deleteSync();
    Link(library).createSync('rust_api');
    expect(load, throwsA(isA<FileSystemException>()));
    expect(openedPaths, isEmpty);
  });

  for (final target in ['outside', 'sibling-framework', 'prefix-lookalike']) {
    test('rejects a binary symlink escaping to $target', () {
      final destination = switch (target) {
        'sibling-framework' => p.join(
          contents,
          'Frameworks',
          'Other.framework',
          'rust_api',
        ),
        'prefix-lookalike' => p.join('$framework.untrusted', 'rust_api'),
        _ => p.join(temporary.path, 'outside', 'rust_api'),
      };
      createFile(destination);
      File(library).deleteSync();
      Link(library).createSync(destination);
      expect(load, throwsStateError);
      expect(openedPaths, isEmpty);
    });
  }

  test('rejects Versions/Current escaping the framework', () {
    File(library).deleteSync();
    final external = p.join(temporary.path, 'external-version');
    createFile(p.join(external, 'rust_api'));
    Directory(p.join(framework, 'Versions')).createSync();
    Link(p.join(framework, 'Versions', 'Current')).createSync(external);
    Link(library).createSync('Versions/Current/rust_api');
    expect(load, throwsStateError);
    expect(openedPaths, isEmpty);
  });

  for (final component in ['framework', 'Frameworks']) {
    test('rejects an aliased $component root outside its bundled location', () {
      final original = component == 'framework'
          ? framework
          : p.dirname(framework);
      final external = p.join(temporary.path, 'relocated-$component');
      Directory(original).renameSync(external);
      Link(original).createSync(external);
      expect(load, throwsStateError);
      expect(openedPaths, isEmpty);
    });
  }

  for (final malformed in [
    'relative/rust_api',
    '/bundle/../outside/rust_api',
    '/bundle/rust_api\u0000',
  ]) {
    test('rejects malformed canonical filesystem results $malformed', () {
      expect(
        () => loadMacosManagedNativeLibrary(
          managedHelper: true,
          isMacOS: true,
          releaseMode: true,
          resolvedExecutable: () => executable,
          canonicalize: (path) => path == library ? malformed : path,
          isFile: (_) => true,
          openLibrary: openLibrary,
        ),
        throwsStateError,
      );
      expect(openedPaths, isEmpty);
    });
  }

  test('propagates native opening failure without retrying another loader', () {
    final failure = ArgumentError('invalid fixture binary');
    expect(
      () => loadMacosManagedNativeLibrary(
        managedHelper: true,
        isMacOS: true,
        releaseMode: true,
        resolvedExecutable: () => executable,
        openLibrary: (path) {
          openedPaths.add(path);
          throw failure;
        },
      ),
      throwsA(same(failure)),
    );
    expect(openedPaths, [library]);
  });
}
