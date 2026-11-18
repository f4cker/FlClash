import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/core/desktop/macos_repair_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('repair-record-');
    file = File('${directory.path}/pending');
  });

  tearDown(() => directory.delete(recursive: true));

  test('absent record permits a fresh installation', () async {
    expect(await MacRepairRecord(file).isPending(), isFalse);
  });

  test(
    'record survives reopening; boot session is a diagnostic only',
    () async {
      await MacRepairRecord(file).markPending(diagnostics: {'boot': 'boot-a'});
      final reopened = MacRepairRecord(file);
      expect(await reopened.isPending(), isTrue);
      final saved = jsonDecode(await file.readAsString()) as Map;
      expect(saved['version'], 2);
      expect(saved['boot'], 'boot-a');
      expect(saved['started'], isA<String>());
    },
  );

  test('a record with no boot session (unreadable) is still written', () async {
    await MacRepairRecord(file).markPending();
    expect(await MacRepairRecord(file).isPending(), isTrue);
  });

  test('clears only when confirmed, never by boot comparison', () async {
    // Same boot as when it was written: the boot never decides anything.
    await file.writeAsString(
      '{"version":1,"boot":"boot-a","registrationBoot":"boot-a"}',
    );
    final record = MacRepairRecord(file);
    expect(await record.clearIf(() async => false), isFalse);
    expect(await record.isPending(), isTrue);
    expect(await record.clearIf(() async => true), isTrue);
    expect(await record.isPending(), isFalse);
    // Clearing an absent record asks nothing.
    var asked = false;
    expect(
      await record.clearIf(() async {
        asked = true;
        return false;
      }),
      isTrue,
    );
    expect(asked, isFalse);
  });

  test('a failing confirmation keeps the record', () async {
    await MacRepairRecord(file).markPending();
    final record = MacRepairRecord(file);
    await expectLater(
      record.clearIf(() async => throw StateError('helper gone')),
      throwsA(isA<StateError>()),
    );
    expect(await record.isPending(), isTrue);
  });

  test('missing directory is not treated as a fresh installation', () async {
    final record = MacRepairRecord(File('${directory.path}/missing/pending'));
    await expectLater(record.isPending(), throwsA(isA<FileSystemException>()));
    await expectLater(
      record.markPending(),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('a dangling link or a directory counts as pending (fail closed) and '
      'cannot be cleared as a record', () async {
    await Link(file.path).create('${directory.path}/missing');
    expect(await MacRepairRecord(file).isPending(), isTrue);
    await Link(file.path).delete();

    await Directory(file.path).create();
    final record = MacRepairRecord(file);
    expect(await record.isPending(), isTrue);
    await expectLater(
      record.clearIf(() async => true),
      throwsA(isA<FileSystemException>()),
    );
    expect(await record.isPending(), isTrue);
  });
}
