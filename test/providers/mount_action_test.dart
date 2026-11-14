import 'dart:async';
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
  static String config = 'proxies: []';

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
  ) async => (base: null, config: config);
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
    sources: [
      MountSourceReport(
        id: 2,
        provider: 'flash-mount-2',
        status: MountSourceStatus.nodes,
      ),
    ],
    groups: [
      MountGroupReport(
        name: 'Proxy',
        via: MountGroupVia.use,
        protection: MountProtection.reject,
      ),
    ],
  ),
);

Future<void> waitFor(bool Function() ready) async {
  final elapsed = Stopwatch()..start();
  while (!ready()) {
    if (elapsed.elapsed > const Duration(seconds: 3)) {
      fail('asynchronous inspection did not start');
    }
    await pumpEventQueue();
  }
}

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
    _FakeSetupAction.config = 'proxies: []';
    when(
      () => core.preflightMounts(
        base: any(named: 'base'),
        config: any(named: 'config'),
        mounts: any(named: 'mounts'),
      ),
    ).thenAnswer((_) async => _withGroup);
    when(() => core.clearEffect(any())).thenAnswer((_) async {});
  });

  ProviderContainer build({
    bool running = false,
    List<TailscaleManagedRecord>? managed = const [],
    List<Profile> profiles = const [_target, _source],
  }) {
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(() => TestProfiles(profiles)),
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        initProvider.overrideWithBuild((_, _) => running),
        setupActionProvider.overrideWith(_FakeSetupAction.new),
        tailscaleManagedRecordsProvider.overrideWithBuild((_, _) => managed),
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
  }) => action(
    container,
  ).save(1, expectedVersion: expectedVersion, sourceIds: [2]);

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
      expect(stored.version, 1);
      expect(stored.pending, isNull);
      expect(_FakeSetupAction.applied, 0);
    });

    for (final source in <MountSourceReport?>[
      null,
      const MountSourceReport(
        id: 2,
        provider: 'flash-mount-2',
        status: MountSourceStatus.missing,
      ),
      const MountSourceReport(
        id: 2,
        provider: 'flash-mount-2',
        status: MountSourceStatus.readError,
      ),
      const MountSourceReport(
        id: 2,
        provider: 'flash-mount-2',
        status: MountSourceStatus.invalid,
      ),
      const MountSourceReport(
        id: 2,
        provider: 'flash-mount-2',
        status: MountSourceStatus.nodes,
        tailscaleExcluded: 1,
      ),
      const MountSourceReport(
        id: 2,
        provider: 'flash-mount-2',
        status: MountSourceStatus.nodes,
        relayExcluded: 1,
      ),
      const MountSourceReport(
        id: 2,
        provider: 'flash-mount-2',
        status: MountSourceStatus.nodes,
        unsupportedExcluded: 1,
      ),
    ]) {
      test(
        'fresh preflight rejects unavailable or wholly excluded addition $source',
        () async {
          when(
            () => core.preflightMounts(
              base: any(named: 'base'),
              config: any(named: 'config'),
              mounts: any(named: 'mounts'),
            ),
          ).thenAnswer(
            (_) async => MountPreflight(
              report: _withGroup.report!.copyWith(sources: [?source]),
            ),
          );
          final result = await mountAir(build());
          expect(result.outcome, MountSaveOutcome.unchanged);
          expect(await testDatabase.mountsDao.target(1), isNull);
        },
      );
    }

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

    test('no group at all stores nothing', () async {
      final container = build();
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
          (await action(
            container,
          ).save(1, expectedVersion: 1, sourceIds: [2])).outcome,
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
        (await action(container).deleteSource(2)).result,
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
        (await action(container).deleteSource(2)).result,
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
        (await action(container).deleteSource(2)).result,
        MountSourceDeletion.deleted,
      );
      expect(container.read(profilesProvider).getProfile(2), isNull);
    });

    test('a pending target blocks the deletion', () async {
      final container = build(running: true);
      when(() => core.getMountState()).thenThrow(const SocketException('x'));
      await mountAir(container);

      expect(
        (await action(container).deleteSource(2)).result,
        MountSourceDeletion.blocked,
      );
      expect(container.read(profilesProvider).getProfile(2), isNotNull);
    });
  });

  group('a source is inspected against the target', () {
    void inspects() {
      when(
        () => core.inspectMountTarget(
          base: any(named: 'base'),
          config: any(named: 'config'),
          managedTarget: any(named: 'managedTarget'),
        ),
      ).thenAnswer((_) async => const MountTarget(relay: ['ts', 'Via TS']));
      when(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
          relay: any(named: 'relay'),
          managed: any(named: 'managed'),
        ),
      ).thenAnswer(
        (_) async => const MountSourceInspection(
          status: MountSourceStatus.nodes,
          listed: 2,
          relayExcluded: 2,
        ),
      );
    }

    test('inspection overlaps within a bound and keeps source order', () async {
      inspects();
      final targetRead = Completer<void>();
      when(
        () => core.inspectMountTarget(
          base: any(named: 'base'),
          config: any(named: 'config'),
          managedTarget: any(named: 'managedTarget'),
        ),
      ).thenAnswer((_) async {
        targetRead.complete();
        return const MountTarget(relay: ['ts']);
      });
      final pending = {
        for (var id = 2; id <= 6; id++) id: Completer<MountSourceInspection>(),
      };
      const nodes = MountSourceInspection(
        status: MountSourceStatus.nodes,
        count: 1,
        listed: 1,
      );
      addTearDown(() {
        for (final result in pending.values) {
          if (!result.isCompleted) result.complete(nodes);
        }
      });
      final started = <int>[];
      var active = 0;
      var peak = 0;
      when(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
          relay: any(named: 'relay'),
          managed: any(named: 'managed'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.positionalArguments.single as String;
        final id = int.parse(path.split('/').last.split('.').first);
        started.add(id);
        active++;
        if (active > peak) peak = active;
        try {
          return await pending[id]!.future;
        } finally {
          active--;
        }
      });
      final container = build(
        profiles: [
          _target,
          for (var id = 2; id <= 6; id++) _source.copyWith(id: id),
        ],
      );
      final updates = <MountPanel>[];
      final loading = action(container).watchPanel(1).map((panel) {
        updates.add(panel);
        return panel;
      }).last;
      await targetRead.future;
      await pumpEventQueue();
      expect(updates.first.groupsPending, isTrue);
      expect(updates.first.sources.map((item) => item.profile.id), [
        2,
        3,
        4,
        5,
        6,
      ]);
      expect(
        updates.first.sources.every(
          (item) => item.state == MountSourceState.pending,
        ),
        isTrue,
      );
      await waitFor(() => started.length == 4);
      expect(started, unorderedEquals([2, 3, 4, 5]));
      expect(peak, 4);

      pending[5]!.complete(nodes);
      await pumpEventQueue();
      await waitFor(() => started.length == 5);
      expect(started, unorderedEquals([2, 3, 4, 5, 6]));
      expect(updates.last.sources[3].state.mountable, isTrue);
      expect(updates.last.sources.first.state, MountSourceState.pending);
      expect(peak, 4);
      pending[3]!.completeError(const SocketException('unreadable'));
      pending[4]!.complete(nodes);
      pending[6]!.complete(nodes);
      pending[2]!.complete(nodes);
      final panel = await loading;
      expect(panel.sources.map((item) => item.profile.id), [2, 3, 4, 5, 6]);
      expect(panel.sources[1].state, MountSourceState.unreadable);
      expect(panel.sources.first.count, 1);
      expect(active, 0);

      inspects();
      final reloaded = await action(container).watchPanel(1).last;
      expect(reloaded.sources.every((item) => item.relayExcluded == 2), isTrue);
      verify(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
          relay: any(named: 'relay'),
          managed: any(named: 'managed'),
        ),
      ).called(10);
    });

    test('metadata is published before the target RPC resolves', () async {
      inspects();
      final target = Completer<MountTarget>();
      when(
        () => core.inspectMountTarget(
          base: any(named: 'base'),
          config: any(named: 'config'),
          managedTarget: any(named: 'managedTarget'),
        ),
      ).thenAnswer((_) => target.future);
      final updates = <MountPanel>[];
      final subscription = action(build()).watchPanel(1).listen(updates.add);
      await pumpEventQueue();
      expect(updates.single.sources.single.profile.realLabel, 'Air');
      expect(updates.single.groupsPending, isTrue);
      expect(updates.single.sources.single.state, MountSourceState.pending);
      expect(updates.single.sources.single.state.mountable, isFalse);
      await subscription.cancel();
      target.complete(const MountTarget());
      await pumpEventQueue();
      expect(updates, hasLength(1));
      verifyNever(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
          relay: any(named: 'relay'),
          managed: any(named: 'managed'),
        ),
      );
    });

    test(
      'close/retry cancels queued checks but retains live RPC slots',
      () async {
        inspects();
        final calls = <({int id, Completer<MountSourceInspection> gate})>[];
        var active = 0;
        var peak = 0;
        when(
          () => core.inspectMountSource(
            any(),
            ageSecretKey: any(named: 'ageSecretKey'),
            relay: any(named: 'relay'),
            managed: any(named: 'managed'),
          ),
        ).thenAnswer((invocation) async {
          final path = invocation.positionalArguments.single as String;
          final id = int.parse(path.split('/').last.split('.').first);
          final gate = Completer<MountSourceInspection>();
          calls.add((id: id, gate: gate));
          active++;
          if (active > peak) peak = active;
          try {
            return await gate.future;
          } finally {
            active--;
          }
        });
        final container = build(
          profiles: [
            _target,
            for (var id = 2; id <= 8; id++) _source.copyWith(id: id),
          ],
        );
        final old = <MountPanel>[];
        final first = action(container).watchPanel(1).listen(old.add);
        await pumpEventQueue();
        await waitFor(() => calls.length == 4);
        expect(calls.map((call) => call.id), unorderedEquals([2, 3, 4, 5]));
        await first.cancel();
        final oldCount = old.length;
        final next = <MountPanel>[];
        final second = action(container).watchPanel(1).listen(next.add);
        await pumpEventQueue();
        expect(next.single.groupsPending, isTrue);
        expect(calls, hasLength(4));
        const nodes = MountSourceInspection(
          status: MountSourceStatus.nodes,
          count: 1,
        );
        calls.first.gate.complete(nodes);
        await pumpEventQueue();
        await waitFor(() => calls.length == 5);
        expect(calls.map((call) => call.id), unorderedEquals([2, 3, 4, 5, 2]));
        expect(peak, 4);
        await second.cancel();
        for (final call in calls.skip(1)) {
          call.gate.complete(nodes);
        }
        await pumpEventQueue();
        expect(old, hasLength(oldCount));
        expect(calls, hasLength(5));
        expect(active, 0);
      },
    );

    test(
      'context changes invalidate completed rows and discard late results',
      () async {
        inspects();
        final source = Completer<MountSourceInspection>();
        when(
          () => core.inspectMountSource(
            any(),
            ageSecretKey: any(named: 'ageSecretKey'),
            relay: any(named: 'relay'),
            managed: any(named: 'managed'),
          ),
        ).thenAnswer((_) => source.future);
        final container = build();
        final updates = <MountPanel>[];
        final done = action(container).watchPanel(1).map((panel) {
          updates.add(panel);
          return panel;
        }).last;
        await pumpEventQueue();
        container
            .read(profilesProvider.notifier)
            .put(_source.copyWith(label: 'Changed'));
        await pumpEventQueue();
        final result = await done;
        expect(result.groups, isNull);
        expect(result.sources.single.state.mountable, isFalse);
        final count = updates.length;
        source.complete(
          const MountSourceInspection(
            status: MountSourceStatus.nodes,
            count: 1,
          ),
        );
        await pumpEventQueue();
        expect(updates, hasLength(count));
      },
    );

    test(
      'timeout marks pending rows failed without releasing live RPC slots',
      () async {
        inspects();
        final gates = <Completer<MountSourceInspection>>[];
        when(
          () => core.inspectMountSource(
            any(),
            ageSecretKey: any(named: 'ageSecretKey'),
            relay: any(named: 'relay'),
            managed: any(named: 'managed'),
          ),
        ).thenAnswer((_) {
          final gate = Completer<MountSourceInspection>();
          gates.add(gate);
          return gate.future;
        });
        final container = build(
          profiles: [
            _target,
            for (var id = 2; id <= 7; id++) _source.copyWith(id: id),
          ],
        );
        final updates = <MountPanel>[];
        final expired = await action(container).watchPanel(1).map((panel) {
          updates.add(panel);
          return panel;
        }).last;
        expect(gates, hasLength(4));
        expect(
          expired.sources.every(
            (item) => item.state == MountSourceState.unreadable,
          ),
          isTrue,
        );
        expect(expired.sources.every((item) => !item.state.mountable), isTrue);
        final count = updates.length;
        final next = <MountPanel>[];
        final retry = action(container).watchPanel(1).listen(next.add);
        await pumpEventQueue();
        expect(next.single.groupsPending, isTrue);
        expect(gates, hasLength(4));
        await retry.cancel();
        for (final gate in gates) {
          gate.complete(
            const MountSourceInspection(
              status: MountSourceStatus.nodes,
              count: 1,
            ),
          );
        }
        await pumpEventQueue();
        expect(gates, hasLength(4));
        expect(updates, hasLength(count));
      },
    );

    test(
      'same content skips repeat source RPCs; content and context invalidate',
      () async {
        inspects();
        final file = File(await appPath.getProfilePath('2'));
        await file.parent.create(recursive: true);
        await file.writeAsString('proxies: [a]');
        addTearDown(() async {
          if (await file.exists()) await file.delete();
        });
        var calls = 0;
        when(
          () => core.inspectMountSource(
            any(),
            ageSecretKey: any(named: 'ageSecretKey'),
            relay: any(named: 'relay'),
            managed: any(named: 'managed'),
          ),
        ).thenAnswer((_) async {
          calls++;
          return const MountSourceInspection(
            status: MountSourceStatus.nodes,
            count: 1,
          );
        });
        final container = build();
        final mounts = action(container);
        Future<void> load() async {
          final panel = await mounts.watchPanel(1).last;
          expect(panel.sources.single.state.mountable, isTrue);
        }

        await load();
        await load();
        expect(calls, 1);
        final modified = await file.lastModified();
        await file.writeAsString('proxies: [b]');
        await file.setLastModified(modified);
        await load();
        expect(calls, 2);
        container
            .read(profilesProvider.notifier)
            .put(_source.copyWith(ageSecretKey: 'test-secret'));
        await load();
        expect(calls, 3);
        _FakeSetupAction.config = 'proxies: [target]';
        await load();
        expect(calls, 4);
        container.read(tailscaleManagedRecordsProvider.notifier).value = const [
          TailscaleManagedRecord(id: 'x', profileId: 1, name: 'Office'),
        ];
        await load();
        expect(calls, 5);
        container.read(versionProvider.notifier).value = 2;
        await load();
        expect(calls, 6);
        await mounts.watchPanel(1, refresh: true).last;
        expect(calls, 7);
        await file.delete();
        await load();
        await load();
        expect(calls, 9);
      },
    );

    test('cached counts never bypass a changed live guard at save', () async {
      inspects();
      final file = File(await appPath.getProfilePath('2'));
      await file.parent.create(recursive: true);
      await file.writeAsString('proxies: []');
      addTearDown(file.delete);
      var calls = 0;
      when(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
          relay: any(named: 'relay'),
          managed: any(named: 'managed'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return const MountSourceInspection(
          status: MountSourceStatus.nodes,
          count: 1,
        );
      });
      final container = build();
      final mounts = action(container);
      await mounts.watchPanel(1).last;
      final cached = await mounts.watchPanel(1).last;
      expect(calls, 1);
      expect(cached.sources.single.state.mountable, isTrue);
      when(
        () => core.preflightMounts(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).thenAnswer(
        (_) async => MountPreflight(
          report: _withGroup.report!.copyWith(
            sources: const [
              MountSourceReport(
                id: 2,
                provider: 'flash-mount-2',
                status: MountSourceStatus.nodes,
                tailscaleExcluded: 1,
              ),
            ],
          ),
        ),
      );
      final result = await mountAir(container);
      expect(result.outcome, MountSaveOutcome.unchanged);
      expect(await testDatabase.mountsDao.target(1), isNull);
      await mounts.watchPanel(1).last;
      expect(calls, 2);
    });

    test(
      'queued target refresh shares the four live inspection slots',
      () async {
        inspects();
        final gates = <Completer<MountSourceInspection>>[];
        when(
          () => core.inspectMountSource(
            any(),
            ageSecretKey: any(named: 'ageSecretKey'),
            relay: any(named: 'relay'),
            managed: any(named: 'managed'),
          ),
        ).thenAnswer((_) {
          final gate = Completer<MountSourceInspection>();
          gates.add(gate);
          return gate.future;
        });
        final mounts = action(
          build(
            profiles: [
              _target,
              for (var id = 2; id <= 5; id++) _source.copyWith(id: id),
            ],
          ),
        );
        final subscription = mounts.watchPanel(1).listen((_) {});
        await waitFor(() => gates.length == 4);
        var refreshed = false;
        final refresh = mounts.readGroups(1).then((_) => refreshed = true);
        await pumpEventQueue();
        expect(refreshed, isFalse);
        await subscription.cancel();
        gates.first.complete(
          const MountSourceInspection(status: MountSourceStatus.nodes),
        );
        await refresh;
        expect(refreshed, isTrue);
        for (final gate in gates.skip(1)) {
          gate.complete(
            const MountSourceInspection(status: MountSourceStatus.nodes),
          );
        }
        await pumpEventQueue();
      },
    );

    test('with its relay list and its own panel-added names', () async {
      inspects();
      final container = build(
        managed: const [
          TailscaleManagedRecord(id: 'a', profileId: 1, name: 'Office'),
          TailscaleManagedRecord(id: 'b', profileId: 1),
          TailscaleManagedRecord(id: 'c', profileId: 2, name: 'Other'),
        ],
      );

      final panel = await action(container).watchPanel(1).last;

      verify(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
          relay: ['ts', 'Via TS'],
          managed: ['Office', ''],
        ),
      ).called(1);
      final air = panel.sources.single;
      expect(air.state, MountSourceState.relayOnly);
      expect(air.state.mountable, isFalse);
      expect(air.relayExcluded, 2);
    });

    test(
      'with the panel-added rules only when an account is attached',
      () async {
        inspects();
        final container = build(
          managed: const [
            TailscaleManagedRecord(id: 'a', profileId: 1),
            TailscaleManagedRecord(id: 'c', profileId: 2, attached: true),
          ],
        );
        await action(container).readGroups(1);
        await action(container).readGroups(2);

        verify(
          () => core.inspectMountTarget(
            base: any(named: 'base'),
            config: any(named: 'config'),
          ),
        ).called(1);
        verify(
          () => core.inspectMountTarget(
            base: any(named: 'base'),
            config: any(named: 'config'),
            managedTarget: 2,
          ),
        ).called(1);
      },
    );

    test('unread managed accounts block inspections and additions', () async {
      inspects();
      final container = build(managed: null);

      final panel = await action(container).watchPanel(1).last;
      expect(panel.groups, isNull);
      expect(panel.sources.single.state.mountable, isFalse);
      verifyNever(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
          relay: any(named: 'relay'),
          managed: any(named: 'managed'),
        ),
      );
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
