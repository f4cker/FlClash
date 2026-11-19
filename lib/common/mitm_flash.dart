import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:path/path.dart' as p;

const flashMitmUnsupported = 'Not supported by the Flash Go engine';

Map<MitmList, Map<String, String>> flashMitmIssues(
  MitmModuleContent content,
) => {
  if (content.clientSourceAddress.isNotEmpty)
    MitmList.clientSourceAddress: {
      for (final line in content.clientSourceAddress)
        line: flashMitmUnsupported,
    },
  if (content.skipVerifyHostname.isNotEmpty)
    MitmList.skipVerifyHostname: {
      for (final line in content.skipVerifyHostname) line: flashMitmUnsupported,
    },
  if (content.requestBodyMock.isNotEmpty)
    MitmList.requestBodyMock: {
      for (final line in content.requestBodyMock) line: flashMitmUnsupported,
    },
  MitmList.bodyRewrite: {
    for (final line in content.bodyRewrite)
      if (_unsupportedBody(line)) line: flashMitmUnsupported,
  },
  MitmList.script: {
    for (final line in content.script)
      if (parseMitmScriptInfo(line) == null) line: flashMitmUnsupported,
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

bool _unsupportedBody(String line) =>
    line.startsWith('http-request-jq ') || line.startsWith('http-response-jq ');

MitmRules flashMitmRules(MitmModuleContent content) {
  // Ignoring a client restriction would broaden the module's authority.
  if (content.clientSourceAddress.isNotEmpty ||
      content.requirementMet == false) {
    return const MitmRules();
  }
  return MitmRules(
    hostname: [...content.insertedHostname, ...content.hostname],
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
