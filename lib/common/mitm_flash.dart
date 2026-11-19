import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:path/path.dart' as p;

const _flashMitmUnsupported = 'Not supported by the Flash Go engine';

Map<MitmList, Map<String, String>> flashMitmIssues(
  MitmModuleContent content,
) => {
  if (content.clientSourceAddress.isNotEmpty)
    MitmList.clientSourceAddress: {
      for (final line in content.clientSourceAddress)
        line: _flashMitmUnsupported,
    },
  if (content.skipVerifyHostname.isNotEmpty)
    MitmList.skipVerifyHostname: {
      for (final line in content.skipVerifyHostname)
        line: _flashMitmUnsupported,
    },
  if (content.requestBodyMock.isNotEmpty)
    MitmList.requestBodyMock: {
      for (final line in content.requestBodyMock) line: _flashMitmUnsupported,
    },
  MitmList.bodyRewrite: {
    for (final line in content.bodyRewrite)
      if (_unsupportedBody(line)) line: _flashMitmUnsupported,
  },
  MitmList.script: {
    for (final line in content.script)
      if (parseMitmScriptInfo(line) == null) line: _flashMitmUnsupported,
  },
};

List<MitmModuleSkip> flashMitmSkipped(MitmModuleContent content) => [
  ...content.skipped,
  for (final change in content.network.changes)
    MitmModuleSkip('Network', change.key.name, MitmModuleSkipReason.setting),
  for (final entry in flashMitmIssues(content).entries)
    for (final line in entry.value.keys)
      MitmModuleSkip(entry.key.key, line, MitmModuleSkipReason.setting),
];

/// Flash decrypts on port 443 alone, the port a Surge hostname without one
/// means, so a `:443` adds nothing and is taken off. Nothing else is: a line
/// is never read as broader than it was written.
String flashMitmHostname(String line) {
  final trimmed = line.trim();
  if (!trimmed.endsWith(':443')) return trimmed;
  final host = trimmed.substring(0, trimmed.length - ':443'.length);
  // An IPv6 address keeps its colons; it is unusable either way.
  return host.contains(':') || host.endsWith(']') ? trimmed : host;
}

final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

/// The module's hostname lines the Core skips, as written: another port, an
/// address, or a `*` or `?` inside a name, which the Core matches only as a
/// leading `*.`. Too broad and Apple-owned names the Core also skips are told
/// by the Core itself.
List<String> flashUnusableHostnames(MitmModuleContent content) => [
  for (final line in [...content.insertedHostname, ...content.hostname])
    if (_unusableHostname(flashMitmHostname(line))) line,
];

bool _unusableHostname(String line) {
  var host = line.toLowerCase();
  if (host.startsWith('-')) host = host.substring(1).trim();
  if (host == '*' || host == '*.') return false;
  if (host.contains(':') || _ipv4.hasMatch(host)) return true;
  if (host.startsWith('*.')) host = host.substring(2);
  return host.contains('*') || host.contains('?');
}

bool _unsupportedBody(String line) =>
    line.startsWith('http-request-jq ') || line.startsWith('http-response-jq ');

MitmRules flashMitmRules(MitmModuleContent content) {
  // Ignoring a client restriction would broaden the module's authority.
  if (content.clientSourceAddress.isNotEmpty ||
      content.requirementMet == false) {
    return const MitmRules();
  }
  return MitmRules(
    hostname: [
      for (final line in [...content.insertedHostname, ...content.hostname])
        flashMitmHostname(line),
    ],
    urlRewrite: content.urlRewrite,
    headerRewrite: content.headerRewrite,
    bodyRewrite: content.bodyRewrite
        .where((line) => !_unsupportedBody(line))
        .toList(),
    mapLocal: content.mapLocal,
    script: mitmHttpScriptLines(content.script),
    h2: content.h2,
  );
}

List<String> flashModuleRules(
  MitmModuleContent content, {
  required Set<String> policies,
  required Map<String, String> exits,
  Map<String, String> providerNames = const {},
}) {
  if (content.clientSourceAddress.isNotEmpty ||
      content.requirementMet == false) {
    return const [];
  }
  final result = <String>[];
  for (var line in content.rules) {
    final target = mitmRulePolicy(line);
    if (content.exits.contains(target)) {
      final selected = exits[target];
      if (selected != null && policies.contains(selected)) {
        line = mitmRulesWithExits([line], {target}, (_) => selected).single;
      }
    }
    if (!mitmRuleUsable(line, policies)) continue;
    final type = line.split(',').first;
    if (!RuleAction.values.any((action) => action.value == type)) continue;
    if (type == 'RULE-SET') {
      final parts = line.split(',');
      if (parts.length < 3 || !providerNames.containsKey(parts[1])) continue;
      parts[1] = providerNames[parts[1]]!;
      line = parts.join(',');
    }
    result.add(line);
  }
  return result;
}

Map<String, Map<String, Object?>> flashModuleProviders(
  MitmModuleContent content,
  Map<String, String> resources,
) => {
  for (final MapEntry(:key, :value) in content.ruleProviders.entries)
    if (_safeProvider(value, resources)) key: value,
};

bool _safeProvider(Map<String, Object?> value, Map<String, String> resources) {
  if (value['format'] == 'domain-set') return false;
  return switch (value['type']) {
    'inline' => value['payload'] is List,
    'http' => const {
      'https',
      'http',
    }.contains(Uri.tryParse('${value['url']}')?.scheme),
    'file' => resources.values.any(
      (file) =>
          file.isNotEmpty &&
          p.basename(file) == file &&
          file != '.' &&
          file != '..' &&
          value['path'] == 'mitm/resources/$file',
    ),
    _ => false,
  };
}
