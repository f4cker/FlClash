// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../core.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SetupParams _$SetupParamsFromJson(Map<String, dynamic> json) => _SetupParams(
  base: json['base'] == null
      ? null
      : SetupBase.fromJson(json['base'] as Map<String, dynamic>),
  selectedMap: Map<String, String>.from(json['selected-map'] as Map),
  options: CoreOptions.fromJson(json['options'] as Map<String, dynamic>),
  tailscale: json['tailscale'] == null
      ? null
      : TailscaleSetup.fromJson(json['tailscale'] as Map<String, dynamic>),
  mounts: json['mounts'] == null
      ? null
      : MountSetup.fromJson(json['mounts'] as Map<String, dynamic>),
  mitm: json['mitm'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$SetupParamsToJson(_SetupParams instance) =>
    <String, dynamic>{
      'base': ?instance.base,
      'selected-map': instance.selectedMap,
      'options': instance.options,
      'tailscale': ?instance.tailscale,
      'mounts': ?instance.mounts,
      'mitm': ?instance.mitm,
    };

_CoreOptions _$CoreOptionsFromJson(Map<String, dynamic> json) => _CoreOptions(
  testUrl: json['test-url'] as String,
  skipCertVerify: json['skip-cert-verify'] as bool? ?? false,
  delayTestTimeout:
      (json['delay-test-timeout'] as num?)?.toInt() ?? defaultDelayTestTimeout,
  mitmCapture: json['mitm-capture'] as bool? ?? false,
);

Map<String, dynamic> _$CoreOptionsToJson(_CoreOptions instance) =>
    <String, dynamic>{
      'test-url': instance.testUrl,
      'skip-cert-verify': instance.skipCertVerify,
      'delay-test-timeout': instance.delayTestTimeout,
      'mitm-capture': instance.mitmCapture,
    };

_SetupBase _$SetupBaseFromJson(Map<String, dynamic> json) => _SetupBase(
  path: json['path'] as String,
  overlay: json['overlay'] as String,
);

Map<String, dynamic> _$SetupBaseToJson(_SetupBase instance) =>
    <String, dynamic>{'path': instance.path, 'overlay': instance.overlay};

_ProfileBase _$ProfileBaseFromJson(Map<String, dynamic> json) => _ProfileBase(
  config: json['config'] as Map<String, dynamic>,
  digest: json['digest'] as String,
  matchRules:
      (json['match-rules'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  proxies: (json['proxies'] as num?)?.toInt() ?? 0,
  proxyGroups: (json['proxy-groups'] as num?)?.toInt() ?? 0,
  rules: (json['rules'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ProfileBaseToJson(_ProfileBase instance) =>
    <String, dynamic>{
      'config': instance.config,
      'digest': instance.digest,
      'match-rules': instance.matchRules,
      'proxies': instance.proxies,
      'proxy-groups': instance.proxyGroups,
      'rules': instance.rules,
    };

_UpdateParams _$UpdateParamsFromJson(Map<String, dynamic> json) =>
    _UpdateParams(
      tun: json['tun'] as Map<String, dynamic>?,
      mixedPort: (json['mixed-port'] as num?)?.toInt(),
      allowLan: json['allow-lan'] as bool?,
      findProcessMode: $enumDecodeNullable(
        _$FindProcessModeEnumMap,
        json['find-process-mode'],
      ),
      mode: $enumDecodeNullable(_$ModeEnumMap, json['mode']),
      logLevel: $enumDecodeNullable(_$LogLevelEnumMap, json['log-level']),
      ipv6: json['ipv6'] as bool?,
      tcpConcurrent: json['tcp-concurrent'] as bool?,
      externalController: $enumDecodeNullable(
        _$ExternalControllerStatusEnumMap,
        json['external-controller'],
      ),
      secret: json['secret'] as String?,
      unifiedDelay: json['unified-delay'] as bool?,
      authentication: (json['authentication'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      geoAutoUpdate: json['geo-auto-update'] as bool?,
      geoUpdateInterval: (json['geo-update-interval'] as num?)?.toInt(),
      geoXUrl: (json['geox-url'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      options: CoreOptions.fromJson(json['options'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UpdateParamsToJson(_UpdateParams instance) =>
    <String, dynamic>{
      'tun': ?instance.tun,
      'mixed-port': ?instance.mixedPort,
      'allow-lan': ?instance.allowLan,
      'find-process-mode': ?_$FindProcessModeEnumMap[instance.findProcessMode],
      'mode': ?_$ModeEnumMap[instance.mode],
      'log-level': ?_$LogLevelEnumMap[instance.logLevel],
      'ipv6': ?instance.ipv6,
      'tcp-concurrent': ?instance.tcpConcurrent,
      'external-controller':
          ?_$ExternalControllerStatusEnumMap[instance.externalController],
      'secret': ?instance.secret,
      'unified-delay': ?instance.unifiedDelay,
      'authentication': ?instance.authentication,
      'geo-auto-update': ?instance.geoAutoUpdate,
      'geo-update-interval': ?instance.geoUpdateInterval,
      'geox-url': ?instance.geoXUrl,
      'options': instance.options,
    };

const _$FindProcessModeEnumMap = {
  FindProcessMode.always: 'always',
  FindProcessMode.off: 'off',
};

const _$ModeEnumMap = {
  Mode.rule: 'rule',
  Mode.global: 'global',
  Mode.direct: 'direct',
};

const _$LogLevelEnumMap = {
  LogLevel.debug: 'debug',
  LogLevel.info: 'info',
  LogLevel.warning: 'warning',
  LogLevel.error: 'error',
  LogLevel.silent: 'silent',
};

const _$ExternalControllerStatusEnumMap = {
  ExternalControllerStatus.close: '',
  ExternalControllerStatus.open: '127.0.0.1:9090',
};

_MitmStatus _$MitmStatusFromJson(Map<String, dynamic> json) => _MitmStatus(
  enable: json['enable'] as bool? ?? false,
  hostnames: (json['hostnames'] as num?)?.toInt() ?? 0,
  ignoredHostnames: (json['ignored-hostnames'] as num?)?.toInt() ?? 0,
  capture: json['capture'] as bool? ?? false,
  paused: json['paused'] as String? ?? '',
);

Map<String, dynamic> _$MitmStatusToJson(_MitmStatus instance) =>
    <String, dynamic>{
      'enable': instance.enable,
      'hostnames': instance.hostnames,
      'ignored-hostnames': instance.ignoredHostnames,
      'capture': instance.capture,
      'paused': instance.paused,
    };

_MitmCertificate _$MitmCertificateFromJson(Map<String, dynamic> json) =>
    _MitmCertificate(
      pem: json['pem'] as String,
      fingerprint: json['fingerprint'] as String,
      subject: json['subject'] as String,
      notBefore: DateTime.parse(json['not-before'] as String),
      notAfter: DateTime.parse(json['not-after'] as String),
    );

Map<String, dynamic> _$MitmCertificateToJson(_MitmCertificate instance) =>
    <String, dynamic>{
      'pem': instance.pem,
      'fingerprint': instance.fingerprint,
      'subject': instance.subject,
      'not-before': instance.notBefore.toIso8601String(),
      'not-after': instance.notAfter.toIso8601String(),
    };

_MitmScriptOutput _$MitmScriptOutputFromJson(Map<String, dynamic> json) =>
    _MitmScriptOutput(
      logs:
          (json['logs'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      result: json['result'] as String? ?? '',
      error: json['error'] as String? ?? '',
    );

Map<String, dynamic> _$MitmScriptOutputToJson(_MitmScriptOutput instance) =>
    <String, dynamic>{
      'logs': instance.logs,
      'result': instance.result,
      'error': instance.error,
    };

_MitmExchangeSummary _$MitmExchangeSummaryFromJson(Map<String, dynamic> json) =>
    _MitmExchangeSummary(
      id: (json['id'] as num).toInt(),
      start: DateTime.parse(json['start'] as String),
      pending: json['pending'] as bool? ?? false,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      method: json['method'] as String? ?? '',
      proto: json['proto'] as String? ?? '',
      url: json['url'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      requestSize: (json['request-size'] as num?)?.toInt() ?? 0,
      responseSize: (json['response-size'] as num?)?.toInt() ?? 0,
      error: json['error'] as String? ?? '',
      rewritten: json['rewritten'] as bool? ?? false,
      rewriteSkipped: json['rewrite-skipped'] as bool? ?? false,
    );

Map<String, dynamic> _$MitmExchangeSummaryToJson(
  _MitmExchangeSummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'start': instance.start.toIso8601String(),
  'pending': instance.pending,
  'duration': instance.duration,
  'method': instance.method,
  'proto': instance.proto,
  'url': instance.url,
  'status': instance.status,
  'request-size': instance.requestSize,
  'response-size': instance.responseSize,
  'error': instance.error,
  'rewritten': instance.rewritten,
  'rewrite-skipped': instance.rewriteSkipped,
};

_MitmExchangeList _$MitmExchangeListFromJson(
  Map<String, dynamic> json,
) => _MitmExchangeList(
  capturing: json['capturing'] as bool? ?? false,
  since: json['since'] == null ? null : DateTime.parse(json['since'] as String),
  exchanges:
      (json['exchanges'] as List<dynamic>?)
          ?.map((e) => MitmExchangeSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  closed: json['closed'] as bool? ?? false,
);

Map<String, dynamic> _$MitmExchangeListToJson(_MitmExchangeList instance) =>
    <String, dynamic>{
      'capturing': instance.capturing,
      'since': instance.since?.toIso8601String(),
      'exchanges': instance.exchanges,
      'closed': instance.closed,
    };

_MitmAction _$MitmActionFromJson(Map<String, dynamic> json) => _MitmAction(
  kind: json['kind'] as String,
  phase: json['phase'] as String? ?? '',
  detail: json['detail'] as String? ?? '',
  rule: json['rule'] as String? ?? '',
  skipped: json['skipped'] as String? ?? '',
  tookNs: (json['took-ns'] as num?)?.toInt() ?? 0,
  logs:
      (json['logs'] as List<dynamic>?)
          ?.map((e) => MitmScriptLog.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  requests:
      (json['requests'] as List<dynamic>?)
          ?.map((e) => MitmScriptRequest.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  error: json['error'] as String? ?? '',
);

Map<String, dynamic> _$MitmActionToJson(_MitmAction instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'phase': instance.phase,
      'detail': instance.detail,
      'rule': instance.rule,
      'skipped': instance.skipped,
      'took-ns': instance.tookNs,
      'logs': instance.logs,
      'requests': instance.requests,
      'error': instance.error,
    };

_MitmScriptLog _$MitmScriptLogFromJson(Map<String, dynamic> json) =>
    _MitmScriptLog(
      level: json['level'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );

Map<String, dynamic> _$MitmScriptLogToJson(_MitmScriptLog instance) =>
    <String, dynamic>{'level': instance.level, 'text': instance.text};

_MitmScriptRequest _$MitmScriptRequestFromJson(Map<String, dynamic> json) =>
    _MitmScriptRequest(
      method: json['method'] as String? ?? '',
      url: json['url'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      error: json['error'] as String? ?? '',
      tookNs: (json['took-ns'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MitmScriptRequestToJson(_MitmScriptRequest instance) =>
    <String, dynamic>{
      'method': instance.method,
      'url': instance.url,
      'status': instance.status,
      'error': instance.error,
      'took-ns': instance.tookNs,
    };

_MitmConnectionRewrite _$MitmConnectionRewriteFromJson(
  Map<String, dynamic> json,
) => _MitmConnectionRewrite(
  applied: json['applied'] as bool? ?? false,
  failed: json['failed'] as bool? ?? false,
  hit: json['hit'] == null
      ? null
      : MitmAction.fromJson(json['hit'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MitmConnectionRewriteToJson(
  _MitmConnectionRewrite instance,
) => <String, dynamic>{
  'applied': instance.applied,
  'failed': instance.failed,
  'hit': instance.hit,
};

_MitmExchange _$MitmExchangeFromJson(
  Map<String, dynamic> json,
) => _MitmExchange(
  id: (json['id'] as num).toInt(),
  start: DateTime.parse(json['start'] as String),
  pending: json['pending'] as bool? ?? false,
  duration: (json['duration'] as num?)?.toInt() ?? 0,
  ttfb: (json['ttfb'] as num?)?.toInt() ?? 0,
  method: json['method'] as String? ?? '',
  url: json['url'] as String? ?? '',
  originalUrl: json['original-url'] as String? ?? '',
  proto: json['proto'] as String? ?? '',
  status: (json['status'] as num?)?.toInt() ?? 0,
  requestSize: (json['request-size'] as num?)?.toInt() ?? 0,
  responseSize: (json['response-size'] as num?)?.toInt() ?? 0,
  error: json['error'] as String? ?? '',
  connection: json['connection'] as String? ?? '',
  requestHeader:
      (json['request-header'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ) ??
      const {},
  responseHeader:
      (json['response-header'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ) ??
      const {},
  actions:
      (json['actions'] as List<dynamic>?)
          ?.map((e) => MitmAction.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  rewritten: json['rewritten'] as bool? ?? false,
  rewriteSkipped: json['rewrite-skipped'] as bool? ?? false,
  originalRequestHeader:
      (json['original-request-header'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ) ??
      const {},
  originalResponseHeader:
      (json['original-response-header'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ) ??
      const {},
  originalRequestBody: json['original-request-body'] as bool? ?? false,
  originalResponseBody: json['original-response-body'] as bool? ?? false,
);

Map<String, dynamic> _$MitmExchangeToJson(_MitmExchange instance) =>
    <String, dynamic>{
      'id': instance.id,
      'start': instance.start.toIso8601String(),
      'pending': instance.pending,
      'duration': instance.duration,
      'ttfb': instance.ttfb,
      'method': instance.method,
      'url': instance.url,
      'original-url': instance.originalUrl,
      'proto': instance.proto,
      'status': instance.status,
      'request-size': instance.requestSize,
      'response-size': instance.responseSize,
      'error': instance.error,
      'connection': instance.connection,
      'request-header': instance.requestHeader,
      'response-header': instance.responseHeader,
      'actions': instance.actions,
      'rewritten': instance.rewritten,
      'rewrite-skipped': instance.rewriteSkipped,
      'original-request-header': instance.originalRequestHeader,
      'original-response-header': instance.originalResponseHeader,
      'original-request-body': instance.originalRequestBody,
      'original-response-body': instance.originalResponseBody,
    };

_MitmRewriteIssue _$MitmRewriteIssueFromJson(Map<String, dynamic> json) =>
    _MitmRewriteIssue(
      rule: json['rule'] as String? ?? '',
      section: json['section'] as String? ?? '',
      line: (json['line'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? '',
      args:
          (json['args'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      message: json['message'] as String? ?? '',
    );

Map<String, dynamic> _$MitmRewriteIssueToJson(_MitmRewriteIssue instance) =>
    <String, dynamic>{
      'rule': instance.rule,
      'section': instance.section,
      'line': instance.line,
      'kind': instance.kind,
      'args': instance.args,
      'message': instance.message,
    };

_MitmRewriteRuleStatus _$MitmRewriteRuleStatusFromJson(
  Map<String, dynamic> json,
) => _MitmRewriteRuleStatus(
  rule: json['rule'] as String,
  section: json['section'] as String? ?? '',
  hits: (json['hits'] as num?)?.toInt() ?? 0,
  skips: (json['skips'] as num?)?.toInt() ?? 0,
  lastSkip: json['last-skip'] as String? ?? '',
  lastSkipAt: json['last-skip-at'] == null
      ? null
      : DateTime.parse(json['last-skip-at'] as String),
);

Map<String, dynamic> _$MitmRewriteRuleStatusToJson(
  _MitmRewriteRuleStatus instance,
) => <String, dynamic>{
  'rule': instance.rule,
  'section': instance.section,
  'hits': instance.hits,
  'skips': instance.skips,
  'last-skip': instance.lastSkip,
  'last-skip-at': instance.lastSkipAt?.toIso8601String(),
};

_MitmRewriteStatus _$MitmRewriteStatusFromJson(Map<String, dynamic> json) =>
    _MitmRewriteStatus(
      active: json['active'] as bool? ?? false,
      bodyLimit: (json['body-limit'] as num?)?.toInt() ?? 0,
      issues:
          (json['issues'] as List<dynamic>?)
              ?.map((e) => MitmRewriteIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      rules:
          (json['rules'] as List<dynamic>?)
              ?.map(
                (e) =>
                    MitmRewriteRuleStatus.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$MitmRewriteStatusToJson(_MitmRewriteStatus instance) =>
    <String, dynamic>{
      'active': instance.active,
      'body-limit': instance.bodyLimit,
      'issues': instance.issues,
      'rules': instance.rules,
    };

_MitmRewriteLine _$MitmRewriteLineFromJson(Map<String, dynamic> json) =>
    _MitmRewriteLine(
      section: json['section'] as String,
      line: json['line'] as String,
      number: (json['number'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MitmRewriteLineToJson(_MitmRewriteLine instance) =>
    <String, dynamic>{
      'section': instance.section,
      'line': instance.line,
      'number': instance.number,
    };

_MitmRewriteParse _$MitmRewriteParseFromJson(Map<String, dynamic> json) =>
    _MitmRewriteParse(
      rules:
          (json['rules'] as List<dynamic>?)
              ?.map((e) => MitmRewriteLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      issues:
          (json['issues'] as List<dynamic>?)
              ?.map((e) => MitmRewriteIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$MitmRewriteParseToJson(_MitmRewriteParse instance) =>
    <String, dynamic>{'rules': instance.rules, 'issues': instance.issues};

_MitmBody _$MitmBodyFromJson(Map<String, dynamic> json) => _MitmBody(
  data: json['data'] as String? ?? '',
  truncated: json['truncated'] as bool? ?? false,
  encoding: json['encoding'] as String? ?? '',
);

Map<String, dynamic> _$MitmBodyToJson(_MitmBody instance) => <String, dynamic>{
  'data': instance.data,
  'truncated': instance.truncated,
  'encoding': instance.encoding,
};

_VpnOptions _$VpnOptionsFromJson(Map<String, dynamic> json) => _VpnOptions(
  enable: json['enable'] as bool,
  port: (json['port'] as num).toInt(),
  ipv6: json['ipv6'] as bool,
  dnsHijacking: json['dnsHijacking'] as bool,
  accessControlProps: AccessControlProps.fromJson(
    json['accessControlProps'] as Map<String, dynamic>,
  ),
  allowBypass: json['allowBypass'] as bool,
  systemProxy: json['systemProxy'] as bool,
  bypassDomain: (json['bypassDomain'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  stack: json['stack'] as String,
  routeAddress:
      (json['routeAddress'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  mtu: (json['mtu'] as num?)?.toInt() ?? 0,
  congestionController: json['congestionController'] as String? ?? '',
);

Map<String, dynamic> _$VpnOptionsToJson(_VpnOptions instance) =>
    <String, dynamic>{
      'enable': instance.enable,
      'port': instance.port,
      'ipv6': instance.ipv6,
      'dnsHijacking': instance.dnsHijacking,
      'accessControlProps': instance.accessControlProps,
      'allowBypass': instance.allowBypass,
      'systemProxy': instance.systemProxy,
      'bypassDomain': instance.bypassDomain,
      'stack': instance.stack,
      'routeAddress': instance.routeAddress,
      'mtu': instance.mtu,
      'congestionController': instance.congestionController,
    };

_InitParams _$InitParamsFromJson(Map<String, dynamic> json) => _InitParams(
  homeDir: json['home-dir'] as String,
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$InitParamsToJson(_InitParams instance) =>
    <String, dynamic>{
      'home-dir': instance.homeDir,
      'version': instance.version,
    };

_ChangeProxyParams _$ChangeProxyParamsFromJson(Map<String, dynamic> json) =>
    _ChangeProxyParams(
      groupName: json['group-name'] as String,
      proxyName: json['proxy-name'] as String,
    );

Map<String, dynamic> _$ChangeProxyParamsToJson(_ChangeProxyParams instance) =>
    <String, dynamic>{
      'group-name': instance.groupName,
      'proxy-name': instance.proxyName,
    };

_ChangeProxyResult _$ChangeProxyResultFromJson(Map<String, dynamic> json) =>
    _ChangeProxyResult(
      message: json['message'] as String? ?? '',
      changed: json['changed'] as bool? ?? false,
    );

Map<String, dynamic> _$ChangeProxyResultToJson(_ChangeProxyResult instance) =>
    <String, dynamic>{'message': instance.message, 'changed': instance.changed};

_RouteSnapshot _$RouteSnapshotFromJson(Map<String, dynamic> json) =>
    _RouteSnapshot(
      coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
      routeVersion: (json['route-version'] as num?)?.toInt() ?? 0,
      running: json['running'] as bool? ?? false,
    );

Map<String, dynamic> _$RouteSnapshotToJson(_RouteSnapshot instance) =>
    <String, dynamic>{
      'core-epoch': instance.coreEpoch,
      'route-version': instance.routeVersion,
      'running': instance.running,
    };

_RouteHit _$RouteHitFromJson(Map<String, dynamic> json) => _RouteHit(
  host: json['host'] as String? ?? '',
  proxy: json['proxy'] as String? ?? '',
  exit: json['exit'] as String? ?? '',
);

Map<String, dynamic> _$RouteHitToJson(_RouteHit instance) => <String, dynamic>{
  'host': instance.host,
  'proxy': instance.proxy,
  'exit': instance.exit,
};

_CheckRoutesParams _$CheckRoutesParamsFromJson(Map<String, dynamic> json) =>
    _CheckRoutesParams(
      routes:
          (json['routes'] as List<dynamic>?)
              ?.map(
                (e) => (e as List<dynamic>)
                    .map((e) => RouteHit.fromJson(e as Map<String, dynamic>))
                    .toList(),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$CheckRoutesParamsToJson(_CheckRoutesParams instance) =>
    <String, dynamic>{'routes': instance.routes};

_RouteCheck _$RouteCheckFromJson(Map<String, dynamic> json) => _RouteCheck(
  coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
  routeVersion: (json['route-version'] as num?)?.toInt() ?? 0,
  held:
      (json['held'] as List<dynamic>?)?.map((e) => e as bool).toList() ??
      const [],
);

Map<String, dynamic> _$RouteCheckToJson(_RouteCheck instance) =>
    <String, dynamic>{
      'core-epoch': instance.coreEpoch,
      'route-version': instance.routeVersion,
      'held': instance.held,
    };

_CoreEvent _$CoreEventFromJson(Map<String, dynamic> json) => _CoreEvent(
  type: $enumDecode(_$CoreEventTypeEnumMap, json['type']),
  data: json['data'],
);

Map<String, dynamic> _$CoreEventToJson(_CoreEvent instance) =>
    <String, dynamic>{
      'type': _$CoreEventTypeEnumMap[instance.type]!,
      'data': instance.data,
    };

const _$CoreEventTypeEnumMap = {
  CoreEventType.log: 'log',
  CoreEventType.delay: 'delay',
  CoreEventType.request: 'request',
  CoreEventType.requestTraffic: 'requestTraffic',
  CoreEventType.dns: 'dns',
  CoreEventType.loaded: 'loaded',
  CoreEventType.crash: 'crash',
  CoreEventType.geoUpdate: 'geoUpdate',
  CoreEventType.routeChanged: 'routeChanged',
  CoreEventType.dialerLoop: 'dialerLoop',
  CoreEventType.tailscaleState: 'tailscaleState',
  CoreEventType.tailscaleRoutes: 'tailscaleRoutes',
  CoreEventType.mitmSign: 'mitmSign',
  CoreEventType.mitmConnection: 'mitmConnection',
  CoreEventType.mitmNotification: 'mitmNotification',
};

_TestDelayParams _$TestDelayParamsFromJson(Map<String, dynamic> json) =>
    _TestDelayParams(
      proxyName: json['proxy-name'] as String,
      testUrl: json['test-url'] as String,
      timeout: (json['timeout'] as num).toInt(),
    );

Map<String, dynamic> _$TestDelayParamsToJson(_TestDelayParams instance) =>
    <String, dynamic>{
      'proxy-name': instance.proxyName,
      'test-url': instance.testUrl,
      'timeout': instance.timeout,
    };

_Delay _$DelayFromJson(Map<String, dynamic> json) => _Delay(
  name: json['name'] as String,
  url: json['url'] as String,
  value: (json['value'] as num?)?.toInt(),
);

Map<String, dynamic> _$DelayToJson(_Delay instance) => <String, dynamic>{
  'name': instance.name,
  'url': instance.url,
  'value': instance.value,
};

_OutboundIpParams _$OutboundIpParamsFromJson(Map<String, dynamic> json) =>
    _OutboundIpParams(
      proxyName: json['proxy-name'] as String? ?? '',
      urls:
          (json['urls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      timeout: (json['timeout'] as num).toInt(),
      maxBody: (json['max-body'] as num?)?.toInt(),
    );

Map<String, dynamic> _$OutboundIpParamsToJson(_OutboundIpParams instance) =>
    <String, dynamic>{
      'proxy-name': instance.proxyName,
      'urls': instance.urls,
      'timeout': instance.timeout,
      'max-body': ?instance.maxBody,
    };

_OutboundIpResult _$OutboundIpResultFromJson(Map<String, dynamic> json) =>
    _OutboundIpResult(
      url: json['url'] as String? ?? '',
      body: json['body'] as String? ?? '',
      delay: (json['delay'] as num?)?.toInt() ?? 0,
      chains:
          (json['chains'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      error: json['error'] as String?,
      coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
      routeVersion: (json['route-version'] as num?)?.toInt() ?? 0,
      hits:
          (json['hits'] as List<dynamic>?)
              ?.map((e) => RouteHit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      nodeHits:
          (json['node-hits'] as List<dynamic>?)
              ?.map((e) => RouteHit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$OutboundIpResultToJson(_OutboundIpResult instance) =>
    <String, dynamic>{
      'url': instance.url,
      'body': instance.body,
      'delay': instance.delay,
      'chains': instance.chains,
      'error': instance.error,
      'core-epoch': instance.coreEpoch,
      'route-version': instance.routeVersion,
      'hits': instance.hits,
      'node-hits': instance.nodeHits,
    };

_ServiceCheckParams _$ServiceCheckParamsFromJson(Map<String, dynamic> json) =>
    _ServiceCheckParams(
      proxyName: json['proxy-name'] as String? ?? '',
      names:
          (json['names'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      timeout: (json['timeout'] as num).toInt(),
    );

Map<String, dynamic> _$ServiceCheckParamsToJson(_ServiceCheckParams instance) =>
    <String, dynamic>{
      'proxy-name': instance.proxyName,
      'names': instance.names,
      'timeout': instance.timeout,
    };

_ServiceCheckItem _$ServiceCheckItemFromJson(Map<String, dynamic> json) =>
    _ServiceCheckItem(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      region: json['region'] as String? ?? '',
      delay: (json['delay'] as num?)?.toInt() ?? 0,
      chains:
          (json['chains'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      checkedAt: (json['checked-at'] as num?)?.toInt() ?? 0,
      coreEpoch: (json['core-epoch'] as num?)?.toInt() ?? 0,
      routeVersion: (json['route-version'] as num?)?.toInt() ?? 0,
      hits:
          (json['hits'] as List<dynamic>?)
              ?.map((e) => RouteHit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ServiceCheckItemToJson(_ServiceCheckItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'status': instance.status,
      'region': instance.region,
      'delay': instance.delay,
      'chains': instance.chains,
      'checked-at': instance.checkedAt,
      'core-epoch': instance.coreEpoch,
      'route-version': instance.routeVersion,
      'hits': instance.hits,
    };

_CoreMemoryStats _$CoreMemoryStatsFromJson(Map<String, dynamic> json) =>
    _CoreMemoryStats(
      rss: (json['rss'] as num?)?.toInt() ?? 0,
      heapInuse: (json['heap-inuse'] as num?)?.toInt() ?? 0,
      heapIdle: (json['heap-idle'] as num?)?.toInt() ?? 0,
      stackInuse: (json['stack-inuse'] as num?)?.toInt() ?? 0,
      runtimeOther: (json['runtime-other'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CoreMemoryStatsToJson(_CoreMemoryStats instance) =>
    <String, dynamic>{
      'rss': instance.rss,
      'heap-inuse': instance.heapInuse,
      'heap-idle': instance.heapIdle,
      'stack-inuse': instance.stackInuse,
      'runtime-other': instance.runtimeOther,
    };

_ExternalProvider _$ExternalProviderFromJson(Map<String, dynamic> json) =>
    _ExternalProvider(
      name: json['name'] as String,
      type: json['type'] as String,
      path: json['path'] as String?,
      count: (json['count'] as num).toInt(),
      subscriptionInfo: subscriptionInfoFormCore(
        json['subscription-info'] as Map<String, Object?>?,
      ),
      vehicleType: json['vehicle-type'] as String,
      updateAt: DateTime.parse(json['update-at'] as String),
    );

Map<String, dynamic> _$ExternalProviderToJson(_ExternalProvider instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'path': instance.path,
      'count': instance.count,
      'subscription-info': instance.subscriptionInfo,
      'vehicle-type': instance.vehicleType,
      'update-at': instance.updateAt.toIso8601String(),
    };

_ProxiesData _$ProxiesDataFromJson(Map<String, dynamic> json) => _ProxiesData(
  tailscaleRevision: (json['tailscale-revision'] as num?)?.toInt() ?? 0,
  proxies: json['proxies'] as Map<String, dynamic>,
  all: (json['all'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$ProxiesDataToJson(_ProxiesData instance) =>
    <String, dynamic>{
      'tailscale-revision': instance.tailscaleRevision,
      'proxies': instance.proxies,
      'all': instance.all,
    };
