import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart';

import 'profile.dart';

part 'generated/mount.freezed.dart';
part 'generated/mount.g.dart';

/// The prefix of the provider a mount becomes; `core/mount.go` names it.
const mountProviderPrefix = 'flash-mount-';

String mountProviderName(int sourceId) => '$mountProviderPrefix$sourceId';

@freezed
abstract class MountSource with _$MountSource {
  const factory MountSource({
    required int id,
    required String label,
    required String path,
    @JsonKey(name: 'age-secret-key', includeIfNull: false) String? ageSecretKey,
  }) = _MountSource;

  factory MountSource.fromJson(Map<String, Object?> json) =>
      _$MountSourceFromJson(json);
}

/// What `SetupParams.mounts` carries; [revision] binds a readback to it and
/// [target] the selections the Core follows across applies. No group is
/// named: every group the Core's checks allow takes the mounts.
@freezed
abstract class MountSetup with _$MountSetup {
  const factory MountSetup({
    required int target,
    required String revision,
    @Default([]) List<MountSource> sources,
  }) = _MountSetup;

  factory MountSetup.fromJson(Map<String, Object?> json) =>
      _$MountSetupFromJson(json);
}

/// What [target] makes the Core mount. The revision changes with the
/// relation and with any source update or rename, which recomputes suffixes.
MountSetup mountSetupOf(
  MountTargetState target,
  List<Profile> profiles,
  String profilesPath,
) {
  final sources = [
    for (final id in target.sourceIds)
      if (profiles.getProfile(id) case final profile?
          when profile.type == ProfileType.url)
        profile,
  ];
  final revision = json.encode({
    'target': target.targetId,
    'version': target.version,
    'sources': [
      for (final source in sources)
        [
          source.id,
          source.realLabel,
          source.lastUpdateDate?.millisecondsSinceEpoch,
          if (source.ageSecretKey.isNotEmpty) source.ageSecretKey.toMd5(),
        ],
    ],
  });
  return MountSetup(
    target: target.targetId,
    revision: revision.toMd5(),
    sources: [
      for (final source in sources)
        MountSource(
          id: source.id,
          label: source.realLabel,
          path: join(profilesPath, '${source.id}.yaml'),
          ageSecretKey: source.ageSecretKey.isEmpty
              ? null
              : source.ageSecretKey,
        ),
    ],
  );
}

/// A save or a source removal whose application is not yet proven.
@freezed
abstract class MountOperation with _$MountOperation {
  const factory MountOperation({
    required MountOperationKind kind,
    required int version,
    @Default([]) List<int> sourceIds,
  }) = _MountOperation;

  factory MountOperation.fromJson(Map<String, Object?> json) =>
      _$MountOperationFromJson(json);
}

/// Groups a target once chose by hand are not read: the relation, its
/// version and any pending record are all a target keeps.
@freezed
abstract class MountTargetState with _$MountTargetState {
  const factory MountTargetState({
    required int targetId,
    @Default([]) List<int> sourceIds,
    required int version,
    MountOperation? pending,
  }) = _MountTargetState;
}

@freezed
abstract class MountSourceRecord with _$MountSourceRecord {
  const factory MountSourceRecord({
    required int sourceId,
    MountSourceFailure? failure,
    DateTime? failedAt,
    DateTime? succeededAt,
  }) = _MountSourceRecord;
}

class MountVersionConflict implements Exception {
  const MountVersionConflict();
}

/// A save or removal whose outcome is unknown locks the target until a
/// readback resolves it.
class MountOperationUnresolved implements Exception {
  const MountOperationUnresolved();
}

enum MountSourceStatus {
  nodes,
  unsupported,
  invalid,
  missing,
  @JsonValue('read-error')
  readError,
}

@freezed
abstract class MountSourceInspection with _$MountSourceInspection {
  const factory MountSourceInspection({
    required MountSourceStatus status,
    @Default(0) int count,
    @Default(0) int listed,
    @Default(0) @JsonKey(name: 'tailscale-excluded') int tailscaleExcluded,
    @Default(0) @JsonKey(name: 'relay-excluded') int relayExcluded,
    @Default(0) @JsonKey(name: 'unsupported-excluded') int unsupportedExcluded,
  }) = _MountSourceInspection;

  factory MountSourceInspection.fromJson(Map<String, Object?> json) =>
      _$MountSourceInspectionFromJson(json);
}

/// [auto] takes the mounts through its own filters; [excluded] is kept out;
/// [fixed] only lists its members, so takes no new node and is never shown.
enum MountGroupKind { auto, excluded, fixed }

enum MountGroupExclusion { builtin, type, tailscale }

enum MountGroupReason {
  holds,
  @JsonValue('provider-unknown')
  providerUnknown,
  rule,
  @JsonValue('rule-unknown')
  ruleUnknown,
  member,

  /// A Tailscale node, or a proxy Tailscale traffic takes, dials through it.
  carrier,

  /// Tailscale traffic is sent to GLOBAL, which may select any group.
  global,

  /// DNS lookups, tailnet names among them, go out through it.
  dns,

  /// Another proxy dials through it (dialer-proxy) and may keep a session
  /// there that later carries Tailscale traffic unchecked.
  dialer,
}

/// Why a group is kept out of mounts, as a user is told.
enum MountGroupIsolation { traffic, dialer, unknown }

extension MountGroupReasonIsolation on MountGroupReason {
  MountGroupIsolation get isolation => switch (this) {
    MountGroupReason.dialer => MountGroupIsolation.dialer,
    MountGroupReason.providerUnknown ||
    MountGroupReason.ruleUnknown => MountGroupIsolation.unknown,
    _ => MountGroupIsolation.traffic,
  };
}

/// Each group kept out to isolate Tailscale once; none when unread.
List<MountGroupInfo> mountIsolatedGroups(MountTarget? target) {
  final seen = <String>{};
  return [
    for (final group in target?.groups ?? const <MountGroupInfo>[])
      if (group.kind == MountGroupKind.excluded &&
          group.excluded == MountGroupExclusion.tailscale &&
          seen.add(group.name))
        group,
  ];
}

Map<MountGroupIsolation, int> mountIsolationCounts(
  List<MountGroupInfo> groups,
) {
  final counts = {for (final kind in MountGroupIsolation.values) kind: 0};
  for (final group in groups) {
    final kind = group.reason?.isolation ?? MountGroupIsolation.unknown;
    counts[kind] = counts[kind]! + 1;
  }
  return counts;
}

/// [all] collects base proxies and providers, [providers] providers only.
enum MountGroupCollects { all, providers }

/// [unknown] is a probing type whose checks the base turned off.
enum MountGroupProbe { none, probes, unknown }

@freezed
abstract class MountGroupInfo with _$MountGroupInfo {
  const factory MountGroupInfo({
    required String name,
    required String type,
    required MountGroupKind kind,
    MountGroupExclusion? excluded,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    MountGroupReason? reason,
    MountGroupCollects? collects,
    @Default(false) bool hidden,
    @Default(false) bool filter,
    @Default(false) @JsonKey(name: 'exclude-filter') bool excludeFilter,
    @Default(false) @JsonKey(name: 'exclude-type') bool excludeType,
    @Default(false) bool uses,
    @Default(MountGroupProbe.none) MountGroupProbe probe,
    @JsonKey(name: 'empty-fallback') String? emptyFallback,
  }) = _MountGroupInfo;

  factory MountGroupInfo.fromJson(Map<String, Object?> json) =>
      _$MountGroupInfoFromJson(json);
}

@freezed
abstract class MountTarget with _$MountTarget {
  const factory MountTarget({
    @Default([]) List<MountGroupInfo> groups,
    @Default([]) List<String> relay,
  }) = _MountTarget;

  factory MountTarget.fromJson(Map<String, Object?> json) =>
      _$MountTargetFromJson(json);
}

@freezed
abstract class MountNode with _$MountNode {
  const factory MountNode({required String name, required String original}) =
      _MountNode;

  factory MountNode.fromJson(Map<String, Object?> json) =>
      _$MountNodeFromJson(json);
}

@freezed
abstract class MountSourceReport with _$MountSourceReport {
  const factory MountSourceReport({
    required int id,
    required String provider,
    required MountSourceStatus status,
    @Default(0) @JsonKey(name: 'tailscale-excluded') int tailscaleExcluded,
    @Default(0) @JsonKey(name: 'relay-excluded') int relayExcluded,
    @Default(0) @JsonKey(name: 'unsupported-excluded') int unsupportedExcluded,
    @Default([]) List<MountNode> nodes,
  }) = _MountSourceReport;

  factory MountSourceReport.fromJson(Map<String, Object?> json) =>
      _$MountSourceReportFromJson(json);
}

/// [reject] is the block-when-empty Flash set; [base] is the base profile's
/// own empty-fallback, kept as written; [original] is a group that also
/// holds base proxies and keeps mihomo's default.
enum MountProtection { reject, base, original }

enum MountGroupVia { auto, use }

@freezed
abstract class MountGroupReport with _$MountGroupReport {
  const factory MountGroupReport({
    required String name,
    required MountGroupVia via,
    required MountProtection protection,
    @JsonKey(name: 'empty-fallback') @Default('') String emptyFallback,
  }) = _MountGroupReport;

  factory MountGroupReport.fromJson(Map<String, Object?> json) =>
      _$MountGroupReportFromJson(json);
}

@freezed
abstract class MountReport with _$MountReport {
  const factory MountReport({
    @Default(0) int target,
    @Default('') String revision,
    @Default([]) List<MountSourceReport> sources,
    @Default([]) List<MountGroupReport> groups,
    @Default(0) int renamed,
  }) = _MountReport;

  factory MountReport.fromJson(Map<String, Object?> json) =>
      _$MountReportFromJson(json);
}

@freezed
abstract class MountPreflight with _$MountPreflight {
  const factory MountPreflight({
    String? error,
    @JsonKey(name: 'error-code') String? errorCode,
    MountReport? report,
  }) = _MountPreflight;

  factory MountPreflight.fromJson(Map<String, Object?> json) =>
      _$MountPreflightFromJson(json);
}

@freezed
abstract class MountRuntimeSource with _$MountRuntimeSource {
  const factory MountRuntimeSource({
    required int id,
    required String provider,
    @Default(false) bool present,
    @Default(0) int count,
    @Default(false) bool matches,
  }) = _MountRuntimeSource;

  factory MountRuntimeSource.fromJson(Map<String, Object?> json) =>
      _$MountRuntimeSourceFromJson(json);
}

@freezed
abstract class MountRuntimeGroup with _$MountRuntimeGroup {
  const factory MountRuntimeGroup({
    required String name,
    @Default(false) bool present,
    @Default(0) int members,
    @Default(0) int mounted,
    @Default(false) bool empty,
    String? fallback,
  }) = _MountRuntimeGroup;

  factory MountRuntimeGroup.fromJson(Map<String, Object?> json) =>
      _$MountRuntimeGroupFromJson(json);
}

/// [moved] and [lost] are the selections the last apply followed to a new
/// name or dropped, by group.
@freezed
abstract class MountRuntimeState with _$MountRuntimeState {
  const factory MountRuntimeState({
    @Default(0) int generation,
    @Default(false) bool blocked,
    @Default([]) List<String> refused,
    MountReport? report,
    @Default([]) List<MountRuntimeSource> sources,
    @Default([]) List<MountRuntimeGroup> groups,
    @Default({}) Map<String, String> moved,
    @Default([]) List<String> lost,
  }) = _MountRuntimeState;

  factory MountRuntimeState.fromJson(Map<String, Object?> json) =>
      _$MountRuntimeStateFromJson(json);
}

enum MountRefreshOutcome { applied, requiresApply, superseded, kept, unknown }

class MountRefreshResult {
  const MountRefreshResult({
    required this.outcome,
    required this.state,
    this.error,
  });

  final MountRefreshOutcome outcome;
  final MountRuntimeState state;
  final String? error;

  factory MountRefreshResult.fromJson(Map<String, Object?> json) =>
      MountRefreshResult(
        outcome: MountRefreshOutcome.values.firstWhere(
          (value) => value.name == json['outcome'],
          orElse: () => MountRefreshOutcome.unknown,
        ),
        state: MountRuntimeState.fromJson(
          (json['state'] as Map).cast<String, Object?>(),
        ),
        error: json['error'] as String?,
      );
}

/// [isolatedOnly]: only nodes kept out to isolate Tailscale, for mixed reasons.
enum MountSourceState {
  pending,
  nodes,
  empty,
  tailscaleOnly,
  relayOnly,
  isolatedOnly,
  notFetched,
  unsupported,
  unreadable;

  bool get mountable => switch (this) {
    nodes || empty => true,
    _ => false,
  };

  /// A source read and left with a list to mount, even an empty one.
  bool get fetched => this == nodes || this == empty;
}

@freezed
abstract class MountSourceItem with _$MountSourceItem {
  const factory MountSourceItem({
    required Profile profile,
    required MountSourceState state,
    @Default(0) int count,
    @Default(0) int tailscaleExcluded,
    @Default(0) int relayExcluded,
    @Default(0) int unsupportedExcluded,
    @Default(false) bool mounted,
    MountSourceRecord? record,
  }) = _MountSourceItem;
}

/// [groups] is null when they could not be read, which is not the same as a
/// profile without groups. [revision] is what the stored relation applies
/// as, to tell a readback of it from one of an earlier relation.
@freezed
abstract class MountPanel with _$MountPanel {
  const factory MountPanel({
    required Profile target,
    MountTargetState? stored,
    @Default([]) List<MountSourceItem> sources,
    MountTarget? groups,
    @Default(false) bool groupsPending,
    String? revision,
  }) = _MountPanel;
}

/// [appliedUnverified]: the Core runs this revision but its nodes or groups
/// differ from the report; [saved]: stored, no readback possible;
/// [needsGroup]: no group of the target may take the mounts.
enum MountSaveOutcome {
  applied,
  appliedUnverified,
  saved,
  unchanged,
  needsGroup,
  locked,
  applyFailedKept,
  applyFailedBlocked,
  applyFailed,
  unknown,
}

@freezed
abstract class MountSaveResult with _$MountSaveResult {
  const factory MountSaveResult({
    required MountSaveOutcome outcome,
    String? message,
    MountTargetState? state,
    @Default([]) List<String> lostSelections,
  }) = _MountSaveResult;
}

@freezed
abstract class MountSourceRefresh with _$MountSourceRefresh {
  const factory MountSourceRefresh({
    required bool updated,
    MountSourceItem? item,
    String? message,
    MountSaveOutcome? application,
    @Default([]) List<String> lostSelections,
  }) = _MountSourceRefresh;
}

enum MountSourceDeletion { deleted, blocked, unchanged, keptProfile, unknown }

@freezed
abstract class MountCardSummary with _$MountCardSummary {
  const factory MountCardSummary({required int mounted, required int failed}) =
      _MountCardSummary;
}

/// Null for a target that mounts nothing. A failure counts only while no
/// later update of that source succeeded.
MountCardSummary? mountCardSummaryOf(
  MountTargetState? target,
  Map<int, MountSourceRecord> records,
) {
  if (target == null || target.sourceIds.isEmpty) {
    return null;
  }
  return MountCardSummary(
    mounted: target.sourceIds.length,
    failed: target.sourceIds.where((id) => records[id]?.failure != null).length,
  );
}

/// What [state] proves about the apply of [revision]; null when the Core
/// runs another revision.
MountSaveOutcome? confirmMounts(MountRuntimeState state, String revision) {
  if (state.blocked) {
    return MountSaveOutcome.applyFailedBlocked;
  }
  final report = state.report;
  if (report == null || report.revision != revision) {
    return null;
  }
  final sources = {for (final source in state.sources) source.id: source};
  final groups = {for (final group in state.groups) group.name: group};
  final consistent =
      report.sources.every(
        (source) =>
            source.status != MountSourceStatus.nodes ||
            (sources[source.id]?.matches ?? false),
      ) &&
      report.groups.every((group) => groups[group.name]?.present ?? false);
  return consistent
      ? MountSaveOutcome.applied
      : MountSaveOutcome.appliedUnverified;
}

typedef MountSkip = ({int sourceId, MountSourceStatus status});

/// The sources the Core left out of [report] as their copies were unreadable.
List<MountSkip> mountSkipsOf(MountReport report) => [
  for (final source in report.sources)
    if (source.status != MountSourceStatus.nodes)
      (sourceId: source.id, status: source.status),
];

MountSourceItem mountSourceItem(
  Profile profile,
  MountSourceInspection? inspection, {
  bool mounted = false,
  MountSourceRecord? record,
}) {
  final state = switch (inspection?.status) {
    null || MountSourceStatus.readError => MountSourceState.unreadable,
    MountSourceStatus.missing => MountSourceState.notFetched,
    MountSourceStatus.unsupported ||
    MountSourceStatus.invalid => MountSourceState.unsupported,
    MountSourceStatus.nodes when inspection!.count > 0 =>
      MountSourceState.nodes,
    MountSourceStatus.nodes => switch ((
      inspection!.tailscaleExcluded > 0,
      inspection.relayExcluded > 0,
      inspection.unsupportedExcluded > 0,
    )) {
      (false, false, false) => MountSourceState.empty,
      (true, false, false) => MountSourceState.tailscaleOnly,
      (false, true, false) => MountSourceState.relayOnly,
      _ => MountSourceState.isolatedOnly,
    },
  };
  return MountSourceItem(
    profile: profile,
    state: state,
    count: inspection?.count ?? 0,
    tailscaleExcluded: inspection?.tailscaleExcluded ?? 0,
    relayExcluded: inspection?.relayExcluded ?? 0,
    unsupportedExcluded: inspection?.unsupportedExcluded ?? 0,
    mounted: mounted,
    record: record,
  );
}

/// Viewer-only notes; names only from the readback of the revision the Core
/// runs, as a source read since is not what runs until applied.
String annotateMountProviders(
  String yaml,
  MountSetup mounts,
  MountRuntimeState? runtime,
  AppLocalizations appLocalizations,
) {
  final report = runtime?.report;
  final running =
      runtime != null &&
      !runtime.blocked &&
      report != null &&
      report.target == mounts.target &&
      report.revision == mounts.revision;
  final loaded = <String, List<String>>{
    if (running)
      for (final source in report.sources)
        if (runtime.sources.any(
          (it) => it.provider == source.provider && it.present && it.matches,
        ))
          source.provider: [for (final node in source.nodes) node.name],
  };
  final labels = {
    for (final source in mounts.sources)
      mountProviderName(source.id): source.label,
  };
  final key = RegExp(r'^( +)(' + mountProviderPrefix + r'\d+):\s*$');
  final section = RegExp(r'^([^\s#][^:]*):');
  List<String> notes(String indent, String provider) {
    final name = _commentSafe(labels[provider]!);
    return switch (loaded[provider]) {
      final nodes? => [
        '$indent# ${appLocalizations.mountViewerSource(name, nodes.length)}',
        for (final node in nodes) '$indent#   - ${_commentSafe(node)}',
      ],
      null => ['$indent# ${appLocalizations.mountViewerPending(name)}'],
    };
  }

  final lines = yaml.split('\n');
  final block = <String>{};
  var providers = false;
  for (final line in lines) {
    if (section.firstMatch(line) case final match?) {
      providers = match.group(1) == 'proxy-providers';
    } else if (key.firstMatch(line) case final match? when providers) {
      block.add(match.group(2)!);
    }
  }
  final out = <String>[];
  providers = false;
  for (final line in lines) {
    if (section.firstMatch(line) case final match?) {
      providers = match.group(1) == 'proxy-providers';
      // A flow mapping has no line per provider: its notes lead the section.
      if (providers) {
        for (final provider in labels.keys) {
          if (!block.contains(provider)) {
            out.addAll(notes('', provider));
          }
        }
      }
    } else if (key.firstMatch(line) case final match? when providers) {
      if (labels.containsKey(match.group(2))) {
        out.addAll(notes(match.group(1)!, match.group(2)!));
      }
    }
    out.add(line);
  }
  return out.join('\n');
}

String _commentSafe(String text) => text.replaceAll(RegExp(r'[\r\n]+'), ' ');

class MountSourceInUse implements Exception {
  const MountSourceInUse();
}
