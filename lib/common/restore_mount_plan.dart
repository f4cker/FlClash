import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// Why a relation cannot be kept. Each [id] is stable: tests, logs and the
/// confirmation list name a reason by it, never by its wording.
enum RestoreMountReason {
  /// The profile would mount itself.
  self('self'),

  /// The source exists after the restore, but is not a subscription.
  sourceNotSubscription('source-not-subscription'),

  /// The source exists neither in the backup nor, when it is kept, locally.
  sourceMissing('source-missing'),

  /// The target profile itself does not exist after the restore.
  targetMissing('target-missing'),

  /// An override restore rebuilds every relation from the backup, which
  /// does not have this one.
  notInBackup('not-in-backup');

  final String id;

  const RestoreMountReason(this.id);

  /// Reasons that make a relation invalid wherever it comes from.
  bool get isInvalid =>
      this == self || this == sourceNotSubscription || this == sourceMissing;
}

/// A profile as the plan names it. A missing name is left null, not
/// guessed: the view says the name is unavailable and shows [id].
class RestoreMountProfile {
  final int id;
  final String? label;
  final ProfileType? type;

  const RestoreMountProfile(this.id, {this.label, this.type});

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'type': type?.name,
  };

  @override
  bool operator ==(Object other) =>
      other is RestoreMountProfile &&
      other.id == id &&
      other.label == label &&
      other.type == type;

  @override
  int get hashCode => Object.hash(id, label, type);
}

/// One target ← source relation. [groupSize] is how many relations its
/// target has in the same group, so two rows that look alike can be told
/// apart by their ids.
class RestoreMountRelation {
  final RestoreMountProfile target;
  final RestoreMountProfile source;

  const RestoreMountRelation(this.target, this.source);

  Map<String, Object?> toJson() => {
    'target': target.toJson(),
    'source': source.toJson(),
  };
}

class RestoreMountRemoval {
  final RestoreMountRelation relation;
  final RestoreMountReason reason;

  const RestoreMountRemoval(this.relation, this.reason);

  Map<String, Object?> toJson() => {...relation.toJson(), 'reason': reason.id};
}

/// A compatible restore replacing a target's whole local relation with the
/// backup's. Never a union.
class RestoreMountReplacement {
  final RestoreMountProfile target;
  final List<RestoreMountProfile> before;
  final List<RestoreMountProfile> after;

  const RestoreMountReplacement(this.target, this.before, this.after);

  Map<String, Object?> toJson() => {
    'target': target.toJson(),
    'before': [for (final s in before) s.toJson()],
    'after': [for (final s in after) s.toJson()],
  };
}

/// A MITM module a restore writes, as the confirmation lists it. Every one
/// is written turned off and not consented to.
class RestoreMitmModule {
  final int id;
  final String name;

  const RestoreMitmModule(this.id, this.name);
}

enum RestoreMountOrigin { local, backup }

class RestoreMountKept {
  final RestoreMountRelation relation;
  final RestoreMountOrigin origin;

  const RestoreMountKept(this.relation, this.origin);

  Map<String, Object?> toJson() => {
    ...relation.toJson(),
    'origin': origin.name,
  };
}

/// The rows a restore writes for one target, in its transaction.
class RestoreMountWrite {
  final int targetId;
  final List<int> sourceIds;
  final int version;

  const RestoreMountWrite(this.targetId, this.sourceIds, this.version);

  MountOperation get pending => MountOperation(
    kind: MountOperationKind.save,
    version: version,
    sourceIds: sourceIds,
  );

  Map<String, Object?> toJson() => {
    'target': targetId,
    'sources': sourceIds,
    'version': version,
  };
}

/// What a restore will do to mount relations, computed before anything is
/// written and again inside the write transaction. [digest] tells the two
/// apart: a plan confirmed by the user is only written while it still
/// holds.
class RestoreMountPlan {
  final bool isOverride;
  final bool mountsCarried;

  /// Local relations that will be gone. These are losses.
  final List<RestoreMountRemoval> removals;

  /// Targets whose local relation the backup replaces. These are losses.
  final List<RestoreMountReplacement> replacements;

  /// Relations that exist after the restore: those kept as they are
  /// locally and those the backup brings; see [keptLocally] and
  /// [restoredFromBackup].
  final List<RestoreMountKept> kept;

  /// Backup relations that are not written, and are not local either.
  final List<RestoreMountRemoval> invalid;

  /// Every target rebuilt. Each stays locked until it is checked.
  final List<RestoreMountWrite> writes;

  /// The targets in [writes], by profile.
  final List<RestoreMountProfile> pendingCheck;

  final String digest;

  const RestoreMountPlan({
    required this.isOverride,
    required this.mountsCarried,
    this.removals = const [],
    this.replacements = const [],
    this.kept = const [],
    this.invalid = const [],
    this.writes = const [],
    this.pendingCheck = const [],
    this.digest = '',
  });

  static const empty = RestoreMountPlan(
    isOverride: false,
    mountsCarried: false,
  );

  int get removalCount => removals.length;

  int get replacementCount => replacements.length;

  /// An override with mount data: every target it touches is rewritten from
  /// the backup, so [keptLocally] are relations the same before and after,
  /// not ones left alone.
  bool get rewritesFromBackup => isOverride && mountsCarried;

  /// Relations that exist locally now and stay as they are.
  List<RestoreMountKept> get keptLocally => [
    for (final k in kept)
      if (k.origin == RestoreMountOrigin.local) k,
  ];

  /// Relations the backup brings that do not exist locally now; never
  /// counted as kept.
  List<RestoreMountKept> get restoredFromBackup => [
    for (final k in kept)
      if (k.origin == RestoreMountOrigin.backup) k,
  ];

  bool get hasLosses => removals.isNotEmpty || replacements.isNotEmpty;

  /// Whether the restore touches mounts at all.
  bool get isEmpty =>
      removals.isEmpty &&
      replacements.isEmpty &&
      kept.isEmpty &&
      invalid.isEmpty &&
      writes.isEmpty;
}

/// Plans the mount rows of a restore from the local state and the backup.
///
/// [backupTargets] is null when the backup carries no mount tables: it
/// then has no opinion and the local relations are kept, filtered to what
/// stays valid.
RestoreMountPlan planRestoreMounts({
  required bool isOverride,
  required Map<int, MountTargetState> localTargets,
  required List<Profile> localProfiles,
  required List<Profile> backupProfiles,
  required Map<int, MountTargetState>? backupTargets,
}) {
  final local = {for (final p in localProfiles) p.id: p};
  final backup = {for (final p in backupProfiles) p.id: p};
  final finals = isOverride ? backup : {...local, ...backup};
  final imported = backup.keys.toSet();
  final carried = backupTargets != null;
  final bTargets = backupTargets ?? const <int, MountTargetState>{};

  RestoreMountProfile profileOf(int id) {
    final profile = finals[id] ?? local[id] ?? backup[id];
    if (profile == null) return RestoreMountProfile(id);
    return RestoreMountProfile(
      id,
      label: profile.realLabel,
      type: finals[id]?.type ?? profile.type,
    );
  }

  RestoreMountReason? invalidity(int targetId, int sourceId) {
    if (sourceId == targetId) return RestoreMountReason.self;
    final source = finals[sourceId];
    if (source == null) return RestoreMountReason.sourceMissing;
    if (source.type != ProfileType.url) {
      return RestoreMountReason.sourceNotSubscription;
    }
    return null;
  }

  final removals = <RestoreMountRemoval>[];
  final replacements = <RestoreMountReplacement>[];
  final kept = <RestoreMountKept>[];
  final invalid = <RestoreMountRemoval>[];
  final writes = <RestoreMountWrite>[];

  final targetIds = {...localTargets.keys, ...bTargets.keys}.toList()..sort();
  for (final t in targetIds) {
    final l = localTargets[t];
    final b = bTargets[t];
    final localLinks = l?.sourceIds ?? const <int>[];
    final backupLinks = b?.sourceIds ?? const <int>[];
    RestoreMountRelation rel(int s) =>
        RestoreMountRelation(profileOf(t), profileOf(s));

    if (!finals.containsKey(t)) {
      for (final s in localLinks) {
        removals.add(
          RestoreMountRemoval(rel(s), RestoreMountReason.targetMissing),
        );
      }
      for (final s in backupLinks) {
        if (localLinks.contains(s)) continue;
        invalid.add(
          RestoreMountRemoval(rel(s), RestoreMountReason.targetMissing),
        );
      }
      continue;
    }

    final List<int> candidate;
    final bool touched;
    final bool fromBackup;
    if (isOverride) {
      fromBackup = carried;
      candidate = carried ? backupLinks : localLinks;
      touched = true;
    } else if (imported.contains(t) && b != null) {
      fromBackup = true;
      candidate = backupLinks;
      touched = true;
    } else if (l != null &&
        (imported.contains(t) || localLinks.any(imported.contains))) {
      fromBackup = false;
      candidate = localLinks;
      touched = true;
    } else {
      // Nothing about this target comes from the backup: left as it is.
      continue;
    }
    if (!touched) continue;

    final result = <int>[];
    final rejected = <int, RestoreMountReason>{};
    for (final s in candidate) {
      if (result.contains(s) || rejected.containsKey(s)) continue;
      final reason = invalidity(t, s);
      if (reason == null) {
        result.add(s);
      } else {
        rejected[s] = reason;
      }
    }

    final lost = [
      for (final s in localLinks)
        if (!result.contains(s)) s,
    ];
    if (!isOverride && fromBackup && l != null) {
      final validLocal = [
        for (final s in localLinks)
          if (invalidity(t, s) == null) s,
      ];
      final replaced = [
        for (final s in validLocal)
          if (!result.contains(s)) s,
      ];
      final added = [
        for (final s in result)
          if (!localLinks.contains(s)) s,
      ];
      if (replaced.isNotEmpty || added.isNotEmpty) {
        replacements.add(
          RestoreMountReplacement(
            profileOf(t),
            [for (final s in validLocal) profileOf(s)],
            [for (final s in result) profileOf(s)],
          ),
        );
      }
      for (final s in lost) {
        final reason = invalidity(t, s);
        if (reason != null) {
          removals.add(RestoreMountRemoval(rel(s), reason));
        }
      }
    } else {
      for (final s in lost) {
        removals.add(
          RestoreMountRemoval(
            rel(s),
            invalidity(t, s) ?? RestoreMountReason.notInBackup,
          ),
        );
      }
    }
    for (final MapEntry(key: s, value: reason) in rejected.entries) {
      if (localLinks.contains(s)) continue;
      invalid.add(RestoreMountRemoval(rel(s), reason));
    }
    for (final s in result) {
      kept.add(
        RestoreMountKept(
          rel(s),
          localLinks.contains(s)
              ? RestoreMountOrigin.local
              : RestoreMountOrigin.backup,
        ),
      );
    }
    // A target keeps its row even with no source left: the row guards
    // against the direct-only fallback and keeps the version rising.
    if (l != null || b != null) {
      final version =
          [
            l?.version ?? 0,
            b?.version ?? 0,
            0,
          ].reduce((a, c) => a > c ? a : c) +
          1;
      writes.add(RestoreMountWrite(t, result, version));
    }
  }

  final pendingCheck = [for (final w in writes) profileOf(w.targetId)];
  final digest = sha256
      .convert(
        utf8.encode(
          json.encode({
            'override': isOverride,
            'carried': carried,
            'local': [
              for (final id in localTargets.keys.toList()..sort())
                {
                  'target': id,
                  'sources': localTargets[id]!.sourceIds,
                  'version': localTargets[id]!.version,
                  'pending': localTargets[id]!.pending != null,
                },
            ],
            'removals': [for (final r in removals) r.toJson()],
            'replacements': [for (final r in replacements) r.toJson()],
            'kept': [for (final k in kept) k.toJson()],
            'invalid': [for (final r in invalid) r.toJson()],
            'writes': [for (final w in writes) w.toJson()],
          }),
        ),
      )
      .toString();
  return RestoreMountPlan(
    isOverride: isOverride,
    mountsCarried: carried,
    removals: removals,
    replacements: replacements,
    kept: kept,
    invalid: invalid,
    writes: writes,
    pendingCheck: pendingCheck,
    digest: digest,
  );
}
