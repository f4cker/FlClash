import 'dart:io';

import 'package:fl_clash/common/restored_added_cache.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const set = AddedRuleSet(
    id: 7,
    profileId: 1,
    name: 'ads',
    url: 'https://example.test/ads',
  );
  test('empty reservations do not require filesystem support', () {
    expect(reserveRestoredAddedCaches(('/nonexistent', [])), isEmpty);
  });
  test('unsupported platforms reject nonempty reservations', () {
    if (!Platform.isMacOS) {
      expect(
        () => reserveRestoredAddedCaches(('/nonexistent', [set])),
        throwsUnsupportedError,
      );
    }
  });
  test(
    'fresh reservations do not adopt existing caches or alter their bytes',
    () async {
      final root = await Directory.systemTemp.createTemp('restore-reserve-');
      addTearDown(() => root.delete(recursive: true));
      final old = set.copyWith(cacheGeneration: 'a' * 32);
      final oldFile = File(old.pathUnder(p.join(root.path, 'profiles')));
      await oldFile.parent.create(recursive: true);
      await oldFile.writeAsString('foreign');
      final first = reserveRestoredAddedCaches((root.path, [old])).single;
      final second = reserveRestoredAddedCaches((root.path, [old])).single;
      expect(first.cacheGeneration, isNot(old.cacheGeneration));
      expect(second.cacheGeneration, isNot(first.cacheGeneration));
      expect(await oldFile.readAsString(), 'foreign');
      expect(
        await Directory(
          File(first.pathUnder(p.join(root.path, 'profiles'))).parent.path,
        ).exists(),
        isTrue,
      );
      expect(
        await File(first.pathUnder(p.join(root.path, 'profiles'))).exists(),
        isFalse,
      );
    },
    skip: !Platform.isMacOS,
  );
  test('rejects a symlink inside the cache tree', () async {
    final root = await Directory.systemTemp.createTemp('restore-reserve-');
    final foreign = await Directory.systemTemp.createTemp('restore-foreign-');
    addTearDown(() async {
      await root.delete(recursive: true);
      await foreign.delete(recursive: true);
    });
    final profiles = Directory(p.join(root.path, 'profiles'));
    await profiles.create();
    await Link(p.join(profiles.path, 'providers')).create(foreign.path);
    expect(
      () => reserveRestoredAddedCaches((root.path, [set])),
      throwsA(isA<FileSystemException>()),
    );
    expect(await foreign.list().toList(), isEmpty);
  }, skip: !Platform.isMacOS);
}
