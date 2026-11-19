import 'dart:io';
import 'dart:math';

const _replaceAttempts = 10;
const _replaceRetryDelay = Duration(milliseconds: 50);

final _tempRandom = Random.secure();

/// A sibling of [path] no other write, in this process or another, picks:
/// `<path>.flash-<pid>-<8 hex>.tmp`. The `flash-` marker keeps it apart from
/// temporaries other programs make in the same directories, such as the
/// Core's `os.CreateTemp` names (`<name>.<digits>.tmp`).
String uniqueTempPath(String path) {
  final suffix = _tempRandom.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
  return '$path.flash-$pid-$suffix.tmp';
}

/// Matches what [uniqueTempPath] appends, and the `<pid>.tmp` of older builds,
/// so a clean can tell which file a leftover temporary belonged to.
final atomicTempSuffix = RegExp(r'\.(flash-\d+-[0-9a-f]{8}|\d+)\.tmp$');

/// Only the names [uniqueTempPath] makes, with the pid of the writer.
final _ownTempSuffix = RegExp(r'\.flash-(\d+)-[0-9a-f]{8}\.tmp$');

/// How old a temporary has to be before a sweep takes it for a leftover of a
/// write that was cut short; no write runs anywhere near this long.
const staleAtomicTempAge = Duration(hours: 1);

final _sweeps = <String, Future<void>>{};

/// Deletes the temporaries atomic writes left in [directory] (a crash or a
/// kill between write and rename) once they are older than [olderThan].
/// Only names [uniqueTempPath] makes are touched, and never one of this
/// process, whose writes may still be running. Failures are ignored: a
/// leftover only takes space.
Future<void> sweepStaleAtomicTemps(
  String directory, {
  Duration olderThan = staleAtomicTempAge,
}) async {
  final cutoff = DateTime.now().subtract(olderThan);
  try {
    await for (final entity in Directory(directory).list(followLinks: false)) {
      final writer = _ownTempSuffix.firstMatch(entity.path)?.group(1);
      if (entity is! File || writer == null || writer == '$pid') {
        continue;
      }
      try {
        if ((await entity.lastModified()).isBefore(cutoff)) {
          await entity.delete();
        }
      } on FileSystemException {
        // Gone already, or not ours to delete.
      }
    }
  } on FileSystemException {
    // No directory yet: nothing was left in it.
  }
}

/// [sweepStaleAtomicTemps] once per directory and process. Every atomic
/// write there waits for it before making its temporary, so no sweep runs
/// beside a write of this process.
Future<void> _sweepOnce(String directory) =>
    _sweeps.putIfAbsent(directory, () => sweepStaleAtomicTemps(directory));

/// Whether a failed rename's [errorCode] says the target is busy, held open
/// by someone else, rather than a lasting failure.
///
/// On Windows an open target refuses replacement with a sharing or lock
/// violation, and with ERROR_ACCESS_DENIED while it is open without
/// FILE_SHARE_DELETE or pending deletion. Elsewhere only EBUSY qualifies.
bool isHeldOpenError(int? errorCode, {bool? windows}) {
  if (errorCode == null) return false;
  if (windows ?? Platform.isWindows) {
    // ERROR_ACCESS_DENIED, ERROR_SHARING_VIOLATION, ERROR_LOCK_VIOLATION.
    return const {5, 32, 33}.contains(errorCode);
  }
  return errorCode == 16; // EBUSY
}

/// The prefix mihomo's `age.DecryptBytes` tells an encrypted config by.
const _ageArmorHeader = '-----BEGIN AGE ENCRYPTED FILE-----';

extension FileExt on File {
  Future<void> safeCopy(String newPath) async {
    if (!await exists()) {
      await create(recursive: true);
      return;
    }
    final targetFile = File(newPath);
    if (!await targetFile.exists()) {
      await targetFile.create(recursive: true);
    }
    await copy(newPath);
  }

  Future<bool> get isAgeEncrypted async {
    final head = await openRead(
      0,
      _ageArmorHeader.length,
    ).expand((chunk) => chunk).toList();
    return String.fromCharCodes(head) == _ageArmorHeader;
  }

  Future<File> safeWriteAsString(String str) async {
    if (!await exists()) {
      await create(recursive: true);
    }
    return writeAsString(str);
  }

  Future<File> safeWriteAsBytes(List<int> bytes) async {
    if (!await exists()) {
      await create(recursive: true);
    }
    return writeAsBytes(bytes);
  }

  /// Each write goes through its own temporary sibling, so overlapping
  /// writes never trip over each other: the last rename wins whole.
  Future<void> writeAsStringAtomically(String content) =>
      _writeAtomically((temp) => temp.writeAsString(content, flush: true));

  /// With [keepMode], a file already at [path] passes its permissions on to
  /// the one replacing it: the temporary starts as a copy of it, which
  /// carries its mode, and is then overwritten.
  Future<void> writeAsBytesAtomically(
    List<int> bytes, {
    bool keepMode = false,
  }) => _writeAtomically(
    (temp) => temp.writeAsBytes(bytes, flush: true),
    keepMode: keepMode,
  );

  Future<void> _writeAtomically(
    Future<void> Function(File temp) write, {
    bool keepMode = false,
  }) async {
    final temp = File(uniqueTempPath(path));
    try {
      await temp.parent.create(recursive: true);
      await _sweepOnce(temp.parent.path);
      if (keepMode) {
        try {
          await copy(temp.path);
          // A copy may carry the old file's times; the temporary is new.
          await temp.setLastModified(DateTime.now());
        } on FileSystemException {
          // Nothing there to take the mode of, or unreadable: a new file.
          await temp.delete().then((_) {}, onError: (_) {});
        }
      }
      await write(temp);
      await temp._renameRetryingWhileHeldOpen(path);
    } catch (_) {
      await temp.delete().then((_) {}, onError: (_) {});
      rethrow;
    }
  }

  /// Copies to [target] through a temporary sibling, so a watcher of
  /// [target] never reads half of it.
  Future<void> copyAtomically(String target) async {
    final temp = File(uniqueTempPath(target));
    try {
      await temp.parent.create(recursive: true);
      await _sweepOnce(temp.parent.path);
      await copy(temp.path);
      await temp._renameRetryingWhileHeldOpen(target);
    } catch (_) {
      await temp.delete().then((_) {}, onError: (_) {});
      rethrow;
    }
  }

  /// Only a target another process holds open is worth waiting for (Windows
  /// refuses to replace it until it is closed); a missing source, a missing
  /// directory or a denied path fails the same way every time.
  Future<void> _renameRetryingWhileHeldOpen(String target) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await rename(target);
        return;
      } on FileSystemException catch (e) {
        if (attempt == _replaceAttempts ||
            !isHeldOpenError(e.osError?.errorCode)) {
          rethrow;
        }
        await Future<void>.delayed(_replaceRetryDelay);
      }
    }
  }
}

extension FileSystemEntityExt on FileSystemEntity {
  Future<void> safeDelete({bool recursive = false}) async {
    if (!await exists()) {
      return;
    }
    await delete(recursive: recursive);
  }
}

Future<void> safeDeletePath(String path) async {
  final entity = switch (FileSystemEntity.typeSync(path)) {
    FileSystemEntityType.directory => Directory(path),
    _ => File(path),
  };
  await entity.safeDelete(recursive: true);
}
