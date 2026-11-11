// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../tailscale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TailscaleError _$TailscaleErrorFromJson(Map<String, dynamic> json) =>
    _TailscaleError(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );

Map<String, dynamic> _$TailscaleErrorToJson(_TailscaleError instance) =>
    <String, dynamic>{'code': instance.code, 'message': instance.message};

_TailscaleExitNodeSetting _$TailscaleExitNodeSettingFromJson(
  Map<String, dynamic> json,
) => _TailscaleExitNodeSetting(
  value: json['value'] as String? ?? '',
  source:
      $enumDecodeNullable(
        _$TailscaleSettingSourceEnumMap,
        json['source'],
        unknownValue: TailscaleSettingSource.coreDefault,
      ) ??
      TailscaleSettingSource.coreDefault,
);

Map<String, dynamic> _$TailscaleExitNodeSettingToJson(
  _TailscaleExitNodeSetting instance,
) => <String, dynamic>{
  'value': instance.value,
  'source': _$TailscaleSettingSourceEnumMap[instance.source]!,
};

const _$TailscaleSettingSourceEnumMap = {
  TailscaleSettingSource.override: 'override',
  TailscaleSettingSource.profile: 'profile',
  TailscaleSettingSource.subscription: 'subscription',
  TailscaleSettingSource.provider: 'provider',
  TailscaleSettingSource.coreDefault: 'default',
};

_TailscaleAcceptRoutesSetting _$TailscaleAcceptRoutesSettingFromJson(
  Map<String, dynamic> json,
) => _TailscaleAcceptRoutesSetting(
  value: json['value'] as bool? ?? false,
  source:
      $enumDecodeNullable(
        _$TailscaleSettingSourceEnumMap,
        json['source'],
        unknownValue: TailscaleSettingSource.coreDefault,
      ) ??
      TailscaleSettingSource.coreDefault,
);

Map<String, dynamic> _$TailscaleAcceptRoutesSettingToJson(
  _TailscaleAcceptRoutesSetting instance,
) => <String, dynamic>{
  'value': instance.value,
  'source': _$TailscaleSettingSourceEnumMap[instance.source]!,
};

_TailscaleSettings _$TailscaleSettingsFromJson(Map<String, dynamic> json) =>
    _TailscaleSettings(
      exitNode: json['exit-node'] == null
          ? const TailscaleExitNodeSetting()
          : TailscaleExitNodeSetting.fromJson(
              json['exit-node'] as Map<String, dynamic>,
            ),
      acceptRoutes: json['accept-routes'] == null
          ? const TailscaleAcceptRoutesSetting()
          : TailscaleAcceptRoutesSetting.fromJson(
              json['accept-routes'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$TailscaleSettingsToJson(_TailscaleSettings instance) =>
    <String, dynamic>{
      'exit-node': instance.exitNode,
      'accept-routes': instance.acceptRoutes,
    };

_TailscaleNode _$TailscaleNodeFromJson(
  Map<String, dynamic> json,
) => _TailscaleNode(
  profileId: (json['profile-id'] as num?)?.toInt() ?? 0,
  name: json['name'] as String,
  generation: (json['generation'] as num).toInt(),
  controlUrl: json['control-url'] as String? ?? '',
  hostname: json['hostname'] as String? ?? '',
  stateDirMode:
      $enumDecodeNullable(
        _$TailscaleStateDirModeEnumMap,
        json['state-dir-mode'],
        unknownValue: TailscaleStateDirMode.shared,
      ) ??
      TailscaleStateDirMode.shared,
  started: json['started'] as bool? ?? false,
  backendState:
      $enumDecodeNullable(
        _$TailscaleBackendStateEnumMap,
        json['backend-state'],
        unknownValue: TailscaleBackendState.unknown,
      ) ??
      TailscaleBackendState.none,
  loggedOut: json['logged-out'] as bool? ?? false,
  hasIdentity: json['has-identity'] as bool? ?? false,
  authKey: json['auth-key'] as bool? ?? false,
  ephemeral: json['ephemeral'] as bool? ?? false,
  overridable: json['overridable'] as bool? ?? false,
  startError: json['start-error'] == null
      ? null
      : TailscaleError.fromJson(json['start-error'] as Map<String, dynamic>),
  settings: json['settings'] == null
      ? const TailscaleSettings()
      : TailscaleSettings.fromJson(json['settings'] as Map<String, dynamic>),
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  legacy: json['legacy'] == null
      ? null
      : TailscaleLegacyIdentity.fromJson(
          json['legacy'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$TailscaleNodeToJson(_TailscaleNode instance) =>
    <String, dynamic>{
      'profile-id': instance.profileId,
      'name': instance.name,
      'generation': instance.generation,
      'control-url': instance.controlUrl,
      'hostname': instance.hostname,
      'state-dir-mode': _$TailscaleStateDirModeEnumMap[instance.stateDirMode]!,
      'started': instance.started,
      'backend-state': _$TailscaleBackendStateEnumMap[instance.backendState]!,
      'logged-out': instance.loggedOut,
      'has-identity': instance.hasIdentity,
      'auth-key': instance.authKey,
      'ephemeral': instance.ephemeral,
      'overridable': instance.overridable,
      'start-error': instance.startError,
      'settings': instance.settings,
      'warnings': instance.warnings,
      'legacy': instance.legacy,
    };

const _$TailscaleStateDirModeEnumMap = {
  TailscaleStateDirMode.derived: 'derived',
  TailscaleStateDirMode.explicit: 'explicit',
  TailscaleStateDirMode.shared: 'shared',
};

const _$TailscaleBackendStateEnumMap = {
  TailscaleBackendState.none: '',
  TailscaleBackendState.noState: 'NoState',
  TailscaleBackendState.needsLogin: 'NeedsLogin',
  TailscaleBackendState.needsMachineAuth: 'NeedsMachineAuth',
  TailscaleBackendState.stopped: 'Stopped',
  TailscaleBackendState.starting: 'Starting',
  TailscaleBackendState.running: 'Running',
  TailscaleBackendState.unknown: 'unknown',
};

_TailscaleNodeRef _$TailscaleNodeRefFromJson(Map<String, dynamic> json) =>
    _TailscaleNodeRef(
      name: json['name'] as String,
      generation: (json['generation'] as num).toInt(),
    );

Map<String, dynamic> _$TailscaleNodeRefToJson(_TailscaleNodeRef instance) =>
    <String, dynamic>{'name': instance.name, 'generation': instance.generation};

_TailscaleLegacyMigration _$TailscaleLegacyMigrationFromJson(
  Map<String, dynamic> json,
) => _TailscaleLegacyMigration(
  fingerprint: json['fingerprint'] as String,
  profileId: (json['profile-id'] as num?)?.toInt() ?? 0,
  name: json['name'] as String? ?? '',
  controlUrl: json['control-url'] as String? ?? '',
);

Map<String, dynamic> _$TailscaleLegacyMigrationToJson(
  _TailscaleLegacyMigration instance,
) => <String, dynamic>{
  'fingerprint': instance.fingerprint,
  'profile-id': instance.profileId,
  'name': instance.name,
  'control-url': instance.controlUrl,
};

_TailscaleLegacyIdentity _$TailscaleLegacyIdentityFromJson(
  Map<String, dynamic> json,
) => _TailscaleLegacyIdentity(
  loginName: json['login-name'] as String? ?? '',
  displayName: json['display-name'] as String? ?? '',
  tailnet: json['tailnet'] as String? ?? '',
  controlUrl: json['control-url'] as String? ?? '',
  fingerprint: json['fingerprint'] as String? ?? '',
  migratedTo: json['migrated-to'] == null
      ? null
      : TailscaleLegacyMigration.fromJson(
          json['migrated-to'] as Map<String, dynamic>,
        ),
  eligibility:
      $enumDecodeNullable(
        _$TailscaleLegacyEligibilityEnumMap,
        json['eligibility'],
        unknownValue: TailscaleLegacyEligibility.unconfirmed,
      ) ??
      TailscaleLegacyEligibility.unconfirmed,
  offerToken: json['offer-token'] as String?,
);

Map<String, dynamic> _$TailscaleLegacyIdentityToJson(
  _TailscaleLegacyIdentity instance,
) => <String, dynamic>{
  'login-name': instance.loginName,
  'display-name': instance.displayName,
  'tailnet': instance.tailnet,
  'control-url': instance.controlUrl,
  'fingerprint': instance.fingerprint,
  'migrated-to': instance.migratedTo,
  'eligibility': _$TailscaleLegacyEligibilityEnumMap[instance.eligibility]!,
  'offer-token': instance.offerToken,
};

const _$TailscaleLegacyEligibilityEnumMap = {
  TailscaleLegacyEligibility.eligible: 'eligible',
  TailscaleLegacyEligibility.hasIdentity: 'has-identity',
  TailscaleLegacyEligibility.controlMismatch: 'control-mismatch',
  TailscaleLegacyEligibility.inUse: 'in-use',
  TailscaleLegacyEligibility.migrated: 'migrated',
  TailscaleLegacyEligibility.notIsolated: 'not-isolated',
  TailscaleLegacyEligibility.dirInUse: 'dir-in-use',
  TailscaleLegacyEligibility.unreadable: 'unreadable',
  TailscaleLegacyEligibility.unconfirmed: 'unconfirmed',
};

_TailscaleMigrateResult _$TailscaleMigrateResultFromJson(
  Map<String, dynamic> json,
) => _TailscaleMigrateResult(
  generation: (json['generation'] as num).toInt(),
  outcome:
      $enumDecodeNullable(
        _$TailscaleMigrateOutcomeEnumMap,
        json['outcome'],
        unknownValue: TailscaleMigrateOutcome.unknown,
      ) ??
      TailscaleMigrateOutcome.unknown,
  migration: TailscaleLegacyMigration.fromJson(
    json['migration'] as Map<String, dynamic>,
  ),
  node: TailscaleNode.fromJson(json['node'] as Map<String, dynamic>),
  reapplyRequired: json['reapply-required'] as bool? ?? false,
  targetUntouched: json['target-untouched'] as bool? ?? false,
  archiveIntact: json['archive-intact'] as bool? ?? false,
  stage: $enumDecodeNullable(
    _$TailscaleMigrateStageEnumMap,
    json['stage'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  error: json['error'] == null
      ? null
      : TailscaleError.fromJson(json['error'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TailscaleMigrateResultToJson(
  _TailscaleMigrateResult instance,
) => <String, dynamic>{
  'generation': instance.generation,
  'outcome': _$TailscaleMigrateOutcomeEnumMap[instance.outcome]!,
  'migration': instance.migration,
  'node': instance.node,
  'reapply-required': instance.reapplyRequired,
  'target-untouched': instance.targetUntouched,
  'archive-intact': instance.archiveIntact,
  'stage': _$TailscaleMigrateStageEnumMap[instance.stage],
  'error': instance.error,
};

const _$TailscaleMigrateOutcomeEnumMap = {
  TailscaleMigrateOutcome.migrated: 'migrated',
  TailscaleMigrateOutcome.failed: 'failed',
  TailscaleMigrateOutcome.unknown: 'unknown',
};

const _$TailscaleMigrateStageEnumMap = {
  TailscaleMigrateStage.claim: 'claim',
  TailscaleMigrateStage.copy: 'copy',
  TailscaleMigrateStage.verify: 'verify',
};

_TailscaleUser _$TailscaleUserFromJson(Map<String, dynamic> json) =>
    _TailscaleUser(
      id: json['id'] as String,
      loginName: json['login-name'] as String? ?? '',
      displayName: json['display-name'] as String? ?? '',
      profilePicUrl: json['profile-pic-url'] as String? ?? '',
    );

Map<String, dynamic> _$TailscaleUserToJson(_TailscaleUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'login-name': instance.loginName,
      'display-name': instance.displayName,
      'profile-pic-url': instance.profilePicUrl,
    };

_TailscalePeer _$TailscalePeerFromJson(Map<String, dynamic> json) =>
    _TailscalePeer(
      id: json['id'] as String,
      hostName: json['host-name'] as String? ?? '',
      dnsName: json['dns-name'] as String? ?? '',
      os: json['os'] as String? ?? '',
      userId: json['user-id'] as String? ?? '',
      altSharerUserId: json['alt-sharer-user-id'] as String?,
      addresses:
          (json['addresses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      online: json['online'] as bool? ?? false,
      exitNode: json['exit-node'] as bool? ?? false,
      exitNodeOption: json['exit-node-option'] as bool? ?? false,
      shareeNode: json['sharee-node'] as bool? ?? false,
      expired: json['expired'] as bool? ?? false,
      keyExpiry: json['key-expiry'] == null
          ? null
          : DateTime.parse(json['key-expiry'] as String),
    );

Map<String, dynamic> _$TailscalePeerToJson(_TailscalePeer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'host-name': instance.hostName,
      'dns-name': instance.dnsName,
      'os': instance.os,
      'user-id': instance.userId,
      'alt-sharer-user-id': instance.altSharerUserId,
      'addresses': instance.addresses,
      'tags': instance.tags,
      'online': instance.online,
      'exit-node': instance.exitNode,
      'exit-node-option': instance.exitNodeOption,
      'sharee-node': instance.shareeNode,
      'expired': instance.expired,
      'key-expiry': instance.keyExpiry?.toIso8601String(),
    };

_TailscaleTailnet _$TailscaleTailnetFromJson(Map<String, dynamic> json) =>
    _TailscaleTailnet(
      name: json['name'] as String? ?? '',
      magicDnsSuffix: json['magic-dns-suffix'] as String? ?? '',
      magicDnsEnabled: json['magic-dns-enabled'] as bool? ?? false,
    );

Map<String, dynamic> _$TailscaleTailnetToJson(_TailscaleTailnet instance) =>
    <String, dynamic>{
      'name': instance.name,
      'magic-dns-suffix': instance.magicDnsSuffix,
      'magic-dns-enabled': instance.magicDnsEnabled,
    };

_TailscalePrefs _$TailscalePrefsFromJson(Map<String, dynamic> json) =>
    _TailscalePrefs(
      exitNodeId: json['exit-node-id'] as String? ?? '',
      exitNodeIp: json['exit-node-ip'] as String? ?? '',
      autoExitNode: json['auto-exit-node'] as String? ?? '',
      acceptRoutes: json['accept-routes'] as bool? ?? false,
    );

Map<String, dynamic> _$TailscalePrefsToJson(_TailscalePrefs instance) =>
    <String, dynamic>{
      'exit-node-id': instance.exitNodeId,
      'exit-node-ip': instance.exitNodeIp,
      'auto-exit-node': instance.autoExitNode,
      'accept-routes': instance.acceptRoutes,
    };

_TailscaleStatus _$TailscaleStatusFromJson(Map<String, dynamic> json) =>
    _TailscaleStatus(
      node: TailscaleNode.fromJson(json['node'] as Map<String, dynamic>),
      authUrlReady: json['auth-url-ready'] as bool? ?? false,
      haveNodeKey: json['have-node-key'] as bool? ?? false,
      self: json['self'] == null
          ? null
          : TailscalePeer.fromJson(json['self'] as Map<String, dynamic>),
      loginUser: json['login-user'] == null
          ? null
          : TailscaleUser.fromJson(json['login-user'] as Map<String, dynamic>),
      tailnet: json['tailnet'] == null
          ? null
          : TailscaleTailnet.fromJson(json['tailnet'] as Map<String, dynamic>),
      users:
          (json['users'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, TailscaleUser.fromJson(e as Map<String, dynamic>)),
          ) ??
          const {},
      peers:
          (json['peers'] as List<dynamic>?)
              ?.map((e) => TailscalePeer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      prefs: json['prefs'] == null
          ? null
          : TailscalePrefs.fromJson(json['prefs'] as Map<String, dynamic>),
      health:
          (json['health'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TailscaleStatusToJson(_TailscaleStatus instance) =>
    <String, dynamic>{
      'node': instance.node,
      'auth-url-ready': instance.authUrlReady,
      'have-node-key': instance.haveNodeKey,
      'self': instance.self,
      'login-user': instance.loginUser,
      'tailnet': instance.tailnet,
      'users': instance.users,
      'peers': instance.peers,
      'prefs': instance.prefs,
      'health': instance.health,
    };

_TailscaleLoginResult _$TailscaleLoginResultFromJson(
  Map<String, dynamic> json,
) => _TailscaleLoginResult(
  generation: (json['generation'] as num).toInt(),
  state:
      $enumDecodeNullable(
        _$TailscaleBackendStateEnumMap,
        json['state'],
        unknownValue: TailscaleBackendState.unknown,
      ) ??
      TailscaleBackendState.none,
  authUrl: json['auth-url'] as String?,
  pending: json['pending'] as bool? ?? false,
);

Map<String, dynamic> _$TailscaleLoginResultToJson(
  _TailscaleLoginResult instance,
) => <String, dynamic>{
  'generation': instance.generation,
  'state': _$TailscaleBackendStateEnumMap[instance.state]!,
  'auth-url': instance.authUrl,
  'pending': instance.pending,
};

_TailscaleLogoutResult _$TailscaleLogoutResultFromJson(
  Map<String, dynamic> json,
) => _TailscaleLogoutResult(
  generation: (json['generation'] as num).toInt(),
  state:
      $enumDecodeNullable(
        _$TailscaleBackendStateEnumMap,
        json['state'],
        unknownValue: TailscaleBackendState.unknown,
      ) ??
      TailscaleBackendState.none,
  outcome:
      $enumDecodeNullable(
        _$TailscaleLogoutOutcomeEnumMap,
        json['outcome'],
        unknownValue: TailscaleLogoutOutcome.unknown,
      ) ??
      TailscaleLogoutOutcome.unknown,
  serverConfirmed: json['server-confirmed'] as bool? ?? false,
  identityCleared: json['identity-cleared'] as bool? ?? false,
  error: json['error'] == null
      ? null
      : TailscaleError.fromJson(json['error'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TailscaleLogoutResultToJson(
  _TailscaleLogoutResult instance,
) => <String, dynamic>{
  'generation': instance.generation,
  'state': _$TailscaleBackendStateEnumMap[instance.state]!,
  'outcome': _$TailscaleLogoutOutcomeEnumMap[instance.outcome]!,
  'server-confirmed': instance.serverConfirmed,
  'identity-cleared': instance.identityCleared,
  'error': instance.error,
};

const _$TailscaleLogoutOutcomeEnumMap = {
  TailscaleLogoutOutcome.confirmed: 'confirmed',
  TailscaleLogoutOutcome.unknown: 'unknown',
};

_TailscalePrefsResult _$TailscalePrefsResultFromJson(
  Map<String, dynamic> json,
) => _TailscalePrefsResult(
  generation: (json['generation'] as num).toInt(),
  outcome:
      $enumDecodeNullable(
        _$TailscalePrefsOutcomeEnumMap,
        json['outcome'],
        unknownValue: TailscalePrefsOutcome.unknown,
      ) ??
      TailscalePrefsOutcome.unknown,
  prefs: json['prefs'] == null
      ? null
      : TailscalePrefs.fromJson(json['prefs'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : TailscaleError.fromJson(json['error'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TailscalePrefsResultToJson(
  _TailscalePrefsResult instance,
) => <String, dynamic>{
  'generation': instance.generation,
  'outcome': _$TailscalePrefsOutcomeEnumMap[instance.outcome]!,
  'prefs': instance.prefs,
  'error': instance.error,
};

const _$TailscalePrefsOutcomeEnumMap = {
  TailscalePrefsOutcome.applied: 'applied',
  TailscalePrefsOutcome.notRunning: 'not-running',
  TailscalePrefsOutcome.failed: 'failed',
  TailscalePrefsOutcome.unknown: 'unknown',
};

_TailscaleStateEvent _$TailscaleStateEventFromJson(Map<String, dynamic> json) =>
    _TailscaleStateEvent(
      name: json['name'] as String,
      generation: (json['generation'] as num).toInt(),
      state:
          $enumDecodeNullable(
            _$TailscaleBackendStateEnumMap,
            json['state'],
            unknownValue: TailscaleBackendState.unknown,
          ) ??
          TailscaleBackendState.none,
      authUrlReady: json['auth-url-ready'] as bool? ?? false,
    );

Map<String, dynamic> _$TailscaleStateEventToJson(
  _TailscaleStateEvent instance,
) => <String, dynamic>{
  'name': instance.name,
  'generation': instance.generation,
  'state': _$TailscaleBackendStateEnumMap[instance.state]!,
  'auth-url-ready': instance.authUrlReady,
};

_TailscaleNodeRecord _$TailscaleNodeRecordFromJson(Map<String, dynamic> json) =>
    _TailscaleNodeRecord(
      profileId: (json['profile-id'] as num).toInt(),
      name: json['name'] as String,
      controlUrl: json['control-url'] as String? ?? '',
      exitNode: json['exit-node'] as String?,
      acceptRoutes: json['accept-routes'] as bool?,
      loggedOut: json['logged-out'] as bool? ?? false,
    );

Map<String, dynamic> _$TailscaleNodeRecordToJson(
  _TailscaleNodeRecord instance,
) => <String, dynamic>{
  'profile-id': instance.profileId,
  'name': instance.name,
  'control-url': instance.controlUrl,
  'exit-node': ?instance.exitNode,
  'accept-routes': ?instance.acceptRoutes,
  'logged-out': instance.loggedOut,
};

_TailscaleNodeSetup _$TailscaleNodeSetupFromJson(Map<String, dynamic> json) =>
    _TailscaleNodeSetup(
      name: json['name'] as String,
      controlUrl: json['control-url'] as String? ?? '',
      exitNode: json['exit-node'] as String?,
      acceptRoutes: json['accept-routes'] as bool?,
      loggedOut: json['logged-out'] as bool? ?? false,
    );

Map<String, dynamic> _$TailscaleNodeSetupToJson(_TailscaleNodeSetup instance) =>
    <String, dynamic>{
      'name': instance.name,
      'control-url': instance.controlUrl,
      'exit-node': ?instance.exitNode,
      'accept-routes': ?instance.acceptRoutes,
      'logged-out': instance.loggedOut,
    };

_TailscaleSetup _$TailscaleSetupFromJson(Map<String, dynamic> json) =>
    _TailscaleSetup(
      profileId: (json['profile-id'] as num).toInt(),
      configSource: $enumDecode(
        _$TailscaleSettingSourceEnumMap,
        json['config-source'],
      ),
      nodes:
          (json['nodes'] as List<dynamic>?)
              ?.map(
                (e) => TailscaleNodeSetup.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      legacyMigration: json['legacy-migration'] == null
          ? null
          : TailscaleLegacyMigration.fromJson(
              json['legacy-migration'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$TailscaleSetupToJson(_TailscaleSetup instance) =>
    <String, dynamic>{
      'profile-id': instance.profileId,
      'config-source': _$TailscaleSettingSourceEnumMap[instance.configSource]!,
      'nodes': instance.nodes,
      'legacy-migration': ?instance.legacyMigration,
    };
