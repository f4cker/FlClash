import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/restore_journal.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';

Profile _profile(int id, String label) =>
    Profile(id: id, label: label, autoUpdateDuration: Duration.zero);

/// Consented to on the device the backup came from.
final _module = MitmModule(
  id: 41,
  name: 'Restored module',
  enabled: true,
  accepted: true,
  lastUpdateTime: DateTime(2026),
);

/// Where a test stops the restore, as a crash would.
enum _Crash {
  beforePublish,
  midPublish,
  afterPublish,
  insideTransaction,
  afterCommit,
  afterCaches,
  afterConfigWritten,
  afterConfigStored,
  afterPrefs,
  afterMitm,
}

extension on _Crash {
  bool get committed => index >= _Crash.afterCommit.index;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory home;
  late File dbFile;
  late Database db;

  const dropped = ClashProvider(
    id: 5,
    label: 'Dropped',
    url: 'https://example.com/dropped.yaml',
  );

  setUpAll(() {
    loadAppLocalizations(const Locale('en'));
  });

  setUp(() async {
    await mockPreferences({'version': 1});
    restoreRecovery.clearMitmHolds();
    home = Directory.systemTemp.createTempSync('flash-restore-journal-');
    await useAppPaths(home);
    dbFile = File(join(home.path, 'database.sqlite'));
    db = Database(NativeDatabase(dbFile));
    database = db;
  });

  tearDown(() async {
    await db.close();
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  /// A fresh connection to the same file, as the next launch would open.
  Future<Database> relaunch() async {
    await db.close();
    db = Database(NativeDatabase(dbFile));
    database = db;
    return db;
  }

  ProviderContainer buildContainer() {
    final container = ProviderContainer()..listen(configProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  File live(String entry) => File(BackupEntries.resolve(home.path, entry));

  Map<String, String?> liveFiles() => {
    for (final entry in [
      BackupEntries.profile(1),
      BackupEntries.profile(2),
      BackupEntries.profile(3),
    ])
      entry: live(entry).existsSync() ? live(entry).readAsStringSync() : null,
  };

  Future<Map<int, String>> labels() async => {
    for (final profile in await database.profilesDao.query().get())
      profile.id: profile.label,
  };

  Future<int?> storedProfileId() async =>
      (await preferences.getConfig())?.currentProfileId;

  /// Local data: profiles 1 and 2 with their files, a remote provider with
  /// a cache, and saved settings pointing at profile 1.
  Future<({ProviderContainer container, Directory staging, MigrationData data})>
  fixture() async {
    await database.profilesDao.putAll([
      _profile(1, 'Local A').toCompanion(0),
      _profile(2, 'Local B').toCompanion(1),
    ]);
    await database.clashProvidersDao.putAll([dropped.toCompanion()]);
    for (final path in [await dropped.path, await dropped.compiledPath]) {
      File(path).createSync(recursive: true);
    }
    live(BackupEntries.profile(1))
      ..createSync(recursive: true)
      ..writeAsStringSync('local-1');
    live(BackupEntries.profile(2))
      ..createSync(recursive: true)
      ..writeAsStringSync('local-2');
    final container = buildContainer();
    container.read(currentProfileIdProvider.notifier).value = 1;
    container
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(restoreStrategy: RestoreStrategy.override),
        );
    expect(await preferences.saveConfig(container.read(configProvider)), true);
    final staging = Directory(join(home.path, 'staging'))
      ..createSync(recursive: true);
    for (final (id, body) in [(1, 'backup-1'), (3, 'backup-3')]) {
      File(BackupEntries.resolve(staging.path, BackupEntries.profile(id)))
        ..createSync(recursive: true)
        ..writeAsStringSync(body);
    }
    final configMap =
        jsonDecode(jsonEncode(container.read(configProvider).toJson()))
            as Map<String, Object?>;
    configMap['currentProfileId'] = 3;
    return (
      container: container,
      staging: staging,
      data: MigrationData(
        configMap: configMap,
        profiles: [_profile(1, 'Backup A'), _profile(3, 'Backup C')],
        mitmModules: [_module],
      ),
    );
  }

  Future<void> crashAt(
    _Crash crash,
    BackupAction action,
    MigrationData data,
    String stagingPath,
  ) async {
    var files = 0;
    action.onRestoreCheckpoint = (point) async {
      final hit = switch ((crash, point)) {
        (_Crash.beforePublish, RestoreCheckpoint.prepared) => true,
        (_Crash.midPublish, RestoreCheckpoint.filePublished) => ++files == 1,
        (_Crash.afterPublish, RestoreCheckpoint.published) => true,
        (_Crash.afterCommit, RestoreCheckpoint.committed) => true,
        (_Crash.afterCaches, RestoreCheckpoint.cachesCleared) => true,
        (_Crash.afterConfigWritten, RestoreCheckpoint.configWritten) => true,
        (_Crash.afterConfigStored, RestoreCheckpoint.configStored) => true,
        (_Crash.afterPrefs, RestoreCheckpoint.configSaved) => true,
        (_Crash.afterMitm, RestoreCheckpoint.mitmDone) => true,
        _ => false,
      };
      if (hit) throw RestoreCrash(point);
    };
    if (crash == _Crash.insideTransaction) {
      database.beforeRestoreCommit = () async => throw const RestoreCrash();
    }
    await expectLater(
      action.applyRestore(data, RestoreOption.all, stagingDirPath: stagingPath),
      throwsA(isA<RestoreCrash>()),
    );
  }

  Future<List<RestoreRecoveryReport>> recover({
    void Function()? mitm,
    Preferences? store,
  }) async {
    final recovery = RestoreRecovery(
      db: () => database,
      homeDirPath: () async => home.path,
      store: () => store ?? preferences,
    );
    await recovery.run();
    if (recovery.needsMitm) {
      await recovery.finish(() async => mitm?.call());
    }
    return recovery.takeReports();
  }

  List<FileSystemEntity> journals() {
    final root = Directory(RestoreJournal.rootOf(home.path));
    if (!root.existsSync()) return const [];
    return root
        .listSync()
        .where((entity) => basename(entity.path) != 'quarantine')
        .toList();
  }

  List<String> quarantined() {
    final root = Directory(
      join(RestoreJournal.rootOf(home.path), 'quarantine'),
    );
    if (!root.existsSync()) return const [];
    return root.listSync().map((entity) => basename(entity.path)).toList();
  }

  Future<List<int>> markers() async {
    final tables = await database
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE name = 'restore_commits'",
        )
        .get();
    if (tables.isEmpty) return const [];
    return [
      for (final row
          in await database
              .customSelect('SELECT id FROM restore_commits')
              .get())
        row.read<int>('id'),
    ];
  }

  group('a crash at each phase recovers to one consistent state', () {
    for (final crash in _Crash.values) {
      test(crash.name, () async {
        final (:container, :staging, :data) = await fixture();
        final dbBefore = await database.restoreFingerprint();
        final filesBefore = liveFiles();
        final prefsBefore = await storedConfigHash(preferences);

        await crashAt(
          crash,
          container.read(backupActionProvider.notifier),
          data,
          staging.path,
        );
        expect(journals(), hasLength(1), reason: 'the journal survives');
        await relaunch();
        var mitmRuns = 0;
        final reports = await recover(mitm: () => mitmRuns++);

        expect(journals(), isEmpty);
        expect(await markers(), isEmpty);
        expect(quarantined(), isEmpty);
        if (!crash.committed) {
          expect(reports.single.outcome, RestoreRecoveryOutcome.rolledBack);
          expect(await database.restoreFingerprint(), dbBefore);
          expect(await labels(), {1: 'Local A', 2: 'Local B'});
          expect(liveFiles(), filesBefore);
          expect(await storedConfigHash(preferences), prefsBefore);
          expect(await storedProfileId(), 1);
          expect(File(await dropped.path).existsSync(), isTrue);
          expect(mitmRuns, 0);
        } else {
          expect(reports.single.outcome, RestoreRecoveryOutcome.completed);
          expect(await labels(), {1: 'Backup A', 3: 'Backup C'});
          expect(liveFiles(), {
            BackupEntries.profile(1): 'backup-1',
            BackupEntries.profile(2): 'local-2',
            BackupEntries.profile(3): 'backup-3',
          });
          expect(await storedProfileId(), 3);
          expect(File(await dropped.path).existsSync(), isFalse);
          expect(File(await dropped.compiledPath).existsSync(), isFalse);
          expect(mitmRuns, crash == _Crash.afterMitm ? 0 : 1);
        }
        // A second launch has nothing left to do.
        await relaunch();
        expect(await recover(mitm: () => mitmRuns++), isEmpty);
      });
    }
  });

  test('an uninterrupted restore leaves no journal or marker', () async {
    final (:container, :staging, :data) = await fixture();
    await container
        .read(backupActionProvider.notifier)
        .applyRestore(data, RestoreOption.all, stagingDirPath: staging.path);
    expect(journals(), isEmpty);
    expect(await markers(), isEmpty);
    expect(await storedProfileId(), 3, reason: 'saved, not debounced');
    expect(await recover(), isEmpty);
  });

  test('a post-commit failure keeps the journal for the next launch', () async {
    final (:container, :staging, :data) = await fixture();
    final action = container.read(backupActionProvider.notifier);
    action.afterRestoreCommit = () async => throw StateError('injected');
    await expectLater(
      action.applyRestore(
        data,
        RestoreOption.all,
        stagingDirPath: staging.path,
      ),
      throwsA(
        isA<RestorePartialException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('has been restored'),
            contains('clearing old rule caches'),
            isNot(contains('was not changed')),
          ),
        ),
      ),
    );
    expect(journals(), hasLength(1));
    expect(await markers(), hasLength(1));
    await relaunch();
    final reports = await recover();
    expect(reports.single.outcome, RestoreRecoveryOutcome.completed);
    expect(await storedProfileId(), 3);
    expect(journals(), isEmpty);
  });

  test('a pre-commit failure in session puts files back and drops the '
      'journal', () async {
    final (:container, :staging, :data) = await fixture();
    database.beforeRestoreCommit = () async => throw StateError('rows failed');
    await expectLater(
      container
          .read(backupActionProvider.notifier)
          .applyRestore(data, RestoreOption.all, stagingDirPath: staging.path),
      throwsA(isA<StateError>()),
    );
    expect(liveFiles(), {
      BackupEntries.profile(1): 'local-1',
      BackupEntries.profile(2): 'local-2',
      BackupEntries.profile(3): null,
    });
    expect(journals(), isEmpty);
    expect(await markers(), isEmpty);
  });

  group('another build ran between the crash and this launch', () {
    test('it changed a published file: that file is kept, the rest goes '
        'back', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterPublish,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      await relaunch();
      // The older build ignores the journal and updates the subscription.
      live(BackupEntries.profile(1)).writeAsStringSync('old-build-1');

      final reports = await recover();

      expect(reports.single.outcome, RestoreRecoveryOutcome.rolledBackPartly);
      expect(reports.single.keptFiles, [BackupEntries.profile(1)]);
      expect(liveFiles(), {
        BackupEntries.profile(1): 'old-build-1',
        BackupEntries.profile(2): 'local-2',
        BackupEntries.profile(3): null,
      });
      expect(await labels(), {1: 'Local A', 2: 'Local B'});
      expect(journals(), isEmpty);
      final [id] = quarantined();
      expect(
        File(
          BackupEntries.resolve(
            join(
              RestoreJournal.rootOf(home.path),
              'quarantine',
              id,
              'replaced',
            ),
            BackupEntries.profile(1),
          ),
        ).readAsStringSync(),
        'local-1',
        reason: 'the original of a file left alone is kept',
      );
      final message = restoreRecoveryMessage(
        reports.single,
        currentAppLocalizations,
      );
      expect(message, contains(BackupEntries.profile(1)));
      expect(message, isNot(contains('was not changed')));
    });

    test('it changed rows after the commit: nothing rolls forward over '
        'them', () async {
      final (:container, :staging, :data) = await fixture();
      final prefsBefore = await storedConfigHash(preferences);
      await crashAt(
        _Crash.afterCommit,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      await relaunch();
      await database.profilesDao.putAll([
        _profile(9, 'Made in old build').toCompanion(9),
      ]);

      var mitmRuns = 0;
      final reports = await recover(mitm: () => mitmRuns++);

      expect(reports.single.outcome, RestoreRecoveryOutcome.incomplete);
      expect(reports.single.skippedSteps, [
        RestoreStep.caches,
        RestoreStep.settings,
      ]);
      expect(mitmRuns, 1, reason: 'the consent recheck overwrites nothing');
      expect(await labels(), {
        1: 'Backup A',
        3: 'Backup C',
        9: 'Made in old build',
      });
      expect(await storedConfigHash(preferences), prefsBefore);
      expect(await storedProfileId(), 1);
      expect(
        File(await dropped.path).existsSync(),
        isTrue,
        reason: 'no file is touched once the guard trips',
      );
      expect(await markers(), isEmpty);
      expect(journals(), isEmpty);
      expect(quarantined(), hasLength(1));
      final message = restoreRecoveryMessage(
        reports.single,
        currentAppLocalizations,
      );
      expect(message, contains('The data was changed after the restore'));
      expect(message, isNot(contains('older version')));
      expect(message, contains('clearing old rule caches'));
      expect(message, isNot(contains('was not changed')));
      await relaunch();
      expect(await recover(), isEmpty);
    });

    test('it saved its own settings: they are not overwritten', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterConfigWritten,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      await relaunch();
      final oldBuild = (await preferences.getConfig())!.copyWith(
        currentProfileId: 2,
      );
      expect(await preferences.saveConfig(oldBuild), isTrue);

      final reports = await recover();

      expect(reports.single.outcome, RestoreRecoveryOutcome.incomplete);
      expect(reports.single.skippedSteps, [RestoreStep.settings]);
      expect(await storedProfileId(), 2);
      expect(await markers(), isEmpty);
      expect(journals(), isEmpty);
    });

    test(
      'settings already saved: later writes, by this build or another, '
      'do not stop the MITM recheck and are not blamed on an older one',
      () async {
        final (:container, :staging, :data) = await fixture();
        await crashAt(
          _Crash.afterPrefs,
          container.read(backupActionProvider.notifier),
          data,
          staging.path,
        );
        await relaunch();
        await database.profilesDao.putAll([
          _profile(9, 'Made in old build').toCompanion(9),
        ]);
        var mitmRuns = 0;

        final reports = await recover(mitm: () => mitmRuns++);

        expect(reports.single.outcome, RestoreRecoveryOutcome.completed);
        expect(mitmRuns, 1);
        expect(await storedProfileId(), 3);
        expect(await labels(), containsPair(9, 'Made in old build'));
        expect(journals(), isEmpty);
        expect(await markers(), isEmpty);
      },
    );

    test('the database was cleared: the journal is set aside', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterCommit,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      await relaunch();
      await database.customStatement('DROP TABLE restore_commits');

      final reports = await recover();

      expect(reports.single.outcome, RestoreRecoveryOutcome.incomplete);
      expect(liveFiles()[BackupEntries.profile(1)], 'backup-1');
      expect(journals(), isEmpty);
      expect(quarantined(), hasLength(1));
    });
  });

  test('an unreadable journal is set aside, never acted on', () async {
    final dir = Directory(join(RestoreJournal.rootOf(home.path), '77'))
      ..createSync(recursive: true);
    File(join(dir.path, 'journal.json')).writeAsStringSync('{not json');
    final reports = await recover();
    expect(reports.single.outcome, RestoreRecoveryOutcome.unreadable);
    expect(
      reports.single.followUp,
      RestoreFollowUp.none,
      reason: 'no re-restore is offered',
    );
    expect(journals(), isEmpty);
    expect(quarantined(), ['77.unreadable']);
  });

  test('a backup never carries the commit marker', () async {
    final (:container, :staging, :data) = await fixture();
    await crashAt(
      _Crash.afterCommit,
      container.read(backupActionProvider.notifier),
      data,
      staging.path,
    );
    expect(await markers(), hasLength(1));
    final out = Directory(join(home.path, 'out'))..createSync();
    final delivered = await container
        .read(backupActionProvider.notifier)
        .backup((archivePath) async {
          File(archivePath).copySync(join(out.path, 'backup.zip'));
          return true;
        });
    expect(delivered, isTrue);
    final archive = ZipDecoder().decodeBytes(
      File(join(out.path, 'backup.zip')).readAsBytesSync(),
    );
    final snapshot = File(join(out.path, 'snapshot.db'))
      ..writeAsBytesSync(archive.findFile(backupDatabaseName)!.content);
    final copy = Database(NativeDatabase(snapshot));
    addTearDown(copy.close);
    final tables = await copy
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'restore_commits'",
        )
        .get();
    expect(tables, isEmpty);
    expect(await markers(), hasLength(1), reason: 'the live marker stays');
  });

  test('a marker inside an older build\'s backup is never imported', () async {
    await database.customStatement(
      'CREATE TABLE restore_commits (id INTEGER NOT NULL PRIMARY KEY, '
      "created_at INTEGER NOT NULL, fingerprint TEXT NOT NULL DEFAULT '')",
    );
    await database.customStatement(
      "INSERT INTO restore_commits VALUES (4242, 1, 'fp')",
    );
    await database.profilesDao.putAll([_profile(1, 'Backed up').toCompanion()]);
    final snapshot = join(home.path, 'old.db');
    await database.customStatement('VACUUM INTO ?', [snapshot]);
    final archive = join(home.path, 'old.zip');
    await writeBackupArchive(
      archivePath: archive,
      configMap: {'version': 1},
      databaseSnapshotPath: snapshot,
      homeDirPath: home.path,
      entries: const [],
    );
    await database.customStatement('DROP TABLE restore_commits');
    final data = await readBackupArchive(
      archivePath: archive,
      stagingDirPath: join(home.path, 'read'),
    );
    final container = buildContainer();
    await container
        .read(backupActionProvider.notifier)
        .applyRestore(data, RestoreOption.onlyProfiles);
    expect(await database.restoreCommit(4242), isNull);
    expect(await markers(), isEmpty);
    expect(await recover(), isEmpty);
  });

  test('every message names what happened without claiming too much', () {
    final l10n = currentAppLocalizations;
    String of(RestoreRecoveryOutcome outcome) =>
        restoreRecoveryMessage(RestoreRecoveryReport(outcome), l10n);
    expect(of(RestoreRecoveryOutcome.rolledBack), contains('was not changed'));
    for (final outcome in RestoreRecoveryOutcome.values) {
      if (outcome == RestoreRecoveryOutcome.rolledBack) continue;
      expect(of(outcome), isNot(contains('was not changed')));
    }
    loadAppLocalizations(const Locale('zh'));
    addTearDown(() => loadAppLocalizations(const Locale('en')));
    final zh = currentAppLocalizations;
    expect(
      restoreRecoveryMessage(
        const RestoreRecoveryReport(RestoreRecoveryOutcome.rolledBack),
        zh,
      ),
      contains('现有数据未改动'),
    );
    for (final outcome in RestoreRecoveryOutcome.values) {
      if (outcome == RestoreRecoveryOutcome.rolledBack) continue;
      final text = restoreRecoveryMessage(RestoreRecoveryReport(outcome), zh);
      expect(text, isNot(contains('未改动')));
    }
    final pending = restoreRecoveryMessage(
      const RestoreRecoveryReport(
        RestoreRecoveryOutcome.pending,
        skippedSteps: [RestoreStep.settings],
        pendingMounts: ['甲'],
        followUp: RestoreFollowUp.nextLaunch,
      ),
      zh,
    );
    expect(pending, startsWith('数据已恢复，后续处理尚未完成。'));
    expect(pending, contains('应用备份中的设置'));
    expect(pending, contains('甲'));
    expect(pending, contains('下次启动'));
    final incomplete = restoreRecoveryMessage(
      const RestoreRecoveryReport(
        RestoreRecoveryOutcome.incomplete,
        skippedSteps: [RestoreStep.mitm],
        followUp: RestoreFollowUp.restoreAgain,
      ),
      zh,
    );
    expect(incomplete, startsWith('恢复后数据又被修改过，为保留这些修改，已跳过部分恢复步骤。'));
    expect(incomplete, isNot(contains('旧版本')));
    expect(
      restoreRecoveryMessage(
        const RestoreRecoveryReport(RestoreRecoveryOutcome.unreadable),
        zh,
      ),
      '上次恢复被中断，恢复记录无法读取。数据库中未找到本次恢复的提交记录；'
      '部分文件可能已被替换，当前无法确认。为避免覆盖现有数据，未进行自动处理。',
      reason: 'the approved copy, with no re-restore guidance after it',
    );
    expect(
      restoreRecoveryMessage(
        const RestoreRecoveryReport(
          RestoreRecoveryOutcome.incomplete,
          followUp: RestoreFollowUp.restoreAgain,
        ),
        zh,
      ),
      allOf(isNot(contains('恢复后数据又被修改过')), isNot(contains('已跳过'))),
      reason: 'said only when steps were really skipped',
    );
    expect(incomplete.split('\n').take(2), [
      '恢复后数据又被修改过，为保留这些修改，已跳过部分恢复步骤。',
      '已跳过：重新检查 MITM 模块。当前数据保持现状。',
    ], reason: 'followed by the steps it actually skipped');
    expect(incomplete, contains('重新恢复备份'));
  });

  group('review fixes', () {
    test('an unreadable journal whose restore committed says the data was '
        'restored', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterCommit,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      final [dir] = journals();
      File(join(dir.path, 'journal.json')).writeAsStringSync('{broken');
      await relaunch();

      var rechecked = 0;
      // recover() runs the consent recheck too; it must not change what
      // is said, since no step can be verified without the journal.
      final reports = await recover(mitm: () => rechecked++);

      expect(rechecked, 1, reason: 'the consent recheck still runs');
      expect(reports, hasLength(1), reason: 'the recheck adds no success');
      final report = reports.single;
      expect(report.outcome, RestoreRecoveryOutcome.committedUnconfirmed);
      expect(report.followUp, RestoreFollowUp.none, reason: 'no restoreAgain');
      expect(report.skippedSteps, isEmpty, reason: 'no step claimed owed');
      expect(await markers(), isEmpty);
      expect(journals(), isEmpty);
      expect(quarantined(), hasLength(1), reason: 'the journal is kept');
      final en = currentAppLocalizations;
      final message = restoreRecoveryMessage(report, en);
      expect(message, contains(en.restoreResultCommitKnown));
      expect(message, contains(en.restoreResultUnknownItems));
      expect(message, isNot(contains(en.restoreActionRestoreAgain)));
      expect(message, isNot(contains(en.restoreRecoveryCompleted)));
      loadAppLocalizations(const Locale('zh'));
      addTearDown(() => loadAppLocalizations(const Locale('en')));
      final zh = currentAppLocalizations;
      expect(restoreRecoveryMessage(report, zh).split('\n'), [
        '已确认：本次恢复的数据已写入数据库。',
        '无法读取待处理项，暂不能确认后续处理是否完成。',
      ]);
    });

    test('an unreadable committed journal stays unconfirmed even when the '
        'consent recheck fails', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterCommit,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      final [dir] = journals();
      File(join(dir.path, 'journal.json')).writeAsStringSync('{broken');
      await relaunch();

      final reports = await recover(mitm: () => throw StateError('no'));

      expect(
        [for (final r in reports) r.outcome],
        [RestoreRecoveryOutcome.committedUnconfirmed],
      );
      // Kept, with its marker, so the next launch retries the recheck.
      expect(journals(), hasLength(1));
      expect(await markers(), hasLength(1));
      expect(quarantined(), isEmpty);

      await relaunch();
      var rechecked = 0;
      final retried = await recover(mitm: () => rechecked++);

      expect(rechecked, 1, reason: 'the next launch retries the recheck');
      expect(
        [for (final r in retried) r.outcome],
        [RestoreRecoveryOutcome.committedUnconfirmed],
      );
      expect(journals(), isEmpty);
      expect(await markers(), isEmpty);
      expect(quarantined(), hasLength(1));

      await relaunch();
      expect(await recover(), isEmpty, reason: 'done once it passed');
    });

    test('a published file torn after the commit is reported, not called '
        'complete', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterCommit,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      await relaunch();
      live(BackupEntries.profile(3)).writeAsStringSync('');

      final reports = await recover();

      expect(reports.single.outcome, RestoreRecoveryOutcome.pending);
      expect(reports.single.tornFiles, [BackupEntries.profile(3)]);
      expect(await storedProfileId(), 3, reason: 'the other steps still ran');
      expect(journals(), isEmpty);
      expect(
        restoreRecoveryMessage(reports.single, currentAppLocalizations),
        contains(BackupEntries.profile(3)),
      );
    });

    test('a crash between saving the settings and recording it does not '
        'count as another writer', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterConfigStored,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      final saved = await storedConfigHash(preferences);
      await relaunch();

      final reports = await recover();

      expect(reports.single.outcome, RestoreRecoveryOutcome.completed);
      expect(await storedConfigHash(preferences), saved);
      expect(await storedProfileId(), 3);
    });

    test('a journal naming a path outside the data directory is never '
        'acted on', () async {
      final outside = File(join(home.parent.path, 'outside-${home.hashCode}'))
        ..writeAsStringSync('keep');
      addTearDown(() => outside.existsSync() ? outside.deleteSync() : null);
      final dir = Directory(join(RestoreJournal.rootOf(home.path), '88'))
        ..createSync(recursive: true);
      File(join(dir.path, 'journal.json')).writeAsStringSync(
        jsonEncode({
          'id': 88,
          'createdAt': 1,
          'phase': 'published',
          'previousProviderFiles': <String>[],
          'restoredLocalProviderFiles': <String>[],
          'entries': [
            {
              'entry': '../${basename(outside.path)}',
              'replaced': false,
              'originalHash': null,
              'restoredHash': 'x',
            },
          ],
        }),
      );

      final reports = await recover();

      expect(reports.single.outcome, RestoreRecoveryOutcome.unreadable);
      expect(outside.readAsStringSync(), 'keep');
      expect(BackupEntries.isValid('profiles/1.yaml'), isTrue);
      expect(BackupEntries.isValid('profiles/../x.yaml'), isFalse);
      expect(BackupEntries.isValid('/etc/passwd'), isFalse);
      expect(BackupEntries.isValid('mitm/resources/ca.key/..'), isFalse);
    });

    test('a copy interrupted before its rename leaves no temp file', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.midPublish,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      final leftover = File(
        '${live(BackupEntries.profile(1)).path}.restore-tmp',
      )..writeAsStringSync('partial');
      await relaunch();

      expect(
        (await recover()).single.outcome,
        RestoreRecoveryOutcome.rolledBack,
      );
      expect(leftover.existsSync(), isFalse);
    });

    test('unreadable journals are set aside whole: nothing is deleted, '
        'not their replaced files nor any earlier quarantine', () async {
      final quarantine = join(RestoreJournal.rootOf(home.path), 'quarantine');
      for (var id = 10; id <= 13; id++) {
        File(join(quarantine, '$id', 'journal.json'))
          ..createSync(recursive: true)
          ..writeAsStringSync('{}');
      }
      File(join(quarantine, '3.unreadable', 'journal.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('?');
      for (var id = 1; id <= 5; id++) {
        final dir = Directory(join(RestoreJournal.rootOf(home.path), '$id'))
          ..createSync(recursive: true);
        File(join(dir.path, 'journal.json')).writeAsStringSync('?');
        File(join(dir.path, 'replaced', 'profiles', '$id.yaml'))
          ..createSync(recursive: true)
          ..writeAsStringSync('original-$id');
      }
      final reports = await recover();
      expect(
        {for (final r in reports) r.outcome},
        {RestoreRecoveryOutcome.unreadable},
      );
      expect(quarantined()..sort(), [
        '1.unreadable',
        '10',
        '11',
        '12',
        '13',
        '2.unreadable',
        '3.unreadable',
        '3.unreadable.2',
        '4.unreadable',
        '5.unreadable',
      ]);
      for (var id = 1; id <= 5; id++) {
        final name = id == 3 ? '3.unreadable.2' : '$id.unreadable';
        expect(
          File(
            join(quarantine, name, 'replaced', 'profiles', '$id.yaml'),
          ).readAsStringSync(),
          'original-$id',
        );
      }
    });

    test('unreadable is said only once the database was checked', () async {
      final dir = Directory(join(RestoreJournal.rootOf(home.path), '78'))
        ..createSync(recursive: true);
      File(join(dir.path, 'journal.json')).writeAsStringSync('{not json');
      final recovery = RestoreRecovery(
        db: () => throw StateError('database unavailable'),
        homeDirPath: () async => home.path,
        store: () => preferences,
      );
      await recovery.run();
      final [report] = recovery.takeReports();
      expect(report.outcome, RestoreRecoveryOutcome.failed);
      expect(journals(), hasLength(1), reason: 'left in place, untouched');
      expect(quarantined(), isEmpty);
    });

    test('a recovery that fails at launch after the commit says the data '
        'was restored and keeps the journal', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterCaches,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      await relaunch();

      final reports = await recover(store: _FailingSave(preferences));

      expect(reports.single.outcome, RestoreRecoveryOutcome.pending);
      expect(reports.single.followUp, RestoreFollowUp.nextLaunch);
      expect(reports.single.skippedSteps, contains(RestoreStep.settings));
      expect(journals(), hasLength(1));
      expect(await markers(), hasLength(1));
      expect(
        restoreRecoveryMessage(reports.single, currentAppLocalizations),
        contains('has been restored'),
      );
      expect(
        (await recover()).single.outcome,
        RestoreRecoveryOutcome.completed,
      );
    });

    test('at startup every owed step completes before background work '
        'starts, and reports come before any gate', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterPrefs,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      await relaunch();
      final recovery = RestoreRecovery(
        db: () => database,
        homeDirPath: () async => home.path,
        store: () => preferences,
      );
      await recovery.run();
      expect(recovery.needsMitm, isTrue);
      final events = <String>[];
      await recovery.completeAtStartup(
        mitm: () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          events.add('mitm');
        },
        startBackgroundWork: () async {
          events.add('start');
          expect(journals(), isEmpty, reason: 'recovery finished first');
          expect(await markers(), isEmpty);
        },
        show: (report) async => events.add('show:${report.outcome.name}'),
      );
      expect(events, ['mitm', 'start', 'show:completed']);
      // A launch that ends at the disclaimer afterwards leaves nothing owed.
      await relaunch();
      expect(await recover(), isEmpty);
    });

    test('a failing MITM step at startup stays owed and holds the restored '
        'modules until the next launch rechecks them', () async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        _Crash.afterPrefs,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      await relaunch();
      final recovery = RestoreRecovery(
        db: () => database,
        homeDirPath: () async => home.path,
        store: () => preferences,
      );
      await recovery.run();
      final shown = <RestoreRecoveryReport>[];
      await recovery.completeAtStartup(
        mitm: () async => throw StateError('mitm'),
        startBackgroundWork: () {},
        show: (report) async => shown.add(report),
      );
      expect(shown.single.outcome, RestoreRecoveryOutcome.pending);
      expect(shown.single.skippedSteps, [RestoreStep.mitm]);
      expect(shown.single.followUp, RestoreFollowUp.nextLaunch);
      expect(journals(), hasLength(1), reason: 'never finalized');
      expect(await markers(), hasLength(1));
      expect(recovery.mitmHold.value.holds(_module.id), isTrue);
      expect(recovery.mitmHold.value.holds(999), isFalse);
      expect(
        restoreRecoveryMessage(shown.single, currentAppLocalizations),
        allOf(contains('has been restored'), contains('next time')),
      );

      // The app is used meanwhile; that does not stop the retry.
      await database.profilesDao.putAll([_profile(9, 'Later').toCompanion(9)]);
      await relaunch();
      final next = RestoreRecovery(
        db: () => database,
        homeDirPath: () async => home.path,
        store: () => preferences,
      );
      await next.run();
      expect(next.mitmHold.value.holds(_module.id), isTrue);
      var retried = 0;
      await next.finish(() async => retried++);
      expect(retried, 1);
      expect(
        next.takeReports().single.outcome,
        RestoreRecoveryOutcome.completed,
      );
      expect(next.mitmHold.value.isEmpty, isTrue);
      expect(journals(), isEmpty);
      expect(await markers(), isEmpty);
    });

    test(
      'restored module rows never carry the other device\'s consent: '
      'they are written off and declined, and held until rechecked',
      () async {
        final (:container, :staging, :data) = await fixture();
        final action = container.read(backupActionProvider.notifier);
        action.afterRestoreCommit = () async => throw StateError('injected');
        await expectLater(
          action.applyRestore(
            data,
            RestoreOption.all,
            stagingDirPath: staging.path,
          ),
          throwsA(isA<RestorePartialException>()),
        );
        expect((_module.enabled, _module.accepted), (true, true));
        final [row] = await database.mitmModulesDao.query().get();
        expect((row.enabled, row.accepted), (false, false));
        expect(row.runsUnder(RestoreMitmHold.none), isFalse);
        final hold = container.read(restoreMitmHoldStateProvider);
        expect(hold.holds(_module.id), isTrue);
        final [dir] = journals();
        expect(
          jsonDecode(File(join(dir.path, 'journal.json')).readAsStringSync())
              as Map,
          containsPair('mitmModules', [_module.id]),
        );
      },
    );

    test('an uninterrupted restore holds its modules only until the '
        'recheck', () async {
      final (:container, :staging, :data) = await fixture();
      final action = container.read(backupActionProvider.notifier);
      final seen = <bool>[];
      action.onRestoreCheckpoint = (point) async {
        if (point == RestoreCheckpoint.committed ||
            point == RestoreCheckpoint.configSaved) {
          seen.add(restoreRecovery.mitmHold.value.holds(_module.id));
        }
      };
      await action.applyRestore(
        data,
        RestoreOption.all,
        stagingDirPath: staging.path,
      );
      expect(seen, [true, true]);
      expect(
        container.read(restoreMitmHoldStateProvider).holds(_module.id),
        isFalse,
      );
    });

    test('a pre-commit failure releases the hold', () async {
      final (:container, :staging, :data) = await fixture();
      database.beforeRestoreCommit = () async => throw StateError('rows');
      await expectLater(
        container
            .read(backupActionProvider.notifier)
            .applyRestore(
              data,
              RestoreOption.all,
              stagingDirPath: staging.path,
            ),
        throwsA(isA<StateError>()),
      );
      expect(restoreRecovery.mitmHold.value.holds(_module.id), isFalse);
    });

    test('a partial failure lists the targets to check; continuing finishes '
        'the steps, lifts the hold and says what is left', () async {
      final (:container, :staging, :data) = await fixture();
      final action = container.read(backupActionProvider.notifier);
      action.afterRestoreCommit = () async => throw StateError('injected');
      RestorePartialException? partial;
      try {
        await action.applyRestore(
          data,
          RestoreOption.all,
          stagingDirPath: staging.path,
        );
      } on RestorePartialException catch (error) {
        partial = error;
      }
      expect(partial!.steps, RestoreStep.values);
      expect(partial.pendingChecks, isEmpty, reason: 'known, and none');
      expect(restoreRecovery.mitmHold.value.holds(_module.id), isTrue);

      action.afterRestoreCommit = null;
      expect(await action.resumeRestore(), isEmpty);
      expect(restoreRecovery.mitmHold.value.isEmpty, isTrue);
      expect(journals(), isEmpty);
      expect(await markers(), isEmpty);
      expect(await storedProfileId(), 3);
      // What the recheck leaves: the file is not on this device, so the
      // module now asks for consent; it stays off and declined, as written.
      final [row] = await database.mitmModulesDao.query().get();
      expect(row.asksConsent, isTrue);
      expect((row.enabled, row.accepted), (false, false));
    });

    test('launch runs the recovery before any gate and wires the recheck '
        'that keeps the module list alive', () {
      final source = File('lib/bootstrap.dart').readAsStringSync();
      final body = source.substring(source.indexOf('Future<void> _initApp()'));
      final recovery = body.indexOf('restoreRecovery.completeAtStartup(');
      expect(recovery, greaterThan(0));
      expect(recovery, lessThan(body.indexOf('_handleFailedPreference()')));
      expect(recovery, lessThan(body.indexOf('_handlerDisclaimer()')));
      expect(recovery, lessThan(body.indexOf('startCore()')));
      expect(
        body.substring(recovery, body.indexOf('startBackgroundWork:')),
        contains('recheckRestored()'),
      );
    });

    test('a journal from before modules were recorded holds them all', () {
      final hold = RestoreMitmHold.of([null]);
      expect(hold.holds(1), isTrue);
      expect(
        RestoreMitmHold.of([
          [1],
        ]).holds(2),
        isFalse,
      );
      expect(RestoreMitmHold.of(const []).isEmpty, isTrue);
    });
  });

  group('restored MITM modules need consent on this device', () {
    /// Consented to here before the restore, and not in the backup.
    final local = MitmModule(
      id: 50,
      name: 'Local module',
      enabled: true,
      accepted: true,
      lastUpdateTime: DateTime(2026),
    );

    Future<({ProviderContainer container, MigrationData data})>
    mergeFixture() async {
      final (:container, :staging, :data) = await fixture();
      await database.mitmModulesDao.putAll([
        local.toCompanion(0),
        // The backup's module is here too, consented to: the backup's
        // whole item still wins, and its consent is still cleared.
        _module.copyWith(name: 'Local copy').toCompanion(1),
      ]);
      container
          .read(appSettingProvider.notifier)
          .update(
            (state) =>
                state.copyWith(restoreStrategy: RestoreStrategy.compatible),
          );
      await container
          .read(backupActionProvider.notifier)
          .applyRestore(data, RestoreOption.all, stagingDirPath: staging.path);
      return (container: container, data: data);
    }

    Future<Map<int, MitmModule>> rows() async => {
      for (final row in await database.mitmModulesDao.query().get())
        row.id: row,
    };

    test('a restored module the backup had accepted does not run after '
        'the commit and a passing recheck', () async {
      final (:container, data: _) = await mergeFixture();
      expect(
        restoreRecovery.mitmHold.value.isEmpty,
        isTrue,
        reason: 'the recheck passed and lifted the hold',
      );
      await container.read(mitmModulesActionProvider.notifier).recheckConsent();
      final restored = (await rows())[_module.id]!;
      expect(restored.name, _module.name, reason: 'the backup wins');
      expect((restored.enabled, restored.accepted), (false, false));
      expect(restored.runsUnder(restoreRecovery.mitmHold.value), isFalse);
      expect(
        restored.awaitsConsent,
        isFalse,
        reason: 'declined, so never offered or turned on by itself',
      );
    });

    test(
      'a relaunch after the journal finished does not run it either',
      () async {
        await mergeFixture();
        expect(journals(), isEmpty);
        expect(await markers(), isEmpty);
        await relaunch();
        final next = RestoreRecovery(
          db: () => database,
          homeDirPath: () async => home.path,
          store: () => preferences,
        );
        await next.run();
        expect(next.needsMitm, isFalse);
        expect(next.mitmHold.value.isEmpty, isTrue);
        final restored = (await rows())[_module.id]!;
        expect((restored.enabled, restored.accepted), (false, false));
        expect(restored.runsUnder(next.mitmHold.value), isFalse);
      },
    );

    test('a local module the restore did not write keeps its consent and '
        'runs', () async {
      await mergeFixture();
      final kept = (await rows())[local.id]!;
      expect((kept.enabled, kept.accepted), (true, true));
      expect(kept.runsUnder(restoreRecovery.mitmHold.value), isTrue);
    });

    test('only the explicit local consent turns it on', () async {
      final (:container, data: _) = await mergeFixture();
      final action = container.read(mitmModulesActionProvider.notifier);
      final keep = container.listen(mitmModulesProvider, (_, _) {});
      addTearDown(keep.close);
      await container.read(mitmModulesProvider.future);
      await action.recordConsent(_module.id, asksConsent: true, agreed: true);
      await pumpEventQueue();
      final restored = (await rows())[_module.id]!;
      expect((restored.enabled, restored.accepted), (true, true));
      expect(restored.runsUnder(restoreRecovery.mitmHold.value), isTrue);
    });
  });
  group('an old-format journal without the module list', () {
    final other = MitmModule(
      id: 50,
      name: 'Other module',
      enabled: true,
      accepted: true,
      lastUpdateTime: DateTime(2026),
    );

    Future<Map<int, (bool, bool?)>> states() async => {
      for (final row in await database.mitmModulesDao.query().get())
        row.id: (row.enabled, row.accepted),
    };

    /// Crashes at [crash], then leaves what an old development build would
    /// have: modules on, and a journal with no `mitmModules` key unless
    /// [keepKey].
    Future<ProviderContainer> oldCrash(
      _Crash crash, {
      bool keepKey = false,
    }) async {
      final (:container, :staging, :data) = await fixture();
      await crashAt(
        crash,
        container.read(backupActionProvider.notifier),
        data,
        staging.path,
      );
      await database.mitmModulesDao.putAll([
        if (crash.committed) _module.toCompanion(0),
        other.toCompanion(1),
      ]);
      final [dir] = journals();
      final file = File(join(dir.path, 'journal.json'));
      final map = jsonDecode(file.readAsStringSync()) as Map;
      // The old build wrote these rows itself, before its checkpoint.
      if (crash.committed) {
        map['dbFingerprint'] = await database.restoreFingerprint();
      }
      if (!keepKey) expect(map.remove('mitmModules'), [_module.id]);
      file.writeAsStringSync(jsonEncode(map));
      await relaunch();
      restoreRecovery.clearMitmHolds();
      return container;
    }

    for (final crash in [
      _Crash.afterCommit,
      _Crash.afterCaches,
      _Crash.afterPrefs,
    ]) {
      test('${crash.name}: turns every module off and declined, keeps their '
          'settings, and never calls the restore finished', () async {
        await oldCrash(crash);
        final before = {
          for (final row in await database.mitmModulesDao.query().get())
            row.id: row,
        };
        expect(await states(), {41: (true, true), 50: (true, true)});

        final reports = await recover();

        expect(await states(), {41: (false, false), 50: (false, false)});
        for (final row in await database.mitmModulesDao.query().get()) {
          final was = before[row.id]!;
          expect(
            row.copyWith(enabled: was.enabled, accepted: was.accepted),
            was,
            reason: 'only the two flags change',
          );
        }
        final report = reports.single;
        expect(report.mitmAllOff, isTrue);
        expect(report.outcome, RestoreRecoveryOutcome.pending);
        expect(journals(), isEmpty);
        expect(await markers(), isEmpty);
        final en = currentAppLocalizations;
        final message = restoreRecoveryMessage(report, en);
        expect(message, contains(en.restoreRecoveryMitmAllOff));
        expect(message, isNot(contains(en.restoreRecoveryCompleted)));
      });
    }

    test('stays off on the next launch until consented to here', () async {
      final container = await oldCrash(_Crash.afterCommit);
      await recover();
      await relaunch();
      expect(await recover(), isEmpty);
      expect(await states(), {41: (false, false), 50: (false, false)});

      final action = container.read(mitmModulesActionProvider.notifier);
      final keep = container.listen(mitmModulesProvider, (_, _) {});
      addTearDown(keep.close);
      await container.read(mitmModulesProvider.future);
      await action.recordConsent(other.id, asksConsent: true, agreed: true);
      await pumpEventQueue();
      expect(await states(), {41: (false, false), 50: (true, true)});
    });

    for (final (name, trigger) in [
      (
        'the write fails',
        'CREATE TRIGGER t_off BEFORE UPDATE ON mitm_modules '
            "BEGIN SELECT RAISE(ABORT, 'disk'); END",
      ),
      (
        'a row still reads on',
        'CREATE TRIGGER t_off AFTER UPDATE ON mitm_modules WHEN NEW.id = 50 '
            'BEGIN UPDATE mitm_modules SET enabled = 1 WHERE id = 50; END',
      ),
    ]) {
      test('$name: says turning off failed, never that they are off; all '
          'stay held this run and the next launch tries again', () async {
        await oldCrash(_Crash.afterCommit);
        await database.customStatement(trigger);
        final recovery = RestoreRecovery(
          db: () => database,
          homeDirPath: () async => home.path,
          store: () => preferences,
        );
        await recovery.run();
        if (recovery.needsMitm) await recovery.finish(() async {});
        final report = recovery.takeReports().single;

        expect(report.mitmAllOff, isFalse);
        expect(report.mitmOffFailed, isTrue);
        expect(
          report.outcome,
          isNot(RestoreRecoveryOutcome.completed),
          reason: 'never called finished',
        );
        final en = currentAppLocalizations;
        final message = restoreRecoveryMessage(report, en);
        expect(message, contains(en.restoreRecoveryMitmOffFailed));
        expect(message, isNot(contains(en.restoreRecoveryMitmAllOff)));
        for (final id in [41, 50, 999]) {
          expect(recovery.mitmHold.value.holds(id), isTrue, reason: '$id');
        }
        expect(journals(), hasLength(1), reason: 'kept for the next launch');
        expect(await markers(), hasLength(1));

        await database.customStatement('DROP TRIGGER t_off');
        await relaunch();
        final next = await recover();
        expect(next.single.mitmAllOff, isTrue);
        expect(next.single.mitmOffFailed, isFalse);
        expect(await states(), {41: (false, false), 50: (false, false)});
        expect(journals(), isEmpty);
      });
    }

    test('a failed recheck keeps the journal in its old format, so the next '
        'launch turns them off again and says so', () async {
      await oldCrash(_Crash.afterCommit);
      final first = await recover(mitm: () => throw StateError('no'));
      expect(first.single.mitmAllOff, isTrue);
      final [dir] = journals();
      expect(
        (jsonDecode(File(join(dir.path, 'journal.json')).readAsStringSync())
                as Map)
            .containsKey('mitmModules'),
        isFalse,
      );
      // Turned on in between, as the old build might.
      await database.mitmModulesDao.putAll([other.toCompanion(1)]);
      await relaunch();

      final second = await recover();

      expect(await states(), {41: (false, false), 50: (false, false)});
      expect(second.single.mitmAllOff, isTrue);
      expect(journals(), isEmpty);
    });

    test('a restore rolled back before its rows committed changes no '
        'module', () async {
      await oldCrash(_Crash.beforePublish);
      final reports = await recover();
      expect(reports.single.outcome, RestoreRecoveryOutcome.rolledBack);
      expect(reports.single.mitmAllOff, isFalse);
      expect(await states(), {50: (true, true)});
    });

    test('a current journal leaves modules it did not write alone', () async {
      await oldCrash(_Crash.afterCommit, keepKey: true);
      final reports = await recover();
      expect(reports.single.mitmAllOff, isFalse);
      expect(reports.single.outcome, RestoreRecoveryOutcome.completed);
      expect((await states())[50], (true, true));
    });
  });
}

/// Saving settings fails, as a full disk would make it.
class _FailingSave implements Preferences {
  final Preferences _inner;

  _FailingSave(this._inner);

  @override
  Future<Map<String, Object?>?> getConfigMap() => _inner.getConfigMap();

  @override
  Future<bool> saveConfig(Config config) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
