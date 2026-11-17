import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:fl_clash/models/models.dart';

/// Reserves empty generations without following any link below the trusted home.
/// Unreferenced reservations are intentionally retained after failures.
List<AddedRuleSet> reserveRestoredAddedCaches(
  (String, List<AddedRuleSet>) request,
) {
  final (home, sets) = request;
  if (sets.isEmpty) return sets;
  // The Linux/Android values of O_DIRECTORY and O_NOFOLLOW vary by ABI,
  // including 32-bit ARM. Until a native implementation supplies verified
  // constants, reject nonempty restores there rather than guess flags.
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'Safe added rule set restore is unavailable on this platform',
    );
  }
  final libc = DynamicLibrary.process();
  final open = libc
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32),
        int Function(Pointer<Utf8>, int)
      >('open');
  final openat = libc
      .lookupFunction<
        Int32 Function(Int32, Pointer<Utf8>, Int32),
        int Function(int, Pointer<Utf8>, int)
      >('openat');
  final mkdirat = libc
      .lookupFunction<
        Int32 Function(Int32, Pointer<Utf8>, Uint32),
        int Function(int, Pointer<Utf8>, int)
      >('mkdirat');
  final close = libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
    'close',
  );
  const flags = 0x100000 | 0x100; // Darwin O_DIRECTORY | O_NOFOLLOW.
  final name = home.toNativeUtf8();
  final root = open(name, flags);
  calloc.free(name);
  if (root < 0) {
    throw FileSystemException('Cannot open trusted restore root', home);
  }
  final random = Random.secure();
  final result = <AddedRuleSet>[];
  try {
    for (final set in sets) {
      var current = root;
      try {
        for (final component in [
          'profiles',
          'providers',
          '${set.profileId}',
          'rules',
          'added',
          '${set.id}',
        ]) {
          final name = component.toNativeUtf8();
          try {
            var next = openat(current, name, flags);
            if (next < 0) {
              mkdirat(current, name, 0x1ed);
              next = openat(current, name, flags);
            }
            if (next < 0) {
              throw FileSystemException(
                'Unsafe or inaccessible cache directory',
                component,
              );
            }
            if (current != root) close(current);
            current = next;
          } finally {
            calloc.free(name);
          }
        }
        String? generation;
        for (var attempt = 0; attempt < 16; attempt++) {
          final token = List.generate(
            16,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
          final name = token.toNativeUtf8();
          final created = mkdirat(current, name, 0x1c0);
          calloc.free(name);
          if (created == 0) {
            generation = token;
            break;
          }
        }
        if (generation == null) {
          throw const FileSystemException(
            'Unable to reserve rule set generation',
          );
        }
        result.add(set.copyWith(cacheGeneration: generation));
      } finally {
        if (current != root) close(current);
      }
    }
    return result;
  } finally {
    close(root);
  }
}
