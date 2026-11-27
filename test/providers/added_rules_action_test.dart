import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'dart:convert';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAddedRulesAction extends AddedRulesAction {
  FakeAddedRulesAction(
    this.reload, {
    this.profilesPath,
    this.providerView,
    this.generation,
  });
  final Future<bool> Function() reload;
  final String? profilesPath;
  final String Function()? generation;

  @override
  String newCacheGeneration() =>
      generation?.call() ?? super.newCacheGeneration();
  final Future<RuleSetView?> Function()? providerView;

  @override
  Future<RuleSetView?> loadAddedRuleSetView(AddedRuleSet set) =>
      providerView?.call() ?? super.loadAddedRuleSetView(set);
  final warnings = <String>[];
  bool reportThrows = false;

  @override
  void reportLateRollbackFailure(String message) {
    warnings.add(message);
    if (reportThrows) throw StateError('reporter failed');
  }

  @override
  Future<String> get addedRulesProfilesPath async =>
      profilesPath ?? await super.addedRulesProfilesPath;

  @override
  Duration get saveTimeout => const Duration(milliseconds: 30);

  /// Told to the next apply's own listener, as the Core's mount refusal.
  String? rejection;

  /// Told to a failed apply's own listener, as the error that failed it.
  Object? failure;

  @override
  Future<bool> applyAddedRulesProfile({
    void Function(String reason)? onMountRejected,
    void Function(Object error)? onFailed,
  }) async {
    final applied = await reload();
    if (!applied && rejection != null) onMountRejected?.call(rejection!);
    if (!applied && failure != null) onFailed?.call(failure!);
    return applied;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = Profile(id: 1, autoUpdateDuration: Duration.zero);
  const original = Rule(
    id: 10,
    order: 'a0',
    ruleTarget: 'DIRECT',
    profileId: 1,
  );
  late db.Database previousDatabase;
  late db.Database database;
  late ProviderContainer container;

  setUp(() async {
    previousDatabase = db.database;
    database = db.Database(NativeDatabase.memory());
    db.database = database;
    await database.profilesDao.putAll([profile.toCompanion()]);
    await database.rulesDao.putRule(original, profileId: 1);
  });

  tearDown(() async {
    container.dispose();
    db.database = previousDatabase;
    await database.close();
  });

  Future<String> target() async =>
      (await database.rulesDao.queryProfileRules(1).get()).single.ruleTarget!;

  test('rollback database failure still attempts compensation', () async {
    var calls = 0;
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        addedRulesActionProvider.overrideWith(
          () => FakeAddedRulesAction(() async {
            if (++calls == 1) {
              await database.customStatement(
                'CREATE TRIGGER reject_restore BEFORE UPDATE ON rules BEGIN SELECT RAISE(ABORT, \'restore blocked\'); END',
              );
              return false;
            }
            return true;
          }),
        ),
      ],
    );
    final result = await container
        .read(addedRulesActionProvider.notifier)
        .putRule(
          profile,
          original.copyWith(ruleTarget: 'REJECT'),
          previous: original,
        );
    expect(result.error, contains('restore blocked'));
    expect(result.error, contains('another editor changed'));
    expect(calls, 2);
    expect(await target(), 'REJECT');
  });

  test('a thrown reload restores the snapshot and applies it again', () async {
    final applied = <String>[];
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        addedRulesActionProvider.overrideWith(
          () => FakeAddedRulesAction(() async {
            applied.add(await target());
            if (applied.length == 1) throw StateError('failed');
            return true;
          }),
        ),
      ],
    );
    final action = container.read(addedRulesActionProvider.notifier);
    final save = await action.putRule(
      profile,
      original.copyWith(ruleTarget: 'REJECT'),
      previous: original,
    );
    expect(save.error, isNotNull);
    expect(await target(), 'DIRECT');
    expect(applied, ['REJECT', 'DIRECT']);
  });

  test(
    'a slow apply that succeeds keeps the write, and a save queued behind it runs after',
    () async {
      final slow = Completer<bool>();
      final started = Completer<void>();
      final applied = <String>[];
      final fake = FakeAddedRulesAction(() async {
        applied.add(await target());
        if (applied.length == 1) {
          started.complete();
          return slow.future;
        }
        return true;
      });
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(() => fake),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      final first = action.putRule(
        profile,
        original.copyWith(ruleTarget: 'REJECT'),
        previous: original,
      );
      await started.future;
      final second = action.putRule(
        profile,
        original.copyWith(ruleTarget: 'PROXY'),
        previous: original.copyWith(ruleTarget: 'REJECT'),
      );
      var answered = false;
      unawaited(Future.any([first, second]).then((_) => answered = true));
      // Well past the 30 ms save timeout: neither is answered early.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(answered, isFalse);
      expect(applied, ['REJECT']);
      slow.complete(true);
      final firstResult = await first;
      expect(firstResult.error, isNull);
      expect(firstResult.pending, isFalse);
      expect(firstResult.ruleId, original.id);
      expect((await second).error, isNull);
      expect(await target(), 'PROXY');
      expect(applied, ['REJECT', 'PROXY']);
      expect(fake.warnings, isEmpty);
    },
  );
  test(
    'a retry queued behind a slow apply that fails waits and then succeeds',
    () async {
      final slow = Completer<bool>();
      final started = Completer<void>();
      final applied = <String>[];
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(() async {
              applied.add(await target());
              if (applied.length == 1) {
                started.complete();
                return slow.future;
              }
              return true;
            }),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      final first = action.putRule(
        profile,
        original.copyWith(ruleTarget: 'REJECT'),
        previous: original,
      );
      await started.future;
      final retry = action.putRule(
        profile,
        original.copyWith(ruleTarget: 'PROXY'),
        previous: original,
      );
      var answered = false;
      unawaited(retry.then((_) => answered = true));
      // Well past twice the 30 ms save timeout: the retry is not turned away.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(answered, isFalse);
      expect(applied, ['REJECT']);
      slow.complete(false);
      expect(
        (await first).error,
        startsWith(currentAppLocalizations.addedRulesReloadFailed),
      );
      final retryResult = await retry;
      expect(retryResult.error, isNull);
      expect(await target(), 'PROXY');
      expect(applied, ['REJECT', 'DIRECT', 'PROXY']);
    },
  );

  test(
    'a queued stale edit cannot overwrite a successful first edit',
    () async {
      final slow = Completer<bool>();
      final started = Completer<void>();
      final applied = <String>[];
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(() async {
              applied.add(await target());
              if (applied.length == 1) {
                started.complete();
                return slow.future;
              }
              return applied.length != 2;
            }),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      final first = action.putRule(
        profile,
        original.copyWith(ruleTarget: 'REJECT'),
        previous: original,
      );
      await started.future;
      final second = action.putRule(
        profile,
        original.copyWith(ruleTarget: 'PROXY'),
        previous: original,
      );
      expect(await target(), 'REJECT');
      slow.complete(true);
      expect((await first).error, isNull);
      expect((await second).error, isNotNull);
      expect(await target(), 'REJECT');
      expect(applied, ['REJECT']);
    },
  );
  test('late apply failure cannot race rollback or a queued restore', () async {
    final applyGate = Completer<void>();
    final started = Completer<void>();
    final compensationGate = Completer<bool>();
    final compensating = Completer<void>();
    final applied = <String>[];
    var calls = 0;
    var restoreRan = false;
    final fake = FakeAddedRulesAction(() async {
      if (++calls == 1) {
        started.complete();
        await applyGate.future;
        applied.add(await target());
        return false;
      }
      applied.add(await target());
      compensating.complete();
      return compensationGate.future;
    });
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        addedRulesActionProvider.overrideWith(() => fake),
      ],
    );
    final action = container.read(addedRulesActionProvider.notifier);
    final save = action.putRule(
      profile,
      original.copyWith(ruleTarget: 'REJECT'),
      previous: original,
    );
    await started.future;
    expect(await target(), 'REJECT');
    final restore = action.runRestoreInLane(() async {
      restoreRan = true;
    });
    await database.rulesDao.putRule(
      original.copyWith(ruleTarget: 'EXTERNAL'),
      profileId: 1,
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(restoreRan, isFalse);
    applyGate.complete();
    await compensating.future;
    expect(applied, ['EXTERNAL', 'EXTERNAL']);
    expect(await target(), 'EXTERNAL');
    expect(
      (await save).error,
      contains(currentAppLocalizations.addedRulesRollbackReloadTimeout),
    );
    expect(restoreRan, isFalse);
    compensationGate.complete(true);
    await restore;
    expect(restoreRan, isTrue);
  });

  for (final throws in [false, true]) {
    test(
      'a slow apply that fails is undone and says why: throws=$throws',
      () async {
        final slow = Completer<bool>();
        final started = Completer<void>();
        var calls = 0;
        final fake = FakeAddedRulesAction(() async {
          if (++calls == 1) {
            started.complete();
            return slow.future;
          }
          return true;
        });
        container = ProviderContainer(
          overrides: [
            currentProfileIdProvider.overrideWithBuild((_, _) => 1),
            coreStatusProvider.overrideWithBuild(
              (_, _) => CoreStatus.connected,
            ),
            addedRulesActionProvider.overrideWith(() => fake),
          ],
        );
        final action = container.read(addedRulesActionProvider.notifier);
        final save = action.putRule(
          profile,
          original.copyWith(ruleTarget: 'REJECT'),
          previous: original,
        );
        await started.future;
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(await target(), 'REJECT');
        if (throws) {
          slow.completeError(const DnsRespectRulesUnmetException());
        } else {
          slow.complete(false);
        }
        final appLocalizations = currentAppLocalizations;
        expect(
          (await save).error,
          throws
              ? '${appLocalizations.addedRulesApplyFailed}\n'
                    '${appLocalizations.dnsRespectRulesUnmetError}'
              : appLocalizations.addedRulesReloadFailed,
        );
        expect(await target(), 'DIRECT');
        expect(calls, 2);
        expect(fake.warnings, isEmpty);
      },
    );
  }

  test('a failed apply tells the error that failed it', () async {
    var calls = 0;
    final fake = FakeAddedRulesAction(() async => ++calls != 1)
      ..failure = const DnsRespectRulesUnmetException();
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        addedRulesActionProvider.overrideWith(() => fake),
      ],
    );
    final appLocalizations = currentAppLocalizations;
    final result = await container
        .read(addedRulesActionProvider.notifier)
        .putRule(
          profile,
          original.copyWith(ruleTarget: 'REJECT'),
          previous: original,
        );
    expect(
      result.error,
      '${appLocalizations.addedRulesApplyFailed}\n'
      '${appLocalizations.dnsRespectRulesUnmetError}',
    );
    expect(calls, 2);
    expect(await target(), 'DIRECT');
  });

  test('failed reload preserves writes from an independent editor', () async {
    final slow = Completer<bool>();
    final started = Completer<void>();
    var calls = 0;
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        addedRulesActionProvider.overrideWith(
          () => FakeAddedRulesAction(() async {
            if (++calls == 1) {
              started.complete();
              return slow.future;
            }
            return true;
          }),
        ),
      ],
    );
    final action = container.read(addedRulesActionProvider.notifier);
    final first = action.putRule(
      profile,
      original.copyWith(ruleTarget: 'REJECT'),
      previous: original,
    );
    await started.future;
    const other = Rule(id: 11, order: 'b', ruleTarget: 'OTHER', profileId: 1);
    await database.rulesDao.putRule(other, profileId: 1);
    await database.rulesDao.putRule(
      original.copyWith(ruleTarget: 'EXTERNAL'),
      profileId: 1,
    );
    slow.complete(false);
    expect((await first).error, isNotNull);
    final rules = await database.rulesDao.queryProfileRules(1).get();
    expect(rules.map((r) => r.ruleTarget), ['EXTERNAL', 'OTHER']);
  });
  test(
    'failed apply retains its cache and retry writes a fresh generation',
    () async {
      final dir = await Directory.systemTemp.createTemp('added-rule-seed-');
      addTearDown(() => dir.delete(recursive: true));
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      var calls = 0;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(
              () async => ++calls != 1,
              profilesPath: dir.path,
            ),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      final first = await action.putSet(
        profile,
        set,
        target: 'REJECT',
        content: Uint8List.fromList([1, 2]),
      );
      expect(first.error, isNotNull);
      final old = dir
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('/provider'));
      expect(await old.readAsBytes(), [1, 2]);
      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      final retry = await action.putSet(
        profile,
        set,
        target: 'REJECT',
        content: Uint8List.fromList([3, 4]),
      );
      expect(retry.error, isNull);
      final saved = (await database.addedRuleSetsDao.query(1).get()).single;
      expect(saved.cacheGeneration, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(saved.pathUnder(dir.path), isNot(old.path));
      expect(await old.readAsBytes(), [1, 2]);
      expect(await File(saved.pathUnder(dir.path)).readAsBytes(), [3, 4]);
    },
  );

  test('unknown pre-existing seed is not overwritten', () async {
    final dir = await Directory.systemTemp.createTemp('added-rule-seed-');
    addTearDown(() => dir.delete(recursive: true));
    const set = AddedRuleSet(
      id: 123,
      profileId: 1,
      name: 'ads',
      url: 'https://x.test/ads',
    );
    final path = File(set.pathUnder(dir.path));
    await path.parent.create(recursive: true);
    await path.writeAsBytes([9]);
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.disconnected),
        addedRulesActionProvider.overrideWith(
          () => FakeAddedRulesAction(() async => true, profilesPath: dir.path),
        ),
      ],
    );
    final action = container.read(addedRulesActionProvider.notifier);
    final result = await action.putSet(
      profile,
      set,
      target: 'REJECT',
      content: Uint8List.fromList([1]),
    );
    expect(result.error, isNull);
    expect(await path.readAsBytes(), [9]);
    final saved = (await database.addedRuleSetsDao.query(1).get()).single;
    expect(await File(saved.pathUnder(dir.path)).readAsBytes(), [1]);
  });
  test(
    'provider identity follows the paired applied rule, not prefix guesses',
    () {
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      const list = RuleList(
        total: 3,
        rules: [
          CoreRule(
            type: 'RULE-SET',
            payload: 'flash-added-ads',
            target: 'DIRECT',
            ruleSet: RuleSetView(name: 'flash-added-ads', status: 'failed'),
          ),
          CoreRule(
            type: 'RULE-SET',
            payload: 'flash-added-ads-3',
            target: 'REJECT',
            ruleSet: RuleSetView(name: 'flash-added-ads-3'),
          ),
          CoreRule(
            type: 'RULE-SET',
            payload: 'ads',
            target: 'DIRECT',
            ruleSet: RuleSetView(name: 'ads'),
          ),
        ],
      );
      const applied = AppliedRuleSources(
        profileId: 1,
        sources: [
          RuleSource(
            kind: RuleSourceKind.subscription,
            text: 'RULE-SET,flash-added-ads,DIRECT',
          ),
          RuleSource(
            kind: RuleSourceKind.addedProfile,
            ruleId: 123,
            text: 'RULE-SET,flash-added-ads-3,REJECT',
          ),
          RuleSource(
            kind: RuleSourceKind.subscription,
            text: 'RULE-SET,ads,DIRECT',
          ),
        ],
      );
      expect(
        identifiedAddedRuleSetView(list, applied, set)?.name,
        'flash-added-ads-3',
      );
      expect(
        identifiedAddedRuleSetView(list, applied.copyWith(profileId: 2), set),
        isNull,
      );
      expect(
        identifiedAddedRuleSetView(
          list,
          applied.copyWith(
            sources: [
              applied.sources[0],
              applied.sources[1].copyWith(text: 'RULE-SET,ads,REJECT'),
              applied.sources[2],
            ],
          ),
          set,
        ),
        isNull,
      );
    },
  );
  test('failed compensating reload is included in the save error', () async {
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        addedRulesActionProvider.overrideWith(
          () => FakeAddedRulesAction(() async => false),
        ),
      ],
    );
    final result = await container
        .read(addedRulesActionProvider.notifier)
        .putRule(
          profile,
          original.copyWith(ruleTarget: 'REJECT'),
          previous: original,
        );
    expect(
      result.error,
      contains('restoring the running configuration failed'),
    );
    expect(await target(), 'DIRECT');
  });

  test('a refused reload tells why the Core kept the running config', () async {
    var calls = 0;
    final fake = FakeAddedRulesAction(() async {
      calls++;
      return false;
    })..rejection = 'source Air is missing';
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        addedRulesActionProvider.overrideWith(() => fake),
      ],
    );
    final appLocalizations = currentAppLocalizations;
    final result = await container
        .read(addedRulesActionProvider.notifier)
        .putRule(
          profile,
          original.copyWith(ruleTarget: 'REJECT'),
          previous: original,
        );
    expect(calls, 2);
    expect(
      result.error,
      startsWith(
        '${appLocalizations.addedRulesReloadFailed}\nsource Air is missing',
      ),
    );
    expect(
      result.error,
      contains(appLocalizations.addedRulesRollbackReloadFailed),
    );
  });

  test(
    'a slow apply that fails waits for the compensating reload to answer',
    () async {
      final slow = Completer<bool>();
      final started = Completer<void>();
      var calls = 0;
      final fake = FakeAddedRulesAction(() async {
        if (++calls == 1) {
          started.complete();
          return slow.future;
        }
        return false;
      });
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(() => fake),
        ],
      );
      final save = container
          .read(addedRulesActionProvider.notifier)
          .putRule(
            profile,
            original.copyWith(ruleTarget: 'REJECT'),
            previous: original,
          );
      await started.future;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      slow.complete(false);
      final result = await save;
      expect(
        result.error,
        allOf(
          startsWith(currentAppLocalizations.addedRulesReloadFailed),
          contains('restoring the running configuration failed'),
        ),
      );
      expect(calls, 2);
      expect(fake.warnings, isEmpty);
    },
  );

  for (final outcome in [true, false]) {
    test('slow compensation reports its final outcome: $outcome', () async {
      final compensation = Completer<bool>();
      var calls = 0;
      final fake = FakeAddedRulesAction(
        () async => ++calls == 1 ? false : compensation.future,
      );
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(() => fake),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      final result = await action.putRule(
        profile,
        original.copyWith(ruleTarget: 'REJECT'),
        previous: original,
      );
      expect(
        result.error,
        contains(currentAppLocalizations.addedRulesRollbackReloadTimeout),
      );
      expect(await target(), 'DIRECT');
      var released = false;
      final lane = action.runRestoreInLane(() async => released = true);
      await pumpEventQueue();
      expect(released, isFalse);
      expect(fake.warnings, isEmpty);
      compensation.complete(outcome);
      await lane;
      expect(fake.warnings, [
        if (outcome)
          currentAppLocalizations.addedRulesApplyRestored
        else
          allOf(
            startsWith(currentAppLocalizations.addedRulesApplyRestoreFailed),
            contains(currentAppLocalizations.addedRulesRollbackReloadFailed),
          ),
      ]);
    });
  }

  for (final outcome in [true, false]) {
    test(
      'provider disposed during a slow apply still answers: $outcome',
      () async {
        final slow = Completer<bool>();
        final started = Completer<void>();
        var calls = 0;
        final fake = FakeAddedRulesAction(() async {
          if (++calls == 1) {
            started.complete();
            return slow.future;
          }
          return true;
        });
        container = ProviderContainer(
          overrides: [
            currentProfileIdProvider.overrideWithBuild((_, _) => 1),
            coreStatusProvider.overrideWithBuild(
              (_, _) => CoreStatus.connected,
            ),
            addedRulesActionProvider.overrideWith(() => fake),
          ],
        );
        final action = container.read(addedRulesActionProvider.notifier);
        final save = action.putRule(
          profile,
          original.copyWith(ruleTarget: 'REJECT'),
          previous: original,
        );
        await started.future;
        container.dispose();
        slow.complete(outcome);
        final result = await save;
        expect(calls, 1);
        if (outcome) {
          expect(result.error, isNull);
          expect(await target(), 'REJECT');
        } else {
          expect(
            result.error,
            contains(currentAppLocalizations.addedRulesRollbackReloadFailed),
          );
          expect(await target(), 'DIRECT');
        }
        expect(fake.warnings, isEmpty);
      },
    );
  }

  test(
    'throwing feedback cannot release the lane before compensation',
    () async {
      final slow = Completer<bool>();
      final started = Completer<void>();
      final compensation = Completer<bool>();
      final compensating = Completer<void>();
      var calls = 0;
      final fake = FakeAddedRulesAction(() async {
        switch (++calls) {
          case 1:
            started.complete();
            return slow.future;
          case 2:
            compensating.complete();
            return compensation.future;
        }
        return true;
      })..reportThrows = true;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(() => fake),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      final save = action.putRule(
        profile,
        original.copyWith(ruleTarget: 'REJECT'),
        previous: original,
      );
      await started.future;
      slow.complete(false);
      await compensating.future;
      expect(
        (await save).error,
        contains(currentAppLocalizations.addedRulesRollbackReloadTimeout),
      );
      var released = false;
      final lane = action.runRestoreInLane(() async => released = true);
      // Well past the 30 ms compensation timeout.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(released, isFalse);
      compensation.complete(true);
      await lane;
      expect(released, isTrue);
      expect(fake.warnings, [currentAppLocalizations.addedRulesApplyRestored]);
      final next = await action.putRule(
        profile,
        original.copyWith(ruleTarget: 'PROXY'),
        previous: original,
      );
      expect(next.error, isNull);
      expect(await target(), 'PROXY');
    },
  );
  for (final stalls in [true, false]) {
    test(
      'a set the Core never reports loaded is kept as not ready yet: stalls=$stalls',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'added-rule-timeout-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final stalled = Completer<RuleSetView?>();
        var applies = 0;
        var queries = 0;
        container = ProviderContainer(
          overrides: [
            currentProfileIdProvider.overrideWithBuild((_, _) => 1),
            coreStatusProvider.overrideWithBuild(
              (_, _) => CoreStatus.connected,
            ),
            addedRulesActionProvider.overrideWith(
              () => FakeAddedRulesAction(
                () async {
                  applies++;
                  return true;
                },
                profilesPath: dir.path,
                providerView: () {
                  queries++;
                  // No identity match: the view never names this set.
                  return stalls ? stalled.future : Future.value(null);
                },
              ),
            ),
          ],
        );
        const set = AddedRuleSet(
          id: 123,
          profileId: 1,
          name: 'ads',
          url: 'https://x.test/ads',
        );
        final result = await container
            .read(addedRulesActionProvider.notifier)
            .putSet(profile, set, target: 'REJECT')
            .timeout(const Duration(seconds: 2));
        expect(result.error, isNull);
        expect(result.pending, isTrue);
        expect(result.ruleId, set.id);
        expect(applies, 1);
        expect(queries, greaterThan(0));
        expect(
          (await database.addedRuleSetsDao.query(1).get()).single.name,
          'ads',
        );
        expect(
          (await database.rulesDao.queryAddedRules(1).get())
              .singleWhere((r) => r.id == set.id)
              .ruleTarget,
          'REJECT',
        );
        stalled.complete(null);
      },
    );
  }

  test('a set the Core reports loaded is in effect', () async {
    final dir = await Directory.systemTemp.createTemp('added-rule-loaded-');
    addTearDown(() => dir.delete(recursive: true));
    var queries = 0;
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        addedRulesActionProvider.overrideWith(
          () => FakeAddedRulesAction(
            () async => true,
            profilesPath: dir.path,
            // Loading at first, then loaded.
            providerView: () async => ++queries == 1
                ? null
                : const RuleSetView(name: 'flash-added-ads', status: 'ok'),
          ),
        ),
      ],
    );
    const set = AddedRuleSet(
      id: 123,
      profileId: 1,
      name: 'ads',
      url: 'https://x.test/ads',
    );
    final result = await container
        .read(addedRulesActionProvider.notifier)
        .putSet(profile, set, target: 'REJECT');
    expect(result.error, isNull);
    expect(result.pending, isFalse);
    expect(queries, 2);
  });

  test(
    'external edit during failed set save preserves both pair rows and coherent generated YAML',
    () async {
      final dir = await Directory.systemTemp.createTemp('added-rule-conflict-');
      addTearDown(() => dir.delete(recursive: true));
      final pending = Completer<bool>();
      final started = Completer<void>();
      var calls = 0;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(() async {
              if (++calls == 1) {
                started.complete();
                return pending.future;
              }
              return true;
            }, profilesPath: dir.path),
          ),
        ],
      );
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      final save = container
          .read(addedRulesActionProvider.notifier)
          .putSet(profile, set, target: 'REJECT');
      await started.future;
      final pair = (await database.rulesDao.queryAddedRules(1).get())
          .singleWhere((r) => r.id == set.id);
      await database.rulesDao.putRule(
        pair.copyWith(ruleTarget: 'DIRECT'),
        profileId: 1,
      );
      pending.complete(false);
      final result = await save;
      expect(result.error, contains('another editor changed'));
      final savedSet = (await database.addedRuleSetsDao.query(1).get()).single;
      expect(savedSet.id, set.id);
      final rules = await database.rulesDao.queryAddedRules(1).get();
      expect(rules.singleWhere((r) => r.id == set.id).ruleTarget, 'DIRECT');
      final rawConfig = await decodeJSONTask<Map<String, dynamic>>(
        jsonEncode({
          'rules': ['MATCH,DIRECT'],
        }),
      );
      final generated = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: dir.path,
          profileId: 1,
          rawConfig: rawConfig,
          realPatchConfig: const PatchClashConfig(),
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: rules,
          addedRuleSets: [savedSet],
          defaultUA: 'test',
        ),
      );
      expect(generated.yaml, contains('RULE-SET,ads,DIRECT'));
      expect(generated.yaml, contains(savedSet.pathUnder(dir.path)));
    },
  );

  test('only stable profile-owned pair opens or deletes as a set', () {
    const set = AddedRuleSet(
      id: 123,
      profileId: 1,
      name: 'ads',
      url: 'https://x.test/ads',
    );
    const paired = Rule(
      id: 123,
      profileId: 1,
      ruleAction: RuleAction.RULE_SET,
      ruleProvider: 'ads',
    );
    expect(pairedAddedRuleSetFor(paired, [set], 1), set);
    expect(pairedAddedRuleSetFor(paired.copyWith(id: 124), [set], 1), isNull);
    expect(
      pairedAddedRuleSetFor(paired.copyWith(profileId: null), [set], 1),
      isNull,
    );
    expect(
      pairedAddedRuleSetFor(paired.copyWith(profileId: 2), [set], 1),
      isNull,
    );
    expect(
      pairedAddedRuleSetFor(paired.copyWith(ruleProvider: 'other'), [set], 1),
      isNull,
    );
  });

  test(
    're-added set uses a distinct cache without deleting old bytes',
    () async {
      final dir = await Directory.systemTemp.createTemp('added-rule-readd-');
      addTearDown(() => dir.delete(recursive: true));
      const first = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      final second = first.copyWith(id: 124);
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
          addedRulesActionProvider.overrideWith(
            () =>
                FakeAddedRulesAction(() async => true, profilesPath: dir.path),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      expect(
        (await action.putSet(
          profile,
          first,
          target: 'DIRECT',
          content: Uint8List.fromList([1]),
        )).error,
        isNull,
      );
      final savedFirst =
          (await database.addedRuleSetsDao.query(1).get()).single;
      expect(
        (await action.deleteSet(
          profile,
          savedFirst,
          rule: (await database.rulesDao.queryAddedRules(1).get()).singleWhere(
            (r) => r.id == first.id,
          ),
        )).error,
        isNull,
      );
      expect(
        (await action.putSet(
          profile,
          second,
          target: 'DIRECT',
          content: Uint8List.fromList([2]),
        )).error,
        isNull,
      );
      final savedSecond =
          (await database.addedRuleSetsDao.query(1).get()).single;
      expect(await File(savedFirst.pathUnder(dir.path)).readAsBytes(), [1]);
      expect(await File(savedSecond.pathUnder(dir.path)).readAsBytes(), [2]);
    },
  );
  test(
    'same-name insertion during failed deletion is preserved and reloaded',
    () async {
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      const paired = Rule(
        id: 123,
        profileId: 1,
        ruleAction: RuleAction.RULE_SET,
        ruleProvider: 'ads',
        ruleTarget: 'REJECT',
        order: 'b',
      );
      final replacement = set.copyWith(id: 124, url: 'https://x.test/new');
      final replacementRule = paired.copyWith(id: 124, ruleTarget: 'DIRECT');
      await database.addedRuleSetsDao.put(set, paired);
      final pending = Completer<bool>();
      final started = Completer<void>();
      var calls = 0;
      List<AddedRuleSet>? appliedSets;
      List<Rule>? appliedRules;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(() async {
              if (++calls == 1) {
                started.complete();
                return pending.future;
              }
              appliedSets = await database.addedRuleSetsDao.query(1).get();
              appliedRules = await database.rulesDao.queryAddedRules(1).get();
              return true;
            }),
          ),
        ],
      );
      final deleting = container
          .read(addedRulesActionProvider.notifier)
          .deleteSet(profile, set, rule: paired);
      await started.future;
      await database.addedRuleSetsDao.put(replacement, replacementRule);
      pending.complete(false);
      final result = await deleting;
      expect(result.error, contains('another editor changed'));
      expect(await database.addedRuleSetsDao.query(1).get(), [replacement]);
      expect(
        (await database.rulesDao.queryAddedRules(1).get()).where(
          (r) => r.id == 123 || r.id == 124,
        ),
        [replacementRule],
      );
      expect(appliedSets, [replacement]);
      expect(appliedRules!.where((r) => r.id == 123 || r.id == 124), [
        replacementRule,
      ]);
      expect(calls, 2);
    },
  );

  test(
    'failed set deletion restores missing set if another editor resurrects paired rule',
    () async {
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      const paired = Rule(
        id: 123,
        profileId: 1,
        ruleAction: RuleAction.RULE_SET,
        ruleProvider: 'ads',
        ruleTarget: 'REJECT',
        order: 'b',
      );
      await database.addedRuleSetsDao.put(set, paired);
      final pending = Completer<bool>();
      final started = Completer<void>();
      var calls = 0;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(() async {
              if (++calls == 1) {
                started.complete();
                return pending.future;
              }
              return true;
            }),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      final deleting = action.deleteSet(profile, set, rule: paired);
      await started.future;
      await database.rulesDao.putRule(
        paired.copyWith(ruleTarget: 'DIRECT'),
        profileId: 1,
      );
      pending.complete(false);
      final result = await deleting;
      expect(result.error, contains('another editor changed'));
      expect(await database.addedRuleSetsDao.query(1).get(), [set]);
      expect(
        (await database.rulesDao.queryAddedRules(1).get())
            .singleWhere((r) => r.id == 123)
            .ruleTarget,
        'DIRECT',
      );
    },
  );
  test(
    'failed rename preserves external old-name edit with its old provider',
    () async {
      final dir = await Directory.systemTemp.createTemp('added-rule-rename-');
      addTearDown(() => dir.delete(recursive: true));
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      const paired = Rule(
        id: 123,
        profileId: 1,
        ruleAction: RuleAction.RULE_SET,
        ruleProvider: 'ads',
        ruleTarget: 'REJECT',
        order: 'b',
      );
      await database.addedRuleSetsDao.put(set, paired);
      final pending = Completer<bool>();
      final started = Completer<void>();
      var calls = 0;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(() async {
              if (++calls == 1) {
                started.complete();
                return pending.future;
              }
              return true;
            }, profilesPath: dir.path),
          ),
        ],
      );
      final saving = container
          .read(addedRulesActionProvider.notifier)
          .putSet(
            profile,
            set.copyWith(name: 'new-ads'),
            target: 'REJECT',
            previous: set,
            rule: paired,
          );
      await started.future;
      await database.rulesDao.putRule(
        paired.copyWith(ruleTarget: 'DIRECT'),
        profileId: 1,
      );
      pending.complete(false);
      final result = await saving;
      expect(result.error, contains('another editor changed'));
      expect(await database.addedRuleSetsDao.query(1).get(), [set]);
      final rule = (await database.rulesDao.queryAddedRules(1).get())
          .singleWhere((r) => r.id == 123);
      expect(rule.ruleProvider, 'ads');
      expect(rule.ruleTarget, 'DIRECT');
    },
  );
  test(
    'stalled compensation warns promptly and later writes wait until it settles',
    () async {
      final slow = Completer<bool>();
      var calls = 0;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(() async {
              calls++;
              if (calls == 1) return false;
              if (calls == 2) return slow.future;
              return true;
            }),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      final first = await action
          .putRule(
            profile,
            original.copyWith(ruleTarget: 'REJECT'),
            previous: original,
          )
          .timeout(const Duration(seconds: 2));
      expect(first.error, contains('taking too long'));
      expect(await target(), 'DIRECT');
      final next = action.putRule(
        profile,
        original.copyWith(ruleTarget: 'PROXY'),
        previous: original,
      );
      var answered = false;
      unawaited(next.then((_) => answered = true));
      // Well past twice the 30 ms save timeout: it waits its turn.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(answered, isFalse);
      expect(calls, 2);
      expect(await target(), 'DIRECT');
      slow.complete(true);
      expect((await next).error, isNull);
      expect(calls, 3);
      expect(await target(), 'PROXY');
    },
  );
  test(
    'stale rule edit and delete do not overwrite an external edit or resurrect a deletion',
    () async {
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(() async => true),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      await database.rulesDao.putRule(
        original.copyWith(ruleTarget: 'EXTERNAL'),
        profileId: 1,
      );
      final edit = await action.putRule(
        profile,
        original.copyWith(ruleTarget: 'REJECT'),
        previous: original,
      );
      final delete = await action.deleteRule(profile, original);
      expect(edit.error, contains('changed elsewhere'));
      expect(delete.error, contains('changed elsewhere'));
      expect(await target(), 'EXTERNAL');
      await database.rulesDao.delRules([original.id]);
      final resurrect = await action.putRule(
        profile,
        original.copyWith(ruleTarget: 'REJECT'),
        previous: original,
      );
      expect(resurrect.error, contains('changed elsewhere'));
      expect(await database.rulesDao.queryProfileRules(1).get(), isEmpty);
    },
  );

  test(
    'stale set and paired rule cannot be edited, deleted, or resurrected',
    () async {
      final dir = await Directory.systemTemp.createTemp('added-rule-stale-');
      addTearDown(() => dir.delete(recursive: true));
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      const paired = Rule(
        id: 123,
        profileId: 1,
        ruleAction: RuleAction.RULE_SET,
        ruleProvider: 'ads',
        ruleTarget: 'REJECT',
        order: 'b',
      );
      await database.addedRuleSetsDao.put(set, paired);
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
          addedRulesActionProvider.overrideWith(
            () =>
                FakeAddedRulesAction(() async => true, profilesPath: dir.path),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      await database.rulesDao.putRule(
        paired.copyWith(ruleTarget: 'DIRECT'),
        profileId: 1,
      );
      final edit = await action.putSet(
        profile,
        set.copyWith(url: 'https://x.test/new'),
        target: 'REJECT',
        previous: set,
        rule: paired,
      );
      final delete = await action.deleteSet(profile, set, rule: paired);
      expect(edit.error, contains('changed elsewhere'));
      expect(delete.error, contains('changed elsewhere'));
      expect(
        (await database.rulesDao.queryAddedRules(1).get())
            .singleWhere((r) => r.id == set.id)
            .ruleTarget,
        'DIRECT',
      );
      expect(await database.addedRuleSetsDao.query(1).get(), [set]);
      await database.addedRuleSetsDao.remove(set);
      final resurrect = await action.putSet(
        profile,
        set,
        target: 'DIRECT',
        previous: set,
        rule: paired,
      );
      expect(resurrect.error, contains('changed elsewhere'));
      expect(await database.addedRuleSetsDao.query(1).get(), isEmpty);
    },
  );

  test('stale move rejects a changed neighboring rule order', () async {
    const neighbor = Rule(
      id: 11,
      profileId: 1,
      ruleTarget: 'DIRECT',
      order: 'a1',
    );
    await database.rulesDao.putRule(neighbor, profileId: 1);
    final expected = await database.rulesDao.queryProfileRules(1).get();
    await database.rulesDao.order(ruleId: neighbor.id, order: 'a2');
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.disconnected),
        addedRulesActionProvider.overrideWith(
          () => FakeAddedRulesAction(() async => true),
        ),
      ],
    );
    final result = await container
        .read(addedRulesActionProvider.notifier)
        .moveRule(profile, original, up: false, expectedOrder: expected);
    expect(result.error, contains('changed elsewhere'));
    expect(
      (await database.rulesDao.queryProfileRules(1).get())
          .singleWhere((r) => r.id == original.id)
          .order,
      original.order,
    );
  });

  test(
    'leftover interrupted staging file does not block an identical offline retry',
    () async {
      final dir = await Directory.systemTemp.createTemp('added-rule-crash-');
      addTearDown(() => dir.delete(recursive: true));
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      final dest = File(set.pathUnder(dir.path));
      await dest.parent.create(recursive: true);
      final oldStage = File('${dest.path}.seed-crashed');
      await oldStage.writeAsBytes([1]);
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
          addedRulesActionProvider.overrideWith(
            () =>
                FakeAddedRulesAction(() async => true, profilesPath: dir.path),
          ),
        ],
      );
      final result = await container
          .read(addedRulesActionProvider.notifier)
          .putSet(
            profile,
            set,
            target: 'DIRECT',
            content: Uint8List.fromList([1, 2, 3]),
          );
      expect(result.error, isNull);
      final saved = (await database.addedRuleSetsDao.query(1).get()).single;
      expect(await File(saved.pathUnder(dir.path)).readAsBytes(), [1, 2, 3]);
      expect(await oldStage.readAsBytes(), [1]);
    },
  );
  test(
    'interrupted staged seed permits retry after disk database reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('added-rule-reopen-');
      addTearDown(() => dir.delete(recursive: true));
      await database.close();
      final dbFile = File('${dir.path}/rules.sqlite');
      database = db.Database(NativeDatabase(dbFile));
      db.database = database;
      await database.profilesDao.putAll([profile.toCompanion()]);
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      final orphan = set.copyWith(
        cacheGeneration: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final dest = File(orphan.pathUnder(dir.path));
      await dest.parent.create(recursive: true);
      await File('${dest.path}.seed-interrupted').writeAsBytes([1]);
      await database.close();
      database = db.Database(NativeDatabase(dbFile));
      db.database = database;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
          addedRulesActionProvider.overrideWith(
            () =>
                FakeAddedRulesAction(() async => true, profilesPath: dir.path),
          ),
        ],
      );
      final result = await container
          .read(addedRulesActionProvider.notifier)
          .putSet(
            profile,
            set,
            target: 'DIRECT',
            content: Uint8List.fromList([1, 2, 3]),
          );
      expect(result.error, isNull);
      final saved = (await database.addedRuleSetsDao.query(1).get()).single;
      expect(await File(saved.pathUnder(dir.path)).readAsBytes(), [1, 2, 3]);
      expect(await File('${dest.path}.seed-interrupted').readAsBytes(), [1]);
    },
  );
  test(
    'failed new set whose rule changes type removes only unreferenced new set',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'added-rule-type-conflict-',
      );
      addTearDown(() => dir.delete(recursive: true));
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      final pending = Completer<bool>();
      final started = Completer<void>();
      var calls = 0;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(() async {
              if (++calls == 1) {
                started.complete();
                return pending.future;
              }
              return true;
            }, profilesPath: dir.path),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      final saving = action.putSet(profile, set, target: 'REJECT');
      await started.future;
      final pair = (await database.rulesDao.queryProfileRules(1).get())
          .singleWhere((r) => r.id == set.id);
      final external = pair.copyWith(
        ruleAction: RuleAction.DOMAIN,
        content: 'example.org',
        ruleProvider: null,
      );
      await database.rulesDao.putRule(external, profileId: 1);
      pending.complete(false);
      final result = await saving;
      expect(result.error, contains('#123: ads'));
      expect(await database.addedRuleSetsDao.query(1).get(), isEmpty);
      final kept = (await database.rulesDao.queryProfileRules(1).get())
          .singleWhere((r) => r.id == set.id);
      expect(kept.ruleAction, RuleAction.DOMAIN);
      expect(kept.content, 'example.org');
    },
  );
  for (final identical in [true, false]) {
    test('promoted orphan after reopen: identical=$identical', () async {
      final dir = await Directory.systemTemp.createTemp('added-rule-promoted-');
      addTearDown(() => dir.delete(recursive: true));
      await database.close();
      final dbFile = File('${dir.path}/rules.sqlite');
      database = db.Database(NativeDatabase(dbFile));
      db.database = database;
      await database.profilesDao.putAll([profile.toCompanion()]);
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      final orphan = set.copyWith(
        cacheGeneration: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final dest = File(orphan.pathUnder(dir.path));
      await dest.parent.create(recursive: true);
      final existing = identical ? [1, 2, 3] : [9, 8];
      await dest.writeAsBytes(existing, flush: true);
      await database.close();
      database = db.Database(NativeDatabase(dbFile));
      db.database = database;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
          addedRulesActionProvider.overrideWith(
            () =>
                FakeAddedRulesAction(() async => true, profilesPath: dir.path),
          ),
        ],
      );
      final result = await container
          .read(addedRulesActionProvider.notifier)
          .putSet(
            profile,
            set,
            target: 'DIRECT',
            content: Uint8List.fromList([1, 2, 3]),
          );
      expect(result.error, isNull);
      expect(await dest.readAsBytes(), existing);
      final saved = (await database.addedRuleSetsDao.query(1).get()).single;
      expect(saved.pathUnder(dir.path), isNot(dest.path));
      expect(await File(saved.pathUnder(dir.path)).readAsBytes(), [1, 2, 3]);
    });
  }
  test('target and interval edits keep the stored cache generation', () async {
    final dir = await Directory.systemTemp.createTemp(
      'added-rule-stable-generation-',
    );
    addTearDown(() => dir.delete(recursive: true));
    const set = AddedRuleSet(
      id: 123,
      profileId: 1,
      name: 'ads',
      url: 'https://x.test/ads',
    );
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.disconnected),
        addedRulesActionProvider.overrideWith(
          () => FakeAddedRulesAction(() async => true, profilesPath: dir.path),
        ),
      ],
    );
    final action = container.read(addedRulesActionProvider.notifier);
    expect(
      (await action.putSet(
        profile,
        set,
        target: 'DIRECT',
        content: Uint8List.fromList([1]),
      )).error,
      isNull,
    );
    final saved = (await database.addedRuleSetsDao.query(1).get()).single;
    final rule = (await database.rulesDao.queryProfileRules(1).get())
        .singleWhere((r) => r.id == set.id);
    expect(
      (await action.putSet(
        profile,
        saved.copyWith(interval: 99),
        previous: saved,
        rule: rule,
        target: 'REJECT',
      )).error,
      isNull,
    );
    final edited = (await database.addedRuleSetsDao.query(1).get()).single;
    expect(edited.cacheGeneration, saved.cacheGeneration);
    expect(await File(edited.pathUnder(dir.path)).readAsBytes(), [1]);
  });
  test(
    'generation collision never adopts a foreign directory even without seed',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'added-rule-generation-collision-',
      );
      addTearDown(() => dir.delete(recursive: true));
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      const occupied = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const next = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final foreign = File(
        set.copyWith(cacheGeneration: occupied).pathUnder(dir.path),
      );
      await foreign.parent.create(recursive: true);
      await foreign.writeAsBytes([9, 8]);
      final candidates = [occupied, next].iterator;
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
          addedRulesActionProvider.overrideWith(
            () => FakeAddedRulesAction(
              () async => true,
              profilesPath: dir.path,
              generation: () {
                candidates.moveNext();
                return candidates.current;
              },
            ),
          ),
        ],
      );
      final saved = await container
          .read(addedRulesActionProvider.notifier)
          .putSet(profile, set, target: 'DIRECT');
      expect(saved.error, isNull);
      expect(
        (await database.addedRuleSetsDao.query(1).get()).single.cacheGeneration,
        next,
      );
      expect(await foreign.readAsBytes(), [9, 8]);
    },
  );

  test('committed generation and cache survive disk database reopen', () async {
    final dir = await Directory.systemTemp.createTemp('added-rule-committed-');
    addTearDown(() => dir.delete(recursive: true));
    await database.close();
    final file = File('${dir.path}/rules.sqlite');
    database = db.Database(NativeDatabase(file));
    db.database = database;
    await database.profilesDao.putAll([profile.toCompanion()]);
    const set = AddedRuleSet(
      id: 123,
      profileId: 1,
      name: 'ads',
      url: 'https://x.test/ads',
    );
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.disconnected),
        addedRulesActionProvider.overrideWith(
          () => FakeAddedRulesAction(() async => true, profilesPath: dir.path),
        ),
      ],
    );
    final result = await container
        .read(addedRulesActionProvider.notifier)
        .putSet(
          profile,
          set,
          target: 'DIRECT',
          content: Uint8List.fromList([1, 2, 3]),
        );
    expect(result.error, isNull);
    final written = (await database.addedRuleSetsDao.query(1).get()).single;
    await database.close();
    database = db.Database(NativeDatabase(file));
    db.database = database;
    final reopened = (await database.addedRuleSetsDao.query(1).get()).single;
    expect(reopened, written);
    expect(await File(reopened.pathUnder(dir.path)).readAsBytes(), [1, 2, 3]);
  });
  test(
    'changing provider URL leaves the old generation and bytes intact',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'added-rule-url-generation-',
      );
      addTearDown(() => dir.delete(recursive: true));
      const set = AddedRuleSet(
        id: 123,
        profileId: 1,
        name: 'ads',
        url: 'https://x.test/ads',
      );
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
          addedRulesActionProvider.overrideWith(
            () =>
                FakeAddedRulesAction(() async => true, profilesPath: dir.path),
          ),
        ],
      );
      final action = container.read(addedRulesActionProvider.notifier);
      expect(
        (await action.putSet(
          profile,
          set,
          target: 'DIRECT',
          content: Uint8List.fromList([1]),
        )).error,
        isNull,
      );
      final original = (await database.addedRuleSetsDao.query(1).get()).single;
      final rule = (await database.rulesDao.queryProfileRules(1).get())
          .singleWhere((r) => r.id == set.id);
      final updated = original.copyWith(url: 'https://x.test/new');
      expect(
        (await action.putSet(
          profile,
          updated,
          previous: original,
          rule: rule,
          target: 'DIRECT',
          content: Uint8List.fromList([2]),
        )).error,
        isNull,
      );
      final saved = (await database.addedRuleSetsDao.query(1).get()).single;
      expect(saved.cacheGeneration, isNot(original.cacheGeneration));
      expect(await File(original.pathUnder(dir.path)).readAsBytes(), [1]);
      expect(await File(saved.pathUnder(dir.path)).readAsBytes(), [2]);
    },
  );
}
