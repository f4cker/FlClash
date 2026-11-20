import 'package:fl_clash/common/restore_mount_plan.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _file(int id, String label) =>
    Profile(id: id, label: label, autoUpdateDuration: Duration.zero);

Profile _sub(int id, String label) => _file(
  id,
  label,
).copyWith(type: ProfileType.url, url: 'https://example.invalid/$id');

MountTargetState _target(int id, List<int> sources, {int version = 1}) =>
    MountTargetState(targetId: id, sourceIds: sources, version: version);

void main() {
  RestoreMountPlan plan({
    bool isOverride = false,
    Map<int, MountTargetState> local = const {},
    List<Profile> localProfiles = const [],
    List<Profile> backupProfiles = const [],
    Map<int, MountTargetState>? backup,
  }) => planRestoreMounts(
    isOverride: isOverride,
    localTargets: local,
    localProfiles: localProfiles,
    backupProfiles: backupProfiles,
    backupTargets: backup,
  );

  test('every reason has its stable id', () {
    expect(
      {for (final r in RestoreMountReason.values) r.id},
      {
        'self',
        'source-not-subscription',
        'source-missing',
        'target-missing',
        'not-in-backup',
      },
    );
  });

  test('backup relations that are invalid are listed with their exact '
      'reason and never written', () {
    final result = plan(
      isOverride: true,
      backupProfiles: [_file(1, 'T'), _file(2, 'Local file'), _sub(3, 'Sub')],
      backup: {
        1: _target(1, [1, 2, 3, 99]),
      },
    );
    expect(
      {for (final r in result.invalid) r.relation.source.id: r.reason.id},
      {1: 'self', 2: 'source-not-subscription', 99: 'source-missing'},
    );
    expect(result.writes.single.sourceIds, [3]);
    expect(result.hasLosses, isFalse, reason: 'none of these was local');
    final missing = result.invalid.firstWhere(
      (r) => r.relation.source.id == 99,
    );
    expect(missing.relation.source.label, isNull, reason: 'never guessed');
  });

  test('override: a local relation the backup drops is a removal; the row '
      'stays with a version above both sides', () {
    final result = plan(
      isOverride: true,
      local: {
        1: _target(1, [2], version: 7),
      },
      localProfiles: [_file(1, 'T'), _sub(2, 'S')],
      backupProfiles: [_file(1, 'T'), _sub(2, 'S')],
      backup: {1: _target(1, [], version: 3)},
    );
    expect(result.removals.single.reason, RestoreMountReason.notInBackup);
    expect(result.writes.single.sourceIds, isEmpty);
    expect(result.writes.single.version, 8);
    expect(result.writes.single.pending.version, 8);
    expect(result.pendingCheck.single.id, 1);
  });

  test('override: a target missing from the backup loses its relations', () {
    final result = plan(
      isOverride: true,
      local: {
        5: _target(5, [6]),
      },
      localProfiles: [_file(5, 'Gone'), _sub(6, 'S')],
      backupProfiles: [_sub(6, 'S')],
      backup: const {},
    );
    expect(result.removals.single.reason, RestoreMountReason.targetMissing);
    expect(result.removals.single.relation.target.label, 'Gone');
    expect(result.writes, isEmpty);
  });

  test('a backup without mount data keeps local relations, filtered', () {
    final result = plan(
      isOverride: true,
      local: {
        1: _target(1, [2, 3]),
      },
      localProfiles: [_file(1, 'T'), _sub(2, 'S'), _sub(3, 'Gone')],
      backupProfiles: [_file(1, 'T'), _sub(2, 'S')],
    );
    expect(result.mountsCarried, isFalse);
    expect(result.kept.single.relation.source.id, 2);
    expect(result.kept.single.origin, RestoreMountOrigin.local);
    expect(result.removals.single.reason, RestoreMountReason.sourceMissing);
    expect(result.removals.single.relation.source.label, 'Gone');
  });

  test('compatible: the backup replaces a conflicting relation whole', () {
    final result = plan(
      local: {
        1: _target(1, [2, 3]),
      },
      localProfiles: [_file(1, 'T'), _sub(2, 'A'), _sub(3, 'X'), _sub(4, 'Y')],
      backupProfiles: [_file(1, 'T')],
      backup: {
        1: _target(1, [2, 4]),
      },
    );
    final replacement = result.replacements.single;
    expect(replacement.before.map((p) => p.id), [2, 3]);
    expect(replacement.after.map((p) => p.id), [2, 4]);
    expect(result.writes.single.sourceIds, [2, 4]);
    expect(result.removals, isEmpty);
    expect(
      {for (final k in result.kept) k.relation.source.id: k.origin},
      {2: RestoreMountOrigin.local, 4: RestoreMountOrigin.backup},
    );
  });

  test('compatible: a target whose source the backup updates is rebuilt '
      'unchanged; unrelated targets are not touched', () {
    final result = plan(
      local: {
        1: _target(1, [2]),
        5: _target(5, [6]),
      },
      localProfiles: [_file(1, 'T'), _sub(2, 'S'), _file(5, 'U'), _sub(6, 'V')],
      backupProfiles: [_sub(2, 'S')],
      backup: const {},
    );
    expect(result.writes.map((w) => w.targetId), [1]);
    expect(result.writes.single.sourceIds, [2]);
    expect(result.writes.single.version, 2);
    expect(result.hasLosses, isFalse);
  });

  test('compatible: a source the backup turns into a local file is removed '
      'with its reason', () {
    final result = plan(
      local: {
        1: _target(1, [2]),
      },
      localProfiles: [_file(1, 'T'), _sub(2, 'S')],
      backupProfiles: [_file(2, 'S now a file')],
      backup: const {},
    );
    expect(
      result.removals.single.reason,
      RestoreMountReason.sourceNotSubscription,
    );
    expect(result.writes.single.sourceIds, isEmpty);
  });

  test('the digest tells changed local mounts apart', () {
    RestoreMountPlan at(int version) => plan(
      local: {
        1: _target(1, [2], version: version),
      },
      localProfiles: [_file(1, 'T'), _sub(2, 'S')],
      backupProfiles: [_sub(2, 'S')],
    );
    expect(at(1).digest, at(1).digest);
    expect(at(1).digest, isNot(at(2).digest));
  });

  test('a restore without mounts on either side plans nothing', () {
    final result = plan(backupProfiles: [_sub(1, 'S')], backup: const {});
    expect(result.isEmpty, isTrue);
  });
}
