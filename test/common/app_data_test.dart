import 'dart:io';

import 'package:drift/drift.dart';
import 'package:fl_clash/common/app_data.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory home;

  setUpAll(() async {
    home = Directory.systemTemp.createTempSync('flclash-app-data-');
    await useAppPaths(home);
  });

  tearDownAll(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  test('clears what a startup failure left behind without the Core', () async {
    await mockPreferences();
    await preferences.setVersion(7);
    final databaseFile = File(await appPath.databasePath)
      ..writeAsStringSync('not a database');
    final profilesDir = Directory(join(await appPath.profilesPath, '1'))
      ..createSync(recursive: true);
    final broken = db.Database(
      LazyDatabase(() async => throw const FileSystemException('corrupt')),
    );
    final previous = db.database;
    db.database = broken;
    addTearDown(() => db.database = previous);
    await expectLater(broken.profilesDao.query().get(), throwsA(anything));

    await clearAppData();

    expect(await preferences.getVersion(), 0);
    expect(
      databaseFile.existsSync(),
      isFalse,
      reason:
          'a database that failed to open rethrows from close, and it is '
          'the file most likely to be why startup failed',
    );
    expect(profilesDir.parent.existsSync(), isFalse);
  });
  test('clears the WAL and its index when a reader kept them open', () async {
    await mockPreferences();
    final databasePath = await appPath.databasePath;
    final opened = db.Database.onFile(File(databasePath));
    final previous = db.database;
    db.database = opened;
    addTearDown(() => db.database = previous);
    await opened.customStatement('CREATE TABLE kept (id INTEGER)');
    await opened.customStatement('INSERT INTO kept VALUES (1)');
    // A worker connection still open means close is not the last one out.
    final reader = sqlite.sqlite3.open(databasePath);
    addTearDown(reader.close);
    reader.select('SELECT * FROM kept');
    expect(File('$databasePath-wal').existsSync(), isTrue);

    await clearAppData();

    for (final path in [
      databasePath,
      '$databasePath-wal',
      '$databasePath-shm',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });
}
