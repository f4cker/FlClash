import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/common/mitm_trust.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/mitm_core_ca.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

class _MockTrustStore extends Mock implements MitmTrustStore {}

class _Passphrases implements MitmPassphraseStore {
  final values = <String, String>{};

  @override
  Future<void> deletePassphrase(String fingerprint) async =>
      values.remove(fingerprint);

  @override
  Future<String?> readPassphrase(String fingerprint) async =>
      values[fingerprint];

  @override
  Future<void> writePassphrase(String fingerprint, String passphrase) async =>
      values[fingerprint] = passphrase;
}

const _channel = MethodChannel(MitmSigner.channelName);
const _coreFp = 'AA:AA';
const _pendingFp = 'BB:BB';
const _legacyFp = 'CC:CC';

MitmCertificate _cert(String fingerprint, String subject) => MitmCertificate(
  pem: 'PEM $subject',
  fingerprint: fingerprint,
  subject: subject,
  notBefore: DateTime.utc(2026),
  notAfter: DateTime.utc(2027),
);

final _p12 = MitmCaP12('AAAA');
final _pendingP12 = MitmCaP12('BBBB');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockCore core;
  late _MockTrustStore store;
  late _Passphrases passphrases;
  late ProviderContainer container;
  late List<MethodCall> calls;
  late String identity;
  late MitmTrust verdict;
  late Map<String, Object?>? legacy;
  final loaded = <MitmCaSecret>[];
  final leases = <(String, String)>[];
  var checks = 0;
  var stops = 0;

  setUpAll(() {
    registerFallbackValue(_cert('', ''));
    registerFallbackValue(
      MitmCaSecret(p12: _p12, passphrase: '', fingerprint: ''),
    );
    registerFallbackValue(_p12);
  });

  MitmCaState state(String? fingerprint, {int lease = 0}) =>
      MitmCaState(loaded: true, fingerprint: fingerprint, leaseMillis: lease);

  setUp(() {
    mitmFeature = true;
    MitmCoreCaLease.renewEvery = const Duration(hours: 1);
    calls = [];
    identity = 'verified';
    verdict = MitmTrust.ready;
    legacy = null;
    loaded.clear();
    leases.clear();
    checks = 0;
    stops = 0;
    String? current;
    passphrases = _Passphrases()
      ..values[_coreFp] = 'core secret'
      ..values[_pendingFp] = 'pending secret';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'coreIdentity' => identity,
            'certificate' => legacy,
            'deleteLegacy' =>
              (call.arguments as Map)['fingerprint'] == _legacyFp,
            _ => null,
          };
        });
    core = _MockCore();
    when(() => core.setMitmCa(any())).thenAnswer((call) async {
      final secret = call.positionalArguments.single as MitmCaSecret;
      loaded.add(secret);
      current = secret.fingerprint;
      return state(current);
    });
    when(() => core.issueMitmCheck(any())).thenAnswer((_) async {
      checks++;
      return MitmCheckLeaf(pem: 'leaf of $current', check: 'c$checks');
    });
    when(() => core.leaseMitmTrust(any(), any())).thenAnswer((call) async {
      final fingerprint = call.positionalArguments[0] as String;
      leases.add((fingerprint, call.positionalArguments[1] as String));
      return state(fingerprint, lease: 10000);
    });
    when(() => core.stopMitmSigning(timeout: any(named: 'timeout'))).thenAnswer(
      (_) async {
        stops++;
        current = null;
        return const MitmCaState();
      },
    );
    when(() => core.generateMitmCa()).thenAnswer(
      (_) async => MitmGeneratedCa(
        p12: _pendingP12,
        passphrase: 'generated secret',
        certificate: _cert(_pendingFp, 'Flash pending'),
      ),
    );
    when(() => core.inspectMitmCa(any(), any())).thenAnswer((call) async {
      if (call.positionalArguments[1] != 'right') {
        throw const CoreMethodException(
          code: 'mitm_ca',
          message: 'refused',
          details: {'reason': 'badPassphrase'},
        );
      }
      return _cert(_pendingFp, 'Imported');
    });
    store = _MockTrustStore();
    when(() => store.check(any(), any())).thenAnswer((call) async {
      await (call.positionalArguments[1] as Future<String> Function())();
      return MitmTrustCheck(verdict);
    });
    when(
      () => store.install(any()),
    ).thenAnswer((_) async => MitmInstallOutcome.installed);
    when(
      () => store.remove(any()),
    ).thenAnswer((_) async => MitmRemoveOutcome.removed);
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        mitmSignerProvider.overrideWithValue(const MitmSigner()),
        mitmTrustStoreProvider.overrideWithValue(store),
        mitmPassphraseStoreProvider.overrideWithValue(passphrases),
        enabledMitmModuleRulesProvider.overrideWith(
          (_) async => MitmModuleRules.empty,
        ),
      ],
    );
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(mitmSetupProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    mitmFeature = false;
    MitmCoreCaLease.renewEvery = const Duration(seconds: 5);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Mitm mitm() => container.read(patchClashConfigProvider).mitm;

  void setMitm(Mitm value) =>
      container.read(patchClashConfigProvider.notifier).value =
          PatchClashConfig(mitm: value);

  Mitm coreMitm({bool enable = true, String? trusted}) => Mitm(
    enable: enable,
    hostname: const ['example.com'],
    caP12: _p12,
    caCertificate: _cert(_coreFp, 'Flash core'),
    trustedFingerprint: trusted,
  );

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> started() async {
    container.read(mitmCoreCaProvider);
    await settle();
  }

  group('the lease loop', () {
    test('names the Core as signer only after the first lease', () async {
      setMitm(coreMitm());
      expect(container.read(mitmSetupProvider)!['decrypt-tls'], isFalse);
      expect(container.read(mitmSetupProvider), isNot(contains('signer')));

      await started();

      expect(loaded.single.fingerprint, _coreFp);
      expect(loaded.single.passphrase, 'core secret');
      expect(leases, [(_coreFp, 'c1')]);
      final setup = container.read(mitmSetupProvider)!;
      expect(setup['signer'], 'core');
      expect(setup['decrypt-tls'], isTrue);
      expect(setup['ca-fingerprint'], _coreFp);
      expect(mitm().trustedFingerprint, _coreFp);
      expect(
        calls
            .where((call) => call.method == 'activity')
            .map((c) => c.arguments),
        [
          {'hold': true},
        ],
      );
    });

    test('a persisted trust alone never enables the Core signer', () {
      setMitm(coreMitm(trusted: _coreFp));
      final setup = container.read(mitmSetupProvider)!;
      expect(setup['decrypt-tls'], isFalse);
      expect(setup, isNot(contains('signer')));
    });

    test('renews from each check and loads the CA once', () async {
      MitmCoreCaLease.renewEvery = const Duration(milliseconds: 20);
      setMitm(coreMitm());
      await started();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(leases.length, greaterThanOrEqualTo(3));
      expect(loaded, hasLength(1));
      expect(leases.map((lease) => lease.$2).toSet(), hasLength(leases.length));
    });

    test('a check that errors sends nothing and keeps the setup', () async {
      setMitm(coreMitm());
      await started();
      when(
        () => store.check(any(), any()),
      ).thenThrow(const ProcessException('security', [], 'timeout'));
      await container.read(mitmCoreCaProvider.notifier).checkNow();
      expect(leases, hasLength(1));
      expect(stops, 0);
      expect(
        container.read(mitmCoreCaProvider).status,
        MitmCoreCaStatus.lapsed,
      );
      expect(container.read(mitmSetupProvider)!['signer'], 'core');
    });

    test('an unknown check reloads the CA on the next round', () async {
      setMitm(coreMitm());
      await started();
      when(() => core.leaseMitmTrust(any(), any())).thenThrow(
        const CoreMethodException(
          code: 'mitm_ca',
          message: 'x',
          details: {'reason': 'unknownCheck'},
        ),
      );
      await container.read(mitmCoreCaProvider.notifier).checkNow();
      expect(loaded, hasLength(1));
      when(
        () => core.leaseMitmTrust(any(), any()),
      ).thenAnswer((call) async => state(_coreFp, lease: 1));
      await container.read(mitmCoreCaProvider.notifier).checkNow();
      expect(loaded, hasLength(2));
    });

    test('untrusted stops signing and turns decryption off', () async {
      setMitm(coreMitm());
      await started();
      verdict = MitmTrust.untrusted;
      await container.read(mitmCoreCaProvider.notifier).checkNow();
      expect(stops, 1);
      expect(
        container.read(mitmCoreCaProvider).status,
        MitmCoreCaStatus.untrusted,
      );
      expect(mitm().trustedFingerprint, isNull);
      final setup = container.read(mitmSetupProvider)!;
      expect(setup['decrypt-tls'], isFalse);
      expect(setup, isNot(contains('signer')));
      expect(calls.last.method, 'activity');
      expect(calls.last.arguments, {'hold': false});
    });

    test('trust found again resumes nothing until asked to', () async {
      setMitm(coreMitm());
      await started();
      verdict = MitmTrust.untrusted;
      await container.read(mitmCoreCaProvider.notifier).checkNow();
      verdict = MitmTrust.ready;
      await container.read(mitmCoreCaProvider.notifier).checkNow();
      expect(leases, hasLength(1));
      expect(
        container.read(mitmCoreCaProvider).status,
        MitmCoreCaStatus.untrusted,
      );
      expect(container.read(mitmSetupProvider)!['decrypt-tls'], isFalse);
      expect(mitm().enable, isTrue);

      await container.read(mitmCoreCaProvider.notifier).retrust();

      expect(leases, hasLength(2));
      expect(
        container.read(mitmCoreCaProvider).status,
        MitmCoreCaStatus.leased,
      );
      expect(container.read(mitmSetupProvider)!['decrypt-tls'], isTrue);
    });

    test('a retrust still untrusted stays stopped', () async {
      setMitm(coreMitm());
      await started();
      verdict = MitmTrust.untrusted;
      await container.read(mitmCoreCaProvider.notifier).checkNow();
      await container.read(mitmCoreCaProvider.notifier).retrust();
      expect(leases, hasLength(1));
      expect(
        container.read(mitmCoreCaProvider).status,
        MitmCoreCaStatus.untrusted,
      );
    });

    test('a Core that failed its identity check gets no CA', () async {
      identity = 'failed:cdhash';
      setMitm(coreMitm());
      await started();
      expect(loaded, isEmpty);
      expect(
        container.read(mitmCoreCaProvider).failure,
        MitmCoreCaFailure.coreIdentity,
      );
    });

    test('a missing passphrase is said, not guessed', () async {
      passphrases.values.clear();
      setMitm(coreMitm());
      await started();
      expect(loaded, isEmpty);
      expect(
        container.read(mitmCoreCaProvider).failure,
        MitmCoreCaFailure.passphraseMissing,
      );
    });

    test('a reconnected Core gets the CA and a lease again at once', () async {
      setMitm(coreMitm());
      await started();
      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      await settle();
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await settle();
      expect(loaded, hasLength(2));
      expect(leases.length, greaterThanOrEqualTo(2));
    });

    test('turning MITM off stops signing', () async {
      setMitm(coreMitm());
      await started();
      setMitm(coreMitm(enable: false, trusted: _coreFp));
      await settle();
      expect(stops, 1);
      expect(container.read(mitmCoreCaProvider).status, MitmCoreCaStatus.off);
    });

    test('a legacy user stays on the app signer', () async {
      setMitm(
        const Mitm(
          enable: true,
          hostname: ['example.com'],
          trustedFingerprint: _legacyFp,
        ),
      );
      await started();
      expect(loaded, isEmpty);
      final setup = container.read(mitmSetupProvider)!;
      expect(setup['decrypt-tls'], isTrue);
      expect(setup['ca-fingerprint'], _legacyFp);
      expect(setup, isNot(contains('signer')));
    });
  });

  group('the staged switch', () {
    Mitm legacyMitm() => const Mitm(
      enable: true,
      hostname: ['example.com'],
      trustedFingerprint: _legacyFp,
    );

    setUp(() {
      legacy = {
        'pem': 'LEGACY',
        'fingerprint': _legacyFp,
        'subject': 'Flash legacy',
        'notBefore': 0,
        'notAfter': 4102444800000,
      };
      passphrases.values.remove(_pendingFp);
    });

    MitmCaMigration migration() =>
        container.read(mitmCaMigrationProvider.notifier);

    test('a new CA waits as pending and the legacy one stays', () async {
      setMitm(legacyMitm());
      await migration().generate();
      expect(mitm().pendingCaCertificate?.fingerprint, _pendingFp);
      expect(mitm().pendingCaP12, _pendingP12);
      expect(mitm().coreCa, isNull);
      expect(mitm().trustedFingerprint, _legacyFp);
      expect(passphrases.values[_pendingFp], 'generated secret');
      expect(container.read(mitmSetupProvider)!['ca-fingerprint'], _legacyFp);
    });

    test('switches only once trusted, checked and leased', () async {
      setMitm(legacyMitm());
      await migration().generate();
      expect(
        await migration().installAndSwitch(),
        MitmMigrationOutcome.switched,
      );
      verify(() => store.install(any())).called(1);
      expect(loaded.single.fingerprint, _pendingFp);
      expect(leases.first.$1, _pendingFp);
      expect(mitm().coreCa?.fingerprint, _pendingFp);
      expect(mitm().caP12, _pendingP12);
      expect(mitm().pendingCaCertificate, isNull);
      final setup = container.read(mitmSetupProvider)!;
      expect(setup['signer'], 'core');
      expect(setup['ca-fingerprint'], _pendingFp);
      // The legacy CA is left for the user to remove.
      expect(calls.where((call) => call.method == 'deleteLegacy'), isEmpty);
      expect(calls.where((call) => call.method == 'delete'), isEmpty);
    });

    test('a cancelled install leaves everything as it was', () async {
      setMitm(legacyMitm());
      await migration().generate();
      when(
        () => store.install(any()),
      ).thenThrow(const ProcessException('security', [], 'canceled', 1));
      expect(
        await migration().installAndSwitch(),
        MitmMigrationOutcome.cancelled,
      );
      expect(loaded, isEmpty);
      expect(mitm().coreCa, isNull);
      expect(mitm().trustedFingerprint, _legacyFp);
      expect(container.read(mitmSetupProvider), isNot(contains('signer')));
    });

    test('an untrusted CA is never switched to', () async {
      setMitm(legacyMitm());
      await migration().generate();
      verdict = MitmTrust.untrusted;
      expect(
        await migration().installAndSwitch(),
        MitmMigrationOutcome.untrusted,
      );
      expect(leases, isEmpty);
      expect(stops, 1);
      expect(mitm().coreCa, isNull);
      expect(mitm().pendingCaCertificate?.fingerprint, _pendingFp);
      expect(mitm().trustedFingerprint, _legacyFp);
    });

    test('a refused Core identity changes nothing', () async {
      setMitm(legacyMitm());
      await migration().generate();
      identity = 'none';
      expect(await migration().verify(), MitmMigrationOutcome.coreIdentity);
      expect(loaded, isEmpty);
      expect(mitm().coreCa, isNull);
    });

    test('removing the old certificate names the legacy one only', () async {
      setMitm(legacyMitm());
      await migration().generate();
      await migration().installAndSwitch();
      expect((await migration().oldCertificate())?.fingerprint, _legacyFp);
      expect(await migration().removeOld(), isTrue);
      final deletes = calls.where((call) => call.method == 'deleteLegacy');
      expect(deletes.single.arguments, {'fingerprint': _legacyFp});
    });

    test('an import refused by the Core says why and keeps nothing', () async {
      setMitm(legacyMitm());
      await expectLater(
        migration().import(MitmCaP12('QUJD'), 'wrong'),
        throwsA(
          isA<CoreMethodException>().having(
            (error) => error.details,
            'details',
            {'reason': 'badPassphrase'},
          ),
        ),
      );
      expect(mitm().pendingCaCertificate, isNull);
      expect(passphrases.values, isNot(contains(_pendingFp)));
    });

    test('with no CA at all the first one is in use at once', () async {
      legacy = null;
      setMitm(const Mitm(enable: true, hostname: ['example.com']));
      await migration().generate();
      expect(mitm().coreCa?.fingerprint, _pendingFp);
      expect(mitm().pendingCaCertificate, isNull);
      expect(mitm().trustedFingerprint, isNull);
    });
  });
}
