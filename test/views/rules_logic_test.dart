import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/rules/hit_card.dart';
import 'package:fl_clash/views/rules/rules_logic.dart';
import 'package:flutter_test/flutter_test.dart';

CoreRule _rule(int index, String type, String payload, String target) =>
    CoreRule(
      index: index,
      type: type,
      ruleType: type,
      payload: payload,
      target: target,
    );

void main() {
  group('lookupHostOf', () {
    test('reads the host of a pasted link', () {
      expect(
        lookupHostOf('https://www.YouTube.com/watch?v=abc'),
        'www.youtube.com',
      );
      expect(lookupHostOf('github.com/f4cker/flash'), 'github.com');
      expect(lookupHostOf('http://[2001:db8::1]:8080/x'), '2001:db8::1');
    });

    test('reads a bare domain or address', () {
      expect(lookupHostOf('api.openai.com'), 'api.openai.com');
      expect(lookupHostOf('example.com.'), 'example.com');
      expect(lookupHostOf('example.com:8443'), 'example.com');
      expect(lookupHostOf('1.1.1.1'), '1.1.1.1');
      expect(lookupHostOf('1.1.1.1:53'), '1.1.1.1');
      expect(lookupHostOf('::1'), '::1');
    });

    test('leaves plain text to the filter', () {
      expect(lookupHostOf(''), isNull);
      expect(lookupHostOf('youtube'), isNull);
      expect(lookupHostOf('DOMAIN-SUFFIX'), isNull);
      expect(lookupHostOf('GEOIP,CN'), isNull);
      expect(lookupHostOf('rule set'), isNull);
    });
  });

  test('lookupPortOf reads a port or a scheme', () {
    expect(lookupPortOf('https://a.com/x'), 443);
    expect(lookupPortOf('http://a.com'), 80);
    expect(lookupPortOf('a.com:8080'), 8080);
    expect(lookupPortOf('a.com'), isNull);
    expect(lookupPortOf('1.2.3.4'), isNull);
  });

  test('domainLevels splits a host from its registrable domain down', () {
    expect(domainLevels('www.youtube.com'), ['youtube.com', 'www.youtube.com']);
    expect(domainLevels('a.b.example.co.uk'), [
      'example.co.uk',
      'b.example.co.uk',
      'a.b.example.co.uk',
    ]);
    expect(domainLevels('github.com'), ['github.com']);
  });

  group('added rules', () {
    test('a domain offers each level and the exact host', () {
      final choices = addedRuleChoices('api.example.com');
      expect(choices.map((choice) => choice.type), [
        'DOMAIN-SUFFIX',
        'DOMAIN-SUFFIX',
        'DOMAIN',
      ]);
      expect(choices.first.value, 'example.com');
      expect(choices.last.value, 'api.example.com');
      expect(
        addedRuleText(choices.first, 'Proxy'),
        'DOMAIN-SUFFIX,example.com,Proxy',
      );
    });

    test('an address offers only itself, without resolving', () {
      final v4 = addedRuleChoices('1.2.3.4');
      expect(v4, hasLength(1));
      expect(
        addedRuleText(v4.single, 'DIRECT'),
        'IP-CIDR,1.2.3.4/32,DIRECT,no-resolve',
      );
      final v6 = addedRuleChoices('2001:db8::1');
      expect(
        addedRuleText(v6.single, 'REJECT'),
        'IP-CIDR6,2001:db8::1/128,REJECT,no-resolve',
      );
    });
  });

  group('alignRuleSources', () {
    final list = RuleList(
      coreEpoch: 7,
      managedPrefix: 1,
      total: 3,
      rules: [
        _rule(0, 'IP-CIDR', '100.64.0.0/10', 'Tailscale (Flash)'),
        _rule(1, 'DOMAIN-SUFFIX', 'github.com', 'Proxy'),
        _rule(2, 'MATCH', '', 'Final'),
      ],
    );
    const sources = [
      RuleSource(
        kind: RuleSourceKind.addedProfile,
        text: 'DOMAIN-SUFFIX,github.com,Proxy',
      ),
      RuleSource(kind: RuleSourceKind.subscription, text: 'MATCH,Final'),
    ];

    test('lines the sources up after the managed rules', () {
      final aligned = alignRuleSources(
        list: list,
        applied: const AppliedRuleSources(profileId: 1, sources: sources),
        profileId: 1,
      );
      expect(aligned, [null, sources[0], sources[1]]);
    });

    test('gives up on another profile, epoch, length or type', () {
      expect(
        alignRuleSources(
          list: list,
          applied: const AppliedRuleSources(profileId: 2, sources: sources),
          profileId: 1,
        ),
        isNull,
      );
      expect(
        alignRuleSources(
          list: list,
          applied: const AppliedRuleSources(
            profileId: 1,
            sources: sources,
            epoch: 6,
          ),
          profileId: 1,
        ),
        isNull,
      );
      expect(
        alignRuleSources(
          list: list,
          applied: AppliedRuleSources(profileId: 1, sources: [sources[0]]),
          profileId: 1,
        ),
        isNull,
      );
      expect(
        alignRuleSources(
          list: list,
          applied: const AppliedRuleSources(
            profileId: 1,
            sources: [
              RuleSource(
                kind: RuleSourceKind.subscription,
                text: 'GEOIP,CN,DIRECT',
              ),
              RuleSource(kind: RuleSourceKind.subscription, text: 'MATCH,X'),
            ],
          ),
          profileId: 1,
        ),
        isNull,
      );
    });
  });

  test('sameRuleAsRecord compares by the names a request carries', () {
    const rule = CoreRule(
      index: 3,
      type: 'DOMAIN-SUFFIX',
      ruleType: 'DomainSuffix',
      payload: 'youtube.com',
      target: 'YouTube',
    );
    expect(
      sameRuleAsRecord(
        rule,
        recordRule: 'DomainSuffix',
        recordPayload: 'youtube.com',
      ),
      isTrue,
    );
    expect(
      sameRuleAsRecord(
        rule,
        recordRule: 'Domain',
        recordPayload: 'youtube.com',
      ),
      isFalse,
    );
    const match = CoreRule(type: 'MATCH', ruleType: 'Match', target: 'Final');
    expect(
      sameRuleAsRecord(match, recordRule: 'Match', recordPayload: ''),
      isTrue,
    );
  });

  test('ruleSetOverdueDays counts whole days past the interval', () {
    final now = DateTime.utc(2026, 11, 16, 12);
    final set = RuleSetView(
      name: 'Netflix',
      interval: 86400,
      updatedAt: DateTime.utc(2026, 11, 12, 12),
    );
    expect(ruleSetOverdueDays(set, now), 3);
    expect(ruleSetOverdueDays(set.copyWith(interval: 0), now), 0);
    expect(
      ruleSetOverdueDays(set.copyWith(updatedAt: DateTime.utc(1)), now),
      0,
    );
  });

  test('sourceFilterOf sorts each rule under one chip', () {
    const rule = CoreRule(type: 'DOMAIN', payload: 'a.com', target: 'X');
    expect(
      sourceFilterOf(
        rule.copyWith(ruleSet: const RuleSetView(name: 'S')),
        null,
      ),
      RuleSourceFilter.ruleSet,
    );
    expect(sourceFilterOf(rule, null), isNull);
    expect(sourceFilterOf(rule.copyWith(managed: true), null), isNull);
    expect(
      sourceFilterOf(rule, const RuleSource(kind: RuleSourceKind.addedGlobal)),
      RuleSourceFilter.added,
    );
    expect(
      sourceFilterOf(rule, const RuleSource(kind: RuleSourceKind.mitm)),
      RuleSourceFilter.module,
    );
    expect(
      sourceFilterOf(rule, const RuleSource(kind: RuleSourceKind.script)),
      RuleSourceFilter.script,
    );
    expect(
      sourceFilterOf(rule, const RuleSource(kind: RuleSourceKind.custom)),
      RuleSourceFilter.subscription,
    );
  });

  test('lookupRows lists matches in order, leaving undecided rules out', () {
    const lookup = RuleLookup(
      matches: [
        RuleHit(index: 9, status: RuleHitStatus.shadowed),
        RuleHit(index: 4, status: RuleHitStatus.winner),
      ],
      uncertain: [
        RuleHit(index: 1, reason: 'process'),
        RuleHit(index: 2, reason: 'rematch'),
      ],
    );
    expect(lookupRows(lookup).map((hit) => hit.index), [2, 4, 9]);
  });

  test('lookupRows keeps the fallback MATCH taken after an undecided rule', () {
    const lookup = RuleLookup(
      winner: RuleHit(
        index: 7,
        type: 'MATCH',
        ruleType: 'Match',
        target: '漏网之鱼',
        status: RuleHitStatus.winner,
      ),
      matches: [
        RuleHit(
          index: 7,
          type: 'MATCH',
          ruleType: 'Match',
          target: '漏网之鱼',
          status: RuleHitStatus.winner,
        ),
      ],
      uncertain: [
        RuleHit(
          index: 2,
          type: 'PROCESS-NAME',
          payload: 'Telegram',
          status: RuleHitStatus.uncertain,
          reason: 'process',
        ),
      ],
    );
    final rows = lookupRows(lookup);
    expect(rows.map((hit) => hit.index), [7]);
    expect(rows.single.status, RuleHitStatus.winner);
  });

  test('ruleBodyOf leaves out the target', () {
    expect(ruleBodyOf(_rule(0, 'DOMAIN', 'a.com', 'X')), 'DOMAIN,a.com');
    expect(ruleBodyOf(_rule(0, 'MATCH', '', 'X')), 'MATCH');
    expect(
      ruleBodyOf(
        _rule(
          0,
          'RULE-SET',
          'Netflix',
          'X',
        ).copyWith(ruleSet: const RuleSetView(name: 'Netflix')),
      ),
      'RULE-SET,Netflix',
    );
  });

  group('scriptRuleSources', () {
    test('marks what the script added and keeps what it left', () {
      final sources = scriptRuleSources(
        ['DOMAIN,a.com,X', 'MATCH,Final'],
        ['DOMAIN,new.com,Y', 'DOMAIN,a.com,X', 'MATCH,Final'],
        script: 'Enhance',
      );
      expect(sources.map((source) => source.kind), [
        RuleSourceKind.script,
        RuleSourceKind.subscription,
        RuleSourceKind.subscription,
      ]);
      expect(sources.first.name, 'Enhance');
    });

    test('counts duplicates, so a copy the script made is its own', () {
      final sources = scriptRuleSources(
        ['DOMAIN,a.com,X'],
        ['DOMAIN,a.com,X', 'DOMAIN,a.com,X'],
        script: 's',
      );
      expect(sources.map((source) => source.kind), [
        RuleSourceKind.subscription,
        RuleSourceKind.script,
      ]);
    });

    test('reads every rule as the script\'s without rules before it', () {
      expect(
        scriptRuleSources(null, ['MATCH,DIRECT'], script: 's').single.kind,
        RuleSourceKind.script,
      );
      expect(scriptRuleSources(['MATCH,DIRECT'], null, script: 's'), isEmpty);
    });
  });

  test('a request record reads in a config spelling', () {
    expect(recordRuleText('RuleSet', 'YouTube'), 'RULE-SET,YouTube');
    expect(
      recordRuleText('DomainSuffix', 'github.com'),
      'DOMAIN-SUFFIX,github.com',
    );
    expect(recordRuleText('IPCIDR', '10.0.0.0/8'), 'IP-CIDR,10.0.0.0/8');
    expect(recordRuleText('Process', 'Telegram'), 'PROCESS-NAME,Telegram');
    expect(recordRuleText('Match', ''), 'MATCH');
  });

  test('a lookup is uncertain on an undecided rule or a missing set', () {
    expect(lookupUncertain(const RuleLookup()), isFalse);
    expect(
      lookupUncertain(
        const RuleLookup(
          uncertain: [
            RuleHit(
              index: 1,
              status: RuleHitStatus.uncertain,
              reason: 'rematch',
            ),
          ],
        ),
      ),
      isFalse,
    );
    expect(
      lookupUncertain(
        const RuleLookup(
          uncertain: [
            RuleHit(index: 1, status: RuleHitStatus.uncertain, reason: 'port'),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      lookupUncertain(
        const RuleLookup(
          ruleSets: [RuleSetView(name: 'A', status: 'missing')],
        ),
      ),
      isTrue,
    );
  });

  test('spaceCjkLatin spaces Chinese from Latin, as the copy does', () {
    expect(spaceCjkLatin('前面的规则可能因 App或端口 而优先匹配'), '前面的规则可能因 App 或端口 而优先匹配');
    expect(spaceCjkLatin('因 App、端口或IP 而'), '因 App、端口或 IP 而');
  });
}
