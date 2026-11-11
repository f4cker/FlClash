import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

class _FakeSetupAction extends SetupAction {
  static bool result = true;
  static int applied = 0;

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applied++;
    return result;
  }

  @override
  Future<({SetupBase? base, String? config})> mountTargetInput(
    int profileId,
  ) async => (base: null, config: 'proxies: []');
}

const _target = Profile(
  id: 1,
  label: 'Home',
  type: ProfileType.url,
  url: 'https://example.invalid/home',
  autoUpdateDuration: Duration.zero,
);
const _source = Profile(
  id: 2,
  label: 'Air',
  type: ProfileType.url,
  url: 'https://example.invalid/air',
  autoUpdateDuration: Duration.zero,
);

const _withGroup = MountPreflight(
  report: MountReport(
    groups: [
      MountGroupReport(
        name: 'Proxy',
        via: MountGroupVia.use,
        protection: MountProtection.reject,
      ),
    ],
  ),
);

void main() {
  late Directory home;
  late _MockCore core;
  late db.Database testDatabase;

  setUpAll(() async {
    home = Directory.systemTemp.createTempSync('flclash-mount-action-');
    await useAppPaths(home);
    registerFallbackValue(const MountSetup(target: 0, revision: ''));
  });

  tearDownAll(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  setUp(() async {
    core = _MockCore();
    await mockPreferences();
    testDatabase = db.Database(NativeDatabase.memory());
    db.database = testDatabase;
    addTearDown(testDatabase.close);
    await testDatabase.profilesDao.putAll([
      _target.toCompanion(),
      _source.toCompanion(),
    ]);
    _FakeSetupAction.result = true;
    _FakeSetupAction.applied = 0;
    when(
      () => core.preflightMounts(
        base: any(named: 'base'),
        config: any(named: 'config'),
        mounts: any(named: 'mounts'),
      ),
    ).thenAnswer((_) async => _withGroup);
    when(() => core.clearEffect(any())).thenAnswer((_) async {});
  });

  ProviderContainer build({bool running = false}) {
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(() => TestProfiles([_target, _source])),
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        initProvider.overrideWithBuild((_, _) => running),
        setupActionProvider.overrideWith(_FakeSetupAction.new),
        tailscaleManagedRecordsProvider.overrideWithBuild((_, _) => const []),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    return container;
  }

  MountAction action(ProviderContainer container) =>
      container.read(mountActionProvider.notifier);

  Future<MountSaveResult> mountAir(
    ProviderContainer container, {
    int? expectedVersion,
  }) => action(container).save(
    1,
    expectedVersion: expectedVersion,
    sourceIds: [2],
    groups: ['Proxy'],
  );

  Future<String> runningRevision() async {
    final target = (await testDatabase.mountsDao.target(1))!;
    return mountSetupOf(target, const [
      _target,
      _source,
    ], await appPath.profilesPath).revision;
  }

  void readsBack({bool blocked = false, bool matches = true}) {
    when(() => core.getMountState()).thenAnswer(
      (_) async => MountRuntimeState(
        blocked: blocked,
        report: MountReport(
          revision: await runningRevision(),
          sources: const [
            MountSourceReport(
              id: 2,
              provider: 'flash-mount-2',
              status: MountSourceStatus.nodes,
            ),
          ],
          groups: _withGroup.report!.groups,
        ),
        sources: [
          MountRuntimeSource(
            id: 2,
            provider: 'flash-mount-2',
            present: true,
            matches: matches,
          ),
        ],
        groups: const [MountRuntimeGroup(name: 'Proxy', present: true)],
      ),
    );
  }

  group('save', () {
    test('a target that is not running is saved and settled', () async {
      final result = await mountAir(build());

      expect(result.outcome, MountSaveOutcome.saved);
      final stored = (await testDatabase.mountsDao.target(1))!;
      expect(stored.sourceIds, [2]);
      expect(stored.groups, ['Proxy']);
      expect(stored.version, 1);
      expect(stored.pending, isNull);
      expect(_FakeSetupAction.applied, 0);
    });

    test('a choice made on a stale version writes nothing', () async {
      final container = build();
      await mountAir(container);

      final result = await mountAir(container);

      expect(result.outcome, MountSaveOutcome.unchanged);
      expect(result.state?.version, 1);
      verify(
        () => core.preflightMounts(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).called(1);
    });

    test('a vanished group or no group at all stores nothing', () async {
      final container = build();
      when(
        () => core.preflightMounts(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).thenAnswer(
        (_) async => const MountPreflight(
          error: 'gone',
          errorCode: 'mount_group_changed',
        ),
      );
      expect(
        (await mountAir(container)).outcome,
        MountSaveOutcome.groupsChanged,
      );

      when(
        () => core.preflightMounts(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).thenAnswer((_) async => const MountPreflight(report: MountReport()));
      expect((await mountAir(container)).outcome, MountSaveOutcome.needsGroup);

      expect(await testDatabase.mountsDao.target(1), isNull);
    });

    test('a running target is applied and proven by a readback', () async {
      readsBack();

      final result = await mountAir(build(running: true));

      expect(result.outcome, MountSaveOutcome.applied);
      expect(result.lostSelections, isEmpty);
      expect(_FakeSetupAction.applied, 1);
      expect((await testDatabase.mountsDao.target(1))!.pending, isNull);
    });

    test(
      'a readback that differs settles unverified, a blocked one says so',
      () async {
        final container = build(running: true);
        readsBack(matches: false);
        expect(
          (await mountAir(container)).outcome,
          MountSaveOutcome.appliedUnverified,
        );

        readsBack(blocked: true);
        _FakeSetupAction.result = false;
        expect(
          (await action(container).save(
            1,
            expectedVersion: 1,
            sourceIds: [2],
            groups: const [],
          )).outcome,
          MountSaveOutcome.applyFailedBlocked,
        );
        expect((await testDatabase.mountsDao.target(1))!.pending, isNull);
      },
    );

    test('an unread outcome keeps the target locked until a recheck', () async {
      final container = build(running: true);
      when(() => core.getMountState()).thenThrow(const SocketException('x'));

      expect((await mountAir(container)).outcome, MountSaveOutcome.unknown);
      expect((await testDatabase.mountsDao.target(1))!.pending, isNotNull);
      expect(
        (await mountAir(container, expectedVersion: 1)).outcome,
        MountSaveOutcome.locked,
      );

      readsBack();
      expect(
        (await action(container).recheck(1)).outcome,
        MountSaveOutcome.applied,
      );
      expect((await testDatabase.mountsDao.target(1))!.pending, isNull);
    });
  });

  group('deleting a source', () {
    test('a mounted source cannot be deleted as a plain profile', () async {
      final container = build();
      await mountAir(container);

      await expectLater(
        container.read(profilesActionProvider.notifier).deleteProfile(2),
        throwsA(isA<MountSourceInUse>()),
      );
      expect(container.read(profilesProvider).getProfile(2), isNotNull);
    });

    test('the mount action unmounts it first, then deletes it', () async {
      final container = build();
      await mountAir(container);
      expect(await action(container).sourceTargets(2), [_target]);

      expect(
        await action(container).deleteSource(2),
        MountSourceDeletion.deleted,
      );
      expect((await testDatabase.mountsDao.target(1))!.sourceIds, isEmpty);
      expect(container.read(profilesProvider).getProfile(2), isNull);
    });

    test('an unknown apply keeps the source until a recheck', () async {
      final container = build(running: true);
      readsBack();
      await mountAir(container);
      when(() => core.getMountState()).thenThrow(const SocketException('x'));

      expect(
        await action(container).deleteSource(2),
        MountSourceDeletion.unknown,
      );
      expect(container.read(profilesProvider).getProfile(2), isNotNull);
      expect((await testDatabase.mountsDao.target(1))!.pending, isNotNull);

      readsBack();
      expect(
        (await action(container).recheck(1)).outcome,
        MountSaveOutcome.applied,
      );
      expect(
        await action(container).deleteSource(2),
        MountSourceDeletion.deleted,
      );
      expect(container.read(profilesProvider).getProfile(2), isNull);
    });

    test('a pending target blocks the deletion', () async {
      final container = build(running: true);
      when(() => core.getMountState()).thenThrow(const SocketException('x'));
      await mountAir(container);

      expect(
        await action(container).deleteSource(2),
        MountSourceDeletion.blocked,
      );
      expect(container.read(profilesProvider).getProfile(2), isNotNull);
    });
  });

  test('the card summary follows the stored relation and records', () async {
    final container = build();
    final sub = container.listen(mountCardSummaryProvider(1), (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(mountCardSummaryProvider(1).future), isNull);

    await mountAir(container);
    await testDatabase.mountsDao.recordSourceResult(
      2,
      failure: MountSourceFailure.fetch,
      at: DateTime(2026),
    );
    await pumpEventQueue();

    expect(
      await container.read(mountCardSummaryProvider(1).future),
      const MountCardSummary(mounted: 1, failed: 1),
    );
  });
}
