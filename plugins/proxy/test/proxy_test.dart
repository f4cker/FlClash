import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy.dart';
import 'package:proxy/proxy_method_channel.dart';
import 'package:proxy/src/linux_proxy.dart';
import 'package:proxy/src/macos_proxy.dart';
import 'package:proxy/src/proxy_command.dart';
import 'package:proxy/src/windows_proxy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Proxy', () {
    test('rejects ports outside the TCP port range', () async {
      final proxy = Proxy(
        processRunner: (executable, arguments, {runInShell = false}) async {
          fail('invalid ports must not execute platform commands');
        },
      );

      expect(await proxy.startProxy(0), isFalse);
      expect(await proxy.startProxy(65536), isFalse);
    });
  });

  group('ProxyCommandRunner', () {
    test('treats an empty command set as failure', () async {
      final runner = ProxyCommandRunner((
        executable,
        arguments, {
        runInShell = false,
      }) async {
        fail('empty command sets must not start a process');
      });

      expect(await runner.run(const []), isFalse);
    });

    test('stops after the first failed command', () async {
      var callCount = 0;
      final runner = ProxyCommandRunner((
        executable,
        arguments, {
        runInShell = false,
      }) async {
        callCount++;
        return ProcessResult(callCount, callCount == 1 ? 1 : 0, '', '');
      });

      final result = await runner.run([
        ProxyCommand('first', const []),
        ProxyCommand('second', const []),
      ]);

      expect(result, isFalse);
      expect(callCount, 1);
    });

    test('converts process launch failures to false', () async {
      final runner = ProxyCommandRunner((
        executable,
        arguments, {
        runInShell = false,
      }) async {
        throw ProcessException(executable, arguments);
      });

      expect(await runner.run([ProxyCommand('missing', const [])]), isFalse);
    });

    test('carries on past an optional command that fails', () async {
      final started = <String>[];
      final runner = ProxyCommandRunner((
        executable,
        arguments, {
        runInShell = false,
      }) async {
        started.add(executable);
        if (executable == 'missing') {
          throw ProcessException(executable, arguments);
        }
        return ProcessResult(0, executable == 'refused' ? 1 : 0, '', '');
      });

      final result = await runner.run([
        ProxyCommand('missing', const [], optional: true),
        ProxyCommand('refused', const [], optional: true),
        ProxyCommand('last', const []),
      ]);

      expect(result, isTrue);
      expect(started, ['missing', 'refused', 'last']);
    });
  });

  group('Linux proxy command builders', () {
    test(
      'checks each fallback command only once for unknown desktops',
      () async {
        final checkedExecutables = <String>[];
        final executedCommands = <String>[];
        final proxy = LinuxProxy(
          commandRunner: ProxyCommandRunner((
            executable,
            arguments, {
            runInShell = false,
          }) async {
            executedCommands.add(executable);
            return ProcessResult(1, 0, '', '');
          }),
          executableChecker: (executable) async {
            checkedExecutables.add(executable);
            return executable == 'kwriteconfig5';
          },
        );

        final result = await proxy.start(
          7890,
          const ['localhost'],
          desktop: 'UNKNOWN',
          homeDir: '/home/user',
        );

        expect(result, isTrue);
        expect(checkedExecutables, [
          'gsettings',
          'kwriteconfig6',
          'kwriteconfig5',
        ]);
        expect(executedCommands.toSet(), {'kwriteconfig5', 'dbus-send'});
      },
    );

    test('builds GNOME commands without duplicate port writes', () {
      final commands = LinuxProxyCommands.buildStart(
        port: 7890,
        bypassDomain: ['localhost', '127.0.0.1'],
        desktop: 'GNOME',
        homeDir: '/home/user',
      );

      final portCommands = commands.where(
        (command) => command.args.length == 4 && command.args[2] == 'port',
      );
      final hostCommands = commands.where(
        (command) => command.args.length == 4 && command.args[2] == 'host',
      );

      expect(portCommands, hasLength(3));
      expect(hostCommands, hasLength(3));
      expect(commands.last.args, [
        'set',
        'org.gnome.system.proxy',
        'mode',
        'manual',
      ]);
      expect(
        commands
            .singleWhere(
              (command) =>
                  command.args.contains('org.gnome.system.proxy') &&
                  command.args.contains('ignore-hosts'),
            )
            .args
            .last,
        "['localhost', '127.0.0.1']",
      );
    });

    test('builds empty GNOME ignore-hosts as an empty list', () {
      final commands = LinuxProxyCommands.buildStart(
        port: 7890,
        bypassDomain: const [],
        desktop: 'GNOME',
        homeDir: '/home/user',
      );

      expect(
        commands
            .singleWhere(
              (command) =>
                  command.args.contains('org.gnome.system.proxy') &&
                  command.args.contains('ignore-hosts'),
            )
            .args
            .last,
        '[]',
      );
    });

    test('escapes backslashes and quotes in GNOME ignore-hosts', () {
      final commands = LinuxProxyCommands.buildStart(
        port: 7890,
        bypassDomain: [r'local\host', "it's"],
        desktop: 'GNOME',
        homeDir: '/home/user',
      );

      expect(
        commands
            .singleWhere((command) => command.args.contains('ignore-hosts'))
            .args
            .last,
        r"['local\\host', 'it\'s']",
      );
    });

    test('builds MATE commands with MATE proxy schema', () {
      final commands = LinuxProxyCommands.buildStart(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'MATE',
        homeDir: '/home/user',
      );

      expect(
        commands.any(
          (command) => command.args.contains('org.mate.system.proxy'),
        ),
        isTrue,
      );
      expect(
        commands.any(
          (command) => command.args.contains('org.gnome.system.proxy'),
        ),
        isFalse,
      );
    });

    test('falls back to GNOME gsettings commands for XFCE when available', () {
      final commands = LinuxProxyCommands.buildStart(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'XFCE',
        homeDir: '/home/user',
        availableExecutables: {'gsettings'},
      );

      expect(commands.map((command) => command.executable).toSet(), {
        'gsettings',
      });
      expect(
        commands.any(
          (command) =>
              command.args.contains('org.gnome.system.proxy') &&
              command.args.contains('manual'),
        ),
        isTrue,
      );
    });

    test('prefers kwriteconfig6 for KDE when available', () {
      final commands = LinuxProxyCommands.buildStart(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'KDE',
        homeDir: '/home/user',
        availableExecutables: {'kwriteconfig6', 'kwriteconfig5'},
      );

      expect(commands.map((command) => command.executable).toSet(), {
        'kwriteconfig6',
        'dbus-send',
      });
    });

    test('points every KDE proxy at the plain HTTP or SOCKS listener and '
        'tells running KIO programs to reload', () {
      for (final commands in [
        LinuxProxyCommands.buildStart(
          port: 7890,
          bypassDomain: ['localhost'],
          desktop: 'KDE',
          homeDir: '/home/user',
          availableExecutables: {'kwriteconfig6'},
        ),
        LinuxProxyCommands.buildStop(
          desktop: 'KDE',
          homeDir: '/home/user',
          availableExecutables: {'kwriteconfig6'},
        ),
      ]) {
        final reload = commands.last;
        expect(reload.executable, 'dbus-send');
        expect(reload.args, [
          '--session',
          '--type=signal',
          '/KIO/Scheduler',
          'org.kde.KIO.Scheduler.reparseSlaveConfiguration',
          'string:',
        ]);
        expect(reload.optional, isTrue);
      }
      final proxies = {
        for (final command in LinuxProxyCommands.buildStart(
          port: 7890,
          bypassDomain: ['localhost'],
          desktop: 'KDE',
          homeDir: '/home/user',
          availableExecutables: {'kwriteconfig6'},
        ))
          if (command.args.length > 6 && command.args[5].endsWith('Proxy'))
            command.args[5]: command.args[6],
      };
      expect(proxies, {
        'httpProxy': 'http://127.0.0.1:7890',
        'httpsProxy': 'http://127.0.0.1:7890',
        'socksProxy': 'socks://127.0.0.1:7890',
      });
    });

    test(
      'falls back to kwriteconfig5 for KDE when kwriteconfig6 is missing',
      () {
        final commands = LinuxProxyCommands.buildStart(
          port: 7890,
          bypassDomain: ['localhost'],
          desktop: 'KDE',
          homeDir: '/home/user',
          availableExecutables: {'kwriteconfig5'},
        );

        expect(commands.map((command) => command.executable).toSet(), {
          'kwriteconfig5',
          'dbus-send',
        });
      },
    );

    test('uses available backend for unknown desktops', () {
      final commands = LinuxProxyCommands.buildStart(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'UNKNOWN',
        homeDir: '/home/user',
        availableExecutables: {'kwriteconfig5'},
      );

      expect(commands.map((command) => command.executable).toSet(), {
        'kwriteconfig5',
        'dbus-send',
      });
    });

    test('does not use an unrelated backend for a known desktop', () {
      final commands = LinuxProxyCommands.buildStart(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'KDE',
        homeDir: '/home/user',
        availableExecutables: {'gsettings'},
      );

      expect(commands, isEmpty);
    });
  });

  group('macOS proxy command builders', () {
    test(
      'filters networksetup service list headers, disabled services, and blanks',
      () {
        final services = MacosProxyCommands.parseNetworkServices('''
An asterisk (*) denotes that a network service is disabled.
Wi-Fi
*Thunderbolt Bridge
USB 10/100/1000 LAN

''');

        expect(services, ['Wi-Fi', 'USB 10/100/1000 LAN']);
      },
    );

    test('passes bypass domains as separate networksetup arguments', () {
      final command = MacosProxyCommands.buildProxyBypass('Wi-Fi', [
        'localhost',
        '127.0.0.1',
      ]);

      expect(command.executable, '/usr/sbin/networksetup');
      expect(command.args, [
        '-setproxybypassdomains',
        'Wi-Fi',
        'localhost',
        '127.0.0.1',
      ]);
    });

    test('uses Empty when clearing bypass domains', () {
      final command = MacosProxyCommands.buildProxyBypass('Wi-Fi', const []);

      expect(command.args, ['-setproxybypassdomains', 'Wi-Fi', 'Empty']);
    });

    test('configures values before enabling proxy states', () {
      final commands = MacosProxyCommands.buildStart('Wi-Fi', 7890, const [
        'localhost',
      ]);

      final firstStateCommand = commands.indexWhere(
        (command) => command.args.first.endsWith('proxystate'),
      );

      expect(firstStateCommand, 4);
      expect(commands[3].args.first, '-setproxybypassdomains');
    });

    test('reports failure when no active network service is found', () async {
      var callCount = 0;
      final proxy = MacosProxy(
        commandRunner: ProxyCommandRunner((
          executable,
          arguments, {
          runInShell = false,
        }) async {
          callCount++;
          return ProcessResult(
            callCount,
            0,
            'An asterisk (*) denotes that a network service is disabled.\n',
            '',
          );
        }),
      );

      expect(await proxy.start(7890, const []), isFalse);
      expect(callCount, 1);
    });
  });

  group('macOS proxy snapshot and restore', () {
    final applied = MacosServiceProxy.applied(7890, const ['localhost']);
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
    );
    final unset = MacosServiceProxy(
      web: const MacosProxyEndpoint(enabled: false, host: '', port: 0),
      secure: const MacosProxyEndpoint(enabled: false, host: '', port: 0),
      socks: const MacosProxyEndpoint(enabled: false, host: '', port: 0),
      bypassDomain: const [],
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
        applied: applied,
        current: {'Wi-Fi': applied, 'Ethernet': clashMac},
      );

      expect(plan, {'Wi-Fi': clashMac});
    });

    test('leaves a service whose proxy moved to another port alone', () {
      final moved = MacosServiceProxy.applied(7891, const ['localhost']);
      final plan = MacosProxyCommands.restorePlan(
        before: {'Wi-Fi': clashMac},
        applied: applied,
        current: {'Wi-Fi': moved},
      );

      expect(plan, isEmpty);
    });

    test('leaves a service whose bypass list was edited alone', () {
      final plan = MacosProxyCommands.restorePlan(
        before: {'Wi-Fi': clashMac},
        applied: applied,
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
        applied: applied,
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
        ],
      );
    });

    test('never touches the auto proxy', () {
      final commands = [
        ...MacosProxyCommands.buildStart('Wi-Fi', 7890, const []),
        ...MacosProxyCommands.buildRestore('Wi-Fi', clashMac),
      ];

      expect(
        commands.where((command) => command.args.first.contains('autoproxy')),
        isEmpty,
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
        }, applied);

        expect(ok, isTrue);
        expect(writes.map((args) => args[1]).toSet(), {'Wi-Fi'});
        expect(writes.first, ['-setwebproxy', 'Wi-Fi', '127.0.0.1', '7893']);
      });

      test('writes nothing when another app took over', () async {
        system['Wi-Fi'] = MacosServiceProxy.applied(7897, const []);

        final ok = await macosProxy().restore({'Wi-Fi': clashMac}, applied);

        expect(ok, isTrue);
        expect(writes, isEmpty);
      });

      test('reports a service it could not read and leaves it', () async {
        system['Wi-Fi'] = applied;
        unreadable.add('Wi-Fi');

        final ok = await macosProxy().restore({'Wi-Fi': clashMac}, applied);

        expect(ok, isFalse);
        expect(writes, isEmpty);
      });

      test('skips a service that is gone', () async {
        final ok = await macosProxy().restore({'USB LAN': clashMac}, applied);

        expect(ok, isTrue);
        expect(writes, isEmpty);
      });
    });
  });

  group('windowsBypassList', () {
    test('adds the intranet token once', () {
      expect(windowsBypassList(['localhost', '127.*', '<local>']), [
        'localhost',
        '127.*',
        '<local>',
      ]);
      expect(windowsBypassList(['localhost']), ['localhost', '<local>']);
    });

    test('brackets bare IPv6 literals and drops blank entries', () {
      expect(
        windowsBypassList([' ::1 ', 'fe80::1', '', '[fd00::1]', '*.lan']),
        ['[::1]', '[fe80::1]', '[fd00::1]', '*.lan', '<local>'],
      );
    });

    test('drops trailing slashes that fail the whole list', () {
      expect(
        windowsBypassList(['example.test/', 'example.test', 'nas//', '/']),
        ['example.test', 'nas', '<local>'],
      );
    });
  });

  group('MethodChannelProxy', () {
    final proxy = MethodChannelProxy();

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(proxy.methodChannel, null);
    });

    test('sends the Windows start contract', () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(proxy.methodChannel, (call) async {
            capturedCall = call;
            return true;
          });

      final result = await proxy.startProxy(7890, const ['localhost']);

      expect(result, isTrue);
      expect(capturedCall?.method, 'StartProxy');
      expect(capturedCall?.arguments, {
        'port': 7890,
        'bypassDomain': ['localhost'],
      });
    });

    test('maps a null native response to false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(proxy.methodChannel, (_) async => null);

      expect(await proxy.stopProxy(), isFalse);
    });
  });
}
