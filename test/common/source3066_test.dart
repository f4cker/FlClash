import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

MakeRealProfileState fixture(PatchClashConfig page) => MakeRealProfileState(
  profilesPath: '/synthetic-only',
  profileId: 1,
  rawConfig: const {},
  realPatchConfig: page,
  appendSystemDns: false,
  proxyGroups: const [],
  rules: const [],
  addedRules: const [],
  defaultUA: 'synthetic',
);

void main() {
  test('saved page false, zero and defaults beat file and obsolete flags', () {
    final page = const PatchClashConfig().copyWith(
      pagePriority: false,
      followKeys: PageConfigKey.values.toSet(),
      port: 0,
      allowLan: false,
    );
    final config = <String, dynamic>{
      'port': 1234,
      'allow-lan': true,
      'log-level': 'debug',
      'tun': {'enable': true, 'stack': 'mixed'},
    };
    applyPageSettings(config, fixture(page));
    expect(config['port'], 0);
    expect(config['allow-lan'], false);
    expect(config['log-level'], 'error');
    expect(config['tun']['enable'], false);
    expect(config['tun']['stack'], 'mips');
  });

  test(
    'uncontrolled file children retain false, zero and empty collections',
    () {
      final config = <String, dynamic>{
        'profile': {'store-selected': false},
        'tun': {
          'auto-route': false,
          'auto-detect-interface': false,
          'file-only-zero': 0,
          'file-only-list': <String>[],
          'file-only-map': <String, dynamic>{},
        },
      };
      applyPageSettings(config, fixture(const PatchClashConfig()));
      expect(config['profile'], {'store-selected': false});
      expect(config['tun']['auto-route'], false);
      expect(config['tun']['auto-detect-interface'], false);
      expect(config['tun']['file-only-zero'], 0);
      expect(config['tun']['file-only-list'], isEmpty);
      expect(config['tun']['file-only-map'], isEmpty);
      expect(config['tun'].containsKey('device'), isFalse);
    },
  );

  test(
    'missing uncontrolled key stays absent for kernel default resolution',
    () {
      final config = <String, dynamic>{};
      applyPageSettings(config, fixture(const PatchClashConfig()));
      expect(config.containsKey('profile'), isFalse);
      expect(config['tun'].containsKey('auto-route'), isFalse);
      expect(readConfigPath(config, 'tun.auto-route'), same(configKeyMissing));
      expect(kernelDefaults['tun.auto-route'], true);
    },
  );

  test('live page fields are sent despite obsolete source flags', () {
    final page = const PatchClashConfig().copyWith(
      pagePriority: false,
      followKeys: PageConfigKey.values.toSet(),
    );
    final patch = page
        .toUpdateParams(
          authentication: const [],
          options: const CoreOptions(testUrl: ''),
          layered: true,
        )
        .toJson();
    expect(patch['allow-lan'], false);
    expect(patch['mode'], 'rule');
    expect(patch['tun'], {'enable': false, 'stack': 'mips'});
    expect(patch['ipv6'], false);
  });

  test('controller without authentication is explicitly rejected', () {
    final page = const PatchClashConfig().copyWith(
      externalController: ExternalControllerStatus.open,
      secret: '',
    );
    expect(
      () => applyPageSettings(<String, dynamic>{}, fixture(page)),
      throwsStateError,
    );
  });
  test(
    'DNS exact page children win while unowned nested values survive',
    () async {
      final raw = <String, dynamic>{
        'dns': {
          'enable': false,
          'ipv6': true,
          'fake-ip-range': '',
          'fake-ip-ttl': 0,
          'nameserver-policy': <String, dynamic>{},
          'fallback-filter': {'geoip': false, 'domain': <String>[]},
        },
      };
      final state = fixture(const PatchClashConfig()).copyWith(rawConfig: raw);
      final built = await makeRealProfileTask(state);
      final config = loadYaml(built.yaml) as YamlMap;
      expect(config['dns']['enable'], false);
      expect(config['dns']['ipv6'], false);
      expect(config['dns']['fake-ip-range'], '');
      expect(config['dns']['fake-ip-ttl'], 0);
      expect(config['dns']['nameserver-policy'], isEmpty);
      expect(config['dns']['fallback-filter'], {'geoip': false, 'domain': []});
      expect((raw['dns'] as Map)['ipv6'], true);
    },
  );
  test('unsupported endpoints reject and explicit empty endpoints survive', () {
    for (final key in [
      'external-controller-tls',
      'external-controller-unix',
      'external-controller-pipe',
    ]) {
      expect(
        () => applyPageSettings(<String, dynamic>{
          key: '/synthetic',
        }, fixture(const PatchClashConfig())),
        throwsStateError,
      );
      final empty = <String, dynamic>{key: ''};
      applyPageSettings(empty, fixture(const PatchClashConfig()));
      expect(empty[key], '');
    }
  });

  test(
    'safe mode isolates enabled invalid iptables before validation',
    () async {
      final data = fixture(const PatchClashConfig()).copyWith(
        safeMode: true,
        rawConfig: {
          'iptables': {'enable': true, 'inbound-interface': 'a b'},
        },
      );
      final built = await makeRealProfileTask(data);
      expect(loadYaml(built.yaml)['iptables'], {'enable': false});
    },
  );

  test(
    'disabled iptables keeps all fields; enabled invalid interface rejects',
    () {
      final config = <String, dynamic>{
        'iptables': {'enable': false, 'inbound-interface': 'a b', 'sibling': 0},
        'hosts': {'file.test': '1.2.3.4'},
      };
      applyPageSettings(config, fixture(const PatchClashConfig()));
      expect(config['iptables'], {
        'enable': false,
        'inbound-interface': 'a b',
        'sibling': 0,
      });
      expect(config['hosts'], isEmpty);
      expect(
        () => applyPageSettings(<String, dynamic>{
          'iptables': {'enable': true, 'inbound-interface': 'a b'},
        }, fixture(const PatchClashConfig())),
        throwsStateError,
      );
    },
  );
}
