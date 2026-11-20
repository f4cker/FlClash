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
import 'package:fl_clash/common/restore_mount_plan.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
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

  /// [dbFingerprint] from before turning every module off, which happens in
  /// one transaction with recording the new one: a crash before that
  /// transaction commits leaves the database here.
  String? dbFingerprintBeforeMitmOff;

  /// [configHash] of the settings about to be saved, recorded before the
  /// save so a crash right after it is not mistaken for another writer.
  String? prefsTarget;

  /// Mount targets the commit left with a pending record.
  List<int> mountTargets;

  /// The MITM modules the restore writes, held off until their consent is
  /// rechecked here. Null (a journal from before this was recorded) holds
  /// every module.
  final List<int>? mitmModules;

  /// Read from a journal written by a development build before
  /// [mitmModules] was recorded: the key is absent, not null.
  final bool mitmUnrecorded;

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
    this.dbFingerprintBeforeMitmOff,
    this.prefsTarget,
    this.mountTargets = const [],
    this.mitmModules,
    this.mitmUnrecorded = false,
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
    List<int> mountTargets = const [],
    List<int>? mitmModules,
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
      mountTargets: mountTargets,
      mitmModules: mitmModules,
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
    dbFingerprintBeforeMitmOff: json['dbFingerprintBeforeMitmOff'] as String?,
    prefsTarget: json['prefsTarget'] as String?,
    mountTargets: [...?(json['mountTargets'] as List?)?.cast<int>()],
    mitmModules: (json['mitmModules'] as List?)?.cast<int>(),
    mitmUnrecorded: !json.containsKey('mitmModules'),
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
    if (dbFingerprintBeforeMitmOff != null)
      'dbFingerprintBeforeMitmOff': dbFingerprintBeforeMitmOff,
    'prefsTarget': prefsTarget,
    'mountTargets': mountTargets,
    // Left out as it was read, so a later launch still knows the format.
    if (!mitmUnrecorded) 'mitmModules': mitmModules,
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
    String? dbFingerprintBeforeMitmOff,
    String? prefsTarget,
    List<int>? mountTargets,
  }) async {
    phase = next;
    if (prefsBefore != null) this.prefsBefore = prefsBefore;
    if (dbFingerprint != null) this.dbFingerprint = dbFingerprint;
    if (dbFingerprintBeforeMitmOff != null) {
      this.dbFingerprintBeforeMitmOff = dbFingerprintBeforeMitmOff;
    }
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

  /// Sets aside a journal that cannot be read. Nothing is deleted: not its
  /// replaced files, nor an earlier one set aside, nor any other quarantine.
  /// The name is not a bare id, so no later pruning ever takes it.
  static Future<void> _quarantineUnreadable(String homeDirPath, int id) async {
    final root = join(rootOf(homeDirPath), _quarantineDirectoryName);
    await Directory(root).create(recursive: true);
    var target = Directory(join(root, '$id.unreadable'));
    for (var n = 2; await target.exists(); n++) {
      target = Directory(join(root, '$id.unreadable.$n'));
    }
    await Directory(join(rootOf(homeDirPath), '$id')).rename(target.path);
  }

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

  /// Whether [current] is the database this journal last recorded, before
  /// or after turning every module off.
  bool recorded(String current, String? committed) =>
      current == (dbFingerprint ?? committed) ||
      (dbFingerprintBeforeMitmOff != null &&
          current == dbFingerprintBeforeMitmOff);

  /// Whether the MITM consent recheck is still owed.
  bool get owesMitm => phase.index < RestorePhase.mitmDone.index;

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

  /// The journal could not be read, the database was checked and holds no
  /// commit for it, and nothing was done beyond setting it aside intact.
  unreadable,

  /// The journal could not be read, but the database holds the restore's
  /// commit: the data is restored, and whether the later steps ran is
  /// unknown. Nothing can check them without the journal, so nothing is
  /// offered beyond closing; data, backups and the set-aside journal stay.
  committedUnconfirmed,

  /// Recovery itself failed before it could tell whether anything had
  /// committed; the journal stays for the next launch.
  failed,

  /// Nothing to say beyond the MITM lines: what the safety lock did, or
  /// that every module was stopped for this launch.
  mitmOnly,
}

/// What the user can do about a [RestoreRecoveryReport].
enum RestoreFollowUp {
  none,
  nextLaunch,

  /// Left for the next launch, with nothing confirmed for it to act on.
  nextLaunchUnconfirmed,
  retryNow,
  restoreAgain,
}

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

  /// Every MITM module was turned off, since which ones the restore wrote
  /// could not be told.
  final bool mitmAllOff;

  /// Turning every module off was needed but failed.
  final bool mitmOffFailed;

  /// With [mitmOffFailed]: the journal (and its marker, if it had one) was
  /// confirmed kept for the next launch to try again. Either way no module
  /// runs for the rest of this launch.
  final bool mitmOffRetryKept;

  /// A hold could not be applied, so every module was stopped for the rest
  /// of this launch.
  final bool mitmStopped;

  /// Every module reads off, but the safety lock still stands: the next
  /// launch turns every module off again. Never said with a finished
  /// outcome.
  final bool mitmLockKept;

  /// With [mitmLockKept]: the next launch is confirmed to turn every module
  /// off again.
  final bool mitmLockKeptConfirmed;

  /// The safety lock could not be saved durably, so nothing was turned off
  /// and every module is stopped for this launch; with
  /// [mitmLockNotSavedRetryKept], the journal is confirmed kept for the
  /// next launch.
  final bool mitmLockNotSaved;

  /// For [RestoreRecoveryOutcome.failed]: the journal read back after the
  /// failure, so it is said kept and retried.
  final bool recordKept;

  /// For [RestoreRecoveryOutcome.failed]: a restore is confirmed committed,
  /// so its data may already be in place.
  final bool commitKnown;

  /// Recovery as a whole failed and every module is stopped; with
  /// [recoveryErrorRetryKept], the next launch has a confirmed basis to
  /// handle it again.
  final bool recoveryError;
  final bool recoveryErrorRetryKept;
  final bool mitmLockNotSavedRetryKept;

  const RestoreRecoveryReport(
    this.outcome, {
    this.keptFiles = const [],
    this.skippedSteps = const [],
    this.tornFiles = const [],
    this.pendingMounts = const [],
    this.followUp = RestoreFollowUp.none,
    this.mitmAllOff = false,
    this.mitmOffFailed = false,
    this.mitmOffRetryKept = false,
    this.mitmStopped = false,
    this.mitmLockKept = false,
    this.mitmLockKeptConfirmed = false,
    this.mitmLockNotSaved = false,
    this.recordKept = false,
    this.commitKnown = false,
    this.recoveryError = false,
    this.recoveryErrorRetryKept = false,
    this.mitmLockNotSavedRetryKept = false,
  });

  /// [outcome], unless it would call the restore finished: with every
  /// module turned off, or the lock still standing, it is not.
  RestoreRecoveryOutcome get _unfinished =>
      outcome == RestoreRecoveryOutcome.completed ||
          (outcome == RestoreRecoveryOutcome.incomplete && skippedSteps.isEmpty)
      ? RestoreRecoveryOutcome.pending
      : outcome;

  RestoreRecoveryReport _copy({
    RestoreRecoveryOutcome? outcome,
    bool? mitmAllOff,
    bool? mitmOffFailed,
    bool? mitmOffRetryKept,
    bool? mitmStopped,
    bool? mitmLockKept,
    bool? mitmLockKeptConfirmed,
    bool? mitmLockNotSaved,
    bool? recordKept,
    bool? commitKnown,
    bool? recoveryError,
    bool? recoveryErrorRetryKept,
    bool? mitmLockNotSavedRetryKept,
  }) => RestoreRecoveryReport(
    outcome ?? this.outcome,
    keptFiles: keptFiles,
    skippedSteps: skippedSteps,
    tornFiles: tornFiles,
    pendingMounts: pendingMounts,
    followUp: followUp,
    mitmAllOff: mitmAllOff ?? this.mitmAllOff,
    mitmOffFailed: mitmOffFailed ?? this.mitmOffFailed,
    mitmOffRetryKept: mitmOffRetryKept ?? this.mitmOffRetryKept,
    mitmStopped: mitmStopped ?? this.mitmStopped,
    mitmLockKept: mitmLockKept ?? this.mitmLockKept,
    mitmLockKeptConfirmed: mitmLockKeptConfirmed ?? this.mitmLockKeptConfirmed,
    mitmLockNotSaved: mitmLockNotSaved ?? this.mitmLockNotSaved,
    recordKept: recordKept ?? this.recordKept,
    commitKnown: commitKnown ?? this.commitKnown,
    recoveryError: recoveryError ?? this.recoveryError,
    recoveryErrorRetryKept:
        recoveryErrorRetryKept ?? this.recoveryErrorRetryKept,
    mitmLockNotSavedRetryKept:
        mitmLockNotSavedRetryKept ?? this.mitmLockNotSavedRetryKept,
  );

  /// With every module turned off the restore is never called finished:
  /// what ran before needs consent again here.
  RestoreRecoveryReport withMitmAllOff({
    bool failed = false,
    bool retryKept = false,
  }) => _copy(
    outcome: _unfinished,
    mitmAllOff: !failed,
    mitmOffFailed: failed,
    mitmOffRetryKept: failed && retryKept,
  );

  /// The safety lock's lines, said with whatever this report says; never
  /// called finished either.
  RestoreRecoveryReport withMitmLines({
    required bool allOff,
    required bool offFailed,
    required bool retryKept,
  }) => _copy(
    outcome: _unfinished,
    mitmAllOff: allOff,
    mitmOffFailed: offFailed,
    mitmOffRetryKept: offFailed && retryKept,
  );

  RestoreRecoveryReport withMitmStopped() => _copy(mitmStopped: true);

  RestoreRecoveryReport withRecoveryError(bool retryKept) => _copy(
    outcome: _unfinished,
    recoveryError: true,
    recoveryErrorRetryKept: retryKept,
  );

  /// Never called finished either.
  RestoreRecoveryReport withMitmLockNotSaved(bool retryKept) => _copy(
    outcome: _unfinished,
    mitmLockNotSaved: true,
    mitmLockNotSavedRetryKept: retryKept,
  );

  /// The same report, not called finished.
  RestoreRecoveryReport unfinished() => _copy(outcome: _unfinished);

  /// The lock still stands: never called finished.
  RestoreRecoveryReport withMitmLockKept(bool confirmed) => _copy(
    outcome: _unfinished,
    mitmLockKept: true,
    mitmLockKeptConfirmed: confirmed,
  );

  @override
  String toString() =>
      'RestoreRecoveryReport($outcome, kept: $keptFiles, '
      'skipped: $skippedSteps, torn: $tornFiles, mounts: $pendingMounts, '
      'followUp: $followUp, mitmAllOff: $mitmAllOff, '
      'mitmOffFailed: $mitmOffFailed, retryKept: $mitmOffRetryKept, '
      'stopped: $mitmStopped, lockKept: $mitmLockKept/$mitmLockKeptConfirmed, '
      'lockNotSaved: $mitmLockNotSaved/$mitmLockNotSavedRetryKept)';
}

/// The restored mount targets among [targetIds] whose record is still
/// pending, in profile order.
Future<List<RestoreMountProfile>> pendingMountProfiles(
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
      if (pending.contains(profile.id))
        RestoreMountProfile(
          profile.id,
          label: profile.realLabel,
          type: profile.type,
        ),
  ];
}

/// The labels of [targetIds] whose mount record is still pending.
Future<List<String>> pendingMountLabels(
  Database db,
  Iterable<int> targetIds,
) async => [
  for (final profile in await pendingMountProfiles(db, targetIds))
    profile.label ?? '${profile.id}',
];

/// MITM modules a committed restore wrote whose consent this device has not
/// rechecked yet. None of them runs meanwhile: the consent they carry was
/// judged against another device's files.
class RestoreMitmHold {
  /// A restore that did not record its modules holds all of them.
  final bool all;
  final Set<int> ids;

  const RestoreMitmHold({this.all = false, this.ids = const {}});

  static const none = RestoreMitmHold();

  /// One entry per restore; a null entry did not record its modules.
  factory RestoreMitmHold.of(Iterable<List<int>?> held) {
    var all = false;
    final ids = <int>{};
    for (final modules in held) {
      if (modules == null) {
        all = true;
      } else {
        ids.addAll(modules);
      }
    }
    return RestoreMitmHold(all: all, ids: ids);
  }

  bool get isEmpty => !all && ids.isEmpty;

  bool holds(int moduleId) => all || ids.contains(moduleId);

  @override
  bool operator ==(Object other) =>
      other is RestoreMitmHold &&
      other.all == all &&
      other.ids.length == ids.length &&
      other.ids.containsAll(ids);

  @override
  int get hashCode => Object.hash(all, Object.hashAllUnordered(ids));

  @override
  String toString() => 'RestoreMitmHold(all: $all, ids: $ids)';
}

/// A committed restore whose MITM step is still owed at launch.
class _OwedMitm {
  final int id;

  /// Null for a journal that could not be read: it is set aside already,
  /// and the recheck only lifts this session's hold.
  final RestoreJournal? journal;
  final List<String> torn;

  /// Set when the data changed after the commit: these steps are skipped,
  /// and the journal is set aside once the recheck has run.
  final List<RestoreStep>? skipped;

  const _OwedMitm(this.id, this.journal, {this.torn = const [], this.skipped});
}

/// A step waited on a durable lock that could not be saved.
class _LockNotDurable implements Exception {
  const _LockNotDurable();
}

/// One of the two copies of a [MitmSafetyLock].
enum MitmLockCopy { file, prefs }

/// Says, outside the database and the journals, that some module rows may
/// still carry consent this device never gave: the next launch turns every
/// module off before any runs. Kept in two places, a file beside the
/// journals and a settings key, so losing either still leaves the other.
class MitmSafetyLock {
  static const fileName = 'mitm-safety.lock';

  final Future<String> Function() _homeDirPath;
  final Preferences Function() _store;

  /// Called at each step of a write or clear; a test throws or snapshots
  /// the disk here.
  final Future<void> Function(MitmLockCopy copy, String step) _step;

  MitmSafetyLock(this._homeDirPath, this._store, this._step);

  Future<File> _file() async => File(join(await _homeDirPath(), fileName));

  /// Whether either copy is there; a copy that cannot be read counts as
  /// there, so the lock fails closed.
  Future<bool> present() async {
    var found = false;
    try {
      await _step(MitmLockCopy.file, 'read');
      if (await (await _file()).exists()) found = true;
    } catch (_) {
      found = true;
    }
    try {
      await _step(MitmLockCopy.prefs, 'read');
      if (await _store().readMitmSafetyLock() != null) found = true;
    } catch (_) {
      found = true;
    }
    return found;
  }

  /// Whether the file copy reads back now. Only the file counts as kept:
  /// the setting's store cannot be confirmed flushed to disk.
  Future<bool> fileReads() async {
    try {
      final file = await _file();
      return await file.exists() && (await file.readAsString()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Writes both copies; never throws. The file is confirmed once written,
  /// flushed, renamed into place, its directory synced and read back; the
  /// setting once saved and read back fresh from the store, which says
  /// nothing of the disk, so only [file] makes the lock durable.
  Future<({bool file, bool prefs})> write(String reason) async {
    final value = json.encode({
      'reason': reason,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    var fileSaved = false;
    var prefsSaved = false;
    try {
      final file = await _file();
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(value, flush: true);
      await _step(MitmLockCopy.file, 'written');
      await temp.rename(file.path);
      await _step(MitmLockCopy.file, 'renamed');
      syncDirectory(file.parent.path);
      if (await file.readAsString() != value) {
        throw StateError('lock file reads back otherwise');
      }
      await _step(MitmLockCopy.file, 'confirmed');
      fileSaved = true;
    } catch (error) {
      commonPrint.log('MITM lock file: $error', logLevel: LogLevel.error);
    }
    try {
      await _step(MitmLockCopy.prefs, 'writing');
      if (!await _store().writeMitmSafetyLock(value)) {
        throw StateError('lock setting not saved');
      }
      await _step(MitmLockCopy.prefs, 'confirmed');
      prefsSaved = true;
    } catch (error) {
      commonPrint.log('MITM lock setting: $error', logLevel: LogLevel.error);
    }
    return (file: fileSaved, prefs: prefsSaved);
  }

  /// Removes the file, then the setting. True once both read back gone.
  Future<bool> clear() async {
    var cleared = true;
    try {
      await _step(MitmLockCopy.file, 'clearing');
      final file = await _file();
      if (await file.exists()) {
        await file.delete();
        syncDirectory(file.parent.path);
      }
      if (await file.exists()) throw StateError('lock file still there');
      await _step(MitmLockCopy.file, 'cleared');
    } catch (error) {
      cleared = false;
      commonPrint.log('MITM lock file clear: $error', logLevel: LogLevel.error);
    }
    try {
      await _step(MitmLockCopy.prefs, 'clearing');
      if (!await _store().clearMitmSafetyLock()) {
        throw StateError('lock setting still there');
      }
      await _step(MitmLockCopy.prefs, 'cleared');
    } catch (error) {
      cleared = false;
      commonPrint.log(
        'MITM lock setting clear: $error',
        logLevel: LogLevel.error,
      );
    }
    return cleared;
  }
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

  final _awaitingMitm = <_OwedMitm>[];
  final reports = <RestoreRecoveryReport>[];

  /// Old-format journals whose recovery turned every module off.
  final _mitmAllOff = <int>{};

  /// Old-format journals whose modules could not be turned off.
  final _mitmOffFailed = <int>{};

  /// Of [_mitmOffFailed]: whether the journal had a commit marker then.
  final _mitmOffMarked = <int, bool>{};

  /// Of [_mitmOffFailed]: those whose journal was confirmed kept for a
  /// retry.
  final _mitmOffRetryKept = <int>{};

  /// Whether the next launch is confirmed to try again: the lock reads
  /// back, or the journal of [id] is still there in the old format, with
  /// its marker if it had one.
  Future<bool> _confirmOffRetry(int id, RestoreJournal journal) async {
    if (await _lockRetryConfirmed()) return true;
    try {
      final file = File(join(journal.dirPath, _journalFileName));
      if (!await file.exists()) return false;
      final map = json.decode(await file.readAsString()) as Map;
      if (map['id'] != id || map.containsKey('mitmModules')) return false;
      if (_mitmOffMarked[id] ?? false) {
        if (await _db().restoreCommit(id) == null) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Called inside the transaction that turns every module off (false),
  /// and once it committed (true); a test throws here to crash.
  @visibleForTesting
  Future<void> Function(bool committed)? onMitmOff;

  void _report(int id, RestoreRecoveryReport report) => reports.add(
    _mitmOffFailed.contains(id)
        ? report.withMitmAllOff(
            failed: true,
            retryKept: _mitmOffRetryKept.contains(id),
          )
        : _mitmAllOff.contains(id)
        ? report.withMitmAllOff()
        : report,
  );

  bool get needsMitm => _awaitingMitm.isNotEmpty;

  /// Called at each step of writing or clearing the lock; a test throws or
  /// snapshots the disk here.
  @visibleForTesting
  Future<void> Function(MitmLockCopy copy, String step)? onLockStep;

  late final _lock = MitmSafetyLock(
    _homeDirPath,
    _preferences,
    (copy, step) async => onLockStep?.call(copy, step),
  );

  /// The hold kept while the lock stands and no turn-off has been verified
  /// since it was last written.
  static const _lockHold = -2;

  /// The lock may be on disk: found at launch, or written here.
  bool _lockActive = false;

  /// The file copy was written durably this launch: only then may a step
  /// that could lose a journal go ahead.
  bool _lockDurable = false;

  /// The file copy was there at launch, so it outlived one.
  bool _lockFileAtLaunch = false;

  /// The lock still stands after a verified turn-off: the next launch turns
  /// every module off again.
  bool _lockKeptAfterOff = false;

  /// With [_lockKeptAfterOff]: the file copy still reads, so the next
  /// launch is confirmed to turn every module off again.
  bool _lockKeptConfirmed = false;

  /// Lock writes started, and [_lockSeq] when the last verified turn-off
  /// began: the lock is cleared only after a turn-off that followed every
  /// write.
  int _lockSeq = 0;
  int _offVerifiedSeq = -1;
  Future<void> _lockQueue = Future.value();

  /// What [_settleLock] did, said once with the reports.
  bool _lockTurnedOff = false;
  bool _lockOffFailed = false;
  bool _lockOffRetryKept = false;
  bool _lockSaid = false;

  /// A step that waits on a durable lock found it not durable: nothing
  /// that could lose the journal was done, nothing was turned off, and
  /// every module is stopped.
  bool _lockGateFailed = false;
  bool _lockGateRetryKept = false;
  bool _lockGateSaid = false;

  /// Whether the next launch has something confirmed to act on: the lock
  /// file known durable, or any journal, read now. False on any error.
  Future<bool> _nextLaunchBasisConfirmed() async {
    if (await _lockRetryConfirmed()) return true;
    try {
      return (await RestoreJournal.pending(await _homeDirPath())).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Recovery as a whole failed: every module is stopped and the lock
  /// written; the report says so, and says the next launch handles it only
  /// if there is a confirmed basis for that.
  Future<void> failAtLaunch(Object error) async {
    await stopMitmModules(error, said: false);
    reports.add(
      const RestoreRecoveryReport(
        RestoreRecoveryOutcome.mitmOnly,
      ).withRecoveryError(await _nextLaunchBasisConfirmed()),
    );
  }

  /// Whether a restore is confirmed committed and not finalized; false
  /// when that cannot be read.
  Future<bool> _anyCommitKnown() async {
    try {
      return await _db().hasRestoreCommit();
    } catch (_) {
      return false;
    }
  }

  /// Whether the journal [id] (any journal, without one) reads back as
  /// pending now, after a failure: only then is it said kept for a retry.
  Future<bool> _recordsReadBack([int? id]) async {
    try {
      final found = await RestoreJournal.pending(await _homeDirPath());
      return id == null ? found.isNotEmpty : found.any((e) => e.$1 == id);
    } catch (_) {
      return false;
    }
  }

  /// Whether a journal the lock stands in for is confirmed still pending,
  /// for the next launch to handle again.
  Future<bool> _evidenceConfirmed() async {
    try {
      final found = await RestoreJournal.pending(await _homeDirPath());
      return found.any(
        (entry) =>
            entry.$2 == null ||
            (entry.$2!.mitmUnrecorded && entry.$2!.mitmModules == null),
      );
    } catch (_) {
      return false;
    }
  }

  /// Writes the lock and holds every module until a turn-off verified after
  /// it. True once the file copy is durable; otherwise every module is
  /// stopped for this launch, the setting copy left only as a signal for
  /// later launches. Never throws.
  Future<bool> _writeLock(String reason, {bool gate = false}) {
    _lockActive = true;
    _lockSeq++;
    _hold(_lockHold, null, persist: false);
    final write = _lockQueue.then((_) => _lock.write(reason));
    _lockQueue = write.then((_) {});
    return write.then((saved) async {
      if (saved.file) {
        _lockDurable = true;
        return true;
      }
      // A file copy already durable still reads: the lock stands whatever
      // this write's reason.
      if (await _lockRetryConfirmed()) return true;
      // Said by its own line, when a step waited on it.
      await stopMitmModules(
        'safety lock not durable ($reason)',
        persist: false,
        said: false,
      );
      if (gate) _lockGateFailed = true;
      return false;
    });
  }

  /// Whether the next launch is confirmed to turn every module off: a file
  /// copy known durable still reads.
  Future<bool> _lockRetryConfirmed() async =>
      (_lockDurable || _lockFileAtLaunch) && await _lock.fileReads();

  /// Every module row reads off and declined.
  Future<void> _verifyAllOff(Database db) async {
    for (final row in await db.mitmModulesDao.query().get()) {
      if (row.enabled || row.accepted != false) {
        throw StateError('module ${row.id} still on after turning off');
      }
    }
  }

  /// A journal still pending that the lock stands in for: an old-format one
  /// or one that cannot be read. Unknown counts as pending.
  Future<bool> _lockEvidencePending() async {
    try {
      final found = await RestoreJournal.pending(await _homeDirPath());
      return found.any(
        (entry) =>
            entry.$2 == null ||
            (entry.$2!.mitmUnrecorded && entry.$2!.mitmModules == null),
      );
    } catch (_) {
      return true;
    }
  }

  /// With the lock standing: turns every module off unless a turn-off since
  /// the last write was verified, then lifts the lock's hold, and clears
  /// the lock once no journal it stands in for is left. Order: rows read off,
  /// journal gone, then the lock; a crash anywhere leaves a journal or a
  /// lock or both.
  Future<void> _settleLock() async {
    if (!_lockActive) return;
    await _lockQueue;
    // Nothing more without a durable lock: the journal is the evidence.
    if (_lockGateFailed) {
      _lockGateRetryKept = await _evidenceConfirmed();
      return;
    }
    // A journal's own turn-off failed this launch: its report says so, and
    // the next launch tries again.
    if (_mitmOffFailed.isNotEmpty) return;
    final db = _db();
    if (_offVerifiedSeq < _lockSeq) {
      final seq = _lockSeq;
      try {
        await db.transaction(() async {
          await db.mitmModulesDao.turnAllOff();
          await _verifyAllOff(db);
          await onMitmOff?.call(false);
        });
      } catch (error) {
        commonPrint.log(
          'MITM lock turn-off failed: $error',
          logLevel: LogLevel.error,
        );
        _lockOffFailed = true;
        _lockOffRetryKept = await _lockRetryConfirmed();
        return;
      }
      _offVerifiedSeq = seq;
      _lockTurnedOff = true;
      await onMitmOff?.call(true);
    }
    releaseMitm(_lockHold);
    _lockKeptAfterOff = true;
    // Kept for a journal still pending: the next launch is confirmed to
    // turn modules off only if the lock file or that journal reads now.
    _lockKeptConfirmed =
        await _lockRetryConfirmed() || await _evidenceConfirmed();
    if (await _lockEvidencePending()) return;
    // Cleared only once neither copy reads, nor fails to read, as there.
    if (await _lock.clear() && !await _lock.present()) {
      _lockActive = false;
      _lockKeptAfterOff = false;
      _lockDurable = false;
      _lockFileAtLaunch = false;
    } else {
      _lockKeptConfirmed = await _lock.fileReads();
    }
  }

  final _mitmHolds = <int, List<int>?>{};

  /// What no MITM module may run under: every committed restore, in this
  /// session or one before, whose consent recheck has not completed.
  final mitmHold = ValueNotifier<RestoreMitmHold>(RestoreMitmHold.none);

  /// Set once a hold could not be confirmed in place: no module runs for
  /// the rest of this launch, whatever [mitmHold] says. Every place that
  /// runs a module reads this directly, not only through [mitmHold].
  bool get mitmStopped => _mitmStopped;
  bool _mitmStopped = false;

  /// Whether a report has said [mitmStopped] yet.
  bool _mitmStopSaid = false;

  /// A stop that its own line should say: not one a lock that could not be
  /// saved explains.
  bool _mitmStopSay = false;

  /// What no module may run under right now.
  RestoreMitmHold get effectiveMitmHold =>
      _mitmStopped ? const RestoreMitmHold(all: true) : mitmHold.value;

  /// Called first in [holdMitm]; a test throws here to fail the hold.
  @visibleForTesting
  void Function()? onHoldMitm;

  /// Holds the [modules] restore [journalId] writes (all, when null) until
  /// [releaseMitm]. Set before the commit, so nothing runs in between. Never
  /// throws: a hold that cannot be confirmed stops every module instead.
  void holdMitm(int journalId, List<int>? modules) =>
      _hold(journalId, modules, persist: true);

  void _hold(int journalId, List<int>? modules, {required bool persist}) {
    try {
      onHoldMitm?.call();
      _mitmHolds[journalId] = modules;
      mitmHold.value = RestoreMitmHold.of(_mitmHolds.values);
      final hold = mitmHold.value;
      if (modules == null ? !hold.all : !modules.every(hold.holds)) {
        throw StateError('hold not in effect: $hold');
      }
    } catch (error) {
      unawaited(stopMitmModules(error, persist: persist));
    }
  }

  /// Stops every module for the rest of this launch, for when what must not
  /// run cannot be held, or cannot be known; with [persist], also writes
  /// the lock, so the next launch turns every module off first.
  Future<void> stopMitmModules(
    Object reason, {
    bool persist = true,
    bool said = true,
  }) async {
    commonPrint.log(
      'MITM modules stopped for this launch: $reason',
      logLevel: LogLevel.error,
    );
    _mitmStopped = true;
    if (said) _mitmStopSay = true;
    try {
      mitmHold.value = const RestoreMitmHold(all: true);
    } catch (_) {
      // Every module reads [mitmStopped] itself as well.
    }
    if (persist) await _writeLock('stopped: $reason');
  }

  /// Only once the recheck for [journalId] has completed, or its rows were
  /// rolled back.
  void releaseMitm(int journalId) {
    if (!_mitmHolds.containsKey(journalId)) return;
    _mitmHolds.remove(journalId);
    mitmHold.value = RestoreMitmHold.of(_mitmHolds.values);
  }

  /// Each test starts from a launch with nothing held or stopped.
  @visibleForTesting
  void clearMitmHolds() {
    _mitmHolds.clear();
    _mitmStopped = false;
    _mitmStopSaid = false;
    _mitmStopSay = false;
    _lockGateFailed = false;
    _lockGateRetryKept = false;
    _lockGateSaid = false;
    onHoldMitm = null;
    onMitmOff = null;
    _awaitingMitm.clear();
    reports.clear();
    _mitmAllOff.clear();
    _mitmOffFailed.clear();
    _mitmOffMarked.clear();
    _mitmOffRetryKept.clear();
    onLockStep = null;
    _lockActive = false;
    _lockDurable = false;
    _lockFileAtLaunch = false;
    _lockKeptAfterOff = false;
    _lockKeptConfirmed = false;
    _lockSeq = 0;
    _offVerifiedSeq = -1;
    _lockQueue = Future.value();
    _lockTurnedOff = false;
    _lockOffFailed = false;
    _lockOffRetryKept = false;
    _lockSaid = false;
    mitmHold.value = RestoreMitmHold.none;
  }

  Future<void> run() async {
    // Before anything reads a module: a lock from an earlier launch holds
    // every module until a turn-off is verified, journal or not.
    if (await _lock.present()) {
      _lockActive = true;
      _lockFileAtLaunch = await _lock.fileReads();
      holdMitm(_lockHold, null);
    }
    await _runJournals();
    await _settleLock();
  }

  Future<void> _runJournals() async {
    final List<(int, RestoreJournal?)> found;
    try {
      found = await RestoreJournal.pending(await _homeDirPath());
    } catch (error) {
      commonPrint.log(
        'restore journals unreadable: $error',
        logLevel: LogLevel.error,
      );
      // Whether a restore committed is unknown: no module runs until the
      // recheck, which needs no journal, has.
      holdMitm(-1, null);
      // Rows an older build wrote on may be among them: every module is
      // turned off before the lock goes, whatever the recheck finds.
      await _writeLock('journals unreadable', gate: true);
      _awaitingMitm.add(const _OwedMitm(-1, null));
      reports.add(
        RestoreRecoveryReport(
          RestoreRecoveryOutcome.failed,
          recordKept: await _recordsReadBack(),
          commitKnown: await _anyCommitKnown(),
        ),
      );
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
        if (_mitmOffFailed.contains(id)) {
          // Applied again before anything else here, whatever the journal
          // says now.
          holdMitm(id, null);
        }
        final report = await _failure(id, journal);
        if (_mitmOffFailed.contains(id) &&
            journal != null &&
            await _confirmOffRetry(id, journal)) {
          _mitmOffRetryKept.add(id);
        }
        _report(id, report);
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
    // The journal stays for the next launch, and until then so does the
    // hold on whatever it may have restored.
    if (journal?.owesMitm ?? committed != null) {
      holdMitm(id, journal?.mitmModules);
    }
    if (committed == null) {
      return RestoreRecoveryReport(
        RestoreRecoveryOutcome.failed,
        recordKept: await _recordsReadBack(id),
      );
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
      if (committed == null) {
        await RestoreJournal._quarantineUnreadable(await _homeDirPath(), id);
        _report(
          id,
          const RestoreRecoveryReport(RestoreRecoveryOutcome.unreadable),
        );
        return;
      }
      // Which steps ran is unknown; none can be redone or verified without
      // the record, so no step is claimed done or owed and no action is
      // offered. The consent recheck needs none of it, so that one still
      // runs; it never changes this report. The journal and marker stay
      // until it passed, so a failed one is retried at the next launch.
      holdMitm(id, null);
      // Which rows it wrote, and whether on, is unknown: every module is
      // turned off before the lock goes. Until a copy is confirmed the
      // journal is not set aside.
      await _writeLock('journal $id unreadable', gate: true);
      _awaitingMitm.add(_OwedMitm(id, null));
      _report(
        id,
        const RestoreRecoveryReport(
          RestoreRecoveryOutcome.committedUnconfirmed,
        ),
      );
      return;
    }
    // A journal from a development build before the module list was kept:
    // which modules it wrote, and whether they were written turned on, is
    // unknown, so every module is turned off until consented to here.
    // Skipped only when the rows certainly never committed. Idempotent, and
    // done before the journal goes, so a crash in between redoes it.
    if (journal.mitmUnrecorded &&
        journal.mitmModules == null &&
        (committed != null ||
            journal.phase.index > RestorePhase.published.index)) {
      // Still to be checked for other writers below: this write is not one,
      // so the recorded fingerprint moves with it when it matched before.
      final followsCommit =
          committed != null &&
          journal.phase.index < RestorePhase.configSaved.index &&
          journal.recorded(await db.restoreFingerprint(), committed);
      // Held, or else stopped, before trying: whether turning off works or
      // the journal survives, nothing runs on the old consent meanwhile.
      holdMitm(id, null);
      var seq = 0;
      try {
        // The lock outlives the journal: confirmed before anything that
        // could lose the journal, or nothing more is done here.
        // Once a lock could not be saved, no module is turned off this
        // launch, so the report saying none was stays true.
        if (_lockGateFailed ||
            !await _writeLock('old-format journal $id', gate: true)) {
          throw const _LockNotDurable();
        }
        // Every lock write so far, a stop's included, came before this.
        seq = _lockSeq;
        // The new fingerprint is recorded before this commits, keeping the
        // old one too, so a crash at any point leaves a recorded database.
        await db.transaction(() async {
          final before = await db.restoreFingerprint();
          await db.mitmModulesDao.turnAllOff();
          // Said only once every row reads off and declined.
          await _verifyAllOff(db);
          if (followsCommit) {
            await journal.advance(
              journal.phase,
              dbFingerprint: await db.restoreFingerprint(),
              dbFingerprintBeforeMitmOff: before,
            );
          }
          await onMitmOff?.call(false);
        });
      } catch (error) {
        // Every module stays held (or stopped) for this run; the journal
        // stays, unless it went too, for the next launch to try again.
        holdMitm(id, null);
        // Without a durable lock no turn-off was tried: its own line says
        // so, not that turning off failed.
        if (error is! _LockNotDurable) {
          _mitmOffFailed.add(id);
          _mitmOffMarked[id] = committed != null;
        }
        rethrow;
      }
      // Every row reads off and declined: the hold is no longer what keeps
      // them from running. Whatever this journal still owes holds again.
      if (_offVerifiedSeq < seq) _offVerifiedSeq = seq;
      releaseMitm(id);
      _mitmAllOff.add(id);
      await onMitmOff?.call(true);
    }
    if (committed == null) {
      if (journal.phase.index <= RestorePhase.published.index) {
        final kept = await journal.rollBack();
        _report(
          id,
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
        // Nothing else to say, except that every module was turned off.
        if (_mitmAllOff.contains(id)) {
          _report(
            id,
            const RestoreRecoveryReport(RestoreRecoveryOutcome.completed),
          );
        }
        return;
      }
      // The rows committed once but their marker is gone (the database was
      // cleared or replaced since): nothing here can be trusted to apply.
      await journal.quarantine();
      _report(
        id,
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
      _report(id, await _finished(db, journal, const []));
      return;
    }
    final torn = await journal.tornFiles();
    // Only the consent recheck is left: it rereads the module files and
    // overwrites nothing anyone else wrote, so later writes don't stop it.
    if (journal.phase.index < RestorePhase.configSaved.index) {
      final store = _preferences();
      final dbUnchanged = journal.recorded(
        await db.restoreFingerprint(),
        committed,
      );
      final prefs = await storedConfigHash(store);
      final settingsSaved =
          journal.config == null ||
          (prefs != null &&
              (prefs == journal.prefsTarget ||
                  prefs == configHash(Config.fromJson(journal.config!))));
      final prefsUnchanged = settingsSaved || prefs == journal.prefsBefore;
      if (!dbUnchanged || !prefsUnchanged) {
        // Someone else ran on this data after the commit; rolling forward
        // would overwrite what they did. The recheck still runs first.
        holdMitm(id, journal.mitmModules);
        _awaitingMitm.add(
          _OwedMitm(id, journal, skipped: journal.remainingSteps()),
        );
        return;
      }
      if (journal.phase.index < RestorePhase.cachesCleared.index) {
        await journal.clearCaches(db);
        await journal.advance(RestorePhase.cachesCleared);
      }
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
    if (journal.owesMitm) {
      holdMitm(id, journal.mitmModules);
      _awaitingMitm.add(_OwedMitm(id, journal, torn: torn));
      return;
    }
    await journal.finish(db);
    _report(id, await _finished(db, journal, torn));
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
      // A failed recheck is retried at the next launch; torn files are not.
      followUp: torn.isEmpty
          ? RestoreFollowUp.nextLaunch
          : RestoreFollowUp.restoreAgain,
    );
  }

  /// Runs the MITM step [run] left, then removes the journal and marker. A
  /// failed recheck keeps both, and the hold, for the next launch to retry.
  Future<void> finish(Future<void> Function() mitm) async {
    final db = _db();
    for (final item in [..._awaitingMitm]) {
      _awaitingMitm.remove(item);
      final journal = item.journal;
      var checked = false;
      try {
        await mitm();
        checked = true;
        if (journal != null && item.skipped == null) {
          await journal.advance(RestorePhase.mitmDone);
        }
      } catch (error) {
        commonPrint.log(
          'restore recovery ${item.id} mitm step failed: $error',
          logLevel: LogLevel.warning,
        );
      }
      // An unreadable journal stays, and so does its hold, until the lock
      // standing in for it is durable.
      if (checked && (journal != null || _lockDurable)) releaseMitm(item.id);
      if (journal == null) {
        // An unreadable journal whose restore committed: set aside only
        // once its recheck passed and the lock is confirmed; the lock goes
        // only after every module reads off.
        if (checked && _lockDurable && item.id >= 0) {
          await RestoreJournal._quarantineUnreadable(
            await _homeDirPath(),
            item.id,
          );
          await db.clearRestoreCommit(item.id);
        }
        continue;
      }
      if (item.skipped case final skipped?) {
        if (checked) {
          await db.clearRestoreCommit(item.id);
          await journal.quarantine();
        }
        final left = [
          for (final step in skipped)
            if (step != RestoreStep.mitm || !checked) step,
        ];
        final mounts = await pendingMountLabels(db, journal.mountTargets);
        // Data changed since, but no step ended up skipped: nothing to
        // say about skipping.
        _report(
          item.id,
          left.isEmpty
              ? RestoreRecoveryReport(
                  RestoreRecoveryOutcome.completed,
                  pendingMounts: mounts,
                )
              : RestoreRecoveryReport(
                  RestoreRecoveryOutcome.incomplete,
                  skippedSteps: left,
                  pendingMounts: mounts,
                  followUp: RestoreFollowUp.restoreAgain,
                ),
        );
        continue;
      }
      if (checked) {
        try {
          await journal.finish(db);
        } catch (error) {
          commonPrint.log(
            'restore recovery ${journal.id} finalize failed: $error',
            logLevel: LogLevel.warning,
          );
        }
      }
      _report(
        item.id,
        await _finished(
          db,
          journal,
          item.torn,
          failedSteps: checked ? const [] : const [RestoreStep.mitm],
        ),
      );
    }
    await _settleLock();
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
      final report = RestoreRecoveryReport(
        RestoreRecoveryOutcome.pending,
        skippedSteps: const [RestoreStep.mitm],
        followUp: await _nextLaunchBasisConfirmed()
            ? RestoreFollowUp.nextLaunch
            : RestoreFollowUp.nextLaunchUnconfirmed,
      );
      reports.add(
        _mitmOffFailed.isNotEmpty
            ? report.withMitmAllOff(
                failed: true,
                retryKept: _mitmOffRetryKept.containsAll(_mitmOffFailed),
              )
            : _mitmAllOff.isNotEmpty
            ? report.withMitmAllOff()
            : report,
      );
    }
    startBackgroundWork();
    for (final report in takeReports()) {
      await show(report);
    }
  }

  /// Reports are shown once. What the lock did, and a stop, are said once,
  /// with the first of them, unless a report already says it.
  List<RestoreRecoveryReport> takeReports() {
    final taken = [...reports];
    reports.clear();
    void attach(RestoreRecoveryReport Function(RestoreRecoveryReport) add) {
      taken.isEmpty
          ? taken.add(
              add(const RestoreRecoveryReport(RestoreRecoveryOutcome.mitmOnly)),
            )
          : taken[0] = add(taken[0]);
    }

    if ((_lockTurnedOff || _lockOffFailed) && !_lockSaid) {
      _lockSaid = true;
      if (!taken.any((r) => r.mitmAllOff || r.mitmOffFailed)) {
        attach(
          (report) => report.withMitmLines(
            allOff: !_lockOffFailed,
            offFailed: _lockOffFailed,
            retryKept: _lockOffRetryKept,
          ),
        );
      }
    }
    if (_lockGateFailed && !_lockGateSaid) {
      _lockGateSaid = true;
      attach((report) => report.withMitmLockNotSaved(_lockGateRetryKept));
    }
    if (_mitmStopSay && !_mitmStopSaid) {
      _mitmStopSaid = true;
      attach((report) => report.withMitmStopped());
    }
    // Said once, with the first report; none of them is called finished
    // while the lock stands.
    if (_lockActive && _lockKeptAfterOff && !_lockOffFailed) {
      _lockKeptAfterOff = false;
      attach((report) => report.withMitmLockKept(_lockKeptConfirmed));
    }
    // While the lock stands, for whatever reason, no report is called
    // finished.
    if (_lockActive) {
      for (var i = 0; i < taken.length; i++) {
        taken[i] = taken[i].unfinished();
      }
    }
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
      RestoreFollowUp.nextLaunchUnconfirmed =>
        l10n.restoreActionNextLaunchUnconfirmed,
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
    // Said only with the steps it skipped, right after it.
    RestoreRecoveryOutcome.incomplete when report.skippedSteps.isNotEmpty => [
      l10n.restoreDataChangedSkipped,
      l10n.restoreSkippedSteps(steps()),
    ],
    RestoreRecoveryOutcome.incomplete => [l10n.restoreRecoveryCompleted],
    RestoreRecoveryOutcome.unreadable => [l10n.restoreRecoveryUnreadable],
    RestoreRecoveryOutcome.committedUnconfirmed => [
      l10n.restoreResultCommitKnown,
      l10n.restoreResultUnknownItems,
    ],
    RestoreRecoveryOutcome.failed => [
      report.recordKept
          ? l10n.restoreRecoveryFailed
          : l10n.restoreRecoveryFailedUnconfirmed,
      if (report.commitKnown) l10n.restoreResultCommitKnown,
    ],
    RestoreRecoveryOutcome.mitmOnly => const <String>[],
  };
  return [
    ...lines,
    if (report.recoveryError)
      report.recoveryErrorRetryKept
          ? l10n.restoreRecoveryCheckFailed
          : l10n.restoreRecoveryCheckFailedNoRetry,
    if (report.mitmAllOff) l10n.restoreRecoveryMitmAllOff,
    if (report.mitmOffFailed)
      report.mitmOffRetryKept
          ? l10n.restoreRecoveryMitmOffFailed
          : l10n.restoreRecoveryMitmOffFailedNoRetry,
    if (report.mitmLockNotSaved)
      report.mitmLockNotSavedRetryKept
          ? l10n.restoreRecoveryMitmLockNotSaved
          : l10n.restoreRecoveryMitmLockNotSavedNoRetry,
    if (report.mitmStopped) l10n.restoreRecoveryMitmStopped,
    if (report.mitmLockKept)
      report.mitmLockKeptConfirmed
          ? l10n.restoreRecoveryMitmLockKept
          : l10n.restoreRecoveryMitmLockKeptUnconfirmed,
    if (report.pendingMounts.isNotEmpty)
      l10n.restorePendingMounts(report.pendingMounts.join(separator)),
    if (restoreFollowUpText(report.followUp, l10n) case final text
        when text.isNotEmpty)
      text,
  ].join('\n');
}

final restoreRecovery = RestoreRecovery();

/// The launch-time recovery, before any provider exists. If it fails as a
/// whole, whether a restore left modules on another device's consent is
/// unknown: every module is stopped, and the lock written for the next
/// launch.
Future<void> recoverAtLaunch([RestoreRecovery? recovery]) async {
  final target = recovery ?? restoreRecovery;
  try {
    await target.run();
  } catch (error) {
    commonPrint.log(
      'restore recovery failed: $error',
      logLevel: LogLevel.error,
    );
    await target.failAtLaunch(error);
  }
}
