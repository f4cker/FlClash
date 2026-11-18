import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/core.freezed.dart';
part 'generated/core.g.dart';

@freezed
abstract class SetupParams with _$SetupParams {
  const factory SetupParams({
    @JsonKey(includeIfNull: false) SetupBase? base,
    @JsonKey(name: 'selected-map') required Map<String, String> selectedMap,
    required CoreOptions options,
    @JsonKey(includeIfNull: false) TailscaleSetup? tailscale,
    @JsonKey(includeIfNull: false) MountSetup? mounts,

    /// The user's decryption setup; the Core ignores a profile's own.
    @JsonKey(includeIfNull: false) Map<String, Object?>? mitm,
  }) = _SetupParams;

  factory SetupParams.fromJson(Map<String, dynamic> json) =>
      _$SetupParamsFromJson(json);
}

@freezed
abstract class CoreOptions with _$CoreOptions {
  const factory CoreOptions({
    @JsonKey(name: 'test-url') required String testUrl,
    @Default(false) @JsonKey(name: 'skip-cert-verify') bool skipCertVerify,
    @Default(defaultDelayTestTimeout)
    @JsonKey(name: 'delay-test-timeout')
    int delayTestTimeout,
    @Default(false) @JsonKey(name: 'mitm-capture') bool mitmCapture,
  }) = _CoreOptions;

  factory CoreOptions.fromJson(Map<String, Object?> json) =>
      _$CoreOptionsFromJson(json);
}

@freezed
abstract class SetupBase with _$SetupBase {
  const factory SetupBase({required String path, required String overlay}) =
      _SetupBase;

  factory SetupBase.fromJson(Map<String, dynamic> json) =>
      _$SetupBaseFromJson(json);
}

@freezed
abstract class ProfileBase with _$ProfileBase {
  const factory ProfileBase({
    required Map<String, dynamic> config,
    required String digest,
    @Default([]) @JsonKey(name: 'match-rules') List<String> matchRules,
    @Default(0) int proxies,
    @Default(0) @JsonKey(name: 'proxy-groups') int proxyGroups,
    @Default(0) int rules,
  }) = _ProfileBase;

  factory ProfileBase.fromJson(Map<String, dynamic> json) =>
      _$ProfileBaseFromJson(json);
}

@freezed
abstract class UpdateParams with _$UpdateParams {
  /// A field left null is one the Core keeps as the profile set it.
  @JsonSerializable(includeIfNull: false)
  const factory UpdateParams({
    Map<String, Object?>? tun,
    @JsonKey(name: 'mixed-port') int? mixedPort,
    @JsonKey(name: 'allow-lan') bool? allowLan,
    @JsonKey(name: 'find-process-mode') FindProcessMode? findProcessMode,
    Mode? mode,
    @JsonKey(name: 'log-level') LogLevel? logLevel,
    bool? ipv6,
    @JsonKey(name: 'tcp-concurrent') bool? tcpConcurrent,
    @JsonKey(name: 'external-controller')
    ExternalControllerStatus? externalController,
    String? secret,
    @JsonKey(name: 'unified-delay') bool? unifiedDelay,
    List<String>? authentication,
    @JsonKey(name: 'geo-auto-update') bool? geoAutoUpdate,
    @JsonKey(name: 'geo-update-interval') int? geoUpdateInterval,
    @JsonKey(name: 'geox-url') Map<String, String>? geoXUrl,
    required CoreOptions options,
  }) = _UpdateParams;

  factory UpdateParams.fromJson(Map<String, dynamic> json) =>
      _$UpdateParamsFromJson(json);
}

/// The CA the Core signs decrypted hosts' certificates with.
/// What the Core decrypts now, and how many of the profile's own `mitm`
/// hostnames it ignored, since only the user's list counts.
@freezed
abstract class MitmStatus with _$MitmStatus {
  const factory MitmStatus({
    @Default(false) bool enable,
    @Default(0) int hostnames,
    @Default(0) @JsonKey(name: 'ignored-hostnames') int ignoredHostnames,
    @Default(false) bool capture,
    @Default('') String paused,
  }) = _MitmStatus;

  factory MitmStatus.fromJson(Map<String, Object?> json) =>
      _$MitmStatusFromJson(json);
}

/// What the always-visible decryption status says: [on] once decryption is
/// ready, [decrypting] only while a connection is being decrypted.
enum MitmIndicatorKind { on, decrypting, paused, unconfirmed }

/// Why listed connections pass through as they came.
enum MitmPauseReason {
  coreStopped,
  coreIdentity,
  notTrusted,

  /// This device trusts the CA and hosts are listed, yet the Core does not
  /// decrypt: the settings have not reached it (a setup failed or is pending).
  notApplied,
  liveness,
  indicatorPending,
  partialConnections,
  unavailable,
}

@immutable
class MitmIndicator {
  const MitmIndicator.on() : kind = MitmIndicatorKind.on, reason = null;

  const MitmIndicator.decrypting()
    : kind = MitmIndicatorKind.decrypting,
      reason = null;

  const MitmIndicator.paused(MitmPauseReason this.reason)
    : kind = MitmIndicatorKind.paused;

  const MitmIndicator.unconfirmed()
    : kind = MitmIndicatorKind.unconfirmed,
      reason = null;

  final MitmIndicatorKind kind;
  final MitmPauseReason? reason;

  @override
  bool operator ==(Object other) =>
      other is MitmIndicator && other.kind == kind && other.reason == reason;

  @override
  int get hashCode => Object.hash(kind, reason);

  @override
  String toString() => 'MitmIndicator(${kind.name}, ${reason?.name})';
}

@freezed
abstract class MitmCertificate with _$MitmCertificate {
  const factory MitmCertificate({
    required String pem,
    required String fingerprint,
    required String subject,
    @JsonKey(name: 'not-before') required DateTime notBefore,
    @JsonKey(name: 'not-after') required DateTime notAfter,
  }) = _MitmCertificate;

  factory MitmCertificate.fromJson(Map<String, Object?> json) =>
      _$MitmCertificateFromJson(json);
}

@freezed
abstract class MitmScriptOutput with _$MitmScriptOutput {
  const factory MitmScriptOutput({
    @Default([]) List<String> logs,
    @Default('') String result,
    @Default('') String error,
  }) = _MitmScriptOutput;

  factory MitmScriptOutput.fromJson(Map<String, Object?> json) =>
      _$MitmScriptOutputFromJson(json);
}

/// Times are in milliseconds, sizes those of the client's bodies.
@freezed
abstract class MitmExchangeSummary with _$MitmExchangeSummary {
  const factory MitmExchangeSummary({
    required int id,
    required DateTime start,
    @Default(false) bool pending,
    @Default(0) int duration,
    @Default('') String method,
    // HTTP/1.1 or HTTP/2.0, as the client spoke it; empty from an older Core.
    @Default('') String proto,
    @Default('') String url,
    @Default(0) int status,
    @Default(0) @JsonKey(name: 'request-size') int requestSize,
    @Default(0) @JsonKey(name: 'response-size') int responseSize,
    @Default('') String error,
    // A rewrite rule changed or answered it.
    @Default(false) bool rewritten,
    // A rewrite rule matched but left a message as it was; the actions say
    // which and why.
    @Default(false) @JsonKey(name: 'rewrite-skipped') bool rewriteSkipped,
  }) = _MitmExchangeSummary;

  factory MitmExchangeSummary.fromJson(Map<String, Object?> json) =>
      _$MitmExchangeSummaryFromJson(json);
}

/// Every request that started after [since] is still kept.
@freezed
abstract class MitmExchangeList with _$MitmExchangeList {
  const factory MitmExchangeList({
    @Default(false) bool capturing,
    DateTime? since,
    @Default([]) List<MitmExchangeSummary> exchanges,
    @Default(false) bool closed,
  }) = _MitmExchangeList;

  factory MitmExchangeList.fromJson(Map<String, Object?> json) =>
      _$MitmExchangeListFromJson(json);
}

/// What one rewrite rule did: [kind] is its list ([MitmList.key]),
/// [detail] the action it took, [rule] the ID the app gave it, and
/// [skipped] why it left the message as it was, if it did.
@freezed
abstract class MitmAction with _$MitmAction {
  const factory MitmAction({
    required String kind,
    @Default('') String phase,
    @Default('') String detail,
    @Default('') String rule,
    @Default('') String skipped,
    // How long the rule took to apply; 0 when the Core did not measure it.
    @Default(0) @JsonKey(name: 'took-ns') int tookNs,
  }) = _MitmAction;

  factory MitmAction.fromJson(Map<String, Object?> json) =>
      _$MitmActionFromJson(json);
}

/// What rewrite rules did on one connection so far: [applied] when any
/// changed or answered a request, [failed] when any matched but let a
/// message pass as it was; [hit] is the latest that set one of them.
@freezed
abstract class MitmConnectionRewrite with _$MitmConnectionRewrite {
  const factory MitmConnectionRewrite({
    @Default(false) bool applied,
    @Default(false) bool failed,
    MitmAction? hit,
  }) = _MitmConnectionRewrite;

  factory MitmConnectionRewrite.fromJson(Map<String, Object?> json) =>
      _$MitmConnectionRewriteFromJson(json);
}

@freezed
abstract class MitmExchange with _$MitmExchange {
  const factory MitmExchange({
    required int id,
    required DateTime start,
    @Default(false) bool pending,
    @Default(0) int duration,
    @Default(0) int ttfb,
    @Default('') String method,
    @Default('') String url,
    @Default('') @JsonKey(name: 'original-url') String originalUrl,
    @Default('') String proto,
    @Default(0) int status,
    @Default(0) @JsonKey(name: 'request-size') int requestSize,
    @Default(0) @JsonKey(name: 'response-size') int responseSize,
    @Default('') String error,
    @Default('') String connection,
    @Default({})
    @JsonKey(name: 'request-header')
    Map<String, List<String>> requestHeader,
    @Default({})
    @JsonKey(name: 'response-header')
    Map<String, List<String>> responseHeader,
    @Default([]) List<MitmAction> actions,
    @Default(false) bool rewritten,
    @Default(false) @JsonKey(name: 'rewrite-skipped') bool rewriteSkipped,
    // A side's headers before rewrite rules changed them, and whether its
    // body as it came is kept; set only for a side the rules changed.
    @Default({})
    @JsonKey(name: 'original-request-header')
    Map<String, List<String>> originalRequestHeader,
    @Default({})
    @JsonKey(name: 'original-response-header')
    Map<String, List<String>> originalResponseHeader,
    @Default(false)
    @JsonKey(name: 'original-request-body')
    bool originalRequestBody,
    @Default(false)
    @JsonKey(name: 'original-response-body')
    bool originalResponseBody,
  }) = _MitmExchange;

  factory MitmExchange.fromJson(Map<String, Object?> json) =>
      _$MitmExchangeFromJson(json);
}

/// A rewrite rule the Core left out, or a pasted line it could not take.
@freezed
abstract class MitmRewriteIssue with _$MitmRewriteIssue {
  const factory MitmRewriteIssue({
    @Default('') String rule,
    @Default('') String section,
    // 1-based within pasted text; 0 for a stored rule.
    @Default(0) int line,
    // What is wrong as a stable code and the values its text names; message
    // is the Core's English, for details only.
    @Default('') String kind,
    @Default([]) List<String> args,
    @Default('') String message,
  }) = _MitmRewriteIssue;

  factory MitmRewriteIssue.fromJson(Map<String, Object?> json) =>
      _$MitmRewriteIssueFromJson(json);
}

@freezed
abstract class MitmRewriteRuleStatus with _$MitmRewriteRuleStatus {
  const factory MitmRewriteRuleStatus({
    required String rule,
    @Default('') String section,
    @Default(0) int hits,
    @Default(0) int skips,
    @Default('') @JsonKey(name: 'last-skip') String lastSkip,
    @JsonKey(name: 'last-skip-at') DateTime? lastSkipAt,
  }) = _MitmRewriteRuleStatus;

  factory MitmRewriteRuleStatus.fromJson(Map<String, Object?> json) =>
      _$MitmRewriteRuleStatusFromJson(json);
}

/// The rewrite rules in force; inactive while MITM is off.
@freezed
abstract class MitmRewriteStatus with _$MitmRewriteStatus {
  const factory MitmRewriteStatus({
    @Default(false) bool active,
    @Default(0) @JsonKey(name: 'body-limit') int bodyLimit,
    @Default([]) List<MitmRewriteIssue> issues,
    @Default([]) List<MitmRewriteRuleStatus> rules,
  }) = _MitmRewriteStatus;

  factory MitmRewriteStatus.fromJson(Map<String, Object?> json) =>
      _$MitmRewriteStatusFromJson(json);
}

@freezed
abstract class MitmRewriteLine with _$MitmRewriteLine {
  const factory MitmRewriteLine({
    required String section,
    required String line,
    @Default(0) int number,
  }) = _MitmRewriteLine;

  factory MitmRewriteLine.fromJson(Map<String, Object?> json) =>
      _$MitmRewriteLineFromJson(json);
}

/// Pasted Surge sections, split into rule lines the Core takes and the
/// lines it does not, each with its line number.
@freezed
abstract class MitmRewriteParse with _$MitmRewriteParse {
  const factory MitmRewriteParse({
    @Default([]) List<MitmRewriteLine> rules,
    @Default([]) List<MitmRewriteIssue> issues,
  }) = _MitmRewriteParse;

  factory MitmRewriteParse.fromJson(Map<String, Object?> json) =>
      _$MitmRewriteParseFromJson(json);
}

/// One side of a request as kept, decoded unless [encoding] names the coding
/// the Core could not undo; [data] is Base64.
@freezed
abstract class MitmBody with _$MitmBody {
  const factory MitmBody({
    @Default('') String data,
    @Default(false) bool truncated,
    @Default('') String encoding,
  }) = _MitmBody;

  factory MitmBody.fromJson(Map<String, Object?> json) =>
      _$MitmBodyFromJson(json);
}

@freezed
abstract class VpnOptions with _$VpnOptions {
  const factory VpnOptions({
    required bool enable,
    required int port,
    required bool ipv6,
    required bool dnsHijacking,
    required AccessControlProps accessControlProps,
    required bool allowBypass,
    required bool systemProxy,
    required List<String> bypassDomain,
    required String stack,
    @Default([]) List<String> routeAddress,
    @Default(0) int mtu,
    @Default('') String congestionController,
  }) = _VpnOptions;

  factory VpnOptions.fromJson(Map<String, Object?> json) =>
      _$VpnOptionsFromJson(json);
}

extension VpnOptionsExt on VpnOptions {
  /// Only what `ServiceController.start` and `VpnService.handleStart` read.
  VpnOptions get effective {
    if (!enable) {
      return const VpnOptions(
        enable: false,
        port: 0,
        ipv6: false,
        dnsHijacking: false,
        accessControlProps: AccessControlProps(),
        allowBypass: false,
        systemProxy: false,
        bypassDomain: [],
        stack: '',
      );
    }
    final accessControl = accessControlProps;
    final accepts = accessControl.mode == AccessControlMode.acceptSelected;
    return copyWith(
      port: systemProxy ? port : 0,
      bypassDomain: systemProxy ? bypassDomain : const [],
      accessControlProps: accessControl.enable
          ? AccessControlProps(
              enable: true,
              mode: accessControl.mode,
              acceptList: accepts ? accessControl.acceptList : const [],
              rejectList: accepts ? const [] : accessControl.rejectList,
            )
          : const AccessControlProps(),
    );
  }
}

@freezed
abstract class InitParams with _$InitParams {
  const factory InitParams({
    @JsonKey(name: 'home-dir') required String homeDir,
    required int version,
  }) = _InitParams;

  factory InitParams.fromJson(Map<String, Object?> json) =>
      _$InitParamsFromJson(json);
}

@freezed
abstract class ChangeProxyParams with _$ChangeProxyParams {
  const factory ChangeProxyParams({
    @JsonKey(name: 'group-name') required String groupName,
    @JsonKey(name: 'proxy-name') required String proxyName,
  }) = _ChangeProxyParams;

  factory ChangeProxyParams.fromJson(Map<String, Object?> json) =>
      _$ChangeProxyParamsFromJson(json);
}

@freezed
abstract class ChangeProxyResult with _$ChangeProxyResult {
  const factory ChangeProxyResult({
    @Default('') String message,
    @Default(false) bool changed,
  }) = _ChangeProxyResult;

  factory ChangeProxyResult.fromJson(Map<String, Object?> json) =>
      _$ChangeProxyResultFromJson(json);
}

@freezed
abstract class RouteSnapshot with _$RouteSnapshot {
  const factory RouteSnapshot({
    @JsonKey(name: 'core-epoch') @Default(0) int coreEpoch,
    @JsonKey(name: 'route-version') @Default(0) int routeVersion,
    @Default(false) bool running,
  }) = _RouteSnapshot;

  factory RouteSnapshot.fromJson(Map<String, Object?> json) =>
      _$RouteSnapshotFromJson(json);
}

/// [exit] is the Core's name for where a connection left, only compared whole.
@freezed
abstract class RouteHit with _$RouteHit {
  const factory RouteHit({
    @Default('') String host,
    @Default('') String proxy,
    @Default('') String exit,
  }) = _RouteHit;

  factory RouteHit.fromJson(Map<String, Object?> json) =>
      _$RouteHitFromJson(json);
}

@freezed
abstract class CheckRoutesParams with _$CheckRoutesParams {
  const factory CheckRoutesParams({@Default([]) List<List<RouteHit>> routes}) =
      _CheckRoutesParams;

  factory CheckRoutesParams.fromJson(Map<String, Object?> json) =>
      _$CheckRoutesParamsFromJson(json);
}

@freezed
abstract class RouteCheck with _$RouteCheck {
  const factory RouteCheck({
    @JsonKey(name: 'core-epoch') @Default(0) int coreEpoch,
    @JsonKey(name: 'route-version') @Default(0) int routeVersion,
    @Default([]) List<bool> held,
  }) = _RouteCheck;

  factory RouteCheck.fromJson(Map<String, Object?> json) =>
      _$RouteCheckFromJson(json);
}

@freezed
abstract class CoreEvent with _$CoreEvent {
  const factory CoreEvent({required CoreEventType type, dynamic data}) =
      _CoreEvent;

  factory CoreEvent.fromJson(Map<String, Object?> json) =>
      _$CoreEventFromJson(json);
}

@freezed
abstract class TestDelayParams with _$TestDelayParams {
  const factory TestDelayParams({
    @JsonKey(name: 'proxy-name') required String proxyName,
    @JsonKey(name: 'test-url') required String testUrl,
    required int timeout,
  }) = _TestDelayParams;

  factory TestDelayParams.fromJson(Map<String, Object?> json) =>
      _$TestDelayParamsFromJson(json);
}

@freezed
abstract class Delay with _$Delay {
  const factory Delay({required String name, required String url, int? value}) =
      _Delay;

  factory Delay.fromJson(Map<String, Object?> json) => _$DelayFromJson(json);
}

@freezed
abstract class OutboundIpParams with _$OutboundIpParams {
  const factory OutboundIpParams({
    @JsonKey(name: 'proxy-name') @Default('') String proxyName,
    @Default([]) List<String> urls,
    required int timeout,

    /// Bytes of body kept per answer; null keeps the Core's address-sized
    /// default.
    @JsonKey(name: 'max-body', includeIfNull: false) int? maxBody,
  }) = _OutboundIpParams;

  factory OutboundIpParams.fromJson(Map<String, Object?> json) =>
      _$OutboundIpParamsFromJson(json);
}

@freezed
abstract class OutboundIpResult with _$OutboundIpResult {
  const factory OutboundIpResult({
    @Default('') String url,
    @Default('') String body,
    @Default(0) int delay,
    @Default([]) List<String> chains,
    String? error,
    @JsonKey(name: 'core-epoch') @Default(0) int coreEpoch,
    @JsonKey(name: 'route-version') @Default(0) int routeVersion,
    @Default([]) List<RouteHit> hits,
    @JsonKey(name: 'node-hits') @Default([]) List<RouteHit> nodeHits,
  }) = _OutboundIpResult;

  factory OutboundIpResult.fromJson(Map<String, Object?> json) =>
      _$OutboundIpResultFromJson(json);
}

@freezed
abstract class ServiceCheckParams with _$ServiceCheckParams {
  const factory ServiceCheckParams({
    @JsonKey(name: 'proxy-name') @Default('') String proxyName,
    @Default([]) List<String> names,
    required int timeout,
  }) = _ServiceCheckParams;

  factory ServiceCheckParams.fromJson(Map<String, Object?> json) =>
      _$ServiceCheckParamsFromJson(json);
}

@freezed
abstract class ServiceCheckItem with _$ServiceCheckItem {
  const factory ServiceCheckItem({
    @Default('') String name,
    @Default('') String status,
    @Default('') String region,
    @Default(0) int delay,
    @Default([]) List<String> chains,
    @JsonKey(name: 'checked-at') @Default(0) int checkedAt,
    @JsonKey(name: 'core-epoch') @Default(0) int coreEpoch,
    @JsonKey(name: 'route-version') @Default(0) int routeVersion,
    @Default([]) List<RouteHit> hits,
  }) = _ServiceCheckItem;

  factory ServiceCheckItem.fromJson(Map<String, Object?> json) =>
      _$ServiceCheckItemFromJson(json);
}

@freezed
abstract class CoreMemoryStats with _$CoreMemoryStats {
  const factory CoreMemoryStats({
    @Default(0) int rss,
    @Default(0) @JsonKey(name: 'heap-inuse') int heapInuse,
    @Default(0) @JsonKey(name: 'heap-idle') int heapIdle,
    @Default(0) @JsonKey(name: 'stack-inuse') int stackInuse,
    @Default(0) @JsonKey(name: 'runtime-other') int runtimeOther,
  }) = _CoreMemoryStats;

  factory CoreMemoryStats.fromJson(Map<String, Object?> json) =>
      _$CoreMemoryStatsFromJson(json);
}

extension CoreMemoryStatsExt on CoreMemoryStats {
  int get runtimeTotal => heapInuse + heapIdle + stackInuse + runtimeOther;
}

SubscriptionInfo? subscriptionInfoFormCore(Map<String, Object?>? json) {
  if (json == null) return null;
  return SubscriptionInfo(
    upload: (json['Upload'] as num?)?.toInt() ?? 0,
    download: (json['Download'] as num?)?.toInt() ?? 0,
    total: (json['Total'] as num?)?.toInt() ?? 0,
    expire: (json['Expire'] as num?)?.toInt() ?? 0,
  );
}

@freezed
abstract class ExternalProvider with _$ExternalProvider {
  const factory ExternalProvider({
    required String name,
    required String type,
    String? path,
    required int count,
    @JsonKey(name: 'subscription-info', fromJson: subscriptionInfoFormCore)
    SubscriptionInfo? subscriptionInfo,
    @JsonKey(name: 'vehicle-type') required String vehicleType,
    @JsonKey(name: 'update-at') required DateTime updateAt,
  }) = _ExternalProvider;

  factory ExternalProvider.fromJson(Map<String, Object?> json) =>
      _$ExternalProviderFromJson(json);
}

extension ExternalProviderExt on ExternalProvider {
  String get updatingKey => 'provider_$name';
}

@freezed
abstract class ProxiesData with _$ProxiesData {
  const factory ProxiesData({
    @JsonKey(name: 'tailscale-revision') @Default(0) int tailscaleRevision,
    required Map<String, dynamic> proxies,
    required List<String> all,
  }) = _ProxiesData;

  factory ProxiesData.fromJson(Map<String, Object?> json) =>
      _$ProxiesDataFromJson(json);
}
