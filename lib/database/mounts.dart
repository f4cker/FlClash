part of 'database.dart';

/// A target profile taking the nodes of a source subscription.
@DataClassName('ProfileMountRow')
class ProfileMounts extends Table {
  @override
  String get tableName => 'profile_mounts';

  @ReferenceName('mountsAsTarget')
  IntColumn get targetId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  @ReferenceName('mountsAsSource')
  IntColumn get sourceId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {targetId, sourceId};
}

/// Outlives the target's last mount, so the profile keeps the guard against
/// mihomo's direct-only fallback and an unresolved operation keeps its lock.
@DataClassName('MountTargetRow')
class MountTargets extends Table {
  @override
  String get tableName => 'mount_targets';

  IntColumn get targetId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get groups => text().map(const StringListConverter())();

  IntColumn get version => integer()();

  TextColumn get pending =>
      text().map(const MountOperationConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {targetId};
}

@DataClassName('MountSourceStatusRow')
class MountSourceStatuses extends Table {
  @override
  String get tableName => 'mount_source_statuses';

  IntColumn get sourceId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get failure => textEnum<MountSourceFailure>().nullable()();

  DateTimeColumn get failedAt => dateTime().nullable()();

  DateTimeColumn get succeededAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {sourceId};
}

/// An unreadable record reads as one of unknown kind, which still locks.
class MountOperationConverter extends TypeConverter<MountOperation?, String?> {
  const MountOperationConverter();

  @override
  MountOperation? fromSql(String? fromDb) {
    if (fromDb == null) return null;
    return decodeOrRestoreDefault(
      'mount operation',
      () => MountOperation.fromJson(json.decode(fromDb)),
      () => const MountOperation(kind: MountOperationKind.unknown, version: -1),
    );
  }

  @override
  String? toSql(MountOperation? value) {
    if (value == null) return null;
    return json.encode(value.toJson());
  }
}

@DriftAccessor(tables: [ProfileMounts, MountTargets, MountSourceStatuses])
class MountsDao extends DatabaseAccessor<Database> with _$MountsDaoMixin {
  MountsDao(super.attachedDatabase);

  Selectable<ProfileMountRow> _mountsOf(int targetId) {
    return (select(profileMounts)
      ..where((t) => t.targetId.equals(targetId))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]));
  }

  Future<MountTargetState?> target(int targetId) async {
    final row = await (select(
      mountTargets,
    )..where((t) => t.targetId.equals(targetId))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    final mounts = await _mountsOf(targetId).get();
    return MountTargetState(
      targetId: targetId,
      sourceIds: [for (final mount in mounts) mount.sourceId],
      groups: row.groups,
      version: row.version,
      pending: row.pending,
    );
  }

  Future<Map<int, MountTargetState>> targets() async {
    final rows = await select(mountTargets).get();
    final mounts = await (select(
      profileMounts,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    return {
      for (final row in rows)
        row.targetId: MountTargetState(
          targetId: row.targetId,
          sourceIds: [
            for (final mount in mounts)
              if (mount.targetId == row.targetId) mount.sourceId,
          ],
          groups: row.groups,
          version: row.version,
          pending: row.pending,
        ),
    };
  }

  /// Every target with a mount record, by target id. Also wakes on profile
  /// writes, as a deleted profile takes its mount rows along by cascade.
  Stream<Map<int, MountTargetState>> watchTargets() {
    return customSelect(
          'SELECT 1',
          readsFrom: {mountTargets, profileMounts, attachedDatabase.profiles},
        )
        .watch()
        .asyncMap((_) => targets())
        .distinct(const DeepCollectionEquality().equals);
  }

  Stream<MountTargetState?> watchTarget(int targetId) {
    return watchTargets().map((targets) => targets[targetId]).distinct();
  }

  /// The targets that mount [sourceId], in target id order.
  Future<List<int>> targetsOf(int sourceId) async {
    final rows =
        await (select(profileMounts)
              ..where((t) => t.sourceId.equals(sourceId))
              ..orderBy([(t) => OrderingTerm.asc(t.targetId)]))
            .get();
    return [for (final row in rows) row.targetId];
  }

  /// Writes the whole relation of [targetId] and its next version in one
  /// transaction, with [pending] as the record of what is being applied.
  /// A save built on a stale read, or made while an earlier one is not yet
  /// resolved, never lands.
  Future<MountTargetState> save({
    required int targetId,
    required int? expectedVersion,
    required List<int> sourceIds,
    required List<String> groups,
    required MountOperation Function(int version) pending,
  }) {
    return transaction(() async {
      final current = await target(targetId);
      if (current?.version != expectedVersion) {
        throw const MountVersionConflict();
      }
      if (current?.pending != null) {
        throw const MountOperationUnresolved();
      }
      final version = (expectedVersion ?? 0) + 1;
      final operation = pending(version);
      await (delete(
        profileMounts,
      )..where((t) => t.targetId.equals(targetId))).go();
      await batch((b) {
        b.insertAll(profileMounts, [
          for (final (index, sourceId) in sourceIds.indexed)
            ProfileMountsCompanion.insert(
              targetId: targetId,
              sourceId: sourceId,
              position: index,
            ),
        ]);
      });
      await into(mountTargets).insertOnConflictUpdate(
        MountTargetsCompanion.insert(
          targetId: Value(targetId),
          groups: groups,
          version: version,
          pending: Value(operation),
        ),
      );
      return MountTargetState(
        targetId: targetId,
        sourceIds: sourceIds,
        groups: groups,
        version: version,
        pending: operation,
      );
    });
  }

  /// Clears [targetId]'s record only while it is still the one for [version].
  Future<bool> settle(int targetId, int version) async {
    final rows =
        await (update(mountTargets)..where(
              (t) => t.targetId.equals(targetId) & t.version.equals(version),
            ))
            .write(const MountTargetsCompanion(pending: Value(null)));
    return rows > 0;
  }

  /// Unmounts [sourceId] from every target, each left with a record of the
  /// removal, and fails when any of them still has a record pending.
  Future<List<MountTargetState>> beginSourceRemoval(int sourceId) {
    return transaction(() async {
      final targets = <MountTargetState>[];
      for (final targetId in await targetsOf(sourceId)) {
        final current = await target(targetId);
        if (current == null) continue;
        if (current.pending != null) {
          throw const MountOperationUnresolved();
        }
        targets.add(current);
      }
      await (delete(
        profileMounts,
      )..where((t) => t.sourceId.equals(sourceId))).go();
      final marked = <MountTargetState>[];
      for (final current in targets) {
        final version = current.version + 1;
        final operation = MountOperation(
          kind: MountOperationKind.deleteSource,
          version: version,
          sourceIds: [sourceId],
        );
        await (update(
          mountTargets,
        )..where((t) => t.targetId.equals(current.targetId))).write(
          MountTargetsCompanion(
            version: Value(version),
            pending: Value(operation),
          ),
        );
        marked.add(
          current.copyWith(
            sourceIds: [
              for (final id in current.sourceIds)
                if (id != sourceId) id,
            ],
            version: version,
            pending: operation,
          ),
        );
      }
      return marked;
    });
  }

  Map<int, MountSourceRecord> _records(List<MountSourceStatusRow> rows) => {
    for (final row in rows)
      row.sourceId: MountSourceRecord(
        sourceId: row.sourceId,
        failure: row.failure,
        failedAt: row.failedAt,
        succeededAt: row.succeededAt,
      ),
  };

  Future<Map<int, MountSourceRecord>> statuses() async {
    return _records(await select(mountSourceStatuses).get());
  }

  Stream<Map<int, MountSourceRecord>> watchStatuses() {
    return select(
      mountSourceStatuses,
    ).watch().map(_records).distinct(const DeepCollectionEquality().equals);
  }

  /// A failure stays until an update of the source actually succeeds.
  Future<void> recordSourceResult(
    int sourceId, {
    MountSourceFailure? failure,
    required DateTime at,
  }) async {
    if (failure == null) {
      await into(mountSourceStatuses).insertOnConflictUpdate(
        MountSourceStatusesCompanion.insert(
          sourceId: Value(sourceId),
          failure: const Value(null),
          failedAt: const Value(null),
          succeededAt: Value(at),
        ),
      );
      return;
    }
    await into(mountSourceStatuses).insert(
      MountSourceStatusesCompanion.insert(
        sourceId: Value(sourceId),
        failure: Value(failure),
        failedAt: Value(at),
      ),
      onConflict: DoUpdate(
        (_) => MountSourceStatusesCompanion(
          failure: Value(failure),
          failedAt: Value(at),
        ),
      ),
    );
  }

  Future<bool> isMounted(int sourceId) async {
    final row =
        await (select(profileMounts)
              ..where((t) => t.sourceId.equals(sourceId))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }
}
