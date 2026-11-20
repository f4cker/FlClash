import 'package:fl_clash/common/restore_journal.dart';
import 'package:fl_clash/common/restore_mount_plan.dart';

/// The result a restore may claim, one per row of the design's evidence
/// table. Nothing here is guessed from an exception type.
enum RestoreResultKind {
  /// The pre-check failed and no write started.
  notStarted,

  /// Failed before the commit; the rollback finished and was verified.
  rolledBack,

  /// Whether the rollback is complete is unknown or failed.
  rollbackUnverified,

  /// Committed, but follow-up steps are still owed or unknown.
  committedLocked,

  /// Committed; another (older) version changed the data and steps were
  /// skipped.
  foreignSkipped,

  /// Committed, every step confirmed, nothing skipped, pending or to check.
  completed,

  /// Committed and finished, but mount targets still need a check.
  needsCheck,

  /// Refused because a mount operation was already pending.
  refusedPending,
}

/// What is actually known about a restore. A null list means "not known",
/// which never counts as empty.
class RestoreEvidence {
  final bool refusedForPending;
  final bool writeStarted;

  /// Null when it can't be told whether the rows committed.
  final bool? committed;

  /// Only meaningful when [committed] is false.
  final bool? rollbackVerified;

  /// Another writer changed the data after the commit.
  final bool foreignWrites;

  final List<RestoreStep>? pendingSteps;
  final List<RestoreStep>? skippedSteps;

  /// Targets left locked until checked again.
  final List<RestoreMountProfile>? pendingChecks;

  /// Whether this session can run the remaining steps now.
  final bool canContinue;

  const RestoreEvidence({
    this.refusedForPending = false,
    this.writeStarted = false,
    this.committed,
    this.rollbackVerified,
    this.foreignWrites = false,
    this.pendingSteps,
    this.skippedSteps,
    this.pendingChecks,
    this.canContinue = false,
  });

  /// A committed restore whose every step ran in this session.
  const RestoreEvidence.committed({
    required List<RestoreMountProfile> pendingChecks,
  }) : this(
         writeStarted: true,
         committed: true,
         pendingSteps: const [],
         skippedSteps: const [],
         pendingChecks: pendingChecks,
       );

  RestoreResultKind get kind {
    if (refusedForPending) return RestoreResultKind.refusedPending;
    if (committed == true) {
      if (foreignWrites) return RestoreResultKind.foreignSkipped;
      final pending = pendingSteps;
      final skipped = skippedSteps;
      if (pending == null ||
          skipped == null ||
          pending.isNotEmpty ||
          skipped.isNotEmpty) {
        return RestoreResultKind.committedLocked;
      }
      final checks = pendingChecks;
      if (checks == null || checks.isNotEmpty) {
        return RestoreResultKind.needsCheck;
      }
      return RestoreResultKind.completed;
    }
    if (!writeStarted && committed == false) {
      return RestoreResultKind.notStarted;
    }
    if (committed == false && rollbackVerified == true) {
      return RestoreResultKind.rolledBack;
    }
    return RestoreResultKind.rollbackUnverified;
  }

  /// Whether the result counts as a failure the user must notice at once.
  bool get isMajorFailure =>
      kind == RestoreResultKind.rollbackUnverified ||
      kind == RestoreResultKind.foreignSkipped;
}
