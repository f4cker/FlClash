// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../mount.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MountSource _$MountSourceFromJson(Map<String, dynamic> json) => _MountSource(
  id: (json['id'] as num).toInt(),
  label: json['label'] as String,
  path: json['path'] as String,
);

Map<String, dynamic> _$MountSourceToJson(_MountSource instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'path': instance.path,
    };

_MountSetup _$MountSetupFromJson(Map<String, dynamic> json) => _MountSetup(
  target: (json['target'] as num).toInt(),
  revision: json['revision'] as String,
  sources:
      (json['sources'] as List<dynamic>?)
          ?.map((e) => MountSource.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  groups:
      (json['groups'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$MountSetupToJson(_MountSetup instance) =>
    <String, dynamic>{
      'target': instance.target,
      'revision': instance.revision,
      'sources': instance.sources,
      'groups': instance.groups,
    };

_MountOperation _$MountOperationFromJson(Map<String, dynamic> json) =>
    _MountOperation(
      kind: $enumDecode(_$MountOperationKindEnumMap, json['kind']),
      version: (json['version'] as num).toInt(),
      sourceIds:
          (json['sourceIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$MountOperationToJson(_MountOperation instance) =>
    <String, dynamic>{
      'kind': _$MountOperationKindEnumMap[instance.kind]!,
      'version': instance.version,
      'sourceIds': instance.sourceIds,
    };

const _$MountOperationKindEnumMap = {
  MountOperationKind.save: 'save',
  MountOperationKind.deleteSource: 'deleteSource',
  MountOperationKind.unknown: 'unknown',
};

_MountSourceInspection _$MountSourceInspectionFromJson(
  Map<String, dynamic> json,
) => _MountSourceInspection(
  status: $enumDecode(_$MountSourceStatusEnumMap, json['status']),
  count: (json['count'] as num?)?.toInt() ?? 0,
  listed: (json['listed'] as num?)?.toInt() ?? 0,
  tailscaleExcluded: (json['tailscale-excluded'] as num?)?.toInt() ?? 0,
  relayExcluded: (json['relay-excluded'] as num?)?.toInt() ?? 0,
  unsupportedExcluded: (json['unsupported-excluded'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MountSourceInspectionToJson(
  _MountSourceInspection instance,
) => <String, dynamic>{
  'status': _$MountSourceStatusEnumMap[instance.status]!,
  'count': instance.count,
  'listed': instance.listed,
  'tailscale-excluded': instance.tailscaleExcluded,
  'relay-excluded': instance.relayExcluded,
  'unsupported-excluded': instance.unsupportedExcluded,
};

const _$MountSourceStatusEnumMap = {
  MountSourceStatus.nodes: 'nodes',
  MountSourceStatus.unsupported: 'unsupported',
  MountSourceStatus.invalid: 'invalid',
  MountSourceStatus.missing: 'missing',
  MountSourceStatus.readError: 'read-error',
};

_MountGroupInfo _$MountGroupInfoFromJson(
  Map<String, dynamic> json,
) => _MountGroupInfo(
  name: json['name'] as String,
  type: json['type'] as String,
  kind: $enumDecode(_$MountGroupKindEnumMap, json['kind']),
  excluded: $enumDecodeNullable(_$MountGroupExclusionEnumMap, json['excluded']),
  reason: $enumDecodeNullable(
    _$MountGroupReasonEnumMap,
    json['reason'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  collects: $enumDecodeNullable(_$MountGroupCollectsEnumMap, json['collects']),
  hidden: json['hidden'] as bool? ?? false,
  filter: json['filter'] as bool? ?? false,
  excludeFilter: json['exclude-filter'] as bool? ?? false,
  excludeType: json['exclude-type'] as bool? ?? false,
  uses: json['uses'] as bool? ?? false,
  probe:
      $enumDecodeNullable(_$MountGroupProbeEnumMap, json['probe']) ??
      MountGroupProbe.none,
  emptyFallback: json['empty-fallback'] as String?,
);

Map<String, dynamic> _$MountGroupInfoToJson(_MountGroupInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'kind': _$MountGroupKindEnumMap[instance.kind]!,
      'excluded': _$MountGroupExclusionEnumMap[instance.excluded],
      'reason': _$MountGroupReasonEnumMap[instance.reason],
      'collects': _$MountGroupCollectsEnumMap[instance.collects],
      'hidden': instance.hidden,
      'filter': instance.filter,
      'exclude-filter': instance.excludeFilter,
      'exclude-type': instance.excludeType,
      'uses': instance.uses,
      'probe': _$MountGroupProbeEnumMap[instance.probe]!,
      'empty-fallback': instance.emptyFallback,
    };

const _$MountGroupKindEnumMap = {
  MountGroupKind.auto: 'auto',
  MountGroupKind.candidate: 'candidate',
  MountGroupKind.excluded: 'excluded',
};

const _$MountGroupExclusionEnumMap = {
  MountGroupExclusion.builtin: 'builtin',
  MountGroupExclusion.hidden: 'hidden',
  MountGroupExclusion.type: 'type',
  MountGroupExclusion.tailscale: 'tailscale',
};

const _$MountGroupReasonEnumMap = {
  MountGroupReason.holds: 'holds',
  MountGroupReason.providerUnknown: 'provider-unknown',
  MountGroupReason.rule: 'rule',
  MountGroupReason.ruleUnknown: 'rule-unknown',
  MountGroupReason.member: 'member',
  MountGroupReason.carrier: 'carrier',
  MountGroupReason.global: 'global',
  MountGroupReason.dns: 'dns',
  MountGroupReason.dialer: 'dialer',
};

const _$MountGroupCollectsEnumMap = {
  MountGroupCollects.all: 'all',
  MountGroupCollects.providers: 'providers',
};

const _$MountGroupProbeEnumMap = {
  MountGroupProbe.none: 'none',
  MountGroupProbe.probes: 'probes',
  MountGroupProbe.unknown: 'unknown',
};

_MountTarget _$MountTargetFromJson(Map<String, dynamic> json) => _MountTarget(
  groups:
      (json['groups'] as List<dynamic>?)
          ?.map((e) => MountGroupInfo.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  relay:
      (json['relay'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$MountTargetToJson(_MountTarget instance) =>
    <String, dynamic>{'groups': instance.groups, 'relay': instance.relay};

_MountNode _$MountNodeFromJson(Map<String, dynamic> json) => _MountNode(
  name: json['name'] as String,
  original: json['original'] as String,
);

Map<String, dynamic> _$MountNodeToJson(_MountNode instance) =>
    <String, dynamic>{'name': instance.name, 'original': instance.original};

_MountSourceReport _$MountSourceReportFromJson(Map<String, dynamic> json) =>
    _MountSourceReport(
      id: (json['id'] as num).toInt(),
      provider: json['provider'] as String,
      status: $enumDecode(_$MountSourceStatusEnumMap, json['status']),
      tailscaleExcluded: (json['tailscale-excluded'] as num?)?.toInt() ?? 0,
      relayExcluded: (json['relay-excluded'] as num?)?.toInt() ?? 0,
      unsupportedExcluded: (json['unsupported-excluded'] as num?)?.toInt() ?? 0,
      nodes:
          (json['nodes'] as List<dynamic>?)
              ?.map((e) => MountNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$MountSourceReportToJson(_MountSourceReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'provider': instance.provider,
      'status': _$MountSourceStatusEnumMap[instance.status]!,
      'tailscale-excluded': instance.tailscaleExcluded,
      'relay-excluded': instance.relayExcluded,
      'unsupported-excluded': instance.unsupportedExcluded,
      'nodes': instance.nodes,
    };

_MountGroupReport _$MountGroupReportFromJson(Map<String, dynamic> json) =>
    _MountGroupReport(
      name: json['name'] as String,
      via: $enumDecode(_$MountGroupViaEnumMap, json['via']),
      protection: $enumDecode(_$MountProtectionEnumMap, json['protection']),
      emptyFallback: json['empty-fallback'] as String? ?? '',
    );

Map<String, dynamic> _$MountGroupReportToJson(_MountGroupReport instance) =>
    <String, dynamic>{
      'name': instance.name,
      'via': _$MountGroupViaEnumMap[instance.via]!,
      'protection': _$MountProtectionEnumMap[instance.protection]!,
      'empty-fallback': instance.emptyFallback,
    };

const _$MountGroupViaEnumMap = {
  MountGroupVia.auto: 'auto',
  MountGroupVia.use: 'use',
};

const _$MountProtectionEnumMap = {
  MountProtection.reject: 'reject',
  MountProtection.base: 'base',
  MountProtection.original: 'original',
};

_MountReport _$MountReportFromJson(Map<String, dynamic> json) => _MountReport(
  target: (json['target'] as num?)?.toInt() ?? 0,
  revision: json['revision'] as String? ?? '',
  sources:
      (json['sources'] as List<dynamic>?)
          ?.map((e) => MountSourceReport.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  groups:
      (json['groups'] as List<dynamic>?)
          ?.map((e) => MountGroupReport.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  renamed: (json['renamed'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MountReportToJson(_MountReport instance) =>
    <String, dynamic>{
      'target': instance.target,
      'revision': instance.revision,
      'sources': instance.sources,
      'groups': instance.groups,
      'renamed': instance.renamed,
    };

_MountPreflight _$MountPreflightFromJson(Map<String, dynamic> json) =>
    _MountPreflight(
      error: json['error'] as String?,
      errorCode: json['error-code'] as String?,
      report: json['report'] == null
          ? null
          : MountReport.fromJson(json['report'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MountPreflightToJson(_MountPreflight instance) =>
    <String, dynamic>{
      'error': instance.error,
      'error-code': instance.errorCode,
      'report': instance.report,
    };

_MountRuntimeSource _$MountRuntimeSourceFromJson(Map<String, dynamic> json) =>
    _MountRuntimeSource(
      id: (json['id'] as num).toInt(),
      provider: json['provider'] as String,
      present: json['present'] as bool? ?? false,
      count: (json['count'] as num?)?.toInt() ?? 0,
      matches: json['matches'] as bool? ?? false,
    );

Map<String, dynamic> _$MountRuntimeSourceToJson(_MountRuntimeSource instance) =>
    <String, dynamic>{
      'id': instance.id,
      'provider': instance.provider,
      'present': instance.present,
      'count': instance.count,
      'matches': instance.matches,
    };

_MountRuntimeGroup _$MountRuntimeGroupFromJson(Map<String, dynamic> json) =>
    _MountRuntimeGroup(
      name: json['name'] as String,
      present: json['present'] as bool? ?? false,
      members: (json['members'] as num?)?.toInt() ?? 0,
      mounted: (json['mounted'] as num?)?.toInt() ?? 0,
      empty: json['empty'] as bool? ?? false,
      fallback: json['fallback'] as String?,
    );

Map<String, dynamic> _$MountRuntimeGroupToJson(_MountRuntimeGroup instance) =>
    <String, dynamic>{
      'name': instance.name,
      'present': instance.present,
      'members': instance.members,
      'mounted': instance.mounted,
      'empty': instance.empty,
      'fallback': instance.fallback,
    };

_MountRuntimeState _$MountRuntimeStateFromJson(
  Map<String, dynamic> json,
) => _MountRuntimeState(
  blocked: json['blocked'] as bool? ?? false,
  refused:
      (json['refused'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  report: json['report'] == null
      ? null
      : MountReport.fromJson(json['report'] as Map<String, dynamic>),
  sources:
      (json['sources'] as List<dynamic>?)
          ?.map((e) => MountRuntimeSource.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  groups:
      (json['groups'] as List<dynamic>?)
          ?.map((e) => MountRuntimeGroup.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  moved:
      (json['moved'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  lost:
      (json['lost'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$MountRuntimeStateToJson(_MountRuntimeState instance) =>
    <String, dynamic>{
      'blocked': instance.blocked,
      'refused': instance.refused,
      'report': instance.report,
      'sources': instance.sources,
      'groups': instance.groups,
      'moved': instance.moved,
      'lost': instance.lost,
    };
