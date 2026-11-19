import 'dart:io';
import 'dart:math';

const _replaceAttempts = 10;
const _replaceRetryDelay = Duration(milliseconds: 50);

final _tempRandom = Random.secure();

/// A sibling of [path] no other write, in this process or another, picks:
/// `<path>.<pid>.<8 hex>.tmp`.
String uniqueTempPath(String path) {
  final suffix = _tempRandom.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
  return '$path.$pid.$suffix.tmp';
}

/// Matches what [uniqueTempPath] appends, and the `<pid>.tmp` of older builds,
/// so a sweep can tell which file a leftover temporary belonged to.
final atomicTempSuffix = RegExp(r'\.\d+(\.[0-9a-f]{8})?\.tmp$');

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

  Future<void> writeAsBytesAtomically(List<int> bytes) =>
      _writeAtomically((temp) => temp.writeAsBytes(bytes, flush: true));

  Future<void> _writeAtomically(Future<void> Function(File temp) write) async {
    final temp = File(uniqueTempPath(path));
    try {
      await temp.parent.create(recursive: true);
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
      await copy(temp.path);
      await temp._renameRetryingWhileHeldOpen(target);
    } catch (_) {
      await temp.delete().then((_) {}, onError: (_) {});
      rethrow;
    }
  }

  Future<void> _renameRetryingWhileHeldOpen(String target) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await rename(target);
        return;
      } on FileSystemException {
        if (attempt == _replaceAttempts) rethrow;
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
