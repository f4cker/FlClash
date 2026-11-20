import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' show Digest, sha256;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/restore_mount_plan.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

part 'added_rule_sets.dart';
part 'clash_providers.dart';
part 'converter.dart';
part 'custom_proxies.dart';
part 'dialers.dart';
part 'generated/database.g.dart';
part 'groups.dart';
part 'icons.dart';
part 'ip_qualities.dart';
part 'mitm_modules.dart';
part 'mitm_rewrites.dart';
part 'mitm_scripts.dart';
part 'mounts.dart';
part 'profiles.dart';
part 'rules.dart';
part 'scripts.dart';

@DriftDatabase(
  tables: [
    Profiles,
    Scripts,
    Rules,
    DisabledRules,
    ProxyGroups,
    IconRecords,
    IconSets,
    ClashProviders,
    CustomProxies,
    ProxyDialers,
    IpQualities,
    MitmModules,
    ProfileMounts,
    MountTargets,
    MountSourceStatuses,
    AddedRuleSets,
    MitmRewrites,
    MitmScripts,
  ],
  daos: [
    ProfilesDao,
    ScriptsDao,
    RulesDao,
    ProxyGroupsDao,
    IconRecordsDao,
    IconSetsDao,
    ClashProvidersDao,
    CustomProxiesDao,
    ProxyDialersDao,
    IpQualitiesDao,
    MitmModulesDao,
    MountsDao,
    AddedRuleSetsDao,
    MitmRewritesDao,
    MitmScriptsDao,
  ],
)
class Database extends _$Database {
  Database([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 32;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final databaseFile = File(await appPath.databasePath);
      return NativeDatabase.createInBackground(databaseFile);
    });
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) => transaction(() async {
        final hadCustomExits = (await _columnsOf(
          'rules',
        )).contains('custom_exit');
        final hadModuleConsent = (await _columnsOf(
          'mitm_modules',
        )).contains('asks_consent');
        if (from < 2) {
          await m.createTable(iconRecords);
          await _migrateV1Rules();
        }
        if (from < 3) {
          await _addColumnIfMissing(m, profiles, profiles.matchTarget);
        }
        if (from < 4) {
          await _addColumnIfMissing(m, scripts, scripts.url);
        }
        if (from < 5) {
          await _addColumnIfMissing(m, scripts, scripts.order);
        }
        if (from < 6) {
          await _createTableIfMissing(m, clashProviders);
        }
        if (from < 8) {
          await m.alterTable(TableMigration(clashProviders));
        }
        if (from < 10) {
          await _createTableIfMissing(m, customProxies);
        }
        if (from < 17) {
          await _renameColumnIfPresent(
            m,
            profiles,
            'overwrite_type',
            profiles.extendType,
          );
          await _dropProfileCustomProxies(m);
          await _migrateToCustomProfiles(m);
          await _createTableIfMissing(m, iconSets);
          await _addColumnIfMissing(m, iconSets, iconSets.lastUpdateTime);
          await _addColumnIfMissing(m, profiles, profiles.overrides);
        }
        if (from < 18) {
          await _moveGroupOptionsToDefinition(m);
        }
        if (from < 19) {
          await _addColumnIfMissing(m, profiles, profiles.ageSecretKey);
        }
        if (from < 20) {
          await _addColumnIfMissing(
            m,
            customProxies,
            customProxies.emptyOptions,
          );
        }
        if (from < 21) {
          await _createTableIfMissing(m, ipQualities);
        }
        if (from < 22) {
          await _createTableIfMissing(m, mitmModules);
        }
        if (from < 23) {
          // The copy below names every column the table has today.
          await _addColumnIfMissing(m, mitmModules, mitmModules.pendingTime);
          await _addColumnIfMissing(m, mitmModules, mitmModules.error);
          await _addColumnIfMissing(m, mitmModules, mitmModules.failure);
          await _addColumnIfMissing(m, mitmModules, mitmModules.rulesEnabled);
          await _addColumnIfMissing(m, mitmModules, mitmModules.asksConsent);
          await _addColumnIfMissing(m, mitmModules, mitmModules.accepted);
          await m.alterTable(TableMigration(mitmModules));
        }
        // Flash 0.9.x and upstream FlClash both shipped a version 24: Flash's
        // added the mount tables, upstream's merged the extend modes. A
        // version 24 database holding the mount tables is Flash's and still
        // needs the merge; one without them is upstream's and needs the tables.
        if (from < 25) {
          final flashV24 =
              from == 24 &&
              (await _columnsOf(profileMounts.actualTableName)).isNotEmpty;
          await _createTableIfMissing(m, profileMounts);
          await _createTableIfMissing(m, mountTargets);
          await _createTableIfMissing(m, mountSourceStatuses);
          if (from < 24 || flashV24) {
            await _mergeExtendModes();
          }
        }
        // Upstream 25/26 did not contain Flash's mount or added-set tables.
        if (from < 32) {
          await _createTableIfMissing(m, profileMounts);
          await _createTableIfMissing(m, mountTargets);
          await _createTableIfMissing(m, mountSourceStatuses);
          await _createTableIfMissing(m, addedRuleSets);
        }
        if (from < 27) {
          await _addColumnIfMissing(
            m,
            addedRuleSets,
            addedRuleSets.cacheGeneration,
          );
        }
        if (from < 28) {
          await _createTableIfMissing(m, mitmRewrites);
        }
        if (from < 29) {
          await _createTableIfMissing(m, mitmScripts);
          await _addColumnIfMissing(m, mitmModules, mitmModules.pendingTime);
          await _addColumnIfMissing(m, mitmModules, mitmModules.error);
        }
        if (from < 30) {
          await _addColumnIfMissing(m, mitmScripts, mitmScripts.failure);
          await _addColumnIfMissing(m, mitmModules, mitmModules.failure);
        }
        if (from < 31) {
          await _addColumnIfMissing(m, mitmModules, mitmModules.rulesEnabled);
        }
        if (from < 32) {
          await _addColumnIfMissing(m, rules, rules.customExit);
          await _addColumnIfMissing(m, profiles, profiles.exitTargets);
          await _addColumnIfMissing(m, mitmModules, mitmModules.asksConsent);
          await _addColumnIfMissing(m, mitmModules, mitmModules.accepted);
          if (!hadModuleConsent) {
            // Old script approval never authorizes new network capabilities.
            await customStatement(
              'UPDATE mitm_modules SET asks_consent = 1, accepted = NULL',
            );
          }
          await _copyLegacyMatchTargets(convertRules: !hadCustomExits);
        }
      }),
      beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _copyLegacyMatchTargets({required bool convertRules}) async {
    if (convertRules) {
      await customStatement(
        'UPDATE rules SET custom_exit = 1 '
        "WHERE upper(trim(rule_target)) = 'MATCH' AND rule_action != 'SUB_RULE' "
        'AND (profile_id IS NULL OR profile_id IN '
        "(SELECT id FROM profiles WHERE type != 'custom'))",
      );
    }
    // Keep the old target until the routing adapter consumes exit_targets.
    await customStatement(
      'UPDATE profiles SET exit_targets = json_set('
      "coalesce(exit_targets, '{}'), '\$.MATCH', trim(match_target)) "
      "WHERE trim(coalesce(match_target, '')) != '' AND type != 'custom' "
      "AND json_extract(coalesce(exit_targets, '{}'), '\$.MATCH') IS NULL",
    );
  }

  Future<Set<String>> _columnsOf(String table) async {
    final tableInfo = await customSelect('PRAGMA table_info($table)').get();
    return {for (final row in tableInfo) row.read<String>('name')};
  }

  /// Drift rewinds user_version on downgrade but keeps the tables it added.
  Future<bool> _createTableIfMissing(Migrator m, TableInfo table) async {
    if ((await _columnsOf(table.actualTableName)).isNotEmpty) {
      return false;
    }
    await m.createTable(table);
    return true;
  }

  /// Drift rewinds user_version on downgrade but keeps the columns it added.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    if ((await _columnsOf(table.actualTableName)).contains(column.name)) {
      return;
    }
    await m.addColumn(table, column);
  }

  Future<void> _renameColumnIfPresent(
    Migrator m,
    TableInfo table,
    String oldName,
    GeneratedColumn column,
  ) async {
    if (!(await _columnsOf(table.actualTableName)).contains(oldName)) {
      return;
    }
    await m.renameColumn(table, oldName, column);
  }

  /// A profile keeps the rules it applied when it ran a script or added rules.
  Future<void> _mergeExtendModes() async {
    await customStatement(
      'INSERT OR IGNORE INTO disabled_rules (profile_id, rule_id) '
      'SELECT profiles.id, rules.id FROM profiles, rules '
      "WHERE rules.profile_id IS NULL AND profiles.extend_type = 'script'",
    );
    await customStatement(
      'UPDATE profiles SET script_id = NULL '
      "WHERE extend_type != 'script' "
      'OR script_id NOT IN (SELECT id FROM scripts)',
    );
    await customStatement(
      'UPDATE profiles SET extend_type = '
      "CASE WHEN script_id IS NULL THEN 'standard' ELSE 'script' END",
    );
  }

  /// alterTable re-creates the old index, which names the dropped column.
  Future<void> _dropProfileCustomProxies(Migrator m) async {
    final columns = await _columnsOf(customProxies.actualTableName);
    if (!columns.contains('profile_id')) {
      return;
    }
    await customStatement(
      'DELETE FROM ${customProxies.actualTableName} '
      'WHERE profile_id IS NOT NULL',
    );
    await customStatement(
      'DROP INDEX IF EXISTS idx_custom_proxies_profile_order',
    );
    await m.alterTable(
      TableMigration(
        customProxies,
        newColumns: [
          if (!columns.contains(customProxies.emptyOptions.name))
            customProxies.emptyOptions,
        ],
      ),
    );
  }

  /// Schema 17 kept each group option in a column of its own.
  Future<void> _moveGroupOptionsToDefinition(Migrator m) async {
    final columns = await _columnsOf(proxyGroups.actualTableName);
    if (columns.isEmpty || columns.contains(proxyGroups.definition.name)) {
      return;
    }
    final rows = await customSelect(
      'SELECT * FROM ${proxyGroups.actualTableName}',
    ).get();
    await m.alterTable(
      TableMigration(proxyGroups, newColumns: [proxyGroups.definition]),
    );
    for (final row in rows) {
      final options = {
        for (final (column, key) in _v17GroupOptions)
          if (row.data[column] case final Object value) key: value,
        for (final (column, key) in _v17GroupFlags)
          if (row.data[column] case final int value) key: value != 0,
      };
      if (options.isEmpty) {
        continue;
      }
      final stmt = proxyGroups.update()
        ..where((t) => t.id.equals(row.read<int>('id')));
      await stmt.write(
        ProxyGroupsCompanion(definition: Value(json.encode(options))),
      );
    }
  }

  /// Schema 1 kept each rule as one `value` string and its links in reverse
  /// order; [_migrateToCustomProfiles] then moves both onto the rules.
  Future<void> _migrateV1Rules() async {
    final columns = await _columnsOf('rules');
    if (columns.contains('value')) {
      await customStatement(
        'ALTER TABLE rules ADD COLUMN rule_action TEXT NOT NULL DEFAULT ""',
      );
      await customStatement('ALTER TABLE rules ADD COLUMN content TEXT');
      await customStatement('ALTER TABLE rules ADD COLUMN rule_target TEXT');
      await customStatement('ALTER TABLE rules ADD COLUMN rule_provider TEXT');
      await customStatement('ALTER TABLE rules ADD COLUMN sub_rule TEXT');
      await customStatement(
        'ALTER TABLE rules ADD COLUMN no_resolve INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE rules ADD COLUMN src INTEGER NOT NULL DEFAULT 0',
      );
      final oldRows = await customSelect('SELECT id, value FROM rules').get();
      for (final row in oldRows) {
        final id = row.read<int>('id');
        final parsed = Rule.parse(row.read<String>('value'), id: id);
        await customStatement(
          'UPDATE rules SET rule_action = ?, content = ?, rule_target = ?, rule_provider = ?, sub_rule = ?, no_resolve = ?, src = ? WHERE id = ?',
          [
            parsed.ruleAction.name,
            parsed.content,
            parsed.ruleTarget,
            parsed.ruleProvider,
            parsed.subRule,
            parsed.noResolve ? 1 : 0,
            parsed.src ? 1 : 0,
            id,
          ],
        );
      }
      await customStatement('ALTER TABLE rules DROP COLUMN value');
    }
    final links = await customSelect(
      'SELECT id FROM profile_rule_mapping '
      'ORDER BY scene ASC, "order" DESC, id DESC',
    ).get();
    final keys = indexing.generateNKeys(links.length);
    for (final (index, link) in links.indexed) {
      await customStatement(
        'UPDATE profile_rule_mapping SET "order" = ? WHERE id = ?',
        [keys[index], link.read<String>('id')],
      );
    }
  }

  /// Rules move from `profile_rule_mapping` onto their owner, and everything a
  /// custom overwrite kept — its groups, its rules and its dialers — is
  /// dropped: those groups named the subscription's own proxies, which a
  /// custom profile does not have. The mapping table marks the old shape, so
  /// a database that went back to an older build and returns is left as is.
  Future<void> _migrateToCustomProfiles(Migrator m) async {
    final profileColumns = await _columnsOf('profiles');
    if (!profileColumns.contains(profiles.type.name)) {
      await m.alterTable(
        TableMigration(
          profiles,
          columnTransformer: {
            profiles.type: const CustomExpression<String>(
              "CASE WHEN url = '' THEN 'file' ELSE 'url' END",
            ),
          },
          newColumns: [
            for (final column in profiles.$columns)
              if (!profileColumns.contains(column.name)) column,
          ],
        ),
      );
    }
    final customOverwrites = {
      for (final row in await customSelect(
        'SELECT id FROM profiles '
        "WHERE extend_type NOT IN ('standard', 'script')",
      ).get())
        row.read<int>('id'),
    };
    await customStatement(
      "UPDATE profiles SET extend_type = 'standard', match_target = NULL "
      "WHERE extend_type NOT IN ('standard', 'script')",
    );
    if ((await _columnsOf('profile_rule_mapping')).isEmpty) {
      return;
    }
    final profileIds = {
      for (final row in await customSelect('SELECT id FROM profiles').get())
        row.read<int>('id'),
    };
    final ruleRows = (await _columnsOf('rules')).isEmpty
        ? const <QueryRow>[]
        : await customSelect(
            'SELECT id, rule_action, content, rule_target, rule_provider, '
            'sub_rule, no_resolve, src FROM rules',
          ).get();
    final linkRows = await customSelect(
      'SELECT profile_id, rule_id, scene, "order" FROM profile_rule_mapping '
      'ORDER BY profile_id IS NOT NULL, "order"',
    ).get();
    final owners = <int, (int?, String?)>{};
    final disabled = <(int, int)>{};
    for (final link in linkRows) {
      final profileId = link.readNullable<int>('profile_id');
      final ruleId = link.read<int>('rule_id');
      final scene = link.readNullable<String>('scene');
      if (profileId != null && !profileIds.contains(profileId)) {
        continue;
      }
      switch ((profileId, scene)) {
        case (null, null):
        case (int(), 'added') when !customOverwrites.contains(profileId):
          owners.putIfAbsent(
            ruleId,
            () => (profileId, link.readNullable<String>('order')),
          );
        case (final int owner, 'disabled'):
          disabled.add((owner, ruleId));
      }
    }
    for (final MapEntry(key: ruleId, value: (owner, _)) in owners.entries) {
      if (owner != null) {
        continue;
      }
      for (final profileId in customOverwrites) {
        disabled.add((profileId, ruleId));
      }
    }
    for (final table in [
      'profile_rule_mapping',
      'rules',
      'proxy_dialers',
      'proxy_groups',
    ]) {
      await customStatement('DROP TABLE IF EXISTS $table');
    }
    for (final table in <TableInfo>[
      rules,
      disabledRules,
      proxyGroups,
      proxyDialers,
    ]) {
      await m.createTable(table);
    }
    for (final index in [
      idxRuleTarget,
      idxRulesProfileOrder,
      idxProxyGroupsProfileOrder,
    ]) {
      await m.createIndex(index);
    }
    final keptRuleIds = <int>{};
    for (final row in ruleRows) {
      final id = row.read<int>('id');
      final owner = owners[id];
      if (owner == null) {
        continue;
      }
      keptRuleIds.add(id);
      await customStatement(
        'INSERT INTO rules (id, profile_id, rule_action, content, rule_target, '
        'rule_provider, sub_rule, no_resolve, src, "order") '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          owner.$1,
          row.read<String>('rule_action'),
          row.readNullable<String>('content'),
          row.readNullable<String>('rule_target'),
          row.readNullable<String>('rule_provider'),
          row.readNullable<String>('sub_rule'),
          row.read<int>('no_resolve'),
          row.read<int>('src'),
          owner.$2,
        ],
      );
    }
    for (final (profileId, ruleId) in disabled) {
      if (!keptRuleIds.contains(ruleId)) {
        continue;
      }
      await customStatement(
        'INSERT INTO disabled_rules (profile_id, rule_id) VALUES (?, ?)',
        [profileId, ruleId],
      );
    }
  }

  /// Runs every guard [restore] runs and throws the same [StateError],
  /// writing nothing, and returns what [restore] would do to mounts. Live
  /// files a restore names may only be published once this passes, with
  /// mount operations fenced until [restore] commits.
  Future<RestoreMountPlan> checkRestore(
    List<Profile> profiles,
    List<Script> scripts,
    List<Rule> rules,
    List<DisabledRule> disabledRules,
    List<ProxyGroup> proxyGroups, {
    List<ClashProvider> clashProviders = const [],
    List<CustomProxy> customProxies = const [],
    List<ProxyDialer> proxyDialers = const [],
    List<MitmModule> mitmModules = const [],
    List<AddedRuleSet> addedRuleSets = const [],
    bool isOverride = false,
    bool mountsCarried = false,
    List<MountTargetState> mountTargets = const [],
    List<MountSourceRecord> mountSourceStatuses = const [],
  }) async {
    final (_, plan) = await _restore(
      profiles,
      scripts,
      rules,
      disabledRules,
      proxyGroups,
      clashProviders: clashProviders,
      customProxies: customProxies,
      proxyDialers: proxyDialers,
      mitmModules: mitmModules,
      addedRuleSets: addedRuleSets,
      isOverride: isOverride,
      mountsCarried: mountsCarried,
      mountTargets: mountTargets,
      mountSourceStatuses: mountSourceStatuses,
      write: false,
    );
    return plan;
  }

  /// With a [commitId], the transaction also records that restore in
  /// [restoreCommitsTable] and returns [restoreFingerprint] as committed, so
  /// a journal can tell after a crash whether these rows were written.
  ///
  /// Mount rows are rebuilt in the same transaction, per the plan
  /// [checkRestore] returns. With [expectedMountDigest], a plan that no
  /// longer matches the confirmed one throws
  /// [RestoreBlockedReason.mountStateChanged] and nothing is written.
  Future<(String?, RestoreMountPlan)> restore(
    List<Profile> profiles,
    List<Script> scripts,
    List<Rule> rules,
    List<DisabledRule> disabledRules,
    List<ProxyGroup> proxyGroups, {
    List<ClashProvider> clashProviders = const [],
    List<CustomProxy> customProxies = const [],
    List<ProxyDialer> proxyDialers = const [],
    List<MitmModule> mitmModules = const [],
    List<AddedRuleSet> addedRuleSets = const [],
    bool isOverride = false,
    bool mountsCarried = false,
    List<MountTargetState> mountTargets = const [],
    List<MountSourceRecord> mountSourceStatuses = const [],
    String? expectedMountDigest,
    int? commitId,
  }) => _restore(
    profiles,
    scripts,
    rules,
    disabledRules,
    proxyGroups,
    clashProviders: clashProviders,
    customProxies: customProxies,
    proxyDialers: proxyDialers,
    mitmModules: mitmModules,
    addedRuleSets: addedRuleSets,
    isOverride: isOverride,
    mountsCarried: mountsCarried,
    mountTargets: mountTargets,
    mountSourceStatuses: mountSourceStatuses,
    expectedMountDigest: expectedMountDigest,
    write: true,
    commitId: commitId,
  );

  /// Runs last inside a writing restore's transaction; a throw rolls it back.
  @visibleForTesting
  Future<void> Function()? beforeRestoreCommit;

  /// Not part of the drift schema: schemaVersion stays put, so a build that
  /// predates the restore journal opens, uses and backs up this database
  /// unchanged. It is created on the first journaled restore, holds a row
  /// only while that restore is unfinished, and backups leave it out.
  static const restoreCommitsTable = 'restore_commits';

  /// The tables a restore writes, by the columns read. Caches and status
  /// rows that change in the background are left out, as is a mount
  /// target's pending record: a readback settling it changes no restored
  /// data, and every other mount write moves the version.
  static const _fingerprintTables = {
    'profiles': '*',
    'scripts': '*',
    'rules': '*',
    'disabled_rules': '*',
    'proxy_groups': '*',
    'clash_providers': '*',
    'custom_proxies': '*',
    'proxy_dialers': '*',
    'mitm_modules': '*',
    'added_rule_sets': '*',
    'profile_mounts': '*',
    'mount_targets': 'target_id, "groups", version',
  };

  /// A digest of every row a restore writes. Recovery compares it with the
  /// one recorded at commit: a mismatch means something, such as an older
  /// build, changed the data since, and nothing is rolled forward over it.
  Future<String> restoreFingerprint() async {
    final output = _DigestSink();
    final input = sha256.startChunkedConversion(output);
    for (final MapEntry(key: table, value: columns)
        in _fingerprintTables.entries) {
      input.add(utf8.encode('#$table\n'));
      final rows = await customSelect(
        'SELECT $columns FROM "$table" ORDER BY rowid',
      ).get();
      for (final row in rows) {
        input.add(
          utf8.encode(
            '${json.encode(row.data, toEncodable: _fingerprintValue)}\n',
          ),
        );
      }
    }
    input.close();
    return output.value.toString();
  }

  static Object? _fingerprintValue(Object? value) =>
      value is List<int> ? base64.encode(value) : value.toString();

  Future<bool> _hasRestoreCommits() async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(restoreCommitsTable)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<String> _markRestoreCommit(int id) async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS $restoreCommitsTable ('
      'id INTEGER NOT NULL PRIMARY KEY, '
      'created_at INTEGER NOT NULL, '
      "fingerprint TEXT NOT NULL DEFAULT '')",
    );
    final fingerprint = await restoreFingerprint();
    await customStatement(
      'INSERT OR REPLACE INTO $restoreCommitsTable '
      '(id, created_at, fingerprint) VALUES (?, ?, ?)',
      [id, DateTime.now().millisecondsSinceEpoch, fingerprint],
    );
    return fingerprint;
  }

  /// The fingerprint recorded when restore [id] committed, or null when that
  /// restore never committed (or has been finalized).
  Future<String?> restoreCommit(int id) async {
    if (!await _hasRestoreCommits()) return null;
    final row = await customSelect(
      'SELECT fingerprint FROM $restoreCommitsTable WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).getSingleOrNull();
    return row?.read<String>('fingerprint');
  }

  /// Whether any restore committed and is not yet finalized.
  Future<bool> hasRestoreCommit() async {
    if (!await _hasRestoreCommits()) return false;
    final rows = await customSelect(
      'SELECT 1 FROM $restoreCommitsTable LIMIT 1',
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> clearRestoreCommit(int id) async {
    if (!await _hasRestoreCommits()) return;
    await customStatement('DELETE FROM $restoreCommitsTable WHERE id = ?', [
      id,
    ]);
  }

  Future<(String?, RestoreMountPlan)> _restore(
    List<Profile> profiles,
    List<Script> scripts,
    List<Rule> rules,
    List<DisabledRule> disabledRules,
    List<ProxyGroup> proxyGroups, {
    required List<ClashProvider> clashProviders,
    required List<CustomProxy> customProxies,
    required List<ProxyDialer> proxyDialers,
    required List<MitmModule> mitmModules,
    required List<AddedRuleSet> addedRuleSets,
    required bool isOverride,
    required bool mountsCarried,
    required List<MountTargetState> mountTargets,
    required List<MountSourceRecord> mountSourceStatuses,
    String? expectedMountDigest,
    required bool write,
    int? commitId,
  }) async {
    final isEmpty =
        profiles.isEmpty &&
        scripts.isEmpty &&
        rules.isEmpty &&
        disabledRules.isEmpty &&
        proxyGroups.isEmpty &&
        clashProviders.isEmpty &&
        customProxies.isEmpty &&
        proxyDialers.isEmpty &&
        mitmModules.isEmpty &&
        addedRuleSets.isEmpty;
    String? fingerprint;
    var plan = RestoreMountPlan.empty;
    Future<void> commit() async {
      if (commitId != null) {
        fingerprint = await _markRestoreCommit(commitId);
      }
      await beforeRestoreCommit?.call();
    }

    await transaction(() async {
      // Even settings-only restores can change the active profile while an
      // unresolved mount operation is still applying.
      final mountStates = await mountsDao.targets();
      final pendingIds = [
        for (final state in mountStates.values)
          if (state.pending != null) state.targetId,
      ]..sort();
      if (pendingIds.isNotEmpty) {
        throw RestoreBlockedError(
          RestoreBlockedReason.mountPending,
          pendingIds,
        );
      }
      if (isEmpty) {
        if (write) await commit();
        return;
      }
      if (!isOverride && addedRuleSets.isNotEmpty) {
        final existing = await addedRuleSetsDao.queryAll().get();
        final ids = {for (final set in existing) set.id: set};
        final names = {
          for (final set in existing) (set.profileId, set.name): set,
        };
        for (final set in addedRuleSets) {
          final sameId = ids[set.id];
          final sameName = names[(set.profileId, set.name)];
          if ((sameId != null &&
                  (sameId.profileId != set.profileId ||
                      sameId.name != set.name)) ||
              (sameName != null && sameName.id != set.id)) {
            throw StateError(
              'Conflicting added rule set in backup: ${set.name}',
            );
          }
          ids[set.id] = set;
          names[(set.profileId, set.name)] = set;
        }
      }
      if (!isOverride) {
        final existingSets = await addedRuleSetsDao.queryAll().get();
        final existingById = {for (final set in existingSets) set.id: set};
        final incomingById = {for (final set in addedRuleSets) set.id: set};
        final existingRules = {
          for (final row in await this.rules.all().get()) row.id: row.toRule(),
        };
        bool matchesPair(Rule rule, AddedRuleSet set) =>
            rule.profileId == set.profileId &&
            rule.ruleAction == RuleAction.RULE_SET &&
            rule.ruleProvider == set.name;
        // Legacy links can use a different rule ID. Name matches do not prove
        // ownership, so never overwrite a potentially linked rule on merge.
        for (final rule in rules) {
          final old = existingRules[rule.id];
          if (old == null) continue;
          final oldLinks = existingSets.where((set) => matchesPair(old, set));
          final newLinks = addedRuleSets.where((set) => matchesPair(rule, set));
          if (oldLinks.any((set) => set.id != rule.id) ||
              newLinks.any((set) => set.id != rule.id)) {
            throw StateError(
              'Ambiguous legacy rule link in backup: ${rule.id}',
            );
          }
        }
        for (final set in addedRuleSets) {
          final oldRule = existingRules[set.id];
          final oldSet = existingById[set.id];
          if (oldRule != null &&
              (oldSet == null || !matchesPair(oldRule, oldSet))) {
            throw StateError('Conflicting rule ID in backup: ${set.id}');
          }
        }
        for (final rule in rules) {
          final oldSet = existingById[rule.id];
          final newSet = incomingById[rule.id];
          if ((oldSet != null &&
                  (newSet == null || !matchesPair(rule, newSet))) ||
              (newSet != null && !matchesPair(rule, newSet))) {
            throw StateError(
              'Conflicting added rule pair in backup: ${rule.id}',
            );
          }
        }
      }
      // Stale saves and in-flight applies stay rejected: every rebuilt
      // target gets a version above both sides and its own pending record.
      final importedIds = profiles.map((p) => p.id).toSet();
      plan = planRestoreMounts(
        isOverride: isOverride,
        localTargets: mountStates,
        localProfiles: await profilesDao.query().get(),
        backupProfiles: profiles,
        backupTargets: mountsCarried
            ? {for (final target in mountTargets) target.targetId: target}
            : null,
      );
      if (expectedMountDigest != null && plan.digest != expectedMountDigest) {
        throw RestoreBlockedError(RestoreBlockedReason.mountStateChanged, [
          for (final target in plan.pendingCheck) target.id,
        ]);
      }
      if (!write) return;
      // Backups taken while foreign keys were off may carry orphaned rows.
      await customStatement('PRAGMA defer_foreign_keys = ON');
      if (isOverride) {
        await this.mountSourceStatuses.deleteAll();
      } else {
        for (final id in importedIds) {
          await this.mountSourceStatuses.remove((t) => t.sourceId.equals(id));
        }
      }
      final restored = [for (final m in mitmModules) restoredMitmModule(m)];
      await batch((b) {
        if (isOverride) {
          profilesDao.setAllWithBatch(b, profiles);
          scriptsDao.setAllWithBatch(b, scripts);
          rulesDao.setAllWithBatch(b, rules, disabledRules);
          proxyGroupsDao.setAllWithBatch(b, proxyGroups);
          customProxiesDao.setAllWithBatch(b, customProxies);
          clashProvidersDao.setAllWithBatch(b, clashProviders);
          // Rewriting profiles or custom proxies cascades into these.
          proxyDialersDao.setAllWithBatch(b, proxyDialers);
          mitmModulesDao.setAllWithBatch(b, restored);
          addedRuleSetsDao.setAllWithBatch(b, addedRuleSets);
          return;
        }
        profilesDao.putAllWithBatch(
          b,
          profiles.map((item) => item.toCompanion()),
        );
        scriptsDao.putAllWithBatch(b, scripts);
        rulesDao.putAllWithBatch(b, rules, disabledRules);
        proxyGroupsDao.putAllWithBatch(b, proxyGroups);
        customProxiesDao.putAllWithBatch(b, customProxies);
        clashProvidersDao.putAllWithBatch(b, clashProviders);
        proxyDialersDao.putAllWithBatch(b, proxyDialers);
        mitmModulesDao.putAllWithBatch(b, restored);
        addedRuleSetsDao.putAllWithBatch(b, addedRuleSets);
      });
      await _writeRestoredMounts(
        plan,
        statuses: mountsCarried
            ? [
                for (final status in mountSourceStatuses)
                  if (importedIds.contains(status.sourceId)) status,
              ]
            : const [],
      );
      await _purgeOrphans();
      await commit();
    });
    return (fingerprint, plan);
  }

  /// Runs inside [_restore]'s transaction, after the profile rows: an
  /// override's rewrite has already cascaded the rows of removed profiles.
  Future<void> _writeRestoredMounts(
    RestoreMountPlan plan, {
    required List<MountSourceRecord> statuses,
  }) async {
    for (final write in plan.writes) {
      await (delete(
        profileMounts,
      )..where((t) => t.targetId.equals(write.targetId))).go();
      await batch((b) {
        b.insertAll(profileMounts, [
          for (final (index, sourceId) in write.sourceIds.indexed)
            ProfileMountsCompanion.insert(
              targetId: write.targetId,
              sourceId: sourceId,
              position: index,
            ),
        ]);
      });
      await into(mountTargets).insertOnConflictUpdate(
        MountTargetsCompanion.insert(
          targetId: Value(write.targetId),
          groups: const [],
          version: write.version,
          pending: Value(write.pending),
        ),
      );
    }
    // Relations naming a profile the restore removed go with it; the plan
    // has listed each one.
    final profileIds = selectOnly(profiles)..addColumns([profiles.id]);
    await profileMounts.remove(
      (t) =>
          t.targetId.isNotInQuery(profileIds) |
          t.sourceId.isNotInQuery(profileIds),
    );
    await mountTargets.remove((t) => t.targetId.isNotInQuery(profileIds));
    await batch((b) {
      b.insertAllOnConflictUpdate(mountSourceStatuses, [
        for (final status in statuses)
          MountSourceStatusesCompanion.insert(
            sourceId: Value(status.sourceId),
            failure: Value(status.failure),
            failedAt: Value(status.failedAt),
            succeededAt: Value(status.succeededAt),
          ),
      ]);
    });
    await mountSourceStatuses.remove(
      (t) => t.sourceId.isNotInQuery(profileIds),
    );
  }

  Future<void> deleteProfile(int profileId) {
    return profiles.remove((t) => t.id.equals(profileId));
  }

  Future<void> _purgeOrphans() async {
    final profileIds = selectOnly(profiles)..addColumns([profiles.id]);
    final ruleIds = selectOnly(rules)..addColumns([rules.id]);
    final customProxyIds = selectOnly(customProxies)
      ..addColumns([customProxies.id]);
    await rules.remove(
      (t) => t.profileId.isNotNull() & t.profileId.isNotInQuery(profileIds),
    );
    await disabledRules.remove(
      (t) =>
          t.profileId.isNotInQuery(profileIds) | t.ruleId.isNotInQuery(ruleIds),
    );
    await proxyGroups.remove((t) => t.profileId.isNotInQuery(profileIds));
    await addedRuleSets.remove((t) => t.profileId.isNotInQuery(profileIds));
    await proxyDialers.remove(
      (t) =>
          t.profileId.isNotInQuery(profileIds) |
          t.proxyId.isNotInQuery(customProxyIds),
    );
  }
}

const _v17GroupOptions = [
  ('url', 'url'),
  ('interval', 'interval'),
  ('timeout', 'timeout'),
  ('max_failed_times', 'max-failed-times'),
  ('filter', 'filter'),
  ('exclude_filter', 'exclude-filter'),
  ('exclude_type', 'exclude-type'),
  ('expected_status', 'expected-status'),
  ('tolerance', 'tolerance'),
  ('strategy', 'strategy'),
  ('hash_key', 'hash-key'),
  ('default_selected', 'default-selected'),
  ('empty_fallback', 'empty-fallback'),
  ('icon', 'icon'),
];

const _v17GroupFlags = [
  ('lazy', 'lazy'),
  ('disable_u_d_p', 'disable-udp'),
  ('include_all', 'include-all'),
  ('include_all_proxies', 'include-all-proxies'),
  ('include_all_providers', 'include-all-providers'),
  ('hidden', 'hidden'),
];

// SQLite builds before 3.32 cap a statement at 999 bound parameters.
const _maxBoundValues = 900;

extension TableInfoExt<Tbl extends Table, Row> on TableInfo<Tbl, Row> {
  void setAll(
    Batch batch,
    Iterable<Insertable<Row>> items, {
    required Expression<bool> Function(Tbl tbl) deleteFilter,
    bool preDelete = false,
  }) async {
    if (preDelete) {
      batch.deleteWhere(this, deleteFilter);
    }
    batch.insertAllOnConflictUpdate(this, items);
    if (!preDelete) {
      batch.deleteWhere(this, deleteFilter);
    }
  }

  void deleteInChunks<V extends Object>(
    Batch batch,
    Iterable<V> values,
    Expression<bool> Function(Tbl tbl, List<V> chunk) filter,
  ) {
    for (final chunk in values.chunks(_maxBoundValues)) {
      batch.deleteWhere(this, (tbl) => filter(tbl, chunk));
    }
  }

  Selectable<int?> get count {
    final countExp = countAll();
    final query = select().addColumns([countExp]);
    return query.map((row) => row.read(countExp));
  }

  /// [select] that skips a row this version cannot read instead of failing the
  /// whole query; the row itself stays in the table.
  Selectable<R> readable<R extends Object>(
    R Function(Row row) read, {
    Expression<bool> Function(Tbl tbl)? where,
    List<OrderingTerm Function(Tbl tbl)> orderBy = const [],
  }) {
    final query = selectOnly()..addColumns($columns);
    if (where != null) {
      query.where(where(asDslTable));
    }
    query.orderBy([for (final term in orderBy) term(asDslTable)]);
    return _NonNullSelectable(
      query.map((row) => _readRow(row.rawData.data, read)),
    );
  }

  R? _readRow<R extends Object>(
    Map<String, Object?> data,
    R Function(Row row) read,
  ) {
    try {
      return read(map(data, tablePrefix: aliasedName) as Row);
    } catch (error) {
      commonPrint.log(
        'Skipped unreadable $actualTableName row: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<int> remove(Expression<bool> Function(Tbl tbl) filter) async {
    return (delete()..where(filter)).go();
  }

  Future<int> put(Insertable<Row> item) async {
    return insertOnConflictUpdate(item);
  }
}

class _NonNullSelectable<T extends Object> extends Selectable<T> {
  _NonNullSelectable(this._source);

  final Selectable<T?> _source;

  @override
  Future<List<T>> get() async => (await _source.get()).nonNulls.toList();

  @override
  Stream<List<T>> watch() =>
      _source.watch().map((rows) => rows.nonNulls.toList());
}

extension SimpleSelectStatementExt<T extends HasResultSet, D>
    on SimpleSelectStatement<T, D> {
  Selectable<int> get count {
    final countExp = countAll();
    final query = addColumns([countExp]);
    return query.map((row) => row.read(countExp)!);
  }
}

extension JoinedSelectStatementExt<T extends HasResultSet, D>
    on JoinedSelectStatement<T, D> {
  Selectable<int> get count {
    final countExp = countAll();
    addColumns([countExp]);
    return map((row) => row.read(countExp)!);
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value!;

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}

Database _database = Database();

Database get database => _database;

@visibleForTesting
set database(Database value) => _database = value;

/// A MITM module as a restore writes it. Consent given on the device the
/// backup came from does not carry over: the module is off and declined
/// until it is consented to on this one. Only that explicit local action
/// turns it on; the restore's recheck never does.
MitmModule restoredMitmModule(MitmModule module) =>
    module.copyWith(enabled: false, accepted: false);
