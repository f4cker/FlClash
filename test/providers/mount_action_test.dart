import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  static int revisionTick = 0;
  static int queued = 0;

  @override
  void applyProfileDebounce({bool silence = false, bool force = false}) {
    queued++;
  }

  static String config = 'proxies: []';
  static final targetInputs = <int>[];

  @override
  Future<bool> applyProfile({
    bool Function()? owns,
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applied++;
    revisionTick++;
    return result;
  }

  @override
  Future<({SetupBase? base, String? config})> mountTargetProjectionInput(
    int profileId,
  ) => mountTargetInput(profileId);

  @override
  Future<({SetupBase? base, String? config})> mountTargetInput(
    int profileId, {
    String? profilePath,
  }) async {
    targetInputs.add(profileId);
    if (profilePath != null) {
      return (
        base: null,
        config: 'built:${File(profilePath).readAsStringSync()}',
      );
    }
    return (base: null, config: config);
  }
}

class _HeldBuildSetupAction extends SetupAction {
  final ready = Completer<void>();
  final release = Completer<void>();
  var builds = 0;

  @override
  void build() {}

  @override
  Future<bool> requestAdmin(bool enableTun) async => true;

  @override
  Future<BuiltProfile> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    builds++;
    if (!ready.isCompleted) ready.complete();
    await release.future;
    return (
      yaml: 'proxies: []\nproxy-groups: []\nrules: []',
      md5: 'synthetic',
      counts: configCountsOf(const {}),
      base: null,
      ruleSources: const <RuleSource>[],
    );
  }
}

class _FakeProfilesAction extends ProfilesAction {
  static int downloads = 0;
  static final fetchedProfiles = <Profile>[];
  static Future<void> Function(int)? beforeDownload;
  static void Function()? beforeInstall;
  static String Function()? content;

  @override
  Future<Profile?> fetchSource(
    int sourceId,
    Future<Profile?> Function(
      ValidateConfig validate,
      PublishProfile publish,
      InstallProfile install,
    )
    fetch,
  ) => super.fetchSource(sourceId, (validate, publish, install) async {
    downloads++;
    await beforeDownload?.call(sourceId);
    final profile = ref.read(profilesProvider).getProfile(sourceId)!;
    fetchedProfiles.add(profile);
    return profile.saveFile(
      Uint8List.fromList((content?.call() ?? 'proxies: []').codeUnits),
      validate: validate,
      publish: publish,
      install: (publish) {
        beforeInstall?.call();
        return install(publish);
      },
    );
  });
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
    registerFallbackValue(
      const SetupParams(
        selectedMap: {},
        options: CoreOptions(testUrl: ''),
      ),
    );
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
    _FakeSetupAction.revisionTick = 0;
    _FakeSetupAction.applied = 0;
    _FakeSetupAction.queued = 0;
    _FakeProfilesAction.downloads = 0;
    _FakeProfilesAction.beforeDownload = null;
    _FakeProfilesAction.beforeInstall = null;
    _FakeProfilesAction.content = null;
    _FakeProfilesAction.fetchedProfiles.clear();
    _FakeSetupAction.config = 'proxies: []';
    _FakeSetupAction.targetInputs.clear();
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
    bool forbidSetupState = false,
    SetupAction? setup,
  }) {
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(() => TestProfiles(profiles)),
        if (forbidSetupState)
          setupStateProvider.overrideWith(
            (_, _) => throw StateError('full setup forbidden'),
          ),
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        initProvider.overrideWithBuild((_, _) => running),
        setupActionProvider.overrideWith(() => setup ?? _FakeSetupAction()),
        profilesActionProvider.overrideWith(_FakeProfilesAction.new),
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
    return mountSetupOf(
      target,
      globalState.container.read(profilesProvider),
      await appPath.profilesPath,
    ).revision;
  }

  void readsBack({bool blocked = false, bool matches = true}) {
    var lastTick = -1;
    String? revision;
    when(() => core.getMountState()).thenAnswer((_) async {
      if (lastTick != _FakeSetupAction.revisionTick) {
        revision = await runningRevision();
        lastTick = _FakeSetupAction.revisionTick;
      }
      return MountRuntimeState(
        blocked: blocked,
        report: MountReport(
          target: 1,
          revision: revision!,
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
      );
    });
  }

  test('an edit is preflighted with its mounts only when it has some, and '
      'a refusal names the subscription', () async {
    final container = build();
    final edited = Uint8List.fromList(utf8.encode('proxy-groups: []\n'));
    expect(await action(container).preflightEdit(1, edited), isNull);
    verifyNever(
      () => core.preflightMounts(
        base: any(named: 'base'),
        config: any(named: 'config'),
        mounts: any(named: 'mounts'),
      ),
    );

    await testDatabase.mountsDao.save(
      targetId: 1,
      expectedVersion: null,
      sourceIds: [2],
      pending: (version) =>
          MountOperation(kind: MountOperationKind.save, version: version),
    );
    await testDatabase.mountsDao.settle(1, 1);
    expect(await action(container).preflightEdit(1, edited), isNull);

    final calls = <Map<Symbol, Object?>>[];
    when(
      () => core.preflightMounts(
        base: any(named: 'base'),
        config: any(named: 'config'),
        mounts: any(named: 'mounts'),
      ),
    ).thenAnswer((invocation) async {
      calls.add(invocation.namedArguments);
      return const MountPreflight(error: 'mount source 2 is invalid');
    });
    expect(await action(container).preflightEdit(1, edited), (
      reason: currentAppLocalizations.mountSourceInvalidReason('Air'),
      blocking: false,
    ));
    final call = calls.single;
    expect(call[#base], isNull);
    expect(call[#config], 'built:proxy-groups: []\n');
    expect((call[#mounts] as MountSetup).sources.map((source) => source.id), [
      2,
    ]);
  });

  test('an edit the merged config refuses is held', () async {
    final container = build();
    await testDatabase.mountsDao.save(
      targetId: 1,
      expectedVersion: null,
      sourceIds: [2],
      pending: (version) =>
          MountOperation(kind: MountOperationKind.save, version: version),
    );
    await testDatabase.mountsDao.settle(1, 1);
    when(
      () => core.preflightMounts(
        base: any(named: 'base'),
        config: any(named: 'config'),
        mounts: any(named: 'mounts'),
      ),
    ).thenAnswer(
      (_) async => const MountPreflight(error: 'proxy group G: missing X'),
    );
    final issue = await action(
      container,
    ).preflightEdit(1, Uint8List.fromList(utf8.encode('rules: []')));
    expect(issue, (reason: 'proxy group G: missing X', blocking: true));
  });

  test('delayed refresh never resurrects a deleted profile', () async {
    final container = build();
    await container.read(profilesProvider.notifier).del(2);
    await container
        .read(profilesActionProvider.notifier)
        .updateProfile(_source);
    expect(container.read(profilesProvider).getProfile(2), isNull);
    expect(_FakeProfilesAction.downloads, 0);
  });

  test(
    'delayed refresh reads the latest edited URL instead of its capture',
    () async {
      final container = build();
      await mountAir(container);
      final edited = _source.copyWith(url: 'https://example.invalid/new');
      container.read(profilesProvider.notifier).put(edited);
      when(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
        ),
      ).thenAnswer(
        (_) async =>
            const MountSourceInspection(status: MountSourceStatus.nodes),
      );
      await container
          .read(profilesActionProvider.notifier)
          .updateProfile(_source);
      expect(_FakeProfilesAction.fetchedProfiles.single.url, edited.url);
      expect(container.read(profilesProvider).getProfile(2)!.url, edited.url);
    },
  );

  void nativeRefresh(
    MountRefreshOutcome outcome, {
    Future<void> Function()? beforeReply,
  }) {
    when(
      () => core.refreshMountSources(
        target: any(named: 'target'),
        generation: any(named: 'generation'),
        revision: any(named: 'revision'),
        nextRevision: any(named: 'nextRevision'),
        sources: any(named: 'sources'),
      ),
    ).thenAnswer((call) async {
      await beforeReply?.call();
      final state = await core.getMountState();
      return MountRefreshResult(
        outcome: outcome,
        state: state.copyWith(
          generation: state.generation + 1,
          report: state.report?.copyWith(
            revision: call.namedArguments[#nextRevision] as String,
          ),
        ),
      );
    });
  }

  void nodeDownloads() {
    when(
      () => core.inspectMountSource(
        any(),
        ageSecretKey: any(named: 'ageSecretKey'),
      ),
    ).thenAnswer(
      (_) async => const MountSourceInspection(status: MountSourceStatus.nodes),
    );
  }

  for (final mode in [
    'applied',
    'requiresApply',
    'inactive',
    'superseded',
    'kept',
    'unknown',
  ]) {
    test('refresh orchestration stage counts $mode', () async {
      final container = build(running: mode != 'inactive');
      readsBack();
      await mountAir(container);
      _FakeSetupAction.applied = 0;
      _FakeSetupAction.targetInputs.clear();
      var validations = 0;
      var inspections = 0;
      when(() => core.validateConfig(any())).thenAnswer((_) async {
        validations++;
        return null;
      });
      when(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
        ),
      ).thenAnswer((_) async {
        inspections++;
        return const MountSourceInspection(status: MountSourceStatus.nodes);
      });
      nativeRefresh(
        mode == 'inactive'
            ? MountRefreshOutcome.applied
            : MountRefreshOutcome.values.byName(mode),
      );
      final timer = Stopwatch()..start();
      final result = await action(container).refreshSource(2, targetId: 1);
      final returned = timer.elapsedMicroseconds;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      // Synthetic RPCs count orchestration, not Core or network latency.
      // ignore: avoid_print
      print(
        'mount-refresh $mode: downloads=${_FakeProfilesAction.downloads} validate=$validations source=$inspections target=${_FakeSetupAction.targetInputs.length} queued=${_FakeSetupAction.queued} apply=${_FakeSetupAction.applied} returnUs=$returned observedUs=${timer.elapsedMicroseconds}',
      );
      expect(result.updated, isTrue);
      expect(result.item!.state.fetched, isTrue);
      expect(_FakeProfilesAction.downloads, 1);
      expect(validations, 0);
      expect(inspections, 1);
      expect(_FakeSetupAction.targetInputs, isEmpty);
      expect(_FakeSetupAction.queued, 0);
      expect(_FakeSetupAction.applied, mode == 'requiresApply' ? 1 : 0);
      expect(result.application, switch (mode) {
        'applied' || 'requiresApply' => MountSaveOutcome.applied,
        'superseded' => MountSaveOutcome.unchanged,
        'kept' => MountSaveOutcome.applyFailedKept,
        'unknown' => MountSaveOutcome.unknown,
        _ => null,
      });
      expect(
        (await testDatabase.mountsDao.target(1))!.pending != null,
        mode == 'unknown',
      );
    });
  }

  for (final batchMode in ['simultaneous', 'update-all', 'automatic']) {
    test(
      '$batchMode source downloads fall back once for the current target',
      () async {
        const second = Profile(
          id: 3,
          type: ProfileType.url,
          label: 'Second',
          url: 'https://example.invalid/second',
          autoUpdateDuration: Duration.zero,
        );
        await testDatabase.profilesDao.putAll([second.toCompanion()]);
        final container = build(
          running: true,
          profiles: [
            _target.copyWith(type: ProfileType.file),
            _source,
            second,
          ],
        );
        readsBack();
        await testDatabase.mountsDao.save(
          targetId: 1,
          expectedVersion: null,
          sourceIds: [2, 3],
          pending: (version) =>
              MountOperation(kind: MountOperationKind.save, version: version),
        );
        await testDatabase.mountsDao.settle(1, 1);
        await core.getMountState();
        nodeDownloads();
        nativeRefresh(MountRefreshOutcome.requiresApply);
        final ready = Completer<void>();
        final release = Completer<void>();
        var started = 0;
        if (batchMode == 'simultaneous') {
          _FakeProfilesAction.beforeDownload = (_) async {
            if (++started == 2) ready.complete();
            await release.future;
          };
        }
        final profiles = container.read(profilesActionProvider.notifier);
        final refreshing = switch (batchMode) {
          'update-all' => profiles.updateProfiles(),
          'automatic' => profiles.autoUpdateProfiles(),
          _ => Future.wait([
            profiles.updateProfile(_source),
            profiles.updateProfile(second),
          ]),
        };
        if (batchMode == 'simultaneous') {
          await ready.future;
          release.complete();
        }
        await refreshing;
        expect(_FakeProfilesAction.downloads, 2);
        expect(_FakeSetupAction.applied, 1);
        expect(_FakeSetupAction.queued, 0);
        verify(
          () => core.refreshMountSources(
            target: 1,
            generation: any(named: 'generation'),
            revision: any(named: 'revision'),
            nextRevision: any(named: 'nextRevision'),
            sources: any(
              named: 'sources',
              that: containsPair(3, isA<String>()),
            ),
          ),
        ).called(1);
      },
    );
  }

  for (final renameWhen in ['before', 'during']) {
    test(
      'source rename $renameWhen download skips native and applies once',
      () async {
        final container = build(running: true);
        readsBack();
        await mountAir(container);
        _FakeSetupAction.applied = 0;
        nodeDownloads();
        void rename() => container
            .read(profilesProvider.notifier)
            .put(_source.copyWith(label: 'Renamed'));
        if (renameWhen == 'before') {
          rename();
        } else {
          _FakeProfilesAction.beforeDownload = (_) async {
            rename();
          };
        }
        final result = await action(container).refreshSource(2);
        expect(result.application, MountSaveOutcome.applied);
        expect(_FakeSetupAction.applied, 1);
        verifyNever(
          () => core.refreshMountSources(
            target: any(named: 'target'),
            generation: any(named: 'generation'),
            revision: any(named: 'revision'),
            nextRevision: any(named: 'nextRevision'),
            sources: any(named: 'sources'),
          ),
        );
      },
    );
  }

  test(
    'one source mounted by two targets only refreshes the selected target',
    () async {
      final other = _target.copyWith(id: 3, label: 'Inactive');
      await testDatabase.profilesDao.putAll([other.toCompanion()]);
      final container = build(
        running: true,
        profiles: [_target, _source, other],
      );
      readsBack();
      await mountAir(container);
      await action(container).save(3, expectedVersion: null, sourceIds: [2]);
      _FakeSetupAction.applied = 0;
      _FakeSetupAction.targetInputs.clear();
      nodeDownloads();
      nativeRefresh(MountRefreshOutcome.applied);
      final result = await action(container).refreshSource(2);
      expect(result.application, MountSaveOutcome.applied);
      expect(_FakeSetupAction.applied, 0);
      expect(_FakeSetupAction.targetInputs, isEmpty);
      expect((await testDatabase.mountsDao.target(3))!.version, 1);
      verify(
        () => core.refreshMountSources(
          target: 1,
          generation: any(named: 'generation'),
          revision: any(named: 'revision'),
          nextRevision: any(named: 'nextRevision'),
          sources: any(named: 'sources'),
        ),
      ).called(1);
    },
  );

  test(
    'overlapping refreshes share a batch but only newest intent reports success',
    () async {
      final container = build(running: true);
      readsBack();
      await mountAir(container);
      nodeDownloads();
      nativeRefresh(MountRefreshOutcome.applied);
      final oldReady = Completer<void>();
      final newReady = Completer<void>();
      final oldRelease = Completer<void>();
      var count = 0;
      _FakeProfilesAction.beforeDownload = (_) async {
        if (++count == 1) {
          oldReady.complete();
          await oldRelease.future;
        } else {
          newReady.complete();
        }
      };
      final old = action(container).refreshSource(2);
      await oldReady.future;
      final newest = action(container).refreshSource(2);
      await newReady.future;
      oldRelease.complete();
      expect((await old).updated, isFalse);
      expect((await newest).application, MountSaveOutcome.applied);
      verify(
        () => core.refreshMountSources(
          target: 1,
          generation: any(named: 'generation'),
          revision: any(named: 'revision'),
          nextRevision: any(named: 'nextRevision'),
          sources: any(named: 'sources'),
        ),
      ).called(1);
    },
  );

  test(
    'native IPC failure keeps the refresh lock and never falls back',
    () async {
      final container = build(running: true);
      readsBack();
      await mountAir(container);
      _FakeSetupAction.applied = 0;
      nodeDownloads();
      nativeRefresh(
        MountRefreshOutcome.applied,
        beforeReply: () async {
          throw const SocketException('synthetic IPC failure');
        },
      );
      final result = await action(container).refreshSource(2);
      expect(result.application, MountSaveOutcome.unknown);
      expect((await testDatabase.mountsDao.target(1))!.pending, isNotNull);
      expect(_FakeSetupAction.applied, 0);
    },
  );

  for (final scope in ['mounted', 'standalone']) {
    test('saving unrelated target never cancels $scope refresh', () async {
      final other = _target.copyWith(id: 3, label: 'Other');
      await testDatabase.profilesDao.putAll([other.toCompanion()]);
      final container = build(profiles: [_target, _source, other]);
      if (scope == 'mounted') await mountAir(container);
      nodeDownloads();
      when(() => core.validateConfig(any())).thenAnswer((_) async => null);
      final ready = Completer<void>();
      final release = Completer<void>();
      _FakeProfilesAction.beforeDownload = (_) async {
        ready.complete();
        await release.future;
      };
      final selected = scope == 'mounted' ? _source : _target;
      final refreshing = container
          .read(profilesActionProvider.notifier)
          .refreshProfile(selected);
      await ready.future;
      await action(container).save(3, expectedVersion: null, sourceIds: []);
      release.complete();
      expect((await refreshing).updated, isTrue);
      expect(
        container
            .read(profilesProvider)
            .getProfile(selected.id)!
            .lastUpdateDate,
        isNotNull,
      );
    });
  }

  test(
    'new candidate waits for held native refresh before replacing raw bytes',
    () async {
      final container = build(running: true);
      readsBack();
      await mountAir(container);
      nodeDownloads();
      _FakeSetupAction.applied = 0;
      var runtime = await core.getMountState();
      when(() => core.getMountState()).thenAnswer((_) async => runtime);
      final ready = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      when(
        () => core.refreshMountSources(
          target: any(named: 'target'),
          generation: any(named: 'generation'),
          revision: any(named: 'revision'),
          nextRevision: any(named: 'nextRevision'),
          sources: any(named: 'sources'),
        ),
      ).thenAnswer((call) async {
        calls++;
        if (calls == 1) {
          ready.complete();
          await release.future;
        }
        runtime = runtime.copyWith(
          generation: runtime.generation + 1,
          report: runtime.report!.copyWith(
            revision: call.namedArguments[#nextRevision] as String,
          ),
        );
        return MountRefreshResult(
          outcome: MountRefreshOutcome.applied,
          state: runtime,
        );
      });
      _FakeProfilesAction.content = () =>
          'proxies: []\n# download ${_FakeProfilesAction.downloads}';
      final first = action(container).refreshSource(2);
      await ready.future;
      final file = File(await appPath.getProfilePath('2'));
      final firstBytes = await file.readAsString();
      final staged = Completer<void>();
      _FakeProfilesAction.beforeInstall = () => staged.complete();
      final second = action(container).refreshSource(2);
      await staged.future;
      await pumpEventQueue();
      expect(await file.readAsString(), firstBytes);
      expect(_FakeProfilesAction.downloads, 2);
      release.complete();
      expect((await first).updated, isFalse);
      final latest = await second;
      expect(latest.updated, isTrue);
      expect(latest.application, MountSaveOutcome.applied);
      expect(await file.readAsString(), contains('# download 2'));
      expect(calls, 2);
      expect(_FakeSetupAction.applied, 0);
      expect((await testDatabase.mountsDao.target(1))!.pending, isNull);
    },
  );

  test(
    'preexisting setup can install its missing base while refresh awaits fallback',
    () async {
      await mockPreferences({'compositionRevision': 1});
      final held = _HeldBuildSetupAction();
      final container = build(running: true, setup: held);
      final targetFile = File(await appPath.getProfilePath('1'));
      if (await targetFile.exists()) await targetFile.delete();
      await testDatabase.mountsDao.save(
        targetId: 1,
        expectedVersion: null,
        sourceIds: [2],
        pending: (version) =>
            MountOperation(kind: MountOperationKind.save, version: version),
      );
      await testDatabase.mountsDao.settle(1, 1);
      readsBack();
      await core.getMountState();
      nodeDownloads();
      when(() => core.validateConfig(any())).thenAnswer((_) async => null);
      final downloadReady = Completer<void>();
      final releaseDownload = Completer<void>();
      _FakeProfilesAction.beforeDownload = (id) async {
        if (id == 1) {
          downloadReady.complete();
          await releaseDownload.future;
        }
      };
      container.read(setupActionProvider.notifier);
      var ownsFirst = true;
      final first = held.applyProfile(owns: () => ownsFirst);
      await downloadReady.future;
      final nativeReady = Completer<void>();
      nativeRefresh(
        MountRefreshOutcome.requiresApply,
        beforeReply: () async => nativeReady.complete(),
      );
      final refresh = action(container).refreshSource(2);
      await nativeReady.future;
      await pumpEventQueue();
      ownsFirst = false;
      releaseDownload.complete();
      expect(await first.timeout(const Duration(seconds: 3)), isFalse);
      expect(await targetFile.exists(), isTrue);
      await held.ready.future.timeout(const Duration(seconds: 3));
      container.read(profilesActionProvider.notifier).cancelSourceUpdate(2);
      held.release.complete();
      expect(
        (await refresh.timeout(const Duration(seconds: 3))).updated,
        isFalse,
      );
      expect(held.builds, 1);
      verifyNever(() => core.setupConfig(any()));
      expect((await testDatabase.mountsDao.target(1))!.pending, isNull);
    },
  );

  for (final stage in ['queued', 'building']) {
    test(
      'requiresApply owner invalidated while $stage never reaches setup RPC',
      () async {
        await mockPreferences({'compositionRevision': 1});
        final held = _HeldBuildSetupAction();
        final container = build(
          running: true,
          profiles: [
            _target.copyWith(type: ProfileType.file),
            _source,
          ],
          setup: held,
        );
        readsBack();
        await testDatabase.mountsDao.save(
          targetId: 1,
          expectedVersion: null,
          sourceIds: [2],
          pending: (version) =>
              MountOperation(kind: MountOperationKind.save, version: version),
        );
        await testDatabase.mountsDao.settle(1, 1);
        await core.getMountState();
        nodeDownloads();
        container.read(setupActionProvider.notifier);
        var ownsFirst = true;
        Future<bool>? first;
        if (stage == 'queued') {
          first = held.applyProfile(owns: () => ownsFirst);
          await held.ready.future;
        }
        final nativeReady = Completer<void>();
        nativeRefresh(
          MountRefreshOutcome.requiresApply,
          beforeReply: () async {
            nativeReady.complete();
          },
        );
        final refreshing = action(container).refreshSource(2);
        await nativeReady.future;
        if (stage == 'building') await held.ready.future;
        await pumpEventQueue();
        expect(
          (await action(container).recheck(1)).outcome,
          MountSaveOutcome.locked,
        );
        expect((await testDatabase.mountsDao.target(1))!.pending, isNotNull);
        container.read(profilesActionProvider.notifier).cancelSourceUpdate(2);
        ownsFirst = false;
        held.release.complete();
        final result = await refreshing;
        if (first != null) expect(await first, isFalse);
        expect(result.updated, isFalse);
        expect(held.builds, 1);
        verifyNever(() => core.setupConfig(any()));
        expect((await testDatabase.mountsDao.target(1))!.pending, isNull);
      },
    );
  }

  for (final intent in ['newer-refresh', 'switch', 'unmount', 'delete']) {
    test(
      'requiresApply never falls back after $intent intent supersedes it',
      () async {
        final container = build(running: true);
        readsBack();
        await mountAir(container);
        _FakeSetupAction.applied = 0;
        nodeDownloads();
        final ready = Completer<void>();
        final release = Completer<void>();
        nativeRefresh(
          MountRefreshOutcome.requiresApply,
          beforeReply: () async {
            ready.complete();
            await release.future;
          },
        );
        final refreshing = action(container).refreshSource(2);
        await ready.future;
        Future<MountSaveResult>? removing;
        switch (intent) {
          case 'switch':
            container.read(currentProfileIdProvider.notifier).value = 2;
          case 'newer-refresh':
            container
                .read(profilesActionProvider.notifier)
                .cancelSourceUpdate(2);
          case 'unmount':
            removing = action(container).save(
              1,
              expectedVersion: (await testDatabase.mountsDao.target(
                1,
              ))!.version,
              sourceIds: [],
            );
          case 'delete':
            container
                .read(profilesActionProvider.notifier)
                .cancelSourceUpdate(2);
            await container.read(profilesProvider.notifier).del(2);
        }
        release.complete();
        final result = await refreshing;
        expect(result.application, anyOf(isNull, MountSaveOutcome.unchanged));
        if (removing != null) await removing;
        expect(_FakeSetupAction.applied, intent == 'unmount' ? 1 : 0);
      },
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
        () => core.inspectMountTargetProjection(
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

    test('downloads never prewarm target or source inspections', () async {
      inspects();
      final container = build();
      when(() => core.validateConfig(any())).thenAnswer((_) async => null);
      final profiles = container.read(profilesActionProvider.notifier);
      final updated = await profiles.fetchSource(2, (_, _, _) async => _source);
      expect(updated, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(_FakeSetupAction.targetInputs, isEmpty);
      verifyNever(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
          relay: any(named: 'relay'),
          managed: any(named: 'managed'),
        ),
      );
    });

    test('inspection overlaps within a bound and keeps source order', () async {
      inspects();
      final targetRead = Completer<void>();
      when(
        () => core.inspectMountTargetProjection(
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

    test('actual panel entry never initializes full setup inputs', () async {
      inspects();
      final panel = await action(
        build(forbidSetupState: true),
      ).watchPanel(1).last;
      expect(panel.groupsPending, isFalse);
      expect(panel.sources.single.state, isNot(MountSourceState.unreadable));
      verifyNever(() => core.getProfileBase(any()));
      verifyNever(
        () => core.buildProfile(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      );
    });

    test('metadata is published before the target RPC resolves', () async {
      inspects();
      final target = Completer<MountTarget>();
      when(
        () => core.inspectMountTargetProjection(
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
          () => core.inspectMountTargetProjection(
            base: any(named: 'base'),
            config: any(named: 'config'),
          ),
        ).called(1);
        verify(
          () => core.inspectMountTargetProjection(
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
