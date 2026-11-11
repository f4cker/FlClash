import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Database database;

  setUp(() async {
    database = Database(NativeDatabase.memory());
    await database.profilesDao.putAll([
      for (final id in [1, 2, 3, 4])
        Profile(
          id: id,
          label: 'P$id',
          autoUpdateDuration: Duration.zero,
          type: id == 1 ? ProfileType.file : ProfileType.url,
        ).toCompanion(),
    ]);
  });

  tearDown(() async {
    await database.close();
  });

  MountOperation saving(int version) =>
      MountOperation(kind: MountOperationKind.save, version: version);

  test('a save writes the relation in order with a pending record', () async {
    final saved = await database.mountsDao.save(
      targetId: 1,
      expectedVersion: null,
      sourceIds: [3, 2],
      groups: ['Proxy'],
      pending: saving,
    );

    expect(saved.version, 1);
    final read = await database.mountsDao.target(1);
    expect(read, saved);
    expect(read!.sourceIds, [3, 2]);
    expect(read.pending, saving(1));
    expect(await database.mountsDao.targetsOf(2), [1]);
  });

  test('a save on a stale version or over a pending record fails', () async {
    await database.mountsDao.save(
      targetId: 1,
      expectedVersion: null,
      sourceIds: [2],
      groups: const [],
      pending: saving,
    );

    expect(
      () => database.mountsDao.save(
        targetId: 1,
        expectedVersion: 1,
        sourceIds: [3],
        groups: const [],
        pending: saving,
      ),
      throwsA(isA<MountOperationUnresolved>()),
    );
    expect(await database.mountsDao.settle(1, 1), isTrue);
    expect(
      () => database.mountsDao.save(
        targetId: 1,
        expectedVersion: null,
        sourceIds: [3],
        groups: const [],
        pending: saving,
      ),
      throwsA(isA<MountVersionConflict>()),
    );
    final next = await database.mountsDao.save(
      targetId: 1,
      expectedVersion: 1,
      sourceIds: const [],
      groups: const [],
      pending: saving,
    );
    expect(next.version, 2);
    expect((await database.mountsDao.target(1))!.sourceIds, isEmpty);
  });

  test('settle clears only the record of its own version', () async {
    await database.mountsDao.save(
      targetId: 1,
      expectedVersion: null,
      sourceIds: [2],
      groups: const [],
      pending: saving,
    );

    expect(await database.mountsDao.settle(1, 7), isFalse);
    expect((await database.mountsDao.target(1))!.pending, isNotNull);
    expect(await database.mountsDao.settle(1, 1), isTrue);
    expect((await database.mountsDao.target(1))!.pending, isNull);
  });

  test('deleting a profile cascades into its mounts and status', () async {
    await database.mountsDao.save(
      targetId: 1,
      expectedVersion: null,
      sourceIds: [2, 3],
      groups: const [],
      pending: saving,
    );
    await database.mountsDao.recordSourceResult(
      2,
      failure: MountSourceFailure.fetch,
      at: DateTime(2026),
    );

    await database.deleteProfile(2);

    expect((await database.mountsDao.target(1))!.sourceIds, [3]);
    expect(await database.mountsDao.statuses(), isEmpty);

    await database.deleteProfile(1);

    expect(await database.mountsDao.target(1), isNull);
    expect(await database.mountsDao.targetsOf(3), isEmpty);
  });

  test('source removal unmounts it and marks each target', () async {
    await database.mountsDao.save(
      targetId: 1,
      expectedVersion: null,
      sourceIds: [2, 3],
      groups: const [],
      pending: saving,
    );
    await database.mountsDao.settle(1, 1);

    final marked = await database.mountsDao.beginSourceRemoval(2);

    expect(marked.single.sourceIds, [3]);
    final read = await database.mountsDao.target(1);
    expect(read!.sourceIds, [3]);
    expect(read.version, 2);
    expect(read.pending?.kind, MountOperationKind.deleteSource);
    expect(read.pending?.sourceIds, [2]);
    expect(
      () => database.mountsDao.beginSourceRemoval(3),
      throwsA(isA<MountOperationUnresolved>()),
    );
    expect((await database.mountsDao.target(1))!.sourceIds, [3]);
  });

  test('a failure stays until a later success clears it', () async {
    final dao = database.mountsDao;
    await dao.recordSourceResult(2, at: DateTime(2026, 1, 1));
    await dao.recordSourceResult(
      2,
      failure: MountSourceFailure.unsupported,
      at: DateTime(2026, 1, 2),
    );

    var status = (await dao.statuses())[2]!;
    expect(status.failure, MountSourceFailure.unsupported);
    expect(status.succeededAt, DateTime(2026, 1, 1));

    await dao.recordSourceResult(2, at: DateTime(2026, 1, 3));

    status = (await dao.statuses())[2]!;
    expect(status.failure, isNull);
    expect(status.failedAt, isNull);
    expect(status.succeededAt, DateTime(2026, 1, 3));
  });

  test('an unreadable pending record still locks the target', () async {
    await database.mountsDao.save(
      targetId: 1,
      expectedVersion: null,
      sourceIds: [2],
      groups: const [],
      pending: saving,
    );
    await database.customStatement(
      "UPDATE mount_targets SET pending = '{' WHERE target_id = 1",
    );

    final read = await database.mountsDao.target(1);
    expect(read!.pending?.kind, MountOperationKind.unknown);
  });
}
