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

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _MockTrustStore extends Mock implements MitmTrustStore {}

const _channel = MethodChannel(MitmSigner.channelName);

/// What MitmSigner.swift's MitmHostMatcher does with the list it is handed:
/// entries it cannot read are skipped, the first match decides and a `-`
/// entry excludes.
bool _listed(String host, List<String> lines) {
  for (final raw in lines) {
    var line = raw.trim().toLowerCase();
    final exclude = line.startsWith('-');
    if (exclude) line = line.substring(1);
    final wildcard = line.startsWith('*.');
    final base = wildcard ? line.substring(2) : line;
    if (base.isEmpty || base.contains('*') || base.contains(':')) continue;
    if (wildcard ? host.endsWith('.$base') : host == base) return !exclude;
  }
  return false;
}

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

  void setMitm(List<String> hostname, {bool enable = true}) {
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
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
              return _listed(host, list)
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
      ],
    );
    globalState.container = container;
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
}
