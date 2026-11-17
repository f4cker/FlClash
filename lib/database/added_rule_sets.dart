part of 'database.dart';

/// The rule sets the rules page added to a profile. Each goes with a
/// `RULE-SET,name,target` row of [Rules] in the same profile, which holds its
/// place among the added rules and its group; [name] links the two.
@DataClassName('RawAddedRuleSet')
class AddedRuleSets extends Table {
  @override
  String get tableName => 'added_rule_sets';

  IntColumn get id => integer()();

  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  TextColumn get url => text()();

  TextColumn get cacheGeneration => text().nullable()();

  TextColumn get behavior => textEnum<RuleProviderBehavior>()();

  TextColumn get format => textEnum<RuleProviderFormat>()();

  IntColumn get interval =>
      integer().withDefault(const Constant(defaultAddedRuleSetInterval))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, name},
  ];
}

@DriftAccessor(tables: [AddedRuleSets, Rules])
class AddedRuleSetsDao extends DatabaseAccessor<Database>
    with _$AddedRuleSetsDaoMixin {
  AddedRuleSetsDao(super.attachedDatabase);

  Selectable<AddedRuleSet> query(int profileId) {
    return (addedRuleSets.select()
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .map((row) => row.toAddedRuleSet());
  }

  Selectable<AddedRuleSet> queryAll() {
    return (addedRuleSets.select()..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .map((row) => row.toAddedRuleSet());
  }

  Expression<bool> _linkedRule($RulesTable t, int profileId, String name) =>
      t.profileId.equals(profileId) &
      t.ruleAction.equalsValue(RuleAction.RULE_SET) &
      t.ruleProvider.equals(name);

  /// Writes [set] and the rule that uses it in one go. An edit that renames
  /// the set renames its rule with it.
  Future<void> put(AddedRuleSet set, Rule rule) {
    return transaction(() async {
      await addedRuleSets.insertOnConflictUpdate(set.toCompanion());
      await rules.insertOnConflictUpdate(
        rule
            .copyWith(
              ruleAction: RuleAction.RULE_SET,
              ruleProvider: set.name,
              content: null,
            )
            .toCompanion(set.profileId),
      );
    });
  }

  /// Removes the set and its identified paired rule, leaving other references.
  Future<void> remove(AddedRuleSet set) {
    return transaction(() async {
      final linked =
          await (rules.select()
                ..where((t) => _linkedRule(t, set.profileId, set.name)))
              .get();
      final exact = linked.where((rule) => rule.id == set.id).toList();
      // A legacy name reference does not prove ownership, even if unique.
      if (exact.isEmpty && linked.isNotEmpty) {
        throw StateError('Ambiguous added rule set link: ${set.name}');
      }
      final paired = exact.firstOrNull;
      if (paired != null) {
        await (rules.delete()..where((t) => t.id.equals(paired.id))).go();
      }
      await (addedRuleSets.delete()..where((t) => t.id.equals(set.id))).go();
    });
  }

  void putAllWithBatch(Batch batch, Iterable<AddedRuleSet> sets) {
    // A set of the same profile and name under another id gives way.
    batch.insertAll(
      addedRuleSets,
      sets.map((item) => item.toCompanion()),
      mode: InsertMode.insertOrReplace,
    );
  }

  void setAllWithBatch(Batch batch, Iterable<AddedRuleSet> sets) {
    batch.deleteAll(addedRuleSets);
    putAllWithBatch(batch, sets);
  }
}

extension RawAddedRuleSetExt on RawAddedRuleSet {
  AddedRuleSet toAddedRuleSet() {
    return AddedRuleSet(
      id: id,
      profileId: profileId,
      name: name,
      url: url,
      behavior: behavior,
      format: format,
      interval: interval,
      cacheGeneration: cacheGeneration,
    );
  }
}

extension AddedRuleSetsCompanionExt on AddedRuleSet {
  AddedRuleSetsCompanion toCompanion() {
    return AddedRuleSetsCompanion.insert(
      id: Value(id),
      profileId: profileId,
      name: name,
      url: url,
      behavior: behavior,
      format: format,
      interval: Value(interval),
      cacheGeneration: Value(cacheGeneration),
    );
  }
}
