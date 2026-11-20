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

const _channel = MethodChannel(MitmSigner.channelName);
final _spki = Uint8List.fromList([1, 2, 3]);

/// The SHA-256 fingerprint of the fake root `[6]` every fake sign returns:
/// the app sends a leaf only with the root the user confirmed.
const _rootFingerprint =
    '67:58:6E:98:FA:D2:7D:A0:B9:96:8B:C0:39:A1:EF:34:C9:39:B9:B8:E5:23:A8:BE:F8:9D:47:86:08:C5:EC:F6';

/// The macOS path a signing request takes once it reaches Dart, in real
/// time: every MitmSigner call is a platform-channel round trip (a main
/// thread hop each way) onto ONE serial native queue
/// (macos/Runner/MitmSignerChannel.swift), the trust store runs
/// `security verify-cert`, and each answer goes back through the relay's
/// serial send. The costs are the Go burst model's "busy" ones
/// (core/mitm_sign_burst_test.go).
class _Costs {
  const _Costs();

  final hop = const Duration(milliseconds: 8);
  final identity = const Duration(milliseconds: 2);
  final certRead = const Duration(milliseconds: 15);
  final checkSign = const Duration(milliseconds: 17);
  final sign = const Duration(milliseconds: 18);
  final verify = const Duration(milliseconds: 60);
  final sendEach = const Duration(milliseconds: 3);
}

class _NativeQueue {
  _NativeQueue(this.costs);

  final _Costs costs;
  Future<void> _tail = Future.value();
  final arrivals = <(String, Duration)>[];
  final clock = Stopwatch()..start();

  Duration _cost(String method) => switch (method) {
    'coreIdentity' => costs.identity,
    'certificate' => costs.certRead,
    'checkCertificate' => costs.checkSign,
    'sign' => costs.sign,
    _ => Duration.zero,
  };

  Future<Object?> call(MethodCall call) async {
    await Future<void>.delayed(costs.hop);
    arrivals.add((call.method, clock.elapsed));
    final done = Completer<void>();
    final previous = _tail;
    _tail = done.future;
    await previous;
    await Future<void>.delayed(_cost(call.method));
    done.complete();
    await Future<void>.delayed(costs.hop);
    return switch (call.method) {
      'coreIdentity' => 'verified',
      'certificate' => {
        'pem': 'PEM',
        'fingerprint': _rootFingerprint,
        'subject': 'Test',
        'notBefore': 0,
        'notAfter': 4102444800000,
      },
      'checkCertificate' => 'leaf PEM',
      'sign' => {
        'cert': Uint8List.fromList([4]),
        'ca': Uint8List.fromList([6]),
      },
      _ => null,
    };
  }
}

class _VerifyStore implements MitmTrustStore {
  _VerifyStore(this.costs);

  final _Costs costs;
  int checks = 0;

  @override
  Future<MitmTrustCheck> check(
    MitmCertificate ca,
    Future<String> Function() issueLeaf,
  ) async {
    checks++;
    await issueLeaf();
    await Future<void>.delayed(costs.verify);
    return const MitmTrustCheck(MitmTrust.ready);
  }

  @override
  Future<MitmInstallOutcome> install(MitmCertificate ca) =>
      throw UnimplementedError();

  @override
  Future<MitmRemoveOutcome> remove(MitmCertificate ca) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _NativeQueue native;
  late _VerifyStore store;
  late List<(int, MitmSignStage, Duration)> stages;
  late List<Map<String, Object?>> sent;
  const costs = _Costs();

  setUp(() {
    mitmFeature = true;
    stages = [];
    sent = [];
    native = _NativeQueue(costs);
    store = _VerifyStore(costs);
    MitmSignAction.timing = (reqId, stage, since) =>
        stages.add((reqId, stage, since));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, native.call);
    final core = _MockCoreHandlerInterface();
    var sending = Future<void>.value();
    when(() => core.sendMitmSignResult(any(), any())).thenAnswer((call) {
      // The relay sends one frame at a time.
      final previous = sending;
      final done = Completer<void>();
      sending = done.future;
      return previous.then((_) async {
        await Future<void>.delayed(costs.sendEach);
        sent.add(
          (call.positionalArguments[1] as MitmSignResult).toJson(
            call.positionalArguments[0] as int,
          ),
        );
        done.complete();
      });
    });
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        mitmSignerProvider.overrideWithValue(const MitmSigner()),
        mitmTrustStoreProvider.overrideWithValue(store),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
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
        hostname: ['*.burst.example'],
        trustedFingerprint: _rootFingerprint,
      ),
    );
  });

  setUpAll(() => registerFallbackValue(const MitmSignResult()));

  tearDown(() {
    MitmSignAction.timing = null;
    container.dispose();
    mitmFeature = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> answer(int reqId) => container
      .read(mitmSignActionProvider.notifier)
      .answer(
        MitmSignRequest.fromJson({
          'reqId': reqId,
          'deadlineUnixMillis': DateTime.now()
              .add(const Duration(seconds: 10))
              .millisecondsSinceEpoch,
          'host': 'h$reqId.burst.example',
          'spki': base64.encode(_spki),
        }, managedRelay: true),
      );

  Future<void> burst(int size) =>
      Future.wait([for (var i = 1; i <= size; i++) answer(i)]);

  Duration at(int reqId, MitmSignStage stage) =>
      stages.firstWhere((s) => s.$1 == reqId && s.$2 == stage).$3;

  List<Duration> all(MitmSignStage stage) => [
    for (final s in stages)
      if (s.$2 == stage) s.$3,
  ]..sort();

  Duration p(List<Duration> sorted, double q) => sorted.isEmpty
      ? Duration.zero
      : sorted[((sorted.length - 1) * q).toInt()];

  String ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);

  void report(String name, int size) {
    final rows = <String>[];
    for (final stage in MitmSignStage.values.skip(1)) {
      final values = all(stage);
      rows.add(
        '| $name | $size | ${stage.name} | ${ms(p(values, 0.5))} | '
        '${ms(p(values, 0.95))} | ${ms(p(values, 1))} |',
      );
    }
    final busy = sent.where((s) => s['error'] == 'signBusy').length;
    rows.add('| $name | $size | signBusy | $busy | | |');
    final path = Platform.environment['FLASH_MITM_BURST_OUT'];
    if (path != null) {
      File(
        path,
      ).writeAsStringSync('${rows.join('\n')}\n', mode: FileMode.append);
    }
  }

  test('a burst shares one trust check and its stages are timed', () async {
    await burst(12);
    report('dart busy', 12);
    expect(sent.where((s) => s['cert'] != null), hasLength(12));
    expect(store.checks, 1);
    // Every request passes every stage, in order.
    for (var reqId = 1; reqId <= 12; reqId++) {
      final mine = [
        for (final s in stages)
          if (s.$1 == reqId) s.$2,
      ];
      expect(mine, MitmSignStage.values);
      expect(
        at(reqId, MitmSignStage.sent),
        greaterThanOrEqualTo(at(reqId, MitmSignStage.signed)),
      );
    }
    // The serial native queue: the last of 12 signs waits for 11 others.
    final signed = all(MitmSignStage.signed);
    expect(signed.last - signed.first, greaterThanOrEqualTo(costs.sign * 11));
  });

  test('the root and the check leaf reach the native queue together', () async {
    await burst(1);
    Duration arrival(String method) =>
        native.arrivals.firstWhere((a) => a.$1 == method).$2;
    // Issued in one round: apart by far less than a round trip.
    expect(
      arrival('checkCertificate') - arrival('certificate'),
      lessThan(costs.hop),
    );
    // coreIdentity still goes first, alone: a Core that fails it opens no
    // keychain item.
    expect(
      arrival('certificate') - arrival('coreIdentity'),
      greaterThanOrEqualTo(costs.hop * 2 + costs.identity),
    );
  });

  test('more than 16 at once are refused as signBusy', () async {
    await burst(20);
    report('dart busy', 20);
    expect(sent.where((s) => s['error'] == 'signBusy'), hasLength(4));
    expect(sent.where((s) => s['cert'] != null), hasLength(16));
  });

  test('a record holds the request number alone', () async {
    await burst(2);
    for (final (reqId, stage, since) in stages) {
      expect(reqId, isA<int>());
      expect(stage, isA<MitmSignStage>());
      expect(since, isA<Duration>());
    }
    MitmSignAction.timing = null;
    stages.clear();
    sent.clear();
    await burst(1);
    expect(stages, isEmpty);
  });
}
