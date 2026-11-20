import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/common/mitm_trust.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _MockTrustStore extends Mock implements MitmTrustStore {}

const _channel = MethodChannel(MitmSigner.channelName);
final _spki = Uint8List.fromList([1, 2, 3]);
final _leaf = Uint8List.fromList([4, 5]);
final _root = Uint8List.fromList([6]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockCoreHandlerInterface core;
  late _MockTrustStore trust;
  late ProviderContainer container;
  late List<MethodCall> calls;
  late Object? Function(MethodCall) answer;
  final sent = <Map<String, Object?>>[];

  setUpAll(() {
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

  Object? defaultAnswer(MethodCall call) => switch (call.method) {
    'coreIdentity' => 'verified',
    'certificate' => {
      'pem': 'PEM',
      'fingerprint': 'AB:CD',
      'subject': 'Test',
      'notBefore': 0,
      'notAfter': 4102444800000,
    },
    'checkCertificate' => 'leaf PEM',
    'sign' => {'cert': _leaf, 'ca': _root},
    _ => null,
  };

  setUp(() {
    mitmFeature = true;
    calls = [];
    sent.clear();
    answer = defaultAnswer;
    trust = _MockTrustStore();
    when(() => trust.check(any(), any())).thenAnswer((call) async {
      await (call.positionalArguments[1] as Future<String> Function())();
      return const MitmTrustCheck(MitmTrust.ready);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return answer(call);
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
        // Modules sign through the same list; see mitm_module_sign_test.
        enabledMitmModuleRulesProvider.overrideWith(
          (_) async => MitmModuleRules.empty,
        ),
      ],
    );
    container.listen(patchClashConfigProvider, (_, _) {});
    container
        .read(patchClashConfigProvider.notifier)
        .value = const PatchClashConfig(
      mitm: Mitm(
        enable: true,
        hostname: ['api.example.com'],
        trustedFingerprint: 'AB:CD',
      ),
    );
  });

  tearDown(() {
    container.dispose();
    mitmFeature = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> sign(String host, {bool managedRelay = true}) => container
      .read(mitmSignActionProvider.notifier)
      .answer(
        MitmSignRequest.fromJson({
          'reqId': 7,
          'deadlineUnixMillis': DateTime.now()
              .add(const Duration(seconds: 8))
              .millisecondsSinceEpoch,
          'host': host,
          'spki': base64.encode(_spki),
        }, managedRelay: managedRelay),
      );

  test('the request reads the base64 key Go writes', () {
    final request = MitmSignRequest.fromJson({
      'reqId': 3,
      'host': 'a.test',
      'spki': base64.encode(_spki),
    });
    expect(request.reqId, 3);
    expect(request.spki, _spki);
  });

  test('a signed leaf goes back to the Core as base64', () async {
    await sign('api.example.com');

    final signs = calls.where((call) => call.method == 'sign');
    expect(signs.single.arguments, {
      'host': 'api.example.com',
      'spki': _spki,
      'hostnames': ['api.example.com'],
    });
    expect(sent.single, {
      'reqId': 7,
      'cert': base64.encode(_leaf),
      'ca': base64.encode(_root),
    });
  });

  test(
    'slow trust and signing share one budget beyond the old core timeout',
    () async {
      when(() => trust.check(any(), any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 2700));
        return const MitmTrustCheck(MitmTrust.ready);
      });
      answer = (call) async {
        if (call.method == 'sign') {
          await Future<void>.delayed(const Duration(milliseconds: 2700));
        }
        return defaultAnswer(call);
      };
      await sign('api.example.com');
      expect(sent.single['cert'], base64.encode(_leaf));
    },
  );

  test('expired relay deadline refuses before trust or signing', () async {
    await container
        .read(mitmSignActionProvider.notifier)
        .answer(
          MitmSignRequest.fromJson({
            'reqId': 8,
            'host': 'api.example.com',
            'spki': base64.encode(_spki),
            'deadlineUnixMillis': DateTime.now()
                .subtract(const Duration(seconds: 1))
                .millisecondsSinceEpoch,
          }, managedRelay: true),
        );
    expect(sent.single['error'], 'trustUnavailable');
    expect(calls, isEmpty);
    verifyNever(() => trust.check(any(), any()));
  });

  test('the signer is handed the app list, not the Core match', () async {
    container
        .read(patchClashConfigProvider.notifier)
        .value = const PatchClashConfig(
      mitm: Mitm(
        enable: true,
        hostname: ['-api.example.com', '*.b.test'],
        trustedFingerprint: 'AB:CD',
      ),
    );
    answer = (call) =>
        call.method == 'sign' ? {'error': 'notListed'} : defaultAnswer(call);

    await sign('api.example.com');

    expect(
      (calls.singleWhere((call) => call.method == 'sign').arguments
          as Map)['hostnames'],
      ['-api.example.com', '*.b.test'],
    );
    expect(sent.single, {'reqId': 7, 'error': 'notListed'});
  });

  test('nothing is signed while decryption is off', () async {
    container
        .read(patchClashConfigProvider.notifier)
        .value = const PatchClashConfig(
      mitm: Mitm(enable: false, hostname: ['api.example.com']),
    );

    await sign('api.example.com');

    expect(calls, isEmpty);
    expect(sent.single, {'reqId': 7, 'error': 'disabled'});
  });

  test('a refused Core pauses decryption with the reason', () async {
    answer = (call) => switch (call.method) {
      'coreIdentity' => 'verified',
      'sign' => {'error': 'coreIdentity', 'identity': 'failed:cdhash'},
      _ => defaultAnswer(call),
    };
    container.listen(mitmCoreRefusedProvider, (_, _) {});
    await container.read(mitmCoreIdentityStateProvider.future);
    expect(container.read(mitmCoreRefusedProvider), isFalse);

    await sign('api.example.com');

    expect(sent.single, {'reqId': 7, 'error': 'coreIdentity'});
    expect(
      container.read(mitmCoreIdentityStateProvider).value,
      const MitmCoreIdentity.failed('cdhash'),
    );
    expect(container.read(mitmCoreRefusedProvider), isTrue);
  });

  test('lost trust or identity refuses signing before approval', () async {
    when(
      () => trust.check(any(), any()),
    ).thenAnswer((_) async => const MitmTrustCheck(MitmTrust.untrusted));
    await sign('api.example.com');
    expect(sent.single, {'reqId': 7, 'error': 'trustUnavailable'});
    expect(calls.where((c) => c.method == 'sign'), isEmpty);
    calls.clear();
    sent.clear();
    answer = (call) =>
        call.method == 'coreIdentity' ? 'none' : defaultAnswer(call);
    await sign('api.example.com');
    expect(sent.single, {'reqId': 7, 'error': 'trustUnavailable'});
    expect(calls.map((c) => c.method), ['coreIdentity']);
  });

  testWidgets('stalled trust check times out and does not spawn more checks', (
    tester,
  ) async {
    final stalled = Completer<MitmTrustCheck>();
    when(() => trust.check(any(), any())).thenAnswer((_) => stalled.future);
    final first = sign('api.example.com');
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    await first;
    expect(sent.single['error'], 'trustUnavailable');
    sent.clear();
    final second = sign('api.example.com');
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    await second;
    expect(sent.single['error'], 'trustUnavailable');
    verify(() => trust.check(any(), any())).called(1);
    expect(calls.where((c) => c.method == 'sign'), isEmpty);
    stalled.complete(const MitmTrustCheck(MitmTrust.ready));
    await tester.pump();
  });

  test('a request off the helper relay is refused unasked', () async {
    container.listen(mitmCoreRefusedProvider, (_, _) {});

    await sign('api.example.com', managedRelay: false);

    expect(calls.map((call) => call.method), isNot(contains('sign')));
    expect(sent.single, {'reqId': 7, 'error': 'coreIdentity'});
    expect(
      container.read(mitmCoreIdentityStateProvider).value,
      const MitmCoreIdentity.failed('channel'),
    );
  });

  test('a Core the helper did not start is not trusted', () async {
    answer = (_) => 'none';
    container.listen(mitmCoreRefusedProvider, (_, _) {});
    expect(
      await container.read(mitmCoreIdentityStateProvider.future),
      MitmCoreIdentity.none,
    );
    expect(container.read(mitmCoreRefusedProvider), isTrue);
    expect(MitmCoreIdentity.parse('anything'), const MitmCoreIdentity.failed());
    expect(MitmCoreIdentity.parse('failed'), const MitmCoreIdentity.failed());
    expect(
      MitmCoreIdentity.parse('failed:status 0x1'),
      const MitmCoreIdentity.failed('status 0x1'),
    );
    expect(MitmCoreIdentity.parse('verified'), MitmCoreIdentity.verified);
  });

  test('a channel failure is answered, not left to time out', () async {
    answer = (call) => call.method == 'sign'
        ? throw PlatformException(code: 'boom')
        : defaultAnswer(call);

    await sign('api.example.com');

    expect(sent.single, {'reqId': 7, 'error': 'signFailed'});
  });

  test('the certificate and its removal go through the keychain', () async {
    answer = (call) => switch (call.method) {
      'certificate' => {
        'pem': 'PEM',
        'fingerprint': 'AB:CD',
        'subject': 'Flash 本机解密证书（仅此 Mac）',
        'notBefore': 0,
        'notAfter': 1000,
      },
      _ => null,
    };
    final ca = await container.read(mitmCaProvider.future);
    expect(ca?.fingerprint, 'AB:CD');
    expect(
      ca?.notAfter,
      DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );

    await container.read(mitmCaProvider.notifier).delete();

    expect(calls.map((call) => call.method), ['certificate', 'delete']);
    expect(container.read(mitmCaProvider).value, isNull);
    verifyNever(() => core.getMitmCertificate());
  });

  group('the trust check before a signing', () {
    Map<String, Object?> root(String fingerprint) => {
      'pem': 'PEM',
      'fingerprint': fingerprint,
      'subject': 'Test',
      'notBefore': 0,
      'notAfter': 4102444800000,
    };

    // A refusal must leave no error behind: the root read and the check leaf
    // run together, and the one not awaited must still be observed.
    Future<List<Object>> signGuarded(String host) async {
      final stray = <Object>[];
      final done = Completer<void>();
      runZonedGuarded(() {
        unawaited(sign(host).whenComplete(done.complete));
      }, (error, _) => stray.add(error));
      await done.future;
      await pumpEventQueue();
      return stray;
    }

    void expectRefused(List<Object> stray) {
      expect(stray, isEmpty);
      expect(sent.single, {'reqId': 7, 'error': 'trustUnavailable'});
      expect(calls.where((call) => call.method == 'sign'), isEmpty);
    }

    test('a root other than the trusted one refuses', () async {
      answer = (call) => switch (call.method) {
        'certificate' => root('EF:01'),
        'checkCertificate' => throw PlatformException(code: 'noRoot'),
        _ => defaultAnswer(call),
      };
      expectRefused(await signGuarded('api.example.com'));
      verifyNever(() => trust.check(any(), any()));
    });

    for (final (name, certificate) in [
      ('no root', (MethodCall _) => null),
      (
        'a root read that fails',
        (MethodCall _) => throw PlatformException(code: 'keychain'),
      ),
    ]) {
      test('$name, with a check leaf that fails too, refuses', () async {
        answer = (call) => switch (call.method) {
          'certificate' => certificate(call),
          'checkCertificate' => throw PlatformException(code: 'noRoot'),
          _ => defaultAnswer(call),
        };
        expectRefused(await signGuarded('api.example.com'));
        verifyNever(() => trust.check(any(), any()));
      });
    }

    test('a root replaced during the check refuses', () async {
      var reads = 0;
      answer = (call) => call.method == 'certificate'
          ? root(++reads == 1 ? 'AB:CD' : 'EF:01')
          : defaultAnswer(call);
      expectRefused(await signGuarded('api.example.com'));
      expect(reads, 2);
      verify(() => trust.check(any(), any())).called(1);
    });

    test('a check leaf that fails refuses before verify-cert runs', () async {
      final ran = <List<String>>[];
      final store = MacOSMitmTrustStore(
        home: '/nonexistent',
        run: (executable, arguments) async {
          ran.add(arguments);
          return ProcessResult(0, 0, '', '');
        },
        writeTemp: (_) async => '/nonexistent/leaf.pem',
      );
      when(() => trust.check(any(), any())).thenAnswer(
        (call) => store.check(
          call.positionalArguments[0] as MitmCertificate,
          call.positionalArguments[1] as Future<String> Function(),
        ),
      );
      answer = (call) => call.method == 'checkCertificate'
          ? throw PlatformException(code: 'noRoot')
          : defaultAnswer(call);
      expectRefused(await signGuarded('api.example.com'));
      expect(ran, isEmpty);
    });
  });

  group('the macOS root', () {
    const certificate = {
      'pem': 'PEM',
      'fingerprint': 'AB:CD',
      'subject': 'Flash 本机解密证书（仅此 Mac）',
      'notBefore': 0,
      'notAfter': 1000,
    };
    late _MockTrustStore store;

    ProviderContainer containerWith({required bool safeMode}) {
      store = _MockTrustStore();
      when(
        () => store.check(any(), any()),
      ).thenAnswer((_) async => const MitmTrustCheck(MitmTrust.ready));
      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          mitmSignerProvider.overrideWithValue(const MitmSigner()),
          mitmTrustStoreProvider.overrideWithValue(store),
          safeModeProvider.overrideWithValue(safeMode),
        ],
      );
      addTearDown(container.dispose);
      answer = (call) => switch (call.method) {
        'certificate' || 'generate' => certificate,
        _ => null,
      };
      return container;
    }

    setUpAll(
      () => registerFallbackValue(
        MitmCertificate(
          pem: '',
          fingerprint: '',
          subject: '',
          notBefore: DateTime.utc(2026),
          notAfter: DateTime.utc(2027),
        ),
      ),
    );

    test('is regenerated by the signer alone, trust included', () async {
      final container = containerWith(safeMode: false);
      await container.read(mitmTrustStateProvider.future);

      expect(
        await container.read(mitmTrustStateProvider.notifier).regenerate(),
        isTrue,
      );

      verifyNever(() => store.remove(any()));
      expect(calls.map((call) => call.method), contains('generate'));
    });

    test('is left as it is in safe mode', () async {
      final container = containerWith(safeMode: true);
      await container.read(mitmCaProvider.future);
      final ca = container.read(mitmCaProvider.notifier);

      await expectLater(ca.generate(), throwsStateError);
      await expectLater(ca.delete(), throwsStateError);

      expect(calls.map((call) => call.method), ['certificate']);
    });
  });
}
