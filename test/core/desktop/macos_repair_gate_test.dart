import 'dart:async';
import 'dart:io';

import 'package:fl_clash/core/desktop/lifecycle.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/macos_repair_record.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/service.dart';
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

  DesktopCoreLifecycle lifecycleWith(
    FakeLauncher launcher, {
    MacRepairRecord? gate,
  }) => DesktopCoreLifecycle(
    transport: FakeDesktopCoreTransport(),
    launcherResolver: MutableLauncherResolver(launcher),
    startGate: gate == null
        ? null
        : () => requireMacRepairComplete(recordFactory: () async => gate),
  );

  test('a pending record blocks start and restart', () async {
    await MacRepairRecord(file).markPending();
    final launcher = FakeLauncher(owner: CoreProcessOwner.direct, pid: 42);
    final lifecycle = lifecycleWith(launcher, gate: MacRepairRecord(file));
    await expectLater(lifecycle.start(), throwsA(isA<DesktopCoreFailure>()));
    await expectLater(lifecycle.restart(), throwsA(isA<DesktopCoreFailure>()));
    expect(launcher.startCount, 0);
    await lifecycle.close();
  });

  test('an unreadable record blocks too, without a reboot hint', () async {
    final record = MacRepairRecord(File('${directory.path}/missing/pending'));
    Object? error;
    try {
      await requireMacRepairComplete(recordFactory: () async => record);
    } catch (caught) {
      error = caught;
    }
    expect(error, isA<MacRepairPendingException>());
    expect(isMacHelperStartFailure(error!), isTrue);
    expect(error.toString().toLowerCase(), isNot(contains('restart')));
    expect(error.toString(), isNot(contains('重启')));
  });

  test('a record from mitm.3 (boot session fields) is pending and settles '
      'without any boot comparison', () async {
    await file.writeAsString(
      '{"version":1,"boot":"same-boot","registrationBoot":"same-boot"}',
    );
    final native = _RepairNative();
    final client = MacHelperClient(native: native, safeMode: () => false);
    final lifecycle = lifecycleWith(
      FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
    );
    final record = MacRepairRecord(file);
    expect(await record.isPending(), isTrue);
    expect(
      await settleMacRepairWithOwner(
        lifecycle: lifecycle,
        client: client,
        record: record,
      ),
      isFalse,
    );
    expect(await record.isPending(), isFalse);
    expect(native.calls, ['retireCores']);
    await lifecycle.close();
  });

  test('recovery writes the record before native runs, and never runs '
      'native if the record cannot be written', () async {
    final native = _RepairNative();
    final client = MacHelperClient(native: native, safeMode: () => false);
    final lifecycle = lifecycleWith(
      FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
    );
    await expectLater(
      recoverMacHelperWithOwner(
        lifecycle: lifecycle,
        client: client,
        record: MacRepairRecord(File('${directory.path}/missing/pending')),
        readBootSession: () async => 'boot-a',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(native.calls, isEmpty);

    native
      ..recoverAnswer = {'code': 'requiresApproval', 'detail': 'raw'}
      ..watched = file;
    final record = MacRepairRecord(file);
    final state = await recoverMacHelperWithOwner(
      lifecycle: lifecycle,
      client: client,
      record: record,
      // The boot session is only a diagnostic: failing to read it is fine.
      readBootSession: () async => throw StateError('no sysctl'),
    );
    expect(state, MacHelperState.requiresApproval);
    expect(native.calls, ['recover']);
    expect(native.recoverArguments, {'repairRecordWritten': true});
    expect(native.recordExistedAtRecover, isTrue);
    expect(await record.isPending(), isTrue);
    expect(client.lastDetail, 'raw');
    await lifecycle.close();
  });

  test('recovery runs only under maintenance: starts are refused while it '
      'runs', () async {
    final native = _RepairNative()..recoverReply = Completer();
    final client = MacHelperClient(native: native, safeMode: () => false);
    final launcher = FakeLauncher(owner: CoreProcessOwner.direct, pid: 42);
    final lifecycle = DesktopCoreLifecycle(
      transport: FakeDesktopCoreTransport(),
      launcherResolver: MutableLauncherResolver(launcher),
      startBlocked: () => client.maintenanceInProgress,
    );
    final running = recoverMacHelperWithOwner(
      lifecycle: lifecycle,
      client: client,
      record: MacRepairRecord(file),
    );
    await native.recoverStarted.future;
    await expectLater(lifecycle.start(), throwsA(isA<DesktopCoreFailure>()));
    expect(launcher.startCount, 0);
    native.recoverReply!.complete({'code': 'enabled'});
    expect(await running, MacHelperState.enabled);
    await lifecycle.close();
  });

  test('the record stays while the helper cannot confirm old Cores are '
      'gone, and while it cannot be asked', () async {
    await MacRepairRecord(file).markPending();
    final native = _RepairNative();
    final client = MacHelperClient(native: native, safeMode: () => false);
    final lifecycle = lifecycleWith(
      FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
    );
    final record = MacRepairRecord(file);
    for (final code in ['staleCoreUnconfirmed', 'timeout', 'staleHelper']) {
      native.retireAnswer = {'code': code, 'reason': 'pid 9: still running'};
      expect(
        await settleMacRepairWithOwner(
          lifecycle: lifecycle,
          client: client,
          record: record,
        ),
        isTrue,
        reason: code,
      );
      expect(await record.isPending(), isTrue);
    }
    expect(client.lastDetail, 'helper: pid 9: still running');
    native.retireAnswer = {'code': 'staleCoreStopped', 'stopped': 1};
    expect(
      await settleMacRepairWithOwner(
        lifecycle: lifecycle,
        client: client,
        record: record,
      ),
      isFalse,
    );
    expect(await record.isPending(), isFalse);
    await lifecycle.close();
  });

  test('no record: nothing is asked', () async {
    final native = _RepairNative();
    final client = MacHelperClient(native: native, safeMode: () => false);
    final lifecycle = lifecycleWith(
      FakeLauncher(owner: CoreProcessOwner.direct, pid: 42),
    );
    expect(
      await settleMacRepairWithOwner(
        lifecycle: lifecycle,
        client: client,
        record: MacRepairRecord(file),
      ),
      isFalse,
    );
    expect(native.calls, isEmpty);
    await lifecycle.close();
  });
}

final class _RepairNative implements MacHelperNativeApi {
  final calls = <String>[];
  Map<Object?, Object?> recoverAnswer = const {'code': 'enabled'};
  Map<Object?, Object?> retireAnswer = const {'code': 'noStaleCore'};
  Map<String, Object?>? recoverArguments;
  bool? recordExistedAtRecover;
  Completer<Map<Object?, Object?>>? recoverReply;
  final recoverStarted = Completer<void>();
  File? watched;

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    switch (method) {
      case 'recover':
        recoverArguments = arguments;
        recordExistedAtRecover = watched?.existsSync();
        if (recoverReply != null) {
          recoverStarted.complete();
          return recoverReply!.future;
        }
        return recoverAnswer;
      case 'retireCores':
        return retireAnswer;
      case 'status':
        return {'code': 'enabled'};
    }
    throw StateError('Unexpected native method $method');
  }
}
