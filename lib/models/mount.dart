import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
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
  }) = _MountSource;

  factory MountSource.fromJson(Map<String, Object?> json) =>
      _$MountSourceFromJson(json);
}

/// What `SetupParams.mounts` carries; [revision] binds a readback to it.
@freezed
abstract class MountSetup with _$MountSetup {
  const factory MountSetup({
    required String revision,
    @Default([]) List<MountSource> sources,
    @Default([]) List<String> groups,
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
    'groups': target.groups,
    'sources': [
      for (final source in sources)
        [
          source.id,
          source.realLabel,
          source.lastUpdateDate?.millisecondsSinceEpoch,
        ],
    ],
  });
  return MountSetup(
    revision: revision.toMd5(),
    sources: [
      for (final source in sources)
        MountSource(
          id: source.id,
          label: source.realLabel,
          path: join(profilesPath, '${source.id}.yaml'),
        ),
    ],
    groups: target.groups,
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

@freezed
abstract class MountTargetState with _$MountTargetState {
  const factory MountTargetState({
    required int targetId,
    @Default([]) List<int> sourceIds,
    @Default([]) List<String> groups,
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
  }) = _MountSourceInspection;

  factory MountSourceInspection.fromJson(Map<String, Object?> json) =>
      _$MountSourceInspectionFromJson(json);
}

enum MountGroupKind { auto, candidate, excluded }

enum MountGroupExclusion { builtin, hidden, type, tailscale }

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
  const factory MountTarget({@Default([]) List<MountGroupInfo> groups}) =
      _MountTarget;

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
    @Default([]) List<MountNode> nodes,
  }) = _MountSourceReport;

  factory MountSourceReport.fromJson(Map<String, Object?> json) =>
      _$MountSourceReportFromJson(json);
}

/// [reject] is the block-when-empty Flash set; [base] is the base profile's
/// own empty-fallback, kept as written.
enum MountProtection { reject, base }

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

@freezed
abstract class MountRuntimeState with _$MountRuntimeState {
  const factory MountRuntimeState({
    @Default(false) bool blocked,
    MountReport? report,
    @Default([]) List<MountRuntimeSource> sources,
    @Default([]) List<MountRuntimeGroup> groups,
  }) = _MountRuntimeState;

  factory MountRuntimeState.fromJson(Map<String, Object?> json) =>
      _$MountRuntimeStateFromJson(json);
}
