import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('encoding helpers round-trip structured data', () async {
    final encoded = jsonEncode({
      'name': 'FlClash',
      'values': [1, true, null],
    });
    final decoded = await decodeJSONTask<Map<String, dynamic>>(encoded);

    expect(decoded['name'], 'FlClash');
    expect(decoded['values'], [1, true, null]);
    expect(await encodeYamlTask({'enabled': true}), contains('enabled: true'));
  });

  test('a proxy name holding control characters stays readable YAML', () {
    const name = 'HK \x1b[31m\x00\x7f\r ';
    final encoded = yaml.encode({
      'proxies': [
        {'name': name},
      ],
      'proxy-groups': [
        {
          'name': 'G',
          'proxies': [name],
        },
      ],
    });

    expect(encoded, isNot(contains('\x1b')));
    final config = loadYaml(encoded) as YamlMap;
    expect(config['proxies'].first['name'], name);
    expect(config['proxy-groups'].first['proxies'], [name]);
  });

  test('toGroupsTask converts, selects, and sorts core proxy data', () async {
    final proxies = <String, dynamic>{
      'Selector': {
        'name': 'Selector',
        'type': 'Selector',
        'now': 'Beta',
        'all': ['Zulu', 'Beta', 'missing'],
      },
      'Direct': {'name': 'Direct', 'type': 'Direct'},
      'Zulu': {'name': 'Zulu', 'type': 'Direct'},
      'Beta': {'name': 'Beta', 'type': 'Direct'},
    };
    final groups = await toGroupsTask(
      ComputeGroupsState(
        proxiesData: ProxiesData(
          all: const ['Selector', 'Direct'],
          proxies: proxies,
        ),
        sortType: ProxiesSortType.name,
        delayMap: const {},
        selectedMap: const {'Selector': 'Beta'},
        defaultTestUrl: 'https://example.com/generate_204',
      ),
    );

    expect(groups, hasLength(1));
    expect(groups.single.name, 'Selector');
    expect(groups.single.all.map((proxy) => proxy.name), ['Beta', 'Zulu']);
  });

  test(
    'clashConfigTask parses core config data off the main isolate',
    () async {
      final configMap = <String, dynamic>{
        'proxies': [
          {'name': 'Alpha', 'type': 'ss'},
          {'name': 'Beta', 'type': 'vmess'},
        ],
        'proxy-groups': [
          {
            'name': 'Auto',
            'type': 'url-test',
            'proxies': ['Alpha', 'Beta'],
          },
        ],
        'rules': ['DOMAIN,example.com,Auto'],
        'proxy-providers': {
          'provider': {'type': 'http'},
        },
        'rule-providers': {
          'ruleSet': {'type': 'http'},
        },
        'sub-rules': {'nested': []},
      };

      final clashConfig = await clashConfigTask(configMap);

      expect(clashConfig.proxies.map((item) => item.name), ['Alpha', 'Beta']);
      expect(clashConfig.proxyGroups.single.type, GroupType.URLTest);
      expect(clashConfig.rules.single.ruleTarget, 'Auto');
      expect(clashConfig.rules.single.content, 'example.com');
      expect(clashConfig.proxyProviders, ['provider']);
      expect(clashConfig.ruleProviders, ['ruleSet']);
      expect(clashConfig.subRules, ['nested']);
    },
  );

  test('toGroupsTask leaves the source proxy map untouched', () async {
    final proxies = <String, dynamic>{
      'Selector': {
        'name': 'Selector',
        'type': 'Selector',
        'all': ['Beta'],
      },
      'Beta': {'name': 'Beta', 'type': 'Direct'},
    };
    final state = ComputeGroupsState(
      proxiesData: ProxiesData(all: const ['Selector'], proxies: proxies),
      sortType: ProxiesSortType.none,
      delayMap: const {},
      selectedMap: const {},
      defaultTestUrl: '',
    );

    await buildGroups(state);
    await buildGroups(state);

    expect(proxies['Selector']['all'], ['Beta']);
  });

  test('toGroupsTask returns empty data without proxies', () async {
    final groups = await toGroupsTask(
      const ComputeGroupsState(
        proxiesData: ProxiesData(proxies: {}, all: []),
        sortType: ProxiesSortType.none,
        delayMap: {},
        selectedMap: {},
        defaultTestUrl: '',
      ),
    );

    expect(groups, isEmpty);
  });

  test(
    'makeRealProfileTask normalizes runtime config and added rules',
    () async {
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        jsonEncode({
          'dns': {
            'enable': true,
            'nameserver': ['1.1.1.1'],
          },
          'sniffer': {
            'sniff': {
              'HTTP': {
                'ports': [80, '443'],
              },
            },
          },
          'proxy-providers': {
            'remote': {'type': 'http', 'url': 'https://example.com/proxy.yaml'},
            'file': {'type': 'file', 'path': './local.yaml'},
          },
          'rule-providers': {
            'remote': {'type': 'http', 'url': 'https://example.com/rule.yaml'},
          },
          'rules': ['DOMAIN,existing.example,DIRECT', 'MATCH,Original'],
        }),
      );
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 7,
          rawConfig: rawConfig,
          realPatchConfig: const PatchClashConfig(
            mixedPort: 7893,
            port: 7890,
            socksPort: 7891,
            redirPort: 7892,
            tproxyPort: 7894,
            allowLan: true,
            ipv6: true,
            hosts: {'router.local': '192.168.1.1,192.168.1.2'},
            dns: Dns(nameserver: ['9.9.9.9']),
          ),
          appendSystemDns: true,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [
            Rule(
              ruleAction: RuleAction.DOMAIN_SUFFIX,
              content: 'added.example',
              ruleTarget: 'MATCH',
            ),
          ],
          defaultUA: 'FlClash-Test',
        ),
      );
      final config = loadYaml(result.yaml) as YamlMap;

      expect(result.md5, hasLength(32));
      expect(config['mixed-port'], 7893);
      expect(config['allow-lan'], true);
      expect(config['global-ua'], 'FlClash-Test');
      expect(config.containsKey('profile'), isFalse);
      expect(config['dns']['nameserver'], ['9.9.9.9', 'system://']);
      expect(config['hosts']['router.local'], ['192.168.1.1', '192.168.1.2']);
      expect(config['sniffer']['sniff']['HTTP']['ports'], ['80', '443']);
      expect(
        config['proxy-providers']['remote']['path'],
        startsWith('/profiles/providers/7/proxies/'),
      );
      expect(
        config['rule-providers']['remote']['path'],
        startsWith('/profiles/providers/7/rules/'),
      );
      expect(config['rules'], [
        'DOMAIN-SUFFIX,added.example,Original',
        'DOMAIN,existing.example,DIRECT',
        'MATCH,Original',
      ]);
      expect(result.counts, (groups: 0, proxies: 0, rules: 3));
    },
  );

  test(
    'export generated provider YAML for offline Core parser integration',
    () async {
      final home = Platform.environment['FLASH_GENERATED_HOME']!;
      const set = AddedRuleSet(
        id: 42,
        profileId: 7,
        name: 'ads',
        url: 'https://example.invalid/ads',
      );
      final config = await decodeJSONTask<Map<String, dynamic>>(
        jsonEncode({
          'rule-providers': {
            'ads': {
              'type': 'http',
              'url': set.url,
              'behavior': 'ipcidr',
              'format': 'text',
            },
          },
          'rules': ['RULE-SET,ads,DIRECT', 'MATCH,DIRECT'],
        }),
      );
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: home,
          profileId: 7,
          rawConfig: config,
          realPatchConfig: const PatchClashConfig(),
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [
            Rule(
              id: 42,
              profileId: 7,
              ruleAction: RuleAction.RULE_SET,
              ruleProvider: 'ads',
              ruleTarget: 'REJECT',
            ),
          ],
          addedRuleSets: const [set],
          defaultUA: 'test',
        ),
      );
      final cache = File(set.pathUnder(home));
      await cache.parent.create(recursive: true);
      await cache.writeAsString(
        "payload:\n  - localhost\n  - '+.example.test'\n",
      );
      await File(join(home, 'generated.yaml')).writeAsString(result.yaml);
    },
    skip: Platform.environment['FLASH_GENERATED_HOME'] == null,
  );

  group('added rule sets', () {
    const ads = AddedRuleSet(
      id: 1,
      profileId: 7,
      name: 'ads',
      url: 'https://x.test/ads.yaml',
    );
    const news = AddedRuleSet(
      id: 2,
      profileId: 7,
      name: 'news',
      url: 'https://x.test/news.txt',
      behavior: RuleProviderBehavior.classical,
      format: RuleProviderFormat.text,
    );

    Future<YamlMap> make({
      required List<AddedRuleSet> sets,
      List<Rule> addedRules = const [],
      List<Rule> rules = const [],
    }) async {
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        jsonEncode({
          'rule-providers': {
            'ads': {'type': 'http', 'url': 'https://sub.test/ads.yaml'},
          },
          'rules': ['RULE-SET,ads,DIRECT', 'MATCH,Proxy'],
        }),
      );
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 7,
          rawConfig: rawConfig,
          realPatchConfig: const PatchClashConfig(),
          appendSystemDns: false,
          proxyGroups: const [],
          rules: rules,
          addedRules: addedRules,
          addedRuleSets: sets,
          defaultUA: 'FlClash-Test',
        ),
      );
      return loadYaml(result.yaml) as YamlMap;
    }

    test('download into the profile\'s own folder, before its rules', () async {
      final config = await make(
        sets: [news],
        addedRules: const [
          Rule(
            id: 1,
            profileId: 7,
            ruleAction: RuleAction.RULE_SET,
            ruleProvider: 'news',
            ruleTarget: 'Proxy',
          ),
        ],
      );

      final providers = config['rule-providers'] as YamlMap;
      expect(providers.keys.toList(), ['news', 'ads']);
      final entry = providers['news'] as YamlMap;
      expect(entry['type'], 'http');
      expect(entry['url'], 'https://x.test/news.txt');
      expect(entry['behavior'], 'classical');
      expect(entry['format'], 'text');
      expect(entry['path'], news.pathUnder('/profiles'));
      expect(entry['path'], startsWith('/profiles/providers/7/rules/'));
      expect(config['rules'], [
        'RULE-SET,news,Proxy',
        'RULE-SET,ads,DIRECT',
        'MATCH,Proxy',
      ]);
    });

    test('a name the subscription takes renames only the added set', () async {
      final config = await make(
        sets: [ads],
        addedRules: const [
          Rule(
            id: 1,
            profileId: 7,
            ruleAction: RuleAction.RULE_SET,
            ruleProvider: 'ads',
            ruleTarget: 'REJECT',
          ),
        ],
      );

      final providers = config['rule-providers'] as YamlMap;
      expect(providers['ads']['url'], 'https://sub.test/ads.yaml');
      expect(
        providers['${addedRuleSetPrefix}ads']['url'],
        'https://x.test/ads.yaml',
      );
      expect(config['rules'], [
        'RULE-SET,${addedRuleSetPrefix}ads,REJECT',
        'RULE-SET,ads,DIRECT',
        'MATCH,Proxy',
      ]);
    });

    test(
      'collision rewrites the paired rule but leaves another rule alone',
      () async {
        final config = await make(
          sets: [ads],
          rules: const [
            Rule(
              id: 1,
              profileId: 7,
              ruleAction: RuleAction.RULE_SET,
              ruleProvider: 'ads',
              ruleTarget: 'REJECT',
            ),
            Rule(
              id: 8,
              profileId: 7,
              ruleAction: RuleAction.RULE_SET,
              ruleProvider: 'ads',
              ruleTarget: 'DIRECT',
            ),
          ],
        );
        expect(config['rules'], [
          'RULE-SET,${addedRuleSetPrefix}ads,REJECT',
          'RULE-SET,ads,DIRECT',
        ]);
      },
    );

    test(
      'legacy unpaired collisions fail without rewriting any rule',
      () async {
        await expectLater(
          make(
            sets: [ads],
            rules: const [
              Rule(
                id: 8,
                profileId: 7,
                ruleAction: RuleAction.RULE_SET,
                ruleProvider: 'ads',
                ruleTarget: 'DIRECT',
              ),
            ],
          ),
          throwsStateError,
        );
      },
    );

    test('a link that is not on the web is left out', () async {
      final config = await make(
        sets: [news.copyWith(url: 'file:///etc/passwd')],
      );

      expect((config['rule-providers'] as YamlMap).keys, ['ads']);
    });

    test('a custom profile\'s own rules use the renamed set', () async {
      final config = await make(
        sets: [ads],
        rules: const [
          Rule(
            id: 1,
            profileId: 7,
            ruleAction: RuleAction.RULE_SET,
            ruleProvider: 'ads',
            ruleTarget: 'REJECT',
          ),
          Rule(ruleAction: RuleAction.MATCH, ruleTarget: 'DIRECT'),
        ],
      );

      expect(config['rules'], [
        'RULE-SET,${addedRuleSetPrefix}ads,REJECT',
        'MATCH,DIRECT',
      ]);
    });
  });

  test('lastMatchTarget reads the last MATCH rule that names a target', () {
    expect(
      lastMatchTarget(['MATCH,A', 'DOMAIN,x.test,B', 'match,C', 'MATCH,']),
      'C',
    );
    expect(lastMatchTarget(['DOMAIN,x.test,B']), isNull);
  });

  test(
    'makeRealProfileTask routes MATCH placeholders to matchTarget',
    () async {
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        jsonEncode({
          'proxies': [],
          'rules': ['DOMAIN,existing.example,DIRECT', 'MATCH,Original'],
        }),
      );
      final state = MakeRealProfileState(
        profilesPath: '/profiles',
        profileId: 7,
        rawConfig: rawConfig,
        realPatchConfig: const PatchClashConfig(),
        appendSystemDns: false,
        proxyGroups: const [],
        rules: const [],
        addedRules: const [
          Rule(
            ruleAction: RuleAction.DOMAIN_SUFFIX,
            content: 'added.example',
            ruleTarget: 'MATCH',
          ),
        ],
        defaultUA: 'FlClash-Test',
        matchTarget: 'HK',
      );

      final overridden = await makeRealProfileTask(state);
      expect((loadYaml(overridden.yaml) as YamlMap)['rules'], [
        'DOMAIN-SUFFIX,added.example,HK',
        'DOMAIN,existing.example,DIRECT',
        'MATCH,Original',
      ]);

      final blank = await makeRealProfileTask(state.copyWith(matchTarget: ' '));
      expect(
        (loadYaml(blank.yaml) as YamlMap)['rules'].first,
        'DOMAIN-SUFFIX,added.example,Original',
      );
    },
  );

  // The core re-reads these two keys out of the generated config on every
  // profile apply and adopts whatever it finds, so a subscription that ships
  // them would otherwise decide whether GEO databases auto-update — including
  // switching the updater back on after the user turned it off.
  test(
    'makeRealProfileTask lets the app setting own the geo updater',
    () async {
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        jsonEncode({'geo-auto-update': true, 'geo-update-interval': 6}),
      );

      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 11,
          rawConfig: rawConfig,
          realPatchConfig: const PatchClashConfig(
            geoAutoUpdate: false,
            geoUpdateInterval: 48,
          ),
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
        ),
      );
      final config = loadYaml(result.yaml) as YamlMap;

      expect(config['geo-auto-update'], false);
      expect(config['geo-update-interval'], 48);
    },
  );

  test('makeRealProfileTask lets the page own only authentication', () async {
    final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
      jsonEncode({
        'authentication': ['subscription:injected'],
        'skip-auth-prefixes': ['127.0.0.1/32'],
      }),
    );
    final state = MakeRealProfileState(
      profilesPath: '/profiles',
      profileId: 12,
      rawConfig: rawConfig,
      realPatchConfig: const PatchClashConfig(),
      appendSystemDns: false,
      proxyGroups: const [],
      rules: const [],
      addedRules: const [],
      defaultUA: 'FlClash-Test',
      authentication: const ['user:pass'],
    );

    final enabled = await makeRealProfileTask(state);
    final enabledConfig = loadYaml(enabled.yaml) as YamlMap;
    expect(enabledConfig['authentication'], ['user:pass']);
    expect(enabledConfig['skip-auth-prefixes'], ['127.0.0.1/32']);

    final disabled = await makeRealProfileTask(
      state.copyWith(authentication: const []),
    );
    final disabledConfig = loadYaml(disabled.yaml) as YamlMap;
    expect(disabledConfig['authentication'], isEmpty);
    expect(disabledConfig['skip-auth-prefixes'], ['127.0.0.1/32']);
  });

  test('makeRealProfileTask writes custom data and no DNS template', () async {
    final result = await makeRealProfileTask(
      const MakeRealProfileState(
        profilesPath: '/profiles',
        profileId: 9,
        rawConfig: {},
        realPatchConfig: PatchClashConfig(),
        appendSystemDns: false,
        proxyGroups: [
          ProxyGroup(
            id: 1,
            name: 'Select',
            type: GroupType.Selector,
            proxies: ['DIRECT'],
          ),
        ],
        rules: [
          Rule(
            ruleAction: RuleAction.DOMAIN,
            content: 'custom.example',
            ruleTarget: 'DIRECT',
          ),
        ],
        addedRules: [],
        defaultUA: 'Fallback-UA',
      ),
    );
    final config = loadYaml(result.yaml) as YamlMap;

    expect(config['dns']['nameserver'], const Dns().nameserver);
    expect(config['dns'].keys.toSet(), {
      for (final key in DnsOverrideKey.normalProfileKeys) key.path,
    });
    expect(config['dns'].containsKey('enable'), isFalse);
    expect(config['dns'].containsKey('fallback-filter'), isFalse);
    expect(config['proxy-groups'], hasLength(1));
    expect(config['proxy-groups'][0].keys, ['name', 'type', 'proxies']);
    expect(config['proxy-groups'][0]['type'], 'select');
    expect(config['rules'], ['DOMAIN,custom.example,DIRECT']);
  });

  test('makeRealProfileTask keeps the DNS keys it cannot edit', () async {
    final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
      jsonEncode({
        'dns': {
          'enable': false,
          'direct-nameserver': ['223.5.5.5'],
          'proxy-server-nameserver-policy': {
            'www.example.com': ['8.8.8.8'],
          },
          'nameserver': ['9.9.9.9'],
          'respect-rules': false,
          'cache-max-size': 0,
          'nameserver-policy': <String, dynamic>{},
          'fallback-filter': {'geoip': false, 'ipcidr': <String>[]},
        },
        'proxy-providers': {
          'first': {'type': 'http', 'url': 'https://example.com/shared.yaml'},
          'second': {'type': 'http', 'url': 'https://example.com/shared.yaml'},
        },
      }),
    );

    final result = await makeRealProfileTask(
      MakeRealProfileState(
        profilesPath: '/profiles',
        profileId: 13,
        rawConfig: rawConfig,
        realPatchConfig: const PatchClashConfig(),
        appendSystemDns: false,
        proxyGroups: const [],
        rules: const [],
        addedRules: const [],
        defaultUA: 'FlClash-Test',
      ),
    );
    final config = loadYaml(result.yaml) as YamlMap;

    expect(config['dns']['direct-nameserver'], isEmpty);
    expect(config['dns']['enable'], false);
    expect(config['dns']['respect-rules'], false);
    expect(config['dns']['cache-max-size'], 0);
    expect(config['dns']['nameserver-policy'], isEmpty);
    expect(config['dns']['fallback-filter'], {
      'geoip': false,
      'ipcidr': <String>[],
    });
    expect(config['dns']['nameserver'], const Dns().nameserver);
    expect(config['dns']['proxy-server-nameserver-policy'], {
      'www.example.com': ['8.8.8.8'],
    });
    expect(config['dns']['nameserver'], isNot(contains('system://')));
    expect(
      config['proxy-providers']['first']['path'],
      isNot(config['proxy-providers']['second']['path']),
    );
  });

  test('makeRealProfileTask keeps safe mode off the host', () async {
    Future<YamlMap> build({required bool safeMode}) async {
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 14,
          rawConfig: {
            'dns': {'enable': true, 'listen': '0.0.0.0:53'},
            'ntp': {'enable': true, 'write-to-system': true},
          },
          realPatchConfig: const PatchClashConfig(
            dns: Dns(listen: '0.0.0.0:53'),
          ),
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
          safeMode: safeMode,
        ),
      );
      return loadYaml(result.yaml) as YamlMap;
    }

    final normal = await build(safeMode: false);
    expect(normal['dns']['listen'], '0.0.0.0:53');
    expect(normal['ntp']['write-to-system'], true);

    final safe = await build(safeMode: true);
    expect(safe['dns']['listen'], '');
    expect(safe['ntp']['write-to-system'], false);
    expect(safe['ntp']['enable'], true);
  });

  test(
    'makeRealProfileTask does not let a profile open a controller',
    () async {
      for (final endpoint in {
        'external-controller-tls': '0.0.0.0:9443',
        'external-controller-unix': '/tmp/synthetic-controller.sock',
        'external-controller-pipe': r'\\.\pipe\synthetic-controller',
      }.entries) {
        for (final safeMode in [false, true]) {
          final resultFuture = makeRealProfileTask(
            MakeRealProfileState(
              profilesPath: '/profiles',
              profileId: 14,
              rawConfig: {
                'external-controller': '0.0.0.0:9090',
                'secret': 'from-the-profile',
                endpoint.key: endpoint.value,
              },
              realPatchConfig: const PatchClashConfig(),
              appendSystemDns: false,
              proxyGroups: const [],
              rules: const [],
              addedRules: const [],
              defaultUA: 'FlClash-Test',
              safeMode: safeMode,
            ),
          );
          if (!safeMode) {
            await expectLater(
              resultFuture,
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  '${endpoint.key} is not supported',
                ),
              ),
            );
            continue;
          }
          final result = await resultFuture;
          final config = loadYaml(result.yaml) as YamlMap;

          expect(config['external-controller-tls'], '');
          expect(config['external-controller-unix'], '');
          expect(config['external-controller-pipe'], '');
          expect(config['external-controller'], '');
          expect(config['secret'], '');
        }
      }
    },
  );

  test(
    'makeRealProfileTask writes the app secret over the profile one',
    () async {
      Future<YamlMap> build(PatchClashConfig realPatchConfig) async {
        final result = await makeRealProfileTask(
          MakeRealProfileState(
            profilesPath: '/profiles',
            profileId: 14,
            rawConfig: {'secret': 'from-the-profile'},
            realPatchConfig: realPatchConfig,
            appendSystemDns: false,
            proxyGroups: const [],
            rules: const [],
            addedRules: const [],
            defaultUA: 'FlClash-Test',
          ),
        );
        return loadYaml(result.yaml) as YamlMap;
      }

      final open = await build(
        const PatchClashConfig(
          externalController: ExternalControllerStatus.open,
          secret: 'from-the-app',
        ),
      );
      expect(open['external-controller'], '127.0.0.1:9090');
      expect(open['secret'], 'from-the-app');

      final closed = await build(const PatchClashConfig());
      expect(closed['secret'], '');
      expect(closed['external-controller'], '');
      await expectLater(
        build(
          const PatchClashConfig(
            externalController: ExternalControllerStatus.open,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'External controller requires authentication',
          ),
        ),
      );
    },
  );

  test(
    'profile listeners and host changes are disabled only in safe mode',
    () async {
      for (final safeMode in [false, true]) {
        final result = await makeRealProfileTask(
          MakeRealProfileState(
            profilesPath: '/profiles',
            profileId: 14,
            rawConfig: {
              'listeners': [
                {'type': 'mixed', 'name': 'extra', 'port': 1234},
                {'type': 'tun', 'name': 'extra-tun', 'auto-route': true},
              ],
              'tunnels': [
                {
                  'network': ['tcp'],
                  'address': '0.0.0.0:1234',
                  'target': 'example.test:443',
                },
              ],
              'ss-config': 'ss://cipher:password@:1234',
              'vmess-config': 'vmess://uuid@:1234',
              'tuic-server': {'enable': true, 'listen': '0.0.0.0:1234'},
              'iptables': {'enable': true, 'dns-redirect': true},
              'dns': {'enable': true, 'listen': '0.0.0.0:53'},
              'ntp': {'enable': true, 'write-to-system': true},
            },
            realPatchConfig: const PatchClashConfig(
              externalController: ExternalControllerStatus.open,
              secret: 'from-the-app',
              dns: Dns(listen: '0.0.0.0:53'),
            ),
            appendSystemDns: false,
            proxyGroups: const [],
            rules: const [],
            addedRules: const [],
            defaultUA: 'FlClash-Test',
            safeMode: safeMode,
          ),
        );
        final config = loadYaml(result.yaml) as YamlMap;
        if (safeMode) {
          expect(config['listeners'], isEmpty);
          expect(config['tunnels'], isEmpty);
          expect(config['ss-config'], '');
          expect(config['vmess-config'], '');
          expect(config['tuic-server']['enable'], false);
          expect(config['iptables']['enable'], false);
          expect(config['dns']['listen'], '');
          expect(config['ntp']['write-to-system'], false);
        } else {
          expect(config['listeners'], [
            {'type': 'mixed', 'name': 'extra', 'port': 1234},
            {'type': 'tun', 'name': 'extra-tun', 'auto-route': true},
          ]);
          expect(config['tunnels'], [
            {
              'network': ['tcp'],
              'address': '0.0.0.0:1234',
              'target': 'example.test:443',
            },
          ]);
          expect(config['ss-config'], 'ss://cipher:password@:1234');
          expect(config['vmess-config'], 'vmess://uuid@:1234');
          expect(config['tuic-server'], {
            'enable': true,
            'listen': '0.0.0.0:1234',
          });
          expect(config['iptables'], {'enable': true, 'dns-redirect': true});
          expect(config['dns']['listen'], '0.0.0.0:53');
          expect(config['ntp']['write-to-system'], true);
        }
        expect(config['external-controller'], safeMode ? '' : '127.0.0.1:9090');
      }
    },
  );

  test('iptables interface names cannot add command arguments', () async {
    for (final interfaceName in ['br-lan.10', 'lo -M /tmp/extra']) {
      for (final safeMode in [false, true]) {
        final resultFuture = makeRealProfileTask(
          MakeRealProfileState(
            profilesPath: '/profiles',
            profileId: 14,
            rawConfig: {
              'iptables': {
                'enable': true,
                'inbound-interface': interfaceName,
                'bypass': ['192.168.0.0/16'],
              },
            },
            realPatchConfig: const PatchClashConfig(),
            appendSystemDns: false,
            proxyGroups: const [],
            rules: const [],
            addedRules: const [],
            defaultUA: 'FlClash-Test',
            safeMode: safeMode,
          ),
        );
        if (!safeMode && interfaceName != 'br-lan.10') {
          await expectLater(
            resultFuture,
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'iptables.inbound-interface must not contain spaces',
              ),
            ),
          );
          continue;
        }
        final result = await resultFuture;
        final config = loadYaml(result.yaml) as YamlMap;
        expect(
          config['iptables'],
          safeMode
              ? {'enable': false}
              : {
                  'enable': true,
                  'inbound-interface': interfaceName,
                  'bypass': ['192.168.0.0/16'],
                },
        );
      }
    }
  });

  group('makeRealProfileTask interface-name mode', () {
    Future<YamlMap> runWith(PatchClashConfig realPatchConfig) async {
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        jsonEncode({'interface-name': 'en0'}),
      );

      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 13,
          rawConfig: rawConfig,
          realPatchConfig: realPatchConfig,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
        ),
      );
      return loadYaml(result.yaml) as YamlMap;
    }

    // Default mode, so a subscription value must not survive into the
    // generated config.
    test('clear forces interface-name empty', () async {
      final config = await runWith(const PatchClashConfig());

      expect(config['interface-name'], '');
    });

    test('follow leaves the profile value untouched', () async {
      final config = await runWith(
        const PatchClashConfig(interfaceNameMode: InterfaceNameMode.follow),
      );

      expect(config['interface-name'], 'en0');
    });

    test('custom writes the configured interface name', () async {
      final config = await runWith(
        const PatchClashConfig(
          interfaceNameMode: InterfaceNameMode.custom,
          interfaceName: 'eth0',
        ),
      );

      expect(config['interface-name'], 'eth0');
    });
  });

  group('makeRealProfileTask network settings', () {
    Future<YamlMap> runWith(
      PatchClashConfig realPatchConfig,
      Map<String, dynamic> rawConfig, {
      List<MitmModuleSource> mitmModules = const [],
    }) async {
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 14,
          rawConfig: await decodeJSONTask<Map<String, dynamic>>(
            jsonEncode(rawConfig),
          ),
          realPatchConfig: realPatchConfig,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
          mitmModules: mitmModules,
        ),
      );
      return loadYaml(result.yaml) as YamlMap;
    }

    test('tun takes its stack from the settings and the rest from the '
        'profile', () async {
      final config = await runWith(
        const PatchClashConfig(
          tun: Tun(stack: TunStack.gvisor),
          tunOverride: ProfileTun(
            mtu: 1400,
            congestionController: 'bbr',
            udpTimeout: 0,
            routeAddress: [],
            routeExcludeAddress: [],
            dnsHijack: [],
          ),
        ),
        {
          'tun': {
            'stack': 'system',
            'mtu': 1500,
            'strict-route': true,
            'udp-timeout': 60,
            'route-address': ['0.0.0.0/0'],
            'route-exclude-address': ['10.0.0.0/8'],
            'dns-hijack': ['any:53'],
            'device': 'profile-tun',
          },
        },
      );
      final tun = config['tun'] as YamlMap;

      expect(tun['stack'], 'gvisor');
      expect(tun.containsKey('auto-route'), isFalse);
      expect(tun['mtu'], 1400);
      expect(tun['strict-route'], !(Platform.isLinux || Platform.isWindows));
      expect(tun['congestion-controller'], 'bbr');
      expect(tun['udp-timeout'], 0);
      expect(tun['route-address'], isEmpty);
      expect(tun['route-exclude-address'], isEmpty);
      expect(tun['dns-hijack'], isEmpty);
      expect(tun['device'], 'profile-tun');
    });

    test('tun keeps the profile auto-detect-interface', () async {
      final config = await runWith(const PatchClashConfig(), {
        'tun': {'auto-detect-interface': false},
      });
      final tun = config['tun'] as YamlMap;

      expect(tun['auto-detect-interface'], false);
    });

    test('outbound settings start at the core defaults', () async {
      final config = await runWith(const PatchClashConfig(), {
        'routing-mark': 1,
      });

      expect(config['keep-alive-idle'], 15);
      expect(config['routing-mark'], Platform.isLinux ? 0 : 1);
    });

    test('set outbound values replace the profile ones', () async {
      final config = await runWith(
        const PatchClashConfig(routingMark: 6666, disableKeepAlive: true),
        {'routing-mark': 1, 'disable-keep-alive': false},
      );

      expect(config['routing-mark'], Platform.isLinux ? 6666 : 1);
      expect(config['disable-keep-alive'], true);
    });

    test('the mitm section is the app setting, never the profile', () async {
      final config = await runWith(
        const PatchClashConfig(mitm: Mitm(enable: true, hostname: ['a.com'])),
        {
          'mitm': {
            'enable': true,
            'hostname': ['*'],
            'url-rewrite': ['^http://x _ reject'],
          },
        },
      );
      final mitm = config['mitm'] as YamlMap;

      expect(mitm['enable'], isTrue);
      expect(mitm['hostname'], ['a.com']);
      expect(mitm['url-rewrite'], isEmpty);
      expect(mitm['decrypt-tls'], isFalse);
      expect(mitm, isNot(contains('trusted-fingerprint')));
    });

    test('HTTPS is decrypted with the CA the device trusts', () async {
      final config = await runWith(
        const PatchClashConfig(
          mitm: Mitm(enable: true, trustedFingerprint: 'AB:CD'),
        ),
        const {},
      );
      final mitm = config['mitm'] as YamlMap;

      expect(mitm['decrypt-tls'], isTrue);
      expect(mitm['ca-fingerprint'], 'AB:CD');
    });

    test('modules join the mitm lists and lead the rules', () async {
      final config = await runWith(
        const PatchClashConfig(
          mitm: Mitm(enable: true, hostname: ['-own.example.com']),
        ),
        {
          'rules': ['MATCH,DIRECT'],
        },
        mitmModules: const [
          MitmModuleSource(
            content: '''
#!arguments=Host:module.example.com
[MITM]
hostname = %APPEND% {{{Host}}}
[URL Rewrite]
^https://module _ reject
[Rule]
DOMAIN-SUFFIX,ads.example.com,REJECT
''',
            arguments: {'Host': '*.example.com'},
          ),
        ],
      );
      final mitm = config['mitm'] as YamlMap;

      expect(mitm['hostname'], ['-own.example.com', '*.example.com']);
      expect(mitm['url-rewrite'], ['^https://module _ reject']);
      expect(config['rules'], [
        'DOMAIN-SUFFIX,ads.example.com,REJECT',
        'MATCH,DIRECT',
      ]);
    });

    test('a profile cannot turn MITM on while the app has it off', () async {
      final config = await runWith(const PatchClashConfig(), {
        'mitm': {
          'enable': true,
          'hostname': ['*'],
        },
      });

      expect((config['mitm'] as YamlMap)['enable'], isFalse);
      expect((config['mitm'] as YamlMap)['hostname'], isEmpty);
    });
  });

  group('makeRealProfileTask ownership regressions', () {
    Future<YamlMap> build({
      required Map<String, dynamic> rawConfig,
      PatchClashConfig page = const PatchClashConfig(),
      ProfileOverrides overrides = const ProfileOverrides(),
      bool appendSystemDns = false,
      bool safeMode = false,
    }) async {
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 18,
          rawConfig: rawConfig,
          realPatchConfig: page,
          overrides: overrides,
          appendSystemDns: appendSystemDns,
          safeMode: safeMode,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
        ),
      );
      return loadYaml(result.yaml) as YamlMap;
    }

    test(
      'page defaults and the whole Hosts dictionary replace the file',
      () async {
        for (final hosts in [
          <String, String>{},
          {'page.test': '192.0.2.1,192.0.2.2'},
        ]) {
          final config = await build(
            rawConfig: {
              'allow-lan': true,
              'port': 8888,
              'ipv6': true,
              'unified-delay': false,
              'tcp-concurrent': false,
              'hosts': {'file.test': '192.0.2.3'},
            },
            page: PatchClashConfig(hosts: hosts),
          );

          expect(config['allow-lan'], false);
          expect(config['port'], 0);
          expect(config['ipv6'], false);
          expect(config['unified-delay'], true);
          expect(config['tcp-concurrent'], true);
          expect(
            config['hosts'],
            hosts.isEmpty
                ? {}
                : {
                    'page.test': ['192.0.2.1', '192.0.2.2'],
                  },
          );
        }
      },
    );

    test(
      'custom profile overrides apply only their selected controls',
      () async {
        final config = await build(
          rawConfig: {
            'ntp': {
              'enable': true,
              'server': 'file.example',
              'write-to-system': false,
            },
            'sniffer': {
              'enable': true,
              'force-domain': ['file.example'],
            },
          },
          overrides: const ProfileOverrides(
            ntp: Ntp(server: 'custom.example', enable: false),
            ntpOverrideKeys: {NtpOverrideKey.server},
            sniffer: Sniffer(
              enable: false,
              forceDomain: ['unselected.example'],
            ),
            snifferOverrideKeys: {SnifferOverrideKey.enable},
          ),
        );

        expect(config['ntp'], {
          'enable': true,
          'server': 'custom.example',
          'write-to-system': false,
        });
        expect(config['sniffer'], {
          'enable': false,
          'force-domain': ['file.example'],
        });
      },
    );

    test(
      'uncontrolled nested false zero and empty file values survive',
      () async {
        final config = await build(
          rawConfig: {
            'tun': {
              'auto-route': false,
              'auto-detect-interface': false,
              'file-descriptor': 0,
            },
            'sniffer': {'enable': false, 'force-domain': <String>[]},
            'ntp': {'enable': false, 'interval': 0},
            'skip-auth-prefixes': <String>[],
          },
        );

        expect(config['tun']['auto-route'], false);
        expect(config['tun']['auto-detect-interface'], false);
        expect(config['tun']['file-descriptor'], 0);
        expect(config['sniffer'], {
          'enable': false,
          'force-domain': <String>[],
        });
        expect(config['ntp'], {'enable': false, 'interval': 0});
        expect(config['skip-auth-prefixes'], isEmpty);
      },
    );

    test('DNS empty fragments remain selected-only', () {
      const dns = Dns(nameserver: []);

      // Upstream e1669a63: a picked key is written as it is, empty included.
      expect(dns.overrideJson({}), isEmpty);
      expect(dns.overrideJson({DnsOverrideKey.nameserver}), {
        'nameserver': <String>[],
      });
    });

    test(
      'DNS keeps missing and explicit null unowned enable distinct',
      () async {
        final missing = await build(rawConfig: {'dns': <String, dynamic>{}});
        final explicitNull = await build(
          rawConfig: {
            'dns': {'enable': null},
          },
        );

        expect(missing['dns'].containsKey('enable'), false);
        expect(explicitNull['dns'].containsKey('enable'), true);
        expect(explicitNull['dns']['enable'], isNull);
      },
    );

    test(
      'safe mode keeps empty DNS isolated without normal rejection',
      () async {
        final config = await build(
          rawConfig: {
            'dns': {'enable': true, 'listen': '0.0.0.0:53'},
            'tun': {'enable': true},
          },
          page: const PatchClashConfig(
            dns: Dns(listen: '0.0.0.0:53', nameserver: []),
            tun: Tun(enable: true),
          ),
          safeMode: true,
        );

        expect(config['dns']['listen'], '');
        expect(config['dns']['nameserver'], isEmpty);
        expect(config['tun']['enable'], false);
        expect(config['external-controller'], '');
        expect(config['listeners'], isEmpty);
      },
    );

    test('disabled DNS accepts the page empty nameserver list', () async {
      final config = await build(
        rawConfig: {
          'dns': {
            'enable': false,
            'nameserver': ['192.0.2.53'],
          },
        },
        page: const PatchClashConfig(dns: Dns(nameserver: [])),
      );

      expect(config['dns']['enable'], false);
      expect(config['dns']['nameserver'], isEmpty);
    });

    test(
      'enabled DNS rejects empty nameservers without system fallback',
      () async {
        await expectLater(
          build(
            rawConfig: {
              'dns': {'enable': true, 'nameserver': <String>[]},
            },
            page: const PatchClashConfig(dns: Dns(nameserver: [])),
          ),
          throwsStateError,
        );

        final config = await build(
          rawConfig: {
            'dns': {'enable': true, 'nameserver': <String>[]},
          },
          page: const PatchClashConfig(dns: Dns(nameserver: [])),
          appendSystemDns: true,
        );
        expect(config['dns']['enable'], true);
        expect(config['dns']['nameserver'], ['system://']);
      },
    );
  });

  group('makeRealProfileTask legacy provider file migration', () {
    late Directory tempDir;
    const url = 'https://example.com/proxy.yaml';
    const name = 'remote';

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('task_test_providers');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<({String legacyPath, String newPath})> runMigration() async {
      final providerDir = join(
        tempDir.path,
        providersDirectoryName,
        '17',
        proxiesProviderDirectoryName,
      );
      final legacyPath = join(providerDir, url.toMd5());
      final newPath = join(providerDir, '$name@$url'.toMd5());

      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: tempDir.path,
          profileId: 17,
          rawConfig: {
            'proxy-providers': {
              name: {'type': 'http', 'url': url},
            },
          },
          realPatchConfig: const PatchClashConfig(),
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
        ),
      );
      final config = loadYaml(result.yaml) as YamlMap;
      expect(config['proxy-providers'][name]['path'], newPath);
      return (legacyPath: legacyPath, newPath: newPath);
    }

    test('renames a file cached under the legacy url-only key', () async {
      final providerDir = join(
        tempDir.path,
        providersDirectoryName,
        '17',
        proxiesProviderDirectoryName,
      );
      await Directory(providerDir).create(recursive: true);
      final legacyFile = File(join(providerDir, url.toMd5()));
      await legacyFile.writeAsString('cached-provider-data');

      final paths = await runMigration();

      expect(File(paths.newPath).existsSync(), isTrue);
      expect(await File(paths.newPath).readAsString(), 'cached-provider-data');
      expect(File(paths.legacyPath).existsSync(), isFalse);
    });

    test('is a no-op when no legacy file exists', () async {
      final paths = await runMigration();

      expect(File(paths.legacyPath).existsSync(), isFalse);
      expect(File(paths.newPath).existsSync(), isFalse);
    });
  });

  test('log and list tasks produce stable mapped output', () async {
    final logs = [
      const Log(
        logLevel: LogLevel.info,
        payload: 'first',
        dateTime: '2026-07-26 10:00:00',
      ),
      const Log(
        logLevel: LogLevel.error,
        payload: 'second',
        dateTime: '2026-07-26 10:00:01',
      ),
    ];

    final encoded = await encodeLogsTask(logs);

    expect(encoded, contains('first'));
    expect(encoded, contains('\n'));
  });
}
