import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

import 'desktop/model.dart';
import 'method.dart';
import 'spill.dart';

/// A method answers its result or throws: a [CoreMethodException] for what the
/// Core reports or a Core out of reach, a [TimeoutException] for no answer.
abstract class CoreHandlerInterface {
  Future<CoreLifecycleResult> start();

  Future<CoreLifecycleResult> restart();

  Future<CoreLifecycleResult> stop();

  Future<CoreLifecycleResult> close();

  Future<Object?> invokeMethod({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
    CoreResultModel? model,
  });

  Future<Object?> _call(
    CoreMethod method, {
    Object? arguments,
    Duration? timeout,
    CoreResultModel? model,
  }) async {
    return await handleWatch(
      onStart: () {
        commonPrint.log(
          'Invoke method ${method.wireName} ${DateTime.now()} $arguments',
        );
      },
      function: () => invokeMethod(
        method: method,
        arguments: arguments,
        timeout: timeout,
        model: model,
      ),
      onEnd: (result, elapsedMilliseconds) {
        commonPrint.log(
          'Invoke method ${method.wireName} completed in '
          '${elapsedMilliseconds}ms',
        );
      },
    );
  }

  Future<R> _query<R>(
    CoreMethod method,
    R Function(Object data) decode, {
    Object? arguments,
    Duration? timeout,
    CoreResultModel? model,
  }) async {
    final data = await _call(
      method,
      arguments: arguments,
      timeout: timeout,
      model: model,
    );
    if (data == null) {
      throw CoreMethodException(
        code: 'empty_result',
        message: 'Core answered ${method.wireName} with nothing',
      );
    }
    return decode(data);
  }

  Future<R?> _find<R>(
    CoreMethod method,
    R Function(Object data) decode, {
    Object? arguments,
  }) async {
    final data = await _call(method, arguments: arguments);
    return data == null ? null : decode(data);
  }

  Future<void> _command(
    CoreMethod method, {
    Object? arguments,
    Duration? timeout,
  }) async {
    await _call(method, arguments: arguments, timeout: timeout);
  }

  /// For calls whose callers never wait on them, so a Core that is gone or
  /// restarting cannot surface as an unhandled asynchronous error.
  Future<void> _commandUnobserved(CoreMethod method) async {
    try {
      await _call(method);
    } catch (error) {
      commonPrint.log(
        '${method.wireName} failed: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }

  Future<void> init(InitParams params) {
    return _command(CoreMethod.coreInit, arguments: params.toJson());
  }

  Future<bool> get isInit => _query(CoreMethod.coreInitialized, _cast<bool>);

  Future<void> forceGc() => _command(CoreMethod.coreGc);

  Future<CoreMemoryStats> getMemoryStats() {
    return _query(CoreMethod.coreMemory, _model(CoreMemoryStats.fromJson));
  }

  Future<void> crash() => _command(CoreMethod.coreCrash);

  Future<void> setupConfig(SetupParams params) {
    return _command(CoreMethod.configSetup, arguments: params.toJson());
  }

  Future<void> updateConfig(UpdateParams params) {
    return _command(CoreMethod.configUpdate, arguments: params.toJson());
  }

  Future<String?> validateConfig(String path) {
    return _find(
      CoreMethod.configValidate,
      _cast<String>,
      arguments: {'path': path},
    );
  }

  Future<String> decryptConfig(String path, String ageSecretKey) {
    return _query(
      CoreMethod.configDecrypt,
      _cast<String>,
      arguments: {'path': path, 'age-secret-key': ageSecretKey},
    );
  }

  Future<Map<String, dynamic>> readConfig(String path) {
    return _query(CoreMethod.configRead, _json, arguments: {'path': path});
  }

  Future<ProfileBase> getProfileBase(String path) {
    return _query(
      CoreMethod.profileBase,
      _model(ProfileBase.fromJson),
      arguments: {'path': path},
    );
  }

  Future<Map<String, dynamic>> getProfileOutbounds(String path) {
    return _query(
      CoreMethod.profileOutbounds,
      _json,
      arguments: {'path': path},
    );
  }

  /// The profile as the Core runs it, mounts included: built on [base], or
  /// from [config] for a profile the host built whole.
  Future<String> buildProfile({
    SetupBase? base,
    String? config,
    MountSetup? mounts,
  }) {
    return _query(
      CoreMethod.profileBuild,
      _cast<String>,
      arguments: {
        ...?base?.toJson(),
        'config': ?config,
        'mounts': ?mounts?.toJson(),
      },
    );
  }

  Future<void> clearEffect(int profileId) {
    return _command(
      CoreMethod.profileClearEffect,
      arguments: {'profile-id': profileId},
    );
  }

  /// [relay] and [managed] are the target's relay list and panel-added
  /// account names; without them no node's dialer-proxy is checked.
  Future<MountSourceInspection> inspectMountSource(
    String path, {
    String ageSecretKey = '',
    List<String>? relay,
    List<String>? managed,
  }) {
    return _query(
      CoreMethod.mountInspectSource,
      _model(MountSourceInspection.fromJson),
      arguments: {
        'path': path,
        if (ageSecretKey.isNotEmpty) 'age-secret-key': ageSecretKey,
        'relay': ?relay,
        'managed': ?managed,
      },
    );
  }

  /// Display-only node/group projection; preflight must use the full candidate.
  Future<MountTarget> inspectMountTargetProjection({
    SetupBase? base,
    String? config,
    int? managedTarget,
  }) {
    return _query(
      CoreMethod.mountInspectTarget,
      _model(MountTarget.fromJson),
      arguments: {
        'base': ?base?.toJson(),
        'config': ?config,
        'managed-target': ?managedTarget,
        'projection': true,
      },
    );
  }

  /// [base] for a layered profile, [config] for a complete candidate.
  /// [managedTarget] is the target when its apply puts the panel-added
  /// Tailscale rules first, which take Tailscale traffic before its own.
  Future<MountTarget> inspectMountTarget({
    SetupBase? base,
    String? config,
    int? managedTarget,
  }) {
    return _query(
      CoreMethod.mountInspectTarget,
      _model(MountTarget.fromJson),
      arguments: {
        'base': ?base?.toJson(),
        'config': ?config,
        'managed-target': ?managedTarget,
      },
    );
  }

  Future<MountPreflight> preflightMounts({
    SetupBase? base,
    String? config,
    required MountSetup mounts,
  }) {
    return _query(
      CoreMethod.mountPreflight,
      _model(MountPreflight.fromJson),
      arguments: {
        'base': ?base?.toJson(),
        'config': ?config,
        'mounts': mounts.toJson(),
      },
    );
  }

  Future<MountRefreshResult> refreshMountSources({
    required int target,
    required int generation,
    required String revision,
    required String nextRevision,
    required Map<int, String> sources,
  }) => _query(
    CoreMethod.mountRefreshSources,
    _model(MountRefreshResult.fromJson),
    arguments: {
      'target': target,
      'generation': generation,
      'revision': revision,
      'next-revision': nextRevision,
      'sources': [
        for (final entry in sources.entries)
          {'id': entry.key, 'digest': entry.value},
      ],
    },
  );

  Future<MountRuntimeState> getMountState() {
    return _query(CoreMethod.mountState, _model(MountRuntimeState.fromJson));
  }

  Future<ProxiesData> getProxies() {
    return _query(CoreMethod.proxyList, _model(ProxiesData.fromJson));
  }

  Future<ChangeProxyResult> changeProxy(ChangeProxyParams params) {
    return _query(
      CoreMethod.proxySelect,
      _model(ChangeProxyResult.fromJson),
      arguments: params.toJson(),
    );
  }

  Future<Map<String, dynamic>?> getProxyDefinition(String name) {
    return _find(CoreMethod.proxyDefinition, _json, arguments: {'name': name});
  }

  Future<Delay> testDelay(TestDelayParams params) {
    return _query(
      CoreMethod.proxyTestDelay,
      _model(Delay.fromJson),
      arguments: params.toJson(),
      timeout: delayTestGuardDuration,
    );
  }

  Future<Map<int, String>> validateProxies(List<Map<String, dynamic>> proxies) {
    return _query(
      CoreMethod.proxyValidate,
      _issues,
      arguments: {'proxies': proxies},
    );
  }

  Future<List<Map<String, dynamic>>> convertProxies(String path) {
    return _query(
      CoreMethod.proxyConvert,
      _jsonList,
      arguments: {'path': path},
    );
  }

  Future<List<String>> encodeShareLinks(List<Map<String, dynamic>> proxies) {
    return _query(
      CoreMethod.shareLinkEncode,
      _strings,
      arguments: {'proxies': proxies},
    );
  }

  Future<List<List<Map<String, dynamic>>>> decodeShareLinks(
    List<String> lines,
  ) {
    return _query(
      CoreMethod.shareLinkDecode,
      (data) => [for (final line in data as List) _jsonList(line)],
      arguments: {'lines': lines},
    );
  }

  Future<Map<int, String>> validateFilters(List<String> filters) {
    return _query(
      CoreMethod.filterValidate,
      _issues,
      arguments: {'filters': filters},
    );
  }

  Future<List<ExternalProvider>> getExternalProviders() {
    return _query(CoreMethod.providerList, _models(ExternalProvider.fromJson));
  }

  Future<ExternalProvider?> getExternalProvider(String name) {
    return _find(
      CoreMethod.providerGet,
      _model(ExternalProvider.fromJson),
      arguments: {'name': name},
    );
  }

  Future<void> updateExternalProvider(String name) {
    return _command(CoreMethod.providerUpdate, arguments: {'name': name});
  }

  Future<void> sideLoadExternalProvider({
    required String providerName,
    required String data,
  }) {
    return _command(
      CoreMethod.providerSideLoad,
      arguments: {'name': providerName, 'data': data},
    );
  }

  Future<String> dumpRuleSet(String path) {
    return _query(
      CoreMethod.ruleSetDump,
      _cast<String>,
      arguments: {'path': path},
    );
  }

  Future<RuleSetInfo> compileRuleSet(String name, {String url = ''}) {
    return _query(CoreMethod.ruleSetCompile, (data) {
      final info = _json(data);
      return (
        behavior: RuleProviderBehavior.values.byName(
          info['behavior'] as String,
        ),
        format: RuleProviderFormat.values.byName(info['format'] as String),
      );
    }, arguments: {'name': name, 'url': url});
  }

  /// Reads the rule set [name] of the provider cache as [compileRuleSet]
  /// does, with the count of its entries.
  Future<({RuleSetInfo info, int count})> inspectRuleSet(String name) {
    return _query(CoreMethod.ruleSetCompile, (data) {
      final info = _json(data);
      return (
        info: (
          behavior: RuleProviderBehavior.values.byName(
            info['behavior'] as String,
          ),
          format: RuleProviderFormat.values.byName(info['format'] as String),
        ),
        count: (info['count'] as num?)?.toInt() ?? 0,
      );
    }, arguments: {'name': name, 'url': ''});
  }

  Future<void> updateGeoData(String type) {
    return _command(CoreMethod.geoUpdate, arguments: {'type': type});
  }

  Future<Traffic> getTraffic(bool onlyProxy) {
    return _query(
      CoreMethod.trafficCurrent,
      _model(Traffic.fromJson),
      arguments: {'only-proxy': onlyProxy},
    );
  }

  Future<Traffic> getTotalTraffic(bool onlyProxy) {
    return _query(
      CoreMethod.trafficTotal,
      _model(Traffic.fromJson),
      arguments: {'only-proxy': onlyProxy},
    );
  }

  Future<void> resetTraffic() => _commandUnobserved(CoreMethod.trafficReset);

  /// Runs [present] where the list is decoded, possibly in another isolate.
  Future<R> getConnectionsWith<R>(R Function(List<TrackerInfo>) present) {
    return _query(
      CoreMethod.connectionList,
      (data) => data as R,
      model: _presentConnections(present),
    );
  }

  Future<int> getConnectionCount() {
    return _query(CoreMethod.connectionCount, (data) => (data as num).toInt());
  }

  Future<void> closeConnection(String id) {
    return _command(CoreMethod.connectionClose, arguments: {'id': id});
  }

  Future<void> closeConnections() => _command(CoreMethod.connectionCloseAll);

  Future<void> resetConnections() => _command(CoreMethod.connectionReset);

  Future<void> clearDnsCache() => _command(CoreMethod.dnsClearCache);

  Future<void> reportNetworkChange() => _command(CoreMethod.networkChanged);

  Future<void> startLog() => _commandUnobserved(CoreMethod.logStart);

  Future<void> stopLog() => _commandUnobserved(CoreMethod.logStop);

  Future<void> startListener() => _command(CoreMethod.listenerStart);

  Future<void> stopListener() => _command(CoreMethod.listenerStop);

  /// The mixed port the Core holds, 0 when its listener is down or failed
  /// to bind.
  Future<int> getListeningMixedPort() {
    return _query(
      CoreMethod.listenerMixedPort,
      (data) => (data as num).toInt(),
    );
  }

  /// Each inbound port the Core holds, 0 for one it does not, and whether
  /// its TUN is up.
  Future<Map<String, Object?>> getListeningPorts() {
    return _query(
      CoreMethod.listenerPorts,
      (data) => Map<String, Object?>.from(data as Map),
    );
  }

  Future<RuleList> listRules({String filter = ''}) {
    return _query(
      CoreMethod.ruleList,
      _model(RuleList.fromJson),
      arguments: {if (filter.isNotEmpty) 'filter': filter},
    );
  }

  /// A page of a rule set's entries, read by the name the running config
  /// gave the set; never by a path.
  Future<RuleSetEntries> getRuleSetEntries(
    String name, {
    int offset = 0,
    int limit = 500,
    String filter = '',
  }) {
    return _query(
      CoreMethod.ruleSetEntries,
      _model(RuleSetEntries.fromJson),
      arguments: {
        'name': name,
        'offset': offset,
        'limit': limit,
        if (filter.isNotEmpty) 'filter': filter,
      },
    );
  }

  /// Matches a host or IP against the running rules without connecting; with
  /// [RuleLookupParams.resolve] a name costs one query through the Core's
  /// resolver.
  Future<RuleLookup> lookupRule(RuleLookupParams params, {Metadata? metadata}) {
    final sourcePort = int.tryParse(metadata?.sourcePort ?? '');
    return _query(
      CoreMethod.ruleLookup,
      _model(RuleLookup.fromJson),
      arguments: {
        ...params.toJson(),
        if (metadata != null) 'recordContext': true,
        if (metadata?.process.isNotEmpty == true) 'process': metadata!.process,
        if (metadata?.processPath.isNotEmpty == true)
          'processPath': metadata!.processPath,
        if (metadata?.sourceIP.isNotEmpty == true)
          'sourceIP': metadata!.sourceIP,
        if (metadata?.destinationIP.isNotEmpty == true)
          'destinationIP': metadata!.destinationIP,
        if (metadata != null && metadata.uid > 0 && metadata.uid <= 0xffffffff)
          'uid': metadata.uid,
        if (sourcePort != null && sourcePort > 0 && sourcePort <= 65535)
          'sourcePort': sourcePort,
      },
      timeout: coreGuardFor(5000),
    );
  }

  Future<RouteSnapshot> watchRoute(bool watch) {
    return _query(
      CoreMethod.routeWatch,
      _model(RouteSnapshot.fromJson),
      arguments: {'watch': watch},
    );
  }

  Future<RouteCheck> checkRoutes(CheckRoutesParams params) {
    return _query(
      CoreMethod.routeCheck,
      _model(RouteCheck.fromJson),
      arguments: params.toJson(),
      timeout: coreGuardFor(probeTimeoutDuration.inMilliseconds),
    );
  }

  Future<OutboundIpResult> outboundIp(OutboundIpParams params) {
    return _query(
      CoreMethod.probeOutboundIp,
      _model(OutboundIpResult.fromJson),
      arguments: params.toJson(),
      timeout: coreGuardFor(params.timeout),
    );
  }

  Future<List<ServiceCheckItem>> serviceCheck(ServiceCheckParams params) {
    return _query(
      CoreMethod.probeServices,
      _models(ServiceCheckItem.fromJson),
      arguments: params.toJson(),
      timeout: coreGuardFor(
        params.timeout,
        budgetFactor: serviceSweepBudgetFactor,
      ),
    );
  }

  Future<MitmCertificate?> getMitmCertificate() {
    return _find(CoreMethod.mitmCertificate, _model(MitmCertificate.fromJson));
  }

  Future<MitmCertificate> generateMitmCertificate() {
    return _query(
      CoreMethod.mitmGenerateCertificate,
      _model(MitmCertificate.fromJson),
    );
  }

  Future<Map<MitmList, Map<int, String>>> validateMitm(MitmRules rules) {
    return _query(CoreMethod.mitmValidate, (data) {
      final lists = _json(data);
      return {
        for (final list in MitmList.values)
          if (lists[list.key] case final Object issues) list: _issues(issues),
      };
    }, arguments: rules.toJson());
  }

  /// Ends decryption in the Core without a setup; a Core not decrypting is
  /// left alone.
  Future<void> disableMitm() => _command(CoreMethod.mitmDisable);

  /// Hands the Core new MITM settings without a config reload; null turns
  /// decryption off. Connections outside decryption are left alone.
  Future<void> updateMitm(Map<String, Object?>? setup) =>
      _command(CoreMethod.mitmUpdate, arguments: {'setup': setup});

  Future<MitmRewriteStatus> getMitmRewriteStatus() {
    return _query(
      CoreMethod.mitmRewriteStatus,
      _model(MitmRewriteStatus.fromJson),
    );
  }

  /// Splits pasted Surge sections into the rule lines the Core takes.
  Future<MitmRewriteParse> parseMitmRewrite(String text) {
    return _query(
      CoreMethod.mitmRewriteParse,
      _model(MitmRewriteParse.fromJson),
      arguments: {'text': text},
    );
  }

  Future<MitmStatus> getMitmStatus() {
    return _query(CoreMethod.mitmStatus, _model(MitmStatus.fromJson));
  }

  Future<void> sendMitmSignResult(int reqId, MitmSignResult result) {
    return _command(CoreMethod.mitmSignResult, arguments: result.toJson(reqId));
  }

  Future<String> issueMitmCertificate(String host) {
    return _query(
      CoreMethod.mitmIssueCertificate,
      _cast<String>,
      arguments: {'host': host},
    );
  }

  Future<MitmExchangeList> getMitmExchanges(String connectionId) {
    return _query(
      CoreMethod.mitmExchanges,
      _model(MitmExchangeList.fromJson),
      arguments: {'id': connectionId},
    );
  }

  /// Null once the Core no longer keeps the request.
  Future<MitmExchange?> getMitmExchange(int id) {
    return _find(
      CoreMethod.mitmExchange,
      _model(MitmExchange.fromJson),
      arguments: {'id': id},
    );
  }

  /// Null once the Core no longer keeps the request.
  Future<MitmBody?> getMitmBody(int id, {required bool response}) {
    return _find(
      CoreMethod.mitmBody,
      _model(MitmBody.fromJson),
      arguments: {'id': id, 'response': response},
    );
  }

  /// The Core holds the run to the script's own timeout, up to an hour.
  Future<MitmScriptOutput> runMitmScript(String name) {
    return _query(
      CoreMethod.mitmRunScript,
      _model(MitmScriptOutput.fromJson),
      arguments: {'name': name},
      timeout: const Duration(hours: 1, minutes: 1),
    );
  }

  Future<List<TailscaleNode>> getTailscaleNodes() {
    return _query(CoreMethod.tailscaleNodes, _models(TailscaleNode.fromJson));
  }

  /// Reads only; a node that has not started is described, not started.
  Future<TailscaleStatus> getTailscaleStatus(TailscaleNodeRef node) {
    return _query(
      CoreMethod.tailscaleStatus,
      _model(TailscaleStatus.fromJson),
      arguments: node.toJson(),
      timeout: tailscaleCoreGuard,
    );
  }

  Future<TailscaleNode> startTailscale(TailscaleNodeRef node) {
    return _query(
      CoreMethod.tailscaleStart,
      _model(TailscaleNode.fromJson),
      arguments: node.toJson(),
      timeout: tailscaleCoreGuard,
    );
  }

  Future<TailscaleLoginResult> loginTailscale(
    TailscaleNodeRef node, {
    bool reauth = false,
  }) {
    return _query(
      CoreMethod.tailscaleLogin,
      _model(TailscaleLoginResult.fromJson),
      arguments: {...node.toJson(), 'reauth': reauth},
      timeout: tailscaleCoreGuard,
    );
  }

  Future<TailscaleLogoutResult> logoutTailscale(TailscaleNodeRef node) {
    return _query(
      CoreMethod.tailscaleLogout,
      _model(TailscaleLogoutResult.fromJson),
      arguments: node.toJson(),
      timeout: tailscaleCoreGuard,
    );
  }

  Future<TailscalePrefsResult> setTailscalePrefs(
    TailscaleNodeRef node, {
    String? exitNode,
    String? exitLabel,
    bool? acceptRoutes,
  }) {
    return _query(
      CoreMethod.tailscaleSetPrefs,
      _model(TailscalePrefsResult.fromJson),
      arguments: {
        ...node.toJson(),
        'exit-node': ?exitNode,
        'exit-label': ?exitLabel,
        'accept-routes': ?acceptRoutes,
      },
      timeout: tailscaleCoreGuard,
    );
  }

  /// [offerToken] is the one the confirmation showed; the Core refuses it once
  /// the node or the legacy login changed.
  Future<TailscaleMigrateResult> migrateTailscaleLegacy(
    TailscaleNodeRef node, {
    required String offerToken,
  }) {
    return _query(
      CoreMethod.tailscaleMigrateLegacy,
      _model(TailscaleMigrateResult.fromJson),
      arguments: {...node.toJson(), 'offer-token': offerToken},
      timeout: tailscaleCoreGuard,
    );
  }

  Future<TailscaleRoutes> getTailscaleRoutes(int profileId) {
    return _query(
      CoreMethod.tailscaleRoutes,
      _model(TailscaleRoutes.fromJson),
      arguments: {'profile-id': profileId},
      timeout: tailscaleCoreGuard,
    );
  }

  Future<TailscaleAssignResult> assignTailscaleRoutes(
    int profileId,
    List<TailscaleRouteAssignment> assignments,
  ) {
    return _query(
      CoreMethod.tailscaleAssign,
      _model(TailscaleAssignResult.fromJson),
      arguments: {
        'profile-id': profileId,
        'assignments': [for (final item in assignments) item.toJson()],
      },
      timeout: tailscaleCoreGuard,
    );
  }

  /// Only for an explicit removal of the last account or of the profile.
  Future<TailscaleForgetResult> forgetTailscaleRoutes(int profileId) {
    return _query(
      CoreMethod.tailscaleForgetRoutes,
      _model(TailscaleForgetResult.fromJson),
      arguments: {'profile-id': profileId},
      timeout: tailscaleCoreGuard,
    );
  }

  /// Read only, for any profile, running or not.
  Future<TailscaleManagedState> getTailscaleManagedState(int profileId) {
    return _query(
      CoreMethod.tailscaleManagedState,
      _model(TailscaleManagedState.fromJson),
      arguments: {'profile-id': profileId},
      timeout: tailscaleCoreGuard,
    );
  }

  /// Read only: the rules and nodes Flash added to the running config.
  Future<TailscaleRuntimeRules> getTailscaleRuntimeRules(int profileId) {
    return _query(
      CoreMethod.tailscaleRuntimeRules,
      _model(TailscaleRuntimeRules.fromJson),
      arguments: {'profile-id': profileId},
      timeout: tailscaleCoreGuard,
    );
  }

  /// Read only: the exit group and its parents as the running config holds them.
  Future<TailscaleExitReport> getTailscaleExit(int profileId) {
    return _query(
      CoreMethod.tailscaleExit,
      _model(TailscaleExitReport.fromJson),
      arguments: {'profile-id': profileId},
      timeout: tailscaleCoreGuard,
    );
  }
}

T _cast<T>(Object data) => data as T;

Map<String, dynamic> _json(Object? data) =>
    Map<String, dynamic>.from(data as Map);

List<Map<String, dynamic>> _jsonList(Object? data) => [
  for (final item in data as List) _json(item),
];

List<String> _strings(Object data) => [
  for (final item in data as List) item as String,
];

T Function(Object) _model<T>(T Function(Map<String, dynamic>) fromJson) =>
    (data) => fromJson(_json(data));

List<T> Function(Object) _models<T>(
  T Function(Map<String, dynamic>) fromJson,
) =>
    (data) => [for (final item in data as List) fromJson(_json(item))];

Map<int, String> _issues(Object data) => {
  for (final item in data as List)
    if (item case {'index': final num index, 'message': final String message})
      index.toInt(): message,
};

CoreResultModel _presentConnections<R>(R Function(List<TrackerInfo>) present) {
  return (result) => present(trackerInfosOf(result));
}
