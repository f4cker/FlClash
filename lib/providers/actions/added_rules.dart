part of '../action.dart';

/// How a change to the added rules ended: [error] says why it was undone;
/// [pending] means it was written while the Core was not running, to take
/// effect once it starts; [ruleId] is the rule written.
typedef AddedRulesSave = ({String? error, bool pending, int? ruleId});

/// The rules and rule sets the rules page edits for a profile, in the order
/// the added rules apply. For a custom profile they are its own rules.
typedef AddedRulesState = ({List<Rule> rules, List<AddedRuleSet> sets});

/// How long a save waits for the Core to reload, and a new rule set for its
/// first download.
const addedRulesSaveTimeout = Duration(seconds: 15);

/// What a save rolls back to when the Core does not take it.
typedef _AddedSnapshot = ({
  List<Rule> rules,
  List<int> disabled,
  List<AddedRuleSet> sets,
});

/// Adds, edits, moves and removes the rules page's added rules and rule
/// sets. Each belongs to the profile it was added to and is written before
/// the profile's own rules; a custom profile takes them into its own rules.
/// A change counts once the Core reloads with it, and is undone when it
/// does not.
@Riverpod(keepAlive: true)
class AddedRulesAction extends _$AddedRulesAction {
  @override
  void build() {}

  CoreController get _core => ref.read(coreHandlerProvider);

  // All writes share one lane: the Core has one active configuration, and
  // rollback snapshots must not overwrite a later save.
  Future<void> _writeTail = Future.value();

  Future<T> runRestoreInLane<T>(Future<T> Function() task) {
    final result = _writeTail.then((_) => task());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  @visibleForTesting
  Future<String> get addedRulesProfilesPath => appPath.profilesPath;

  @visibleForTesting
  Duration get saveTimeout => addedRulesSaveTimeout;

  @visibleForTesting
  void reportLateRollbackFailure(String message) {
    commonPrint.log(message, logLevel: LogLevel.warning);
    unawaited(
      dialogs.showAlert(message: TextSpan(text: message)).catchError((_) {}),
    );
  }

  @visibleForTesting
  Future<bool> applyAddedRulesProfile({
    void Function(String reason)? onMountRejected,
  }) => ref
      .read(setupActionProvider.notifier)
      .applyProfileReporting(onMountRejected: onMountRejected ?? (_) {});

  Future<AddedRulesState> load(Profile profile) async {
    final rules = profile.type == ProfileType.custom
        ? await database.rulesDao.queryProfileRules(profile.id).get()
        : await database.rulesDao.queryAddedRules(profile.id).get();
    final sets = await database.addedRuleSetsDao.query(profile.id).get();
    return (rules: rules, sets: sets);
  }

  /// The rule set names [profile] already has on its own: a custom
  /// profile's are the app's rule sets, any other's those of its config.
  Set<String> takenRuleSetNames(Profile profile) {
    if (profile.type == ProfileType.custom) {
      return {
        for (final provider
            in ref.read(clashProvidersProvider).value ?? <ClashProvider>[])
          provider.label,
      };
    }
    if (ref.read(currentProfileIdProvider) != profile.id) return const {};
    final providers = ref.read(profileSettingsProvider)?['rule-providers'];
    return {
      if (providers is Map)
        for (final key in providers.keys) '$key',
    };
  }

  /// The profile's own rules, which a new one goes among.
  Future<List<Rule>> _own(int profileId) =>
      database.rulesDao.queryProfileRules(profileId).get();

  /// The key of a rule placed first, or last: for a custom profile, last
  /// comes before its closing MATCH.
  Future<String?> _orderFor(Profile profile, {required bool last}) async {
    final own = await _own(profile.id);
    if (!last) {
      return indexing.generateKeyBetween(null, own.firstOrNull?.order);
    }
    var end = own.length;
    if (profile.type == ProfileType.custom &&
        own.lastOrNull?.ruleAction == RuleAction.MATCH) {
      end--;
    }
    return indexing.generateKeyBetween(
      own.elementAtOrNull(end - 1)?.order,
      own.elementAtOrNull(end)?.order,
    );
  }

  Future<void> _expectCurrentRule(Profile profile, Rule expected) async {
    final rows = expected.profileId == null
        ? await database.rulesDao.queryGlobalRules().get()
        : await database.rulesDao.queryProfileRules(expected.profileId!).get();
    final current = rows.where((r) => r.id == expected.id).firstOrNull;
    final disabled = expected.profileId == null
        ? await database.rulesDao.queryDisabledRuleIds(profile.id).get()
        : const <int>[];
    if (current != expected ||
        disabled.contains(expected.id) ||
        (expected.profileId != null && expected.profileId != profile.id)) {
      throw StateError(currentAppLocalizations.addedRulesStaleEdit);
    }
  }

  Future<void> _expectCurrentSet(
    Profile profile,
    AddedRuleSet expected,
    Rule? rule,
  ) async {
    final sets = await database.addedRuleSetsDao.query(profile.id).get();
    if (expected.profileId != profile.id ||
        sets.where((s) => s.id == expected.id).firstOrNull != expected ||
        rule == null ||
        rule.id != expected.id ||
        rule.profileId != profile.id ||
        rule.ruleAction != RuleAction.RULE_SET ||
        rule.ruleProvider != expected.name) {
      throw StateError(currentAppLocalizations.addedRulesStaleEdit);
    }
    await _expectCurrentRule(profile, rule);
  }

  /// Writes [rule]: a new one first or [last] among the added rules, or in
  /// place of [previous]. A global rule edited here becomes this profile's
  /// own, and the global one stays out of this profile only.
  Future<AddedRulesSave> putRule(
    Profile profile,
    Rule rule, {
    Rule? previous,
    bool last = false,
  }) async {
    late final int ruleId;
    return _commit(profile, () async {
      if (previous != null) await _expectCurrentRule(profile, previous);
      final global =
          previous != null &&
          previous.profileId == null &&
          profile.type != ProfileType.custom;
      if (previous == null || global) {
        final placed = rule.copyWith(
          id: snowflake.id,
          order: await _orderFor(profile, last: last || global),
        );
        ruleId = placed.id;
        final collision = await (database.select(
          database.rules,
        )..where((row) => row.id.equals(placed.id))).getSingleOrNull();
        if (collision != null) {
          throw StateError(currentAppLocalizations.addedRulesStaleEdit);
        }
        await database.transaction(() async {
          await database.rulesDao.putRule(placed, profileId: profile.id);
          if (global) {
            await database.rulesDao.putDisabled(profile.id, previous.id);
          }
        });
        return;
      }
      ruleId = previous.id;
      await database.rulesDao.putRule(
        rule.copyWith(id: previous.id, order: previous.order),
        profileId: previous.profileId ?? profile.id,
      );
    }, ruleId: () => ruleId);
  }

  /// Takes [rule] out of the profile; a global one stays for the others.
  Future<AddedRulesSave> deleteRule(Profile profile, Rule rule) {
    return _commit(profile, () async {
      await _expectCurrentRule(profile, rule);
      if (rule.profileId == null && profile.type != ProfileType.custom) {
        await database.rulesDao.putDisabled(profile.id, rule.id);
      } else {
        await database.rulesDao.delRules([rule.id]);
      }
    });
  }

  /// Moves one of the profile's own rules a place up or down among them.
  Future<AddedRulesSave> moveRule(
    Profile profile,
    Rule rule, {
    required bool up,
    required List<Rule> expectedOrder,
  }) {
    return _commit(profile, () async {
      final own = await _own(profile.id);
      if (!listEquals(own, expectedOrder)) {
        throw StateError(currentAppLocalizations.addedRulesStaleEdit);
      }
      await _expectCurrentRule(profile, rule);
      final index = own.indexWhere((item) => item.id == rule.id);
      final to = up ? index - 1 : index + 1;
      if (index == -1 || to < 0 || to >= own.length) {
        throw StateError('rule $index cannot move to $to');
      }
      final before = up ? own.elementAtOrNull(to - 1) : own[to];
      final after = up ? own[to] : own.elementAtOrNull(to + 1);
      await database.rulesDao.order(
        ruleId: rule.id,
        order: indexing.generateKeyBetween(before?.order, after?.order)!,
      );
    }, ruleId: () => rule.id);
  }

  /// Writes [set] with the rule that uses it going to [target]: a new set
  /// first among the added rules, an edited one where its rule is. What
  /// the check downloaded, [content], starts the set's file so the Core
  /// need not download it again; a set renamed or moved to another link
  /// leaves old files intact because they may be independently owned.
  Future<AddedRulesSave> putSet(
    Profile profile,
    AddedRuleSet set, {
    required String target,
    AddedRuleSet? previous,
    Rule? rule,
    Uint8List? content,
  }) async {
    final profilesPath = await addedRulesProfilesPath;
    late final int ruleId;
    AddedRuleSet? waitSet;
    final result = await _commit(
      profile,
      () async {
        if (set.profileId != profile.id ||
            (previous == null && rule != null) ||
            (previous != null && previous.id != set.id)) {
          throw StateError(currentAppLocalizations.addedRulesStaleEdit);
        }
        if (previous != null) {
          await _expectCurrentSet(profile, previous, rule);
        } else {
          final allSets = await database.addedRuleSetsDao.queryAll().get();
          if (allSets.any((item) => item.id == set.id)) {
            throw StateError(currentAppLocalizations.addedRulesStaleEdit);
          }
        }
        if (rule != null && rule.id != set.id) {
          throw StateError('Legacy rule set link cannot be safely identified');
        }
        if (rule == null) {
          final existing = await (database.select(
            database.rules,
          )..where((row) => row.id.equals(set.id))).getSingleOrNull();
          if (existing != null) {
            throw StateError('Rule set id is already used by another rule');
          }
        }
        final newGeneration =
            previous == null ||
            previous.name != set.name ||
            previous.url != set.url ||
            previous.behavior != set.behavior ||
            previous.format != set.format ||
            content != null;
        final savedSet = set.copyWith(
          cacheGeneration: newGeneration
              ? await _reserveCacheGeneration(set, profilesPath)
              : previous.cacheGeneration,
        );
        if (newGeneration) waitSet = savedSet;
        final placed =
            rule?.copyWith(ruleTarget: target) ??
            Rule(
              id: set.id,
              ruleAction: RuleAction.RULE_SET,
              ruleProvider: set.name,
              ruleTarget: target,
              order: await _orderFor(profile, last: false),
            );
        ruleId = placed.id;
        await database.addedRuleSetsDao.put(savedSet, placed);
        // A failed apply may still leave Core using this path; never unlink it.
        if (content != null) {
          await _seed(savedSet.pathUnder(profilesPath), content);
        }
      },
      ruleId: () => ruleId,
      waitFor: () => waitSet,
    );
    return result;
  }

  /// Removes [set] and its paired rule, preserving provider files.
  Future<AddedRulesSave> deleteSet(
    Profile profile,
    AddedRuleSet set, {
    required Rule rule,
  }) async {
    final result = await _commit(profile, () async {
      await _expectCurrentSet(profile, set, rule);
      await database.addedRuleSetsDao.remove(set);
    });
    return result;
  }

  /// Has the Core download [set] again now; null once it did, or why not.
  Future<String?> refreshSet(Profile profile, AddedRuleSet set) async {
    try {
      final key = await _loadedKeyOf(set);
      if (key == null) {
        throw StateError('Rule set identity is unavailable or ambiguous');
      }
      await _core.updateExternalProvider(key);
      return null;
    } catch (error) {
      return userFacingErrorMessage(error, currentAppLocalizations);
    }
  }

  /// Downloads [url] the way a profile downloads, through Flash's own proxy
  /// while it runs, and reads what it holds.
  Future<RuleSetCheck> checkRuleSet(String url) async {
    final Uint8List bytes;
    try {
      final response = await request.getFileResponseForUrl(url.trim());
      bytes = response.data ?? Uint8List(0);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 410) {
        return RuleSetCheck.failed(
          RuleSetCheckFailure.notFound,
          detail: '$status',
        );
      }
      if (status != null) {
        return RuleSetCheck.failed(
          RuleSetCheckFailure.network,
          detail: 'HTTP $status',
        );
      }
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => const RuleSetCheck.failed(
          RuleSetCheckFailure.timeout,
        ),
        _ => RuleSetCheck.failed(
          RuleSetCheckFailure.network,
          detail: compactError(error.error ?? error.message ?? error),
        ),
      };
    } catch (error) {
      return RuleSetCheck.failed(
        RuleSetCheckFailure.network,
        detail: compactError(error),
      );
    }
    final check = classifyRuleSet(bytes);
    if (!check.ok || ref.read(coreStatusProvider) != CoreStatus.connected) {
      return check;
    }
    if (check.format != RuleProviderFormat.mrs) return check;
    // Only the Core reads an mrs file; it reads a copy in its cache.
    final staged = 'added-check-${snowflake.id}.new';
    final stagedPath = await appPath.getProviderCachePath(staged);
    try {
      await File(stagedPath).safeWriteAsBytes(bytes);
      final inspected = await _core.inspectRuleSet(staged);
      return RuleSetCheck(
        behavior: inspected.info.behavior,
        format: inspected.info.format,
        count: inspected.count,
        content: bytes,
      );
    } catch (_) {
      return const RuleSetCheck.failed(RuleSetCheckFailure.unknown);
    } finally {
      await File(stagedPath).safeDelete();
      await File('$stagedPath.mrs').safeDelete();
    }
  }

  /// Writes and flushes a private staging file, then links it into place
  /// atomically without replacing any existing Core or user-owned file.
  Future<String> _reserveCacheGeneration(
    AddedRuleSet set,
    String profilesPath,
  ) async {
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isAndroid)) {
      throw UnsupportedError(
        'Atomic rule set cache reservation is unavailable on this platform',
      );
    }
    final mkdir = DynamicLibrary.process()
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Uint32),
          int Function(Pointer<Utf8>, int)
        >('mkdir');
    for (var attempt = 0; attempt < 8; attempt++) {
      final generation = newCacheGeneration();
      final directory = File(
        set.copyWith(cacheGeneration: generation).pathUnder(profilesPath),
      ).parent;
      await directory.parent.create(recursive: true);
      final name = directory.path.toNativeUtf8();
      try {
        if (mkdir(name, 448) == 0) return generation;
      } finally {
        calloc.free(name);
      }
    }
    throw StateError('Could not reserve a fresh rule set cache directory');
  }

  @visibleForTesting
  String newCacheGeneration() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> _seed(String path, Uint8List content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isAndroid)) {
      throw UnsupportedError(
        'Atomic rule set seeding is unavailable on this platform',
      );
    }
    final staged = File('$path.seed-${snowflake.id}');
    await staged.create(exclusive: true);
    try {
      await staged.writeAsBytes(content, flush: true);
      final source = staged.path.toNativeUtf8();
      final destination = path.toNativeUtf8();
      final int result;
      try {
        final link = DynamicLibrary.process()
            .lookupFunction<
              Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
              int Function(Pointer<Utf8>, Pointer<Utf8>)
            >('link');
        result = link(source, destination);
      } finally {
        calloc.free(source);
        calloc.free(destination);
      }
      if (result == 0) return;
      throw StateError(
        'Rule set cache exists with different contents or cannot be promoted',
      );
    } finally {
      if (await staged.exists() &&
          listEquals(await staged.readAsBytes(), content)) {
        await staged.delete();
      }
    }
  }

  Future<_AddedSnapshot> _snapshot(int profileId) async {
    final (rules, disabled, sets) = await (
      _own(profileId),
      database.rulesDao.queryDisabledRuleIds(profileId).get(),
      database.addedRuleSetsDao.query(profileId).get(),
    ).wait;
    return (rules: rules, disabled: disabled, sets: sets);
  }

  // Undo only rows written by this operation and only while they still have
  // our post-write value. Other rule editors do not use this action's lane.
  Future<Set<int>> _restore(
    int profileId,
    _AddedSnapshot before,
    _AddedSnapshot after,
  ) {
    return database.transaction(() async {
      final current = await _snapshot(profileId);
      final oldRules = {for (final r in before.rules) r.id: r};
      final newRules = {for (final r in after.rules) r.id: r};
      final currentRules = {for (final r in current.rules) r.id: r};
      final oldSets = {for (final set in before.sets) set.id: set};
      final newSets = {for (final set in after.sets) set.id: set};
      final currentSets = {for (final set in current.sets) set.id: set};
      // Stable-id pair rows are one rollback unit. If either was changed by
      // another writer, retain both rather than creating a dangling reference.
      final conflicts = <int>{};
      for (final id in {...oldSets.keys, ...newSets.keys}) {
        final changed =
            oldRules[id] != newRules[id] || oldSets[id] != newSets[id];
        final oldSet = oldSets[id];
        final nameTaken =
            oldSet != null &&
            oldSet != newSets[id] &&
            current.sets.any((set) => set.id != id && set.name == oldSet.name);
        if (changed &&
            (currentRules[id] != newRules[id] ||
                currentSets[id] != newSets[id] ||
                nameTaken)) {
          conflicts.add(id);
        }
      }
      for (final id in conflicts) {
        final currentRule = currentRules[id];
        final currentSet = currentSets[id];
        final oldRule = oldRules[id];
        final oldSet = oldSets[id];
        if (oldSet == null && currentSet != null && currentSet == newSets[id]) {
          final globalRules = await database.rulesDao.queryGlobalRules().get();
          final all = [...current.rules, ...globalRules];
          final referenced = all.any(
            (rule) =>
                rule.ruleAction == RuleAction.RULE_SET &&
                rule.ruleProvider == currentSet.name,
          );
          if (!referenced) {
            // Only our unchanged, unreferenced new set is removed. Preserve
            // the independent rule's new type/content exactly as written.
            await (database.delete(
              database.addedRuleSets,
            )..where((row) => row.id.equals(id))).go();
            continue;
          }
        }
        // A concurrent writer can resurrect one half while our deletion is
        // awaiting Core. Recover the missing old half only when it still
        // names the retained counterpart; never overwrite the writer's row.
        if (currentRule != null &&
            currentSet == null &&
            oldSet != null &&
            currentRule.ruleAction == RuleAction.RULE_SET &&
            currentRule.ruleProvider == oldSet.name &&
            !current.sets.any(
              (set) => set.id != id && set.name == oldSet.name,
            )) {
          await database
              .into(database.addedRuleSets)
              .insertOnConflictUpdate(oldSet.toCompanion());
        } else if (currentRule != null &&
            currentSet != null &&
            oldSet != null &&
            currentSet == newSets[id] &&
            currentRule.ruleAction == RuleAction.RULE_SET &&
            currentRule.ruleProvider == oldSet.name &&
            currentSet.name != oldSet.name &&
            !current.sets.any(
              (set) => set.id != id && set.name == oldSet.name,
            )) {
          // An external rule edit retained the old provider name while this
          // operation renamed the set. Roll back only our unchanged set row.
          await database
              .into(database.addedRuleSets)
              .insertOnConflictUpdate(oldSet.toCompanion());
        } else if (currentSet != null &&
            currentRule == null &&
            oldRule != null &&
            oldRule.ruleAction == RuleAction.RULE_SET &&
            oldRule.ruleProvider == currentSet.name) {
          await database.rulesDao.putRule(oldRule, profileId: profileId);
        }
      }
      for (final id in {...oldRules.keys, ...newRules.keys}) {
        if (conflicts.contains(id)) continue;
        if (oldRules[id] == newRules[id] || currentRules[id] != newRules[id]) {
          continue;
        }
        final old = oldRules[id];
        if (old == null) {
          await database.rulesDao.delRules([id]);
        } else {
          await database.rulesDao.putRule(old, profileId: profileId);
        }
      }
      final oldDisabled = before.disabled.toSet();
      final newDisabled = after.disabled.toSet();
      final currentDisabled = current.disabled.toSet();
      for (final id in {...oldDisabled, ...newDisabled}) {
        if (conflicts.contains(id)) continue;
        final old = oldDisabled.contains(id);
        final written = newDisabled.contains(id);
        if (old == written || currentDisabled.contains(id) != written) continue;
        if (old) {
          await database.rulesDao.putDisabled(profileId, id);
        } else {
          await database.rulesDao.delDisabled(profileId, id);
        }
      }
      for (final id in {...oldSets.keys, ...newSets.keys}) {
        if (conflicts.contains(id)) continue;
        if (oldSets[id] == newSets[id] || currentSets[id] != newSets[id]) {
          continue;
        }
        final old = oldSets[id];
        if (old == null) {
          await (database.delete(
            database.addedRuleSets,
          )..where((t) => t.id.equals(id))).go();
        } else {
          await database
              .into(database.addedRuleSets)
              .insertOnConflictUpdate(old.toCompanion());
        }
      }
      return conflicts;
    });
  }

  /// Runs [change] and has the Core reload [profile] with it; when the
  /// Core does not, puts back what was there.
  Future<AddedRulesSave> _commit(
    Profile profile,
    Future<void> Function() change, {
    int Function()? ruleId,
    AddedRuleSet? Function()? waitFor,
    Future<void> Function()? onSuccess,
    Future<void> Function()? onFailure,
  }) {
    final result = Completer<AddedRulesSave>();
    final prior = _writeTail;
    final run = () async {
      try {
        await prior.timeout(saveTimeout * 2);
      } on TimeoutException {
        result.complete((
          error: currentAppLocalizations.addedRulesApplyPending,
          pending: false,
          ruleId: null,
        ));
        // Keep this rejected request in the lane until earlier work settles.
        await prior;
        return;
      }
      try {
        final save = await _commitInLane(
          profile,
          change,
          ruleId: ruleId,
          waitFor: waitFor,
          onSuccess: onSuccess,
          onFailure: onFailure,
          earlyResult: result,
        );
        if (!result.isCompleted) result.complete(save);
      } catch (error, stack) {
        if (!result.isCompleted) {
          result.completeError(error, stack);
        } else {
          _reportLateFailure(error);
        }
      }
    }();
    _writeTail = run.catchError(_reportLateFailure);
    return result.future;
  }

  /// Late feedback must never throw into a lane still reconciling the Core.
  void _reportLate(String message) {
    try {
      reportLateRollbackFailure(message);
    } catch (error) {
      try {
        commonPrint.log('$message\n$error', logLevel: LogLevel.warning);
      } catch (_) {}
    }
  }

  void _reportLateFailure(Object error) => _reportLate(
    '${currentAppLocalizations.addedRulesApplyRestoreFailed}\n'
    '${compactError(error)}',
  );

  /// The apply can still publish after [saveTimeout], so it keeps the lane.
  Future<bool> _compensate(
    Completer<AddedRulesSave> earlyResult,
    String timeoutMessage,
  ) async {
    final timer = Timer(saveTimeout, () {
      if (earlyResult.isCompleted) return;
      earlyResult.complete((
        error: timeoutMessage,
        pending: false,
        ruleId: null,
      ));
    });
    try {
      return await applyAddedRulesProfile();
    } finally {
      timer.cancel();
    }
  }

  Future<AddedRulesSave> _commitInLane(
    Profile profile,
    Future<void> Function() change, {
    int Function()? ruleId,
    AddedRuleSet? Function()? waitFor,
    Future<void> Function()? onSuccess,
    Future<void> Function()? onFailure,
    required Completer<AddedRulesSave> earlyResult,
  }) async {
    final appLocalizations = currentAppLocalizations;
    late final _AddedSnapshot snapshot;
    late final _AddedSnapshot written;
    try {
      await database.transaction(() async {
        snapshot = await _snapshot(profile.id);
        await change();
        written = await _snapshot(profile.id);
      });
    } catch (error) {
      await onFailure?.call();
      return (
        error: appLocalizations.addRuleWriteFailed(compactError(error)),
        pending: false,
        ruleId: null,
      );
    }
    ref.invalidate(setupStateProvider(profile.id));
    final id = ruleId?.call();
    if (ref.read(currentProfileIdProvider) != profile.id ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      await onSuccess?.call();
      return (error: null, pending: true, ruleId: id);
    }
    final (error, lateApply) = await _reload(waitFor?.call());
    if (error == null) {
      await onSuccess?.call();
      return (error: null, pending: false, ruleId: id);
    }
    if (lateApply != null) {
      earlyResult.complete((
        error: appLocalizations.addedRulesApplyPending,
        pending: false,
        ruleId: null,
      ));
      // Future.timeout does not cancel setup, which can still publish.
      try {
        await lateApply;
      } catch (_) {}
    }
    Set<int> conflicts = {};
    Object? restoreError;
    try {
      conflicts = await _restore(profile.id, snapshot, written);
    } catch (error) {
      restoreError = error;
    }
    final conflictDetails = [
      for (final id in conflicts)
        '#$id: ${written.sets.where((s) => s.id == id).firstOrNull?.name ?? snapshot.sets.where((s) => s.id == id).firstOrNull?.name ?? "?"}',
    ].join(', ');
    final failureMessage = restoreError != null
        ? '$error\n${appLocalizations.addedRulesRollbackConflict} (${compactError(restoreError)})'
        : conflicts.isNotEmpty
        ? '$error\n${appLocalizations.addedRulesRollbackConflict} ($conflictDetails)'
        : error;
    var restored = true;
    Object? compensationError;
    // A ref disposed while the Core was busy must not skip the outcome.
    try {
      ref.invalidate(setupStateProvider(profile.id));
      if (ref.read(currentProfileIdProvider) == profile.id &&
          ref.read(coreStatusProvider) == CoreStatus.connected) {
        restored = await _compensate(
          earlyResult,
          '$failureMessage\n'
          '${appLocalizations.addedRulesRollbackReloadTimeout}',
        );
      }
    } catch (error) {
      restored = false;
      compensationError = error;
    }
    await onFailure?.call();
    if (earlyResult.isCompleted) {
      final problems = [
        if (restoreError != null)
          '${appLocalizations.addedRulesRollbackConflict} (${compactError(restoreError)})',
        if (conflicts.isNotEmpty)
          '${appLocalizations.addedRulesRollbackConflict} ($conflictDetails)',
        if (!restored) appLocalizations.addedRulesRollbackReloadFailed,
        if (compensationError != null) compactError(compensationError),
      ];
      _reportLate(
        problems.isEmpty
            ? appLocalizations.addedRulesApplyRestored
            : [
                appLocalizations.addedRulesApplyRestoreFailed,
                ...problems,
              ].join('\n'),
      );
    }
    if (!restored) {
      return (
        error:
            '$failureMessage\n'
            '${appLocalizations.addedRulesRollbackReloadFailed}',
        pending: false,
        ruleId: null,
      );
    }
    return (error: failureMessage, pending: false, ruleId: null);
  }

  /// Null once the Core runs the profile as written and [set], if any, has
  /// loaded; else why not.
  Future<(String?, Future<bool>?)> _reload(AddedRuleSet? set) async {
    final appLocalizations = currentAppLocalizations;
    final deadline = DateTime.now().add(saveTimeout);
    final bool applied;
    Future<bool>? applying;
    String? rejection;
    String reloadFailed() =>
        [appLocalizations.addedRulesReloadFailed, ?rejection].join('\n');
    try {
      applying = applyAddedRulesProfile(
        onMountRejected: (reason) => rejection = reason,
      );
      applied = await applying.timeout(saveTimeout);
    } on TimeoutException {
      return (appLocalizations.addedRulesReloadTimeout, applying);
    } catch (_) {
      return (reloadFailed(), null);
    }
    if (!applied) return (reloadFailed(), null);
    if (set == null) return (null, null);
    while (true) {
      final RuleSetView? view;
      try {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          return (appLocalizations.addedRuleSetLoadTimeout, null);
        }
        view = await loadAddedRuleSetView(set).timeout(remaining);
      } on TimeoutException {
        return (appLocalizations.addedRuleSetLoadTimeout, null);
      } catch (_) {
        return (appLocalizations.addedRuleSetLoadFailed, null);
      }
      if (view != null && view.status == 'ok') return (null, null);
      if (view != null && view.status == 'failed') {
        return (appLocalizations.addedRuleSetLoadFailed, null);
      }
      if (DateTime.now().isAfter(deadline)) {
        return (appLocalizations.addedRuleSetLoadTimeout, null);
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        return (appLocalizations.addedRuleSetLoadTimeout, null);
      }
      await Future.delayed(
        remaining < const Duration(milliseconds: 400)
            ? remaining
            : const Duration(milliseconds: 400),
      );
    }
  }

  /// Identify the running provider from the paired rule in the last applied
  /// config, not from names that an unrelated provider could also use.
  @visibleForTesting
  Future<RuleSetView?> loadAddedRuleSetView(AddedRuleSet set) async {
    final list = await _core.listRules();
    final applied = ref.read(appliedRuleSourcesStateProvider);
    return identifiedAddedRuleSetView(list, applied, set);
  }

  Future<String?> _loadedKeyOf(AddedRuleSet set) async =>
      (await loadAddedRuleSetView(set))?.name;
}

/// Returns a provider only when the applied source and current Core rule
/// agree on the stable pair and exact rule text.
@visibleForTesting
RuleSetView? identifiedAddedRuleSetView(
  RuleList list,
  AppliedRuleSources applied,
  AddedRuleSet set,
) {
  final aligned = alignRuleSources(
    list: list,
    applied: applied,
    profileId: set.profileId,
  );
  if (aligned == null) return null;
  final matches = <RuleSetView>[];
  for (var i = 0; i < aligned.length; i++) {
    final source = aligned[i];
    final rule = list.rules[i];
    if (source?.ruleId == set.id &&
        source?.text == rule.text &&
        rule.ruleSet != null) {
      matches.add(rule.ruleSet!);
    }
  }
  return matches.length == 1 ? matches.single : null;
}

/// Name alone never establishes ownership, including for global references.
AddedRuleSet? pairedAddedRuleSetFor(
  Rule rule,
  Iterable<AddedRuleSet> sets,
  int profileId,
) {
  if (rule.profileId != profileId || rule.ruleAction != RuleAction.RULE_SET) {
    return null;
  }
  return sets
      .where(
        (set) =>
            set.profileId == profileId &&
            set.id == rule.id &&
            set.name == rule.ruleProvider,
      )
      .firstOrNull;
}
