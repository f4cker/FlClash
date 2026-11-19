import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('file_test');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  group('safeDeletePath', () {
    test('removes a file', () async {
      final path = join(root.path, 'config.yaml');
      File(path).writeAsStringSync('mixed-port: 7890');

      await safeDeletePath(path);

      expect(File(path).existsSync(), isFalse);
    });

    test('removes a directory along with everything under it', () async {
      final path = join(root.path, '42');
      File(join(path, 'proxies', 'abc'))
        ..createSync(recursive: true)
        ..writeAsStringSync('proxies: []');

      await safeDeletePath(path);

      expect(Directory(path).existsSync(), isFalse);
    });

    test('accepts a path that is already gone', () async {
      await expectLater(safeDeletePath(join(root.path, 'missing')), completes);
    });
  });

  group('writeAsStringAtomically', () {
    test('replaces the file and leaves nothing beside it', () async {
      final file = File(join(root.path, 'config.yaml'))
        ..writeAsStringSync('mixed-port: 7890');

      await file.writeAsStringAtomically('mixed-port: 7891');

      expect(file.readAsStringSync(), 'mixed-port: 7891');
      expect(root.listSync().map((entry) => basename(entry.path)), [
        'config.yaml',
      ]);
    });

    test('creates the directory a first write needs', () async {
      final file = File(join(root.path, 'home', 'config.yaml'));

      await file.writeAsStringAtomically('mode: rule');

      expect(file.readAsStringSync(), 'mode: rule');
    });

    test('keeps the old file when the new one cannot be written', () async {
      final file = File(join(root.path, 'config.yaml'))
        ..writeAsStringSync('mode: rule');
      // No temporary sibling can be created in a read-only directory.
      await Process.run('chmod', ['555', root.path]);
      addTearDown(() => Process.runSync('chmod', ['755', root.path]));

      await expectLater(
        file.writeAsStringAtomically('mode: global'),
        throwsA(isA<FileSystemException>()),
      );
      expect(file.readAsStringSync(), 'mode: rule');
    });

    test('removes its temporary file when the rename fails', () async {
      // A non-empty directory where the file goes refuses the rename.
      final target = Directory(join(root.path, 'config.yaml'))..createSync();
      File(join(target.path, 'occupied')).createSync();

      await expectLater(
        File(target.path).writeAsStringAtomically('mode: global'),
        throwsA(isA<FileSystemException>()),
      );
      expect(root.listSync().map((entry) => basename(entry.path)), [
        'config.yaml',
      ]);
    });

    test('overlapping writes to one file each land whole', () async {
      final file = File(join(root.path, 'config.yaml'));
      final contents = [for (var i = 0; i < 20; i++) 'mode: $i\n' * 2000];

      await Future.wait([
        for (final content in contents) file.writeAsStringAtomically(content),
      ]);

      expect(contents, contains(file.readAsStringSync()));
      expect(root.listSync().map((entry) => basename(entry.path)), [
        'config.yaml',
      ]);
    });

    test('gives each write its own temporary name', () {
      final names = {for (var i = 0; i < 100; i++) uniqueTempPath('/a/b')};

      expect(names, hasLength(100));
      for (final name in names) {
        expect(name, matches(atomicTempSuffix));
        expect(name.replaceFirst(atomicTempSuffix, ''), '/a/b');
      }
      expect('/a/b.$pid.tmp'.replaceFirst(atomicTempSuffix, ''), '/a/b');
      expect(names.first, contains('.flash-$pid-'));
    });
  });

  group('copyAtomically', () {
    test('replaces the target and leaves only the two files', () async {
      final source = File(join(root.path, 'new.yaml'))
        ..writeAsStringSync('proxies: []');
      final target = File(join(root.path, 'profiles', '2.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync('proxies: [old]');

      await source.copyAtomically(target.path);

      expect(target.readAsStringSync(), 'proxies: []');
      expect(target.parent.listSync().map((entry) => basename(entry.path)), [
        '2.yaml',
      ]);
    });
  });

  group('a failed rename', () {
    test('is not retried when it cannot succeed', () async {
      final target = Directory(join(root.path, 'config.yaml'))..createSync();
      File(join(target.path, 'occupied')).createSync();
      final watch = Stopwatch()..start();

      await expectLater(
        File(target.path).writeAsStringAtomically('mode: global'),
        throwsA(isA<FileSystemException>()),
      );

      // Ten attempts 50 ms apart would take 450 ms.
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 300)));
    });

    test('is retried only while someone else holds the target', () {
      // ERROR_ACCESS_DENIED, ERROR_SHARING_VIOLATION, ERROR_LOCK_VIOLATION.
      for (final code in [5, 32, 33]) {
        expect(isHeldOpenError(code, windows: true), isTrue, reason: '$code');
      }
      // ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND.
      expect(isHeldOpenError(2, windows: true), isFalse);
      expect(isHeldOpenError(3, windows: true), isFalse);
      expect(isHeldOpenError(16, windows: false), isTrue); // EBUSY
      expect(isHeldOpenError(2, windows: false), isFalse); // ENOENT
      expect(isHeldOpenError(13, windows: false), isFalse); // EACCES
      expect(isHeldOpenError(null, windows: false), isFalse);
    });
  });

  group('writeAsBytesAtomically with keepMode', () {
    test('passes the mode of the file it replaces on', () async {
      if (Platform.isWindows) return;
      final file = File(join(root.path, 'resource'))..writeAsStringSync('old');
      await Process.run('chmod', ['640', file.path]);
      final mode = file.statSync().mode & 0x1ff;
      expect(mode, 0x1a0); // 0640

      await file.writeAsBytesAtomically('new'.codeUnits, keepMode: true);

      expect(file.readAsStringSync(), 'new');
      expect(file.statSync().mode & 0x1ff, mode);
      expect(root.listSync(), hasLength(1));
    });

    test('writes a new file where there was none', () async {
      final file = File(join(root.path, 'resource'));

      await file.writeAsBytesAtomically('new'.codeUnits, keepMode: true);

      expect(file.readAsStringSync(), 'new');
      expect(root.listSync(), hasLength(1));
    });
  });

  group('sweepStaleAtomicTemps', () {
    test('removes only temporaries older than the cutoff', () async {
      final old = DateTime.now().subtract(const Duration(hours: 2));
      File stale(String name) => File(join(root.path, name))
        ..writeAsStringSync('x')
        ..setLastModifiedSync(old);
      stale('a.json.flash-123-0badf00d.tmp');
      stale('b.json.123.tmp');
      // The Core's os.CreateTemp("x.*.tmp") names.
      stale('x.12345678.tmp');
      stale('config.123.87654321.tmp');
      // This process's own may belong to a write still running.
      stale('mine.json.flash-$pid-0badf00d.tmp');
      stale('keep.json');
      stale('notes.tmp');
      File(
        join(root.path, 'c.json.flash-123-0badf00d.tmp'),
      ).writeAsStringSync('x');

      await sweepStaleAtomicTemps(root.path);

      expect(root.listSync().map((entry) => basename(entry.path)).toSet(), {
        'b.json.123.tmp',
        'x.12345678.tmp',
        'config.123.87654321.tmp',
        'mine.json.flash-$pid-0badf00d.tmp',
        'keep.json',
        'notes.tmp',
        'c.json.flash-123-0badf00d.tmp',
      });
    });

    test('runs before the first atomic write into a directory', () async {
      final leftover = File(join(root.path, 'v.json.flash-99-0badf00d.tmp'))
        ..writeAsStringSync('x')
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 1)));

      await File(join(root.path, 'v.json')).writeAsStringAtomically('{}');

      expect(leftover.existsSync(), isFalse);
    });

    test('concurrent first writes over old files keep their temporaries '
        'and both land', () async {
      if (Platform.isWindows) return;
      final old = DateTime.now().subtract(const Duration(days: 1));
      final leftover = File(join(root.path, 'x.flash-99-0badf00d.tmp'))
        ..writeAsStringSync('x')
        ..setLastModifiedSync(old);
      final files = [
        for (final name in ['a', 'b', 'c', 'd'])
          File(join(root.path, name))
            ..writeAsStringSync('old')
            ..setLastModifiedSync(old),
      ];

      await Future.wait([
        for (final file in files)
          file.writeAsBytesAtomically('new'.codeUnits, keepMode: true),
      ]);

      for (final file in files) {
        expect(file.readAsStringSync(), 'new');
      }
      expect(leftover.existsSync(), isFalse);
      expect(root.listSync(), hasLength(files.length));
    });

    test('accepts a directory that does not exist', () async {
      await sweepStaleAtomicTemps(join(root.path, 'missing'));
    });
  });
}
