import 'dart:async';

import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/l10n/l10n.dart';

typedef _Rule = ({
  RegExp pattern,
  String Function(AppLocalizations l, RegExpMatch match) message,
});

// mihomo's words, from config/config.go; the first match wins.
final List<_Rule> _rules = [
  (
    pattern: RegExp(r'respect-rules.*proxy-server-nameserver.*cannot be empty'),
    message: (l, _) => l.dnsRespectRulesUnmetError,
  ),
  (
    pattern: RegExp(
      r'empty `proxy-server-nameserver` when `proxy-server-nameserver-policy`',
    ),
    message: (l, _) => l.configRejectedProxyServerPolicy,
  ),
  (
    pattern: RegExp(r'default nameserver should be pure IP'),
    message: (l, _) => l.configRejectedDefaultNameserverIp,
  ),
  (
    pattern: RegExp(r'default nameserver should have at least one'),
    message: (l, _) => l.configRejectedDefaultNameserverEmpty,
  ),
  (
    pattern: RegExp(r'NameServer cannot be empty'),
    message: (l, _) => l.configRejectedNameserverEmpty,
  ),
  (
    pattern: RegExp(r'DNS NameServer\[\d+\] (unsupport scheme|format error)'),
    message: (l, _) => l.configRejectedDnsServer,
  ),
  (
    pattern: RegExp(
      r"not found rule-set: ([^\n]*)|rule-set '([^']*)' not found",
    ),
    message: (l, match) => _ruleSetMessage(l, match[1] ?? match[2]),
  ),
  (
    pattern: RegExp(r'dns\.fake-ip-filter\['),
    message: (l, _) => l.configRejectedFakeIpFilter,
  ),
  (
    pattern: RegExp(
      r"fake-ip-range6? must be|ipnet don't have valid ip|"
      r'`fake-ip-range` and `fake-ip-range6` both empty|'
      // parseDNS returns ParsePrefix's error for the ranges unwrapped.
      r'^netip\.ParsePrefix\(',
    ),
    message: (l, _) => l.configRejectedFakeIpRange,
  ),
  (
    pattern: RegExp(r'proxy-server-nameserver-policy\['),
    message: (l, _) => l.configRejectedProxyServerNameserverPolicy,
  ),
  (
    pattern: RegExp(r'nameserver-policy\['),
    message: (l, _) => l.configRejectedNameserverPolicy,
  ),
  (
    pattern: RegExp(
      r'is not a valid value|there is a cycle in domain name mapping',
    ),
    message: (l, _) => l.configRejectedHosts,
  ),
];

// A name is shown only when one was read; never an empty pair of quotes.
String _ruleSetMessage(AppLocalizations l, String? name) =>
    name == null || name.trim().isEmpty
    ? l.configRejectedRuleSetUnnamed
    : l.configRejectedRuleSet(name);

/// What the user should change for a config mihomo refused, in their
/// language; null when its words are not ones the app knows.
String? configRejectionMessage(String raw, AppLocalizations appLocalizations) {
  for (final rule in _rules) {
    if (rule.pattern.firstMatch(raw) case final match?) {
      return rule.message(appLocalizations, match);
    }
  }
  return null;
}

ConfigRejectedException configRejectedException(
  String raw,
  AppLocalizations appLocalizations,
) => ConfigRejectedException(
  configRejectionMessage(raw, appLocalizations) ??
      appLocalizations.configRejectedUnknown,
  raw: raw,
);

String configBuildMessage(
  ConfigBuildException error,
  AppLocalizations appLocalizations,
) {
  final profile = error.profile;
  return switch (error.issue) {
    ConfigBuildIssue.nameserverEmpty when profile != null =>
      appLocalizations.configBuildNameserverEmpty(profile),
    ConfigBuildIssue.nameserverEmpty =>
      appLocalizations.configRejectedNameserverEmpty,
    ConfigBuildIssue.proxyServerNameserverEmpty when profile != null =>
      appLocalizations.configBuildProxyServerPolicy(profile),
    ConfigBuildIssue.proxyServerNameserverEmpty =>
      appLocalizations.configRejectedProxyServerPolicy,
    ConfigBuildIssue.fakeIpFilterRuleSetMissing
        when profile != null && (error.detail ?? '').isNotEmpty =>
      appLocalizations.configBuildFakeIpFilterRuleSet(profile, error.detail!),
    ConfigBuildIssue.fakeIpFilterRuleSetMissing => _ruleSetMessage(
      appLocalizations,
      error.detail,
    ),
    ConfigBuildIssue.hostsCycle when profile != null =>
      appLocalizations.configBuildHostsCycle(profile, error.detail ?? ''),
    ConfigBuildIssue.hostsInvalid when profile != null =>
      appLocalizations.configBuildHostsInvalid(profile, error.detail ?? ''),
    ConfigBuildIssue.hostsCycle ||
    ConfigBuildIssue.hostsInvalid => appLocalizations.configRejectedHosts,
  };
}

/// The Core's own words behind [error], for the banner's details.
String? rawConfigErrorOf(Object error) => switch (error) {
  ParallelWaitError(errors: (final AsyncError? first, final AsyncError? second))
      when first != null || second != null =>
    rawConfigErrorOf((first ?? second)!.error),
  ConfigRejectedException(:final raw) => raw,
  CoreMethodException(
    code: 'config_rejected' || 'mount_rejected',
    :final message,
  ) =>
    message,
  _ => null,
};
