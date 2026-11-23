import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/l10n/l10n.dart';
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

final _ipv4Part = RegExp(r'^(0|[1-9][0-9]{0,2})$');
final _dnsLabel = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');
final _port = RegExp(r'^[0-9]{1,5}$');

/// Why a hostname line is not decrypted, as far as it is known.
enum MitmHostReason {
  appleService,
  overBroad,
  invalidFormat,
  unsupportedPort,
  ipAddress,
  embeddedWildcard,
  unknown;

  /// From the Core's issue code (core/mitm_host.go). Its `address` covers
  /// both an address and a port, so it says no more than that it is skipped.
  static MitmHostReason ofCore(String code) => switch (code) {
    'apple-service' => appleService,
    'over-broad' => overBroad,
    'invalid' => invalidFormat,
    _ => unknown,
  };
}

String mitmHostReasonText(AppLocalizations l, MitmHostReason reason) =>
    switch (reason) {
      MitmHostReason.appleService => l.mitmHostReasonAppleService,
      MitmHostReason.overBroad => l.mitmHostReasonOverBroad,
      MitmHostReason.invalidFormat => l.mitmHostReasonInvalidFormat,
      MitmHostReason.unsupportedPort => l.mitmHostReasonUnsupportedPort,
      MitmHostReason.ipAddress => l.mitmHostReasonIpAddress,
      MitmHostReason.embeddedWildcard => l.mitmHostReasonEmbeddedWildcard,
      MitmHostReason.unknown => l.mitmHostReasonUnknown,
    };

/// What a skipped hostname line shows: ignored, and why. The app's own
/// reading of [line] (as the Core is sent it) comes first; [coreCode], the
/// Core's, tells what only the Core knows, too broad or Apple's.
String mitmHostIssueText(AppLocalizations l, String line, String? coreCode) {
  final reason =
      flashHostReason(line) ??
      (coreCode == null ? null : MitmHostReason.ofCore(coreCode)) ??
      MitmHostReason.unknown;
  return l.mitmHostIgnored(mitmHostReasonText(l, reason));
}

/// The module's hostname lines the Core skips as written: another port, an
/// address, or not a name it can read, such as one with a `*` or `?` inside;
/// the Core matches `*` only as a leading `*.`. Too broad and Apple-owned
/// names the Core also skips are told by the Core itself.
List<String> flashUnusableHostnames(MitmModuleContent content) =>
    flashUnusableHostLines(flashHostnameLines(content));

List<String> flashUnusableHostLines(List<String> lines) => [
  for (final line in lines)
    if (flashHostReason(flashMitmHostname(line)) case final reason?
        when reason != MitmHostReason.overBroad)
      line,
];

/// The module's hostname lines as written, in the order the Core is sent
/// them.
List<String> flashHostnameLines(MitmModuleContent content) => [
  ...content.insertedHostname,
  ...content.hostname,
];

String _normalizeHost(String host) {
  final text = host.trim().toLowerCase();
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}

bool _isIPv4(String text) {
  final parts = text.split('.');
  return parts.length == 4 &&
      parts.every((part) => _ipv4Part.hasMatch(part) && int.parse(part) <= 255);
}

bool _isIP(String text) {
  if (_isIPv4(text)) return true;
  if (!text.contains(':')) return false;
  // An IPv6 zone (fe80::1%en0) is still an address, as Go's netip reads it.
  // With the zone left empty netip refuses it, but the Core still skips it
  // as an address (core/mitm_host.go looksLikeAddress: it has a `:`).
  final zone = text.indexOf('%');
  final address = zone < 0 ? text : text.substring(0, zone);
  try {
    Uri.parseIPv6Address(address);
    return true;
  } on FormatException {
    return false;
  }
}

/// `*` other than as a leading `*.` label, in a name that is otherwise one.
bool _embeddedWildcard(String host) {
  if (host.startsWith('*') && !host.startsWith('*.')) return false;
  final name = host.startsWith('*.') ? host.substring(2) : host;
  return name.contains('*') && _validDNSName(name.replaceAll('*', 'a'));
}

/// Why the Core skips [line] (as it is sent it), from the syntax alone, as
/// core/mitm_host.go's parseMitmHostEntry reads it; null for a name whose
/// syntax holds, which only the Core can still find too broad or Apple's.
MitmHostReason? flashHostReason(String line) {
  var host = _normalizeHost(line);
  final exclude = host.startsWith('-');
  if (exclude) host = _normalizeHost(host.substring(1));
  if (host == '*' || host == '*.') {
    return exclude ? MitmHostReason.invalidFormat : MitmHostReason.overBroad;
  }
  final bare = host.replaceAll(RegExp(r'^\[+|\]+$'), '');
  if (_isIP(bare)) return MitmHostReason.ipAddress;
  if (host.contains(':')) {
    final at = host.lastIndexOf(':');
    final name = host.substring(0, at);
    if (_port.hasMatch(host.substring(at + 1))) {
      if (_isIP(name.replaceAll(RegExp(r'^\[+|\]+$'), ''))) {
        return MitmHostReason.ipAddress;
      }
      final base = name.startsWith('*.') ? name.substring(2) : name;
      if (_validDNSName(base)) return MitmHostReason.unsupportedPort;
    }
    return MitmHostReason.invalidFormat;
  }
  if (_embeddedWildcard(host)) return MitmHostReason.embeddedWildcard;
  final base = host.startsWith('*.') ? host.substring(2) : host;
  return _validDNSName(base) ? null : MitmHostReason.invalidFormat;
}

/// core/mitm_host.go's validDNSName: an all-digit last label is an address.
bool _validDNSName(String name) {
  if (name.isEmpty || name.length > 253) return false;
  final labels = name.split('.');
  return labels.every(_dnsLabel.hasMatch) &&
      labels.last.contains(RegExp('[a-z]'));
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
      for (final line in flashHostnameLines(content)) flashMitmHostname(line),
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

/// The hosts whose plain HTTP the Core rewrites and scripts in full; none
/// where [flashMitmRules] takes nothing from the module.
List<String> flashForceHttpEngineHosts(MitmModuleContent content) =>
    content.clientSourceAddress.isNotEmpty || content.requirementMet == false
    ? const []
    : content.forceHttpEngineHosts;

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
