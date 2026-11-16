import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/system_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

// Flash's restore-only-own system proxy (ported from the removed `proxy`
// plugin's tests). Every command goes to a fake runner; nothing touches the
// system.

void main() {
  group('macOS proxy snapshot and restore', () {
    final applied = MacosServiceProxy.applied(7890, const ['localhost']);
    final manual = MacosAppliedProxy.manual(7890, const ['localhost']);
    final clashMac = MacosServiceProxy(
      web: const MacosProxyEndpoint(
        enabled: true,
        host: '127.0.0.1',
        port: 7893,
      ),
      secure: const MacosProxyEndpoint(
        enabled: true,
        host: '127.0.0.1',
        port: 7893,
      ),
      socks: const MacosProxyEndpoint(
        enabled: true,
        host: '127.0.0.1',
        port: 7893,
      ),
      bypassDomain: const ['localhost', '*.local'],
      auto: MacosAutoProxy.off,
    );
    final unset = MacosServiceProxy(
      web: const MacosProxyEndpoint(enabled: false, host: '', port: 0),
      secure: const MacosProxyEndpoint(enabled: false, host: '', port: 0),
      socks: const MacosProxyEndpoint(enabled: false, host: '', port: 0),
      bypassDomain: const [],
      auto: MacosAutoProxy.off,
    );

    test('parses what networksetup prints for a proxy', () {
      expect(
        MacosProxyEndpoint.parse(
          'Enabled: Yes\nServer: 127.0.0.1\nPort: 7893\n'
          'Authenticated Proxy Enabled: 0\n',
        ),
        const MacosProxyEndpoint(enabled: true, host: '127.0.0.1', port: 7893),
      );
      expect(
        MacosProxyEndpoint.parse(
          'Enabled: No\nServer: \nPort: 0\nAuthenticated Proxy Enabled: 0\n',
        ),
        const MacosProxyEndpoint(enabled: false, host: '', port: 0),
      );
      expect(MacosProxyEndpoint.parse('** Error: unknown service'), isNull);
    });

    test('parses the bypass list and its empty message', () {
      expect(MacosProxyCommands.parseBypassDomains('localhost\n*.local\n\n'), [
        'localhost',
        '*.local',
      ]);
      expect(
        MacosProxyCommands.parseBypassDomains(
          "There aren't any bypass domains set on Tailscale.\n",
        ),
        isEmpty,
      );
    });

    test('compares bypass lists regardless of order', () {
      expect(
        MacosServiceProxy.applied(7890, const ['a', 'b']),
        MacosServiceProxy.applied(7890, const ['b', 'a']),
      );
      expect(
        MacosServiceProxy.applied(7890, const ['a']),
        isNot(MacosServiceProxy.applied(7890, const ['a', 'b'])),
      );
    });

    test('restores only services still holding what Flash applied', () {
      final plan = MacosProxyCommands.restorePlan(
        before: {'Wi-Fi': clashMac, 'Ethernet': unset, 'iPhone USB': unset},
        applied: manual,
        current: {'Wi-Fi': applied, 'Ethernet': clashMac},
      );

      expect(plan, {'Wi-Fi': clashMac});
    });

    test('leaves a service whose proxy moved to another port alone', () {
      final moved = MacosServiceProxy.applied(7891, const ['localhost']);
      final plan = MacosProxyCommands.restorePlan(
        before: {'Wi-Fi': clashMac},
        applied: manual,
        current: {'Wi-Fi': moved},
      );

      expect(plan, isEmpty);
    });

    test('leaves a service whose bypass list was edited alone', () {
      final plan = MacosProxyCommands.restorePlan(
        before: {'Wi-Fi': clashMac},
        applied: manual,
        current: {
          'Wi-Fi': MacosServiceProxy.applied(7890, const ['localhost', 'x']),
        },
      );

      expect(plan, isEmpty);
    });

    test('leaves a service with one proxy turned off since alone', () {
      final current = MacosServiceProxy(
        web: applied.web,
        secure: applied.secure,
        socks: const MacosProxyEndpoint(
          enabled: false,
          host: '127.0.0.1',
          port: 7890,
        ),
        bypassDomain: applied.bypassDomain,
      );
      final plan = MacosProxyCommands.restorePlan(
        before: {'Wi-Fi': clashMac},
        applied: manual,
        current: {'Wi-Fi': current},
      );

      expect(plan, isEmpty);
    });

    test('puts back servers, bypass list, then each state', () {
      final commands = MacosProxyCommands.buildRestore('Wi-Fi', clashMac);

      expect(
        [for (final command in commands) command.args],
        [
          ['-setwebproxy', 'Wi-Fi', '127.0.0.1', '7893'],
          ['-setsecurewebproxy', 'Wi-Fi', '127.0.0.1', '7893'],
          ['-setsocksfirewallproxy', 'Wi-Fi', '127.0.0.1', '7893'],
          ['-setproxybypassdomains', 'Wi-Fi', 'localhost', '*.local'],
          ['-setwebproxystate', 'Wi-Fi', 'on'],
          ['-setsecurewebproxystate', 'Wi-Fi', 'on'],
          ['-setsocksfirewallproxystate', 'Wi-Fi', 'on'],
          ['-setautoproxystate', 'Wi-Fi', 'off'],
        ],
      );
    });

    test('turns a proxy that had no server back off', () {
      final commands = MacosProxyCommands.buildRestore('Ethernet', unset);

      expect(
        [for (final command in commands) command.args],
        [
          ['-setproxybypassdomains', 'Ethernet', 'Empty'],
          ['-setwebproxystate', 'Ethernet', 'off'],
          ['-setsecurewebproxystate', 'Ethernet', 'off'],
          ['-setsocksfirewallproxystate', 'Ethernet', 'off'],
          ['-setautoproxystate', 'Ethernet', 'off'],
        ],
      );
    });

    test('a snapshot survives a JSON round trip', () {
      final snapshot = SystemProxySnapshot(
        services: {'Wi-Fi': clashMac, 'Ethernet': unset},
        port: 7890,
        bypassDomain: const ['localhost'],
      );

      final restored = SystemProxySnapshot.fromJson(
        json.decode(json.encode(snapshot.toJson())),
      );

      expect(restored?.services, snapshot.services);
      expect(restored?.port, 7890);
      expect(restored?.bypassDomain, ['localhost']);
      expect(SystemProxySnapshot.fromJson({'port': 1}), isNull);
    });

    group('MacosProxy', () {
      late Map<String, MacosServiceProxy> system;
      late List<List<String>> writes;
      late Set<String> unreadable;

      String endpointText(MacosProxyEndpoint endpoint) =>
          'Enabled: ${endpoint.enabled ? 'Yes' : 'No'}\n'
          'Server: ${endpoint.host}\nPort: ${endpoint.port}\n'
          'Authenticated Proxy Enabled: 0\n';

      String autoText(MacosAutoProxy? auto) =>
          'URL: ${(auto?.url ?? '').isEmpty ? '(null)' : auto!.url}\n'
          'Enabled: ${auto?.enabled == true ? 'Yes' : 'No'}\n';

      MacosProxy macosProxy() {
        return MacosProxy(
          commandRunner: ProxyCommandRunner((
            executable,
            arguments, {
            runInShell = false,
          }) async {
            final [command, ...rest] = arguments;
            if (command == '-listallnetworkservices') {
              return ProcessResult(
                0,
                0,
                'An asterisk (*) denotes that a network service is disabled.\n'
                    '${system.keys.join('\n')}\n',
                '',
              );
            }
            final service = rest.first;
            if (command.startsWith('-get')) {
              final settings = system[service];
              if (settings == null || unreadable.contains(service)) {
                return ProcessResult(0, 4, '', 'not a service');
              }
              return ProcessResult(0, 0, switch (command) {
                '-getwebproxy' => endpointText(settings.web),
                '-getsecurewebproxy' => endpointText(settings.secure),
                '-getsocksfirewallproxy' => endpointText(settings.socks),
                '-getautoproxyurl' => autoText(settings.auto),
                _ =>
                  settings.bypassDomain.isEmpty
                      ? "There aren't any bypass domains set on $service.\n"
                      : '${settings.bypassDomain.join('\n')}\n',
              }, '');
            }
            writes.add(arguments);
            return ProcessResult(0, 0, '', '');
          }),
        );
      }

      setUp(() {
        system = {'Wi-Fi': clashMac, 'Tailscale': unset};
        writes = [];
        unreadable = {};
      });

      test('reads every service', () async {
        expect(await macosProxy().read(), {
          'Wi-Fi': clashMac,
          'Tailscale': unset,
        });
        expect(writes, isEmpty);
      });

      test('reads nothing when one service cannot be read', () async {
        unreadable.add('Tailscale');

        expect(await macosProxy().read(), isNull);
      });

      test('restores a service Flash still holds', () async {
        system['Wi-Fi'] = applied;

        final ok = await macosProxy().restore({
          'Wi-Fi': clashMac,
          'Tailscale': unset,
        }, manual);

        expect(ok, isTrue);
        expect(writes.map((args) => args[1]).toSet(), {'Wi-Fi'});
        expect(writes.first, ['-setwebproxy', 'Wi-Fi', '127.0.0.1', '7893']);
      });

      test('writes nothing when another app took over', () async {
        system['Wi-Fi'] = MacosServiceProxy.applied(7897, const []);

        final ok = await macosProxy().restore({'Wi-Fi': clashMac}, manual);

        expect(ok, isTrue);
        expect(writes, isEmpty);
      });

      test('reports a service it could not read and leaves it', () async {
        system['Wi-Fi'] = applied;
        unreadable.add('Wi-Fi');

        final ok = await macosProxy().restore({'Wi-Fi': clashMac}, manual);

        expect(ok, isFalse);
        expect(writes, isEmpty);
      });

      test('skips a service that is gone', () async {
        final ok = await macosProxy().restore({'USB LAN': clashMac}, manual);

        expect(ok, isTrue);
        expect(writes, isEmpty);
      });
    });
  });

  group('automatic proxy and PAC', () {
    const off = MacosProxyEndpoint(enabled: false, host: '', port: 0);
    const userPac = MacosAutoProxy(
      enabled: true,
      url: 'http://wpad.example/proxy.pac',
    );
    const flashPac = MacosAutoProxy(
      enabled: true,
      url: 'http://127.0.0.1:53111/flclash.pac?v=3',
    );
    final userManual = MacosServiceProxy(
      web: const MacosProxyEndpoint(
        enabled: true,
        host: '10.0.0.2',
        port: 8080,
      ),
      secure: const MacosProxyEndpoint(
        enabled: true,
        host: '10.0.0.2',
        port: 8080,
      ),
      socks: off,
      bypassDomain: const ['*.corp'],
      auto: MacosAutoProxy.off,
    );
    final withUserPac = MacosServiceProxy(
      web: off,
      secure: off,
      socks: off,
      bypassDomain: const [],
      auto: userPac,
    );

    test('parses what networksetup prints for the automatic proxy', () {
      expect(
        MacosAutoProxy.parse(
          'URL: http://wpad.example/proxy.pac\nEnabled: Yes\n',
        ),
        userPac,
      );
      expect(
        MacosAutoProxy.parse('URL: (null)\nEnabled: No\n'),
        MacosAutoProxy.off,
      );
      expect(MacosAutoProxy.parse('** Error'), isNull);
    });

    test('recognises only the PAC script Flash serves', () {
      expect(flashPac.isFlashPac, isTrue);
      expect(userPac.isFlashPac, isFalse);
      expect(
        const MacosAutoProxy(
          enabled: false,
          url: 'http://127.0.0.1:53111/flclash.pac?v=3',
        ).isFlashPac,
        isFalse,
      );
    });

    test('a manual start that turned a user PAC off puts it back', () {
      final current = MacosServiceProxy(
        web: const MacosProxyEndpoint(
          enabled: true,
          host: '127.0.0.1',
          port: 7890,
        ),
        secure: const MacosProxyEndpoint(
          enabled: true,
          host: '127.0.0.1',
          port: 7890,
        ),
        socks: const MacosProxyEndpoint(
          enabled: true,
          host: '127.0.0.1',
          port: 7890,
        ),
        bypassDomain: const ['localhost'],
        auto: const MacosAutoProxy(
          enabled: false,
          url: 'http://wpad.example/proxy.pac',
        ),
      );
      final plan = MacosProxyCommands.restorePlan(
        before: {'Wi-Fi': withUserPac},
        applied: MacosAppliedProxy.manual(7890, const ['localhost', '<local>']),
        current: {'Wi-Fi': current},
      );
      expect(plan, {'Wi-Fi': withUserPac});
      expect(
        [
          for (final command in MacosProxyCommands.buildRestore(
            'Wi-Fi',
            withUserPac,
          ))
            command.args,
        ],
        [
          ['-setproxybypassdomains', 'Wi-Fi', 'Empty'],
          ['-setautoproxyurl', 'Wi-Fi', 'http://wpad.example/proxy.pac'],
          ['-setwebproxystate', 'Wi-Fi', 'off'],
          ['-setsecurewebproxystate', 'Wi-Fi', 'off'],
          ['-setsocksfirewallproxystate', 'Wi-Fi', 'off'],
          ['-setautoproxystate', 'Wi-Fi', 'on'],
        ],
      );
    });

    test('a manual start leaves a service whose PAC was turned on alone', () {
      final current = MacosServiceProxy(
        web: const MacosProxyEndpoint(
          enabled: true,
          host: '127.0.0.1',
          port: 7890,
        ),
        secure: const MacosProxyEndpoint(
          enabled: true,
          host: '127.0.0.1',
          port: 7890,
        ),
        socks: const MacosProxyEndpoint(
          enabled: true,
          host: '127.0.0.1',
          port: 7890,
        ),
        bypassDomain: const ['localhost'],
        auto: userPac,
      );
      expect(
        MacosProxyCommands.restorePlan(
          before: {'Wi-Fi': userManual},
          applied: MacosAppliedProxy.manual(7890, const ['localhost']),
          current: {'Wi-Fi': current},
        ),
        isEmpty,
      );
    });

    test('a PAC start is undone only while Flash\'s script is in place', () {
      MacosServiceProxy pacOver(
        MacosServiceProxy before,
        MacosAutoProxy auto,
      ) => MacosServiceProxy(
        web: before.web.disabled(),
        secure: before.secure.disabled(),
        socks: before.socks.disabled(),
        bypassDomain: before.bypassDomain,
        auto: auto,
      );
      const applied = MacosAppliedProxy.pac();
      expect(
        MacosProxyCommands.restorePlan(
          before: {'Wi-Fi': userManual},
          applied: applied,
          current: {'Wi-Fi': pacOver(userManual, flashPac)},
        ),
        {'Wi-Fi': userManual},
      );
      expect(
        MacosProxyCommands.restorePlan(
          before: {'Wi-Fi': userManual},
          applied: applied,
          current: {'Wi-Fi': pacOver(userManual, userPac)},
        ),
        isEmpty,
      );
      expect(
        MacosProxyCommands.restorePlan(
          before: {'Wi-Fi': userManual},
          applied: applied,
          current: {
            'Wi-Fi': MacosServiceProxy(
              web: userManual.web,
              secure: userManual.secure.disabled(),
              socks: userManual.socks.disabled(),
              bypassDomain: userManual.bypassDomain,
              auto: flashPac,
            ),
          },
        ),
        isEmpty,
      );
    });

    test('snapshots from before the automatic proxy was read still load', () {
      final legacy = SystemProxySnapshot.fromJson({
        'services': {
          'Wi-Fi': {
            'web': {'enabled': false, 'host': '', 'port': 0},
            'secure': {'enabled': false, 'host': '', 'port': 0},
            'socks': {'enabled': false, 'host': '', 'port': 0},
            'bypassDomain': <String>[],
          },
        },
        'port': 7890,
        'bypassDomain': ['localhost'],
      });
      expect(legacy, isNotNull);
      expect(legacy!.pac, isFalse);
      expect(legacy.services!['Wi-Fi']!.auto, isNull);
      expect(
        MacosProxyCommands.buildRestore(
          'Wi-Fi',
          legacy.services!['Wi-Fi']!,
        ).where((command) => command.args.first.contains('autoproxy')),
        isEmpty,
      );
      final pac = SystemProxySnapshot(
        services: {'Wi-Fi': withUserPac},
        port: 7890,
        bypassDomain: const [],
        pac: true,
      );
      final restored = SystemProxySnapshot.fromJson(
        json.decode(json.encode(pac.toJson())),
      );
      expect(restored!.pac, isTrue);
      expect(restored.services, pac.services);
    });
  });

  group('Proxy', () {
    test('starts through the native bridge with the PAC script', () async {
      final started = <(int, List<String>, String?)>[];
      final proxy = Proxy(
        isMacOS: false,
        start: (port, bypass, pac) async {
          started.add((port, bypass, pac));
          return true;
        },
        stop: () async => true,
      );
      expect(await proxy.startProxy(0), isFalse);
      expect(await proxy.startProxy(65536), isFalse);
      expect(await proxy.startProxy(7890, const ['a'], 'script'), isTrue);
      expect(started, [
        (7890, const ['a'], 'script'),
      ]);
    });

    test('macOS never stops blindly; elsewhere a restore stops', () async {
      var stops = 0;
      Proxy proxy(bool isMacOS) => Proxy(
        isMacOS: isMacOS,
        start: (_, _, _) async => true,
        stop: () async {
          stops++;
          return true;
        },
        processRunner: (executable, arguments, {runInShell = false}) async =>
            ProcessResult(0, 1, '', 'unexpected'),
      );
      expect(await proxy(true).stopProxy(), isFalse);
      expect(stops, 0);
      final snapshot = await proxy(false).snapshotProxy(7890, const [], 'x');
      expect(snapshot!.restorable, isFalse);
      expect(snapshot.pac, isTrue);
      expect(await proxy(false).restoreProxy(snapshot), isTrue);
      expect(stops, 1);
    });
  });
}
