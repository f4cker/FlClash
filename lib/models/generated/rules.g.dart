// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../rules.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RuleSetView _$RuleSetViewFromJson(Map<String, dynamic> json) => _RuleSetView(
  name: json['name'] as String? ?? '',
  behavior: json['behavior'] as String? ?? '',
  count: (json['count'] as num?)?.toInt() ?? 0,
  updatedAt: json['updated-at'] == null
      ? null
      : DateTime.parse(json['updated-at'] as String),
  vehicle: json['vehicle'] as String? ?? '',
  status: json['status'] as String? ?? 'ok',
  interval: (json['interval'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$RuleSetViewToJson(_RuleSetView instance) =>
    <String, dynamic>{
      'name': instance.name,
      'behavior': instance.behavior,
      'count': instance.count,
      'updated-at': instance.updatedAt?.toIso8601String(),
      'vehicle': instance.vehicle,
      'status': instance.status,
      'interval': instance.interval,
    };

_CoreRule _$CoreRuleFromJson(Map<String, dynamic> json) => _CoreRule(
  index: (json['index'] as num?)?.toInt() ?? 0,
  type: json['type'] as String? ?? '',
  ruleType: json['rule-type'] as String? ?? '',
  payload: json['payload'] as String? ?? '',
  rulePayload: json['rule-payload'] as String? ?? '',
  target: json['target'] as String? ?? '',
  disabled: json['disabled'] as bool? ?? false,
  managed: json['managed'] as bool? ?? false,
  ruleSet: json['rule-set'] == null
      ? null
      : RuleSetView.fromJson(json['rule-set'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CoreRuleToJson(_CoreRule instance) => <String, dynamic>{
  'index': instance.index,
  'type': instance.type,
  'rule-type': instance.ruleType,
  'payload': instance.payload,
  'rule-payload': instance.rulePayload,
  'target': instance.target,
  'disabled': instance.disabled,
  'managed': instance.managed,
  'rule-set': instance.ruleSet,
};

_RuleList _$RuleListFromJson(Map<String, dynamic> json) => _RuleList(
  coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
  mode: json['mode'] as String? ?? '',
  managedPrefix: (json['managed-prefix'] as num?)?.toInt() ?? 0,
  total: (json['total'] as num?)?.toInt() ?? 0,
  rules:
      (json['rules'] as List<dynamic>?)
          ?.map((e) => CoreRule.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  filtered:
      (json['filtered'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  setMatches:
      (json['set-matches'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
);

Map<String, dynamic> _$RuleListToJson(_RuleList instance) => <String, dynamic>{
  'core-epoch': instance.coreEpoch,
  'mode': instance.mode,
  'managed-prefix': instance.managedPrefix,
  'total': instance.total,
  'rules': instance.rules,
  'filtered': instance.filtered,
  'set-matches': instance.setMatches,
};

_RuleSetEntries _$RuleSetEntriesFromJson(Map<String, dynamic> json) =>
    _RuleSetEntries(
      coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      behavior: json['behavior'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      matched: (json['matched'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$RuleSetEntriesToJson(_RuleSetEntries instance) =>
    <String, dynamic>{
      'core-epoch': instance.coreEpoch,
      'name': instance.name,
      'behavior': instance.behavior,
      'total': instance.total,
      'matched': instance.matched,
      'offset': instance.offset,
      'entries': instance.entries,
    };

_RuleLookupParams _$RuleLookupParamsFromJson(Map<String, dynamic> json) =>
    _RuleLookupParams(
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt(),
      network: json['network'] as String?,
      resolve: json['resolve'] as bool? ?? true,
    );

Map<String, dynamic> _$RuleLookupParamsToJson(_RuleLookupParams instance) =>
    <String, dynamic>{
      'host': instance.host,
      'port': ?instance.port,
      'network': ?instance.network,
      'resolve': instance.resolve,
    };

_ChainHop _$ChainHopFromJson(Map<String, dynamic> json) => _ChainHop(
  name: json['name'] as String? ?? '',
  type: json['type'] as String? ?? '',
);

Map<String, dynamic> _$ChainHopToJson(_ChainHop instance) => <String, dynamic>{
  'name': instance.name,
  'type': instance.type,
};

_RuleHit _$RuleHitFromJson(Map<String, dynamic> json) => _RuleHit(
  index: (json['index'] as num?)?.toInt() ?? 0,
  type: json['type'] as String? ?? '',
  ruleType: json['rule-type'] as String? ?? '',
  payload: json['payload'] as String? ?? '',
  rulePayload: json['rule-payload'] as String? ?? '',
  target: json['target'] as String? ?? '',
  disabled: json['disabled'] as bool? ?? false,
  managed: json['managed'] as bool? ?? false,
  ruleSet: json['rule-set'] == null
      ? null
      : RuleSetView.fromJson(json['rule-set'] as Map<String, dynamic>),
  status:
      $enumDecodeNullable(
        _$RuleHitStatusEnumMap,
        json['status'],
        unknownValue: RuleHitStatus.uncertain,
      ) ??
      RuleHitStatus.uncertain,
  reason: json['reason'] as String? ?? '',
  detail: json['detail'] as String? ?? '',
  entry: json['entry'] as String? ?? '',
);

Map<String, dynamic> _$RuleHitToJson(_RuleHit instance) => <String, dynamic>{
  'index': instance.index,
  'type': instance.type,
  'rule-type': instance.ruleType,
  'payload': instance.payload,
  'rule-payload': instance.rulePayload,
  'target': instance.target,
  'disabled': instance.disabled,
  'managed': instance.managed,
  'rule-set': instance.ruleSet,
  'status': _$RuleHitStatusEnumMap[instance.status]!,
  'reason': instance.reason,
  'detail': instance.detail,
  'entry': instance.entry,
};

const _$RuleHitStatusEnumMap = {
  RuleHitStatus.winner: 'winner',
  RuleHitStatus.shadowed: 'shadowed',
  RuleHitStatus.pass: 'pass',
  RuleHitStatus.noAdapter: 'no-adapter',
  RuleHitStatus.noUdp: 'no-udp',
  RuleHitStatus.uncertain: 'uncertain',
};

_RuleLookup _$RuleLookupFromJson(Map<String, dynamic> json) => _RuleLookup(
  coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
  mode: json['mode'] as String? ?? '',
  host: json['host'] as String? ?? '',
  ip: json['ip'] as String? ?? '',
  ipSource: json['ip-source'] as String? ?? '',
  resolveError: json['resolve-error'] as String? ?? '',
  resolveWanted: json['resolve-wanted'] as bool? ?? false,
  port: (json['port'] as num?)?.toInt() ?? 0,
  network: json['network'] as String? ?? '',
  managedPrefix: (json['managed-prefix'] as num?)?.toInt() ?? 0,
  total: (json['total'] as num?)?.toInt() ?? 0,
  winner: json['winner'] == null
      ? null
      : RuleHit.fromJson(json['winner'] as Map<String, dynamic>),
  undetermined: json['undetermined'] as String? ?? '',
  chain:
      (json['chain'] as List<dynamic>?)
          ?.map((e) => ChainHop.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  matches:
      (json['matches'] as List<dynamic>?)
          ?.map((e) => RuleHit.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  uncertain:
      (json['uncertain'] as List<dynamic>?)
          ?.map((e) => RuleHit.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  ruleSets:
      (json['rule-sets'] as List<dynamic>?)
          ?.map((e) => RuleSetView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$RuleLookupToJson(_RuleLookup instance) =>
    <String, dynamic>{
      'core-epoch': instance.coreEpoch,
      'mode': instance.mode,
      'host': instance.host,
      'ip': instance.ip,
      'ip-source': instance.ipSource,
      'resolve-error': instance.resolveError,
      'resolve-wanted': instance.resolveWanted,
      'port': instance.port,
      'network': instance.network,
      'managed-prefix': instance.managedPrefix,
      'total': instance.total,
      'winner': instance.winner,
      'undetermined': instance.undetermined,
      'chain': instance.chain,
      'matches': instance.matches,
      'uncertain': instance.uncertain,
      'rule-sets': instance.ruleSets,
    };
