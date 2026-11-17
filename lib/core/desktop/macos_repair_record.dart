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

Future<void> requireMacRepairComplete({
  Future<MacRepairRecord> Function() recordFactory = macRepairRecord,
}) async {
  try {
    if (await (await recordFactory()).isPending()) {
      throw const MacRepairPendingException();
    }
  } on MacRepairPendingException {
    rethrow;
  } catch (error) {
    throw StateError(
      'Cannot read the helper repair record; Core startup is blocked. '
      'Check access to the application support directory and contact support: $error',
    );
  }
}

final class MacRepairPendingException implements Exception {
  const MacRepairPendingException();

  @override
  String toString() =>
      'Helper repair is unfinished and the old Core cannot be verified. '
      '若已确认辅助程序已重新登记，请重启 Mac 后继续；否则请联系支持。';
}

abstract interface class MacRepairVerification {
  /// A stable identifier for this OS boot, not the application process.
  Future<String> readBootSession();

  /// Performs fresh signature and peer authentication and verifies that this
  /// GUI has not launched a Core since that verification.
  Future<bool> verifyCurrentSignedAuthenticatedHelperAndNoGuiCore();
}

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
    try {
      final handle = await file.open();
      try {
        await handle.read(1);
      } finally {
        await handle.close();
      }
      return true;
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode != 2) rethrow;
      await _requireParent();
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.notFound) rethrow;
      return false;
    }
  }

  static String _validBootSession(String session) {
    if (session.isEmpty || session.trim() != session || session.length > 512) {
      throw const FormatException('Invalid boot session identifier');
    }
    return session;
  }

  Future<void> markPending({
    required Future<String> Function() readBootSession,
  }) {
    return _serialized(() async {
      await _requireParent();
      final boot = _validBootSession(await readBootSession());
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.notFound) {
        throw FileSystemException('Repair record already exists', file.path);
      }
      final temp = await file.parent.createTemp('.mac-repair-');
      try {
        final staging = File(p.join(temp.path, 'pending'));
        final handle = await staging.open(mode: FileMode.write);
        try {
          await handle.writeString(jsonEncode({'version': 1, 'boot': boot}));
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

  Future<bool> canRetryExplicit({
    required Future<String> Function() readBootSession,
  }) async {
    await _requireParent();
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    final handle = await file.open();
    final List<int> bytes;
    try {
      bytes = await handle.read(4097);
    } finally {
      await handle.close();
    }
    if (bytes.length > 4096) return false;
    final value = jsonDecode(utf8.decode(bytes));
    final boot = _validBootSession(await readBootSession());
    return value is Map &&
        value['version'] == 1 &&
        value['boot'] == boot &&
        value['registrationBoot'] == null &&
        value['explicitNotStarted'] == true;
  }

  // The absence of this flag always means the call may have started. Each
  // retry first durably removes it, before crossing the native channel.
  Future<void> setExplicitNotStarted({
    required bool notStarted,
    required Future<String> Function() readBootSession,
  }) => _serialized(() async {
    await _requireParent();
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException('Invalid repair record', file.path);
    }
    final handle = await file.open();
    final List<int> bytes;
    try {
      bytes = await handle.read(4097);
    } finally {
      await handle.close();
    }
    if (bytes.length > 4096) {
      throw const FormatException('Invalid repair record');
    }
    final value = jsonDecode(utf8.decode(bytes));
    final boot = _validBootSession(await readBootSession());
    if (value is! Map ||
        value['version'] != 1 ||
        value['boot'] != boot ||
        value['registrationBoot'] != null ||
        (!notStarted && value['explicitNotStarted'] != true) ||
        (notStarted && value['explicitNotStarted'] != null)) {
      throw const FormatException('Invalid explicit repair state');
    }
    final temp = await file.parent.createTemp('.mac-repair-');
    try {
      final staging = File(p.join(temp.path, 'pending'));
      final output = await staging.open(mode: FileMode.write);
      try {
        await output.writeString(
          jsonEncode({
            'version': 1,
            'boot': boot,
            if (notStarted) 'explicitNotStarted': true,
          }),
        );
        await output.flush();
      } finally {
        await output.close();
      }
      await staging.rename(file.path);
      await _syncParents();
    } finally {
      await temp.delete(recursive: true);
    }
  });

  // A new process cannot know whether an earlier system registration returned.
  Future<void> markRegistrationAttemptAfterReboot({
    required Future<String> Function() readBootSession,
  }) => _serialized(() async {
    await _requireParent();
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException('Invalid repair record', file.path);
    }
    final handle = await file.open();
    final List<int> bytes;
    try {
      bytes = await handle.read(4097);
    } finally {
      await handle.close();
    }
    if (bytes.length > 4096) {
      throw const FormatException('Invalid repair record');
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map ||
        value['version'] != 1 ||
        value['boot'] is! String ||
        (value['registrationBoot'] != null &&
            value['registrationBoot'] is! String)) {
      throw const FormatException('Invalid repair record');
    }
    final oldBoot = _validBootSession(value['boot'] as String);
    final currentBoot = _validBootSession(await readBootSession());
    if (oldBoot == currentBoot ||
        (value['registrationBoot'] == currentBoot &&
            value['registrationSettledBoot'] != currentBoot)) {
      throw StateError(
        'Registration outcome may still be in flight; restart the Mac before trying again',
      );
    }
    final temp = await file.parent.createTemp('.mac-repair-');
    try {
      final staging = File(p.join(temp.path, 'pending'));
      final output = await staging.open(mode: FileMode.write);
      try {
        await output.writeString(
          jsonEncode({
            'version': 1,
            'boot': oldBoot,
            'registrationBoot': currentBoot,
          }),
        );
        await output.flush();
      } finally {
        await output.close();
      }
      await staging.rename(file.path);
      await _syncParents();
    } finally {
      await temp.delete(recursive: true);
    }
  });

  Future<void> markRegistrationSettled({
    required Future<String> Function() readBootSession,
  }) => _serialized(() async {
    await _requireParent();
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException('Invalid repair record', file.path);
    }
    final handle = await file.open();
    final List<int> bytes;
    try {
      bytes = await handle.read(4097);
    } finally {
      await handle.close();
    }
    if (bytes.length > 4096) {
      throw const FormatException('Invalid repair record');
    }
    final value = jsonDecode(utf8.decode(bytes));
    final boot = _validBootSession(await readBootSession());
    if (value is! Map ||
        value['version'] != 1 ||
        value['boot'] is! String ||
        value['registrationBoot'] != boot ||
        value['boot'] == boot) {
      throw const FormatException('Invalid registration attempt');
    }
    final temp = await file.parent.createTemp('.mac-repair-');
    try {
      final staging = File(p.join(temp.path, 'pending'));
      final output = await staging.open(mode: FileMode.write);
      try {
        await output.writeString(
          jsonEncode({
            'version': 1,
            'boot': _validBootSession(value['boot'] as String),
            'registrationBoot': boot,
            'registrationSettledBoot': boot,
          }),
        );
        await output.flush();
      } finally {
        await output.close();
      }
      await staging.rename(file.path);
      await _syncParents();
    } finally {
      await temp.delete(recursive: true);
    }
  });

  Future<bool> clearAfterVerifiedReboot({
    required MacRepairVerification verification,
  }) {
    return _serialized(() async {
      await _requireParent();
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        if (await isPending()) throw StateError('Repair record changed');
        return false;
      }
      if (type != FileSystemEntityType.file) {
        throw FileSystemException('Invalid repair record', file.path);
      }
      final handle = await file.open();
      final List<int> bytes;
      try {
        bytes = await handle.read(4097);
      } finally {
        await handle.close();
      }
      if (bytes.length > 4096) {
        throw const FormatException('Invalid repair record');
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map ||
          value['version'] != 1 ||
          value['boot'] is! String ||
          (value['registrationBoot'] != null &&
              value['registrationBoot'] is! String) ||
          (value['registrationSettledBoot'] != null &&
              value['registrationSettledBoot'] is! String)) {
        throw const FormatException('Invalid repair record');
      }
      final oldBoot = _validBootSession(value['boot'] as String);
      final currentBoot = _validBootSession(
        await verification.readBootSession(),
      );
      if (oldBoot == currentBoot ||
          (value['registrationBoot'] == currentBoot &&
              value['registrationSettledBoot'] != currentBoot)) {
        return false;
      }
      if (!await verification
          .verifyCurrentSignedAuthenticatedHelperAndNoGuiCore()) {
        return false;
      }
      await file.delete();
      await _syncParents();
      return true;
    });
  }
}
