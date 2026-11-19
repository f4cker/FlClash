import 'dart:io';

import 'package:fl_clash/models/models.dart';
import 'package:intl/intl.dart' show NumberFormat;

final _grouped = NumberFormat.decimalPattern('en');

/// A count with its thousands grouped, as 1,862; the same in every locale
/// the app ships.
String groupedCount(int count) => _grouped.format(count);

final _domain = RegExp(
  r'^(?:[a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9_])?\.)+(?:[a-z]{2,63}|xn--[a-z0-9-]{1,59})$',
);

/// The host a search reads as when it is a URL, a full domain or an IP;
/// null when it is plain text to filter by. A pasted link gives its host.
String? lookupHostOf(String input) {
  var text = input.trim();
  if (text.isEmpty || text.contains(' ')) return null;
  if (text.contains('://') || text.contains('/')) {
    final uri = Uri.tryParse(text.contains('://') ? text : 'http://$text');
    final host = uri?.host ?? '';
    if (host.isEmpty) return null;
    text = host;
  }
  text = text.toLowerCase();
  if (text.startsWith('[') && text.contains(']')) {
    text = text.substring(1, text.indexOf(']'));
  }
  if (InternetAddress.tryParse(text) != null) return text;
  final colon = text.lastIndexOf(':');
  if (colon > 0 && int.tryParse(text.substring(colon + 1)) != null) {
    text = text.substring(0, colon);
    if (InternetAddress.tryParse(text) != null) return text;
  }
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return _domain.hasMatch(text) ? text : null;
}

bool isIpHost(String host) => InternetAddress.tryParse(host) != null;

// Second-level suffixes common enough that a registrable domain sits under
// them; anything else reads its last two labels as the registrable domain.
const _secondLevelSuffixes = {
  'ac', 'co', 'com', 'edu', 'gov', 'net', 'org', 'ne', 'or', 'go', 'gr', //
  'ltd', 'plc', 'nic', 'mil', 'gob', 'nom', 'sch',
};

/// The levels a rule could cover for [host], widest first: its registrable
/// domain, each level under it, and the host itself.
List<String> domainLevels(String host) {
  final labels = host.split('.');
  if (labels.length <= 2) return [host];
  var take = 2;
  if (labels.length >= 3 &&
      labels.last.length == 2 &&
      _secondLevelSuffixes.contains(labels[labels.length - 2])) {
    take = 3;
  }
  if (labels.length <= take) return [host];
  return [
    for (var count = take; count <= labels.length; count++)
      labels.sublist(labels.length - count).join('.'),
  ];
}

/// A rule the add dialog offers, as an added rule writes it.
typedef AddedRuleChoice = ({String type, String value, bool exact});

List<AddedRuleChoice> addedRuleChoices(String host) {
  if (isIpHost(host)) {
    return [(type: 'IP-CIDR', value: host, exact: true)];
  }
  final levels = domainLevels(host);
  return [
    for (final level in levels)
      (type: 'DOMAIN-SUFFIX', value: level, exact: false),
    (type: 'DOMAIN', value: host, exact: true),
  ];
}

String addedRuleText(AddedRuleChoice choice, String target) {
  if (choice.type == 'IP-CIDR') {
    final address = InternetAddress.tryParse(choice.value);
    final bits = address?.type == InternetAddressType.IPv6 ? 128 : 32;
    final cidr = address?.type == InternetAddressType.IPv6
        ? 'IP-CIDR6'
        : 'IP-CIDR';
    return '$cidr,${choice.value}/$bits,$target,no-resolve';
  }
  return '${choice.type},${choice.value},$target';
}

/// The type a rule line names, as the Core lists it.
String ruleTypeOf(String line) {
  final type = line.split(',').first.trim().toUpperCase();
  return switch (type) {
    'IP-CIDR6' => 'IP-CIDR',
    _ => type,
  };
}

/// Each listed rule's source, or null for every rule when the sources the
/// app recorded do not line up with what the Core runs: another length, a
/// rule of another type, another profile, or another Core epoch.
List<RuleSource?>? alignRuleSources({
  required RuleList list,
  required AppliedRuleSources applied,
  required int? profileId,
}) {
  final sources = applied.sources;
  if (applied.profileId != profileId || sources.isEmpty) return null;
  if (applied.epoch != null && applied.epoch != list.coreEpoch) return null;
  final offset = list.managedPrefix;
  if (list.total - offset != sources.length ||
      list.rules.length != list.total) {
    return null;
  }
  for (final (index, source) in sources.indexed) {
    if (source.text.isEmpty) continue;
    if (ruleTypeOf(source.text) != list.rules[index + offset].type) {
      return null;
    }
  }
  return [
    for (var index = 0; index < list.total; index++)
      index < offset ? null : sources[index - offset],
  ];
}

/// Whether a request's rule, as its record names it, is [rule].
bool sameRuleAsRecord(
  CoreRule rule, {
  required String recordRule,
  required String recordPayload,
}) {
  if (rule.ruleType.toLowerCase() != recordRule.toLowerCase()) return false;
  final payload = rule.rulePayload.isNotEmpty ? rule.rulePayload : rule.payload;
  return payload == recordPayload ||
      (rule.type == 'MATCH' && recordPayload.isEmpty);
}

/// How many whole days past its refresh interval a rule set is; zero while
/// fresh or when it never refreshes.
int ruleSetOverdueDays(RuleSetView set, DateTime now) {
  final loaded = set.loadedAt;
  if (loaded == null || set.interval <= 0) return 0;
  final due = loaded.add(Duration(seconds: set.interval));
  if (!now.isAfter(due)) return 0;
  return now.difference(due).inDays;
}

/// The source chips of the rules page; a managed rule falls under none.
enum RuleSourceFilter { all, subscription, ruleSet, added, module, script }

RuleSourceFilter? sourceFilterOf(CoreRule rule, RuleSource? source) {
  if (rule.ruleSet != null) return RuleSourceFilter.ruleSet;
  if (rule.managed || source == null) return null;
  return switch (source.kind) {
    RuleSourceKind.subscription ||
    RuleSourceKind.custom => RuleSourceFilter.subscription,
    RuleSourceKind.addedProfile ||
    RuleSourceKind.addedGlobal => RuleSourceFilter.added,
    RuleSourceKind.mitm => RuleSourceFilter.module,
    RuleSourceKind.script => RuleSourceFilter.script,
  };
}

/// A rule's text without its target, as the list shows it.
String ruleBodyOf(CoreRule rule) {
  if (rule.type == 'MATCH') return 'MATCH';
  if (rule.ruleSet != null) return 'RULE-SET,${rule.ruleSet!.name}';
  return '${rule.type},${rule.payload}';
}

/// Whether [target] names one of the Core's built-in outbounds rather than a
/// group a user can switch.
bool isBuiltinTarget(String target) => const {
  'DIRECT',
  'REJECT',
  'REJECT-DROP',
  'PASS',
  'COMPATIBLE',
}.contains(target.toUpperCase());

/// Whether the rule at [index] passes the page's filters: the text filter's
/// matches when there are any, the source chip and the group.
bool ruleShown({
  required CoreRule rule,
  required RuleSource? source,
  required RuleSourceFilter filter,
  required String? group,
}) {
  if (group != null && rule.target != group) return false;
  if (filter == RuleSourceFilter.all) return true;
  return sourceFilterOf(rule, source) == filter;
}

/// The rows a lookup lists, in rule order: every rule that holds the host,
/// taken, passed over or undecided.
List<RuleHit> lookupRows(RuleLookup lookup) {
  final winner = lookup.winner?.index;
  final shown = <int>{for (final hit in lookup.matches) hit.index};
  // A rule the lookup cannot decide is left out: the card's hint is the one
  // place that says so. One that waits on a re-match still shows, and the
  // rule taken, the fallback MATCH included, always does.
  return [
    ...lookup.matches,
    for (final hit in lookup.uncertain)
      if (!shown.contains(hit.index) &&
          (hit.reason == 'rematch' || hit.index == winner))
        hit,
  ]..sort((a, b) => a.index.compareTo(b.index));
}

/// The port a pasted address names, by its own port or its scheme; null
/// when it names none, and the lookup reads 443 with port rules undecided.
int? lookupPortOf(String input) {
  final text = input.trim();
  final uri = Uri.tryParse(text.contains('://') ? text : 'tcp://$text');
  if (uri == null) return null;
  if (uri.hasPort && uri.port > 0 && uri.port < 65536) return uri.port;
  return switch (uri.scheme.toLowerCase()) {
    'http' || 'ws' => 80,
    'https' || 'wss' => 443,
    _ => null,
  };
}

/// Whether a lookup cannot promise its answer: a rule before the winner
/// waits on what the lookup lacks, or a rule set it reads is not there.
bool lookupUncertain(RuleLookup lookup) {
  return lookup.uncertain.any((hit) => hit.reason != 'rematch') ||
      lookup.ruleSets.any(
        (set) => set.status == 'missing' || set.status == 'failed',
      );
}

// mihomo's RuleType names, as a request records them, in a config's spelling.
const _configRuleTypes = {
  'domain': 'DOMAIN',
  'domainsuffix': 'DOMAIN-SUFFIX',
  'domainkeyword': 'DOMAIN-KEYWORD',
  'domainregex': 'DOMAIN-REGEX',
  'domainwildcard': 'DOMAIN-WILDCARD',
  'geosite': 'GEOSITE',
  'geoip': 'GEOIP',
  'srcgeoip': 'SRC-GEOIP',
  'ipasn': 'IP-ASN',
  'srcipasn': 'SRC-IP-ASN',
  'ipcidr': 'IP-CIDR',
  'srcipcidr': 'SRC-IP-CIDR',
  'ipsuffix': 'IP-SUFFIX',
  'srcipsuffix': 'SRC-IP-SUFFIX',
  'srcport': 'SRC-PORT',
  'dstport': 'DST-PORT',
  'inport': 'IN-PORT',
  'inuser': 'IN-USER',
  'inname': 'IN-NAME',
  'intype': 'IN-TYPE',
  'process': 'PROCESS-NAME',
  'processname': 'PROCESS-NAME',
  'processpath': 'PROCESS-PATH',
  'processnameregex': 'PROCESS-NAME-REGEX',
  'processpathregex': 'PROCESS-PATH-REGEX',
  'processnamewildcard': 'PROCESS-NAME-WILDCARD',
  'processpathwildcard': 'PROCESS-PATH-WILDCARD',
  'ruleset': 'RULE-SET',
  'network': 'NETWORK',
  'dscp': 'DSCP',
  'uid': 'UID',
  'subrules': 'SUB-RULE',
  'match': 'MATCH',
  'and': 'AND',
  'or': 'OR',
  'not': 'NOT',
};

/// A request's rule, as its record names it (RuleSet and YouTube), in the
/// spelling the rules card uses: RULE-SET,YouTube.
String recordRuleText(String rule, String payload) {
  final key = rule.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  final type = _configRuleTypes[key] ?? rule.toUpperCase();
  if (type == 'MATCH' || payload.isEmpty) return type;
  return '$type,$payload';
}
