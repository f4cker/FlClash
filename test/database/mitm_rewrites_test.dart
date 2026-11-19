import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Database database;

  const reject = MitmRewrite(
    id: 10,
    section: MitmList.urlRewrite,
    line: r'^https:\/\/a\.com\/ad - reject',
  );
  const header = MitmRewrite(
    id: 11,
    section: MitmList.headerRewrite,
    line: r'http-request ^https:\/\/a\.com header-add X-A 1',
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

  Future<List<MitmRewrite>> of(int profileId) =>
      database.mitmRewritesDao.queryProfile(profileId).get();

  test('rules belong to their profile, in order', () async {
    await database.batch(
      (b) =>
          database.mitmRewritesDao.setProfileWithBatch(1, b, [reject, header]),
    );
    await database.mitmRewritesDao.put(
      reject.copyWith(id: 20, order: 'a0'),
      profileId: 2,
    );
    final first = await of(1);
    expect(first.map((item) => item.id), [10, 11]);
    expect(first.last.enabled, isFalse);
    expect(first.last.section, MitmList.headerRewrite);
    expect(first.first.line, reject.line);
    expect((await of(2)).single.id, 20);

    await database.mitmRewritesDao.order(id: 10, order: 'zz');
    expect((await of(1)).map((item) => item.id), [11, 10]);
    await database.mitmRewritesDao.delAll([11]);
    expect((await of(1)).map((item) => item.id), [10]);
  });

  test('a profile update keeps its rules; deleting it removes them', () async {
    await database.mitmRewritesDao.put(reject, profileId: 1);
    // As a subscription update writes the profile back.
    await database.profiles.put(
      Profile(
        id: 1,
        label: 'updated',
        autoUpdateDuration: Duration.zero,
        lastUpdateDate: DateTime(2026, 11, 18),
      ).toCompanion(),
    );
    await database.profilesDao.putAll([
      const Profile(
        id: 1,
        label: 'again',
        autoUpdateDuration: Duration.zero,
      ).toCompanion(),
    ]);
    expect((await of(1)).single.id, reject.id);
    await database.profiles.remove((t) => t.id.equals(1));
    expect(await of(1), isEmpty);
  });

  test('a version 27 database gains the table and keeps its rows', () async {
    final dir = await Directory.systemTemp.createTemp('mitm-rewrites-v27-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/old.sqlite');
    var disk = Database(NativeDatabase(file));
    await disk.profilesDao.putAll([
      const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
    ]);
    await disk.rulesDao.putRule(const Rule(id: 5, order: 'a'), profileId: 1);
    await disk.close();
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('DROP TABLE mitm_rewrites');
    raw.execute('PRAGMA user_version = 27');
    raw.close();

    disk = Database(NativeDatabase(file));
    expect(disk.schemaVersion, 31);
    expect((await disk.rulesDao.queryProfileRules(1).get()).single.id, 5);
    await disk.mitmRewritesDao.put(reject, profileId: 1);
    await disk.close();

    // And again after a restart.
    disk = Database(NativeDatabase(file));
    expect(
      (await disk.mitmRewritesDao.queryProfile(1).get()).single,
      reject.copyWith(profileId: 1),
    );
    await disk.close();
  });

  test('a database rewound to 27 that kept the table opens', () async {
    final dir = await Directory.systemTemp.createTemp('mitm-rewrites-down-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/old.sqlite');
    var disk = Database(NativeDatabase(file));
    await disk.profilesDao.putAll([
      const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
    ]);
    await disk.mitmRewritesDao.put(reject, profileId: 1);
    await disk.close();
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 27');
    raw.close();
    disk = Database(NativeDatabase(file));
    expect((await disk.mitmRewritesDao.queryProfile(1).get()).single.id, 10);
    await disk.close();
  });
}
