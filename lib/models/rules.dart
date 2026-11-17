import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/rules.freezed.dart';
part 'generated/rules.g.dart';

/// A rule provider as the running Core holds it. [status] is `ok`, `missing`
/// (nothing ever loaded), `failed` (a file is there but nothing loaded from
/// it) or `absent` (the config holds no provider by that name).
@freezed
abstract class RuleSetView with _$RuleSetView {
  const RuleSetView._();

  const factory RuleSetView({
    @Default('') String name,
    @Default('') String behavior,
    @Default(0) int count,
    @JsonKey(name: 'updated-at') DateTime? updatedAt,
    @Default('') String vehicle,
    @Default('ok') String status,
    @Default(0) int interval,
  }) = _RuleSetView;

  /// The Core reports a never-loaded time as Go's zero time.
  DateTime? get loadedAt {
    final value = updatedAt;
    if (value == null || value.year <= 1) return null;
    return value;
  }

  factory RuleSetView.fromJson(Map<String, Object?> json) =>
      _$RuleSetViewFromJson(json);
}

/// One rule of the running config, at [index] in the Core's rule list.
/// [payload] reads as a config writes it; [rulePayload] is mihomo's own
/// rendering, as a request's rule payload carries it, when the two differ.
@freezed
abstract class CoreRule with _$CoreRule {
  const CoreRule._();

  const factory CoreRule({
    @Default(0) int index,
    @Default('') String type,
    @JsonKey(name: 'rule-type') @Default('') String ruleType,
    @Default('') String payload,
    @JsonKey(name: 'rule-payload') @Default('') String rulePayload,
    @Default('') String target,
    @Default(false) bool disabled,
    @Default(false) bool managed,
    @JsonKey(name: 'rule-set') RuleSetView? ruleSet,
  }) = _CoreRule;

  String get text =>
      type == 'MATCH' ? 'MATCH,$target' : '$type,$payload,$target';

  factory CoreRule.fromJson(Map<String, Object?> json) =>
      _$CoreRuleFromJson(json);
}

@freezed
abstract class RuleList with _$RuleList {
  const factory RuleList({
    @JsonKey(name: 'core-epoch') @Default(0) int coreEpoch,
    @Default('') String mode,
    @JsonKey(name: 'managed-prefix') @Default(0) int managedPrefix,
    @Default(0) int total,
    @Default([]) List<CoreRule> rules,
    @Default([]) List<int> filtered,
    @JsonKey(name: 'set-matches') @Default({}) Map<String, int> setMatches,
  }) = _RuleList;

  factory RuleList.fromJson(Map<String, Object?> json) =>
      _$RuleListFromJson(json);
}

@freezed
abstract class RuleSetEntries with _$RuleSetEntries {
  const factory RuleSetEntries({
    @JsonKey(name: 'core-epoch') @Default(0) int coreEpoch,
    @Default('') String name,
    @Default('') String behavior,
    @Default(0) int total,
    @Default(0) int matched,
    @Default(0) int offset,
    @Default([]) List<String> entries,
  }) = _RuleSetEntries;

  factory RuleSetEntries.fromJson(Map<String, Object?> json) =>
      _$RuleSetEntriesFromJson(json);
}

@freezed
abstract class RuleLookupParams with _$RuleLookupParams {
  const factory RuleLookupParams({
    required String host,
    @JsonKey(includeIfNull: false) int? port,
    @JsonKey(includeIfNull: false) String? network,
    @Default(true) bool resolve,
  }) = _RuleLookupParams;

  factory RuleLookupParams.fromJson(Map<String, Object?> json) =>
      _$RuleLookupParamsFromJson(json);
}

@freezed
abstract class ChainHop with _$ChainHop {
  const factory ChainHop({@Default('') String name, @Default('') String type}) =
      _ChainHop;

  factory ChainHop.fromJson(Map<String, Object?> json) =>
      _$ChainHopFromJson(json);
}

enum RuleHitStatus {
  winner,
  shadowed,
  pass,
  @JsonValue('no-adapter')
  noAdapter,
  @JsonValue('no-udp')
  noUdp,
  uncertain,
}

/// A rule a lookup matched, or could not decide. [reason] says what an
/// uncertain rule waits on: process, port, network, inbound, source, dscp,
/// uid, ip or rematch. [entry] is the rule-set entry or sub-rule that matched.
@freezed
abstract class RuleHit with _$RuleHit {
  const RuleHit._();

  const factory RuleHit({
    @Default(0) int index,
    @Default('') String type,
    @JsonKey(name: 'rule-type') @Default('') String ruleType,
    @Default('') String payload,
    @JsonKey(name: 'rule-payload') @Default('') String rulePayload,
    @Default('') String target,
    @Default(false) bool disabled,
    @Default(false) bool managed,
    @JsonKey(name: 'rule-set') RuleSetView? ruleSet,
    @JsonKey(unknownEnumValue: RuleHitStatus.uncertain)
    @Default(RuleHitStatus.uncertain)
    RuleHitStatus status,
    @Default('') String reason,
    @Default('') String detail,
    @Default('') String entry,
  }) = _RuleHit;

  CoreRule get rule => CoreRule(
    index: index,
    type: type,
    ruleType: ruleType,
    payload: payload,
    rulePayload: rulePayload,
    target: target,
    disabled: disabled,
    managed: managed,
    ruleSet: ruleSet,
  );

  factory RuleHit.fromJson(Map<String, Object?> json) =>
      _$RuleHitFromJson(json);
}

/// What the Core's rules make of a host or IP, read without connecting.
/// [winner] is null when no rule decided: the mode did, nothing matched, or
/// a REMATCH ([undetermined]) left it to a dial the lookup does not make.
@freezed
abstract class RuleLookup with _$RuleLookup {
  const factory RuleLookup({
    @JsonKey(name: 'core-epoch') @Default(0) int coreEpoch,
    @Default('') String mode,
    @Default('') String host,
    @Default('') String ip,
    @JsonKey(name: 'ip-source') @Default('') String ipSource,
    @JsonKey(name: 'resolve-error') @Default('') String resolveError,
    @JsonKey(name: 'resolve-wanted') @Default(false) bool resolveWanted,
    @Default(0) int port,
    @Default('') String network,
    @JsonKey(name: 'managed-prefix') @Default(0) int managedPrefix,
    @Default(0) int total,
    RuleHit? winner,
    @Default('') String undetermined,
    @Default([]) List<ChainHop> chain,
    @Default([]) List<RuleHit> matches,
    @Default([]) List<RuleHit> uncertain,
    @JsonKey(name: 'rule-sets') @Default([]) List<RuleSetView> ruleSets,
  }) = _RuleLookup;

  factory RuleLookup.fromJson(Map<String, Object?> json) =>
      _$RuleLookupFromJson(json);
}

enum RuleSourceKind {
  /// From the subscription or profile file itself.
  subscription,

  /// An added rule kept for this profile only.
  addedProfile,

  /// An added rule kept for every profile.
  addedGlobal,

  /// Written by the profile's extension script.
  script,

  /// Inserted by an enabled MITM module.
  mitm,

  /// A rule of a custom profile.
  custom,
}

/// Where one rule of a built config came from; [text] is the line as the
/// build wrote it, [name] the module or script that added it.
@freezed
abstract class RuleSource with _$RuleSource {
  const factory RuleSource({
    required RuleSourceKind kind,
    @Default('') String name,
    @Default('') String text,

    /// The stored rule the line was written from, for one the rules page
    /// may edit: an added rule, or a custom profile's own.
    int? ruleId,
  }) = _RuleSource;
}

/// The sources of the config last applied, bound to the Core epoch that first
/// listed rules agreeing with them.
@freezed
abstract class AppliedRuleSources with _$AppliedRuleSources {
  const factory AppliedRuleSources({
    int? profileId,
    @Default([]) List<RuleSource> sources,
    int? epoch,
  }) = _AppliedRuleSources;
}
