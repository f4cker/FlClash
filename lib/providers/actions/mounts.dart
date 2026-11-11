part of '../action.dart';

/// Mount operations run one at a time. Each save writes the relation with a
/// pending record first, and only a readback, or a target that is not
/// running, clears it; an unknown outcome keeps the target locked.
@Riverpod(keepAlive: true)
class MountAction extends _$MountAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  final _scheduler = SerialTaskScheduler();

  @override
  void build() {}

  Future<MountPanel> loadPanel(int targetId) async {
    final target = ref.read(profilesProvider).getProfile(targetId);
    if (target == null) {
      throw StateError('profile $targetId is gone');
    }
    final (stored, records) = await (
      database.mountsDao.target(targetId),
      database.mountsDao.statuses(),
    ).wait;
    final mounted = {...?stored?.sourceIds};
    final sources = <MountSourceItem>[];
    for (final profile in ref.read(profilesProvider)) {
      if (profile.type != ProfileType.url || profile.id == targetId) {
        continue;
      }
      sources.add(
        mountSourceItem(
          profile,
          await _inspect(profile),
          mounted: mounted.contains(profile.id),
          record: records[profile.id],
        ),
      );
    }
    MountTarget? groups;
    try {
      groups = await readGroups(targetId);
    } catch (error) {
      commonPrint.log(
        'mount groups unreadable: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
    return MountPanel(
      target: target,
      stored: stored,
      sources: sources,
      groups: groups,
    );
  }

  Future<MountSourceInspection?> _inspect(Profile source) async {
    try {
      return await _core.inspectMountSource(
        await appPath.getProfilePath(source.id.toString()),
        ageSecretKey: source.ageSecretKey,
      );
    } catch (error) {
      commonPrint.log(
        'mount source unreadable: ${compactError(error)}',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  Future<MountTarget> readGroups(int targetId) async {
    final input = await ref
        .read(setupActionProvider.notifier)
        .mountTargetInput(targetId);
    return _core.inspectMountTarget(base: input.base, config: input.config);
  }

  /// [expectedVersion] is the version the choice was made on, null for a
  /// target never mounted. A save that drops every source is never held up
  /// by its groups.
  Future<MountSaveResult> save(
    int targetId, {
    required int? expectedVersion,
    required List<int> sourceIds,
    required List<String> groups,
  }) {
    return _scheduler.run(
      () => _save(targetId, expectedVersion, sourceIds, groups),
    );
  }

  Future<MountSaveResult> _save(
    int targetId,
    int? expectedVersion,
    List<int> sourceIds,
    List<String> groups,
  ) async {
    final MountTargetState? current;
    try {
      current = await database.mountsDao.target(targetId);
    } catch (_) {
      return const MountSaveResult(outcome: MountSaveOutcome.unchanged);
    }
    if (current?.pending != null) {
      return MountSaveResult(outcome: MountSaveOutcome.locked, state: current);
    }
    if (current?.version != expectedVersion) {
      return MountSaveResult(
        outcome: MountSaveOutcome.unchanged,
        state: current,
      );
    }
    final candidate = MountTargetState(
      targetId: targetId,
      sourceIds: sourceIds,
      groups: groups,
      version: (expectedVersion ?? 0) + 1,
    );
    final MountPreflight preflight;
    try {
      final input = await ref
          .read(setupActionProvider.notifier)
          .mountTargetInput(targetId);
      preflight = await _core.preflightMounts(
        base: input.base,
        config: input.config,
        mounts: mountSetupOf(
          candidate,
          ref.read(profilesProvider),
          await appPath.profilesPath,
        ),
      );
    } catch (error) {
      return MountSaveResult(
        outcome: MountSaveOutcome.unchanged,
        message: _messageOf(error),
      );
    }
    if (preflight.errorCode == 'mount_group_changed') {
      return const MountSaveResult(outcome: MountSaveOutcome.groupsChanged);
    }
    if (preflight.error case final error?) {
      return MountSaveResult(
        outcome: MountSaveOutcome.unchanged,
        message: error,
      );
    }
    if (sourceIds.isNotEmpty && (preflight.report?.groups.isEmpty ?? true)) {
      return const MountSaveResult(outcome: MountSaveOutcome.needsGroup);
    }
    final MountTargetState saved;
    try {
      saved = await database.mountsDao.save(
        targetId: targetId,
        expectedVersion: expectedVersion,
        sourceIds: sourceIds,
        groups: groups,
        pending: (version) => MountOperation(
          kind: MountOperationKind.save,
          version: version,
          sourceIds: sourceIds,
        ),
      );
    } on MountOperationUnresolved {
      return const MountSaveResult(outcome: MountSaveOutcome.locked);
    } catch (_) {
      return const MountSaveResult(outcome: MountSaveOutcome.unchanged);
    }
    return _applyAndSettle(saved);
  }

  /// Reads the running state back for a target whose last save or removal
  /// has no known outcome, and clears its record once that is proven.
  Future<MountSaveResult> recheck(int targetId) {
    return _scheduler.run(() async {
      final MountTargetState? current;
      try {
        current = await database.mountsDao.target(targetId);
      } catch (_) {
        return const MountSaveResult(outcome: MountSaveOutcome.unknown);
      }
      if (current == null) {
        return const MountSaveResult(outcome: MountSaveOutcome.saved);
      }
      final outcome = await _confirm(current, applied: null);
      if (current.pending != null && outcome != MountSaveOutcome.unknown) {
        await _settle(current);
      }
      return MountSaveResult(outcome: outcome, state: current);
    });
  }

  Future<MountSaveResult> _applyAndSettle(MountTargetState saved) async {
    if (!_isRunning(saved.targetId)) {
      await _settle(saved);
      return MountSaveResult(outcome: MountSaveOutcome.saved, state: saved);
    }
    final before = await _readState();
    final applied = await ref
        .read(setupActionProvider.notifier)
        .applyProfile(silence: true);
    final outcome = await _confirm(saved, applied: applied);
    if (outcome != MountSaveOutcome.unknown) {
      await _settle(saved);
    }
    final lost = outcome == MountSaveOutcome.applied
        ? await _followSelections(before?.report)
        : const <String>[];
    return MountSaveResult(
      outcome: outcome,
      state: saved,
      lostSelections: lost,
    );
  }

  bool _isRunning(int targetId) =>
      ref.read(initProvider) && ref.read(currentProfileIdProvider) == targetId;

  Future<MountRuntimeState?> _readState() async {
    try {
      return await _core.getMountState();
    } catch (error) {
      commonPrint.log(
        'mount state unreadable: ${compactError(error)}',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  /// [applied] is what the apply returned, null for a readback alone.
  Future<MountSaveOutcome> _confirm(
    MountTargetState state, {
    required bool? applied,
  }) async {
    if (!_isRunning(state.targetId)) {
      return MountSaveOutcome.saved;
    }
    final String? revision;
    try {
      final setupState = await ref.read(
        setupStateProvider(state.targetId).future,
      );
      revision = setupState.mounts?.revision;
    } catch (_) {
      return MountSaveOutcome.unknown;
    }
    final runtime = await _readState();
    if (runtime == null || revision == null) {
      return MountSaveOutcome.unknown;
    }
    if (confirmMounts(runtime, revision) case final outcome?) {
      return outcome;
    }
    return applied == false
        ? MountSaveOutcome.applyFailedKept
        : MountSaveOutcome.applyFailed;
  }

  Future<void> _settle(MountTargetState state) async {
    try {
      await database.mountsDao.settle(state.targetId, state.version);
    } catch (error) {
      commonPrint.log(
        'mount record not settled: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
  }

  /// Moves each selection of a mounted node to its name in the new report.
  Future<List<String>> _followSelections(MountReport? before) async {
    final after = (await _readState())?.report;
    final profile = ref.read(currentProfileProvider);
    if (after == null || profile == null) {
      return const [];
    }
    final lost = <String>[];
    final proxies = ref.read(proxiesActionProvider.notifier);
    for (final MapEntry(key: group, value: selected)
        in profile.selectedMap.entries) {
      final next = remapMountedSelection(selected, before, after);
      if (next == null) {
        lost.add(group);
      } else if (next != selected) {
        await proxies.changeProxy(groupName: group, proxyName: next);
      }
    }
    return lost;
  }

  String? _messageOf(Object error) => switch (error) {
    MessageException(:final message) => message,
    CoreMethodException(:final message) => message,
    _ => null,
  };

  /// Updates [sourceId] and, when the current profile mounts it, applies
  /// and reads the result back.
  Future<MountSourceRefresh> refreshSource(int sourceId) {
    return _scheduler.run(() async {
      final profile = ref.read(profilesProvider).getProfile(sourceId);
      if (profile == null) {
        return const MountSourceRefresh(updated: false);
      }
      String? message;
      try {
        await ref
            .read(profilesActionProvider.notifier)
            .updateProfile(profile, showLoading: true);
      } catch (error) {
        message = _messageOf(error) ?? compactError(error);
      }
      final item = await _item(sourceId);
      if (message != null) {
        return MountSourceRefresh(updated: false, item: item, message: message);
      }
      final currentId = ref.read(currentProfileIdProvider);
      final MountTargetState? target;
      try {
        target = currentId == null
            ? null
            : await database.mountsDao.target(currentId);
      } catch (_) {
        return MountSourceRefresh(
          updated: true,
          item: item,
          application: MountSaveOutcome.unknown,
        );
      }
      if (target == null || !target.sourceIds.contains(sourceId)) {
        return MountSourceRefresh(updated: true, item: item);
      }
      final applied = await ref
          .read(setupActionProvider.notifier)
          .applyProfile(silence: true);
      return MountSourceRefresh(
        updated: true,
        item: item,
        application: await _confirm(target, applied: applied),
      );
    });
  }

  Future<MountSourceItem?> _item(int sourceId) async {
    final profile = ref.read(profilesProvider).getProfile(sourceId);
    if (profile == null) {
      return null;
    }
    Map<int, MountSourceRecord> records;
    try {
      records = await database.mountsDao.statuses();
    } catch (_) {
      records = const {};
    }
    return mountSourceItem(
      profile,
      await _inspect(profile),
      mounted: true,
      record: records[sourceId],
    );
  }

  /// The profiles that mount [sourceId]; throws when they cannot be read,
  /// which must not pass for a source nobody mounts.
  Future<List<Profile>> sourceTargets(int sourceId) async {
    final ids = await database.mountsDao.targetsOf(sourceId);
    final profiles = ref.read(profilesProvider);
    return [for (final id in ids) ?profiles.getProfile(id)];
  }

  /// Unmounts [sourceId] from every target, applies the current one, then
  /// deletes the profile. Nothing happens while a target has a record
  /// pending.
  Future<MountSourceDeletion> deleteSource(int sourceId) {
    return _scheduler.run(() async {
      final List<MountTargetState> marked;
      try {
        marked = await database.mountsDao.beginSourceRemoval(sourceId);
      } on MountOperationUnresolved {
        return MountSourceDeletion.blocked;
      } catch (_) {
        return MountSourceDeletion.unchanged;
      }
      var known = true;
      for (final target in marked) {
        if (!_isRunning(target.targetId)) {
          await _settle(target);
          continue;
        }
        final result = await _applyAndSettle(target);
        known &= result.outcome != MountSaveOutcome.unknown;
      }
      final outcome = await ref
          .read(profilesActionProvider.notifier)
          .deleteProfile(sourceId);
      if (outcome != TailscaleUnlinkOutcome.done) {
        return MountSourceDeletion.keptProfile;
      }
      return known ? MountSourceDeletion.deleted : MountSourceDeletion.unknown;
    });
  }
}
