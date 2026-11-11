import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_profiles.dart';

void main() {
  late db.Database testDatabase;

  setUp(() {
    testDatabase = db.Database(NativeDatabase.memory());
    db.database = testDatabase;
  });

  tearDown(() async {
    await testDatabase.close();
  });

  testWidgets('a custom setup disposed before its queries return resolves', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      label: 'Home',
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    const subscription = Profile(
      id: 2,
      label: 'Sub',
      type: ProfileType.url,
      url: 'https://example.com/sub',
      autoUpdateDuration: Duration.zero,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([profile, subscription]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = await container.read(setupStateProvider(profile.id).future);

    expect(state.profileType, ProfileType.custom);
    expect(state.profileProviders, {'Sub': subscription.id});
  });

  testWidgets('a custom setup leaves the extension of its profile out', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
      extendType: ExtendType.script,
      scriptId: 5,
      matchTarget: 'Proxy',
    );
    await testDatabase.profilesDao.putAll([profile.toCompanion()]);
    await testDatabase.scripts.put(
      Script(
        id: 5,
        label: 'Script',
        lastUpdateTime: DateTime(2026),
      ).toCompanion(),
    );
    await testDatabase.rulesDao.putRule(
      Rule.parse('DOMAIN,global.com,DIRECT', id: 10),
    );
    await testDatabase.rulesDao.putRule(
      Rule.parse('DOMAIN,own.com,DIRECT', id: 11),
      profileId: profile.id,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = await container.read(setupStateProvider(profile.id).future);

    expect(state.script, isNull);
    expect(state.matchTarget, isNull);
    expect(state.addedRules, isEmpty);
    expect(state.rules.map((rule) => rule.id), [11]);
  });

  testWidgets('a custom setup carries the dialers of its own profile', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      label: 'Home',
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    const other = Profile(
      id: 2,
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    await testDatabase.profilesDao.putAll([
      profile.toCompanion(),
      other.toCompanion(),
    ]);
    await testDatabase.customProxies.put(
      const CustomProxy(id: 30, definition: {'name': 'Home'}).toCompanion(),
    );
    await testDatabase.proxyDialersDao.set(profile.id, 30, 'Relay');
    await testDatabase.proxyDialersDao.set(other.id, 30, 'Other');
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile, other])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = await container.read(setupStateProvider(profile.id).future);

    expect(state.proxyDialers, {30: 'Relay'});
  });

  testWidgets('a profile with a mount record carries its mount setup', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('mount_setup_state');
    addTearDown(() => root.deleteSync(recursive: true));
    await tester.runAsync(() => useAppPaths(root));
    const profile = Profile(
      id: 1,
      label: 'Base',
      autoUpdateDuration: Duration.zero,
    );
    const source = Profile(
      id: 2,
      label: 'Air',
      type: ProfileType.url,
      url: 'https://example.invalid/sub',
      autoUpdateDuration: Duration.zero,
    );
    await testDatabase.profilesDao.putAll([
      profile.toCompanion(),
      source.toCompanion(),
    ]);
    await testDatabase.mountsDao.save(
      targetId: 1,
      expectedVersion: null,
      sourceIds: [2],
      groups: ['Proxy'],
      pending: (version) =>
          MountOperation(kind: MountOperationKind.save, version: version),
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile, source])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = (await tester.runAsync(
      () => container.read(setupStateProvider(profile.id).future),
    ))!;

    final mounts = state.mounts!;
    expect(mounts.groups, ['Proxy']);
    expect(mounts.sources.single.id, 2);
    expect(mounts.sources.single.label, 'Air');
    expect(mounts.sources.single.path, endsWith('2.yaml'));
    expect(mounts.revision, isNotEmpty);
    final other = (await tester.runAsync(
      () => container.read(setupStateProvider(2).future),
    ))!;
    expect(other.mounts, isNull);
  });

  testWidgets('a live setup follows a mount save and a source update', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('mount_setup_live');
    addTearDown(() => root.deleteSync(recursive: true));
    await tester.runAsync(() => useAppPaths(root));
    const profile = Profile(
      id: 1,
      label: 'Base',
      autoUpdateDuration: Duration.zero,
    );
    const source = Profile(
      id: 2,
      label: 'Air',
      type: ProfileType.url,
      url: 'https://example.invalid/sub',
      autoUpdateDuration: Duration.zero,
    );
    await testDatabase.profilesDao.putAll([
      profile.toCompanion(),
      source.toCompanion(),
    ]);
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile, source])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );
    final sub = container.listen(setupStateProvider(1), (_, _) {});
    addTearDown(sub.close);
    Future<MountSetup?> mounts() async => (await tester.runAsync(() async {
      await pumpEventQueue();
      return container.read(setupStateProvider(1).future);
    }))!.mounts;

    expect(await mounts(), isNull);

    await tester.runAsync(
      () => testDatabase.mountsDao.save(
        targetId: 1,
        expectedVersion: null,
        sourceIds: [2],
        groups: ['Proxy'],
        pending: (version) =>
            MountOperation(kind: MountOperationKind.save, version: version),
      ),
    );
    final saved = await mounts();
    expect(saved?.sources.single.id, 2);

    container
        .read(profilesProvider.notifier)
        .put(source.copyWith(lastUpdateDate: DateTime(2026)));
    expect((await mounts())?.revision, isNot(saved!.revision));
  });
}
