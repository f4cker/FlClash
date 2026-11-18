part of 'database.dart';

/// A profile's own http-request and http-response scripts: a Surge [Script]
/// line whose script-path names [file] in the resources directory.
@DataClassName('RawMitmScript')
class MitmScripts extends Table {
  @override
  String get tableName => 'mitm_scripts';

  IntColumn get id => integer()();

  IntColumn get profileId => integer().nullable().references(
    Profiles,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get line => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  TextColumn get order => text().nullable()();

  TextColumn get url => text().nullable()();

  TextColumn get source => text().withDefault(const Constant(''))();

  TextColumn get file => text()();

  TextColumn get pendingFile => text().nullable()();

  DateTimeColumn get checkedAt => dateTime().nullable()();

  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftAccessor(tables: [MitmScripts])
class MitmScriptsDao extends DatabaseAccessor<Database>
    with _$MitmScriptsDaoMixin {
  MitmScriptsDao(super.attachedDatabase);

  Selectable<MitmScript> queryProfile(int profileId) {
    final query = mitmScripts.select()
      ..where((t) => t.profileId.equals(profileId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.order, nulls: NullsOrder.last),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return query.map((row) => row.toMitmScript());
  }

  Selectable<MitmScript> queryAll() =>
      mitmScripts.select().map((row) => row.toMitmScript());

  void setProfileWithBatch(int profileId, Batch b, List<MitmScript> scripts) {
    final keys = indexing.generateNKeys(scripts.length);
    mitmScripts.setAll(
      b,
      scripts.mapIndexed(
        (index, item) =>
            item.copyWith(order: keys[index]).toCompanion(profileId),
      ),
      deleteFilter: (t) => t.profileId.equals(profileId),
      preDelete: true,
    );
  }
}

extension RawMitmScriptExt on RawMitmScript {
  MitmScript toMitmScript() => MitmScript(
    id: id,
    profileId: profileId,
    line: line,
    enabled: enabled,
    order: order,
    url: url,
    source: source,
    file: file,
    pendingFile: pendingFile,
    checkedAt: checkedAt,
    error: error,
  );
}

extension MitmScriptsCompanionExt on MitmScript {
  MitmScriptsCompanion toCompanion([int? profileId]) {
    return MitmScriptsCompanion.insert(
      id: Value(id),
      profileId: Value(profileId ?? this.profileId),
      line: line,
      enabled: Value(enabled),
      order: Value(order),
      url: Value(url),
      source: Value(source),
      file: file,
      pendingFile: Value(pendingFile),
      checkedAt: Value(checkedAt),
      error: Value(error),
    );
  }
}
