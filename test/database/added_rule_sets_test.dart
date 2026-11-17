import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Database database;

  const set = AddedRuleSet(
    id: 1,
    profileId: 1,
    name: 'ads',
    url: 'https://x.test/ads.yaml',
  );
  const rule = Rule(id: 10, ruleTarget: 'REJECT', order: 'a');

  setUp(() async {
    database = Database(NativeDatabase.memory());
    await database.profilesDao.putAll([
      const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
      const Profile(id: 2, autoUpdateDuration: Duration.zero).toCompanion(),
    ]);
  });

  tearDown(() => database.close());

  Future<List<Rule>> rulesOf(int profileId) =>
      database.rulesDao.queryAddedRules(profileId).get();

  test('a set is written with the rule that uses it', () async {
    await database.addedRuleSetsDao.put(set, rule);

    expect(await database.addedRuleSetsDao.query(1).get(), [set]);
    expect(await database.addedRuleSetsDao.query(2).get(), isEmpty);
    final saved = (await rulesOf(1)).single;
    expect(saved.ruleAction, RuleAction.RULE_SET);
    expect(saved.ruleProvider, 'ads');
    expect(saved.ruleTarget, 'REJECT');
  });

  test('renaming a set renames its rule, leaving one', () async {
    await database.addedRuleSetsDao.put(set, rule);
    await database.addedRuleSetsDao.put(
      set.copyWith(name: 'blocked', format: RuleProviderFormat.text),
      rule.copyWith(ruleProvider: 'blocked'),
    );

    final sets = await database.addedRuleSetsDao.query(1).get();
    expect(sets.single.name, 'blocked');
    expect(sets.single.format, RuleProviderFormat.text);
    final rules = await rulesOf(1);
    expect(rules.single.id, 10);
    expect(rules.single.ruleProvider, 'blocked');
  });

  test('removing a set takes its rules, not another profile\'s', () async {
    await database.addedRuleSetsDao.put(set, rule.copyWith(id: set.id));
    await database.addedRuleSetsDao.put(
      set.copyWith(id: 2, profileId: 2),
      rule.copyWith(id: 11),
    );

    await database.addedRuleSetsDao.remove(set);

    expect(await database.addedRuleSetsDao.query(1).get(), isEmpty);
    expect(await rulesOf(1), isEmpty);
    expect(await database.addedRuleSetsDao.query(2).get(), hasLength(1));
    expect((await rulesOf(2)).single.ruleProvider, 'ads');
  });

  test(
    'merge restore rejects same-name or same-id foreign sets atomically',
    () async {
      await database.addedRuleSetsDao.put(set, rule);
      for (final foreign in [set.copyWith(id: 2), set.copyWith(profileId: 2)]) {
        await expectLater(
          database.restore(
            [const Profile(id: 3, autoUpdateDuration: Duration.zero)],
            [],
            [],
            [],
            [],
            addedRuleSets: [foreign],
          ),
          throwsStateError,
        );
        expect(await database.addedRuleSetsDao.queryAll().get(), [set]);
        expect(
          (await database.profilesDao.query().get()).map((p) => p.id),
          isNot(contains(3)),
        );
        expect((await rulesOf(1)).single.id, rule.id);
      }
    },
  );

  test(
    'merge rejects cross-table ID collisions without changing rows',
    () async {
      final ordinary = rule.copyWith(id: 1, profileId: 2, content: 'foreign');
      await database.rulesDao.putRule(ordinary);
      await expectLater(
        database.restore(
          [],
          [],
          [
            rule.copyWith(
              id: 1,
              profileId: 1,
              ruleAction: RuleAction.RULE_SET,
              ruleProvider: 'ads',
            ),
          ],
          [],
          [],
          addedRuleSets: [set],
        ),
        throwsStateError,
      );
      expect(
        (await database.rulesDao.queryProfileRules(2).get()).single,
        ordinary,
      );
      expect(await database.addedRuleSetsDao.queryAll().get(), isEmpty);

      await database.rules.remove((t) => t.id.equals(ordinary.id));
      await database.addedRuleSetsDao.put(set, rule.copyWith(id: 1));
      final original = (await rulesOf(1)).single;
      await expectLater(
        database.restore([], [], [ordinary], [], []),
        throwsStateError,
      );
      expect((await rulesOf(1)).single, original);
      expect(await database.addedRuleSetsDao.queryAll().get(), [set]);
    },
  );

  test(
    'merge rejects collisions involving legacy differently keyed links',
    () async {
      final legacy = rule.copyWith(
        id: 99,
        profileId: 1,
        ruleAction: RuleAction.RULE_SET,
        ruleProvider: 'ads',
      );
      await database.addedRuleSetsDao.put(set, legacy);
      await expectLater(
        database.restore([], [], [rule.copyWith(id: 99, profileId: 2)], [], []),
        throwsStateError,
      );
      expect((await rulesOf(1)).single, legacy);
      await database.addedRuleSets.remove((t) => t.id.equals(set.id));
      await database.rules.remove((t) => t.id.equals(99));
      final foreign = rule.copyWith(id: 99, profileId: 2);
      await database.rulesDao.putRule(foreign);
      await expectLater(
        database.restore([], [], [legacy], [], [], addedRuleSets: [set]),
        throwsStateError,
      );
      expect(
        (await database.rulesDao.queryProfileRules(2).get()).single,
        foreign,
      );
      expect(await database.addedRuleSetsDao.queryAll().get(), isEmpty);
    },
  );

  test('a name is unique within a profile', () async {
    await database.addedRuleSetsDao.put(set, rule);

    await expectLater(
      database.addedRuleSetsDao.put(set.copyWith(id: 2), rule.copyWith(id: 11)),
      throwsA(anything),
    );
  });

  test(
    'profile rules and sets survive database reopen and stay isolated',
    () async {
      final dir = await Directory.systemTemp.createTemp('flash-rules-test-');
      final file = File('${dir.path}/rules.sqlite');
      try {
        var disk = Database(NativeDatabase(file));
        await disk.profilesDao.putAll([
          const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
          const Profile(id: 2, autoUpdateDuration: Duration.zero).toCompanion(),
        ]);
        await disk.addedRuleSetsDao.put(set, rule);
        await disk.close();
        disk = Database(NativeDatabase(file));
        expect(await disk.addedRuleSetsDao.query(1).get(), [set]);
        expect(
          (await disk.rulesDao.queryAddedRules(1).get()).single.ruleProvider,
          'ads',
        );
        expect(await disk.addedRuleSetsDao.query(2).get(), isEmpty);
        expect(await disk.rulesDao.queryAddedRules(2).get(), isEmpty);
        await disk.close();
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test('deleting the profile deletes its sets', () async {
    await database.addedRuleSetsDao.put(set, rule);

    await database.deleteProfile(1);

    expect(await database.addedRuleSetsDao.queryAll().get(), isEmpty);
  });
  test(
    'deleting paired set preserves another rule with the same provider',
    () async {
      await database.addedRuleSetsDao.put(set, rule.copyWith(id: set.id));
      await database.rulesDao.putRule(
        rule.copyWith(
          id: 20,
          ruleAction: RuleAction.RULE_SET,
          ruleProvider: 'ads',
        ),
        profileId: 1,
      );
      await database.addedRuleSetsDao.remove(set);
      final rules = await rulesOf(1);
      expect(rules.map((item) => item.id), [20]);
      expect(rules.single.ruleProvider, 'ads');
    },
  );

  test('ambiguous legacy set deletion fails without deleting rows', () async {
    await database.addedRuleSetsDao.put(set, rule);
    await database.rulesDao.putRule(
      rule.copyWith(
        id: 20,
        ruleAction: RuleAction.RULE_SET,
        ruleProvider: 'ads',
      ),
      profileId: 1,
    );
    await expectLater(database.addedRuleSetsDao.remove(set), throwsStateError);
    expect(await rulesOf(1), hasLength(2));
    expect(await database.addedRuleSetsDao.query(1).get(), [set]);
  });
  test('unique legacy name cannot prove rule ownership', () async {
    await database.addedRuleSetsDao.put(set, rule);
    await expectLater(database.addedRuleSetsDao.remove(set), throwsStateError);
    expect((await rulesOf(1)).single.id, rule.id);
    expect(await database.addedRuleSetsDao.query(1).get(), [set]);
  });
  test('v26 set rows upgrade with legacy null cache paths', () async {
    final dir = await Directory.systemTemp.createTemp('added-set-v26-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/old.sqlite');
    var disk = Database(NativeDatabase(file));
    await disk.profilesDao.putAll([
      const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
    ]);
    await disk.addedRuleSetsDao.put(set, rule.copyWith(id: set.id));
    await disk.close();
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('ALTER TABLE added_rule_sets DROP COLUMN cache_generation');
    raw.execute('PRAGMA user_version = 26');
    raw.close();
    disk = Database(NativeDatabase(file));
    final restored = (await disk.addedRuleSetsDao.query(1).get()).single;
    expect(restored.cacheGeneration, isNull);
    expect(restored.pathUnder(dir.path), set.pathUnder(dir.path));
    await disk.close();
  });

  test('invalid cache generation cannot escape its directory', () {
    expect(
      () => set.copyWith(cacheGeneration: '../other').pathUnder('/safe'),
      throwsStateError,
    );
  });
}
