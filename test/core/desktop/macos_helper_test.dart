import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/core/desktop/rpc_client.dart';
import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/method.dart';

import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_launcher.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/macos_helper_transport.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/desktop/transport.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = '0123456789abcdef0123456789abcdef';

final class _SignListener with CoreEventListener {
  _SignListener(this.requests);

  final Completer<MitmSignRequest> requests;

  @override
  void onMitmSign(MitmSignRequest request) => requests.complete(request);
}

class _Native implements MacHelperNativeApi {
  final calls = <String>[];
  final arguments = <Map<String, Object?>>[];
  String state = 'enabled';
  Map<String, Object?> statusExtra = const {};
  String stopCode = 'ok';
  bool stopExitConfirmed = true;
  String startCode = 'ok';
  bool exitConfirmed = true;
  Completer<Map<Object?, Object?>> receive = Completer();

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    this.arguments.add(arguments);
    return switch (method) {
      'status' => {'code': state, ...statusExtra},
      'start' => {
        'code': startCode,
        'protocol': 1,
        'pid': 42,
        'exitConfirmed': exitConfirmed,
      },
      'stop' => {
        'code': stopCode,
        'exitConfirmed': stopCode == 'ok' && stopExitConfirmed,
      },
      'migrate' => {'code': state},
      'receive' => receive.future,
      _ => {'code': 'ok'},
    };
  }
}

class _StaleStatusNative extends _Native {
  Completer<Map<Object?, Object?>>? delayedStatus;
  Completer<Map<Object?, Object?>>? delayedStop;

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) {
    if (method == 'status' && delayedStatus != null) {
      final reply = delayedStatus!;
      delayedStatus = null;
      return reply.future;
    }
    if (method == 'stop' && delayedStop != null) return delayedStop!.future;
    return super.invoke(method, arguments);
  }
}

final class _RelayCall {
  final Map<String, Object?> arguments;
  final reply = Completer<Map<Object?, Object?>>();

  _RelayCall(this.arguments);
}

final class _RelayNative implements MacHelperNativeApi {
  final sends = <_RelayCall>[];
  final receives = <_RelayCall>[];
  final calls = <String>[];
  final notes = <String>[];
  final lost = <String>[];
  int externalPending = 0;
  int maxPending = 0;
  String stopCode = 'ok';
  Object? stopError;
  Completer<Map<Object?, Object?>>? stopReply;

  int get pending =>
      externalPending +
      [...sends, ...receives].where((call) => !call.reply.isCompleted).length;

  Future<Map<Object?, Object?>> _hold(
    List<_RelayCall> destination,
    Map<String, Object?> arguments,
  ) {
    final full = pending >= 32;
    final call = _RelayCall(arguments);
    destination.add(call);
    if (full) call.reply.complete({'code': 'backpressure'});
    if (pending > maxPending) maxPending = pending;
    return call.reply.future;
  }

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) {
    calls.add(method);
    switch (method) {
      case 'status':
        return Future.value({'code': 'enabled'});
      case 'start':
        return Future.value({'code': 'ok', 'protocol': 1, 'pid': 42});
      case 'stop':
        if (stopError != null) return Future.error(stopError!);
        if (pending >= 32) return Future.value({'code': 'backpressure'});
        return stopReply?.future ??
            Future.value({'code': stopCode, 'exitConfirmed': stopCode == 'ok'});
      case 'send':
        return _hold(sends, arguments);
      case 'receive':
        return _hold(receives, arguments);
      case 'note':
        notes.add(arguments['reason'] as String);
        return Future.value({'code': 'ok'});
      case 'relayLost':
        lost.add(arguments['reason'] as String);
        return Future.value({'code': 'ok'});
      default:
        throw StateError('Unexpected fake method: $method');
    }
  }
}

final class _RelayFixture {
  final native = _RelayNative();
  late final MacHelperClient client;
  final events = <MacHelperEvent>[];
  late final StreamSubscription<MacHelperEvent> subscription;
  String session = _session;
  bool _closed = false;

  /// [maxRelayFailures] 1: the first failed relay request ends the relay
  /// (the retry budget has tests of its own).
  _RelayFixture({
    int backpressureRetries = 500,
    int maxRelayFailures = 1,
    Duration relayRetryDelay = Duration.zero,
  }) {
    client = MacHelperClient(
      native: native,
      safeMode: () => false,
      backpressureRetries: backpressureRetries,
      maxRelayFailures: maxRelayFailures,
      relayRetryDelay: relayRetryDelay,
    );
    subscription = client.events.listen(events.add);
    addTearDown(close);
  }

  Iterable<MacHelperDisconnected> get disconnects =>
      events.whereType<MacHelperDisconnected>();

  Future<void> start([String value = _session]) async {
    session = value;
    await client.start(session);
    await _flush();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    native.externalPending = 0;
    native.stopCode = 'ok';
    native.stopError = null;
    native.stopReply = null;
    await client.stop(session);
    for (final call in [...native.sends, ...native.receives]) {
      if (!call.reply.isCompleted) call.reply.complete({'code': 'stopped'});
    }
    await _flush(const Duration(milliseconds: 32));
    await subscription.cancel();
  }
}

Future<void> _flush([Duration duration = Duration.zero]) =>
    Future<void>.delayed(duration);

Future<void> _until(bool Function() condition) async {
  final elapsed = Stopwatch()..start();
  while (!condition()) {
    if (elapsed.elapsed > const Duration(seconds: 1)) {
      fail('Relay did not progress within one second');
    }
    await _flush(const Duration(milliseconds: 1));
  }
}

Matcher _helperCode(String code) =>
    isA<MacHelperException>().having((error) => error.code, 'code', code);

/// A native side driven by a script, for update / lost-connection sequences.
final class _ScriptNative implements MacHelperNativeApi {
  final calls = <String>[];
  final Map<Object?, Object?> Function(String method) answer;

  _ScriptNative(this.answer);

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    return answer(method);
  }
}

Map<Object?, Object?> _daemon(String code, {int pid = 0, bool? confirmed}) => {
  'code': code,
  'protocol': 1,
  'pid': pid,
  'exitConfirmed': confirmed ?? pid == 0,
};

const _applied = CoreLifecycleResult(
  revision: 1,
  outcome: CoreLifecycleOutcome.applied,
);

void main() {
  test('old status cannot forget a newer stopping session', () async {
    final native = _StaleStatusNative();
    final client = MacHelperClient(native: native, safeMode: () => false);
    await client.start(_session);
    native.stopExitConfirmed = false;
    expect(await client.stop(_session), isFalse);
    final statusReply = Completer<Map<Object?, Object?>>();
    native.delayedStatus = statusReply;
    final status = client.status();
    native.stopExitConfirmed = true;
    expect(await client.stop(_session), isTrue);
    const next = '1123456789abcdef0123456789abcdef';
    await client.start(next);
    final stopReply = Completer<Map<Object?, Object?>>();
    native.delayedStop = stopReply;
    final stop = client.stop(next);
    statusReply.complete({'code': 'enabled', 'exitConfirmed': true, 'pid': 0});
    await status;
    expect(client.hasCoreSession, isTrue);
    stopReply.complete({'code': 'unavailable'});
    expect(await stop, isFalse);
    expect(client.hasCoreSession, isTrue);
  });
  test('helper migration is explicit and never blocks owned stop', () async {
    final native = _Native()..state = 'migrationRequired';
    final client = MacHelperClient(native: native, safeMode: () => false);
    expect(await client.status(), MacHelperState.migrationRequired);
    expect(
      macHelperCardKind(MacHelperState.migrationRequired, false),
      MacHelperCardKind.migration,
    );
    await expectLater(
      client.start(_session),
      throwsA(_helperCode('migrationRequired')),
    );
    expect(native.calls, everyElement('status'));
    expect(
      () => client.migrate(confirmed: false),
      throwsA(_helperCode('consentRequired')),
    );
    native.state = 'enabled';
    await client.start(_session);
    native.state = 'migrationRequired';
    native.calls.clear();
    expect(await client.stop(_session), isTrue);
    expect(native.calls, ['stop']);
    native.receive.complete({'code': 'stopped'});
  });

  test(
    'status is passive and preserves precise authorization states',
    () async {
      const expected = {
        'enabled': MacHelperState.enabled,
        'migrationRequired': MacHelperState.migrationRequired,
        'requiresApproval': MacHelperState.requiresApproval,
        'notRegistered': MacHelperState.notRegistered,
        'staleHelper': MacHelperState.staleHelper,
        'signingRequired': MacHelperState.signatureFailed,
        'notFound': MacHelperState.reinstallRequired,
        'moveRequired': MacHelperState.moveRequired,
        'migrationIncomplete': MacHelperState.updateFailed,
        'unsupported': MacHelperState.unsupported,
        'unavailable': MacHelperState.starting,
      };
      for (final MapEntry(key: code, value: state) in expected.entries) {
        final native = _Native()..state = code;
        expect(await MacHelperClient(native: native).status(), state);
        expect(native.calls, ['status']);
      }
    },
  );

  test(
    'safe mode blocks every native owner entry without calling channels',
    () async {
      final native = _Native();
      final client = MacHelperClient(native: native, safeMode: () => true);
      expect(await client.status(), MacHelperState.disabled);
      expect(
        () => client.migrate(confirmed: true),
        throwsA(isA<MacHelperException>()),
      );
      expect(() => client.enable(), throwsA(isA<MacHelperException>()));
      expect(() => client.repair(), throwsA(isA<MacHelperException>()));

      await expectLater(
        client.start(_session),
        throwsA(isA<MacHelperException>()),
      );
      await expectLater(
        client.stop(_session),
        throwsA(isA<MacHelperException>()),
      );
      expect(() => client.send([1]), throwsA(isA<MacHelperException>()));
      expect(native.calls, isEmpty);
    },
  );

  test('migration requires consent and reports the native outcome', () async {
    final native = _Native()..state = 'migrationRequired';
    final client = MacHelperClient(native: native);
    expect(
      () => client.migrate(confirmed: false),
      throwsA(isA<MacHelperException>()),
    );
    expect(native.calls, isEmpty);
    expect(
      await client.migrate(confirmed: true),
      MacHelperState.migrationRequired,
    );
    expect(native.calls, ['migrate']);
    expect(native.arguments.last, {'confirmed': true});
  });

  for (final state in [
    'migrationRequired',
    'requiresApproval',
    'notRegistered',
    'staleHelper',
    'signingRequired',
    'notFound',
    'incompatible',
    'moveRequired',
    'migrationIncomplete',
    'unsupported',
    'unavailable',
  ]) {
    test(
      'managed launcher refuses $state without fallback or registration',
      () async {
        final native = _Native()..state = state;
        final launcher = MacHelperLauncher(MacHelperClient(native: native));
        await expectLater(
          launcher.resolve(),
          throwsA(isA<MacHelperException>()),
        );
        expect(native.calls, ['status']);
      },
    );
  }

  test(
    'lease start never forwards endpoint or executable and stop is idempotent',
    () async {
      final native = _Native();
      final client = MacHelperClient(native: native);
      final lease = await MacHelperLauncher(
        client,
      ).start(sessionId: _session, address: '/untrusted/address');
      expect(lease.pid, 42);
      expect(lease.owner, CoreProcessOwner.helper);
      expect(native.arguments[native.calls.indexOf('start')], {
        'session': _session,
      });
      final first = await lease.stop(const Duration(seconds: 1));
      expect(first.exitConfirmed, isTrue);
      expect(await lease.stop(const Duration(seconds: 1)), first);
      expect(native.calls.where((method) => method == 'stop'), hasLength(1));
    },
  );

  test(
    'unconfirmed stop retains ownership, rejects replacement, and supports retry',
    () async {
      final native = _Native()..stopCode = 'exitUnconfirmed';
      final client = MacHelperClient(native: native);
      expect(client.hasCoreSession, isFalse);
      final lease = await MacHelperLauncher(
        client,
      ).start(sessionId: _session, address: 'ignored');
      expect(
        (await lease.stop(const Duration(seconds: 1))).exitConfirmed,
        isFalse,
      );
      await expectLater(
        client.start('11111111111111111111111111111111'),
        throwsA(isA<MacHelperException>()),
      );
      expect(native.calls.where((method) => method == 'start'), hasLength(1));
      expect(client.hasCoreSession, isTrue);
      native.stopCode = 'ok';
      expect(
        (await lease.stop(const Duration(seconds: 1))).exitConfirmed,
        isTrue,
      );
      expect(client.hasCoreSession, isFalse);
    },
  );

  test('an ok stop without exit evidence keeps the session owned', () async {
    final native = _Native()..stopExitConfirmed = false;
    final client = MacHelperClient(native: native);
    await client.start(_session);
    expect(await client.stop(_session), isFalse);
    await expectLater(
      client.start('1123456789abcdef0123456789abcdef'),
      throwsA(isA<MacHelperException>()),
    );
    expect(native.calls.where((method) => method == 'start'), hasLength(1));
    native.stopExitConfirmed = true;
    expect(await client.stop(_session), isTrue);
  });

  test('wrong session cannot stop the owned child', () async {
    final native = _Native();
    final client = MacHelperClient(native: native);
    await client.start(_session);
    expect(await client.stop('other-session'), isFalse);
    expect(native.calls, isNot(contains('stop')));
    await client.stop(_session);
  });

  test('confirmed pre-spawn error does not strand a session', () async {
    final native = _Native()..startCode = 'incompatible';
    final client = MacHelperClient(native: native);
    await expectLater(
      client.start(_session),
      throwsA(isA<MacHelperException>()),
    );
    expect(() => client.send([1]), throwsA(_helperCode('notConnected')));
    native.startCode = 'ok';
    expect(await client.start(_session), 42);
    await client.stop(_session);
  });

  test(
    'transport relays unchanged payload and confirms matching disconnect',
    () async {
      final native = _Native();
      final client = MacHelperClient(native: native);
      final transport = MacHelperTransport(client);
      await transport.open();
      final frame = transport.frames.first;
      await client.start(_session);
      final connected = await transport.waitUntilConnected(
        const Duration(seconds: 1),
      );
      expect(connected.pid, 42);
      native.receive.complete({
        'code': 'ok',
        'frames': [
          Uint8List.fromList([123, 125]),
        ],
        'seq': 0,
      });
      expect(await frame, [123, 125]);
      final disconnected = transport.events.firstWhere(
        (event) => event is TransportDisconnected,
      );
      await client.stop(_session);
      expect(
        (await disconnected as TransportDisconnected).generation,
        connected.generation,
      );
      await transport.close();
    },
  );

  test('a sign request over the helper relay is marked as such', () async {
    final native = _Native();
    final client = MacHelperClient(native: native);
    final transport = MacHelperTransport(client);
    final rpc = CoreRpcClient(transport);
    final requests = Completer<MitmSignRequest>();
    final listener = _SignListener(requests);
    coreEventManager.addListener(listener);
    addTearDown(() => coreEventManager.removeListener(listener));
    await transport.open();
    await client.start(_session);
    native.receive.complete({
      'code': 'ok',
      'seq': 0,
      'frames': [
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'method': CoreMethod.message.wireName,
              'arguments': {
                'type': 'mitmSign',
                'data': {'reqId': 1, 'host': 'a.test', 'spki': 'AQ=='},
              },
            }),
          ),
        ),
      ],
    });

    expect((await requests.future).managedRelay, isTrue);
    await client.stop(_session);
    await rpc.close();
    await transport.close();
  });

  test(
    'maintenance stops through its lifecycle owner before migration',
    () async {
      final native = _Native()..state = 'migrationRequired';
      final client = MacHelperClient(native: native);
      final gate = Completer<CoreLifecycleResult>();
      final maintenance = MacHelperMaintenance(client, stop: () => gate.future);
      await maintenance.check();
      native.calls.clear();
      final operation = maintenance.migrate(confirmed: true);
      await expectLater(
        client.start(_session),
        throwsA(isA<MacHelperException>()),
      );
      expect(native.calls, isEmpty);
      gate.complete(
        const CoreLifecycleResult(
          revision: 1,
          outcome: CoreLifecycleOutcome.applied,
        ),
      );
      expect(await operation, MacHelperState.migrationRequired);
      expect(native.calls, ['migrate']);
    },
  );

  test(
    'failed or superseded stop locks replacement, including recheck',
    () async {
      for (final superseded in [false, true]) {
        final native = _Native()..state = 'migrationRequired';
        final maintenance = MacHelperMaintenance(
          MacHelperClient(native: native),
          stop: () async {
            if (!superseded) throw StateError('unknown exit');
            return const CoreLifecycleResult(
              revision: 1,
              outcome: CoreLifecycleOutcome.superseded,
            );
          },
        );
        await maintenance.check();
        native.calls.clear();
        expect(
          await maintenance.migrate(confirmed: true),
          MacHelperState.exitUnconfirmed,
        );
        expect(native.calls, isEmpty);
        native.state = 'enabled';
        expect(await maintenance.check(), MacHelperState.exitUnconfirmed);
        expect(
          await maintenance.migrate(confirmed: true),
          MacHelperState.exitUnconfirmed,
        );
        expect(native.calls, ['status']);
      }
    },
  );

  test(
    'untrusted or unsupported builds offer no activation or retry action',
    () async {
      final l = lookupAppLocalizations(const Locale('en'));
      for (final code in ['signingRequired', 'unsupported', 'notFound']) {
        final flow = MacHelperMaintenance(
          MacHelperClient(native: _Native()..state = code),
          stop: () async => const CoreLifecycleResult(
            revision: 1,
            outcome: CoreLifecycleOutcome.applied,
          ),
        );
        await flow.check();
        final view = macHelperCardView(l, flow);
        expect(view.primary, isNull, reason: code);
        expect(
          view.secondary,
          anyOf(isNull, MacHelperCardAction.viewDetails),
          reason: code,
        );
      }
    },
  );

  group('launcher status cards', () {
    const detail =
        'launcher result: downgrade\n'
        'launcher detail: helper 2026111707 < recorded 2026111708\n'
        'helper version: 2026111707; highest version run: 2026111708; '
        'app version: 2026111707; launcher version: 1';
    const cards = {
      'launcherCheckFailed': (
        MacHelperState.launcherCheckFailed,
        MacHelperCardKind.launcherCheckFailed,
        MacHelperBarKind.failedCheck,
        'Flash 未通过安全检查',
        '辅助程序未启动，请重新安装最新的可信版本。',
      ),
      'launcherDowngrade': (
        MacHelperState.launcherDowngrade,
        MacHelperCardKind.launcherDowngrade,
        MacHelperBarKind.notReady,
        'Flash 版本过旧',
        '辅助程序未启动，请安装最新版本的 Flash。',
      ),
      'launcherFailed': (
        MacHelperState.launcherFailed,
        MacHelperCardKind.launcherFailed,
        MacHelperBarKind.notReady,
        '辅助程序未能启动',
        '系统未能完成辅助程序的准备或启动，请查看详情。',
      ),
    };
    for (final MapEntry(key: code, value: expected) in cards.entries) {
      test('$code shows its card with only "View details"', () async {
        final (state, kind, bar, title, body) = expected;
        expect(MacHelperState.parse(code), state);
        expect(macHelperCardKind(state, false), kind);
        expect(macHelperCardKind(state, true), kind);
        final native = _Native()
          ..state = code
          ..statusExtra = {'detail': detail};
        final flow = MacHelperMaintenance(
          MacHelperClient(native: native, safeMode: () => false),
          stop: () async => const CoreLifecycleResult(
            revision: 1,
            outcome: CoreLifecycleOutcome.applied,
          ),
        );
        expect(await flow.check(), state);
        final zh = lookupAppLocalizations(const Locale('zh'));
        final view = macHelperCardView(zh, flow);
        expect(view.kind, kind);
        expect(view.title, title);
        expect(view.detail, body);
        expect(view.isProblem, isTrue);
        // Nothing can run the helper anyway: details only.
        expect(view.primary, isNull);
        expect(view.secondary, MacHelperCardAction.viewDetails);
        expect(view.rawDetail, contains(detail));
        expect(view.rawDetail, contains('status: $code'));
        final barView = macHelperBarView(zh, flow)!;
        expect(barView.kind, bar);
        expect(barView.tone, MacHelperBarTone.failure);
        expect(barView.title, title);
        // Reading the status never acts on the registration or the daemon.
        expect(native.calls, ['status']);
        final en = macHelperCardView(
          lookupAppLocalizations(const Locale('en')),
          flow,
        );
        expect(en.title, isNotEmpty);
        expect(en.title, isNot(title));
        flow.dispose();
      });
    }

    test('an answering helper or an ordinary wait keeps its own card', () {
      // The bridge adds launcher detail to a wait (launcher "ok" within its
      // grace period) without changing the code.
      expect(MacHelperState.parse('timeout'), MacHelperState.starting);
      expect(
        macHelperCardKind(MacHelperState.parse('launcherUnknown'), false),
        MacHelperCardKind.startSlow,
      );
    });
  });

  test('a reply that fails the app\'s verification is its own state: '
      'a failed check, details only, never a recovery', () async {
    const detail =
        'helper reply rejected by the app\'s verification: '
        'failed:status-read errno=1';
    expect(
      MacHelperState.parse('untrustedReply'),
      MacHelperState.untrustedReply,
    );
    for (final slow in [false, true]) {
      expect(
        macHelperCardKind(MacHelperState.untrustedReply, slow),
        MacHelperCardKind.signatureFailed,
      );
    }
    final native = _Native()
      ..state = 'untrustedReply'
      ..statusExtra = {'detail': detail};
    var recoveries = 0;
    final flow = MacHelperMaintenance(
      MacHelperClient(native: native, safeMode: () => false),
      stop: () async => const CoreLifecycleResult(
        revision: 1,
        outcome: CoreLifecycleOutcome.applied,
      ),
      recover: () async {
        recoveries++;
        return MacHelperState.enabled;
      },
    );
    expect(await flow.check(), MacHelperState.untrustedReply);
    final zh = lookupAppLocalizations(const Locale('zh'));
    final view = macHelperCardView(zh, flow);
    expect(view.kind, MacHelperCardKind.signatureFailed);
    expect(view.title, isNot('辅助程序未能启动'));
    expect(view.isProblem, isTrue);
    expect(view.primary, isNull);
    expect(view.secondary, MacHelperCardAction.viewDetails);
    expect(view.rawDetail, contains(detail));
    expect(macHelperBarView(zh, flow)!.kind, MacHelperBarKind.failedCheck);
    // Even the explicit "try again" path and a return to the foreground only
    // read the status again: nothing is unregistered or registered.
    expect(await flow.retryRecovery(), MacHelperState.untrustedReply);
    flow.resumed();
    await Future<void>.delayed(Duration.zero);
    await flow.check();
    expect(recoveries, 0);
    expect(native.calls.where((call) => call != 'status'), isEmpty);
    flow.dispose();
  });

  test('card kinds and actions follow the helper state', () {
    expect(
      macHelperCardKind(MacHelperState.signatureFailed, false),
      MacHelperCardKind.signatureFailed,
    );
    expect(
      macHelperCardKind(MacHelperState.requiresApproval, false),
      MacHelperCardKind.approval,
    );
    expect(
      macHelperCardKind(MacHelperState.notRegistered, false),
      MacHelperCardKind.approval,
    );
    expect(
      macHelperCardKind(MacHelperState.disabledByUser, false),
      MacHelperCardKind.approval,
    );
    for (final state in [
      MacHelperState.registrationStale,
      MacHelperState.notReady,
      MacHelperState.staleCore,
    ]) {
      expect(macHelperCardKind(state, false), MacHelperCardKind.notReady);
    }
    expect(
      macHelperCardKind(MacHelperState.repairing, false),
      MacHelperCardKind.starting,
    );
    expect(
      macHelperCardKind(MacHelperState.starting, false),
      MacHelperCardKind.starting,
    );
    expect(
      macHelperCardKind(MacHelperState.starting, true),
      MacHelperCardKind.startSlow,
    );
    expect(
      macHelperCardKind(MacHelperState.staleHelper, false),
      MacHelperCardKind.starting,
    );
    expect(
      macHelperCardKind(MacHelperState.disabled, false),
      MacHelperCardKind.unsupported,
    );
    expect(
      macHelperCardKind(MacHelperState.enabled, false),
      MacHelperCardKind.ready,
    );
  });

  test(
    '64-frame burst is copied, FIFO, exactly once under native cap 32',
    () async {
      final fixture = _RelayFixture();
      await fixture.start();
      final native = fixture.native;
      for (var index = 0; index < 64; index++) {
        final frame = [index];
        fixture.client.send(frame);
        frame[0] = 255;
      }
      expect(native.sends, hasLength(1));
      expect(native.pending, 2);
      expect(native.receives, hasLength(1));
      for (var index = 0; index < 64; index++) {
        expect(native.sends, hasLength(index + 1));
        expect(native.sends[index].arguments['frame'], [index]);
        expect(native.sends[index].arguments['session'], _session);
        expect(native.pending, 2);
        native.sends[index].reply.complete({'code': 'ok'});
        await _flush();
      }
      expect(native.sends, hasLength(64));
      expect(native.maxPending, 2);
      expect(fixture.disconnects, isEmpty);
      expect(native.calls.where((method) => method == 'stop'), isEmpty);
      await fixture.close();
      expect(fixture.disconnects, hasLength(1));
    },
  );

  test('native send pressure retries only the refused FIFO head', () async {
    final fixture = _RelayFixture();
    await fixture.start();
    final native = fixture.native..externalPending = 31;
    fixture.client.send([1]);
    fixture.client.send([2]);
    await _flush();
    expect(native.sends, hasLength(1));
    expect(native.sends.single.reply.isCompleted, isTrue);
    expect(fixture.disconnects, isEmpty);
    await _until(() => native.sends.length == 2);
    expect(native.sends, hasLength(2));
    expect(native.sends.last.reply.isCompleted, isTrue);
    native.externalPending = 30;
    await _until(() => native.sends.length == 3);
    expect(native.sends, hasLength(3));
    expect(native.sends.last.reply.isCompleted, isFalse);
    expect(native.sends.map((call) => call.arguments['frame']), [
      [1],
      [1],
      [1],
    ]);
    expect(native.pending, 32);
    native.sends.last.reply.complete({'code': 'ok'});
    await _flush();
    expect(native.sends, hasLength(4));
    expect(native.sends.last.arguments['frame'], [2]);
    native.sends.last.reply.complete({'code': 'ok'});
    await _flush();
    expect(fixture.disconnects, isEmpty);
    await fixture.close();
  });

  test(
    'receive pressure retries with delay and resumes frame delivery',
    () async {
      final fixture = _RelayFixture();
      await fixture.start();
      final native = fixture.native..externalPending = 32;
      native.receives.single.reply.complete({'code': 'backpressure'});
      await _flush();
      expect(fixture.disconnects, isEmpty);
      await _until(() => native.receives.length == 2);
      expect(native.receives, hasLength(2));
      expect(native.receives.last.reply.isCompleted, isTrue);
      native.externalPending = 0;
      await _until(() => native.receives.length == 3);
      expect(native.receives, hasLength(3));
      native.receives.last.reply.complete({
        'code': 'ok',
        'frames': [
          Uint8List.fromList([3, 4]),
        ],
        'seq': 0,
      });
      await _flush();
      expect(fixture.events.whereType<MacHelperFrame>().single.data, [3, 4]);
      expect(fixture.disconnects, isEmpty);
      await _until(() => native.receives.length == 4);
      expect(native.receives, hasLength(4));
      await fixture.close();
    },
  );

  for (final failure in ['unavailable', 'exitUnconfirmed', 'futureError']) {
    test(
      'send $failure fails once without retry or losing ownership',
      () async {
        final fixture = _RelayFixture();
        await fixture.start();
        fixture.client.send([1]);
        fixture.client.send([2]);
        final error = TimeoutException('ambiguous native completion');
        if (failure == 'futureError') {
          fixture.native.sends.single.reply.completeError(error);
        } else {
          fixture.native.sends.single.reply.complete({'code': failure});
        }
        await _flush();
        expect(fixture.disconnects, hasLength(1));
        expect(
          fixture.disconnects.single.error,
          failure == 'futureError' ? same(error) : _helperCode(failure),
        );
        fixture.native.receives.single.reply.complete({'code': 'unavailable'});
        await _flush(const Duration(milliseconds: 64));
        expect(fixture.disconnects, hasLength(1));
        expect(fixture.native.sends, hasLength(1));
        expect(
          () => fixture.client.send([3]),
          throwsA(_helperCode('notConnected')),
        );
        await expectLater(
          fixture.client.start('other-session'),
          throwsA(_helperCode('exitUnconfirmed')),
        );
        expect(
          fixture.native.calls.where((method) => method == 'stop'),
          isEmpty,
        );
        await fixture.close();
        expect(fixture.disconnects, hasLength(1));
      },
    );
  }

  test('receive disconnect wins once over a concurrent failed send', () async {
    final fixture = _RelayFixture();
    await fixture.start();
    fixture.client.send([1]);
    fixture.client.send([2]);
    final error = StateError('receive disconnected');
    fixture.native.receives.single.reply.completeError(error);
    await _flush();
    fixture.native.sends.single.reply.completeError(StateError('send failed'));
    await _flush();
    expect(fixture.disconnects.single.error, same(error));
    expect(fixture.native.sends, hasLength(1));
    await fixture.close();
    expect(fixture.disconnects, hasLength(1));
  });

  test(
    'terminal receive code is preserved and stop still owns cleanup',
    () async {
      final fixture = _RelayFixture();
      await fixture.start();
      fixture.native.receives.single.reply.complete({'code': 'denied'});
      await _flush(const Duration(milliseconds: 64));
      expect(fixture.disconnects.single.error, _helperCode('denied'));
      expect(fixture.native.receives, hasLength(1));
      expect(fixture.native.calls.where((method) => method == 'stop'), isEmpty);
      await fixture.close();
      expect(fixture.disconnects, hasLength(1));
    },
  );

  test(
    'stopped session ignores stale failures without a replacement',
    () async {
      final fixture = _RelayFixture();
      await fixture.start();
      fixture.client.send([1]);
      fixture.client.send([2]);
      expect(await fixture.client.stop(_session), isTrue);
      fixture.native.sends.single.reply.completeError(StateError('late send'));
      fixture.native.receives.single.reply.completeError(
        StateError('late receive'),
      );
      await _flush(const Duration(milliseconds: 64));
      expect(fixture.native.sends, hasLength(1));
      expect(fixture.disconnects, hasLength(1));
      expect(fixture.disconnects.single.error, isNull);
      expect(
        () => fixture.client.send([3]),
        throwsA(_helperCode('notConnected')),
      );
      await fixture.close();
      expect(fixture.disconnects, hasLength(1));
    },
  );

  for (final restart in ['same', 'different']) {
    for (final oldReply in ['ok', 'unavailable', 'futureError']) {
      test(
        'restart $restart isolates stale $oldReply and queue counters',
        () async {
          final fixture = _RelayFixture();
          await fixture.start();
          fixture.client.send([99]);
          for (var index = 0; index < 255; index++) {
            fixture.client.send([98]);
          }
          expect(await fixture.client.stop(_session), isTrue);
          final session = restart == 'same'
              ? _session
              : '1123456789abcdef0123456789abcdef';
          await fixture.start(session);
          final frame = Uint8List(macosHelperMaxFrame);
          fixture.client.send(frame);
          expect(
            () => fixture.client.send([1]),
            throwsA(_helperCode('backpressure')),
          );
          expect(fixture.native.sends, hasLength(1));
          final oldSend = fixture.native.sends.first;
          if (oldReply == 'futureError') {
            oldSend.reply.completeError(StateError('old generation'));
          } else {
            oldSend.reply.complete({'code': oldReply});
          }
          fixture.native.receives.first.reply.complete({
            'code': 'ok',
            'frames': [
              Uint8List.fromList([97]),
            ],
            'seq': 0,
          });
          await _flush();
          expect(fixture.native.sends, hasLength(2));
          expect(fixture.native.sends.last.arguments['session'], session);
          expect(
            (fixture.native.sends.last.arguments['frame'] as Uint8List).length,
            macosHelperMaxFrame,
          );
          expect(fixture.events.whereType<MacHelperFrame>(), isEmpty);
          expect(fixture.disconnects, hasLength(1));
          expect(
            () => fixture.client.send([1]),
            throwsA(_helperCode('backpressure')),
          );
          fixture.native.sends.last.reply.complete({'code': 'ok'});
          await _flush();
          for (var index = 0; index < 256; index++) {
            fixture.client.send([index]);
          }
          expect(
            () => fixture.client.send([]),
            throwsA(_helperCode('backpressure')),
          );
          await fixture.close();
          expect(fixture.native.sends, hasLength(3));
          expect(fixture.disconnects, hasLength(2));
        },
      );
    }
  }

  test(
    'stop invalidates queued sends before native exit confirmation',
    () async {
      final fixture = _RelayFixture();
      await fixture.start();
      fixture.client.send([1]);
      fixture.client.send([2]);
      final stopReply = fixture.native.stopReply = Completer();
      final stopped = fixture.client.stop(_session);
      fixture.native.sends.single.reply.complete({'code': 'ok'});
      await _flush();
      expect(fixture.native.sends, hasLength(1));
      expect(
        () => fixture.client.send([3]),
        throwsA(_helperCode('notConnected')),
      );
      stopReply.complete({'code': 'exitUnconfirmed', 'exitConfirmed': false});
      expect(await stopped, isFalse);
      expect(fixture.disconnects, isEmpty);
      await expectLater(
        fixture.client.start(_session),
        throwsA(_helperCode('exitUnconfirmed')),
      );
      await fixture.close();
      expect(fixture.disconnects, hasLength(1));
      expect(
        fixture.native.calls.where((method) => method == 'stop'),
        hasLength(2),
      );
      expect(await fixture.client.stop(_session), isTrue);
      expect(
        fixture.native.calls.where((method) => method == 'stop'),
        hasLength(2),
      );
    },
  );

  test('stop during send and receive retry cancels stale dispatch', () async {
    final fixture = _RelayFixture();
    await fixture.start();
    fixture.client.send([1]);
    fixture.client.send([2]);
    fixture.native.sends.single.reply.complete({'code': 'backpressure'});
    fixture.native.receives.single.reply.complete({'code': 'backpressure'});
    await _flush();
    expect(await fixture.client.stop(_session), isTrue);
    await fixture.start();
    fixture.client.send([3]);
    await _until(() => fixture.native.sends.length == 2);
    expect(fixture.native.sends, hasLength(2));
    expect(fixture.native.sends.last.arguments['frame'], [3]);
    expect(fixture.native.receives, hasLength(2));
    expect(fixture.disconnects, hasLength(1));
    await fixture.close();
  });

  test('queue count bounds zero-byte frames independently of bytes', () async {
    final fixture = _RelayFixture();
    await fixture.start();
    for (var index = 0; index < 256; index++) {
      fixture.client.send([]);
    }
    expect(() => fixture.client.send([]), throwsA(_helperCode('backpressure')));
    fixture.native.sends.single.reply.complete({'code': 'ok'});
    await _flush();
    fixture.client.send([]);
    expect(
      () => fixture.client.send([1]),
      throwsA(_helperCode('backpressure')),
    );
    expect(fixture.disconnects, isEmpty);
    await fixture.close();
    expect(fixture.native.sends, hasLength(2));
  });

  test(
    '64 MiB byte budget counts in-flight data independently of count',
    () async {
      final fixture = _RelayFixture();
      await fixture.start();
      final frame = Uint8List(macosHelperMaxFrame ~/ 2);
      fixture.client.send(frame);
      fixture.client.send(frame);
      expect(
        () => fixture.client.send([1]),
        throwsA(_helperCode('backpressure')),
      );
      fixture.client.send([]);
      fixture.native.sends.single.reply.complete({'code': 'ok'});
      await _flush();
      fixture.client.send(frame);
      expect(
        () => fixture.client.send([1]),
        throwsA(_helperCode('backpressure')),
      );
      expect(fixture.disconnects, isEmpty);
      await fixture.close();
      expect(fixture.native.sends, hasLength(2));
    },
  );

  test('missing session and invalid frames are not queue saturation', () async {
    final fixture = _RelayFixture();
    expect(
      () => fixture.client.send([1]),
      throwsA(_helperCode('notConnected')),
    );
    await fixture.start();
    expect(
      () => fixture.client.send(Uint8List(macosHelperMaxFrame + 1)),
      throwsA(_helperCode('invalidFrame')),
    );
    expect(
      () => fixture.client.send([-1]),
      throwsA(_helperCode('invalidFrame')),
    );
    expect(
      () => fixture.client.send([256]),
      throwsA(_helperCode('invalidFrame')),
    );
    for (var index = 0; index < 256; index++) {
      fixture.client.send([index]);
    }
    expect(
      () => fixture.client.send([1]),
      throwsA(_helperCode('backpressure')),
    );
    await fixture.close();
    expect(
      () => fixture.client.send([1]),
      throwsA(_helperCode('notConnected')),
    );
  });

  for (final method in ['send', 'receive']) {
    test(
      'persistent $method pressure exhausts once and retains ownership',
      () async {
        final fixture = _RelayFixture(backpressureRetries: 2);
        await fixture.start();
        final native = fixture.native;
        if (method == 'send') {
          native.externalPending = 31;
          for (var index = 0; index < 64; index++) {
            fixture.client.send([index]);
          }
        } else {
          native.externalPending = 32;
          native.receives.single.reply.complete({'code': 'backpressure'});
        }
        await _until(() => fixture.disconnects.isNotEmpty);
        final attempts = method == 'send' ? native.sends : native.receives;
        expect(attempts, hasLength(3));
        expect(fixture.disconnects.single.error, _helperCode('backpressure'));
        await _flush(const Duration(milliseconds: 48));
        expect(attempts, hasLength(3));
        expect(fixture.disconnects, hasLength(1));
        expect(
          () => fixture.client.send([1]),
          throwsA(_helperCode('notConnected')),
        );
        await expectLater(
          fixture.client.start(_session),
          throwsA(_helperCode('exitUnconfirmed')),
        );
        expect(native.calls.where((call) => call == 'stop'), isEmpty);
        await fixture.close();
        expect(fixture.disconnects, hasLength(1));
      },
    );
  }

  test(
    'send progress resets the pressure budget for the next FIFO head',
    () async {
      final fixture = _RelayFixture(backpressureRetries: 1);
      await fixture.start();
      final sends = fixture.native.sends;
      fixture.client.send([1]);
      fixture.client.send([2]);
      sends.single.reply.complete({'code': 'backpressure'});
      await _until(() => sends.length == 2);
      sends.last.reply.complete({'code': 'ok'});
      await _until(() => sends.length == 3);
      sends.last.reply.complete({'code': 'backpressure'});
      await _until(() => sends.length == 4);
      sends.last.reply.complete({'code': 'ok'});
      await _flush();
      expect(sends.map((call) => call.arguments['frame']), [
        [1],
        [1],
        [2],
        [2],
      ]);
      expect(fixture.disconnects, isEmpty);
      await fixture.close();
    },
  );

  test(
    'receive progress resets the pressure budget for the next poll',
    () async {
      final fixture = _RelayFixture(backpressureRetries: 1);
      await fixture.start();
      final receives = fixture.native.receives;
      receives.single.reply.complete({'code': 'backpressure'});
      await _until(() => receives.length == 2);
      receives.last.reply.complete({
        'code': 'ok',
        'frames': [
          Uint8List.fromList([1]),
        ],
        'seq': 0,
      });
      await _until(() => receives.length == 3);
      receives.last.reply.complete({'code': 'backpressure'});
      await _until(() => receives.length == 4);
      receives.last.reply.complete({
        'code': 'ok',
        'frames': [
          Uint8List.fromList([2]),
        ],
        'seq': 1,
      });
      await _flush();
      expect(
        fixture.events.whereType<MacHelperFrame>().map((event) => event.data),
        [
          [1],
          [2],
        ],
      );
      expect(fixture.disconnects, isEmpty);
      await fixture.close();
    },
  );

  test(
    'transient stop pressure retries after discarding unsent frames',
    () async {
      final fixture = _RelayFixture(backpressureRetries: 2);
      await fixture.start();
      final native = fixture.native;
      fixture.client.send([1]);
      fixture.client.send([2]);
      native.externalPending = 30;
      final stopped = fixture.client.stop(_session);
      await _flush();
      expect(native.pending, 32);
      expect(native.calls.where((call) => call == 'stop'), hasLength(1));
      native.sends.single.reply.complete({'code': 'ok'});
      expect(await stopped, isTrue);
      expect(native.calls.where((call) => call == 'stop'), hasLength(2));
      expect(native.sends, hasLength(1));
      await _flush();
      expect(fixture.disconnects.single.error, isNull);
      await fixture.close();
      expect(fixture.disconnects, hasLength(1));
    },
  );

  test(
    'stop pressure exhaustion retains ownership and permits a fresh retry',
    () async {
      final fixture = _RelayFixture(backpressureRetries: 2);
      await fixture.start();
      final native = fixture.native..stopCode = 'backpressure';
      fixture.client.send([1]);
      fixture.client.send([2]);
      expect(await fixture.client.stop(_session), isFalse);
      expect(native.calls.where((call) => call == 'stop'), hasLength(3));
      native.sends.single.reply.complete({'code': 'ok'});
      await _flush(const Duration(milliseconds: 48));
      expect(native.sends, hasLength(1));
      expect(native.calls.where((call) => call == 'stop'), hasLength(3));
      expect(fixture.disconnects, isEmpty);
      expect(
        () => fixture.client.send([3]),
        throwsA(_helperCode('notConnected')),
      );
      await expectLater(
        fixture.client.start(_session),
        throwsA(_helperCode('exitUnconfirmed')),
      );
      native.stopCode = 'ok';
      expect(await fixture.client.stop(_session), isTrue);
      await _flush();
      expect(native.calls.where((call) => call == 'stop'), hasLength(4));
      expect(fixture.disconnects.single.error, isNull);
      await fixture.close();
      expect(fixture.disconnects, hasLength(1));
    },
  );

  for (final failure in ['exitUnconfirmed', 'unavailable', 'futureError']) {
    test('ambiguous stop $failure is never retried', () async {
      final fixture = _RelayFixture(backpressureRetries: 2);
      await fixture.start();
      final native = fixture.native;
      fixture.client.send([1]);
      fixture.client.send([2]);
      if (failure == 'futureError') {
        native.stopError = TimeoutException('ambiguous stop');
      } else {
        native.stopCode = failure;
      }
      expect(await fixture.client.stop(_session), isFalse);
      native.sends.single.reply.complete({'code': 'unavailable'});
      await _flush(const Duration(milliseconds: 48));
      expect(native.calls.where((call) => call == 'stop'), hasLength(1));
      expect(native.sends, hasLength(1));
      expect(fixture.disconnects, isEmpty);
      await expectLater(
        fixture.client.start(_session),
        throwsA(_helperCode('exitUnconfirmed')),
      );
      await fixture.close();
      expect(fixture.disconnects, hasLength(1));
    });
  }

  for (final restart in ['same', 'different']) {
    test(
      'stop pressure retry cannot enter a $restart restarted generation',
      () async {
        final fixture = _RelayFixture(backpressureRetries: 2);
        await fixture.start();
        final native = fixture.native..stopCode = 'backpressure';
        final oldStop = fixture.client.stop(_session);
        await _flush();
        expect(native.calls.where((call) => call == 'stop'), hasLength(1));
        native.stopCode = 'ok';
        expect(await fixture.client.stop(_session), isTrue);
        final session = restart == 'same'
            ? _session
            : '1123456789abcdef0123456789abcdef';
        await fixture.start(session);
        expect(await oldStop, isFalse);
        expect(native.calls.where((call) => call == 'stop'), hasLength(2));
        fixture.client.send([1]);
        native.sends.single.reply.complete({'code': 'ok'});
        await _flush();
        expect(fixture.disconnects, hasLength(1));
        await fixture.close();
        expect(fixture.disconnects, hasLength(2));
      },
    );
  }

  test('a re-check of a ready helper is routine until it answers', () async {
    final native = _StaleStatusNative();
    final maintenance = MacHelperMaintenance(
      MacHelperClient(native: native),
      stop: () async => const CoreLifecycleResult(
        revision: 1,
        outcome: CoreLifecycleOutcome.superseded,
      ),
    );
    addTearDown(maintenance.dispose);
    expect(maintenance.routineCheck, isFalse);
    await maintenance.check();
    final reply = native.delayedStatus = Completer();
    final pending = maintenance.check();
    expect(maintenance.busy, isTrue);
    expect(maintenance.routineCheck, isTrue);
    reply.complete({'code': 'requiresApproval'});
    await pending;
    final next = native.delayedStatus = Completer();
    final again = maintenance.check();
    expect(maintenance.busy && !maintenance.routineCheck, isTrue);
    next.complete({'code': 'enabled'});
    await again;
  });

  group('relay retries and batches', () {
    Map<Object?, Object?> batch(int seq, List<List<int>> frames) => {
      'code': 'ok',
      'seq': seq,
      'frames': [for (final frame in frames) Uint8List.fromList(frame)],
    };

    test(
      'a batch delivers every frame once; a resent one is skipped',
      () async {
        final fixture = _RelayFixture(maxRelayFailures: 3);
        await fixture.start();
        final receives = fixture.native.receives;
        expect(receives.single.arguments['ack'], 0);
        receives.single.reply.complete(
          batch(0, [
            [1],
            [2],
            [3],
          ]),
        );
        await _until(() => receives.length == 2);
        expect(receives.last.arguments['ack'], 3);
        // Its reply was lost: the daemon answers from the old ack again.
        receives.last.reply.complete(
          batch(2, [
            [3],
            [4],
          ]),
        );
        await _until(() => receives.length == 3);
        expect(receives.last.arguments['ack'], 4);
        expect(
          fixture.events.whereType<MacHelperFrame>().map((event) => event.data),
          [
            [1],
            [2],
            [3],
            [4],
          ],
        );
        expect(fixture.disconnects, isEmpty);
        await fixture.close();
      },
    );

    test('a batch that skips frames ends the relay', () async {
      final fixture = _RelayFixture(maxRelayFailures: 3);
      await fixture.start();
      fixture.native.receives.single.reply.complete(
        batch(1, [
          [9],
        ]),
      );
      await _until(() => fixture.disconnects.isNotEmpty);
      expect(fixture.disconnects.single.error, _helperCode('invalidFrame'));
      expect(fixture.events.whereType<MacHelperFrame>(), isEmpty);
      await fixture.close();
    });

    test('transient failures are retried with the same ack and seq', () async {
      final fixture = _RelayFixture(maxRelayFailures: 3);
      await fixture.start();
      final native = fixture.native;
      fixture.client.send([7]);
      expect(native.sends.single.arguments['seq'], 0);
      native.sends.single.reply.complete({'code': 'timeout'});
      native.receives.single.reply.complete({'code': 'unavailable'});
      await _until(
        () => native.sends.length == 2 && native.receives.length == 2,
      );
      expect(native.sends.last.arguments['seq'], 0);
      expect(native.sends.last.arguments['frame'], [7]);
      expect(native.receives.last.arguments['ack'], 0);
      native.sends.last.reply.complete({'code': 'ok'});
      fixture.client.send([8]);
      await _until(() => native.sends.length == 3);
      expect(native.sends.last.arguments['seq'], 1);
      native.sends.last.reply.complete({'code': 'ok'});
      expect(fixture.disconnects, isEmpty);
      expect(
        native.notes.where((note) => note.contains('retry')),
        hasLength(2),
      );
      await fixture.close();
    });

    test(
      'the third transient failure within the window ends the relay',
      () async {
        final fixture = _RelayFixture(maxRelayFailures: 3);
        await fixture.start();
        final receives = fixture.native.receives;
        for (var attempt = 1; attempt <= 3; attempt++) {
          receives.last.reply.complete({'code': 'timeout'});
          if (attempt < 3) await _until(() => receives.length == attempt + 1);
        }
        await _until(() => fixture.disconnects.isNotEmpty);
        expect(fixture.disconnects.single.error, _helperCode('timeout'));
        expect(receives, hasLength(3));
        expect(fixture.native.lost, [
          'relay lost: MacHelperException(timeout)',
        ]);
        expect(fixture.client.relayLive, isFalse);
        expect(fixture.client.hasCoreSession, isTrue);
        await fixture.close();
        expect(fixture.disconnects, hasLength(1));
      },
    );

    MacHelperClient clock(_RelayNative native, DateTime Function() now) =>
        MacHelperClient(
          native: native,
          safeMode: () => false,
          relayRetryDelay: Duration.zero,
          now: now,
        );

    test('failures spread beyond the window do not add up', () async {
      var now = DateTime(2026);
      final native = _RelayNative();
      final client = clock(native, () => now);
      final events = <MacHelperEvent>[];
      final subscription = client.events.listen(events.add);
      await client.start(_session);
      for (var attempt = 0; attempt < 5; attempt++) {
        now = now.add(const Duration(seconds: 6));
        native.receives.last.reply.complete({'code': 'unavailable'});
        await _until(() => native.receives.length == 2 * attempt + 2);
        native.receives.last.reply.complete(
          batch(attempt, [
            [attempt],
          ]),
        );
        await _until(() => native.receives.length == 2 * attempt + 3);
      }
      expect(events.whereType<MacHelperDisconnected>(), isEmpty);
      expect(client.relayLive, isTrue);
      expect(await client.stop(_session), isTrue);
      native.receives.last.reply.complete({'code': 'stopped'});
      await _flush();
      await subscription.cancel();
    });

    test('a hung daemon is lost after 12 s without an ok reply', () async {
      var now = DateTime(2026);
      final native = _RelayNative();
      final client = clock(native, () => now);
      final events = <MacHelperEvent>[];
      final subscription = client.events.listen(events.add);
      await client.start(_session);
      // Every request only fails at the bridge's 8 s timeout (and the
      // reconnecting hello takes as long): never 3 failures within 10 s.
      now = now.add(const Duration(seconds: 8));
      native.receives.last.reply.complete({'code': 'timeout'});
      await _until(() => native.receives.length == 2);
      expect(events.whereType<MacHelperDisconnected>(), isEmpty);
      now = now.add(const Duration(milliseconds: 8250));
      native.receives.last.reply.complete({'code': 'timeout'});
      await _until(() => events.whereType<MacHelperDisconnected>().isNotEmpty);
      expect(native.receives, hasLength(2));
      expect(client.relayLive, isFalse);
      expect(native.lost.single, contains('timeout'));
      expect(await client.stop(_session), isTrue);
      await subscription.cancel();
    });

    test(
      'one dropped connection failing send and receive is one failure',
      () async {
        var now = DateTime(2026);
        final native = _RelayNative();
        final client = clock(native, () => now);
        final events = <MacHelperEvent>[];
        final subscription = client.events.listen(events.add);
        await client.start(_session);
        client.send([1]);
        now = now.add(const Duration(seconds: 1));
        native.receives.last.reply.complete({'code': 'timeout'});
        native.sends.last.reply.complete({'code': 'unavailable'});
        await _until(
          () => native.receives.length == 2 && native.sends.length == 2,
        );
        now = now.add(const Duration(milliseconds: 100));
        native.receives.last.reply.complete({'code': 'unavailable'});
        await _until(() => native.receives.length == 3);
        // Two events so far (the retry was sent after the first failure); a
        // third one ends the relay.
        expect(events.whereType<MacHelperDisconnected>(), isEmpty);
        now = now.add(const Duration(milliseconds: 100));
        native.receives.last.reply.complete({'code': 'unavailable'});
        await _until(
          () => events.whereType<MacHelperDisconnected>().isNotEmpty,
        );
        expect(await client.stop(_session), isTrue);
        for (final call in [...native.sends, ...native.receives]) {
          if (!call.reply.isCompleted) {
            call.reply.complete({'code': 'stopped'});
          }
        }
        await _flush();
        await subscription.cancel();
      },
    );

    for (final code in ['disconnected', 'wrongOwner', 'invalidRequest']) {
      test('$code is not retried: the Core or its session is gone', () async {
        final fixture = _RelayFixture(maxRelayFailures: 3);
        await fixture.start();
        fixture.native.receives.single.reply.complete({'code': code});
        await _until(() => fixture.disconnects.isNotEmpty);
        expect(fixture.disconnects.single.error, _helperCode(code));
        expect(fixture.native.receives, hasLength(1));
        await fixture.close();
      });
    }
  });

  group('recovery after a helper update or a lost connection', () {
    test('a request timeout is a wait, never "exit unconfirmed"', () async {
      expect(MacHelperState.parse('timeout'), MacHelperState.starting);
      final client = MacHelperClient(
        native: _ScriptNative((_) => {'code': 'timeout'}),
      );
      expect(await client.status(), MacHelperState.starting);
      expect(client.lastCode, 'timeout');
    });

    test(
      'a start that timed out and a stop on the reset connection that failed '
      'are settled by the daemon reporting no Core',
      () async {
        var core = 0;
        var stopAnswer = <Object?, Object?>{'code': 'timeout'};
        final native = _ScriptNative(
          (method) => switch (method) {
            'status' => {
              'code': 'enabled',
              'protocol': 1,
              'pid': core,
              'exitConfirmed': core == 0,
            },
            // The bridge gave up waiting (cold first start after an update).
            'start' => {'code': 'timeout'},
            'stop' => stopAnswer,
            _ => {'code': 'ok'},
          },
        );
        final client = MacHelperClient(native: native);
        await expectLater(
          client.start(_session),
          throwsA(_helperCode('timeout')),
        );
        expect(native.calls, ['status', 'start', 'stop']);
        expect(client.hasCoreSession, isTrue);
        // The daemon still owns the Core: nothing claims "ready".
        core = 42;
        expect(await client.status(), MacHelperState.exitUnconfirmed);
        expect(client.hasCoreSession, isTrue);
        // It stopped the Core of the connection that went away.
        core = 0;
        expect(await client.status(), MacHelperState.enabled);
        expect(client.hasCoreSession, isFalse);
        expect(await client.stop(_session), isTrue);
        // And a new start is possible again.
        stopAnswer = _daemon('ok');
        expect(await client.status(), MacHelperState.enabled);
      },
    );

    test('the session is not masked over other helper states', () async {
      var state = <Object?, Object?>{'code': 'timeout'};
      final native = _ScriptNative(
        (method) => switch (method) {
          'status' => state,
          'start' => {'code': 'timeout'},
          _ => {'code': 'timeout'},
        },
      );
      final client = MacHelperClient(native: native);
      state = _daemon('enabled');
      await expectLater(client.start(_session), throwsA(anything));
      expect(client.hasCoreSession, isTrue);
      state = {'code': 'timeout'};
      expect(await client.status(), MacHelperState.starting);
      state = {'code': 'staleHelper'};
      expect(await client.status(), MacHelperState.staleHelper);
      // Unauthenticated or partial answers never release the session.
      state = {'code': 'enabled'};
      expect(await client.status(), MacHelperState.exitUnconfirmed);
      state = {'code': 'enabled', 'pid': 0};
      expect(await client.status(), MacHelperState.exitUnconfirmed);
      expect(client.hasCoreSession, isTrue);
    });

    test('stop accepts the daemon saying it owns no Core, even for an unknown '
        'session', () async {
      var stop = _daemon('wrongOwner', pid: 42, confirmed: false);
      final native = _ScriptNative(
        (method) => switch (method) {
          'status' => _daemon('enabled'),
          'start' => _daemon('ok', pid: 42, confirmed: false),
          'stop' => stop,
          _ => {'code': 'ok'},
        },
      );
      final client = MacHelperClient(native: native);
      expect(await client.start(_session), 42);
      expect(await client.stop(_session), isFalse);
      expect(client.hasCoreSession, isTrue);
      // wrongOwner with a running child is not a confirmation either.
      stop = {...stop, 'exitConfirmed': true};
      expect(await client.stop(_session), isFalse);
      stop = _daemon('wrongOwner');
      expect(await client.stop(_session), isTrue);
      expect(client.hasCoreSession, isFalse);
    });

    test('stale daemon is rechecked without registration changes', () async {
      var oldDaemon = true;
      final native = _ScriptNative(
        (method) => method == 'status'
            ? oldDaemon
                  ? {'code': 'staleHelper'}
                  : _daemon('enabled')
            : {'code': 'ok'},
      );
      final flow = MacHelperMaintenance(
        MacHelperClient(native: native),
        stop: () async => _applied,
        startTimeout: const Duration(milliseconds: 20),
        stalePoll: const Duration(milliseconds: 40),
      );
      expect(await flow.check(), MacHelperState.staleHelper);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(flow.startSlow, isTrue);
      expect(native.calls, ['status']);
      oldDaemon = false;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(flow.state, MacHelperState.enabled);
      expect(native.calls, ['status', 'status']);
      flow.dispose();
    });

    test('repair from "Core state unconfirmed" stops the Core first and '
        'clears the state once the daemon confirms', () async {
      final steps = <String>[];
      var core = 42;
      final native = _ScriptNative((method) {
        steps.add(method);
        return switch (method) {
          'status' => _daemon('enabled', pid: core, confirmed: core == 0),
          'start' => {'code': 'timeout'},
          'stop' => {'code': 'timeout'},
          'repair' => () {
            core = 0;
            return _daemon('enabled');
          }(),
          _ => {'code': 'ok'},
        };
      });
      final client = MacHelperClient(native: native);
      core = 0;
      await expectLater(client.start(_session), throwsA(anything));
      core = 42;
      final flow = MacHelperMaintenance(
        client,
        stop: () async {
          steps.add('appStop');
          return _applied;
        },
      );
      expect(await flow.check(), MacHelperState.exitUnconfirmed);
      final l = lookupAppLocalizations(const Locale('en'));
      final view = macHelperCardView(l, flow);
      expect(view.kind, MacHelperCardKind.exitUnconfirmed);
      // Stopping the Core through the app is the one action; the raw text
      // stays behind "View details".
      expect(view.primary, MacHelperCardAction.repair);
      expect(view.secondary, MacHelperCardAction.viewDetails);
      expect(macHelperActionLabel(l, MacHelperCardAction.repair), 'Repair');
      expect(
        macHelperActionLabel(
          lookupAppLocalizations(const Locale('zh')),
          MacHelperCardAction.repair,
        ),
        '尝试修复',
      );
      steps.clear();
      expect(await flow.repair(), MacHelperState.enabled);
      expect(steps, ['appStop', 'repair']);
      expect(client.hasCoreSession, isFalse);
      expect(macHelperCardView(l, flow).kind, MacHelperCardKind.ready);
      flow.dispose();
    });
  });
}
