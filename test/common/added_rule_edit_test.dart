import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/common/added_rule_edit.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  test('rejects 200 error bodies and malformed domain patterns', () {
    for (final text in [
      'unauthorized',
      '{"error":"denied"}',
      'bad..example',
      '-bad.example',
      'foo/bar.example',
      'bad+.example',
    ]) {
      expect(classifyRuleSet(_bytes(text)).ok, isFalse, reason: text);
    }
    expect(classifyRuleSet(_bytes('+.example.com\n*.example.net')).ok, isTrue);
  });

  group('normalizeAddedRuleValue', () {
    test('a pasted link gives its host for a domain rule', () {
      expect(
        normalizeAddedRuleValue(
          RuleAction.DOMAIN_SUFFIX,
          ' https://WWW.Example.com/path?q=1 ',
        ),
        'www.example.com',
      );
      expect(
        normalizeAddedRuleValue(RuleAction.DOMAIN, 'example.com.'),
        'example.com',
      );
    });

    test('a single address becomes its own range', () {
      expect(
        normalizeAddedRuleValue(RuleAction.IP_CIDR, '10.1.2.3'),
        '10.1.2.3/32',
      );
      expect(
        normalizeAddedRuleValue(RuleAction.IP_CIDR6, '[2001:db8::1]'),
        '2001:db8::1/128',
      );
      expect(
        normalizeAddedRuleValue(RuleAction.IP_CIDR, '10.0.0.0/8'),
        '10.0.0.0/8',
      );
    });
  });

  test('addedRuleValueError says why a value cannot make a rule', () {
    expect(
      addedRuleValueError(RuleAction.DOMAIN_SUFFIX, ''),
      AddedRuleValueError.empty,
    );
    expect(
      addedRuleValueError(RuleAction.DOMAIN_SUFFIX, 'a b'),
      AddedRuleValueError.domain,
    );
    expect(
      addedRuleValueError(RuleAction.DOMAIN_KEYWORD, 'a,b'),
      AddedRuleValueError.comma,
    );
    expect(
      addedRuleValueError(RuleAction.IP_CIDR, '10.0.0.0/40'),
      AddedRuleValueError.cidr,
    );
    expect(
      addedRuleValueError(RuleAction.DST_PORT, 'https'),
      AddedRuleValueError.numberRange,
    );
    expect(addedRuleValueError(RuleAction.DOMAIN_SUFFIX, 'example.com'), null);
    expect(addedRuleValueError(RuleAction.DST_PORT, '8000-9000'), null);
    expect(addedRuleValueError(RuleAction.PROCESS_NAME, 'Safari'), null);
  });

  test('a looked-up host starts the dialog without www.', () {
    expect(addedRulePrefill('www.youtube.com'), (
      type: RuleAction.DOMAIN_SUFFIX,
      value: 'youtube.com',
    ));
    expect(addedRulePrefill('1.2.3.4'), (
      type: RuleAction.IP_CIDR,
      value: '1.2.3.4/32',
    ));
  });

  test('the more menu offers no logic rules and no main type twice', () {
    for (final type in addedRuleMoreTypes) {
      expect(type.nestsRules, isFalse);
      expect(addedRuleMainTypes, isNot(contains(type)));
    }
    expect(addedRuleMoreTypes.toSet().length, addedRuleMoreTypes.length);
    expect(addedRuleMoreTypes, isNot(contains(RuleAction.RULE_SET)));
    expect(addedRuleMoreTypes, isNot(contains(RuleAction.MATCH)));
  });

  test('sameAddedRule ignores the group and case', () {
    expect(
      sameAddedRule(
        const Rule(
          ruleAction: RuleAction.DOMAIN,
          content: 'A.example',
          ruleTarget: 'X',
        ),
        const Rule(
          ruleAction: RuleAction.DOMAIN,
          content: 'a.example',
          ruleTarget: 'Y',
        ),
      ),
      isTrue,
    );
    expect(
      sameAddedRule(
        const Rule(ruleAction: RuleAction.DOMAIN, content: 'a.example'),
        const Rule(ruleAction: RuleAction.DOMAIN_SUFFIX, content: 'a.example'),
      ),
      isFalse,
    );
  });

  group('rule set links and names', () {
    test('a name comes from the file name', () {
      expect(ruleSetNameOf('https://x.test/a/b/telegram.list.txt'), 'telegram');
      expect(ruleSetNameOf('https://x.test/'), 'x.test');
      expect(ruleSetNameOf('https://x.test/a%20b.yaml'), 'a b');
    });

    test('only web links download', () {
      expect(isRuleSetUrl('https://x.test/a.yaml'), isTrue);
      expect(isRuleSetUrl('HTTP://x.test/a.yaml'), isTrue);
      expect(isRuleSetUrl('file:///etc/a.yaml'), isFalse);
      expect(isRuleSetUrl('/etc/a.yaml'), isFalse);
      expect(isRuleSetUrl('ftp://x.test/a'), isFalse);
    });

    test('a name cannot split a rule line', () {
      expect(isRuleSetName('ads'), isTrue);
      expect(isRuleSetName('a,b'), isFalse);
      expect(isRuleSetName(' ads'), isFalse);
      expect(isRuleSetName(''), isFalse);
    });

    test('mrs holds only domains or ranges', () {
      expect(
        ruleSetFormatFits(
          RuleProviderBehavior.classical,
          RuleProviderFormat.mrs,
        ),
        isFalse,
      );
      expect(
        ruleSetFormatFits(RuleProviderBehavior.domain, RuleProviderFormat.mrs),
        isTrue,
      );
      expect(
        ruleSetFormatFits(
          RuleProviderBehavior.classical,
          RuleProviderFormat.yaml,
        ),
        isTrue,
      );
    });
  });

  group('classifyRuleSet', () {
    test('reads a YAML payload of domains', () {
      final check = classifyRuleSet(
        _bytes("payload:\n  - '+.example.com'\n  - 'a.test'\n"),
      );
      expect(check.ok, isTrue);
      expect(check.behavior, RuleProviderBehavior.domain);
      expect(check.format, RuleProviderFormat.yaml);
      expect(check.count, 2);
    });

    test('accepts unambiguous Core single-label and suffix patterns', () {
      for (final text in [
        "payload:\n  - localhost\n",
        '+.localhost',
        '.localhost',
        'localhost\nexample.com',
      ]) {
        expect(
          classifyRuleSet(_bytes(text)).behavior,
          RuleProviderBehavior.domain,
          reason: text,
        );
      }
      expect(classifyRuleSet(_bytes('unauthorized')).ok, isFalse);
    });

    test('reads a text list of ranges, skipping comments', () {
      final check = classifyRuleSet(
        _bytes('# ranges\n10.0.0.0/8\n\n// more\n192.168.0.0/16\n1.1.1.1\n'),
      );
      expect(check.behavior, RuleProviderBehavior.ipcidr);
      expect(check.format, RuleProviderFormat.text);
      expect(check.count, 3);
    });

    test('reads typed lines as mixed rules', () {
      final check = classifyRuleSet(
        _bytes('DOMAIN-SUFFIX,example.com\nIP-CIDR,10.0.0.0/8,no-resolve\n'),
      );
      expect(check.behavior, RuleProviderBehavior.classical);
      expect(check.count, 2);
    });

    test('leaves an mrs file to the Core', () {
      final check = classifyRuleSet(
        Uint8List.fromList([0x28, 0xB5, 0x2F, 0xFD, 0, 1]),
      );
      expect(check.ok, isTrue);
      expect(check.format, RuleProviderFormat.mrs);
      expect(check.behavior, isNull);
      expect(check.count, isNull);
    });

    test('a web page, a config or nothing is not a rule set', () {
      for (final text in [
        '<!doctype html><html></html>',
        'proxies: []\nrules: []\nport: 7890\n',
        '',
        'hello world\nthis is text\n',
      ]) {
        expect(
          classifyRuleSet(_bytes(text)).failure,
          RuleSetCheckFailure.notRuleSet,
          reason: text,
        );
      }
    });

    test('unknown typed lines or a mix are not recognized', () {
      expect(
        classifyRuleSet(_bytes('WHATEVER,x\n')).failure,
        RuleSetCheckFailure.unknown,
      );
      expect(
        classifyRuleSet(_bytes('example.com\n10.0.0.0/8\n')).failure,
        RuleSetCheckFailure.unknown,
      );
    });
  });
}
