import 'package:fl_clash/enum/enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/tailscale.freezed.dart';
part 'generated/tailscale.g.dart';

const tailscaleLegacySharedStateWarning = 'legacy-shared-state-present';
const tailscaleStateDirInUseWarning = 'state-dir-in-use';

@freezed
abstract class TailscaleError with _$TailscaleError {
  const factory TailscaleError({
    @Default('') String code,
    @Default('') String message,
  }) = _TailscaleError;

  factory TailscaleError.fromJson(Map<String, Object?> json) =>
      _$TailscaleErrorFromJson(json);
}

@freezed
abstract class TailscaleExitNodeSetting with _$TailscaleExitNodeSetting {
  const factory TailscaleExitNodeSetting({
    @Default('') String value,
    @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault)
    @Default(TailscaleSettingSource.coreDefault)
    TailscaleSettingSource source,
  }) = _TailscaleExitNodeSetting;

  factory TailscaleExitNodeSetting.fromJson(Map<String, Object?> json) =>
      _$TailscaleExitNodeSettingFromJson(json);
}

@freezed
abstract class TailscaleAcceptRoutesSetting
    with _$TailscaleAcceptRoutesSetting {
  const factory TailscaleAcceptRoutesSetting({
    @Default(false) bool value,
    @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault)
    @Default(TailscaleSettingSource.coreDefault)
    TailscaleSettingSource source,
  }) = _TailscaleAcceptRoutesSetting;

  factory TailscaleAcceptRoutesSetting.fromJson(Map<String, Object?> json) =>
      _$TailscaleAcceptRoutesSettingFromJson(json);
}

@freezed
abstract class TailscaleSettings with _$TailscaleSettings {
  const factory TailscaleSettings({
    @JsonKey(name: 'exit-node')
    @Default(TailscaleExitNodeSetting())
    TailscaleExitNodeSetting exitNode,
    @JsonKey(name: 'accept-routes')
    @Default(TailscaleAcceptRoutesSetting())
    TailscaleAcceptRoutesSetting acceptRoutes,
  }) = _TailscaleSettings;

  factory TailscaleSettings.fromJson(Map<String, Object?> json) =>
      _$TailscaleSettingsFromJson(json);
}

@freezed
abstract class TailscaleNode with _$TailscaleNode {
  const TailscaleNode._();

  const factory TailscaleNode({
    @JsonKey(name: 'profile-id') @Default(0) int profileId,
    required String name,
    required int generation,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
    @Default('') String hostname,
    @JsonKey(
      name: 'state-dir-mode',
      unknownEnumValue: TailscaleStateDirMode.shared,
    )
    @Default(TailscaleStateDirMode.shared)
    TailscaleStateDirMode stateDirMode,
    @Default(false) bool started,
    @JsonKey(
      name: 'backend-state',
      unknownEnumValue: TailscaleBackendState.unknown,
    )
    @Default(TailscaleBackendState.none)
    TailscaleBackendState backendState,
    @JsonKey(name: 'logged-out') @Default(false) bool loggedOut,
    @JsonKey(name: 'has-identity') @Default(false) bool hasIdentity,
    @JsonKey(name: 'auth-key') @Default(false) bool authKey,
    @Default(false) bool ephemeral,
    @Default(false) bool overridable,
    @JsonKey(name: 'start-error') TailscaleError? startError,
    @Default(TailscaleSettings()) TailscaleSettings settings,
    @Default([]) List<String> warnings,
    TailscaleLegacyIdentity? legacy,
  }) = _TailscaleNode;

  factory TailscaleNode.fromJson(Map<String, Object?> json) =>
      _$TailscaleNodeFromJson(json);

  bool get legacySharedStatePresent =>
      warnings.contains(tailscaleLegacySharedStateWarning);

  bool get stateDirInUse => warnings.contains(tailscaleStateDirInUseWarning);

  TailscaleNodeKey get key =>
      (profileId: profileId, name: name, controlUrl: controlUrl);

  TailscaleNodeRef get ref =>
      TailscaleNodeRef(name: name, generation: generation);
}

/// A node as the Core ran it when it was read: an action on a later instance
/// fails with `tailscale_stale_generation` rather than reach the wrong one.
@freezed
abstract class TailscaleNodeRef with _$TailscaleNodeRef {
  const factory TailscaleNodeRef({
    required String name,
    required int generation,
  }) = _TailscaleNodeRef;

  factory TailscaleNodeRef.fromJson(Map<String, Object?> json) =>
      _$TailscaleNodeRefFromJson(json);
}

typedef TailscaleNodeKey = ({int profileId, String name, String controlUrl});

/// The one node the shared pre-isolation login was copied to.
@freezed
abstract class TailscaleLegacyMigration with _$TailscaleLegacyMigration {
  const factory TailscaleLegacyMigration({
    required String fingerprint,
    @JsonKey(name: 'profile-id') @Default(0) int profileId,
    @Default('') String name,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
  }) = _TailscaleLegacyMigration;

  factory TailscaleLegacyMigration.fromJson(Map<String, Object?> json) =>
      _$TailscaleLegacyMigrationFromJson(json);
}

@freezed
abstract class TailscaleLegacyIdentity with _$TailscaleLegacyIdentity {
  const factory TailscaleLegacyIdentity({
    @JsonKey(name: 'login-name') @Default('') String loginName,
    @JsonKey(name: 'display-name') @Default('') String displayName,
    @Default('') String tailnet,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
    @Default('') String fingerprint,
    @JsonKey(name: 'migrated-to') TailscaleLegacyMigration? migratedTo,
    @JsonKey(unknownEnumValue: TailscaleLegacyEligibility.unconfirmed)
    @Default(TailscaleLegacyEligibility.unconfirmed)
    TailscaleLegacyEligibility eligibility,
    @JsonKey(name: 'offer-token') String? offerToken,
  }) = _TailscaleLegacyIdentity;

  factory TailscaleLegacyIdentity.fromJson(Map<String, Object?> json) =>
      _$TailscaleLegacyIdentityFromJson(json);
}

@freezed
abstract class TailscaleMigrateResult with _$TailscaleMigrateResult {
  const factory TailscaleMigrateResult({
    required int generation,
    @JsonKey(unknownEnumValue: TailscaleMigrateOutcome.unknown)
    @Default(TailscaleMigrateOutcome.unknown)
    TailscaleMigrateOutcome outcome,
    required TailscaleLegacyMigration migration,
    required TailscaleNode node,
    @JsonKey(name: 'reapply-required') @Default(false) bool reapplyRequired,
    @JsonKey(name: 'target-untouched') @Default(false) bool targetUntouched,
    @JsonKey(name: 'archive-intact') @Default(false) bool archiveIntact,
    TailscaleError? error,
  }) = _TailscaleMigrateResult;

  factory TailscaleMigrateResult.fromJson(Map<String, Object?> json) =>
      _$TailscaleMigrateResultFromJson(json);
}

@freezed
abstract class TailscaleUser with _$TailscaleUser {
  const factory TailscaleUser({
    required String id,
    @JsonKey(name: 'login-name') @Default('') String loginName,
    @JsonKey(name: 'display-name') @Default('') String displayName,
    @JsonKey(name: 'profile-pic-url') @Default('') String profilePicUrl,
  }) = _TailscaleUser;

  factory TailscaleUser.fromJson(Map<String, Object?> json) =>
      _$TailscaleUserFromJson(json);
}

@freezed
abstract class TailscalePeer with _$TailscalePeer {
  const factory TailscalePeer({
    required String id,
    @JsonKey(name: 'host-name') @Default('') String hostName,
    @JsonKey(name: 'dns-name') @Default('') String dnsName,
    @Default('') String os,
    @JsonKey(name: 'user-id') @Default('') String userId,
    @JsonKey(name: 'alt-sharer-user-id') String? altSharerUserId,
    @Default([]) List<String> addresses,
    @Default([]) List<String> tags,
    @Default(false) bool online,
    @JsonKey(name: 'exit-node') @Default(false) bool exitNode,
    @JsonKey(name: 'exit-node-option') @Default(false) bool exitNodeOption,
    @JsonKey(name: 'sharee-node') @Default(false) bool shareeNode,
    @Default(false) bool expired,
    @JsonKey(name: 'key-expiry') DateTime? keyExpiry,
  }) = _TailscalePeer;

  factory TailscalePeer.fromJson(Map<String, Object?> json) =>
      _$TailscalePeerFromJson(json);
}

@freezed
abstract class TailscaleTailnet with _$TailscaleTailnet {
  const factory TailscaleTailnet({
    @Default('') String name,
    @JsonKey(name: 'magic-dns-suffix') @Default('') String magicDnsSuffix,
    @JsonKey(name: 'magic-dns-enabled') @Default(false) bool magicDnsEnabled,
  }) = _TailscaleTailnet;

  factory TailscaleTailnet.fromJson(Map<String, Object?> json) =>
      _$TailscaleTailnetFromJson(json);
}

@freezed
abstract class TailscalePrefs with _$TailscalePrefs {
  const factory TailscalePrefs({
    @JsonKey(name: 'exit-node-id') @Default('') String exitNodeId,
    @JsonKey(name: 'exit-node-ip') @Default('') String exitNodeIp,
    @JsonKey(name: 'auto-exit-node') @Default('') String autoExitNode,
    @JsonKey(name: 'accept-routes') @Default(false) bool acceptRoutes,
  }) = _TailscalePrefs;

  factory TailscalePrefs.fromJson(Map<String, Object?> json) =>
      _$TailscalePrefsFromJson(json);
}

@freezed
abstract class TailscaleStatus with _$TailscaleStatus {
  const factory TailscaleStatus({
    required TailscaleNode node,
    @JsonKey(name: 'auth-url-ready') @Default(false) bool authUrlReady,
    @JsonKey(name: 'have-node-key') @Default(false) bool haveNodeKey,
    TailscalePeer? self,
    @JsonKey(name: 'login-user') TailscaleUser? loginUser,
    TailscaleTailnet? tailnet,
    @Default({}) Map<String, TailscaleUser> users,
    @Default([]) List<TailscalePeer> peers,
    TailscalePrefs? prefs,
    @Default([]) List<String> health,
  }) = _TailscaleStatus;

  factory TailscaleStatus.fromJson(Map<String, Object?> json) =>
      _$TailscaleStatusFromJson(json);
}

/// [authUrl] is a credential until it expires: hand it to the browser and
/// drop it, never log or persist it.
@freezed
abstract class TailscaleLoginResult with _$TailscaleLoginResult {
  const factory TailscaleLoginResult({
    required int generation,
    @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)
    @Default(TailscaleBackendState.none)
    TailscaleBackendState state,
    @JsonKey(name: 'auth-url') String? authUrl,
    @Default(false) bool pending,
  }) = _TailscaleLoginResult;

  factory TailscaleLoginResult.fromJson(Map<String, Object?> json) =>
      _$TailscaleLoginResultFromJson(json);
}

@freezed
abstract class TailscaleLogoutResult with _$TailscaleLogoutResult {
  const factory TailscaleLogoutResult({
    required int generation,
    @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)
    @Default(TailscaleBackendState.none)
    TailscaleBackendState state,
    @JsonKey(unknownEnumValue: TailscaleLogoutOutcome.unknown)
    @Default(TailscaleLogoutOutcome.unknown)
    TailscaleLogoutOutcome outcome,
    @JsonKey(name: 'server-confirmed') @Default(false) bool serverConfirmed,
    @JsonKey(name: 'identity-cleared') @Default(false) bool identityCleared,
    TailscaleError? error,
  }) = _TailscaleLogoutResult;

  factory TailscaleLogoutResult.fromJson(Map<String, Object?> json) =>
      _$TailscaleLogoutResultFromJson(json);
}

@freezed
abstract class TailscalePrefsResult with _$TailscalePrefsResult {
  const factory TailscalePrefsResult({
    required int generation,
    @JsonKey(unknownEnumValue: TailscalePrefsOutcome.unknown)
    @Default(TailscalePrefsOutcome.unknown)
    TailscalePrefsOutcome outcome,
    TailscalePrefs? prefs,
    TailscaleError? error,
  }) = _TailscalePrefsResult;

  factory TailscalePrefsResult.fromJson(Map<String, Object?> json) =>
      _$TailscalePrefsResultFromJson(json);
}

@freezed
abstract class TailscaleStateEvent with _$TailscaleStateEvent {
  const factory TailscaleStateEvent({
    required String name,
    required int generation,
    @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)
    @Default(TailscaleBackendState.none)
    TailscaleBackendState state,
    @JsonKey(name: 'auth-url-ready') @Default(false) bool authUrlReady,
  }) = _TailscaleStateEvent;

  factory TailscaleStateEvent.fromJson(Map<String, Object?> json) =>
      _$TailscaleStateEventFromJson(json);
}

/// What the app keeps for one node; a null field leaves the config's value.
/// An empty [exitNode] is the explicit choice of no exit node.
@freezed
abstract class TailscaleNodeRecord with _$TailscaleNodeRecord {
  const TailscaleNodeRecord._();

  const factory TailscaleNodeRecord({
    @JsonKey(name: 'profile-id') required int profileId,
    required String name,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
    @JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,
    @JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,
    @JsonKey(name: 'logged-out') @Default(false) bool loggedOut,
  }) = _TailscaleNodeRecord;

  factory TailscaleNodeRecord.fromJson(Map<String, Object?> json) =>
      _$TailscaleNodeRecordFromJson(json);

  TailscaleNodeKey get key =>
      (profileId: profileId, name: name, controlUrl: controlUrl);

  bool get isEmpty => exitNode == null && acceptRoutes == null && !loggedOut;

  TailscaleNodeSetup get setup => TailscaleNodeSetup(
    name: name,
    controlUrl: controlUrl,
    exitNode: exitNode,
    acceptRoutes: acceptRoutes,
    loggedOut: loggedOut,
  );
}

@freezed
abstract class TailscaleNodeSetup with _$TailscaleNodeSetup {
  const factory TailscaleNodeSetup({
    required String name,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
    @JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,
    @JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,
    @JsonKey(name: 'logged-out') @Default(false) bool loggedOut,
  }) = _TailscaleNodeSetup;

  factory TailscaleNodeSetup.fromJson(Map<String, Object?> json) =>
      _$TailscaleNodeSetupFromJson(json);
}

@freezed
abstract class TailscaleSetup with _$TailscaleSetup {
  const factory TailscaleSetup({
    @JsonKey(name: 'profile-id') required int profileId,
    @JsonKey(name: 'config-source')
    required TailscaleSettingSource configSource,
    @Default([]) List<TailscaleNodeSetup> nodes,
    @JsonKey(name: 'legacy-migration', includeIfNull: false)
    TailscaleLegacyMigration? legacyMigration,
  }) = _TailscaleSetup;

  factory TailscaleSetup.fromJson(Map<String, Object?> json) =>
      _$TailscaleSetupFromJson(json);
}

/// The outcome of a settings change: persisted first, then applied.
@freezed
abstract class TailscaleSetPrefsResult with _$TailscaleSetPrefsResult {
  const factory TailscaleSetPrefsResult({
    required TailscaleSetPrefsOutcome outcome,
    TailscalePrefs? prefs,
    TailscaleError? error,
  }) = _TailscaleSetPrefsResult;
}

/// Kept per node for the app's lifetime, so a pending outcome outlives the page.
@freezed
abstract class TailscaleLegacyState with _$TailscaleLegacyState {
  const factory TailscaleLegacyState({
    @Default(false) bool offered,
    @Default(false) bool migrating,
    @Default(TailscaleLegacyNotice.none) TailscaleLegacyNotice notice,

    @Default(true) bool archiveIntact,
  }) = _TailscaleLegacyState;
}
