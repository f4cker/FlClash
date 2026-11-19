import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Database database;

  final remote = MitmScript(
    id: 10,
    line: 'A = type=http-request,pattern=^https://a,script-path=a1.js',
    url: 'https://s/a.js',
    source: 'https://s/a.js',
    file: 'a1.js',
    pendingFile: 'a2.js',
    checkedAt: DateTime(2026, 11, 18, 9),
    error: 'timeout',
  );
  const local = MitmScript(
    id: 11,
    line: 'B = type=http-response,pattern=^https://b,script-path=b1.js',
    source: 'b.js',
    file: 'b1.js',
    enabled: false,
  );

  setUp(() async {
    database = Database(NativeDatabase.memory());
    await database.profilesDao.putAll([
      const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
      const Profile(id: 2, autoUpdateDuration: Duration.zero).toCompanion(),
    ]);
  });

  tearDown(() => database.close());

  Future<List<MitmScript>> of(int profileId) =>
      database.mitmScriptsDao.queryProfile(profileId).get();

  test(
    'scripts belong to their profile, in order, and keep every field',
    () async {
      await database.batch(
        (b) =>
            database.mitmScriptsDao.setProfileWithBatch(1, b, [local, remote]),
      );
      await database.batch(
        (b) => database.mitmScriptsDao.setProfileWithBatch(2, b, [
          remote.copyWith(id: 20),
        ]),
      );
      final first = await of(1);
      expect(first.map((item) => item.id), [11, 10]);
      expect(first.first.enabled, isFalse);
      expect(first.first.isRemote, isFalse);
      expect(first.last.copyWith(order: null), remote.copyWith(profileId: 1));
      expect(first.last.hasPending, isTrue);
      expect((await of(2)).single.id, 20);
      expect(
        (await database.mitmScriptsDao.queryAll().get()).map((s) => s.id),
        unorderedEquals([10, 11, 20]),
      );

      await database.batch(
        (b) => database.mitmScriptsDao.setProfileWithBatch(1, b, [remote]),
      );
      expect((await of(1)).map((item) => item.id), [10]);
      await database.profiles.remove((t) => t.id.equals(1));
      expect(await of(1), isEmpty);
      expect((await of(2)).single.id, 20);
    },
  );

  test('a version 28 database gains scripts and module update state', () async {
    final dir = await Directory.systemTemp.createTemp('mitm-scripts-v28-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/old.sqlite');
    var disk = Database(NativeDatabase(file));
    await disk.profilesDao.putAll([
      const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
    ]);
    final module = MitmModule(
      id: 7,
      name: 'M',
      lastUpdateTime: DateTime(2026, 11, 1),
    );
    await disk.mitmModulesDao.putAll([module.toCompanion()]);
    await disk.close();
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('DROP TABLE mitm_scripts');
    raw.execute('ALTER TABLE mitm_modules DROP COLUMN pending_time');
    raw.execute('ALTER TABLE mitm_modules DROP COLUMN error');
    raw.execute('ALTER TABLE mitm_modules DROP COLUMN rules_enabled');
    raw.execute('PRAGMA user_version = 28');
    raw.close();

    disk = Database(NativeDatabase(file));
    expect(disk.schemaVersion, 32);
    final read = (await disk.mitmModulesDao.query().get()).single;
    expect(read.id, 7);
    expect(read.rulesEnabled, isTrue);
    expect(read.hasPending, isFalse);
    await disk.mitmModulesDao.putAll([
      read
          .copyWith(
            pendingTime: DateTime(2026, 11, 18),
            error: 'x',
            rulesEnabled: false,
          )
          .toCompanion(),
    ]);
    await disk.batch(
      (b) => disk.mitmScriptsDao.setProfileWithBatch(1, b, [local]),
    );
    await disk.close();

    disk = Database(NativeDatabase(file));
    final again = (await disk.mitmModulesDao.query().get()).single;
    expect(again.hasPending, isTrue);
    expect(again.error, 'x');
    expect(again.rulesEnabled, isFalse);
    expect((await disk.mitmScriptsDao.queryProfile(1).get()).single.id, 11);
    await disk.close();
  });
}
