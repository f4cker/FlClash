import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/backup.dart';
import 'package:fl_clash/common/file.dart';
import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:path/path.dart';

/// Lives in the home directory, not the temp one, so it survives a crash and
/// an OS temp purge. Older builds never look inside it.
const restoreJournalDirectoryName = 'restore-journal';
const _quarantineDirectoryName = 'quarantine';
const _journalFileName = 'journal.json';
const _replacedDirectoryName = 'replaced';
const _keptQuarantines = 3;

/// The order a restore moves through. Everything before [committed] can be
/// undone; from [committed] on, the database holds the backup and the rest
/// only moves forward.
enum RestorePhase {
  prepared,
  publishing,
  published,
  committed,
  cachesCleared,
  configSaved,
  mitmDone,
  finalizing,
}

/// Where a restore may be interrupted; tests stop it there.
enum RestoreCheckpoint {
  prepared,
  filePublished,
  published,
  committed,
  cachesCleared,
  configWritten,
  configStored,
  configSaved,
  mitmDone,
}

/// What a recovery could not complete for a committed restore.
enum RestoreStep { caches, settings, mitm }

/// Stands in for the process dying: a restore that sees it skips its own
/// clean-up, exactly as a crash would. Only tests throw it.
class RestoreCrash implements Exception {
  final Object? at;

  const RestoreCrash([this.at]);

  @override
  String toString() => 'RestoreCrash($at)';
}

Future<String?> fileSha256(File file) async {
  if (!await file.exists()) return null;
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

/// The stored settings as last saved, hashed. Null when none were saved.
Future<String?> storedConfigHash(Preferences store) async {
  final map = await store.getConfigMap();
  if (map == null) return null;
  return _hashConfigMap(map);
}

/// What [storedConfigHash] reads once [config] has been saved.
String configHash(Config config) =>
    _hashConfigMap(json.decode(json.encode(config)) as Map<String, Object?>);

String _hashConfigMap(Map<String, Object?> map) =>
    sha256.convert(utf8.encode(json.encode(map))).toString();

/// Flushes a directory's entries to disk, so a rename in it survives a power
/// loss. Dart cannot open a directory, hence libc; Windows has no
/// equivalent and relies on the rename alone.
void syncDirectory(String path) {
  if (Platform.isWindows) return;
  final libc = DynamicLibrary.process();
  final open = libc
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32),
        int Function(Pointer<Utf8>, int)
      >('open');
  final fsync = libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
    'fsync',
  );
  final close = libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
    'close',
  );
  final name = path.toNativeUtf8();
  final fd = open(name, 0);
  calloc.free(name);
  if (fd < 0) {
    throw FileSystemException('Cannot open directory to sync', path);
  }
  try {
    if (fsync(fd) != 0) {
      throw FileSystemException('Cannot sync directory', path);
    }
  } finally {
    close(fd);
  }
}

Future<void> _syncFile(File file) async {
  final handle = await file.open(mode: FileMode.append);
  try {
    await handle.flush();
  } finally {
    await handle.close();
  }
}

class RestoreJournalEntry {
  final String entry;
  final bool replaced;
  final String? originalHash;
  final String restoredHash;

  const RestoreJournalEntry({
    required this.entry,
    required this.replaced,
    required this.originalHash,
    required this.restoredHash,
  });

  Map<String, Object?> toJson() => {
    'entry': entry,
    'replaced': replaced,
    'originalHash': originalHash,
    'restoredHash': restoredHash,
  };

  static RestoreJournalEntry fromJson(Map<String, Object?> json) {
    final entry = json['entry'] as String;
    if (!BackupEntries.isValid(entry)) {
      throw FormatException('restore journal entry out of bounds', entry);
    }
    return RestoreJournalEntry(
      entry: entry,
      replaced: json['replaced'] as bool,
      originalHash: json['originalHash'] as String?,
      restoredHash: json['restoredHash'] as String,
    );
  }
}

/// A write-ahead record of one restore, written atomically (temp file and
/// rename) before each step it describes.
class RestoreJournal {
  final String homeDirPath;
  final int id;
  final int createdAt;
  final String? appBuild;
  final Map<String, Object?>? config;
  final List<String> previousProviderFiles;
  final List<String> restoredLocalProviderFiles;
  final List<RestoreJournalEntry> entries;
  RestorePhase phase;

  /// [storedConfigHash] right before the commit.
  String? prefsBefore;

  /// [Database.restoreFingerprint] after the latest step that wrote rows.
  String? dbFingerprint;

  /// [configHash] of the settings about to be saved, recorded before the
  /// save so a crash right after it is not mistaken for another writer.
  String? prefsTarget;

  /// Mount targets the commit left with a pending record.
  List<int> mountTargets;

  RestoreJournal._({
    required this.homeDirPath,
    required this.id,
    required this.createdAt,
    required this.appBuild,
    required this.config,
    required this.previousProviderFiles,
    required this.restoredLocalProviderFiles,
    required this.entries,
    required this.phase,
    this.prefsBefore,
    this.dbFingerprint,
    this.prefsTarget,
    this.mountTargets = const [],
  });

  static String rootOf(String homeDirPath) =>
      join(homeDirPath, restoreJournalDirectoryName);

  String get dirPath => join(rootOf(homeDirPath), '$id');

  String get _replacedDirPath => join(dirPath, _replacedDirectoryName);

  static Future<RestoreJournal> create({
    required String homeDirPath,
    required int id,
    required Map<String, Object?>? config,
    required List<String> previousProviderFiles,
    required List<String> restoredLocalProviderFiles,
    String? appBuild,
  }) async {
    final journal = RestoreJournal._(
      homeDirPath: homeDirPath,
      id: id,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      appBuild: appBuild,
      config: config,
      previousProviderFiles: previousProviderFiles,
      restoredLocalProviderFiles: restoredLocalProviderFiles,
      entries: [],
      phase: RestorePhase.prepared,
    );
    await journal._write();
    return journal;
  }

  /// Every journal still in [homeDirPath], oldest first. One that can't be
  /// read comes back as its id with a null journal.
  static Future<List<(int, RestoreJournal?)>> pending(
    String homeDirPath,
  ) async {
    final root = Directory(rootOf(homeDirPath));
    if (!await root.exists()) return const [];
    final found = <(int, RestoreJournal?)>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = int.tryParse(basename(entity.path));
      if (id == null) continue;
      RestoreJournal? journal;
      try {
        final file = File(join(entity.path, _journalFileName));
        journal = _fromJson(
          homeDirPath,
          json.decode(await file.readAsString()) as Map<String, Object?>,
        );
        if (journal.id != id) journal = null;
      } catch (error) {
        commonPrint.log(
          'unreadable restore journal $id: $error',
          logLevel: LogLevel.warning,
        );
      }
      found.add((id, journal));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return found;
  }

  static RestoreJournal _fromJson(
    String homeDirPath,
    Map<String, Object?> json,
  ) => RestoreJournal._(
    homeDirPath: homeDirPath,
    id: json['id'] as int,
    createdAt: json['createdAt'] as int,
    appBuild: json['appBuild'] as String?,
    config: (json['config'] as Map?)?.cast<String, Object?>(),
    previousProviderFiles: (json['previousProviderFiles'] as List)
        .cast<String>(),
    restoredLocalProviderFiles: (json['restoredLocalProviderFiles'] as List)
        .cast<String>(),
    entries: [
      for (final item in json['entries'] as List)
        RestoreJournalEntry.fromJson((item as Map).cast<String, Object?>()),
    ],
    phase: RestorePhase.values.byName(json['phase'] as String),
    prefsBefore: json['prefsBefore'] as String?,
    dbFingerprint: json['dbFingerprint'] as String?,
    prefsTarget: json['prefsTarget'] as String?,
    mountTargets: [...?(json['mountTargets'] as List?)?.cast<int>()],
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt,
    'appBuild': appBuild,
    'phase': phase.name,
    'config': config,
    'previousProviderFiles': previousProviderFiles,
    'restoredLocalProviderFiles': restoredLocalProviderFiles,
    'entries': [for (final entry in entries) entry.toJson()],
    'prefsBefore': prefsBefore,
    'dbFingerprint': dbFingerprint,
    'prefsTarget': prefsTarget,
    'mountTargets': mountTargets,
  };

  Future<void> _write() async {
    final created = !await Directory(dirPath).exists();
    await Directory(dirPath).create(recursive: true);
    final target = File(join(dirPath, _journalFileName));
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(json.encode(toJson()), flush: true);
    await temp.rename(target.path);
    syncDirectory(dirPath);
    if (created) syncDirectory(rootOf(homeDirPath));
  }

  Future<void> advance(
    RestorePhase next, {
    String? prefsBefore,
    String? dbFingerprint,
    String? prefsTarget,
    List<int>? mountTargets,
  }) async {
    phase = next;
    if (prefsBefore != null) this.prefsBefore = prefsBefore;
    if (dbFingerprint != null) this.dbFingerprint = dbFingerprint;
    if (prefsTarget != null) this.prefsTarget = prefsTarget;
    if (mountTargets != null) this.mountTargets = mountTargets;
    await _write();
  }

  /// Saves the file [entry] would overwrite, records both hashes, and only
  /// then copies [staged] over the live file.
  Future<void> publish(String entry, File staged) async {
    final target = File(BackupEntries.resolve(homeDirPath, entry));
    final replaced = await target.exists();
    String? originalHash;
    if (replaced) {
      await _copy(target, BackupEntries.resolve(_replacedDirPath, entry));
      originalHash = await fileSha256(target);
    }
    entries.add(
      RestoreJournalEntry(
        entry: entry,
        replaced: replaced,
        originalHash: originalHash,
        restoredHash: (await fileSha256(staged))!,
      ),
    );
    phase = RestorePhase.publishing;
    await _write();
    await _copy(staged, target.path);
  }

  /// Puts back what [publish] replaced and removes what it added, but only
  /// where the live file still holds the restored bytes: a file changed
  /// since, for instance by an older build, is left alone and returned.
  /// The journal is gone afterwards, set aside with its saved originals when
  /// a file was left alone.
  Future<List<String>> rollBack() async {
    await _clearCopyLeftovers();
    final kept = <String>[];
    for (final item in entries.reversed) {
      final live = File(BackupEntries.resolve(homeDirPath, item.entry));
      final liveHash = await fileSha256(live);
      if (item.replaced) {
        if (liveHash == item.originalHash) continue;
        final original = File(
          BackupEntries.resolve(_replacedDirPath, item.entry),
        );
        if (liveHash != item.restoredHash ||
            await fileSha256(original) != item.originalHash) {
          kept.add(item.entry);
          continue;
        }
        await _copy(original, live.path);
      } else {
        if (liveHash == null) continue;
        if (liveHash != item.restoredHash) {
          kept.add(item.entry);
          continue;
        }
        await live.delete();
        syncDirectory(live.parent.path);
      }
    }
    if (kept.isEmpty) {
      await discard();
    } else {
      await quarantine();
    }
    return kept;
  }

  /// Published files that no longer hold the bytes the restore wrote, as a
  /// write lost to a power cut leaves them.
  Future<List<String>> tornFiles() async {
    final torn = <String>[];
    for (final item in entries) {
      final live = File(BackupEntries.resolve(homeDirPath, item.entry));
      if (await fileSha256(live) != item.restoredHash) torn.add(item.entry);
    }
    return torn;
  }

  /// A copy interrupted before its rename leaves its temp file behind.
  Future<void> _clearCopyLeftovers() async {
    for (final item in entries) {
      final live = BackupEntries.resolve(homeDirPath, item.entry);
      await File('$live$_copySuffix').safeDelete();
    }
  }

  Future<void> discard() => Directory(dirPath).safeDelete(recursive: true);

  /// Kept for diagnosis rather than acted on; only the newest few stay.
  Future<void> quarantine() => _quarantine(homeDirPath, id);

  static Future<void> _quarantine(String homeDirPath, int id) async {
    final root = join(rootOf(homeDirPath), _quarantineDirectoryName);
    await Directory(root).create(recursive: true);
    final target = Directory(join(root, '$id'));
    await target.safeDelete(recursive: true);
    await Directory(join(rootOf(homeDirPath), '$id')).rename(target.path);
    final all =
        [
          await for (final entity in Directory(root).list(followLinks: false))
            if (entity is Directory &&
                int.tryParse(basename(entity.path)) != null)
              entity,
        ]..sort(
          (a, b) => int.parse(
            basename(b.path),
          ).compareTo(int.parse(basename(a.path))),
        );
    for (final stale in all.skip(_keptQuarantines)) {
      await stale.safeDelete(recursive: true);
    }
  }

  /// The marker goes first: a journal without one in [finalizing] is done.
  Future<void> finish(Database db) async {
    await advance(RestorePhase.finalizing);
    await db.clearRestoreCommit(id);
    await discard();
  }

  /// What is still to do once the database has committed.
  List<RestoreStep> remainingSteps() => [
    if (phase.index < RestorePhase.cachesCleared.index) RestoreStep.caches,
    if (config != null && phase.index < RestorePhase.configSaved.index)
      RestoreStep.settings,
    if (phase.index < RestorePhase.mitmDone.index) RestoreStep.mitm,
  ];

  /// A replaced cache belongs to a provider the restore removed or renamed;
  /// a restored local source outdates the mrs compiled from the old one.
  Future<void> clearCaches(Database db) async {
    await clearRestoreCaches(
      db,
      previousProviderFiles: previousProviderFiles,
      restoredLocalProviderFiles: restoredLocalProviderFiles,
    );
  }
}

Future<void> clearRestoreCaches(
  Database db, {
  required Iterable<String> previousProviderFiles,
  required Iterable<String> restoredLocalProviderFiles,
}) async {
  final kept = (await db.clashProvidersDao.fileNames().get()).toSet();
  for (final fileName in previousProviderFiles) {
    if (kept.contains(fileName)) continue;
    final path = await appPath.getProviderCachePath(fileName);
    await File(path).safeDelete();
    await File('$path.mrs').safeDelete();
  }
  for (final fileName in restoredLocalProviderFiles) {
    final path = await appPath.getProviderCachePath(fileName);
    await File('$path.mrs').safeDelete();
  }
}

const _copySuffix = '.restore-tmp';

/// The bytes reach the disk before the rename, and the rename before this
/// returns, so a commit that follows never outlives the file it describes.
Future<void> _copy(File source, String targetPath) async {
  await Directory(dirname(targetPath)).create(recursive: true);
  final temp = File('$targetPath$_copySuffix');
  await source.copy(temp.path);
  await _syncFile(temp);
  await temp.rename(targetPath);
  syncDirectory(dirname(targetPath));
}

enum RestoreRecoveryOutcome {
  /// Nothing had committed; every published file went back.
  rolledBack,

  /// Nothing had committed, but files changed since were left as they are.
  rolledBackPartly,

  /// The database had committed; the remaining steps ran at launch.
  completed,

  /// The database had committed, but a later step is not done or a file
  /// does not hold what was restored.
  pending,

  /// The database had committed, but data changed afterwards, so the
  /// remaining steps were skipped.
  incomplete,

  /// The journal could not be read and nothing had committed.
  unreadable,

  /// Recovery itself failed before it could tell whether anything had
  /// committed; the journal stays for the next launch.
  failed,
}

/// What the user can do about a [RestoreRecoveryReport].
enum RestoreFollowUp { none, nextLaunch, retryNow, restoreAgain }

class RestoreRecoveryReport {
  final RestoreRecoveryOutcome outcome;
  final List<String> keptFiles;

  /// For [RestoreRecoveryOutcome.incomplete], the steps skipped; for
  /// [RestoreRecoveryOutcome.pending], the steps not yet done.
  final List<RestoreStep> skippedSteps;
  final List<String> tornFiles;

  /// Labels of restored mount targets still waiting for a readback.
  final List<String> pendingMounts;
  final RestoreFollowUp followUp;

  const RestoreRecoveryReport(
    this.outcome, {
    this.keptFiles = const [],
    this.skippedSteps = const [],
    this.tornFiles = const [],
    this.pendingMounts = const [],
    this.followUp = RestoreFollowUp.none,
  });

  @override
  String toString() =>
      'RestoreRecoveryReport($outcome, kept: $keptFiles, '
      'skipped: $skippedSteps, torn: $tornFiles, mounts: $pendingMounts, '
      'followUp: $followUp)';
}

/// The labels of [targetIds] whose mount record is still pending.
Future<List<String>> pendingMountLabels(
  Database db,
  Iterable<int> targetIds,
) async {
  final ids = targetIds.toSet();
  if (ids.isEmpty) return const [];
  final targets = await db.mountsDao.targets();
  final pending = {
    for (final id in ids)
      if (targets[id]?.pending != null) id,
  };
  if (pending.isEmpty) return const [];
  return [
    for (final profile in await db.profilesDao.query().get())
      if (pending.contains(profile.id)) profile.realLabel,
  ];
}

/// Finishes or undoes a restore the app did not live to complete. [run]
/// needs only the database, files and preferences, so it runs before the
/// settings are loaded; the MITM step needs providers and runs in [finish].
class RestoreRecovery {
  final Database Function() _db;
  final Future<String> Function() _homeDirPath;
  final Preferences Function() _preferences;

  RestoreRecovery({
    Database Function()? db,
    Future<String> Function()? homeDirPath,
    Preferences Function()? store,
  }) : _db = db ?? (() => database),
       _homeDirPath = homeDirPath ?? (() => appPath.homeDirPath),
       _preferences = store ?? (() => preferences);

  final _awaitingMitm = <(RestoreJournal, List<String>)>[];
  final reports = <RestoreRecoveryReport>[];

  bool get needsMitm => _awaitingMitm.isNotEmpty;

  Future<void> run() async {
    final List<(int, RestoreJournal?)> found;
    try {
      found = await RestoreJournal.pending(await _homeDirPath());
    } catch (error) {
      commonPrint.log(
        'restore journals unreadable: $error',
        logLevel: LogLevel.error,
      );
      reports.add(const RestoreRecoveryReport(RestoreRecoveryOutcome.failed));
      return;
    }
    for (final (id, journal) in found) {
      try {
        await _recover(id, journal);
      } catch (error, stack) {
        // Left in place: the next launch tries again.
        commonPrint.log(
          'restore recovery $id failed: $error\n$stack',
          logLevel: LogLevel.error,
        );
        reports.add(await _failure(id, journal));
      }
    }
  }

  Future<RestoreRecoveryReport> _failure(
    int id,
    RestoreJournal? journal,
  ) async {
    String? committed;
    try {
      committed = await _db().restoreCommit(id);
    } catch (_) {
      committed = null;
    }
    if (committed == null) {
      return const RestoreRecoveryReport(RestoreRecoveryOutcome.failed);
    }
    return RestoreRecoveryReport(
      RestoreRecoveryOutcome.pending,
      skippedSteps: journal?.remainingSteps() ?? RestoreStep.values,
      followUp: RestoreFollowUp.nextLaunch,
    );
  }

  Future<void> _recover(int id, RestoreJournal? journal) async {
    final db = _db();
    final committed = await db.restoreCommit(id);
    if (journal == null) {
      await RestoreJournal._quarantine(await _homeDirPath(), id);
      if (committed == null) {
        reports.add(
          const RestoreRecoveryReport(RestoreRecoveryOutcome.unreadable),
        );
        return;
      }
      // Which steps ran is unknown; none can be redone without the record.
      await db.clearRestoreCommit(id);
      reports.add(
        const RestoreRecoveryReport(
          RestoreRecoveryOutcome.pending,
          skippedSteps: RestoreStep.values,
          followUp: RestoreFollowUp.restoreAgain,
        ),
      );
      return;
    }
    if (committed == null) {
      if (journal.phase.index <= RestorePhase.published.index) {
        final kept = await journal.rollBack();
        reports.add(
          kept.isEmpty
              ? const RestoreRecoveryReport(RestoreRecoveryOutcome.rolledBack)
              : RestoreRecoveryReport(
                  RestoreRecoveryOutcome.rolledBackPartly,
                  keptFiles: kept,
                ),
        );
        return;
      }
      final remaining = journal.remainingSteps();
      if (journal.phase == RestorePhase.finalizing || remaining.isEmpty) {
        await journal.discard();
        return;
      }
      // The rows committed once but their marker is gone (the database was
      // cleared or replaced since): nothing here can be trusted to apply.
      await journal.quarantine();
      reports.add(
        RestoreRecoveryReport(
          RestoreRecoveryOutcome.incomplete,
          skippedSteps: remaining,
          followUp: RestoreFollowUp.restoreAgain,
        ),
      );
      return;
    }
    await journal._clearCopyLeftovers();
    if (journal.phase == RestorePhase.finalizing) {
      await journal.finish(db);
      reports.add(await _finished(db, journal, const []));
      return;
    }
    final store = _preferences();
    final expected = journal.dbFingerprint ?? committed;
    final dbUnchanged = await db.restoreFingerprint() == expected;
    final prefs = await storedConfigHash(store);
    final settingsSaved =
        journal.config == null ||
        journal.phase.index >= RestorePhase.configSaved.index ||
        (prefs != null &&
            (prefs == journal.prefsTarget ||
                prefs == configHash(Config.fromJson(journal.config!))));
    final prefsUnchanged = settingsSaved || prefs == journal.prefsBefore;
    if (!dbUnchanged || !prefsUnchanged) {
      // Someone else ran on this data after the commit; rolling forward
      // would overwrite what they did.
      final remaining = journal.remainingSteps();
      await db.clearRestoreCommit(id);
      await journal.quarantine();
      reports.add(
        RestoreRecoveryReport(
          RestoreRecoveryOutcome.incomplete,
          skippedSteps: remaining,
          pendingMounts: await pendingMountLabels(db, journal.mountTargets),
          followUp: RestoreFollowUp.restoreAgain,
        ),
      );
      return;
    }
    final torn = await journal.tornFiles();
    if (journal.phase.index < RestorePhase.cachesCleared.index) {
      await journal.clearCaches(db);
      await journal.advance(RestorePhase.cachesCleared);
    }
    if (journal.phase.index < RestorePhase.configSaved.index) {
      if (!settingsSaved) {
        if (!await store.saveConfig(Config.fromJson(journal.config!))) {
          throw StateError('saving the restored settings failed');
        }
      }
      await journal.advance(
        RestorePhase.configSaved,
        dbFingerprint: await db.restoreFingerprint(),
      );
    }
    if (journal.phase.index < RestorePhase.mitmDone.index) {
      _awaitingMitm.add((journal, torn));
      return;
    }
    await journal.finish(db);
    reports.add(await _finished(db, journal, torn));
  }

  Future<RestoreRecoveryReport> _finished(
    Database db,
    RestoreJournal journal,
    List<String> torn, {
    List<RestoreStep> failedSteps = const [],
  }) async {
    final mounts = await pendingMountLabels(db, journal.mountTargets);
    if (torn.isEmpty && failedSteps.isEmpty) {
      return RestoreRecoveryReport(
        RestoreRecoveryOutcome.completed,
        pendingMounts: mounts,
      );
    }
    return RestoreRecoveryReport(
      RestoreRecoveryOutcome.pending,
      skippedSteps: failedSteps,
      tornFiles: torn,
      pendingMounts: mounts,
      followUp: RestoreFollowUp.restoreAgain,
    );
  }

  /// Runs the MITM step [run] left, then removes the journal and marker. A
  /// failing step is reported rather than retried on every launch.
  Future<void> finish(Future<void> Function() mitm) async {
    final db = _db();
    for (final item in [..._awaitingMitm]) {
      _awaitingMitm.remove(item);
      final (journal, torn) = item;
      var failed = const <RestoreStep>[];
      try {
        await mitm();
        await journal.advance(RestorePhase.mitmDone);
      } catch (error) {
        commonPrint.log(
          'restore recovery ${journal.id} mitm step failed: $error',
          logLevel: LogLevel.warning,
        );
        failed = const [RestoreStep.mitm];
      }
      try {
        await journal.finish(db);
      } catch (error) {
        commonPrint.log(
          'restore recovery ${journal.id} finalize failed: $error',
          logLevel: LogLevel.warning,
        );
      }
      reports.add(await _finished(db, journal, torn, failedSteps: failed));
    }
  }

  /// The launch-time remainder: every step a recovery owes completes before
  /// [startBackgroundWork] lets anything else write, and the reports are
  /// shown before any gate that could end the launch early.
  Future<void> completeAtStartup({
    required Future<void> Function() mitm,
    required void Function() startBackgroundWork,
    required Future<void> Function(RestoreRecoveryReport report) show,
  }) async {
    try {
      if (needsMitm) await finish(mitm);
    } catch (error) {
      commonPrint.log(
        'restore recovery finish failed: $error',
        logLevel: LogLevel.error,
      );
      reports.add(
        const RestoreRecoveryReport(
          RestoreRecoveryOutcome.pending,
          skippedSteps: [RestoreStep.mitm],
          followUp: RestoreFollowUp.restoreAgain,
        ),
      );
    }
    startBackgroundWork();
    for (final report in takeReports()) {
      await show(report);
    }
  }

  /// Reports are shown once.
  List<RestoreRecoveryReport> takeReports() {
    final taken = [...reports];
    reports.clear();
    return taken;
  }
}

String restoreStepLabel(RestoreStep step, AppLocalizations l10n) =>
    switch (step) {
      RestoreStep.caches => l10n.restoreStepCaches,
      RestoreStep.settings => l10n.restoreStepSettings,
      RestoreStep.mitm => l10n.restoreStepMitm,
    };

String restoreFollowUpText(RestoreFollowUp followUp, AppLocalizations l10n) =>
    switch (followUp) {
      RestoreFollowUp.none => '',
      RestoreFollowUp.nextLaunch => l10n.restoreActionNextLaunch,
      RestoreFollowUp.retryNow => l10n.restoreActionRetry,
      RestoreFollowUp.restoreAgain => l10n.restoreActionRestoreAgain,
    };

/// Never says the data is unchanged once the restore had committed, and
/// never calls a restore finished while a step or a mount is outstanding.
String restoreRecoveryMessage(
  RestoreRecoveryReport report,
  AppLocalizations l10n,
) {
  final separator = l10n.mountNameSeparator;
  String steps() =>
      report.skippedSteps.map((s) => restoreStepLabel(s, l10n)).join(separator);
  final lines = switch (report.outcome) {
    RestoreRecoveryOutcome.rolledBack => [l10n.restoreRecoveryRolledBack],
    RestoreRecoveryOutcome.rolledBackPartly => [
      l10n.restoreRecoveryRolledBackPartly(report.keptFiles.join(separator)),
    ],
    RestoreRecoveryOutcome.completed => [l10n.restoreRecoveryCompleted],
    RestoreRecoveryOutcome.pending => [
      l10n.restoreRestoredPending,
      if (report.skippedSteps.isNotEmpty) l10n.restorePendingSteps(steps()),
      if (report.tornFiles.isNotEmpty)
        l10n.restoreTornFiles(report.tornFiles.join(separator)),
    ],
    RestoreRecoveryOutcome.incomplete => [
      l10n.restoreOldVersionSkipped,
      if (report.skippedSteps.isNotEmpty) l10n.restoreSkippedSteps(steps()),
    ],
    RestoreRecoveryOutcome.unreadable => [l10n.restoreRecoveryUnreadable],
    RestoreRecoveryOutcome.failed => [l10n.restoreRecoveryFailed],
  };
  return [
    ...lines,
    if (report.pendingMounts.isNotEmpty)
      l10n.restorePendingMounts(report.pendingMounts.join(separator)),
    if (restoreFollowUpText(report.followUp, l10n) case final text
        when text.isNotEmpty)
      text,
  ].join('\n');
}

final restoreRecovery = RestoreRecovery();
