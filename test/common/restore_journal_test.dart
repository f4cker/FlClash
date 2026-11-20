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
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';

Profile _profile(int id, String label) =>
    Profile(id: id, label: label, autoUpdateDuration: Duration.zero);

/// Where a test stops the restore, as a crash would.
enum _Crash {
  beforePublish,
  midPublish,
  afterPublish,
  insideTransaction,
  afterCommit,
  afterCaches,
  afterConfigWritten,
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

  Future<List<RestoreRecoveryReport>> recover({void Function()? mitm}) async {
    final recovery = RestoreRecovery(
      db: () => database,
      homeDirPath: () async => home.path,
      store: () => preferences,
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
        isA<MessageException>().having(
          (e) => e.message,
          'message',
          contains('database changes were committed'),
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
        RestoreStep.mitm,
      ]);
      expect(mitmRuns, 0);
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
      expect(message, contains('already saved its data'));
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
      expect(reports.single.skippedSteps, [
        RestoreStep.settings,
        RestoreStep.mitm,
      ]);
      expect(await storedProfileId(), 2);
      expect(await markers(), isEmpty);
      expect(journals(), isEmpty);
    });

    test(
      'settings already saved: only the remaining steps are guarded',
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

        expect(reports.single.outcome, RestoreRecoveryOutcome.incomplete);
        expect(reports.single.skippedSteps, [RestoreStep.mitm]);
        expect(mitmRuns, 0);
        expect(await storedProfileId(), 3);
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
    expect(journals(), isEmpty);
    expect(quarantined(), ['77']);
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
    for (final outcome in [
      RestoreRecoveryOutcome.completed,
      RestoreRecoveryOutcome.incomplete,
      RestoreRecoveryOutcome.rolledBackPartly,
      RestoreRecoveryOutcome.unreadable,
    ]) {
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
    for (final outcome in [
      RestoreRecoveryOutcome.completed,
      RestoreRecoveryOutcome.incomplete,
    ]) {
      final text = restoreRecoveryMessage(RestoreRecoveryReport(outcome), zh);
      expect(text, contains('已写入数据'));
      expect(text, isNot(contains('未改动')));
    }
  });
}
