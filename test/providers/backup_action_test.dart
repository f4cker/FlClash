import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/restore_journal.dart';
import 'package:fl_clash/common/restore_mount_plan.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart' show initProvider;
import 'package:fl_clash/providers/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';

Profile _profile(int id, String label) =>
    Profile(id: id, label: label, autoUpdateDuration: Duration.zero);

Profile _sub(int id, String label) => _profile(
  id,
  label,
).copyWith(type: ProfileType.url, url: 'https://example.invalid/$id');

/// Refused because a mount operation is pending; nothing was written.
Matcher _pendingRefusal([List<int>? profileIds]) => throwsA(
  isA<RestoreBlockedException>()
      .having((e) => e.reason, 'reason', RestoreBlockedReason.mountPending)
      .having(
        (e) => e.profileIds,
        'profileIds',
        profileIds ?? isA<List<int>>(),
      ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDatabase;
  late Directory home;

  setUpAll(() async {
    await mockPreferences({'version': 1});
    loadAppLocalizations(const Locale('en'));
    home = Directory.systemTemp.createTempSync('flclash-backup-action-');
    await useAppPaths(home);
  });

  tearDownAll(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  setUp(() {
    testDatabase = Database(NativeDatabase.memory());
    database = testDatabase;
  });

  tearDown(() async {
    await testDatabase.close();
  });

  // AppStateManager's listen keeps the settings alive while a restore awaits.
  ProviderContainer buildContainer() {
    final container = ProviderContainer()..listen(configProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  BackupAction actionOf(ProviderContainer container) =>
      container.read(backupActionProvider.notifier);

  Map<String, Object?> configMapOf(ProviderContainer container) =>
      jsonDecode(jsonEncode(container.read(configProvider).toJson()))
          as Map<String, Object?>;

  test(
    'settings-only restore respects pending mounts without clearing data',
    () async {
      const profile = Profile(id: 1, autoUpdateDuration: Duration.zero);
      await testDatabase.profilesDao.putAll([profile.toCompanion()]);
      final mount = await testDatabase.mountsDao.save(
        targetId: 1,
        expectedVersion: null,
        sourceIds: [],
        pending: (version) =>
            MountOperation(kind: MountOperationKind.save, version: version),
      );
      final container = buildContainer();
      container.read(currentProfileIdProvider.notifier).value = 1;
      container
          .read(appSettingProvider.notifier)
          .update(
            (state) =>
                state.copyWith(restoreStrategy: RestoreStrategy.override),
          );
      final config = configMapOf(container)..['currentProfileId'] = 42;
      await expectLater(
        actionOf(
          container,
        ).applyRestore(MigrationData(configMap: config), RestoreOption.all),
        _pendingRefusal(),
      );
      expect(container.read(currentProfileIdProvider), 1);
      expect(await testDatabase.mountsDao.target(1), mount);
      expect((await testDatabase.profilesDao.query().get()).single.id, 1);
      await testDatabase.mountsDao.settle(1, mount.version);
      await actionOf(
        container,
      ).applyRestore(MigrationData(configMap: config), RestoreOption.all);
      expect(container.read(currentProfileIdProvider), 42);
      expect((await testDatabase.profilesDao.query().get()).single.id, 1);
    },
  );

  group('restore publishes files only once mount guards accept it', () {
    late Directory staging;

    setUp(() {
      staging = Directory.systemTemp.createTempSync('flclash-staging-');
      addTearDown(() => staging.deleteSync(recursive: true));
      final journals = Directory(RestoreJournal.rootOf(home.path));
      if (journals.existsSync()) journals.deleteSync(recursive: true);
    });

    Future<File> liveProfile(int id) async =>
        File(await appPath.getProfilePath('$id'))
          ..createSync(recursive: true)
          ..writeAsStringSync('live');

    void stageProfile(int id) =>
        File(BackupEntries.resolve(staging.path, BackupEntries.profile(id)))
          ..createSync(recursive: true)
          ..writeAsStringSync('from backup');

    // Publication first opens a journal, which keeps the files it replaces,
    // so this shows that no live file was overwritten, even briefly and then
    // put back.
    bool published() =>
        Directory(RestoreJournal.rootOf(home.path)).existsSync();

    Future<MountTargetState> pendingMount(int targetId, List<int> sources) =>
        testDatabase.mountsDao.save(
          targetId: targetId,
          expectedVersion: null,
          sourceIds: sources,
          pending: (version) => MountOperation(
            kind: MountOperationKind.save,
            version: version,
            sourceIds: sources,
          ),
        );

    test('a pending mount leaves the live yaml untouched', () async {
      await testDatabase.profilesDao.putAll([
        _profile(77701, 'Target').toCompanion(0),
      ]);
      final live = await liveProfile(77701);
      await pendingMount(77701, []);
      stageProfile(77701);
      final action = actionOf(buildContainer());
      var reachedPublish = false;
      action.beforeRestorePublish = () async => reachedPublish = true;

      await expectLater(
        action.applyRestore(
          MigrationData(profiles: [_profile(77701, 'Restored')]),
          RestoreOption.onlyProfiles,
          stagingDirPath: staging.path,
        ),
        _pendingRefusal(),
      );

      expect(reachedPublish, isFalse);
      expect(published(), isFalse);
      expect(live.readAsStringSync(), 'live');
      expect(
        (await testDatabase.profilesDao.query().get())
            .singleWhere((p) => p.id == 77701)
            .label,
        'Target',
      );
    });

    Future<MountTargetState> settledMount(
      int targetId,
      List<int> sources,
    ) async {
      final mount = await pendingMount(targetId, sources);
      await testDatabase.mountsDao.settle(targetId, mount.version);
      return (await testDatabase.mountsDao.target(targetId))!;
    }

    ProviderContainer withStrategy(RestoreStrategy strategy) {
      final container = buildContainer();
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(restoreStrategy: strategy));
      return container;
    }

    test('a merge over a mounted source keeps the relation, bumps the '
        'version and settles a target that is not running', () async {
      await testDatabase.profilesDao.putAll([
        _profile(77711, 'Target').toCompanion(0),
        _sub(77712, 'Source').toCompanion(1),
      ]);
      final live = await liveProfile(77712);
      final before = await settledMount(77711, [77712]);
      stageProfile(77712);
      final action = actionOf(withStrategy(RestoreStrategy.compatible));
      RestoreMountPlan? shown;

      final result = await action.applyRestore(
        MigrationData(profiles: [_sub(77712, 'Restored')]),
        RestoreOption.onlyProfiles,
        stagingDirPath: staging.path,
        confirm: (plan) async {
          shown = plan;
          return true;
        },
      );

      expect(shown, isNotNull, reason: 'a plan touching mounts is shown');
      expect(shown!.hasLosses, isFalse);
      expect(result!.plan.kept.single.origin, RestoreMountOrigin.local);
      expect(result.stillPending, isEmpty);
      expect(live.readAsStringSync(), 'from backup');
      final after = (await testDatabase.mountsDao.target(77711))!;
      expect(after.sourceIds, [77712]);
      expect(after.version, before.version + 1);
      expect(after.pending, isNull);
      // A panel still holding the old version can no longer save.
      await expectLater(
        testDatabase.mountsDao.save(
          targetId: 77711,
          expectedVersion: before.version,
          sourceIds: const [],
          pending: (v) =>
              MountOperation(kind: MountOperationKind.save, version: v),
        ),
        throwsA(isA<MountVersionConflict>()),
      );
    });

    test('an override that removes relations needs confirmation; cancel '
        'writes nothing', () async {
      await testDatabase.profilesDao.putAll([
        _profile(77751, 'Target').toCompanion(0),
        _sub(77752, 'Source').toCompanion(1),
      ]);
      final targetFile = await liveProfile(77751);
      final settled = await settledMount(77751, [77752]);
      stageProfile(77751);
      final action = actionOf(withStrategy(RestoreStrategy.override));
      var reachedPublish = false;
      action.beforeRestorePublish = () async => reachedPublish = true;
      final data = MigrationData(
        profiles: [_profile(77751, 'Restored')],
        mountsCarried: true,
        mountTargets: [
          MountTargetState(targetId: 77751, sourceIds: [77752], version: 4),
        ],
      );

      RestoreMountPlan? declined;
      final cancelled = await action.applyRestore(
        data,
        RestoreOption.onlyProfiles,
        stagingDirPath: staging.path,
        confirm: (plan) async {
          declined = plan;
          return false;
        },
      );

      expect(cancelled, isNull);
      expect(
        declined!.removals.single.reason,
        RestoreMountReason.sourceMissing,
      );
      expect(declined!.removals.single.relation.source.label, 'Source');
      expect(reachedPublish, isFalse);
      expect(published(), isFalse);
      expect(targetFile.readAsStringSync(), 'live');
      expect(await testDatabase.mountsDao.target(77751), settled);
      expect(
        (await testDatabase.profilesDao.query().get()).map((p) => p.id),
        unorderedEquals([77751, 77752]),
      );

      // Without a confirmer, losses are never written.
      expect(
        await action.applyRestore(
          data,
          RestoreOption.onlyProfiles,
          stagingDirPath: staging.path,
        ),
        isNull,
      );
      expect(published(), isFalse);

      final result = await action.applyRestore(
        data,
        RestoreOption.onlyProfiles,
        stagingDirPath: staging.path,
        confirm: (_) async => true,
      );

      expect(result!.plan.removals.single.reason.id, 'source-missing');
      expect(targetFile.readAsStringSync(), 'from backup');
      final after = (await testDatabase.mountsDao.target(77751))!;
      expect(after.sourceIds, isEmpty, reason: 'the row stays as a guard');
      expect(after.version, 5, reason: 'max(local 1, backup 4) + 1');
      expect((await testDatabase.profilesDao.query().get()).map((p) => p.id), [
        77751,
      ]);
    });

    test(
      'a compatible conflict is replaced by the backup, never merged',
      () async {
        await testDatabase.profilesDao.putAll([
          _profile(77771, 'Target').toCompanion(0),
          _sub(77772, 'A').toCompanion(1),
          _sub(77773, 'X').toCompanion(2),
          _sub(77774, 'Y').toCompanion(3),
        ]);
        await settledMount(77771, [77772, 77773]);
        final action = actionOf(withStrategy(RestoreStrategy.compatible));
        RestoreMountPlan? shown;

        final result = await action.applyRestore(
          MigrationData(
            profiles: [_profile(77771, 'Target')],
            mountsCarried: true,
            mountTargets: [
              MountTargetState(
                targetId: 77771,
                sourceIds: [77772, 77774],
                version: 1,
              ),
            ],
          ),
          RestoreOption.onlyProfiles,
          confirm: (plan) async {
            shown = plan;
            return true;
          },
        );

        final replacement = shown!.replacements.single;
        expect(replacement.before.map((p) => p.id), [77772, 77773]);
        expect(replacement.after.map((p) => p.id), [77772, 77774]);
        expect(shown!.removals, isEmpty);
        expect(result, isNotNull);
        expect((await testDatabase.mountsDao.target(77771))!.sourceIds, [
          77772,
          77774,
        ]);
      },
    );

    test('a backup without mount data keeps local relations', () async {
      await testDatabase.profilesDao.putAll([
        _profile(77781, 'Target').toCompanion(0),
        _sub(77782, 'Source').toCompanion(1),
      ]);
      final before = await settledMount(77781, [77782]);
      final action = actionOf(withStrategy(RestoreStrategy.override));

      final result = await action.applyRestore(
        MigrationData(
          profiles: [_profile(77781, 'Target'), _sub(77782, 'Source')],
        ),
        RestoreOption.onlyProfiles,
      );

      expect(result!.plan.mountsCarried, isFalse);
      expect(result.plan.hasLosses, isFalse);
      final after = (await testDatabase.mountsDao.target(77781))!;
      expect(after.sourceIds, [77782]);
      expect(after.version, before.version + 1);
    });

    test('mounts changing after confirmation stop the restore before any '
        'write', () async {
      await testDatabase.profilesDao.putAll([
        _profile(77791, 'Target').toCompanion(0),
        _sub(77792, 'Source').toCompanion(1),
      ]);
      final live = await liveProfile(77792);
      await settledMount(77791, [77792]);
      stageProfile(77792);
      final action = actionOf(withStrategy(RestoreStrategy.compatible));

      await expectLater(
        action.applyRestore(
          MigrationData(profiles: [_sub(77792, 'Restored')]),
          RestoreOption.onlyProfiles,
          stagingDirPath: staging.path,
          confirm: (_) async {
            final current = await testDatabase.mountsDao.target(77791);
            final saved = await testDatabase.mountsDao.save(
              targetId: 77791,
              expectedVersion: current!.version,
              sourceIds: const [],
              pending: (v) =>
                  MountOperation(kind: MountOperationKind.save, version: v),
            );
            await testDatabase.mountsDao.settle(77791, saved.version);
            return true;
          },
        ),
        throwsA(
          isA<RestoreBlockedException>().having(
            (e) => e.reason,
            'reason',
            RestoreBlockedReason.mountStateChanged,
          ),
        ),
      );
      expect(published(), isFalse);
      expect(live.readAsStringSync(), 'live');
    });

    test('a running target stays locked until checked, and blocks the next '
        'restore by name', () async {
      await testDatabase.profilesDao.putAll([
        _profile(77801, 'Running').toCompanion(0),
        _sub(77802, 'Source').toCompanion(1),
      ]);
      await settledMount(77801, [77802]);
      final container = withStrategy(RestoreStrategy.compatible);
      container.read(initProvider.notifier).value = true;
      container.read(currentProfileIdProvider.notifier).value = 77801;
      final action = actionOf(container);

      final result = await action.applyRestore(
        MigrationData(profiles: [_sub(77802, 'Restored')]),
        RestoreOption.onlyProfiles,
      );

      expect(result!.stillPending.map((p) => p.id), [77801]);
      expect((await testDatabase.mountsDao.target(77801))!.pending, isNotNull);
      await expectLater(
        action.applyRestore(
          MigrationData(profiles: [_sub(77802, 'Again')]),
          RestoreOption.onlyProfiles,
        ),
        allOf(
          _pendingRefusal([77801]),
          throwsA(
            isA<RestoreBlockedException>().having(
              (e) => e.message,
              'message',
              contains('Running'),
            ),
          ),
        ),
      );
    });

    test(
      'a failure inside the transaction rolls the mount rows back too',
      () async {
        await testDatabase.profilesDao.putAll([
          _profile(77811, 'Target').toCompanion(0),
          _sub(77812, 'Source').toCompanion(1),
        ]);
        final settled = await settledMount(77811, [77812]);
        final action = actionOf(withStrategy(RestoreStrategy.compatible));
        testDatabase.beforeRestoreCommit = () async => throw StateError('boom');
        addTearDown(() => testDatabase.beforeRestoreCommit = null);

        await expectLater(
          action.applyRestore(
            MigrationData(profiles: [_sub(77812, 'Restored')]),
            RestoreOption.onlyProfiles,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await testDatabase.mountsDao.target(77811), settled);
        expect(
          (await testDatabase.profilesDao.query().get())
              .singleWhere((p) => p.id == 77812)
              .label,
          'Source',
        );
      },
    );

    test('a mount operation running first is seen by the guard', () async {
      await testDatabase.profilesDao.putAll([
        _profile(77721, 'Target').toCompanion(0),
      ]);
      final live = await liveProfile(77721);
      stageProfile(77721);
      final container = buildContainer();
      final entered = Completer<void>();
      final release = Completer<void>();
      // Stands in for a save that stores its pending record and then applies.
      final operation = container
          .read(mountActionProvider.notifier)
          .runExclusive(() async {
            entered.complete();
            await release.future;
            await pendingMount(77721, []);
          });
      await entered.future;
      final rejected = expectLater(
        actionOf(container).applyRestore(
          MigrationData(profiles: [_profile(77721, 'Restored')]),
          RestoreOption.onlyProfiles,
          stagingDirPath: staging.path,
        ),
        _pendingRefusal(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(published(), isFalse);
      expect(live.readAsStringSync(), 'live');

      release.complete();
      await operation;
      await rejected;

      expect(published(), isFalse);
      expect(live.readAsStringSync(), 'live');
    });

    test('a mount operation cannot start mid-restore', () async {
      final live = await liveProfile(77731);
      stageProfile(77731);
      final container = buildContainer();
      final action = actionOf(container);
      final entered = Completer<void>();
      final release = Completer<void>();
      action.beforeRestorePublish = () async {
        entered.complete();
        await release.future;
      };
      final restore = action.applyRestore(
        MigrationData(profiles: [_profile(77731, 'Restored')]),
        RestoreOption.onlyProfiles,
        stagingDirPath: staging.path,
      );
      await entered.future;
      String? seenByMount;
      final mount = container
          .read(mountActionProvider.notifier)
          .installSource(77731, () => seenByMount = live.readAsStringSync());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(seenByMount, isNull);

      release.complete();
      await restore;
      await mount;

      expect(seenByMount, 'from backup');
      expect(
        (await testDatabase.profilesDao.query().get())
            .singleWhere((p) => p.id == 77731)
            .label,
        'Restored',
      );
    });
  });

  test('postcommit work remains fenced against later restores', () async {
    final action = actionOf(buildContainer());
    final entered = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    action.afterRestoreCommit = () async {
      if (calls++ == 0) {
        entered.complete();
        await release.future;
      }
    };
    final first = action.applyRestore(
      MigrationData(profiles: [_profile(88883, 'first')]),
      RestoreOption.onlyProfiles,
    );
    await entered.future;
    final second = action.applyRestore(
      MigrationData(profiles: [_profile(88884, 'second')]),
      RestoreOption.onlyProfiles,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await testDatabase.profilesDao.query().get()).map((p) => p.id),
      isNot(contains(88884)),
    );
    release.complete();
    await first;
    await second;
    expect(
      (await testDatabase.profilesDao.query().get()).map((p) => p.id),
      contains(88884),
    );
  });

  test('postcommit exception reports committed database', () async {
    final action = actionOf(buildContainer());
    action.afterRestoreCommit = () async => throw StateError('injected');
    await expectLater(
      action.applyRestore(
        MigrationData(profiles: [_profile(88885, 'committed')]),
        RestoreOption.onlyProfiles,
      ),
      throwsA(
        isA<RestorePartialException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('has been restored'),
            isNot(contains('was not changed')),
          ),
        ),
      ),
    );
    expect(
      (await testDatabase.profilesDao.query().get()).map((p) => p.id),
      contains(88885),
    );
  });

  test('restore waits for added-rule lane before publishing rows', () async {
    final container = buildContainer();
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocked = container
        .read(addedRulesActionProvider.notifier)
        .runRestoreInLane(() async {
          entered.complete();
          await release.future;
        });
    await entered.future;
    final restore = actionOf(container).applyRestore(
      MigrationData(profiles: [_profile(88881, 'Pending')]),
      RestoreOption.onlyProfiles,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await testDatabase.profilesDao.query().get()).where(
        (p) => p.id == 88881,
      ),
      isEmpty,
    );
    release.complete();
    await blocked;
    await restore;
    expect(
      (await testDatabase.profilesDao.query().get()).where(
        (p) => p.id == 88881,
      ),
      hasLength(1),
    );
  });

  test('restore waits for setup apply fence before publishing rows', () async {
    final container = buildContainer();
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocked = container
        .read(setupActionProvider.notifier)
        .runRestoreBeforeApply(() async {
          entered.complete();
          await release.future;
        });
    await entered.future;
    final restore = actionOf(container).applyRestore(
      MigrationData(profiles: [_profile(88882, 'Pending')]),
      RestoreOption.onlyProfiles,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await testDatabase.profilesDao.query().get()).where(
        (p) => p.id == 88882,
      ),
      isEmpty,
    );
    release.complete();
    await blocked;
    await restore;
    expect(
      (await testDatabase.profilesDao.query().get()).where(
        (p) => p.id == 88882,
      ),
      hasLength(1),
    );
  });

  test('restore without cache associates a new reserved generation', () async {
    const set = AddedRuleSet(
      id: 98761,
      profileId: 98760,
      name: 'ads',
      url: 'https://example.test/ads',
      cacheGeneration: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    const rule = Rule(
      id: 98761,
      profileId: 98760,
      ruleAction: RuleAction.RULE_SET,
      ruleProvider: 'ads',
      ruleTarget: 'REJECT',
      order: 'a',
    );
    final old = File(set.pathUnder(join(home.path, 'profiles')));
    await old.parent.create(recursive: true);
    await old.writeAsString('foreign');
    await actionOf(buildContainer()).applyRestore(
      MigrationData(
        profiles: [_profile(98760, 'Test')],
        rules: [rule],
        addedRuleSets: [set],
      ),
      RestoreOption.onlyProfiles,
    );
    final restored =
        (await testDatabase.addedRuleSetsDao.query(98760).get()).single;
    expect(restored.cacheGeneration, isNot(set.cacheGeneration));
    expect(await old.readAsString(), 'foreign');
    expect(
      await File(restored.pathUnder(join(home.path, 'profiles'))).exists(),
      isFalse,
    );
  });

  test('failed database restore preserves existing cache and rows', () async {
    const set = AddedRuleSet(
      id: 98763,
      profileId: 98762,
      name: 'ads',
      url: 'https://example.test/ads',
    );
    final old = File(set.pathUnder(join(home.path, 'profiles')));
    await old.parent.create(recursive: true);
    await old.writeAsString('foreign');
    await testDatabase.customStatement(
      "CREATE TRIGGER reject_added BEFORE INSERT ON added_rule_sets BEGIN SELECT RAISE(ABORT, 'blocked'); END",
    );
    await expectLater(
      actionOf(buildContainer()).applyRestore(
        MigrationData(
          profiles: [_profile(98762, 'Test')],
          addedRuleSets: [set],
        ),
        RestoreOption.onlyProfiles,
      ),
      throwsA(anything),
    );
    expect(await old.readAsString(), 'foreign');
    expect(await testDatabase.addedRuleSetsDao.query(98762).get(), isEmpty);
    expect(
      (await testDatabase.profilesDao.query().get()).where(
        (p) => p.id == 98762,
      ),
      isEmpty,
    );
  });

  group('backup and restore round trip', () {
    late Directory kept;

    setUp(() {
      kept = Directory.systemTemp.createTempSync('flclash-backup-kept-');
      addTearDown(() => kept.deleteSync(recursive: true));
    });

    Set<String> workDirs() => home
        .listSync()
        .map((entity) => basename(entity.path))
        .where((name) => name.startsWith('backup'))
        .toSet();

    Future<String> backupToKept(BackupAction action) async {
      final keptPath = join(kept.path, 'kept.zip');
      final delivered = await action.backup((archivePath) async {
        File(archivePath).copySync(keptPath);
        return true;
      });
      expect(delivered, isTrue);
      return keptPath;
    }

    test('restores the rows, files and settings a backup carries', () async {
      await testDatabase.profilesDao.putAll([
        _profile(1, 'Backed up').toCompanion(0),
      ]);
      final profileFile = File(await appPath.getProfilePath('1'))
        ..createSync(recursive: true)
        ..writeAsStringSync('proxies: []');
      final source = buildContainer();
      source.read(excludeSSIDsProvider.notifier).value = ['home-wifi'];
      final archivePath = await backupToKept(actionOf(source));

      await testDatabase.delete(testDatabase.profiles).go();
      profileFile.deleteSync();
      final target = buildContainer();
      final restored = await actionOf(
        target,
      ).restore(RestoreOption.all, (_) async => archivePath);

      expect(restored, isTrue);
      final stored = await testDatabase.profilesDao.query().get();
      expect(stored.map((item) => item.label), ['Backed up']);
      expect(profileFile.readAsStringSync(), 'proxies: []');
      expect(target.read(excludeSSIDsProvider), ['home-wifi']);
      expect(workDirs(), isEmpty);
    });

    test('a rejected archive restore leaves the live yaml untouched', () async {
      await testDatabase.profilesDao.putAll([
        _profile(77741, 'Target').toCompanion(0),
      ]);
      final live = File(await appPath.getProfilePath('77741'))
        ..createSync(recursive: true)
        ..writeAsStringSync('from backup');
      final archivePath = await backupToKept(actionOf(buildContainer()));
      live.writeAsStringSync('live');
      await testDatabase.mountsDao.save(
        targetId: 77741,
        expectedVersion: null,
        sourceIds: [],
        pending: (version) =>
            MountOperation(kind: MountOperationKind.save, version: version),
      );

      await expectLater(
        actionOf(
          buildContainer(),
        ).restore(RestoreOption.onlyProfiles, (_) async => archivePath),
        _pendingRefusal(),
      );

      expect(live.readAsStringSync(), 'live');
      expect(workDirs(), isEmpty);
    });

    test('restores a version zero archive with a profile file', () async {
      final archivePath = join(kept.path, 'legacy.zip');
      final encoder = ZipFileEncoder()..create(archivePath);
      encoder.addArchiveFile(
        ArchiveFile.string(
          configJsonName,
          jsonEncode({
            'profiles': [
              {'id': 'legacy', 'label': 'Old', 'autoUpdateDuration': 0},
            ],
            'scripts': [],
            'rules': [],
          }),
        ),
      );
      encoder.addArchiveFile(
        ArchiveFile.string('profiles/legacy.yaml', 'proxies: []'),
      );
      await encoder.close();

      expect(
        await actionOf(
          buildContainer(),
        ).restore(RestoreOption.onlyProfiles, (_) async => archivePath),
        isTrue,
      );
      final profile = (await testDatabase.profilesDao.query().get()).single;
      expect(profile.label, 'Old');
      expect(
        await File(
          await appPath.getProfilePath('${profile.id}'),
        ).readAsString(),
        'proxies: []',
      );
      expect(await testDatabase.addedRuleSetsDao.queryAll().get(), isEmpty);
    });

    test('brings back the attachments of local modules and cleans the '
        'rest', () async {
      final module = MitmModule(
        id: 9,
        name: 'Mine',
        resources: const {'own.json': 'own.json'},
        lastUpdateTime: DateTime(2026),
      );
      await testDatabase.mitmModulesDao.putAll([module.toCompanion()]);
      File(join(home.path, 'mitm', 'modules', module.fileName))
        ..createSync(recursive: true)
        ..writeAsStringSync('[Map Local]\n^https://a data="own.json"\n');
      final resources = join(home.path, 'mitm', 'resources');
      final own = File(join(resources, 'own.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      final archivePath = await backupToKept(actionOf(buildContainer()));

      own.deleteSync();
      final stale = File(join(resources, 'stale.json'))..writeAsStringSync('');
      final target = buildContainer();
      final restored = await actionOf(
        target,
      ).restore(RestoreOption.all, (_) async => archivePath);

      expect(restored, isTrue);
      expect(own.readAsStringSync(), '{}');
      expect(stale.existsSync(), isFalse);
    });

    test('removes the work directory when delivery fails', () async {
      final container = buildContainer();

      await expectLater(
        actionOf(
          container,
        ).backup((_) async => throw const SocketException('offline')),
        throwsA(isA<SocketException>()),
      );

      expect(workDirs(), isEmpty);
    });

    test('a cancelled fetch changes nothing', () async {
      final container = buildContainer();

      final restored = await actionOf(
        container,
      ).restore(RestoreOption.all, (_) async => null);

      expect(restored, isFalse);
    });

    test('an unreadable archive is reported and changes nothing', () async {
      await testDatabase.profilesDao.putAll([
        _profile(9, 'Pre-existing').toCompanion(0),
      ]);
      final bogus = File(join(kept.path, 'bogus.zip'))
        ..writeAsStringSync('not a zip');
      final container = buildContainer();

      await expectLater(
        actionOf(container).restore(RestoreOption.all, (_) async => bogus.path),
        throwsA(
          isA<MessageException>().having(
            (error) => error.message,
            'message',
            currentAppLocalizations.invalidBackupFile,
          ),
        ),
      );

      final stored = await testDatabase.profilesDao.query().get();
      expect(stored.map((item) => item.label), ['Pre-existing']);
      expect(workDirs(), isEmpty);
    });

    test('removes the staging an earlier version left behind', () async {
      final legacyArchive = File(join(home.path, 'backup.zip'))
        ..writeAsStringSync('stale');
      final legacyStaging = Directory(join(home.path, 'restore'))..createSync();
      final container = buildContainer();

      await actionOf(container).restore(RestoreOption.all, (_) async => null);

      expect(legacyArchive.existsSync(), isFalse);
      expect(legacyStaging.existsSync(), isFalse);
    });
  });

  group('applyRestore writes the database', () {
    test('inserts the profiles the backup carries', () async {
      final container = buildContainer();

      await actionOf(container).applyRestore(
        MigrationData(profiles: [_profile(1, 'From backup')]),
        RestoreOption.onlyProfiles,
      );

      final stored = await testDatabase.profilesDao.query().get();
      expect(stored.map((item) => item.label), ['From backup']);
    });

    test('an override restore drops profiles the backup omits', () async {
      final container = buildContainer();
      await testDatabase.profilesDao.putAll([
        _profile(9, 'Pre-existing').toCompanion(0),
      ]);
      container
          .read(appSettingProvider.notifier)
          .update(
            (state) =>
                state.copyWith(restoreStrategy: RestoreStrategy.override),
          );

      await actionOf(container).applyRestore(
        MigrationData(profiles: [_profile(1, 'From backup')]),
        RestoreOption.onlyProfiles,
      );

      final stored = await testDatabase.profilesDao.query().get();
      expect(stored.map((item) => item.label), ['From backup']);
    });

    test('a compatible restore keeps profiles the backup omits', () async {
      final container = buildContainer();
      await testDatabase.profilesDao.putAll([
        _profile(9, 'Pre-existing').toCompanion(0),
      ]);
      container
          .read(appSettingProvider.notifier)
          .update(
            (state) =>
                state.copyWith(restoreStrategy: RestoreStrategy.compatible),
          );

      await actionOf(container).applyRestore(
        MigrationData(profiles: [_profile(1, 'From backup')]),
        RestoreOption.onlyProfiles,
      );

      final stored = await testDatabase.profilesDao.query().get();
      expect(stored.map((item) => item.label).toSet(), {
        'Pre-existing',
        'From backup',
      });
    });

    test('a restore drops the cache of a provider it replaced', () async {
      const dropped = ClashProvider(
        id: 5,
        label: 'Dropped',
        url: 'https://example.com/dropped.yaml',
      );
      const kept = ClashProvider(id: 6, label: 'Kept');
      await testDatabase.clashProvidersDao.putAll(
        [dropped, kept].map((item) => item.toCompanion()),
      );
      for (final path in [
        await dropped.path,
        await dropped.compiledPath,
        await kept.path,
        await kept.compiledPath,
      ]) {
        File(path).createSync(recursive: true);
      }
      final container = buildContainer();
      container
          .read(appSettingProvider.notifier)
          .update(
            (state) =>
                state.copyWith(restoreStrategy: RestoreStrategy.override),
          );

      await actionOf(container).applyRestore(
        const MigrationData(clashProviders: [kept]),
        RestoreOption.onlyProfiles,
      );

      expect(File(await dropped.path).existsSync(), isFalse);
      expect(File(await dropped.compiledPath).existsSync(), isFalse);
      expect(File(await kept.path).existsSync(), isTrue);
      expect(
        File(await kept.compiledPath).existsSync(),
        isFalse,
        reason: 'the restored source is compiled again on first use',
      );
    });

    test('rows that fail to restore take their files back out', () async {
      final replaced = File(await appPath.getProfilePath('41'))
        ..createSync(recursive: true)
        ..writeAsStringSync('current');
      final added = File(await appPath.getProfilePath('42'));
      final staging = Directory.systemTemp.createTempSync('flclash-staging-');
      addTearDown(() => staging.deleteSync(recursive: true));
      for (final id in [41, 42]) {
        File(BackupEntries.resolve(staging.path, BackupEntries.profile(id)))
          ..createSync(recursive: true)
          ..writeAsStringSync('from backup');
      }
      await testDatabase.customStatement(
        'CREATE TRIGGER refuse_profiles BEFORE INSERT ON profiles '
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      await expectLater(
        actionOf(buildContainer()).applyRestore(
          MigrationData(profiles: [_profile(41, 'One'), _profile(42, 'Two')]),
          RestoreOption.onlyProfiles,
          stagingDirPath: staging.path,
        ),
        throwsA(anything),
      );

      expect(replaced.readAsStringSync(), 'current');
      expect(added.existsSync(), isFalse);
    });

    test('duplicate file entries retain the original on rollback', () async {
      final target = File(await appPath.getProfilePath('43'))
        ..createSync(recursive: true)
        ..writeAsStringSync('current');
      final staging = Directory.systemTemp.createTempSync('flclash-staging-');
      addTearDown(() => staging.deleteSync(recursive: true));
      File(BackupEntries.resolve(staging.path, BackupEntries.profile(43)))
        ..createSync(recursive: true)
        ..writeAsStringSync('from backup');
      await testDatabase.customStatement(
        'CREATE TRIGGER refuse_duplicate_profiles BEFORE INSERT ON profiles '
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      await expectLater(
        actionOf(buildContainer()).applyRestore(
          MigrationData(profiles: [_profile(43, 'One'), _profile(43, 'Two')]),
          RestoreOption.onlyProfiles,
          stagingDirPath: staging.path,
        ),
        throwsA(anything),
      );

      expect(target.readAsStringSync(), 'current');
    });

    test('a backup carrying only proxy groups still writes them', () async {
      await testDatabase.profiles.put(
        const Profile(id: 7, autoUpdateDuration: Duration.zero).toCompanion(),
      );
      final container = buildContainer();

      await actionOf(container).applyRestore(
        const MigrationData(
          proxyGroups: [
            ProxyGroup(
              id: 1,
              profileId: 7,
              name: 'Selector',
              type: GroupType.Selector,
            ),
          ],
        ),
        RestoreOption.onlyProfiles,
      );

      final stored = await testDatabase.proxyGroupsDao.query(7).get();
      expect(
        stored.map((item) => item.name),
        ['Selector'],
        reason:
            'proxyGroups belongs in the guard that decides whether the batch '
            'runs, not only in the batch body',
      );
    });
  });

  group('applyRestore writes the settings providers', () {
    test('restores every settings provider the config carries', () async {
      final source = buildContainer();
      source
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(autoLaunch: true));
      source.read(currentProfileIdProvider.notifier).value = 42;
      source
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(mixedPort: 7899));
      final configMap = configMapOf(source);

      final target = buildContainer();
      await actionOf(
        target,
      ).applyRestore(MigrationData(configMap: configMap), RestoreOption.all);

      expect(target.read(currentProfileIdProvider), 42);
      expect(target.read(appSettingProvider).autoLaunch, isTrue);
      expect(target.read(patchClashConfigProvider).mixedPort, 7899);
    });

    test(
      'a backup holding a mixed port of 0 restores the default and says so',
      () async {
        final configMap = configMapOf(buildContainer());
        (configMap['patchClashConfig']! as Map<String, Object?>)['mixed-port'] =
            0;
        final banners = <String>[];
        final print = debugPrint;
        debugPrint = (message, {wrapWidth}) => banners.add(message ?? '');
        addTearDown(() => debugPrint = print);
        final target = buildContainer();
        target
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(mixedPort: 7899));

        await actionOf(
          target,
        ).applyRestore(MigrationData(configMap: configMap), RestoreOption.all);

        expect(
          target.read(patchClashConfigProvider).mixedPort,
          defaultMixedPort,
        );
        expect(
          banners,
          contains(
            '[APP] banner: The mixed port cannot be 0, so it was set back to 7890',
          ),
        );
      },
    );

    test('keeps the bound WebDAV account when the backup has none', () async {
      final configMap = configMapOf(buildContainer());
      const dav = DAVProps(uri: 'https://dav.example', user: 'me');
      final target = buildContainer();
      target.read(davSettingProvider.notifier).value = dav;

      await actionOf(
        target,
      ).applyRestore(MigrationData(configMap: configMap), RestoreOption.all);

      expect(target.read(davSettingProvider), dav);
    });

    test('keeps the picked apps when the backup lists none', () async {
      final configMap = configMapOf(buildContainer());
      const picked = AccessControlProps(
        enable: true,
        mode: AccessControlMode.acceptSelected,
        acceptList: ['com.example.browser'],
      );
      final target = buildContainer();
      target
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(accessControlProps: picked));

      await actionOf(
        target,
      ).applyRestore(MigrationData(configMap: configMap), RestoreOption.all);

      expect(target.read(vpnSettingProvider).accessControlProps, picked);
    });

    test('takes the apps a backup lists from another phone', () async {
      const listed = AccessControlProps(
        enable: true,
        rejectList: ['com.example.bank'],
      );
      final source = buildContainer();
      source
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(accessControlProps: listed));
      final configMap = configMapOf(source);
      final target = buildContainer();
      target
          .read(vpnSettingProvider.notifier)
          .update(
            (state) => state.copyWith(
              accessControlProps: const AccessControlProps(
                acceptList: ['com.example.browser'],
              ),
            ),
          );

      await actionOf(
        target,
      ).applyRestore(MigrationData(configMap: configMap), RestoreOption.all);

      expect(target.read(vpnSettingProvider).accessControlProps, listed);
    });

    test('leaves the settings untouched for an onlyProfiles restore', () async {
      final source = buildContainer();
      source.read(currentProfileIdProvider.notifier).value = 42;
      final configMap = configMapOf(source);

      final target = buildContainer();
      final before = target.read(currentProfileIdProvider);

      await actionOf(target).applyRestore(
        MigrationData(configMap: configMap, profiles: [_profile(1, 'P')]),
        RestoreOption.onlyProfiles,
      );

      expect(target.read(currentProfileIdProvider), before);
      expect(await testDatabase.profilesDao.query().get(), hasLength(1));
    });

    test('a backup without a config still restores the database', () async {
      final container = buildContainer();
      final before = container.read(currentProfileIdProvider);

      await actionOf(container).applyRestore(
        MigrationData(profiles: [_profile(1, 'P')]),
        RestoreOption.all,
      );

      expect(container.read(currentProfileIdProvider), before);
      expect(await testDatabase.profilesDao.query().get(), hasLength(1));
    });
  });

  group('a config with unreadable values', () {
    test('restores the rest without keeping a dropped profile', () async {
      final container = buildContainer();
      await testDatabase.profilesDao.putAll([
        _profile(9, 'Pre-existing').toCompanion(0),
      ]);
      container.read(currentProfileIdProvider.notifier).value = 9;
      container
          .read(appSettingProvider.notifier)
          .update(
            (state) =>
                state.copyWith(restoreStrategy: RestoreStrategy.override),
          );

      await actionOf(container).applyRestore(
        MigrationData(
          configMap: const {
            'currentProfileId': 'not an int',
            'appSettingProps': {'hideIp': true},
          },
          profiles: [_profile(1, 'From backup')],
        ),
        RestoreOption.all,
      );

      final stored = await testDatabase.profilesDao.query().get();
      expect(stored.map((item) => item.label), ['From backup']);
      expect(container.read(currentProfileIdProvider), isNull);
      expect(container.read(appSettingProvider).hideIp, true);
    });
  });
}
