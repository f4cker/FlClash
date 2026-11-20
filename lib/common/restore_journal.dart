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

  /// Every MITM module was turned off, since which ones the restore wrote
  /// could not be told.
  final bool mitmAllOff;

  /// Turning every module off was needed but failed: all stay held for
  /// this run, and the next launch tries again.
  final bool mitmOffFailed;

  const RestoreRecoveryReport(
    this.outcome, {
    this.keptFiles = const [],
    this.skippedSteps = const [],
    this.tornFiles = const [],
    this.pendingMounts = const [],
    this.followUp = RestoreFollowUp.none,
    this.mitmAllOff = false,
    this.mitmOffFailed = false,
  });

  /// With every module turned off the restore is never called finished:
  /// what ran before needs consent again here.
  RestoreRecoveryReport withMitmAllOff({bool failed = false}) {
    final finished =
        outcome == RestoreRecoveryOutcome.completed ||
        (outcome == RestoreRecoveryOutcome.incomplete && skippedSteps.isEmpty);
    return RestoreRecoveryReport(
      finished ? RestoreRecoveryOutcome.pending : outcome,
      keptFiles: keptFiles,
      skippedSteps: skippedSteps,
      tornFiles: tornFiles,
      pendingMounts: pendingMounts,
      followUp: followUp,
      mitmAllOff: !failed,
      mitmOffFailed: failed,
    );
  }

  @override
  String toString() =>
      'RestoreRecoveryReport($outcome, kept: $keptFiles, '
      'skipped: $skippedSteps, torn: $tornFiles, mounts: $pendingMounts, '
      'followUp: $followUp, mitmAllOff: $mitmAllOff, '
      'mitmOffFailed: $mitmOffFailed)';
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

  void _report(int id, RestoreRecoveryReport report) => reports.add(
    _mitmOffFailed.contains(id)
        ? report.withMitmAllOff(failed: true)
        : _mitmAllOff.contains(id)
        ? report.withMitmAllOff()
        : report,
  );

  bool get needsMitm => _awaitingMitm.isNotEmpty;

  final _mitmHolds = <int, List<int>?>{};

  /// What no MITM module may run under: every committed restore, in this
  /// session or one before, whose consent recheck has not completed.
  final mitmHold = ValueNotifier<RestoreMitmHold>(RestoreMitmHold.none);

  /// Holds the [modules] restore [journalId] writes (all, when null) until
  /// [releaseMitm]. Set before the commit, so nothing runs in between.
  void holdMitm(int journalId, List<int>? modules) {
    _mitmHolds[journalId] = modules;
    mitmHold.value = RestoreMitmHold.of(_mitmHolds.values);
  }

  /// Only once the recheck for [journalId] has completed, or its rows were
  /// rolled back.
  void releaseMitm(int journalId) {
    if (!_mitmHolds.containsKey(journalId)) return;
    _mitmHolds.remove(journalId);
    mitmHold.value = RestoreMitmHold.of(_mitmHolds.values);
  }

  /// Each test starts from a launch with nothing held.
  @visibleForTesting
  void clearMitmHolds() {
    _mitmHolds.clear();
    mitmHold.value = RestoreMitmHold.none;
  }

  Future<void> run() async {
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
      _awaitingMitm.add(const _OwedMitm(-1, null));
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
        _report(id, await _failure(id, journal));
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
          await db.restoreFingerprint() == (journal.dbFingerprint ?? committed);
      try {
        await db.mitmModulesDao.turnAllOff();
        // Said only once every row reads off and declined.
        for (final row in await db.mitmModulesDao.query().get()) {
          if (row.enabled || row.accepted != false) {
            throw StateError('module ${row.id} still on after turning off');
          }
        }
      } catch (_) {
        // Every module stays held for this run; the journal stays, so the
        // next launch tries again.
        holdMitm(id, null);
        _mitmOffFailed.add(id);
        rethrow;
      }
      _mitmAllOff.add(id);
      if (followsCommit) {
        await journal.advance(
          journal.phase,
          dbFingerprint: await db.restoreFingerprint(),
        );
      }
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
      final expected = journal.dbFingerprint ?? committed;
      final dbUnchanged = await db.restoreFingerprint() == expected;
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
      if (checked) releaseMitm(item.id);
      if (journal == null) {
        // An unreadable journal whose restore committed: set aside only
        // once its recheck passed.
        if (checked && item.id >= 0) {
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
      const report = RestoreRecoveryReport(
        RestoreRecoveryOutcome.pending,
        skippedSteps: [RestoreStep.mitm],
        followUp: RestoreFollowUp.nextLaunch,
      );
      reports.add(
        _mitmOffFailed.isNotEmpty
            ? report.withMitmAllOff(failed: true)
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
    RestoreRecoveryOutcome.failed => [l10n.restoreRecoveryFailed],
  };
  return [
    ...lines,
    if (report.mitmAllOff) l10n.restoreRecoveryMitmAllOff,
    if (report.mitmOffFailed) l10n.restoreRecoveryMitmOffFailed,
    if (report.pendingMounts.isNotEmpty)
      l10n.restorePendingMounts(report.pendingMounts.join(separator)),
    if (restoreFollowUpText(report.followUp, l10n) case final text
        when text.isNotEmpty)
      text,
  ].join('\n');
}

final restoreRecovery = RestoreRecovery();
