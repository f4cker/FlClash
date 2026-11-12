import 'dart:async';
import 'dart:typed_data';

import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_launcher.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/macos_helper_transport.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/desktop/transport.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = '0123456789abcdef0123456789abcdef';

class _Native implements MacHelperNativeApi {
  final calls = <String>[];
  final arguments = <Map<String, Object?>>[];
  String state = 'enabled';
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
      'status' => {'code': state},
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
      'installerInstructions' => {'code': 'installerRequired'},
      'receive' => receive.future,
      _ => {'code': 'ok'},
    };
  }
}

void main() {
  test(
    'status is passive and preserves precise authorization states',
    () async {
      for (final state in MacHelperState.values) {
        final native = _Native()..state = state.name;
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
      await expectLater(
        client.installerInstructions(confirmed: true),
        throwsA(isA<MacHelperException>()),
      );

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

  test(
    'installer instructions require consent and never report installation complete',
    () async {
      final native = _Native();
      final client = MacHelperClient(native: native);
      await expectLater(
        client.installerInstructions(confirmed: false),
        throwsA(isA<MacHelperException>()),
      );
      expect(native.calls, isEmpty);
      expect(
        await client.installerInstructions(confirmed: true),
        MacHelperState.installerRequired,
      );
      expect(native.arguments.single, {'confirmed': true});
    },
  );

  for (final state in MacHelperState.values.where(
    (state) => state != MacHelperState.enabled,
  )) {
    test(
      'managed launcher refuses ${state.name} without fallback or registration',
      () async {
        final native = _Native()..state = state.name;
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
      native.stopCode = 'ok';
      expect(
        (await lease.stop(const Duration(seconds: 1))).exitConfirmed,
        isTrue,
      );
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
        'frame': Uint8List.fromList([123, 125]),
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

  test(
    'turn-off instructions wait for lifecycle stop without claiming removal',
    () async {
      final native = _Native();
      final client = MacHelperClient(native: native);
      final gate = Completer<CoreLifecycleResult>();
      final operation = MacHelperMaintenance(
        client,
        stop: () => gate.future,
      ).turnOff(confirmed: true);
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
      expect(await operation, MacHelperState.installerRequired);
      expect(native.calls, ['installerInstructions']);
    },
  );

  test(
    'failed or superseded lifecycle stop never advances to installer instructions',
    () async {
      for (final superseded in [false, true]) {
        final native = _Native();
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
        if (!superseded) {
          await expectLater(
            maintenance.turnOff(confirmed: true),
            throwsStateError,
          );
        } else {
          expect(
            await maintenance.turnOff(confirmed: true),
            MacHelperState.exitUnconfirmed,
          );
        }
        expect(native.calls, isEmpty);
      }
    },
  );

  test(
    'untrusted or unsupported builds offer no activation or retry action',
    () {
      for (final state in [
        MacHelperState.signingRequired,
        MacHelperState.unsupported,
        MacHelperState.disabled,
      ]) {
        expect(macHelperAction(state), isNull);
      }
      expect(
        macHelperAction(MacHelperState.approvalRequired),
        MacHelperAction.installer,
      );
      expect(macHelperAction(MacHelperState.enabled), MacHelperAction.disable);
      expect(
        macHelperAction(MacHelperState.protectedInstallationRequired),
        MacHelperAction.installer,
      );
      expect(
        macHelperAction(MacHelperState.installerRequired),
        MacHelperAction.installer,
      );
    },
  );
}
