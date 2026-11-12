import 'dart:math';

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
    @JsonKey(name: 'managed-id') @Default('') String managedId,
    @Default(false) bool attached,
    TailscaleAccount? account,
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

  bool get managed => managedId.isNotEmpty;

  /// A panel-added node is known by its ID, whatever name the Core gave it.
  TailscaleNodeKey get key => managed
      ? tailscaleManagedNodeKey(profileId, managedId)
      : (profileId: profileId, name: name, controlUrl: controlUrl);

  TailscaleNodeRef get ref => TailscaleNodeRef(
    name: name,
    managedId: managed ? managedId : null,
    generation: generation,
  );
}

/// A random binding for a new panel-added account; never derived from a name
/// or an email.
String tailscaleManagedId() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

const _managedKeyPrefix = '\u0001managed:';

TailscaleNodeKey tailscaleManagedNodeKey(int profileId, String id) =>
    (profileId: profileId, name: '$_managedKeyPrefix$id', controlUrl: '');

/// The identity a node's own state holds; [userId], [tailnet] and
/// [controlUrl] tell one account from another, never the login name.
@freezed
abstract class TailscaleAccount with _$TailscaleAccount {
  const TailscaleAccount._();

  const factory TailscaleAccount({
    @JsonKey(name: 'user-id') @Default('') String userId,
    @JsonKey(name: 'login-name') @Default('') String loginName,
    @JsonKey(name: 'display-name') @Default('') String displayName,
    @Default('') String tailnet,

    /// The network's domain, which a rename of [tailnet] leaves alone.
    @JsonKey(name: 'tailnet-id') @Default('') String tailnetId,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
  }) = _TailscaleAccount;

  factory TailscaleAccount.fromJson(Map<String, Object?> json) =>
      _$TailscaleAccountFromJson(json);

  bool sameAs(TailscaleAccount other) =>
      userId.isNotEmpty &&
      userId == other.userId &&
      controlUrl == other.controlUrl &&
      (tailnetId.isNotEmpty && other.tailnetId.isNotEmpty
          ? tailnetId == other.tailnetId
          : tailnet == other.tailnet);
}

/// A node as the Core ran it when it was read: an action on a later instance
/// fails with `tailscale_stale_generation` rather than reach the wrong one.
@freezed
abstract class TailscaleNodeRef with _$TailscaleNodeRef {
  const factory TailscaleNodeRef({
    required String name,
    @JsonKey(name: 'managed-id', includeIfNull: false) String? managedId,
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
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    TailscaleMigrateStage? stage,
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
/// An empty [exitNode] is the explicit choice of no exit node; [exitNodeName]
/// only labels it and never reaches the Core.
@freezed
abstract class TailscaleNodeRecord with _$TailscaleNodeRecord {
  const TailscaleNodeRecord._();

  const factory TailscaleNodeRecord({
    @JsonKey(name: 'profile-id') required int profileId,
    required String name,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
    @JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,
    @JsonKey(name: 'exit-node-name', includeIfNull: false) String? exitNodeName,
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

/// A panel-added account the app keeps, in sign-in order. [id] is the
/// binding; nothing else ties it to a node or a sign-in.
@freezed
abstract class TailscaleManagedRecord with _$TailscaleManagedRecord {
  const TailscaleManagedRecord._();

  const factory TailscaleManagedRecord({
    required String id,
    @JsonKey(name: 'profile-id') required int profileId,

    /// The node's name, kept so it never moves to another account.
    @Default('') String name,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
    @JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,
    @JsonKey(name: 'exit-node-name', includeIfNull: false) String? exitNodeName,
    @JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,
    @JsonKey(name: 'logged-out') @Default(false) bool loggedOut,
    @Default(false) bool attached,

    /// A removal was started and its outcome is not known yet; it blocks a
    /// new sign-in, a second removal and deleting the profile.
    @Default(false) bool removing,

    /// Deleting its profile was started and the outcome is not known yet; it
    /// blocks deleting the profile again until a read settles it.
    @Default(false) bool unlinking,

    /// The unlink [unlinking] marks, and what it would undo.
    @JsonKey(includeIfNull: false) TailscaleUnlinkMark? unlink,

    /// The identity it was attached with, so a signed-out entry still counts
    /// against a second sign-in of the same account.
    TailscaleAccount? account,
  }) = _TailscaleManagedRecord;

  factory TailscaleManagedRecord.fromJson(Map<String, Object?> json) =>
      _$TailscaleManagedRecordFromJson(json);

  TailscaleNodeKey get key => tailscaleManagedNodeKey(profileId, id);

  TailscaleManagedSetup setupWith({required bool shared}) =>
      TailscaleManagedSetup(
        id: id,
        name: name,
        controlUrl: controlUrl,
        exitNode: exitNode,
        acceptRoutes: acceptRoutes,
        loggedOut: loggedOut,
        attached: attached,
        exitLabel: exitLabelFor(exitNode, exitNodeName, shared: shared),
      );

  /// The device, then the account once [shared] by another account.
  String? exitLabelFor(
    String? exitNode,
    String? exitNodeName, {
    required bool shared,
  }) {
    if (exitNode == null || exitNode.isEmpty) {
      return null;
    }
    String first(List<String?> values) => values.firstWhere(
      (value) => value?.trim().isNotEmpty ?? false,
      orElse: () => '',
    )!;
    final device = first([exitNodeName, exitNode]);
    if (!shared) {
      return device;
    }
    final owner = first([account?.loginName, account?.displayName, name, id]);
    return '$device · $owner';
  }
}

bool tailscaleExitShared(
  Iterable<TailscaleManagedRecord> records,
  int profileId,
) =>
    records
        .where((record) => record.profileId == profileId && record.attached)
        .length >
    1;

/// One unlink of a profile: [before] is the routing it started from, null
/// when that was not settled, so only a finished forget can be proven.
@freezed
abstract class TailscaleUnlinkMark with _$TailscaleUnlinkMark {
  const factory TailscaleUnlinkMark({
    required String operation,
    @JsonKey(name: 'profile-id') required int profileId,
    @JsonKey(includeIfNull: false) String? before,
  }) = _TailscaleUnlinkMark;

  factory TailscaleUnlinkMark.fromJson(Map<String, Object?> json) =>
      _$TailscaleUnlinkMarkFromJson(json);
}

@freezed
abstract class TailscaleManagedSetup with _$TailscaleManagedSetup {
  const factory TailscaleManagedSetup({
    required String id,
    @Default('') String name,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
    @JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,
    @JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,
    @JsonKey(name: 'logged-out') @Default(false) bool loggedOut,
    @Default(false) bool attached,
    @JsonKey(name: 'exit-label', includeIfNull: false) String? exitLabel,
  }) = _TailscaleManagedSetup;

  factory TailscaleManagedSetup.fromJson(Map<String, Object?> json) =>
      _$TailscaleManagedSetupFromJson(json);
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
    @Default([]) List<TailscaleManagedSetup> managed,

    /// The stored accounts could not be read: the Core blocks every
    /// Tailscale target rather than route by an empty list.
    @JsonKey(name: 'managed-unknown') @Default(false) bool managedUnknown,

    /// The exit group's name in the app's language.
    @JsonKey(name: 'exit-group', includeIfNull: false) String? exitGroup,
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

    /// The Core read the archive back unchanged after the last attempt.
    @Default(false) bool archiveIntact,

    /// Where the last attempt stopped; null when no result came back.
    TailscaleMigrateStage? stage,
  }) = _TailscaleLegacyState;
}

/// What the panel knows of one node beyond the Core's list, kept for the
/// app's lifetime so an operation outlives the page that started it.
@freezed
abstract class TailscalePanelNode with _$TailscalePanelNode {
  const factory TailscalePanelNode({
    /// The last read; it belongs to the node's instance of its generation.
    TailscaleStatus? status,

    /// The latest read failed; [status] is then what an earlier one gave.
    @Default(false) bool readFailed,
    @Default(false) bool reading,
    @Default(false) bool loggingIn,
    @Default(false) bool starting,

    /// The panel's own start call failed for this generation.
    @Default(false) bool startFailed,
    @Default(false) bool restarting,
    @Default(false) bool loggingOut,

    /// An action's result is not known; only a read settles it.
    @Default(false) bool unconfirmed,
    TailscaleCardNotice? notice,
    @Default(false) bool applyingExit,
    @Default(false) bool applyingRoutes,
    TailscaleSettingNotice? exitNotice,
    TailscaleSettingNotice? routesNotice,

    /// The generation the panel already started once, so a reopen does not
    /// start it again.
    int? prewarmed,
  }) = _TailscalePanelNode;
}

@freezed
abstract class TailscaleRouteTarget with _$TailscaleRouteTarget {
  const factory TailscaleRouteTarget({
    required String kind,
    required String value,
  }) = _TailscaleRouteTarget;

  factory TailscaleRouteTarget.fromJson(Map<String, Object?> json) =>
      _$TailscaleRouteTargetFromJson(json);
}

const tailscaleTargetIp = 'ip';
const tailscaleOwnerManaged = 'managed';
const tailscaleOwnerProfile = 'profile';

@freezed
abstract class TailscaleRouteOwner with _$TailscaleRouteOwner {
  const factory TailscaleRouteOwner({
    required String kind,
    required String id,
  }) = _TailscaleRouteOwner;

  factory TailscaleRouteOwner.fromJson(Map<String, Object?> json) =>
      _$TailscaleRouteOwnerFromJson(json);
}

@freezed
abstract class TailscaleRouteIdentity with _$TailscaleRouteIdentity {
  const factory TailscaleRouteIdentity({
    @JsonKey(name: 'user-id') @Default('') String userId,
    @Default('') String tailnet,
    @JsonKey(name: 'control-url') @Default('') String controlUrl,
    @JsonKey(name: 'login-name') @Default('') String loginName,
  }) = _TailscaleRouteIdentity;

  factory TailscaleRouteIdentity.fromJson(Map<String, Object?> json) =>
      _$TailscaleRouteIdentityFromJson(json);
}

@freezed
abstract class TailscaleRouteCandidate with _$TailscaleRouteCandidate {
  const factory TailscaleRouteCandidate({
    required TailscaleRouteOwner owner,
    @Default('') String device,
    @Default('') String label,
    @Default('') String tailnet,
    @Default('') String rule,
    @Default(false) bool removed,
  }) = _TailscaleRouteCandidate;

  factory TailscaleRouteCandidate.fromJson(Map<String, Object?> json) =>
      _$TailscaleRouteCandidateFromJson(json);
}

@freezed
abstract class TailscaleRouteTargetReport with _$TailscaleRouteTargetReport {
  const factory TailscaleRouteTargetReport({
    required TailscaleRouteTarget target,
    @JsonKey(unknownEnumValue: TailscaleRouteState.unconfirmed)
    @Default(TailscaleRouteState.unconfirmed)
    TailscaleRouteState state,
    TailscaleRouteOwner? owner,
    @Default([]) List<TailscaleRouteCandidate> candidates,
  }) = _TailscaleRouteTargetReport;

  factory TailscaleRouteTargetReport.fromJson(Map<String, Object?> json) =>
      _$TailscaleRouteTargetReportFromJson(json);
}

@freezed
abstract class TailscaleRouteAccountReport with _$TailscaleRouteAccountReport {
  const factory TailscaleRouteAccountReport({
    required String id,
    @Default('') String proxy,
    TailscaleRouteIdentity? identity,
    @Default(false) bool fresh,
    @Default(false) bool available,
    @JsonKey(name: 'logged-out') @Default(false) bool loggedOut,
    @Default('') String domain,
    @Default(0) int addresses,
  }) = _TailscaleRouteAccountReport;

  factory TailscaleRouteAccountReport.fromJson(Map<String, Object?> json) =>
      _$TailscaleRouteAccountReportFromJson(json);
}

/// What the Core routes for the profile's panel-added accounts.
@freezed
abstract class TailscaleRoutes with _$TailscaleRoutes {
  const TailscaleRoutes._();

  const factory TailscaleRoutes({
    @JsonKey(name: 'profile-id') @Default(0) int profileId,
    @Default(false) bool active,
    @Default(false) bool complete,
    @Default(false) bool saved,
    @Default(false) bool unreadable,
    @Default(0) int revision,
    @Default([]) List<TailscaleRouteAccountReport> accounts,
    @Default([]) List<TailscaleRouteTargetReport> targets,
    @JsonKey(name: 'protected-prefixes')
    @Default([])
    List<String> protectedPrefixes,
    @JsonKey(name: 'protected-suffixes')
    @Default([])
    List<String> protectedSuffixes,
  }) = _TailscaleRoutes;

  factory TailscaleRoutes.fromJson(Map<String, Object?> json) =>
      _$TailscaleRoutesFromJson(json);

  TailscaleRouteAccountReport? accountOf(String id) =>
      accounts.where((account) => account.id == id).firstOrNull;

  /// Targets still blocked for want of a choice: what the banner counts.
  List<TailscaleRouteTargetReport> get pending => [
    for (final target in targets)
      if (target.state == TailscaleRouteState.conflict ||
          target.state == TailscaleRouteState.reconfirm)
        target,
  ];

  List<TailscaleRouteTargetReport> get assigned => [
    for (final target in targets)
      if (target.state == TailscaleRouteState.assigned) target,
  ];

  TailscaleRouteTargetReport? targetOf(String kind, String value) => targets
      .where(
        (target) => target.target.kind == kind && target.target.value == value,
      )
      .firstOrNull;
}

@freezed
abstract class TailscaleRouteAssignment with _$TailscaleRouteAssignment {
  const factory TailscaleRouteAssignment({
    required TailscaleRouteTarget target,
    required TailscaleRouteOwner owner,
  }) = _TailscaleRouteAssignment;

  factory TailscaleRouteAssignment.fromJson(Map<String, Object?> json) =>
      _$TailscaleRouteAssignmentFromJson(json);
}

@freezed
abstract class TailscaleAssignResult with _$TailscaleAssignResult {
  const factory TailscaleAssignResult({
    @Default('') String outcome,
    TailscaleRoutes? routes,
    TailscaleError? error,
  }) = _TailscaleAssignResult;

  factory TailscaleAssignResult.fromJson(Map<String, Object?> json) =>
      _$TailscaleAssignResultFromJson(json);
}

@freezed
abstract class TailscaleForgetResult with _$TailscaleForgetResult {
  const factory TailscaleForgetResult({
    @Default('') String outcome,
    TailscaleError? error,
  }) = _TailscaleForgetResult;

  factory TailscaleForgetResult.fromJson(Map<String, Object?> json) =>
      _$TailscaleForgetResultFromJson(json);
}

/// What the Core holds of a profile's routing, read without changing it.
@freezed
abstract class TailscaleManagedState with _$TailscaleManagedState {
  const TailscaleManagedState._();

  const factory TailscaleManagedState({
    @JsonKey(name: 'profile-id') @Default(0) int profileId,
    @Default('') String routes,
    @Default('') String digest,
    @Default(false) bool running,
    @Default(false) bool forgotten,
    @Default(false) bool pending,
    @Default('') String protection,
  }) = _TailscaleManagedState;

  factory TailscaleManagedState.fromJson(Map<String, Object?> json) =>
      _$TailscaleManagedStateFromJson(json);

  /// Nothing is on its way and the REJECT rules are where [attached] needs
  /// them, so the state cannot move under the reader.
  bool settled({required bool attached}) =>
      !pending &&
      (routes == 'absent' || routes == 'kept') &&
      switch (protection) {
        'none' => !running,
        'active' => running,
        'off' => running && !attached,
        _ => false,
      };

  /// The routing a forget starts from; null when it cannot be told apart.
  String? fingerprint({required bool attached}) =>
      settled(attached: attached) && !forgotten ? '$routes:$digest' : null;

  bool get isForgotten => routes == 'absent' && (!running || forgotten);
}

@freezed
abstract class TailscaleRoutesEvent with _$TailscaleRoutesEvent {
  const factory TailscaleRoutesEvent({
    @JsonKey(name: 'profile-id') @Default(0) int profileId,
    @Default(0) int revision,
  }) = _TailscaleRoutesEvent;

  factory TailscaleRoutesEvent.fromJson(Map<String, Object?> json) =>
      _$TailscaleRoutesEventFromJson(json);
}

/// The panel's view of a panel-added account beyond the Core's list.
@freezed
abstract class TailscaleManagedPanel with _$TailscaleManagedPanel {
  const factory TailscaleManagedPanel({
    @Default(TailscaleAttachState.none) TailscaleAttachState attach,
    TailscaleManagedNotice? notice,
    @Default(false) bool removing,
    @Default(false) bool preparing,

    /// The user tapped sign-in in this run; only then does a connected draft
    /// attach on its own.
    @Default(false) bool signInTapped,
  }) = _TailscaleManagedPanel;
}
