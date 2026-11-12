import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _fixture = <String, dynamic>{
  'mode': 'rule',
  'port': 7890,
  'socks-port': 7891,
  'redir-port': 7892,
  'mixed-port': 7893,
  'tproxy-port': 7895,
  'ipv6': false,
  'allow-lan': false,
  'log-level': 'silent',
  'find-process-mode': 'always',
  'keep-alive-interval': 15,
  'external-controller': '127.0.0.1:9090',
  'authentication': ['user:pass'],
  'skip-auth-prefixes': ['127.0.0.1/8'],
  'profile': {'store-selected': true},
  'tun': {
    'enable': false,
    'stack': 'mixed',
    'dns-hijack': ['any:53'],
  },
  'sniffer': {'enable': true},
  'dns': {
    'enable': true,
    'nameserver': ['223.5.5.5'],
  },
};

const _page = PatchClashConfig();

Future<YamlMap> _build(
  PatchClashConfig patchConfig, {
  Map<String, dynamic> profile = _fixture,
  List<String> authentication = const [],
}) async {
  final result = await makeRealProfileTask(
    MakeRealProfileState(
      profilesPath: '/profiles',
      profileId: 1,
      rawConfig: profile,
      realPatchConfig: patchConfig,
      appendSystemDns: false,
      proxyGroups: const [],
      rules: const [],
      addedRules: const [],
      defaultUA: 'Flash-Test',
      authentication: authentication,
    ),
  );
  return loadYaml(result.yaml) as YamlMap;
}

PatchClashConfig _following(Iterable<PageConfigKey> keys) =>
    _page.copyWith(followKeys: keys.toSet());

void main() {
  group('page priority', () {
    test('a page control wins over the file for its own field', () async {
      final config = await _build(_page);

      expect(config['mixed-port'], 7890);
      expect(config['port'], 0);
      expect(config['socks-port'], 0);
      expect(config['log-level'], 'error');
      expect(config['find-process-mode'], 'off');
      expect(config['external-controller'], '');
      expect(config['tun']['enable'], false);
      expect(config['tun']['stack'], 'mips');
    });

    test('a followed field takes the file value as written', () async {
      final config = await _build(_following(PageConfigKey.values));

      for (final key in [
        'mode',
        'port',
        'socks-port',
        'redir-port',
        'mixed-port',
        'tproxy-port',
        'allow-lan',
        'log-level',
        'find-process-mode',
        'keep-alive-interval',
        'external-controller',
        'authentication',
      ]) {
        expect(
          const DeepCollectionEquality().equals(config[key], _fixture[key]),
          isTrue,
          reason: key,
        );
      }
      expect(config['tun']['enable'], false);
      expect(config['tun']['stack'], 'mixed');
    });

    test('a followed field the file leaves out stays out', () async {
      final config = await _build(
        _following(PageConfigKey.values),
        profile: const {'mode': 'global'},
      );

      for (final key in [
        'mixed-port',
        'log-level',
        'find-process-mode',
        'allow-lan',
        'external-controller',
        'tun',
        'profile',
        'skip-auth-prefixes',
        'dns',
        'global-ua',
        'hosts',
      ]) {
        expect(config.containsKey(key), isFalse, reason: key);
      }
      expect(config['mode'], 'global');
    });

    test('a page control writes only its field, not the block', () async {
      final config = await _build(
        _page.copyWith(tun: _page.tun.copyWith(enable: true)),
      );

      expect(config['tun']['enable'], true);
      expect(config['tun']['dns-hijack'], ['any:53']);
      expect(config['tun'].containsKey('device'), isFalse);
      expect(config['tun'].containsKey('auto-route'), isFalse);
      expect(config['tun'].containsKey('auto-detect-interface'), isFalse);
    });

    test('the old hidden overrides no longer apply', () async {
      final config = await _build(_page);

      expect(config['profile']['store-selected'], true);
      expect(config['skip-auth-prefixes'], ['127.0.0.1/8']);
      expect(config['sniffer']['enable'], true);
      expect(config['dns']['nameserver'], ['223.5.5.5']);
      expect(config.containsKey('external-ui'), isFalse);
    });

    test('a profile without DNS gets no baseline template', () async {
      final config = await _build(_page, profile: const {'mode': 'rule'});

      expect(config.containsKey('dns'), isFalse);
    });

    test('a false, zero or empty value in the file is kept', () async {
      final config = await _build(
        _following(PageConfigKey.values),
        profile: const {
          'allow-lan': false,
          'port': 0,
          'hosts': <String, dynamic>{},
          'authentication': <String>[],
        },
      );

      expect(config['allow-lan'], false);
      expect(config['port'], 0);
      expect(config['hosts'], isEmpty);
      expect(config['authentication'], isEmpty);
    });

    test('page hosts add entries to the file hosts', () async {
      final config = await _build(
        _page.copyWith(hosts: const {'a.test': '1.1.1.1'}),
        profile: const {
          'hosts': {'b.test': '2.2.2.2'},
        },
      );

      expect(config['hosts']['a.test'], '1.1.1.1');
      expect(config['hosts']['b.test'], '2.2.2.2');
    });

    test('the unix controller stays off, the file cannot open it', () async {
      final config = await _build(
        _following(PageConfigKey.values),
        profile: const {'external-controller-unix': '/tmp/c.sock'},
      );

      expect(config['external-controller-unix'], '');
    });

    test('safe mode keeps the TUN and the controller off', () async {
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 1,
          rawConfig: const {
            'external-controller': '127.0.0.1:9090',
            'tun': {'enable': true},
          },
          realPatchConfig: _following(PageConfigKey.values),
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'Flash-Test',
          safeMode: true,
        ),
      );
      final config = loadYaml(result.yaml) as YamlMap;

      expect(config['external-controller'], '');
      expect(config['tun']['enable'], false);
    });
  });

  group('legacy build until the user confirms', () {
    test('keeps every old override', () async {
      final config = await _build(_page.copyWith(pagePriority: false));

      expect(config['profile']['store-selected'], false);
      expect(config['skip-auth-prefixes'], isEmpty);
      expect(config['tun']['auto-route'], true);
      expect(config['tun']['auto-detect-interface'], true);
      expect(config['find-process-mode'], 'off');
    });

    test('a stored config without the flag reads as legacy', () {
      final stored = PatchClashConfig.fromJson(const {});

      expect(stored.pagePriority, isFalse);
      expect(const PatchClashConfig().pagePriority, isTrue);
    });

    test('follow keys survive a round trip', () {
      final config = _following({
        PageConfigKey.logLevel,
        PageConfigKey.tunEnable,
      });

      final restored = PatchClashConfig.fromJson(
        json.decode(json.encode(config)) as Map<String, Object?>,
      );

      expect(restored.followKeys, config.followKeys);
      expect(restored.pagePriority, isTrue);
    });
  });

  group('follow state', () {
    test('moving a followed control makes it a page setting again', () {
      final followed = _following({PageConfigKey.logLevel});

      final moved = followed.reclaimMoved(
        followed.copyWith(logLevel: LogLevel.debug),
      );

      expect(moved.followKeys, isEmpty);
    });

    test('another control moving leaves the follow alone', () {
      final followed = _following({PageConfigKey.logLevel});

      final moved = followed.reclaimMoved(followed.copyWith(allowLan: true));

      expect(moved.followKeys, {PageConfigKey.logLevel});
    });

    test('a followed live field is left out of the live patch', () {
      final params = _following({PageConfigKey.mode, PageConfigKey.tunEnable})
          .toUpdateParams(
            authentication: const [],
            options: const CoreOptions(testUrl: ''),
            layered: true,
          );
      final patch = params.toJson();

      expect(patch.containsKey('mode'), isFalse);
      expect(patch['tun'], {'stack': 'mips'});
      expect(patch['log-level'], 'error');
    });

    test('the legacy live patch still sends the whole TUN', () {
      final patch = _page
          .toUpdateParams(
            authentication: const [],
            options: const CoreOptions(testUrl: ''),
          )
          .toJson();

      expect(patch['tun']['auto-route'], true);
      expect(patch['mode'], 'rule');
    });
  });
}
