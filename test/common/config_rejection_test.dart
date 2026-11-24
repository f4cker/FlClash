import 'dart:async';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/config_rejection.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => loadAppLocalizations(const Locale('en')));

  // As mihomo words them; core/testdata/config_field_vectors.json holds the
  // Core to the same text.
  Map<String, String> expected(AppLocalizations l) => {
    'if “respect-rules” is turned on, “proxy-server-nameserver” cannot be '
            'empty':
        l.dnsRespectRulesUnmetError,
    'disallow empty `proxy-server-nameserver` when '
            '`proxy-server-nameserver-policy` is set':
        l.configRejectedProxyServerPolicy,
    'default nameserver should be pure IP': l.configRejectedDefaultNameserverIp,
    'default nameserver should have at least one nameserver':
        l.configRejectedDefaultNameserverEmpty,
    'if DNS configuration is turned on, NameServer cannot be empty':
        l.configRejectedNameserverEmpty,
    'DNS NameServer[0] unsupport scheme: doh': l.configRejectedDnsServer,
    'DNS NameServer[0] format error: address 1.1.1.1:53:53: too many colons '
            'in address':
        l.configRejectedDnsServer,
    'dns.fake-ip-filter[0] [example.com] error: invalid action \'\', must be '
            '\'fake-ip\' or \'real-ip\'':
        l.configRejectedFakeIpFilter,
    'dns.fake-ip-filter[0] "rule-set:foo": not found rule-set: foo': l
        .configRejectedRuleSet('foo'),
    'dns.fake-ip-filter[0] [RULE-SET,foo,real-ip] error: rule-set \'foo\' '
        'not found': l.configRejectedRuleSet(
      'foo',
    ),
    'dns.fake-ip-range must be a IPv4 prefix': l.configRejectedFakeIpRange,
    "ipnet don't have valid ip": l.configRejectedFakeIpRange,
    'disallow `fake-ip-range` and `fake-ip-range6` both empty with fake-ip '
            'mode':
        l.configRejectedFakeIpRange,
    'dns.nameserver-policy[0]: invalid domain "a..b": label 2 is empty':
        l.configRejectedNameserverPolicy,
    '[1.1.1.1 example.com] is not a valid value': l.configRejectedHosts,
    'a.com, there is a cycle in domain name mapping': l.configRejectedHosts,
  };

  test('each refusal the app knows names the setting to change', () {
    for (final locale in [const Locale('en'), const Locale('zh')]) {
      final l = loadAppLocalizations(locale);
      for (final MapEntry(key: raw, value: message) in expected(l).entries) {
        expect(configRejectionMessage(raw, l), message, reason: raw);
        final error = configRejectedException(raw, l);
        expect(error.message, message);
        expect(error.raw, raw);
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
}
