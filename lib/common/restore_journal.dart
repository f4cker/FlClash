import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
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
  return sha256.convert(utf8.encode(json.encode(map))).toString();
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

  static RestoreJournalEntry fromJson(Map<String, Object?> json) =>
      RestoreJournalEntry(
        entry: json['entry'] as String,
        replaced: json['replaced'] as bool,
        originalHash: json['originalHash'] as String?,
        restoredHash: json['restoredHash'] as String,
      );
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
  };

  Future<void> _write() async {
    await Directory(dirPath).create(recursive: true);
    final target = File(join(dirPath, _journalFileName));
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(json.encode(toJson()), flush: true);
    await temp.rename(target.path);
  }

  Future<void> advance(
    RestorePhase next, {
    String? prefsBefore,
    String? dbFingerprint,
  }) async {
    phase = next;
    if (prefsBefore != null) this.prefsBefore = prefsBefore;
    if (dbFingerprint != null) this.dbFingerprint = dbFingerprint;
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
  /// The journal is gone afterwards.
  Future<List<String>> rollBack() async {
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
      }
    }
    await discard();
    return kept;
  }

  Future<void> discard() => Directory(dirPath).safeDelete(recursive: true);

  /// Kept for diagnosis rather than acted on; only the newest few stay.
  Future<void> quarantine() async {
    final root = join(rootOf(homeDirPath), _quarantineDirectoryName);
    await Directory(root).create(recursive: true);
    final target = Directory(join(root, '$id'));
    await target.safeDelete(recursive: true);
    await Directory(dirPath).rename(target.path);
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

Future<void> _copy(File source, String targetPath) async {
  await Directory(dirname(targetPath)).create(recursive: true);
  final temp = '$targetPath.restore-tmp';
  await source.copy(temp);
  await File(temp).rename(targetPath);
}

enum RestoreRecoveryOutcome {
  /// Nothing had committed; every published file went back.
  rolledBack,

  /// Nothing had committed, but files changed since were left as they are.
  rolledBackPartly,

  /// The database had committed; the remaining steps ran at launch.
  completed,

  /// The database had committed, but data changed afterwards (or a step
  /// failed), so the remaining steps were skipped.
  incomplete,

  /// The journal could not be read; nothing was done automatically.
  unreadable,
}

class RestoreRecoveryReport {
  final RestoreRecoveryOutcome outcome;
  final List<String> keptFiles;
  final List<RestoreStep> skippedSteps;

  const RestoreRecoveryReport(
    this.outcome, {
    this.keptFiles = const [],
    this.skippedSteps = const [],
  });

  @override
  String toString() =>
      'RestoreRecoveryReport($outcome, kept: $keptFiles, '
      'skipped: $skippedSteps)';
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

  final _awaitingMitm = <RestoreJournal>[];
  final reports = <RestoreRecoveryReport>[];

  bool get needsMitm => _awaitingMitm.isNotEmpty;

  Future<void> run() async {
    final found = await RestoreJournal.pending(await _homeDirPath());
    for (final (id, journal) in found) {
      try {
        await _recover(id, journal);
      } catch (error, stack) {
        // Left in place: the next launch tries again.
        commonPrint.log(
          'restore recovery $id failed: $error\n$stack',
          logLevel: LogLevel.error,
        );
      }
    }
  }

  Future<void> _recover(int id, RestoreJournal? journal) async {
    final db = _db();
    final committed = await db.restoreCommit(id);
    if (journal == null) {
      final dir = Directory(
        join(RestoreJournal.rootOf(await _homeDirPath()), '$id'),
      );
      final quarantine = Directory(
        join(
          RestoreJournal.rootOf(await _homeDirPath()),
          _quarantineDirectoryName,
          '$id',
        ),
      );
      await quarantine.parent.create(recursive: true);
      await quarantine.safeDelete(recursive: true);
      await dir.rename(quarantine.path);
      if (committed != null) await db.clearRestoreCommit(id);
      reports.add(
        const RestoreRecoveryReport(RestoreRecoveryOutcome.unreadable),
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
        ),
      );
      return;
    }
    if (journal.phase == RestorePhase.finalizing) {
      await journal.finish(db);
      reports.add(
        const RestoreRecoveryReport(RestoreRecoveryOutcome.completed),
      );
      return;
    }
    final store = _preferences();
    final expected = journal.dbFingerprint ?? committed;
    final dbUnchanged = await db.restoreFingerprint() == expected;
    final prefsUnchanged =
        journal.config == null ||
        journal.phase.index >= RestorePhase.configSaved.index ||
        await storedConfigHash(store) == journal.prefsBefore;
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
        ),
      );
      return;
    }
    if (journal.phase.index < RestorePhase.cachesCleared.index) {
      await journal.clearCaches(db);
      await journal.advance(RestorePhase.cachesCleared);
    }
    if (journal.phase.index < RestorePhase.configSaved.index) {
      if (journal.config case final config?) {
        if (!await store.saveConfig(Config.fromJson(config))) {
          throw StateError('saving the restored settings failed');
        }
      }
      await journal.advance(
        RestorePhase.configSaved,
        dbFingerprint: await db.restoreFingerprint(),
      );
    }
    if (journal.phase.index < RestorePhase.mitmDone.index) {
      _awaitingMitm.add(journal);
      return;
    }
    await journal.finish(db);
    reports.add(const RestoreRecoveryReport(RestoreRecoveryOutcome.completed));
  }

  /// Runs the MITM step [run] left, then removes the journal and marker. A
  /// failing step is reported rather than retried on every launch.
  Future<void> finish(Future<void> Function() mitm) async {
    final db = _db();
    for (final journal in [..._awaitingMitm]) {
      _awaitingMitm.remove(journal);
      var outcome = const RestoreRecoveryReport(
        RestoreRecoveryOutcome.completed,
      );
      try {
        await mitm();
        await journal.advance(RestorePhase.mitmDone);
      } catch (error) {
        commonPrint.log(
          'restore recovery ${journal.id} mitm step failed: $error',
          logLevel: LogLevel.warning,
        );
        outcome = const RestoreRecoveryReport(
          RestoreRecoveryOutcome.incomplete,
          skippedSteps: [RestoreStep.mitm],
        );
      }
      try {
        await journal.finish(db);
      } catch (error) {
        commonPrint.log(
          'restore recovery ${journal.id} finalize failed: $error',
          logLevel: LogLevel.warning,
        );
      }
      reports.add(outcome);
    }
  }

  /// Reports are shown once.
  List<RestoreRecoveryReport> takeReports() {
    final taken = [...reports];
    reports.clear();
    return taken;
  }
}

/// Never says the data is unchanged once the restore had committed.
String restoreRecoveryMessage(
  RestoreRecoveryReport report,
  AppLocalizations l10n,
) {
  String step(RestoreStep step) => switch (step) {
    RestoreStep.caches => l10n.restoreStepCaches,
    RestoreStep.settings => l10n.restoreStepSettings,
    RestoreStep.mitm => l10n.restoreStepMitm,
  };
  return switch (report.outcome) {
    RestoreRecoveryOutcome.rolledBack => l10n.restoreRecoveryRolledBack,
    RestoreRecoveryOutcome.rolledBackPartly =>
      l10n.restoreRecoveryRolledBackPartly(
        report.keptFiles.join(l10n.mountNameSeparator),
      ),
    RestoreRecoveryOutcome.completed => l10n.restoreRecoveryCompleted,
    RestoreRecoveryOutcome.incomplete => l10n.restoreRecoveryIncomplete(
      report.skippedSteps.map(step).join(l10n.mountNameSeparator),
    ),
    RestoreRecoveryOutcome.unreadable => l10n.restoreRecoveryUnreadable,
  };
}

final restoreRecovery = RestoreRecovery();
