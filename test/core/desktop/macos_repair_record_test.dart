import 'dart:io';

import 'package:fl_clash/core/desktop/macos_repair_record.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Verification implements MacRepairVerification {
  String boot;
  bool authenticated = true;
  bool failBoot = false;

  _Verification(this.boot);

  @override
  Future<String> readBootSession() async {
    if (failBoot) throw StateError('boot unavailable');
    return boot;
  }

  @override
  Future<bool> verifyCurrentSignedAuthenticatedHelperAndNoGuiCore() async =>
      authenticated;
}

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('repair-record-test-');
    file = File('${directory.path}/pending');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('absent record permits a fresh installation', () async {
    expect(await MacRepairRecord(file).isPending(), isFalse);
  });

  test(
    'pending record survives a new instance and incomplete writes',
    () async {
      await MacRepairRecord(
        file,
      ).markPending(readBootSession: () async => 'boot-a');
      expect(await MacRepairRecord(file).isPending(), isTrue);
      await file.writeAsString('');
      expect(await MacRepairRecord(file).isPending(), isTrue);
    },
  );

  test('boot read failure refuses to begin', () async {
    final record = MacRepairRecord(file);
    await expectLater(
      record.markPending(readBootSession: () async => throw StateError('boot')),
      throwsStateError,
    );
    expect(await record.isPending(), isFalse);
  });

  test('only a verified different boot clears a reopened record', () async {
    await MacRepairRecord(
      file,
    ).markPending(readBootSession: () async => 'boot-a');
    final reopened = MacRepairRecord(file);
    final verification = _Verification('boot-a');
    expect(
      await reopened.clearAfterVerifiedReboot(verification: verification),
      isFalse,
    );
    expect(await reopened.isPending(), isTrue);
    await expectLater(
      reopened.markPending(readBootSession: () async => 'boot-b'),
      throwsA(isA<FileSystemException>()),
    );
    verification.failBoot = true;
    await expectLater(
      reopened.clearAfterVerifiedReboot(verification: verification),
      throwsStateError,
    );
    expect(await reopened.isPending(), isTrue);
    verification.failBoot = false;
    verification.boot = 'boot-b';
    verification.authenticated = false;
    expect(
      await reopened.clearAfterVerifiedReboot(verification: verification),
      isFalse,
    );
    expect(await reopened.isPending(), isTrue);
    verification.authenticated = true;
    expect(
      await reopened.clearAfterVerifiedReboot(verification: verification),
      isTrue,
    );
    expect(await MacRepairRecord(file).isPending(), isFalse);
  });

  test('invalid record cannot be cleared after reboot', () async {
    await file.writeAsString('');
    final record = MacRepairRecord(file);
    await expectLater(
      record.clearAfterVerifiedReboot(verification: _Verification('boot-b')),
      throwsFormatException,
    );
    expect(await record.isPending(), isTrue);
  });

  test('missing directory is not treated as a fresh installation', () async {
    final record = MacRepairRecord(File('${directory.path}/missing/pending'));
    await expectLater(record.isPending(), throwsA(isA<FileSystemException>()));
    await expectLater(
      record.markPending(readBootSession: () async => 'boot-a'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('dangling record link is not treated as an absent record', () async {
    await Link(file.path).create('${directory.path}/missing');
    await expectLater(
      MacRepairRecord(file).isPending(),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('read and write errors fail closed', () async {
    await Directory(file.path).create();
    final record = MacRepairRecord(file);
    await expectLater(record.isPending(), throwsA(isA<FileSystemException>()));
    await expectLater(
      record.markPending(readBootSession: () async => 'boot-a'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
