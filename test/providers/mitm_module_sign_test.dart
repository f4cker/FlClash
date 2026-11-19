import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/common/mitm_trust.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';
import '../helpers/mitm_host_policy.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _MockTrustStore extends Mock implements MitmTrustStore {}

const _channel = MethodChannel(MitmSigner.channelName);

/// A real-world shape: a response script, so the module comes in off and
/// asks before it runs.
const _zhihu = r'''
#!name=Zhihu
#!desc=Cleans the answer page
[Script]
zhihu-answer = type=http-response,pattern=^https:\/\/www\.zhihu\.com\/api\/v4\/answers,requires-body=1,script-path=https://example.com/zhihu.js
[MITM]
hostname = %APPEND% www.zhihu.com
''';

String _module(String name, String hostname) =>
    '''
#!name=$name
[MITM]
hostname = %APPEND% $hostname
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory home;
  late db.Database testDatabase;
  late ProviderContainer container;
  late _MockTrustStore trust;
  late _MockCoreHandlerInterface core;
  final signedLists = <List<String>>[];
  final sent = <Map<String, Object?>>[];
  Future<void> Function(String host)? duringSign;
  // Set, the modules' list is read from it instead of the database.
  Future<MitmModuleRules> Function()? moduleRules;

  void setMitm(
    List<String> hostname, {
    bool enable = true,
    LogLevel logLevel = LogLevel.error,
  }) {
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      logLevel: logLevel,
      mitm: Mitm(
        enable: enable,
        hostname: hostname,
        trustedFingerprint: 'AB:CD',
      ),
    );
  }

  setUpAll(() {
    loadAppLocalizations(const Locale('en'));
    globalState.packageInfo = PackageInfo(
      appName: 'FlClash',
      packageName: 'com.follow.clash',
      version: '1.0.0',
      buildNumber: '1',
    );
    registerFallbackValue(const MitmSignResult());
    registerFallbackValue(
      MitmCertificate(
        pem: '',
        fingerprint: '',
        subject: '',
        notBefore: DateTime.utc(2026),
        notAfter: DateTime.utc(2027),
      ),
    );
  });

  setUp(() async {
    mitmFeature = true;
    mitmModulesFeature = true;
    signedLists.clear();
    sent.clear();
    duringSign = null;
    moduleRules = null;
    MitmSignAction.modulesWait = const Duration(seconds: 2);
    home = await Directory.systemTemp.createTemp('mitm_module_sign');
    await useAppPaths(home);
    testDatabase = db.Database(NativeDatabase.memory());
    db.database = testDatabase;
    trust = _MockTrustStore();
    when(() => trust.check(any(), any())).thenAnswer((call) async {
      await (call.positionalArguments[1] as Future<String> Function())();
      return const MitmTrustCheck(MitmTrust.ready);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          switch (call.method) {
            case 'coreIdentity':
              return 'verified';
            case 'certificate':
              return {
                'pem': 'PEM',
                'fingerprint': 'AB:CD',
                'subject': 'Test',
                'notBefore': 0,
                'notAfter': 4102444800000,
              };
            case 'checkCertificate':
              return 'leaf PEM';
            case 'sign':
              final args = call.arguments as Map<Object?, Object?>;
              final host = args['host']! as String;
              final list = (args['hostnames']! as List).cast<String>();
              signedLists.add(list);
              await duringSign?.call(host);
              return mitmPolicyListed(host, list)
                  ? {
                      'cert': Uint8List.fromList([4, 5]),
                      'ca': Uint8List.fromList([6]),
                    }
                  : {'error': 'notListed'};
          }
          return null;
        });
    core = _MockCoreHandlerInterface();
    when(() => core.sendMitmSignResult(any(), any())).thenAnswer((call) async {
      sent.add(
        (call.positionalArguments[1] as MitmSignResult).toJson(
          call.positionalArguments[0] as int,
        ),
      );
    });
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        mitmSignerProvider.overrideWithValue(const MitmSigner()),
        mitmTrustStoreProvider.overrideWithValue(trust),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        enabledMitmModuleRulesProvider.overrideWith(
          (ref) => moduleRules?.call() ?? enabledMitmModuleRules(ref),
        ),
      ],
    );
    globalState.container = container;
    globalState.isAttach = true;
    container.listen(logsProvider, (_, _) {});
    container.listen(mitmModulesProvider, (_, _) {});
    container.listen(patchClashConfigProvider, (_, _) {});
    // The Core manager keeps the setup alive in the app.
    container.listen(mitmSetupProvider, (_, _) {});
    setMitm(const ['user.example.com']);
  });

  tearDown(() async {
    container.dispose();
    await testDatabase.close();
    await home.delete(recursive: true);
    globalState.isAttach = false;
    mitmFeature = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  MitmModulesAction action() =>
      container.read(mitmModulesActionProvider.notifier);

  Future<MitmModule> add(String text, String fileName) async {
    final module = await action().addFromFile(text, fileName);
    await pumpEventQueue();
    return module;
  }

  Future<void> settle() async {
    await pumpEventQueue();
    await container.read(enabledMitmModuleRulesProvider.future);
    await pumpEventQueue();
  }

  List<String> coreHostnames() =>
      (container.read(mitmSetupProvider)?['hostname'] as List<String>?) ??
      const [];

  /// The error the Core got back, or null for a leaf.
  Future<String?> sign(String host) async {
    await container
        .read(mitmSignActionProvider.notifier)
        .answer(
          MitmSignRequest.fromJson({
            'reqId': 7,
            'deadlineUnixMillis': DateTime.now()
                .add(const Duration(seconds: 8))
                .millisecondsSinceEpoch,
            'host': host,
            'spki': base64.encode([1, 2, 3]),
          }, managedRelay: true),
        );
    final result = sent.removeLast();
    return result['cert'] == null ? (result['error']! as String) : null;
  }

  test(
    'a module with a script signs its host once the user turns it on',
    () async {
      final module = await add(_zhihu, 'zhihu.sgmodule');
      await settle();
      expect(module.enabled, isFalse);
      expect(await sign('www.zhihu.com'), 'notListed');
      expect(signedLists.last, ['user.example.com']);

      await action().recordConsent(module.id, asksConsent: false, agreed: true);
      await settle();
      expect(coreHostnames(), ['user.example.com', 'www.zhihu.com']);
      expect(await sign('www.zhihu.com'), isNull);
      expect(signedLists.last, coreHostnames());
      expect(await sign('user.example.com'), isNull);
    },
  );

  test(
    'revoking consent, turning off or deleting takes the hosts away',
    () async {
      final module = await add(_zhihu, 'zhihu.sgmodule');
      await action().recordConsent(module.id, asksConsent: false, agreed: true);
      await settle();
      expect(await sign('www.zhihu.com'), isNull);

      await action().recordConsent(
        module.id,
        asksConsent: false,
        agreed: false,
      );
      // Asked at once, before the setup reaches the Core again.
      expect(await sign('www.zhihu.com'), 'notListed');
      await settle();
      expect(coreHostnames(), ['user.example.com']);

      await action().recordConsent(module.id, asksConsent: false, agreed: true);
      await settle();
      expect(await sign('www.zhihu.com'), isNull);
      await action().turnOff(module.id);
      expect(await sign('www.zhihu.com'), 'notListed');

      await action().recordConsent(module.id, asksConsent: false, agreed: true);
      await settle();
      expect(await sign('www.zhihu.com'), isNull);
      final current = container
          .read(mitmModulesProvider)
          .value!
          .singleWhere((item) => item.id == module.id);
      await action().deleteModule(current);
      expect(await sign('www.zhihu.com'), 'notListed');
      await settle();
      expect(coreHostnames(), ['user.example.com']);
      expect(await sign('user.example.com'), isNull);
    },
  );

  test(
    'the global switch off refuses module hosts and asks no signer',
    () async {
      await add(_module('A', 'a.example.com'), 'a.sgmodule');
      await settle();
      expect(await sign('a.example.com'), isNull);
      setMitm(const ['user.example.com'], enable: false);
      signedLists.clear();
      expect(await sign('a.example.com'), 'disabled');
      expect(await sign('user.example.com'), 'disabled');
      expect(signedLists, isEmpty);
    },
  );

  test('overlapping sources, a disabled module and wildcards', () async {
    setMitm(const ['shared.example.com']);
    await add(
      _module('A', 'shared.example.com, *.a.example.com'),
      'a.sgmodule',
    );
    final b = await add(_module('B', 'b.example.com'), 'b.sgmodule');
    await action().turnOff(b.id);
    await settle();
    expect(coreHostnames(), [
      'shared.example.com',
      'shared.example.com',
      '*.a.example.com',
    ]);
    expect(await sign('x.a.example.com'), isNull);
    expect(signedLists.last, coreHostnames());
    // A wildcard covers subdomains only, as in the Core.
    expect(await sign('a.example.com'), 'notListed');
    expect(await sign('b.example.com'), 'notListed');
    expect(await sign('shared.example.com'), isNull);

    final a = container
        .read(mitmModulesProvider)
        .value!
        .singleWhere((item) => item.name == 'A');
    await action().turnOff(a.id);
    await settle();
    // Still the user's own.
    expect(await sign('shared.example.com'), isNull);
    expect(await sign('x.a.example.com'), 'notListed');
  });

  test('exclusions hold in the order the Core reads them', () async {
    setMitm(const ['-skip.a.example.com']);
    await add(
      _module('A', '*.a.example.com, -private.a.example.com'),
      'a.sgmodule',
    );
    await settle();
    expect(coreHostnames(), [
      '-skip.a.example.com',
      '*.a.example.com',
      '-private.a.example.com',
    ]);
    expect(await sign('skip.a.example.com'), 'notListed');
    expect(await sign('x.a.example.com'), isNull);
    expect(signedLists.last, coreHostnames());
  });

  test('a module turned off while signing withdraws the leaf', () async {
    final module = await add(_module('A', 'a.example.com'), 'a.sgmodule');
    await settle();
    duringSign = (host) async {
      duringSign = null;
      await action().turnOff(module.id);
      await pumpEventQueue();
    };
    expect(await sign('a.example.com'), 'disabled');
    expect(await sign('a.example.com'), 'notListed');
  });

  test('the user list changing while signing withdraws the leaf', () async {
    duringSign = (host) async {
      duringSign = null;
      setMitm(const ['other.example.com']);
    };
    expect(await sign('user.example.com'), 'disabled');
    expect(await sign('user.example.com'), 'notListed');
    expect(await sign('other.example.com'), isNull);
  });

  test('switching profile or config keeps the list the Core is sent', () async {
    await add(_module('A', 'a.example.com'), 'a.sgmodule');
    await settle();
    container.read(currentProfileIdProvider.notifier).value = 42;
    await settle();
    expect(await sign('a.example.com'), isNull);
    expect(signedLists.last, coreHostnames());

    setMitm(const ['new.example.com']);
    await settle();
    expect(coreHostnames(), ['new.example.com', 'a.example.com']);
    expect(await sign('user.example.com'), 'notListed');
    expect(await sign('new.example.com'), isNull);
    expect(await sign('a.example.com'), isNull);
    expect(signedLists.last, coreHostnames());
  });

  List<Log> mitmLogs() => [
    for (final log in container.read(logsProvider).list)
      if (log.payload.contains('MITM: ')) log,
  ];

  test('a refusal warns once per host, naming the host only', () async {
    expect(await sign('a.example.com'), 'notListed');
    expect(await sign('a.example.com'), 'notListed');
    expect(await sign('b.example.com'), 'notListed');
    final logs = mitmLogs();
    expect(logs.map((log) => log.logLevel), [
      LogLevel.warning,
      LogLevel.warning,
    ]);
    expect(logs.first.payload, contains('a.example.com'));
    expect(logs.last.payload, contains('b.example.com'));
    for (final log in logs) {
      expect(log.payload, isNot(contains('BAU=')));
      expect(log.payload, isNot(contains('AQID')));
    }
  });

  test('a leaf is logged only at the debug level, once per host', () async {
    expect(await sign('user.example.com'), isNull);
    expect(mitmLogs(), isEmpty);

    setMitm(const ['user.example.com'], logLevel: LogLevel.debug);
    expect(await sign('user.example.com'), isNull);
    expect(await sign('user.example.com'), isNull);
    final logs = mitmLogs();
    expect(logs.single.logLevel, LogLevel.debug);
    expect(logs.single.payload, '[APP] MITM: decrypting user.example.com');
  });

  test('a host refused again after it signed warns again', () async {
    final module = await add(_module('A', 'a.example.com'), 'a.sgmodule');
    await settle();
    expect(await sign('a.example.com'), isNull);
    await action().turnOff(module.id);
    expect(await sign('a.example.com'), 'notListed');
    await action().recordConsent(module.id, asksConsent: false, agreed: true);
    await settle();
    expect(await sign('a.example.com'), isNull);
    await action().turnOff(module.id);
    expect(await sign('a.example.com'), 'notListed');
    expect(
      mitmLogs().where((log) => log.logLevel == LogLevel.warning),
      hasLength(2),
    );
  });

  test(
    'a :443 host signs as the Core reads it; other ports never sign',
    () async {
      await add(
        _module(
          'P',
          'a.example.com:443, b.example.com:8443, api*.c.example.com',
        ),
        'p.sgmodule',
      );
      await settle();
      expect(coreHostnames(), [
        'user.example.com',
        'a.example.com',
        'b.example.com:8443',
        'api*.c.example.com',
      ]);
      expect(await sign('a.example.com'), isNull);
      expect(signedLists.last, coreHostnames());
      expect(await sign('b.example.com'), 'notListed');
      expect(await sign('api1.c.example.com'), 'notListed');
    },
  );

  test('the test signer holds to the shared hostname vectors', () {
    final vectors = mitmHostVectors();
    expect(vectors.validate.length, greaterThan(40));
    for (final vector in vectors.validate) {
      expect(
        mitmPolicyIssue(vector['line']! as String),
        vector['issue'],
        reason: vector['line']! as String,
      );
    }
    for (final vector in vectors.match) {
      expect(
        mitmPolicyListed(
          vector['host']! as String,
          (vector['list']! as List).cast<String>(),
        ),
        vector['decrypt'],
        reason: '${vector['list']} ${vector['host']}',
      );
    }
  });

  test('module hosts the policy skips never sign', () async {
    await add(
      _module(
        'S',
        'icloud.com:443, *.com, 1.2.3.4, bad_host.example.com, ok.example.com',
      ),
      's.sgmodule',
    );
    await settle();
    expect(await sign('www.icloud.com'), 'notListed');
    expect(await sign('icloud.com'), 'notListed');
    expect(await sign('x.com'), 'notListed');
    expect(await sign('1.2.3.4'), 'notListed');
    expect(await sign('bad_host.example.com'), 'notListed');
    expect(await sign('ok.example.com'), isNull);
    expect(signedLists.last, coreHostnames());
  });

  test('a -host:443 exclusion holds as the Core reads it', () async {
    setMitm(const []);
    await add(
      _module('X', '-skip.a.example.com:443, *.a.example.com'),
      'x.sgmodule',
    );
    await settle();
    expect(coreHostnames(), ['-skip.a.example.com', '*.a.example.com']);
    expect(await sign('skip.a.example.com'), 'notListed');
    expect(await sign('x.a.example.com'), isNull);
    expect(signedLists.last, coreHostnames());
  });

  test('a module whose requirement fails adds no host to sign', () async {
    final module = await add(r'''
#!name=R
#!requirement=SYSTEM = 'tvOS'
[MITM]
hostname = %APPEND% r.example.com
''', 'r.sgmodule');
    await settle();
    expect(module.enabled, isTrue);
    expect(coreHostnames(), ['user.example.com']);
    expect(await sign('r.example.com'), 'notListed');
    expect(signedLists.last, ['user.example.com']);
  });

  test('a module only for some clients adds no host to sign', () async {
    await add(r'''
#!name=C
[MITM]
hostname = %APPEND% c.example.com
client-source-address = %APPEND% 192.168.1.0/24
''', 'c.sgmodule');
    await settle();
    expect(coreHostnames(), ['user.example.com']);
    expect(await sign('c.example.com'), 'notListed');
    expect(signedLists.last, ['user.example.com']);
  });

  group('while the modules cannot be read', () {
    setUp(() {
      MitmSignAction.modulesWait = const Duration(milliseconds: 50);
    });

    test("a module host is refused as not ready, the user's signs", () async {
      moduleRules = () => Completer<MitmModuleRules>().future;
      expect(await sign('a.example.com'), 'notListed');
      expect(await sign('a.example.com'), 'notListed');
      expect(signedLists.last, ['user.example.com']);
      expect(await sign('user.example.com'), isNull);
      final logs = mitmLogs();
      expect(logs.single.logLevel, LogLevel.warning);
      expect(logs.single.payload, contains('not ready'));
      expect(logs.single.payload, contains('a.example.com'));
      expect(logs.single.payload, isNot(contains('not on the decryption')));
    });

    test(
      'a recheck that times out keeps a leaf the Core still decrypts',
      () async {
        moduleRules = () async =>
            const MitmModuleRules(hostname: ['a.example.com']);
        await settle();
        expect(coreHostnames(), ['user.example.com', 'a.example.com']);
        duringSign = (host) async {
          duringSign = null;
          moduleRules = () => Completer<MitmModuleRules>().future;
          container.invalidate(enabledMitmModuleRulesProvider);
          await pumpEventQueue();
        };
        expect(await sign('a.example.com'), isNull);
        // The Core keeps the list it was last sent meanwhile.
        expect(coreHostnames(), ['user.example.com', 'a.example.com']);
        expect(mitmLogs(), isEmpty);
      },
    );

    test('a recheck that times out after a change refuses this host only, '
        'never pausing every host', () async {
      moduleRules = () async =>
          const MitmModuleRules(hostname: ['a.example.com']);
      await settle();
      duringSign = (host) async {
        duringSign = null;
        moduleRules = () => Completer<MitmModuleRules>().future;
        container.invalidate(enabledMitmModuleRulesProvider);
        setMitm(const ['other.example.com']);
        await pumpEventQueue();
      };
      expect(await sign('a.example.com'), 'notListed');
      final logs = mitmLogs();
      expect(logs.single.logLevel, LogLevel.warning);
      expect(logs.single.payload, contains('not ready'));
    });

    test(
      'a first read that timed out is not withdrawn once the modules come',
      () async {
        final gate = Completer<MitmModuleRules>();
        moduleRules = () => gate.future;
        duringSign = (host) async {
          duringSign = null;
          gate.complete(const MitmModuleRules(hostname: ['a.example.com']));
          await pumpEventQueue();
        };
        expect(await sign('user.example.com'), isNull);
        expect(signedLists.last, ['user.example.com']);
        await settle();
        expect(coreHostnames(), ['user.example.com', 'a.example.com']);
        expect(await sign('a.example.com'), isNull);
      },
    );
  });
}
