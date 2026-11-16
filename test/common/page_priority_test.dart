import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    loadAppLocalizations(const Locale('zh', 'CN'));
  });

  group('pagePriorityChanges', () {
    const file = {
      'log-level': 'silent',
      'find-process-mode': 'always',
      'mixed-port': 7893,
      'mode': 'rule',
      'profile': {'store-selected': true},
    };
    const page = {
      'log-level': 'info',
      'find-process-mode': 'off',
      'mixed-port': 7893,
      'mode': 'rule',
      'profile': {'store-selected': true},
    };
    const legacy = {
      'log-level': 'info',
      'find-process-mode': 'off',
      'mixed-port': 7893,
      'mode': 'rule',
      'profile': {'store-selected': false},
      'tun': {
        'dns-hijack': ['any:53'],
      },
    };

    test('lists only the page fields that differ from the file', () {
      final changes = pagePriorityChanges(
        legacy: legacy,
        page: page,
        file: file,
      );

      expect(changes.pageRows.map((row) => row.key), [
        PageConfigKey.logLevel,
        PageConfigKey.findProcessMode,
      ]);
    });

    test('lists each hidden override the upgrade drops as old to new', () {
      final changes = pagePriorityChanges(
        legacy: legacy,
        page: page,
        file: file,
      );

      expect(changes.hiddenRows.map((row) => row.path), [
        'profile.store-selected',
        'tun.dns-hijack',
      ]);
      expect(changes.hiddenRows.last.newValue, same(configKeyMissing));
    });

    test('a missing key equal to the kernel default is no difference', () {
      final changes = pagePriorityChanges(
        legacy: const {'allow-lan': false},
        page: const {'allow-lan': false},
        file: const {},
      );

      expect(changes.pageRows, isEmpty);
      expect(changes.hiddenRows, isEmpty);
    });

    test('nothing to change leaves both lists empty', () {
      final changes = pagePriorityChanges(legacy: file, page: file, file: file);

      expect(changes.pageRows, isEmpty);
      expect(changes.hiddenRows, isEmpty);
    });
  });

  group('describeConfigValue', () {
    test('uses the field translation, not on and off', () {
      expect(describeConfigValue('log-level', 'silent'), '静默');
      expect(describeConfigValue('find-process-mode', 'always'), '总是');
      expect(describeConfigValue('find-process-mode', 'strict'), '按需');
      expect(describeConfigValue('mode', 'rule'), '规则');
      expect(describeConfigValue('external-controller', ''), '关闭');
    });

    test('tells a missing key from an explicit empty one', () {
      expect(describeConfigValue('external-ui', configKeyMissing), '未填写');
      expect(describeConfigValue('log-level', configKeyMissing), '未填写，默认 信息');
      expect(
        describeConfigValue('log-level', configKeyMissing, withDefault: false),
        '未填写',
      );
      expect(describeConfigValue('skip-auth-prefixes', const []), '空列表');
      expect(describeConfigValue('dns.fallback-filter', const {}), '空对象');
      expect(describeConfigValue('external-ui', ''), '空文本');
      expect(describeConfigValue('external-ui', null), '空值（null）');
      expect(describeConfigValue('allow-lan', false), '关闭');
      expect(describeConfigValue('allow-lan', true), '开启');
      expect(describeConfigValue('port', 0), '0');
    });

    test('shows a credential by its user name only', () {
      expect(describeConfigValue('authentication', ['ann:secret']), 'ann');
    });
  });

  test('configPathLabel names a hidden key in user terms', () {
    expect(configPathLabel('profile.store-selected'), '记住节点选择');
    expect(configPathLabel('external-ui'), '外部控制面板');
    expect(configPathLabel('tun.dns-hijack'), 'DNS劫持');
    expect(configPathLabel('routing-mark'), '路由标记');
    expect(configPathLabel('dns.enhanced-mode'), 'DNS 设置 · enhanced-mode');
  });

  test('controllerHostPort keeps only the host and port', () {
    expect(controllerHostPort('0.0.0.0:9090'), '0.0.0.0:9090');
    expect(
      controllerHostPort('http://u:p@10.0.0.2:9090/x?k=1'),
      '10.0.0.2:9090',
    );
    expect(controllerHostPort('[::]:9090'), '[::]:9090');
    expect(controllerHostPort(':9090'), ':9090');
  });

  group('exposesControllerWithoutSecret', () {
    test('refuses a controller open beyond this machine with no secret', () {
      expect(
        exposesControllerWithoutSecret({'external-controller': ':9090'}),
        isTrue,
      );
      expect(
        exposesControllerWithoutSecret({
          'external-controller': '0.0.0.0:9090',
          'secret': '',
        }),
        isTrue,
      );
    });

    test('allows loopback, a secret, or no controller', () {
      expect(
        exposesControllerWithoutSecret({
          'external-controller': '127.0.0.1:9090',
        }),
        isFalse,
      );
      expect(
        exposesControllerWithoutSecret({'external-controller': '[::1]:9090'}),
        isFalse,
      );
      expect(
        exposesControllerWithoutSecret({
          'external-controller': '0.0.0.0:9090',
          'secret': 's',
        }),
        isFalse,
      );
      expect(exposesControllerWithoutSecret(const {}), isFalse);
    });
  });

  test('builtInboundsOf reads the inbounds the config asks for', () {
    expect(builtInboundsOf('mixed-port: 7893\ntun: {enable: true}\n'), {
      'mixed-port': 7893,
      'tun.enable': true,
    });
    expect(builtInboundsOf(''), isEmpty);
  });

  test('builtFindProcessModeOf reads the mode mihomo runs the config with', () {
    expect(builtFindProcessModeOf('find-process-mode: always\n'), 'always');
    expect(builtFindProcessModeOf('find-process-mode: OFF\n'), 'off');
    expect(builtFindProcessModeOf('mode: rule\n'), 'strict');
    expect(builtFindProcessModeOf('find-process-mode: sometimes\n'), isNull);
    expect(builtFindProcessModeOf('find-process-mode: 1\n'), isNull);
    expect(builtFindProcessModeOf(''), isNull);
  });
}
