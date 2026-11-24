import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/config_rejection.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => loadAppLocalizations(const Locale('en')));

  // core/config_field_test.go holds mihomo to these words.
  final vectors =
      (jsonDecode(
                File(
                  'core/testdata/config_rejection_vectors.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, Object?>>();

  String expected(AppLocalizations l, String kind) => switch (kind.split(':')) {
    ['respectRules'] => l.dnsRespectRulesUnmetError,
    ['proxyServerPolicyEmpty'] => l.configRejectedProxyServerPolicy,
    ['defaultNameserverIp'] => l.configRejectedDefaultNameserverIp,
    ['defaultNameserverEmpty'] => l.configRejectedDefaultNameserverEmpty,
    ['nameserverEmpty'] => l.configRejectedNameserverEmpty,
    ['dnsServer'] => l.configRejectedDnsServer,
    ['fakeIpFilter'] => l.configRejectedFakeIpFilter,
    ['ruleSet', final name] => l.configRejectedRuleSet(name),
    ['fakeIpRange'] => l.configRejectedFakeIpRange,
    ['nameserverPolicy'] => l.configRejectedNameserverPolicy,
    ['proxyServerNameserverPolicy'] =>
      l.configRejectedProxyServerNameserverPolicy,
    ['hosts'] => l.configRejectedHosts,
    _ => throw ArgumentError(kind),
  };

  test('each refusal the app knows names the setting to change', () {
    for (final locale in [const Locale('en'), const Locale('zh')]) {
      final l = loadAppLocalizations(locale);
      for (final vector in vectors) {
        final message = expected(l, vector['kind']! as String);
        for (final raw in [
          vector['raw']! as String,
          ...?(vector['alt'] as List?)?.cast<String>(),
        ]) {
          expect(configRejectionMessage(raw, l), message, reason: raw);
          final error = configRejectedException(raw, l);
          expect(error.message, message);
          expect(error.raw, raw);
        }
      }
    }
  });

  test('an unknown refusal still reads in the user\'s language', () {
    final l = loadAppLocalizations(const Locale('zh'));
    const raw = 'proxy 0: unsupport proxy type: foo';
    expect(configRejectionMessage(raw, l), isNull);
    final error = configRejectedException(raw, l);
    expect(error.message, l.configRejectedUnknown);
    expect(error.raw, raw);
    expect(userFacingErrorMessage(error, l), l.configRejectedUnknown);
  });

  test('a rule set is named only when the Core gave its name', () {
    final l = loadAppLocalizations(const Locale('zh'));
    expect(
      configRejectionMessage('not found rule-set: cn', l),
      l.configRejectedRuleSet('cn'),
    );
    for (final raw in ['not found rule-set: ', "rule-set '' not found"]) {
      expect(
        configRejectionMessage(raw, l),
        l.configRejectedRuleSetUnnamed,
        reason: raw,
      );
    }
  });

  test('the Core\'s refusal maps where it is shown', () {
    final l = loadAppLocalizations(const Locale('zh'));
    const rejected = CoreMethodException(
      code: 'config_rejected',
      message: 'default nameserver should be pure IP',
    );
    expect(
      userFacingErrorMessage(rejected, l),
      l.configRejectedDefaultNameserverIp,
    );
    expect(rawConfigErrorOf(rejected), rejected.message);
    expect(
      rawConfigErrorOf(
        ParallelWaitError<(void, void), (AsyncError?, AsyncError?)>(
          (null, null),
          (null, AsyncError(rejected, StackTrace.empty)),
        ),
      ),
      rejected.message,
    );
    expect(
      rawConfigErrorOf(const CoreMethodException(code: 'x', message: 'y')),
      isNull,
    );
    expect(rawConfigErrorOf(StateError('x')), isNull);
  });

  test('a profile the build refuses is named', () {
    final l = loadAppLocalizations(const Locale('zh'));
    const error = ConfigBuildException(ConfigBuildIssue.nameserverEmpty);
    expect(userFacingErrorMessage(error, l), l.configRejectedNameserverEmpty);
    final named = error.withProfile('机场');
    expect(
      userFacingErrorMessage(named, l),
      l.configBuildNameserverEmpty('机场'),
    );
    expect(userFacingErrorMessage(named, l), contains('机场'));
  });

  test('each build refusal names the profile and what to change', () {
    final l = loadAppLocalizations(const Locale('zh'));
    const policy = ConfigBuildException(
      ConfigBuildIssue.proxyServerNameserverEmpty,
    );
    expect(
      userFacingErrorMessage(policy, l),
      l.configRejectedProxyServerPolicy,
    );
    expect(
      userFacingErrorMessage(policy.withProfile('机场'), l),
      l.configBuildProxyServerPolicy('机场'),
    );
    const ruleSet = ConfigBuildException(
      ConfigBuildIssue.fakeIpFilterRuleSetMissing,
      detail: 'cn',
    );
    expect(userFacingErrorMessage(ruleSet, l), l.configRejectedRuleSet('cn'));
    expect(
      userFacingErrorMessage(ruleSet.withProfile('机场'), l),
      l.configBuildFakeIpFilterRuleSet('机场', 'cn'),
    );
    const unnamed = ConfigBuildException(
      ConfigBuildIssue.fakeIpFilterRuleSetMissing,
      detail: '',
    );
    for (final error in [unnamed, unnamed.withProfile('机场')]) {
      expect(userFacingErrorMessage(error, l), l.configRejectedRuleSetUnnamed);
    }
    const cycle = ConfigBuildException(
      ConfigBuildIssue.hostsCycle,
      detail: 'a.test',
    );
    expect(userFacingErrorMessage(cycle, l), l.configRejectedHosts);
    expect(
      userFacingErrorMessage(cycle.withProfile('机场'), l),
      l.configBuildHostsCycle('机场', 'a.test'),
    );
    const invalid = ConfigBuildException(
      ConfigBuildIssue.hostsInvalid,
      detail: 'a.test',
    );
    expect(userFacingErrorMessage(invalid, l), l.configRejectedHosts);
    expect(
      userFacingErrorMessage(invalid.withProfile('机场'), l),
      l.configBuildHostsInvalid('机场', 'a.test'),
    );
  });
}
