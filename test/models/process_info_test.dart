import 'dart:typed_data';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _chromeHelper =
    '/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome '
    'Framework.framework/Versions/1/Helpers/Google Chrome Helper.app/Contents/'
    'MacOS/Google Chrome Helper';

const _chrome = MacApp(
  bundleId: 'com.example.chrome',
  name: 'Google Chrome',
  bundlePath: '/Applications/Google Chrome.app',
);

const _local = {'127.0.0.1', '::1', '192.168.1.5', '198.18.0.1'};

void main() {
  group('ConnectionProcess.classify', () {
    test('a process in a bundle the Mac read is that app', () {
      final process = ConnectionProcess.classify(
        const Metadata(
          process: 'Google Chrome Helper',
          processPath: _chromeHelper,
        ),
        lookup: const AppLookup.app(_chrome),
      );
      expect(process.kind, ProcessKind.app);
      expect(process.label, 'Google Chrome');
      expect(process.name, 'Google Chrome Helper');
      expect(process.path, _chromeHelper);
      expect(process.key, 'app:com.example.chrome');
    });

    test('a command-line tool keeps its own name and path', () {
      final process = ConnectionProcess.classify(
        const Metadata(process: 'ssh', processPath: '/usr/bin/ssh'),
        lookup: AppLookup.none,
      );
      expect(process.kind, ProcessKind.process);
      expect(process.label, 'ssh');
      expect(process.app, isNull);
      expect(process.appUnreadable, isFalse);
      expect(process.key, 'exe:/usr/bin/ssh');
    });

    test('the name comes from the path when the Core sent only a path', () {
      final process = ConnectionProcess.classify(
        const Metadata(processPath: '/opt/homebrew/bin/curl'),
        lookup: AppLookup.none,
      );
      expect(process.name, 'curl');
    });

    test('a pending lookup is not yet called a command-line tool', () {
      final process = ConnectionProcess.classify(
        const Metadata(process: 'x', processPath: '/Applications/X.app/x'),
      );
      expect(process.kind, ProcessKind.process);
      expect(process.pending, isTrue);
    });

    test('an unreadable bundle keeps the known process', () {
      final process = ConnectionProcess.classify(
        const Metadata(process: 'Gone', processPath: '/Applications/G.app/g'),
        lookup: AppLookup.unreadable,
      );
      expect(process.kind, ProcessKind.process);
      expect(process.name, 'Gone');
      expect(process.appUnreadable, isTrue);
    });

    test('no process info is unknown, not another device', () {
      expect(
        ConnectionProcess.classify(
          const Metadata(sourceIP: '192.168.1.20'),
          localAddresses: _local,
        ).kind,
        ProcessKind.unknown,
      );
    });

    test('another device needs a LAN listener on this Mac', () {
      const remote = Metadata(
        type: 'HTTP',
        sourceIP: '192.168.1.20',
        inboundIP: '192.168.1.5',
      );
      expect(
        ConnectionProcess.classify(remote, localAddresses: _local).kind,
        ProcessKind.otherDevice,
      );
      expect(
        ConnectionProcess.classify(remote, localAddresses: _local).key,
        otherDeviceProcessKey,
      );
      expect(
        ConnectionProcess.classify(remote).kind,
        ProcessKind.unknown,
        reason: 'unread local addresses are no evidence',
      );
      expect(
        ConnectionProcess.classify(
          remote.copyWith(type: 'Tun'),
          localAddresses: _local,
        ).kind,
        ProcessKind.unknown,
      );
      expect(
        ConnectionProcess.classify(
          remote.copyWith(sourceIP: '192.168.1.5'),
          localAddresses: _local,
        ).kind,
        ProcessKind.unknown,
      );
      expect(
        ConnectionProcess.classify(
          remote.copyWith(inboundIP: ''),
          localAddresses: _local,
        ).kind,
        ProcessKind.unknown,
      );
      expect(
        ConnectionProcess.classify(
          remote.copyWith(sourceIP: '127.0.0.1', inboundIP: '127.0.0.1'),
          localAddresses: _local,
        ).kind,
        ProcessKind.unknown,
      );
      expect(
        ConnectionProcess.classify(
          remote.copyWith(process: 'curl'),
          localAddresses: _local,
        ).kind,
        ProcessKind.process,
      );
    });

    test('mapped IPv4 addresses compare as IPv4', () {
      expect(
        isFromOtherDevice(
          const Metadata(
            type: 'Socks5',
            sourceIP: '::ffff:192.168.1.20',
            inboundIP: '::ffff:192.168.1.5',
          ),
          _local,
        ),
        isTrue,
      );
    });
  });

  group('process keys', () {
    test('apps sharing a name stay apart by bundle', () {
      const work = MacApp(
        bundleId: 'com.example.notes',
        name: 'Notes',
        bundlePath: '/Applications/Notes.app',
      );
      const other = MacApp(
        bundleId: 'org.other.notes',
        name: 'Notes',
        bundlePath: '/Users/me/Applications/Notes.app',
      );
      final a = ConnectionProcess.classify(
        const Metadata(
          process: 'Notes',
          processPath: '/Applications/Notes.app/n',
        ),
        lookup: const AppLookup.app(work),
      );
      final b = ConnectionProcess.classify(
        const Metadata(
          process: 'Notes',
          processPath: '/Users/me/Applications/Notes.app/n',
        ),
        lookup: const AppLookup.app(other),
      );
      expect(a.label, b.label);
      expect(a.key, isNot(b.key));
    });

    test('helpers of one app share its key', () {
      final main = ConnectionProcess.classify(
        const Metadata(
          process: 'Google Chrome',
          processPath:
              '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        ),
        lookup: const AppLookup.app(_chrome),
      );
      final helper = ConnectionProcess.classify(
        const Metadata(
          process: 'Google Chrome Helper',
          processPath: _chromeHelper,
        ),
        lookup: const AppLookup.app(_chrome),
      );
      expect(main.key, helper.key);
    });

    test('tools sharing a name stay apart by executable', () {
      final a = ConnectionProcess.classify(
        const Metadata(process: 'curl', processPath: '/usr/bin/curl'),
        lookup: AppLookup.none,
      );
      final b = ConnectionProcess.classify(
        const Metadata(process: 'curl', processPath: '/opt/homebrew/bin/curl'),
        lookup: AppLookup.none,
      );
      expect(a.key, isNot(b.key));
    });

    test('a bundle without an identifier goes by its path', () {
      const app = MacApp(bundleId: '', name: 'Tool', bundlePath: '/A/Tool.app');
      expect(app.key, 'bundle:/A/Tool.app');
    });
  });

  group('AppLookup.fromChannel', () {
    test('reads each answer', () {
      final icon = Uint8List.fromList([1, 2, 3]);
      final app = AppLookup.fromChannel({
        'status': 'app',
        'bundleId': 'com.example.chrome',
        'name': 'Google Chrome',
        'bundlePath': '/Applications/Google Chrome.app',
        'icon': icon,
      });
      expect(app.status, AppLookupStatus.app);
      expect(app.app!.icon, icon);
      expect(
        AppLookup.fromChannel({'status': 'none'}).status,
        AppLookupStatus.none,
      );
      expect(
        AppLookup.fromChannel({'status': 'unreadable'}).status,
        AppLookupStatus.unreadable,
      );
      expect(AppLookup.fromChannel(null).status, AppLookupStatus.failed);
      expect(
        AppLookup.fromChannel({'status': 'app', 'name': ''}).status,
        AppLookupStatus.unreadable,
      );
    });
  });

  group('system services', () {
    const apsd =
        '/System/Library/PrivateFrameworks/ApplePushService.framework/apsd';

    test('the Mac names a service by id with its icon', () {
      final icon = Uint8List.fromList([4, 5]);
      final lookup = AppLookup.fromChannel({
        'status': 'service',
        'serviceId': 'pushNotifications',
        'shared': false,
        'icon': icon,
      });
      expect(lookup.status, AppLookupStatus.service);
      expect(lookup.service!.service, SystemService.pushNotifications);
      expect(lookup.service!.icon, icon);
      expect(lookup.app, isNull);
    });

    test('a service id this build does not know reads as a bare process', () {
      expect(
        AppLookup.fromChannel({'status': 'service', 'serviceId': 'later'}),
        AppLookup.none,
      );
      expect(
        AppLookup.fromChannel({'status': 'service'}).status,
        AppLookupStatus.none,
      );
    });

    test('a service stays a process with its raw name and path', () {
      final process = ConnectionProcess.classify(
        const Metadata(process: 'apsd', processPath: apsd),
        lookup: const AppLookup.service(
          ServiceMatch(SystemService.pushNotifications),
        ),
      );
      expect(process.kind, ProcessKind.process);
      expect(process.hasProcess, isTrue);
      expect(process.name, 'apsd');
      expect(process.label, 'apsd');
      expect(process.path, apsd);
      expect(process.app, isNull);
      expect(process.service!.service, SystemService.pushNotifications);
    });

    test('the daemons of one feature group together', () {
      ConnectionProcess of(String name) => ConnectionProcess.classify(
        Metadata(process: name, processPath: '/x/$name'),
        lookup: const AppLookup.service(ServiceMatch(SystemService.appStore)),
      );
      expect(of('storedownloadd').key, 'svc:appStore');
      expect(of('appstoreagent').key, of('storedownloadd').key);
    });

    test('a launchd job keeps its label on the app it names', () {
      final lookup = AppLookup.fromChannel({
        'status': 'app',
        'bundleId': 'com.example.app',
        'name': 'Example',
        'bundlePath': '/Applications/Example.app',
        'launchdLabel': 'com.example.daemon',
      });
      expect(lookup.app!.launchdLabel, 'com.example.daemon');
      expect(lookup.app!.key, 'app:com.example.app');
      expect(
        AppLookup.fromChannel({
          'status': 'app',
          'name': 'Example',
          'bundlePath': '/Applications/Example.app',
        }).app!.launchdLabel,
        '',
      );
    });

    test('only the listed services are shared', () {
      expect(SystemService.values.where((service) => service.shared).toSet(), {
        SystemService.backgroundDownloads,
        SystemService.nameResolution,
        SystemService.certificateChecks,
        SystemService.webContent,
        SystemService.networkProxy,
        SystemService.systemAssets,
        SystemService.location,
        SystemService.continuity,
        SystemService.captivePortal,
        SystemService.appSecurity,
      });
      expect(SystemService.fromId('appStore'), SystemService.appStore);
      expect(SystemService.fromId('apsd'), isNull);
    });
  });
}
