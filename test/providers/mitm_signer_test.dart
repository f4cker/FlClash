import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

const _channel = MethodChannel(MitmSigner.channelName);
final _spki = Uint8List.fromList([1, 2, 3]);
final _leaf = Uint8List.fromList([4, 5]);
final _root = Uint8List.fromList([6]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockCoreHandlerInterface core;
  late ProviderContainer container;
  late List<MethodCall> calls;
  late Object? Function(MethodCall) answer;
  final sent = <Map<String, Object?>>[];

  setUpAll(() => registerFallbackValue(const MitmSignResult()));

  setUp(() {
    mitmFeature = true;
    calls = [];
    sent.clear();
    answer = (_) => {'cert': _leaf, 'ca': _root};
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
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
      ],
    );
    container.listen(patchClashConfigProvider, (_, _) {});
    container
        .read(patchClashConfigProvider.notifier)
        .value = const PatchClashConfig(
      mitm: Mitm(enable: true, hostname: ['api.example.com']),
    );
  });

  tearDown(() {
    container.dispose();
    mitmFeature = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> sign(String host) => container
      .read(mitmSignActionProvider.notifier)
      .answer(
        MitmSignRequest.fromJson({
          'reqId': 7,
          'host': host,
          'spki': base64.encode(_spki),
        }),
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

  test('the signer is handed the app list, not the Core match', () async {
    container
        .read(patchClashConfigProvider.notifier)
        .value = const PatchClashConfig(
      mitm: Mitm(enable: true, hostname: ['-api.example.com', '*.b.test']),
    );
    answer = (_) => {'error': 'notListed'};

    await sign('api.example.com');

    expect((calls.single.arguments as Map)['hostnames'], [
      '-api.example.com',
      '*.b.test',
    ]);
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
      _ => {'error': 'coreIdentity'},
    };
    container.listen(mitmCoreRefusedProvider, (_, _) {});
    await container.read(mitmCoreIdentityStateProvider.future);
    expect(container.read(mitmCoreRefusedProvider), isFalse);

    await sign('api.example.com');

    expect(sent.single, {'reqId': 7, 'error': 'coreIdentity'});
    expect(
      container.read(mitmCoreIdentityStateProvider).value,
      MitmCoreIdentity.failed,
    );
    expect(container.read(mitmCoreRefusedProvider), isTrue);
  });

  test('a Core the helper did not start is not trusted', () async {
    answer = (_) => 'none';
    container.listen(mitmCoreRefusedProvider, (_, _) {});
    expect(
      await container.read(mitmCoreIdentityStateProvider.future),
      MitmCoreIdentity.none,
    );
    expect(container.read(mitmCoreRefusedProvider), isTrue);
    expect(MitmCoreIdentity.parse('anything'), MitmCoreIdentity.failed);
  });

  test('a channel failure is answered, not left to time out', () async {
    answer = (_) => throw PlatformException(code: 'boom');

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
}
