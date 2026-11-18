import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/path.dart';
import 'package:path/path.dart' as p;

void _syncDirectory(String path) {
  final libc = DynamicLibrary.process();
  final open = libc
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32),
        int Function(Pointer<Utf8>, int)
      >('open');
  final sync = libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
    'fsync',
  );
  final close = libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
    'close',
  );
  final nativePath = path.toNativeUtf8();
  try {
    final fd = open(nativePath, 0);
    if (fd < 0) {
      throw FileSystemException('Cannot open directory for sync', path);
    }
    final int syncResult;
    final int closeResult;
    try {
      syncResult = sync(fd);
    } finally {
      closeResult = close(fd);
    }
    if (syncResult != 0 || closeResult != 0) {
      throw FileSystemException('Cannot sync directory', path);
    }
  } finally {
    malloc.free(nativePath);
  }
}

Future<MacRepairRecord> macRepairRecord() async {
  final directory = Directory(await appPath.homeDirPath);
  await directory.create(recursive: true);
  return MacRepairRecord(
    File(p.join(directory.path, 'mac-helper-repair.pending')),
  );
}

/// Blocks a Core start while a helper recovery has not been settled. A record
/// that cannot be read blocks too.
Future<void> requireMacRepairComplete({
  Future<MacRepairRecord> Function() recordFactory = macRepairRecord,
}) async {
  bool pending;
  try {
    pending = await (await recordFactory()).isPending();
  } catch (error) {
    throw MacRepairPendingException(error.toString());
  }
  if (pending) throw const MacRepairPendingException();
}

/// The helper is being recovered: old Cores are not yet confirmed stopped by
/// the new helper. Shown only through the helper card ("View details" holds
/// [detail]); it is never a reason to restart the Mac.
final class MacRepairPendingException implements Exception {
  final String? detail;

  const MacRepairPendingException([this.detail]);

  @override
  String toString() => detail == null
      ? 'MacRepairPendingException'
      : 'MacRepairPendingException($detail)';
}

/// Persisted across app launches: a helper recovery began, so a Core may only
/// start once the new helper has confirmed that no old Core still runs.
///
/// Settling depends only on the helper's answers (signature-checked hello and
/// its signature-based sweep of old Cores), never on a reboot. A record left by
/// an earlier build (it carried a boot-session id) is settled the same way.
final class MacRepairRecord {
  final File file;
  static final Map<String, Future<void>> _operations = {};

  const MacRepairRecord(this.file);

  Future<T> _serialized<T>(Future<T> Function() action) async {
    final key = p.normalize(p.absolute(file.path));
    final previous = _operations[key];
    final finished = Completer<void>();
    _operations[key] = finished.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      if (identical(_operations[key], finished.future)) {
        _operations.remove(key)?.ignore();
      }
      finished.complete();
    }
  }

  Future<void> _requireParent() async {
    final stat = await file.parent.stat();
    if (stat.type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Repair record directory is unavailable',
        file.parent.path,
      );
    }
  }

  Future<void> _syncParents() async {
    final parent = file.parent.path;
    final grandparent = file.parent.parent.path;
    await Isolate.run(() {
      _syncDirectory(parent);
      if (grandparent != parent) _syncDirectory(grandparent);
    });
  }

  Future<bool> isPending() async {
    await _requireParent();
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    return type != FileSystemEntityType.notFound;
  }

  /// Durably records that a recovery begins. [diagnostics] (for example the
  /// boot session) is informational only and never decides anything.
  Future<void> markPending({Map<String, Object?> diagnostics = const {}}) {
    return _serialized(() async {
      await _requireParent();
      if (await isPending()) return;
      final temp = await file.parent.createTemp('.mac-repair-');
      try {
        final staging = File(p.join(temp.path, 'pending'));
        final handle = await staging.open(mode: FileMode.write);
        try {
          await handle.writeString(
            jsonEncode({
              'version': 2,
              'started': DateTime.now().toUtc().toIso8601String(),
              ...diagnostics,
            }),
          );
          await handle.flush();
        } finally {
          await handle.close();
        }
        await staging.rename(file.path);
        await _syncParents();
      } finally {
        await temp.delete(recursive: true);
      }
    });
  }

  /// Removes the record once [confirmed] (run inside the serialization)
  /// reports that the new helper answered and no old Core runs.
  Future<bool> clearIf(Future<bool> Function() confirmed) {
    return _serialized(() async {
      await _requireParent();
      if (!await isPending()) return true;
      if (!await confirmed()) return false;
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        throw FileSystemException('Invalid repair record', file.path);
      }
      await file.delete();
      await _syncParents();
      return true;
    });
  }
}
