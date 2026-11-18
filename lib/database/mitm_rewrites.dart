part of 'database.dart';

/// A profile's own rewrite rules ([MitmList.urlRewrite],
/// [MitmList.headerRewrite], [MitmList.bodyRewrite], [MitmList.mapLocal]),
/// one Surge line each, as the Rules table keeps a profile's added rules:
/// they go with the profile, outlive its updates and are sent to the Core
/// while it is the current one.
@DataClassName('RawMitmRewrite')
@TableIndex(
  name: 'idx_mitm_rewrites_profile_order',
  columns: {#profileId, #order},
)
class MitmRewrites extends Table {
  @override
  String get tableName => 'mitm_rewrites';

  IntColumn get id => integer()();

  IntColumn get profileId => integer().nullable().references(
    Profiles,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get section => textEnum<MitmList>()();

  TextColumn get line => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  TextColumn get order => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftAccessor(tables: [MitmRewrites])
class MitmRewritesDao extends DatabaseAccessor<Database>
    with _$MitmRewritesDaoMixin {
  MitmRewritesDao(super.attachedDatabase);

  Selectable<MitmRewrite> queryProfile(int profileId) {
    final query = mitmRewrites.select()
      ..where((t) => t.profileId.equals(profileId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.order, nulls: NullsOrder.last),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return query.map((row) => row.toMitmRewrite());
  }

  Future<int> put(MitmRewrite rewrite, {int? profileId}) {
    return mitmRewrites.insertOnConflictUpdate(rewrite.toCompanion(profileId));
  }

  Future<void> delAll(Iterable<int> ids) {
    return batch((b) {
      mitmRewrites.deleteInChunks(b, ids, (t, chunk) => t.id.isIn(chunk));
    });
  }

  Future<int> order({required int id, required String order}) {
    final stmt = mitmRewrites.update()..where((t) => t.id.equals(id));
    return stmt.write(MitmRewritesCompanion(order: Value(order)));
  }

  /// Replaces the profile's rules with [rewrites], ordered as given.
  void setProfileWithBatch(
    int profileId,
    Batch b,
    Iterable<MitmRewrite> rewrites,
  ) {
    final keys = indexing.generateNKeys(rewrites.length);
    mitmRewrites.setAll(
      b,
      rewrites.mapIndexed(
        (index, item) =>
            item.copyWith(order: keys[index]).toCompanion(profileId),
      ),
      deleteFilter: (t) => t.profileId.equals(profileId),
      preDelete: true,
    );
  }
}

extension RawMitmRewriteExt on RawMitmRewrite {
  MitmRewrite toMitmRewrite() {
    return MitmRewrite(
      id: id,
      profileId: profileId,
      section: section,
      line: line,
      enabled: enabled,
      order: order,
    );
  }
}

extension MitmRewritesCompanionExt on MitmRewrite {
  MitmRewritesCompanion toCompanion([int? profileId]) {
    return MitmRewritesCompanion.insert(
      id: Value(id),
      profileId: Value(profileId ?? this.profileId),
      section: section,
      line: line,
      enabled: Value(enabled),
      order: Value(order),
    );
  }
}
