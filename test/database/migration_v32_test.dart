import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../helpers/app_paths.dart';

Set<String> _columns(sqlite.Database raw, String table) => {
  for (final row in raw.select('PRAGMA table_info($table)'))
    row['name'] as String,
};

void _legacyShape(sqlite.Database raw, int version, {bool upstream = false}) {
  if (version < 31 || upstream) {
    raw.execute('ALTER TABLE mitm_modules DROP COLUMN rules_enabled');
  }
  if (version < 30 || upstream) {
    raw.execute('ALTER TABLE mitm_modules DROP COLUMN failure');
    raw.execute('ALTER TABLE mitm_scripts DROP COLUMN failure');
  }
  if (version < 29 || upstream) {
    raw.execute('DROP TABLE mitm_scripts');
    raw.execute('ALTER TABLE mitm_modules DROP COLUMN pending_time');
    raw.execute('ALTER TABLE mitm_modules DROP COLUMN error');
  }
  if (version < 28 || upstream) {
    raw.execute('DROP TABLE mitm_rewrites');
  }
  if (version < 27 || upstream) {
    raw.execute('ALTER TABLE added_rule_sets DROP COLUMN cache_generation');
  }
  if (version < 26 || upstream) {
    raw.execute('DROP TABLE added_rule_sets');
  }
  if (upstream) {
    for (final table in [
      'profile_mounts',
      'mount_targets',
      'mount_source_statuses',
    ]) {
      raw.execute('DROP TABLE $table');
    }
    raw.execute(
      'ALTER TABLE rules ADD COLUMN custom_exit INTEGER NOT NULL DEFAULT 0',
    );
    raw.execute('ALTER TABLE profiles ADD COLUMN exit_targets TEXT');
    raw.execute(
      'ALTER TABLE mitm_modules ADD COLUMN asks_consent '
      'INTEGER NOT NULL DEFAULT 0',
    );
    raw.execute('ALTER TABLE mitm_modules ADD COLUMN accepted INTEGER');
  }
  raw.execute('PRAGMA user_version = $version');
}

void _seed(sqlite.Database raw, {bool upstream = false}) {
  for (final (id, type) in [(1, 'url'), (2, 'custom')]) {
    raw.execute(
      'INSERT INTO profiles (id, type, label, url, extend_type, match_target, '
      'auto_update_duration_millis, auto_update, selected_map, unfold_set) '
      "VALUES (?, ?, 'profile', '', 'standard', 'Proxy', 0, 0, '{}', '[]')",
      [id, type],
    );
  }
  raw.execute(
    'INSERT INTO rules (id, profile_id, rule_action, content, rule_target) '
    "VALUES (1, 1, 'DOMAIN', 'example.com', 'MATCH'), "
    "(2, 2, 'DOMAIN', 'custom.example', 'MATCH'), "
    "(3, NULL, 'SUB_RULE', 'nested', 'MATCH'), "
    "(4, 1, 'DOMAIN', 'literal.example', 'MATCH')",
  );
  final columns = _columns(raw, 'mitm_modules');
  for (final id in [7, 8, 9]) {
    final values = <String, Object?>{
      'id': id,
      'name': 'Module $id',
      'description': 'kept',
      'url': id == 7 ? 'https://example.test/module.sgmodule' : null,
      'enabled': id == 8 ? 0 : 1,
      'order': id == 7
          ? 2
          : id == 8
          ? 1
          : 3,
      'arguments': '{"mode":"safe"}',
      'resources': '{"https://example.test/a.js":"shared.js"}',
      'system': 'Surge',
      'scripts': 1,
      'rules_enabled': id == 7 ? 0 : 1,
      'last_update_time': 1730000000,
      'pending_time': id == 7 ? 1730000010 : null,
      'error': id == 7 ? 'download timed out' : null,
      'failure': id == 7 ? 'download' : null,
      if (upstream) 'asks_consent': 1,
      if (upstream) 'accepted': id == 8 ? 0 : 1,
    }..removeWhere((key, _) => !columns.contains(key));
    raw.execute(
      'INSERT INTO mitm_modules '
      '(${values.keys.map((key) => '"$key"').join(',')}) '
      'VALUES (${List.filled(values.length, '?').join(',')})',
      values.values.toList(),
    );
  }
  if (_columns(raw, 'mitm_scripts').isNotEmpty) {
    raw.execute(
      'INSERT INTO mitm_scripts '
      '(id, profile_id, line, enabled, "order", file, pending_file) '
      "VALUES (20, 1, 'A = type=http-request,script-path=shared.js', "
      "0, 'a0', 'shared.js', 'script-pending.js')",
    );
  }
  if (upstream) {
    raw.execute(
      'UPDATE profiles SET match_target = NULL, '
      "exit_targets = '{\"MATCH\":\"Upstream\",\"Other\":\"DIRECT\"}' "
      'WHERE id = 1',
    );
    raw.execute('UPDATE rules SET custom_exit = 1 WHERE id = 1');
  }
}

Future<Map<String, String>> _hashes(Directory root) async => {
  await for (final file in root.list(recursive: true))
    if (file is File && !file.path.contains('database.sqlite'))
      file.path.substring(root.path.length): sha256
          .convert(await file.readAsBytes())
          .toString(),
};

void main() {
  for (final (version, upstream) in [
    (31, false),
    (30, false),
    (28, false),
    (24, false),
    (25, true),
    (26, true),
  ]) {
    test(
      'schema $version ${upstream ? 'upstream' : 'Flash'} preserves '
      'modules, files and pending state across database/provider reopen',
      () async {
        final home = await Directory.systemTemp.createTemp('flash-schema32-');
        addTearDown(() => home.delete(recursive: true));
        await useAppPaths(home);
        final file = File('${home.path}/database.sqlite');
        final raw = sqlite.sqlite3.open(file.path);
        raw.execute(
          File('test/database/fixtures/schema31.sql').readAsStringSync(),
        );
        _legacyShape(raw, version, upstream: upstream);
        _seed(raw, upstream: upstream);
        final original = [
          for (final row in raw.select(
            'SELECT * FROM mitm_modules ORDER BY id',
          ))
            Map<String, Object?>.from(row),
        ];
        raw.close();
        final modulesDir = await appPath.mitmModulesDirPath;
        final resourcesDir = await appPath.mitmResourcesDirPath;
        for (final (path, text) in [
          ('$modulesDir/7.txt', '[MITM]\nhostname = live.example\n'),
          ('$modulesDir/7.pending.txt', '[MITM]\nhostname = pending.example\n'),
          ('$modulesDir/8.txt', '[MITM]\nhostname = disabled.example\n'),
          ('$resourcesDir/shared.js', r'$done({});'),
          ('$resourcesDir/script-pending.js', r'$done({body: "new"});'),
        ]) {
          final resource = File(path);
          await resource.parent.create(recursive: true);
          await resource.writeAsString(text);
        }
        final hashes = await _hashes(home);
        List<MitmModule>? firstRead;
        for (var open = 0; open < 3; open++) {
          final database = db.Database(NativeDatabase(file));
          db.database = database;
          final container = ProviderContainer();
          try {
            container.listen(mitmModulesProvider, (_, _) {});
            final modules = await container.read(mitmModulesProvider.future);
            expect(database.schemaVersion, 32);
            expect(modules.map((module) => module.id), [8, 7, 9]);
            expect(
              modules.where((module) => module.id == 7).single.rulesEnabled,
              version < 31 || upstream,
            );
            if (firstRead == null) {
              firstRead = modules;
            } else {
              expect(modules, firstRead);
            }
            final rows = await database
                .customSelect('SELECT * FROM mitm_modules ORDER BY id')
                .get();
            for (final (i, row) in rows.indexed) {
              for (final entry in original[i].entries) {
                expect(
                  row.data[entry.key],
                  entry.value,
                  reason: 'module ${original[i]['id']}, ${entry.key}',
                );
              }
              expect(row.data['asks_consent'], 1);
              if (!upstream) expect(row.data['accepted'], isNull);
            }
            final profile = (await database.profilesDao.query().get()).first;
            expect(
              profile.exitTargets['MATCH'],
              upstream ? 'Upstream' : 'Proxy',
            );
            final custom =
                (await database.rulesDao.queryProfileRules(2).get()).single;
            expect(custom.customExit, isFalse);
            final rules = await database.rulesDao.queryProfileRules(1).get();
            expect(
              rules.singleWhere((rule) => rule.id == 1).customExit,
              isTrue,
            );
            // An upstream literal MATCH target must not become a custom exit.
            expect(
              rules.singleWhere((rule) => rule.id == 4).customExit,
              !upstream,
            );
            final independent = await database.mitmScriptsDao.queryAll().get();
            if (version >= 29 && !upstream) {
              expect(independent.single.id, 20);
              expect(independent.single.enabled, isFalse);
              expect(independent.single.file, 'shared.js');
              expect(independent.single.pendingFile, 'script-pending.js');
            } else {
              expect(independent, isEmpty);
            }
            expect(await _hashes(home), hashes);
            expect(
              await File('$modulesDir/7.txt').readAsString(),
              contains('live.example'),
            );
            expect(
              await File('$modulesDir/7.pending.txt').readAsString(),
              contains('pending.example'),
            );
            expect(await File('$modulesDir/9.txt').exists(), isFalse);
          } finally {
            container.dispose();
            await database.close();
          }
          if (open == 1) {
            // Simulate a downgrade that retained the added columns. Re-running
            // the migration must not reset consent or change explicit exits.
            final downgraded = sqlite.sqlite3.open(file.path);
            downgraded.execute('PRAGMA user_version = 31');
            downgraded.close();
          }
        }
      },
    );
  }

  test(
    'new database persists consent separately from pending approval',
    () async {
      final database = db.Database(NativeDatabase.memory());
      addTearDown(database.close);
      final module = MitmModule(
        id: 1,
        name: 'New',
        lastUpdateTime: DateTime(2026),
        pendingTime: DateTime(2026, 2),
        asksConsent: true,
        accepted: false,
        rulesEnabled: false,
      );
      await database.mitmModulesDao.putAll([module.toCompanion()]);
      expect((await database.mitmModulesDao.query().get()).single, module);
    },
  );

  test(
    'a v32 file from before WAL converts in place and keeps its rows',
    () async {
      final home = await Directory.systemTemp.createTemp('flash-prewal-');
      addTearDown(() => home.delete(recursive: true));
      final file = File('${home.path}/database.sqlite');
      // The pre-WAL open: drift's default rollback journal.
      final legacy = db.Database(NativeDatabase(file));
      await legacy.profilesDao.putAll([
        const Profile(id: 31, autoUpdateDuration: Duration.zero).toCompanion(),
      ]);
      await legacy.close();
      final before = sqlite.sqlite3.open(file.path);
      expect(
        before.select('PRAGMA journal_mode').single.values.single,
        'delete',
      );
      expect(before.select('PRAGMA user_version').single.values.single, 32);
      before.close();

      final opened = db.Database.onFile(file);
      final profiles = await opened.profilesDao.query().get();
      final mode = await opened.customSelect('PRAGMA journal_mode').getSingle();
      await opened.close();

      expect(profiles.map((profile) => profile.id), [31]);
      expect(mode.data.values.single, 'wal');
      final after = sqlite.sqlite3.open(file.path);
      addTearDown(after.close);
      expect(after.select('PRAGMA journal_mode').single.values.single, 'wal');
      expect(after.select('PRAGMA user_version').single.values.single, 32);
    },
  );
}
