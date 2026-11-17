import 'dart:io';
import 'dart:async';

import 'package:fl_clash/core/desktop/lifecycle.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/service.dart';
import 'package:fl_clash/core/desktop/macos_repair_record.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('repair-gate-');
    file = File('${directory.path}/pending');
  });

  tearDown(() => directory.delete(recursive: true));

  test('reopened pending record blocks start and restart', () async {
    await MacRepairRecord(
      file,
    ).markPending(readBootSession: () async => 'boot-a');
    final reopened = MacRepairRecord(file);
    final launcher = FakeLauncher(owner: CoreProcessOwner.direct, pid: 42);
    final lifecycle = DesktopCoreLifecycle(
      transport: FakeDesktopCoreTransport(),
      launcherResolver: MutableLauncherResolver(launcher),
      startGate: () =>
          requireMacRepairComplete(recordFactory: () async => reopened),
    );
    await expectLater(lifecycle.start(), throwsA(isA<DesktopCoreFailure>()));
    await expectLater(lifecycle.restart(), throwsA(isA<DesktopCoreFailure>()));
    expect(launcher.startCount, 0);
    await lifecycle.close();
  });

  test('production repair never unregisters if persistence fails', () async {
    final native = _RepairNative();
    final client = MacHelperClient(native: native, safeMode: () => false);
    final lifecycle = DesktopCoreLifecycle(
      transport: FakeDesktopCoreTransport(),
      launcherResolver: MutableLauncherResolver(
        FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
      ),
    );
    await expectLater(
      performMacExplicitRepair(
        lifecycle: lifecycle,
        client: client,
        recordFactory: () async =>
            MacRepairRecord(File('${directory.path}/missing/pending')),
        readBootSession: () async => 'boot-a',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(native.calls, isEmpty);
    await lifecycle.close();
  });

  test(
    'recovery requires new boot and authenticated status under exclusion',
    () async {
      final native = _RepairNative();
      final client = MacHelperClient(native: native, safeMode: () => false);
      final lifecycle = DesktopCoreLifecycle(
        transport: FakeDesktopCoreTransport(),
        launcherResolver: MutableLauncherResolver(
          FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
        ),
      );
      final record = MacRepairRecord(file);
      expect(
        await performMacExplicitRepair(
          lifecycle: lifecycle,
          client: client,
          recordFactory: () async => record,
          readBootSession: () async => 'boot-a',
        ),
        'repairRegistered',
      );
      expect(await record.isPending(), isTrue);
      expect(
        await recoverMacRepairWithOwner(
          lifecycle: lifecycle,
          client: client,
          record: record,
          readBootSession: () async => 'boot-a',
        ),
        isTrue,
      );
      expect(native.calls, ['repairExplicit']);
      native.status = 'signingRequired';
      expect(
        await recoverMacRepairWithOwner(
          lifecycle: lifecycle,
          client: client,
          record: record,
          readBootSession: () async => 'boot-b',
        ),
        isTrue,
      );
      native.status = 'enabled';
      native.reply = Completer<Map<Object?, Object?>>();
      final recovery = recoverMacRepairWithOwner(
        lifecycle: lifecycle,
        client: client,
        record: record,
        readBootSession: () async => 'boot-b',
      );
      await native.statusStarted.future;
      await expectLater(lifecycle.start(), throwsA(isA<DesktopCoreFailure>()));
      await expectLater(
        lifecycle.restart(),
        throwsA(isA<DesktopCoreFailure>()),
      );
      expect(await record.isPending(), isTrue);
      native.reply!.complete({'code': 'enabled'});
      expect(await recovery, isFalse);
      expect(await record.isPending(), isFalse);
      await lifecycle.close();
    },
  );

  test('explicit busy before dispatch retries after relay drains', () async {
    final native = _RepairNative()
      ..explicitAnswers.addAll([
        {'code': 'sessionBusy', 'explicitNotStarted': true},
        {'code': 'repairRegistered'},
      ]);
    final client = MacHelperClient(native: native, safeMode: () => false);
    final lifecycle = DesktopCoreLifecycle(
      transport: FakeDesktopCoreTransport(),
      launcherResolver: MutableLauncherResolver(
        FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
      ),
    );
    final record = MacRepairRecord(file);
    expect(
      await performMacExplicitRepair(
        lifecycle: lifecycle,
        client: client,
        recordFactory: () async => record,
        readBootSession: () async => 'boot-a',
      ),
      'repairRegistered',
    );
    expect(native.calls, ['repairExplicit', 'repairExplicit']);
    expect(await record.isPending(), isTrue);
    await lifecycle.close();
  });

  test(
    'unconfirmed stop and in-flight receive drain before explicit retry',
    () async {
      final native = _RepairNative()
        ..receiveReply = Completer<Map<Object?, Object?>>();
      final client = MacHelperClient(native: native, safeMode: () => false);
      final lifecycle = DesktopCoreLifecycle(
        transport: FakeDesktopCoreTransport(),
        launcherResolver: MutableLauncherResolver(
          FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
        ),
      );
      await client.start('test-session');
      await native.receiveStarted.future;
      expect(await client.stop('test-session'), isFalse);
      final repair = performMacExplicitRepair(
        lifecycle: lifecycle,
        client: client,
        recordFactory: () async => MacRepairRecord(file),
        readBootSession: () async => 'boot-a',
      );
      await native.explicitBusy.future;
      native.receiveReply!.complete({'code': 'ok'});
      expect(await repair, 'repairRegistered');
      expect(native.calls.where((call) => call == 'repairExplicit').length, 2);
      expect(client.hasCoreSession, isTrue);
      await lifecycle.close();
    },
  );

  test(
    'predispatch evidence survives reopen but is consumed before retry',
    () async {
      final record = MacRepairRecord(file);
      await record.markPending(readBootSession: () async => 'boot-a');
      await record.setExplicitNotStarted(
        notStarted: true,
        readBootSession: () async => 'boot-a',
      );
      final reopened = MacRepairRecord(file);
      expect(
        await reopened.canRetryExplicit(readBootSession: () async => 'boot-a'),
        isTrue,
      );
      expect(
        await reopened.canRetryExplicit(readBootSession: () async => 'boot-b'),
        isFalse,
      );
      await reopened.setExplicitNotStarted(
        notStarted: false,
        readBootSession: () async => 'boot-a',
      );
      expect(
        await MacRepairRecord(
          file,
        ).canRetryExplicit(readBootSession: () async => 'boot-a'),
        isFalse,
      );
      await expectLater(
        reopened.setExplicitNotStarted(
          notStarted: false,
          readBootSession: () async => 'boot-a',
        ),
        throwsFormatException,
      );
    },
  );

  test('unknown explicit outcome is never repeated', () async {
    final native = _RepairNative()..explicitAnswers.add({'code': 'timeout'});
    final client = MacHelperClient(native: native, safeMode: () => false);
    final lifecycle = DesktopCoreLifecycle(
      transport: FakeDesktopCoreTransport(),
      launcherResolver: MutableLauncherResolver(
        FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
      ),
    );
    final record = MacRepairRecord(file);
    Future<String> attempt() => performMacExplicitRepair(
      lifecycle: lifecycle,
      client: client,
      recordFactory: () async => record,
      readBootSession: () async => 'boot-a',
    );
    expect(await attempt(), 'timeout');
    await expectLater(attempt(), throwsFormatException);
    expect(native.calls, ['repairExplicit']);
    await lifecycle.close();
  });

  test('registration reconciliation is durable and once per boot', () async {
    final native = _RepairNative();
    final client = MacHelperClient(native: native, safeMode: () => false);
    final lifecycle = DesktopCoreLifecycle(
      transport: FakeDesktopCoreTransport(),
      launcherResolver: MutableLauncherResolver(
        FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
      ),
    );
    final record = MacRepairRecord(file);
    await record.markPending(readBootSession: () async => 'boot-a');
    Future<String> attempt(String boot) => registerPendingMacRepairWithOwner(
      lifecycle: lifecycle,
      client: client,
      record: record,
      readBootSession: () async => boot,
    );
    await expectLater(attempt('boot-a'), throwsStateError);
    expect(native.calls, isEmpty);
    expect(await attempt('boot-b'), 'registrationOutcomeUnknown');
    await expectLater(attempt('boot-b'), throwsStateError);
    expect(native.calls, ['repairRegisterOnly']);
    expect(await record.isPending(), isTrue);
    expect(
      await recoverMacRepairWithOwner(
        lifecycle: lifecycle,
        client: client,
        record: record,
        readBootSession: () async => 'boot-b',
      ),
      isTrue,
    );
    expect(native.calls, ['repairRegisterOnly']);
    expect(await attempt('boot-c'), 'registrationOutcomeUnknown');
    expect(native.calls, ['repairRegisterOnly', 'repairRegisterOnly']);
    expect(
      await recoverMacRepairWithOwner(
        lifecycle: lifecycle,
        client: client,
        record: record,
        readBootSession: () async => 'boot-d',
      ),
      isFalse,
    );
    expect(native.calls.last, 'status');
    await lifecycle.close();
  });

  test('settled failure allows same-boot retry but unknown does not', () async {
    final native = _RepairNative()
      ..registrationResult = 'registrationFailed'
      ..registrationSettled = true;
    final client = MacHelperClient(native: native, safeMode: () => false);
    final lifecycle = DesktopCoreLifecycle(
      transport: FakeDesktopCoreTransport(),
      launcherResolver: MutableLauncherResolver(
        FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
      ),
    );
    final record = MacRepairRecord(file);
    await record.markPending(readBootSession: () async => 'boot-a');
    Future<String> attempt() => registerPendingMacRepairWithOwner(
      lifecycle: lifecycle,
      client: client,
      record: record,
      readBootSession: () async => 'boot-b',
    );
    expect(await attempt(), 'registrationFailed');
    native.registrationResult = 'registrationOutcomeUnknown';
    native.registrationSettled = false;
    expect(await attempt(), 'registrationOutcomeUnknown');
    await expectLater(attempt(), throwsStateError);
    expect(await record.isPending(), isTrue);
    await lifecycle.close();
  });

  test(
    'settled registration allows authenticated recovery in same new boot',
    () async {
      final native = _RepairNative()..registrationResult = 'repairRegistered';
      final client = MacHelperClient(native: native, safeMode: () => false);
      final lifecycle = DesktopCoreLifecycle(
        transport: FakeDesktopCoreTransport(),
        launcherResolver: MutableLauncherResolver(
          FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
        ),
      );
      final record = MacRepairRecord(file);
      await record.markPending(readBootSession: () async => 'boot-a');
      expect(
        await registerPendingMacRepairWithOwner(
          lifecycle: lifecycle,
          client: client,
          record: record,
          readBootSession: () async => 'boot-b',
        ),
        'repairRegistered',
      );
      native.status = 'signingRequired';
      expect(
        await recoverMacRepairWithOwner(
          lifecycle: lifecycle,
          client: client,
          record: MacRepairRecord(file),
          readBootSession: () async => 'boot-b',
        ),
        isTrue,
      );
      native.status = 'enabled';
      expect(
        await recoverMacRepairWithOwner(
          lifecycle: lifecycle,
          client: client,
          record: MacRepairRecord(file),
          readBootSession: () async => 'boot-b',
        ),
        isFalse,
      );
      expect(native.calls, ['repairRegisterOnly', 'status', 'status']);
      await lifecycle.close();
    },
  );

  test(
    'explicit repair continues after unconfirmed stop, retaining leftover',
    () async {
      final native = _RepairNative();
      final client = MacHelperClient(native: native, safeMode: () => false);
      final transport = FakeDesktopCoreTransport();
      final launcher = FakeLauncher(owner: CoreProcessOwner.direct, pid: 42);
      launcher.lease.stopResult = const CoreProcessStopResult(
        stopped: false,
        exitConfirmed: false,
      );
      final lifecycle = DesktopCoreLifecycle(
        transport: transport,
        launcherResolver: MutableLauncherResolver(launcher),
        sessionIdFactory: () => '0123456789abcdef0123456789abcdef',
      );
      final start = lifecycle.start();
      transport.ready();
      await launcher.started;
      transport.connect(pid: 42);
      await start;
      final record = MacRepairRecord(file);
      expect(
        await performMacExplicitRepair(
          lifecycle: lifecycle,
          client: client,
          recordFactory: () async => record,
          readBootSession: () async => 'boot-a',
        ),
        'repairRegistered',
      );
      expect(await record.isPending(), isTrue);
      expect(lifecycle.hasNoCore, isFalse);
      expect(native.calls, ['repairExplicit']);
      await expectLater(lifecycle.start(), throwsA(isA<DesktopCoreFailure>()));
      await lifecycle.close();
    },
  );

  test('fresh record permits startup check', () async {
    await requireMacRepairComplete(
      recordFactory: () async => MacRepairRecord(file),
    );
  });

  test('gate read failure blocks startup', () async {
    await Directory(file.path).create();
    final launcher = FakeLauncher(owner: CoreProcessOwner.direct, pid: 42);
    final lifecycle = DesktopCoreLifecycle(
      transport: FakeDesktopCoreTransport(),
      launcherResolver: MutableLauncherResolver(launcher),
      startGate: () => requireMacRepairComplete(
        recordFactory: () async => MacRepairRecord(file),
      ),
    );
    await expectLater(lifecycle.start(), throwsA(isA<DesktopCoreFailure>()));
    expect(launcher.startCount, 0);
    await lifecycle.close();
  });
}

final class _RepairNative implements MacHelperNativeApi {
  final calls = <String>[];
  final explicitAnswers = <Map<Object?, Object?>>[];
  Completer<Map<Object?, Object?>>? receiveReply;
  final receiveStarted = Completer<void>();
  final explicitBusy = Completer<void>();
  String status = 'enabled';
  String registrationResult = 'registrationOutcomeUnknown';
  bool registrationSettled = false;
  Completer<Map<Object?, Object?>>? reply;
  final statusStarted = Completer<void>();

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    if (method == 'receive' && receiveReply != null) {
      receiveStarted.complete();
      return receiveReply!.future;
    }
    if (method == 'start') return {'code': 'ok', 'protocol': 1, 'pid': 42};
    if (method == 'stop') return {'code': 'timeout'};
    if (method == 'repairExplicit' &&
        receiveReply != null &&
        !receiveReply!.isCompleted) {
      explicitBusy.complete();
      return {'code': 'sessionBusy', 'explicitNotStarted': true};
    }
    if (method == 'repairExplicit') {
      return explicitAnswers.isEmpty
          ? {'code': 'repairRegistered'}
          : explicitAnswers.removeAt(0);
    }
    if (method == 'repairRegisterOnly') {
      return {
        'code': registrationResult,
        'registrationSettled':
            registrationSettled || registrationResult == 'repairRegistered',
      };
    }
    if (method == 'status') {
      if (reply != null) {
        statusStarted.complete();
        return reply!.future;
      }
      return {'code': status};
    }
    throw StateError('Unexpected native method $method');
  }
}
