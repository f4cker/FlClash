import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

Future<T> decodeJSONTask<T>(String data) async {
  return compute<String, T>(_decodeJSON, data);
}

Future<T> _decodeJSON<T>(String content) async {
  return json.decode(content);
}

Future<String> encodeYamlTask<T>(T data) async {
  return compute<T, String>(_encodeYaml, data);
}

Future<String> _encodeYaml<T>(T content) async {
  return yaml.encode(content);
}

/// Throws [FormatException] when the file is not UTF-8.
Future<String?> readTextFileTask(String path) {
  return compute(_readTextFile, path);
}

String? _readTextFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  return utf8.decode(file.readAsBytesSync());
}

Future<List<Group>> toGroupsTask(ComputeGroupsState data) async {
  return compute<ComputeGroupsState, List<Group>>(buildGroups, data);
}

@visibleForTesting
Future<List<Group>> buildGroups(ComputeGroupsState state) async {
  final proxiesData = state.proxiesData;
  final all = proxiesData.all;
  final sortType = state.sortType;
  final delayMap = state.delayMap;
  final selectedMap = state.selectedMap;
  final defaultTestUrl = state.defaultTestUrl;
  final proxies = proxiesData.proxies;
  if (proxies.isEmpty) return [];
  final groups = <Group>[];
  for (final groupName in all) {
    final raw = proxies[groupName];
    if (raw is! Map) continue;
    if (!GroupTypeExtension.valueList.contains(raw['type'])) continue;
    final memberNames = raw['all'];
    final group = Map<String, dynamic>.from(raw);
    group['all'] = memberNames is List
        ? memberNames.map((name) => proxies[name]).nonNulls.toList()
        : const [];
    groups.add(Group.fromJson(group));
  }
  return computeSort(
    groups: groups,
    sortType: sortType,
    delayMap: delayMap,
    selectedMap: selectedMap,
    defaultTestUrl: defaultTestUrl,
  );
}

Future<ClashConfig> clashConfigTask(Map<String, dynamic> data) async {
  return compute<Map<String, dynamic>, ClashConfig>(_buildClashConfig, data);
}

ClashConfig _buildClashConfig(Map<String, dynamic> configMap) {
  return ClashConfig.fromJson(configMap);
}

typedef ConfigCounts = ({int groups, int proxies, int rules});

typedef RealProfile = ({
  String yaml,
  String md5,
  ConfigCounts counts,
  List<RuleSource> ruleSources,
});

/// Counts what the Core was handed, not what the profile file declares.
ConfigCounts configCountsOf(Map<Object?, Object?> config) {
  int lengthOf(Object? value) => value is List ? value.length : 0;
  return (
    groups: lengthOf(config['proxy-groups']),
    proxies: lengthOf(config['proxies']),
    rules: lengthOf(config['rules']),
  );
}

/// Which rules an extension script wrote, read by count: a line the script
/// left as many times as the profile had it stays the profile's, every other
/// one is the script's. A rule the script moved reads as the profile's.
List<RuleSource> scriptRuleSources(
  Object? before,
  Object? after, {
  required String script,
}) {
  final remaining = <String, int>{};
  if (before is List) {
    for (final rule in before) {
      remaining.update('$rule', (count) => count + 1, ifAbsent: () => 1);
    }
  }
  if (after is! List) return const [];
  final sources = <RuleSource>[];
  for (final rule in after.map((rule) => '$rule')) {
    final left = remaining[rule] ?? 0;
    if (left > 0) {
      remaining[rule] = left - 1;
      sources.add(RuleSource(kind: RuleSourceKind.subscription, text: rule));
    } else {
      sources.add(
        RuleSource(kind: RuleSourceKind.script, name: script, text: rule),
      );
    }
  }
  return sources;
}

String? lastMatchTarget(List<String> rules) =>
    matchTargetOf(rules.map(Rule.parse));

String? matchTargetOf(Iterable<Rule> rules) {
  for (final rule in rules.toList().reversed) {
    if (rule.ruleAction == RuleAction.MATCH) {
      final target = rule.ruleTarget;
      if (target != null && target.isNotEmpty) {
        return target;
      }
    }
  }
  return null;
}

Set<String> outboundNamesOf(Map<dynamic, dynamic> config) => {
  for (final key in const ['proxies', 'proxy-groups'])
    if (config[key] case final List<dynamic> items)
      for (final item in items)
        if (item case {'name': final String name}) name,
};

/// mihomo sends DIRECT what no rule matches, MATCH included.
String Function(String exit) exitTargetResolver({
  required Map<String, String> targets,
  required Set<String> outbounds,
  required String? fallback,
}) {
  bool usable(String? target) =>
      target != null &&
      (RuleTarget.ruleTargets.contains(target) || outbounds.contains(target));
  return (exit) {
    final mapped = targets[exit];
    if (usable(mapped)) {
      return mapped!;
    }
    if (outbounds.contains(exit)) {
      return exit;
    }
    return fallback ?? RuleTarget.DIRECT.value;
  };
}

Map<String, dynamic> inboundConfigOf(
  PatchClashConfig config, {
  required List<String> authentication,
}) => {
  'mixed-port': config.mixedPort,
  'port': config.port,
  'socks-port': config.socksPort,
  'redir-port': config.redirPort,
  'tproxy-port': config.tproxyPort,
  'allow-lan': config.allowLan,
  // A profile's skip-auth-prefixes could exempt loopback from authentication.
  'authentication': authentication,
  'skip-auth-prefixes': const <String>[],
};

/// Puts [sets] among the config's rule providers, each at its file under
/// the profile's own providers, where neither a subscription update nor a
/// restart moves it. A name the config already takes leaves the config's
/// set alone and renames the added one; the renames are returned, old name
/// to new, for the rules that use them.
Map<String, String> injectAddedRuleSets(
  Map rawConfig,
  List<AddedRuleSet> sets, {
  required String profilesPath,
  required int profileId,
}) {
  if (sets.isEmpty) return const {};
  final existing = rawConfig['rule-providers'];
  final providers = <String, dynamic>{
    if (existing is Map) ...existing.cast<String, dynamic>(),
  };
  final taken = providers.keys.toSet();
  final renames = <String, String>{};
  final added = <String, dynamic>{};
  for (final set in sets) {
    // Only a web address downloads; anything else could reach outside.
    final scheme = Uri.tryParse(set.url)?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') continue;
    var key = set.name;
    if (taken.contains(key)) {
      key = '$addedRuleSetPrefix${set.name}';
      for (var n = 2; taken.contains(key); n++) {
        key = '$addedRuleSetPrefix${set.name}-$n';
      }
      renames[set.name] = key;
    }
    taken.add(key);
    added[key] = set.definition(set.pathUnder(profilesPath));
  }
  rawConfig['rule-providers'] = {...added, ...providers};
  return renames;
}

Future<RealProfile> makeRealProfileTask(MakeRealProfileState data) async {
  return compute<MakeRealProfileState, RealProfile>(
    _makeRealProfileTask,
    realProfileInput(data),
  );
}

/// What crosses into the isolate: never the CA's p12.
@visibleForTesting
MakeRealProfileState realProfileInput(MakeRealProfileState data) =>
    data.copyWith.realPatchConfig(
      mitm: data.realPatchConfig.mitm.withoutCaSecrets,
    );

Future<RealProfile> _makeRealProfileTask(MakeRealProfileState data) async {
  final rawConfig = Map.from(data.rawConfig);
  final realPatchConfig = data.realPatchConfig;
  final profilesPath = data.profilesPath;
  final profileId = data.profileId;
  final overrides = data.overrides;
  final appendSystemDns = data.appendSystemDns;
  String getProvidersFilePathInner(String type, String key) {
    return join(
      profilesPath,
      providersDirectoryName,
      profileId.toString(),
      type,
      key.toMd5(),
    );
  }

  void confineProviders(String section, String type) {
    final providers = rawConfig[section];
    if (providers is! Map) {
      return;
    }
    for (final name in providers.keys) {
      final provider = providers[name];
      if (provider is! Map || provider['type'] == 'inline') {
        continue;
      }
      // Two providers may share a URL and differ only by header.
      final url = provider['url'];
      final hasUrl = url is String && url.isNotEmpty;
      final path = getProvidersFilePathInner(
        type,
        hasUrl ? '$name@$url' : '$section/$name',
      );
      if (hasUrl) {
        _migrateLegacyProviderFile(
          legacyPath: getProvidersFilePathInner(type, url),
          newPath: path,
        );
      }
      provider['path'] = path;
    }
  }

  applyPageSettings(rawConfig, data);
  final snifferOverride = overrides.sniffer.overrideJson(
    overrides.snifferOverrideKeys,
  );
  if (snifferOverride.isNotEmpty) {
    rawConfig['sniffer'] = mergeSnifferOverride(
      rawConfig['sniffer'] is Map
          ? Map<String, dynamic>.from(rawConfig['sniffer'] as Map)
          : <String, dynamic>{},
      snifferOverride,
    );
  }
  if (rawConfig['sniffer']?['sniff'] != null) {
    for (final value in (rawConfig['sniffer']?['sniff'] as Map).values) {
      if (value['ports'] != null && value['ports'] is List) {
        value['ports'] =
            value['ports']?.map((item) => item.toString()).toList() ?? [];
      }
    }
  }
  void injectUnconfinedProviders(
    String section,
    Map<String, dynamic> injected,
  ) {
    if (injected.isEmpty) {
      return;
    }
    final providers = rawConfig[section];
    rawConfig[section] = {
      ...injected,
      if (providers is Map) ...providers.cast<String, dynamic>(),
    };
  }

  final moduleContents = [
    for (final source in data.mitmModules)
      (
        source: source,
        content: parseMitmModule(
          source.content,
          values: source.arguments,
          resources: source.resources,
        ),
      ),
  ];
  final moduleProviderNames = <int, Map<String, String>>{};
  final attachedRuleSets = <String, Map<String, Object?>>{};
  final providers = <String, dynamic>{
    if (rawConfig['rule-providers'] case final Map existing)
      ...existing.cast<String, dynamic>(),
  };
  for (final (index, module) in moduleContents.indexed) {
    final names = moduleProviderNames[index] = <String, String>{};
    for (final entry in flashModuleProviders(
      module.content,
      module.source.resources,
    ).entries) {
      var name = 'mitm-${module.source.id ?? index}-${entry.key}';
      while (providers.containsKey(name) ||
          data.injectedRuleProviders.containsKey(name) ||
          attachedRuleSets.containsKey(name)) {
        name = '$name-';
      }
      names[entry.key] = name;
      if (entry.value['type'] == 'file') {
        attachedRuleSets[name] = entry.value;
      } else {
        providers[name] = entry.value;
      }
    }
  }
  rawConfig['rule-providers'] = providers;
  confineProviders('proxy-providers', proxiesProviderDirectoryName);
  confineProviders('rule-providers', rulesProviderDirectoryName);
  injectUnconfinedProviders('proxy-providers', data.injectedProxyProviders);
  injectUnconfinedProviders('rule-providers', {
    ...data.injectedRuleProviders,
    ...attachedRuleSets,
  });
  final addedSetNames = injectAddedRuleSets(
    rawConfig,
    data.addedRuleSets,
    profilesPath: profilesPath,
    profileId: profileId,
  );
  const systemDns = 'system://';
  final dns = mergeDnsOverride(
    rawConfig['dns'] is Map
        ? Map<String, dynamic>.from(rawConfig['dns'] as Map)
        : <String, dynamic>{},
    overrides.dns.overrideJson(overrides.dnsOverrideKeys),
  );
  if (dns.isNotEmpty || rawConfig.containsKey('dns')) {
    rawConfig['dns'] = dns;
  }
  final pageDns = mergeDnsOverride(
    rawConfig['dns'] is Map
        ? Map<String, dynamic>.from(rawConfig['dns'] as Map)
        : <String, dynamic>{},
    realPatchConfig.dns.overrideJson(DnsOverrideKey.normalProfileKeys),
  );
  rawConfig['dns'] = pageDns;
  final ntpOverride = overrides.ntp.overrideJson(overrides.ntpOverrideKeys);
  if (ntpOverride.isNotEmpty) {
    final rawNtp = rawConfig['ntp'] is Map
        ? Map<String, dynamic>.from(rawConfig['ntp'] as Map)
        : <String, dynamic>{};
    rawConfig['ntp'] = {...rawNtp, ...ntpOverride};
  }
  if (appendSystemDns || data.safeMode) {
    rawConfig['dns'] ??= <String, dynamic>{};
  }
  if (appendSystemDns) {
    final List<String> nameserver = List<String>.from(
      rawConfig['dns']['nameserver'] ?? [],
    );
    if (!nameserver.contains(systemDns)) {
      rawConfig['dns']['nameserver'] = [...nameserver, systemDns];
    }
  }
  if (data.safeMode) {
    rawConfig['listeners'] = [];
    rawConfig['tunnels'] = [];
    rawConfig['ss-config'] = '';
    rawConfig['vmess-config'] = '';
    rawConfig['tuic-server'] = {'enable': false};
    rawConfig['iptables'] = {'enable': false};
    rawConfig['dns']['listen'] = '';
    final rawNtp = rawConfig['ntp'];
    if (rawNtp is Map) {
      rawConfig['ntp'] = {
        ...Map<String, dynamic>.from(rawNtp),
        NtpOverrideKey.writeToSystem.path: false,
      };
    }
  }
  final effectiveDns = rawConfig['dns'] as Map;
  final effectiveNameservers = effectiveDns['nameserver'];
  if (!data.safeMode &&
      effectiveDns['enable'] == true &&
      (effectiveNameservers is! List || effectiveNameservers.isEmpty)) {
    throw const ConfigBuildException(ConfigBuildIssue.nameserverEmpty);
  }
  if (_proxyServerPolicyUnmet(effectiveDns)) {
    throw const ConfigBuildException(
      ConfigBuildIssue.proxyServerNameserverEmpty,
    );
  }
  final ruleProviders = rawConfig['rule-providers'];
  for (final name in _fakeIpFilterRuleSets(effectiveDns)) {
    if (ruleProviders is! Map || !ruleProviders.containsKey(name)) {
      throw ConfigBuildException(
        ConfigBuildIssue.fakeIpFilterRuleSetMissing,
        detail: name,
      );
    }
  }
  // A colliding set is rewritten only through its stable paired rule id.
  // Older rows have no persistent association; refusing an ambiguous
  // collision preserves the previously running configuration and all rules.
  final paired = <int?, Map<String, String>>{};
  final allProfileRules = [...data.rules, ...data.addedRules];
  for (final set in data.addedRuleSets) {
    final replacement = addedSetNames[set.name];
    if (replacement == null) continue;
    final matches = allProfileRules.where(
      (rule) =>
          rule.id == set.id &&
          rule.ruleAction == RuleAction.RULE_SET &&
          rule.ruleProvider == set.name &&
          rule.profileId != null,
    );
    if (matches.length != 1) {
      throw StateError('Ambiguous added rule set collision: ${set.name}');
    }
    paired[set.id] = {set.name: replacement};
  }
  Rule ownRule(Rule rule) {
    final names = paired[rule.id];
    return names == null ? rule : rule.renamedRuleSets(names);
  }

  final addedRules = [for (final rule in data.addedRules) ownRule(rule)];
  final customRules = [for (final rule in data.rules) ownRule(rule)];
  List<String> rules = [];
  List<RuleSource> sources = [];
  // Where the module rules go: after the added rules, before the profile's.
  var moduleRulesAt = 0;
  if (customRules.isEmpty) {
    if (rawConfig['rules'] != null) {
      rules = List<String>.from(rawConfig['rules']);
    }
    sources = data.profileRuleSources.length == rules.length
        ? data.profileRuleSources
        : [
            for (final rule in rules)
              RuleSource(kind: RuleSourceKind.subscription, text: rule),
          ];
    if (addedRules.isNotEmpty) {
      final exitTarget = exitTargetResolver(
        targets: {
          if (data.matchTarget != null) 'MATCH': data.matchTarget!,
          ...data.exitTargets,
        },
        outbounds: data.outboundNames ?? outboundNamesOf(rawConfig),
        fallback: data.defaultExitTarget ?? lastMatchTarget(rules),
      );
      final finalAddedRules = [
        for (final rule in addedRules)
          ((rule.customExit || rule.ruleTarget == 'MATCH') &&
                      rule.ruleTarget != null
                  ? rule.copyWith(ruleTarget: exitTarget(rule.ruleTarget!))
                  : rule)
              .rawValue,
      ];
      rules = [...finalAddedRules, ...rules];
      moduleRulesAt = finalAddedRules.length;
      sources = [
        for (final (index, rule) in finalAddedRules.indexed)
          RuleSource(
            kind: addedRules[index].profileId == null
                ? RuleSourceKind.addedGlobal
                : RuleSourceKind.addedProfile,
            text: rule,
            ruleId: addedRules[index].id,
          ),
        ...sources,
      ];
    }
  } else {
    rules = customRules.map((item) => item.rawValue).toList();
    sources = [
      for (final (index, rule) in rules.indexed)
        RuleSource(
          kind: RuleSourceKind.custom,
          text: rule,
          ruleId: customRules[index].id,
        ),
    ];
  }
  if (data.proxyGroups.isNotEmpty) {
    rawConfig['proxy-groups'] = data.proxyGroups
        .map((item) => item.definition)
        .toList();
  }
  final policies = {...mitmConfigPolicies(rawConfig), ...?data.outboundNames};
  final moduleSources = [
    for (final (index, entry) in moduleContents.indexed)
      for (final rule in flashModuleRules(
        entry.content,
        policies: policies,
        exits: {
          if (data.matchTarget != null) 'MATCH': data.matchTarget!,
          ...data.exitTargets,
        },
        providerNames: moduleProviderNames[index] ?? const {},
      ))
        RuleSource(
          kind: RuleSourceKind.mitm,
          name: entry.source.name,
          text: rule,
          moduleId: entry.source.id,
        ),
  ];
  if (moduleSources.isNotEmpty) {
    rules.insertAll(moduleRulesAt, [
      for (final source in moduleSources) source.text,
    ]);
    sources = [...sources]..insertAll(moduleRulesAt, moduleSources);
  }
  rawConfig['rules'] = rules;
  final yaml = await _encodeYaml(Map<String, dynamic>.from(rawConfig));
  return (
    yaml: yaml,
    md5: yaml.toMd5(),
    counts: configCountsOf(rawConfig),
    ruleSources: sources,
  );
}

/// Writes each field a page control owns, and only that field; every other
/// key stays as the file wrote it, and one it leaves out takes the Core's
/// default.
@visibleForTesting
void applyPageSettings(Map rawConfig, MakeRealProfileState data) {
  final page = data.realPatchConfig;
  final overrides = data.overrides;
  void put(PageConfigKey key, Object? value) {
    rawConfig[key.path] = value;
  }

  if (data.safeMode) {
    rawConfig['external-controller'] = '';
    rawConfig['secret'] = page.secret;
  } else {
    if (page.externalController != ExternalControllerStatus.close &&
        page.secret.isEmpty) {
      throw StateError('External controller requires authentication');
    }
    rawConfig['external-controller'] = page.externalController.value;
    rawConfig['secret'] = page.secret;
  }
  for (final key in [
    'external-controller-tls',
    'external-controller-unix',
    'external-controller-pipe',
  ]) {
    if (data.safeMode) {
      rawConfig[key] = '';
    } else if (rawConfig[key] case final String endpoint
        when endpoint.isNotEmpty) {
      throw StateError('$key is not supported');
    }
  }
  final iptables = rawConfig['iptables'];
  if (!data.safeMode && iptables is Map && iptables['enable'] == true) {
    final inboundInterface = iptables['inbound-interface'];
    if (inboundInterface is String && inboundInterface.contains(' ')) {
      throw StateError('iptables.inbound-interface must not contain spaces');
    }
  }
  switch (page.interfaceNameMode) {
    case InterfaceNameMode.clear:
      rawConfig['interface-name'] = '';
    case InterfaceNameMode.follow:
      break;
    case InterfaceNameMode.custom:
      rawConfig['interface-name'] = page.interfaceName;
  }
  rawConfig.addAll(page.generalOverrideJson);
  put(PageConfigKey.logLevel, page.logLevel.name);
  put(PageConfigKey.mixedPort, page.mixedPort);
  put(PageConfigKey.port, page.port);
  put(PageConfigKey.socksPort, page.socksPort);
  put(PageConfigKey.redirPort, page.redirPort);
  put(PageConfigKey.tproxyPort, page.tproxyPort);
  put(PageConfigKey.keepAliveInterval, page.keepAliveInterval);
  put(PageConfigKey.keepAliveIdle, page.keepAliveIdle);
  put(PageConfigKey.disableKeepAlive, page.disableKeepAlive);
  if (Platform.isLinux) {
    rawConfig['routing-mark'] = page.routingMark;
  }
  put(PageConfigKey.findProcessMode, page.findProcessMode.name);
  put(PageConfigKey.allowLan, page.allowLan);
  put(PageConfigKey.authentication, data.authentication);
  put(PageConfigKey.mode, page.mode.name);
  final tun = {
    if (rawConfig['tun'] is Map) ...rawConfig['tun'] as Map,
    ...overrides.tun.overrideJson(overrides.tunOverrideKeys),
    ...page.tunOverride.overrideJson({
      TunOverrideKey.mtu,
      TunOverrideKey.congestionController,
      TunOverrideKey.routeAddress,
      TunOverrideKey.routeExcludeAddress,
      TunOverrideKey.dnsHijack,
      TunOverrideKey.udpTimeout,
      TunOverrideKey.disableIcmpForwarding,
      if (Platform.isLinux || Platform.isWindows) TunOverrideKey.strictRoute,
      if (Platform.isLinux) ...{
        TunOverrideKey.gso,
        TunOverrideKey.includeInterface,
        TunOverrideKey.excludeInterface,
        TunOverrideKey.includeUid,
        TunOverrideKey.excludeUid,
        TunOverrideKey.excludeSrcPort,
        TunOverrideKey.excludeDstPort,
      },
    }),
    'enable': page.tun.enable,
    'stack': page.tun.stack.name,
  };
  if (data.safeMode) {
    tun['enable'] = false;
  }
  if (data.bypassPrivateRoute) {
    tun['route-exclude-address'] = [
      if (tun['route-exclude-address'] case final List routes) ...routes,
      ...privateRouteAddress,
    ];
  }
  // sing-tun points the system resolver at the TUN with auto-route everywhere
  // but macOS, where native does it; a profile's own dns-mode still wins.
  if (data.defaultTunDnsMode case final mode?
      when tun['dns-mode'] == null || tun['dns-mode'] == '') {
    tun['dns-mode'] = mode;
  }
  if (tun.isNotEmpty) {
    rawConfig['tun'] = tun;
  }
  put(PageConfigKey.geoAutoUpdate, page.geoAutoUpdate);
  put(PageConfigKey.geoUpdateInterval, page.geoUpdateInterval);
  rawConfig['geox-url'] = {
    if (rawConfig['geox-url'] is Map) ...rawConfig['geox-url'] as Map,
    ...page.geoXUrl.raw,
  };
  put(PageConfigKey.globalUa, page.globalUa ?? data.defaultUA);
  rawConfig['hosts'] = {
    for (final MapEntry(:key, :value) in page.hosts.entries)
      key: value.splitByMultipleSeparators,
  };
}

// config.go parseDNS, whatever dns.enable says.
bool _proxyServerPolicyUnmet(Map dns) {
  final policy = dns['proxy-server-nameserver-policy'];
  final servers = dns['proxy-server-nameserver'];
  return policy is Map &&
      policy.isNotEmpty &&
      (servers == null ||
          servers == '' ||
          (servers is List && servers.isEmpty));
}

// The rule sets config.go parseFakeIPRules and parseDomain look up.
Iterable<String> _fakeIpFilterRuleSets(Map dns) sync* {
  final filter = dns['fake-ip-filter'];
  if (dns['enhanced-mode'] != 'fake-ip' || filter is! List) return;
  final rules = dns['fake-ip-filter-mode'] == 'rule';
  for (final entry in filter.whereType<String>()) {
    final item = entry.split(',').map((part) => part.trim()).toList();
    if (rules) {
      if (item.length > 1 && item.first.toUpperCase() == 'RULE-SET') {
        yield item[1];
      }
    } else if (entry.toLowerCase().startsWith('rule-set:')) {
      yield* entry.split(':')[1].split(',');
    }
  }
}

typedef ShakingStoreArgs = ({
  Iterable<int> profileIds,
  Iterable<int> scriptIds,
  Iterable<String> providerFileNames,
});

Future<List<String>> shakingProfileTask(ShakingStoreArgs data) async {
  return compute<
    ({ShakingStoreArgs args, RootIsolateToken token}),
    List<String>
  >(_shakingProfileTask, (args: data, token: RootIsolateToken.instance!));
}

Future<List<String>> _shakingProfileTask(
  ({ShakingStoreArgs args, RootIsolateToken token}) data,
) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(data.token);
  return shakeOrphanFiles(
    profileIds: data.args.profileIds,
    scriptIds: data.args.scriptIds,
    providerFileNames: data.args.providerFileNames,
    profilesDirPath: await appPath.profilesPath,
    providersDirPath: await appPath.getProvidersRootPath(),
    providerCacheDirPath: await appPath.providerCacheRootPath,
    scriptsDirPath: await appPath.scriptsDirPath,
  );
}

@visibleForTesting
List<String> shakeOrphanFiles({
  required Iterable<int> profileIds,
  required Iterable<int> scriptIds,
  required Iterable<String> providerFileNames,
  required String profilesDirPath,
  required String providersDirPath,
  required String providerCacheDirPath,
  required String scriptsDirPath,
}) {
  final List<String> targets = [];
  void scanDirectory(
    Directory dir,
    bool Function(String baseName) isLive, {
    bool includeDirectories = false,
  }) {
    if (!dir.existsSync()) return;
    final entities = dir.listSync(recursive: false, followLinks: false);

    for (final entity in entities) {
      final selected =
          entity is File || (includeDirectories && entity is Directory);
      if (!selected) {
        continue;
      }
      if (!isLive(basenameWithoutExtension(entity.path))) {
        targets.add(entity.path);
      }
    }
  }

  bool Function(String) isLiveId(Iterable<int> ids) =>
      (baseName) => ids.contains(int.tryParse(baseName));

  scanDirectory(Directory(profilesDirPath), isLiveId(profileIds));
  scanDirectory(
    Directory(providersDirPath),
    isLiveId(profileIds),
    includeDirectories: true,
  );
  scanDirectory(
    Directory(join(providerCacheDirPath, rulesProviderDirectoryName)),
    providerFileNames.toSet().contains,
  );
  scanDirectory(Directory(scriptsDirPath), isLiveId(scriptIds));
  return targets;
}

// Best-effort: a legacy url shared by two providers, or any rename failure,
// just leaves the file to be re-downloaded under the new path.
void _migrateLegacyProviderFile({
  required String legacyPath,
  required String newPath,
}) {
  if (legacyPath == newPath || File(newPath).existsSync()) {
    return;
  }
  try {
    final legacyFile = File(legacyPath);
    if (legacyFile.existsSync()) {
      Directory(dirname(newPath)).createSync(recursive: true);
      legacyFile.renameSync(newPath);
    }
  } catch (_) {}
}

Future<String> encodeLogsTask(List<Log> data) async {
  return compute<List<Log>, String>(_encodeLogsTask, data);
}

Future<String> _encodeLogsTask(List<Log> data) async {
  final logsRaw = data.map((item) => item.toString());
  final logsRawString = logsRaw.join('\n');
  return logsRawString;
}

Future<MigrationData> oldToNowTask(Map<String, Object?> data) async {
  final homeDir = await appPath.homeDirPath;
  return compute<
    ({Map<String, Object?> configMap, String sourcePath, String targetPath}),
    MigrationData
  >(_oldToNowTask, (configMap: data, sourcePath: homeDir, targetPath: homeDir));
}

Future<MigrationData> _oldToNowTask(
  ({Map<String, Object?> configMap, String sourcePath, String targetPath}) data,
) {
  return migrateLegacyConfig(
    configMap: data.configMap,
    sourcePath: data.sourcePath,
    targetPath: data.targetPath,
  );
}

Future<MigrationData> migrateLegacyConfig({
  required Map<String, Object?> configMap,
  required String sourcePath,
  required String targetPath,
}) async {
  final accessControlMap = configMap['accessControl'];
  final isAccessControl = configMap['isAccessControl'];
  if (accessControlMap != null) {
    (accessControlMap as Map)['enable'] = isAccessControl;
    if (configMap['vpnProps'] != null) {
      final vpnPropsRaw = configMap['vpnProps'] as Map;
      vpnPropsRaw['accessControl'] = accessControlMap;
    }
  }
  if (configMap['vpnProps'] != null) {
    final vpnPropsRaw = configMap['vpnProps'] as Map;
    vpnPropsRaw['accessControlProps'] = vpnPropsRaw['accessControl'];
  }
  configMap['davProps'] = configMap['dav'];
  final appSettingProps =
      configMap['appSetting'] as Map<String, dynamic>? ?? {};
  appSettingProps['restoreStrategy'] = appSettingProps['recoveryStrategy'];
  configMap['appSettingProps'] = appSettingProps;
  configMap['proxiesStyleProps'] = configMap['proxiesStyle'];
  List rawScripts = configMap['scripts'] as List<dynamic>? ?? [];
  if (rawScripts.isEmpty) {
    final scriptPropsJson = configMap['scriptProps'] as Map<String, dynamic>?;
    if (scriptPropsJson != null) {
      rawScripts = scriptPropsJson['scripts'] as List<dynamic>? ?? [];
    }
  }
  final Map<String, int> idMap = {};
  final List<Script> scripts = [];
  for (final rawScript in rawScripts) {
    final id = rawScript['id'] as String?;
    final content = rawScript['content'] as String?;
    final label = rawScript['label'] as String?;
    if (id == null || content == null || label == null) {
      continue;
    }
    final newId = idMap.updateCacheValue(rawScript['id'], () => snowflake.id);
    final path = BackupEntries.resolve(targetPath, BackupEntries.script(newId));
    final file = File(path);
    await file.safeWriteAsString(content);
    scripts.add(
      Script(id: newId, label: label, lastUpdateTime: DateTime.now()),
    );
  }
  final List rawRules = configMap['rules'] as List<dynamic>? ?? [];
  final List<Rule> rules = [];
  final List<DisabledRule> disabledRules = [];
  for (final rawRule in rawRules) {
    final id = idMap.updateCacheValue(rawRule['id'], () => snowflake.id);
    rawRule['id'] = id;
    final value = rawRule['value'] ?? '';
    rules.add(Rule.parse(value, id: id));
  }
  final globalRuleIds = [for (final rule in rules) rule.id];
  final List rawProfiles = configMap['profiles'] as List<dynamic>? ?? [];
  final List<Profile> profiles = [];
  for (final rawProfile in rawProfiles) {
    final rawId = rawProfile['id'] as String?;
    if (rawId == null) {
      continue;
    }
    final profileId = idMap.updateCacheValue(rawId, () => snowflake.id);
    rawProfile['id'] = profileId;
    final overwrite = rawProfile['overwrite'] as Map?;
    if (overwrite != null) {
      final isScript = overwrite['type'] == 'script';
      final standardOverwrite = overwrite['standardOverwrite'] as Map?;
      if (standardOverwrite != null) {
        final addedRules = standardOverwrite['addedRules'] as List? ?? [];
        for (final addRule in addedRules) {
          final id = idMap.updateCacheValue(addRule['id'], () => snowflake.id);
          final value = addRule['value'] ?? '';
          rules.add(Rule.parse(value, id: id).copyWith(profileId: profileId));
        }
        final disabledRuleIds = standardOverwrite['disabledRuleIds'] as List?;
        if (disabledRuleIds != null && !isScript) {
          for (final disabledRuleId in disabledRuleIds) {
            final newDisabledRuleId = idMap[disabledRuleId];
            if (newDisabledRuleId != null) {
              disabledRules.add(
                DisabledRule(profileId: profileId, ruleId: newDisabledRuleId),
              );
            }
          }
        }
      }
      // A script profile used to skip the global rules it now runs with.
      if (isScript) {
        for (final ruleId in globalRuleIds) {
          disabledRules.add(DisabledRule(profileId: profileId, ruleId: ruleId));
        }
        final scriptId =
            (overwrite['scriptOverwrite'] as Map?)?['scriptId'] as String?;
        if (scriptId != null) {
          rawProfile['scriptId'] = idMap[scriptId];
        }
      }
    }
    final rawUrl = rawProfile['url'];
    rawProfile['type'] = rawUrl is String && rawUrl.isNotEmpty ? 'url' : 'file';

    final sourceFile = File(
      BackupEntries.resolve(sourcePath, BackupEntries.profile(rawId)),
    );
    final targetFilePath = BackupEntries.resolve(
      targetPath,
      BackupEntries.profile(profileId),
    );
    await sourceFile.safeCopy(targetFilePath);
    profiles.add(Profile.fromJson(rawProfile));
  }
  final currentProfileId = configMap['currentProfileId'];
  configMap['currentProfileId'] = currentProfileId != null
      ? idMap[currentProfileId]
      : null;
  return MigrationData(
    configMap: configMap,
    profiles: profiles,
    rules: rules,
    scripts: scripts,
    disabledRules: disabledRules,
  );
}
