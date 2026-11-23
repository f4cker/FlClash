part of '../action.dart';

typedef _MountRelay = ({List<String> names, List<String> managed});

typedef MountEditIssue = ({String reason, bool blocking});

/// Mount operations run one at a time. Each save writes the relation with a
/// pending record first, and only a readback, or a target that is not
/// running, clears it; an unknown outcome keeps the target locked.
@Riverpod(keepAlive: true)
class MountAction extends _$MountAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  final _scheduler = SerialTaskScheduler();
  final _applyingTargets = <int>{};

  /// Runs [task] on the mount mutation scheduler: no mount operation is in
  /// its scheduled section meanwhile, and none starts until [task] ends.
  /// [task] must not wait for the setup scheduler or another mount operation.
  Future<T> runExclusive<T>(Future<T> Function() task) => _scheduler.run(task);

  Future<void> installSource(int sourceId, VoidCallback install) =>
      _scheduler.run(() async {
        if (await hasPendingRemoval(sourceId)) {
          throw const ProfileUpdateSuperseded();
        }
        install();
      });

  final _inspectionPool = _MountInspectionPool();
  final _panelLoads = <VoidCallback>{};
  final _inspectionCache = <String, MountSourceInspection>{};
  final _inspectionFlights =
      <
        String,
        ({Future<MountSourceInspection?> result, bool Function() isCurrent})
      >{};
  var _cacheEpoch = 0;
  final _targetIntents = <int, int>{};

  void _clearInspectionCache() {
    _cacheEpoch++;
    _inspectionCache.clear();
    _inspectionFlights.clear();
  }

  @override
  void build() {
    ref.listen(initProvider, (_, _) => _clearInspectionCache());
    ref.listen(versionProvider, (_, _) => _clearInspectionCache());
    ref.listen(coreStatusProvider, (_, _) => _clearInspectionCache());
    ref.listen(coreHandlerProvider, (_, _) => _clearInspectionCache());
    ref.onDispose(() {
      _clearInspectionCache();
      for (final cancel in _panelLoads.toList()) {
        cancel();
      }
    });
  }

  Future<MountSourceInspection> inspectDownloadedSource(
    String path,
    String key,
  ) => _inspectionPool.run(
    () => _core.inspectMountSource(path, ageSecretKey: key),
  );

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
    final sources = [
      for (final profile in ref.read(profilesProvider))
        if (profile.type == ProfileType.url && profile.id != targetId)
          MountSourceItem(
            profile: profile,
            state: MountSourceState.pending,
            mounted: mounted.contains(profile.id),
            record: records[profile.id],
          ),
    ];
    return MountPanel(
      target: target,
      stored: stored,
      sources: sources,
      groupsPending: true,
      revision: stored == null
          ? null
          : mountSetupOf(
              stored,
              ref.read(profilesProvider),
              await appPath.profilesPath,
            ).revision,
    );
  }

  Stream<MountPanel> watchPanel(int targetId, {bool refresh = false}) {
    if (refresh) _clearInspectionCache();
    late StreamController<MountPanel> controller;
    final owner = Object();
    late VoidCallback disposeLoad;
    var active = true;
    Timer? deadline;
    MountPanel? panel;
    final subscriptions = <ProviderSubscription<dynamic>>[];
    StreamSubscription<dynamic>? databaseChanges;

    void cancel() {
      active = false;
      deadline?.cancel();
      _inspectionPool.cancel(owner);
      for (final subscription in subscriptions) {
        subscription.close();
      }
      subscriptions.clear();
      unawaited(databaseChanges?.cancel());
      _panelLoads.remove(disposeLoad);
    }

    void finish() {
      cancel();
      unawaited(controller.close());
    }

    void publish(MountPanel value) {
      panel = value;
      controller.add(value);
    }

    void fail({bool contextChanged = false}) {
      if (!active) return;
      final current = panel;
      if (current == null) {
        controller.addError(TimeoutException('mount metadata'));
      } else {
        publish(
          current.copyWith(
            groups: contextChanged || current.groupsPending
                ? null
                : current.groups,
            groupsPending: false,
            sources: [
              for (final item in current.sources)
                contextChanged || item.state == MountSourceState.pending
                    ? item.copyWith(state: MountSourceState.unreadable)
                    : item,
            ],
          ),
        );
      }
      finish();
    }

    Future<void> inspect() async {
      MountTarget? groups;
      String? targetKey;
      try {
        groups = await _readGroups(
          targetId,
          isCurrent: () => active && ref.mounted,
          onInput: (input) async {
            final fingerprint = await compute(_mountTargetFingerprint, input);
            targetKey = fingerprint == null ? null : '$targetId:$fingerprint';
          },
        );
      } catch (error) {
        commonPrint.log(
          'mount groups unreadable: ${compactError(error)}',
          logLevel: LogLevel.warning,
        );
      }
      if (!active || !ref.mounted) return;
      deadline?.cancel();
      final relay = _relayOf(targetId, groups);
      if (relay == null) {
        fail(contextChanged: true);
        return;
      }
      publish(panel!.copyWith(groups: groups, groupsPending: false));
      var remaining = panel!.sources.length;
      if (remaining == 0) {
        finish();
        return;
      }
      deadline = Timer(const Duration(seconds: 10), fail);
      for (var index = 0; index < panel!.sources.length; index++) {
        final position = index;
        final item = panel!.sources[position];
        _inspectionPool.add(owner, () async {
          final result = await _inspectCached(
            item.profile,
            relay,
            targetKey: targetKey,
            isCurrent: () => active && ref.mounted,
          );
          if (!active || !ref.mounted) return;
          final sources = [...panel!.sources];
          sources[position] = mountSourceItem(
            item.profile,
            result,
            mounted: item.mounted,
            record: item.record,
          );
          publish(panel!.copyWith(sources: sources));
          if (--remaining == 0) finish();
        });
      }
    }

    Future<void> start() async {
      deadline = Timer(const Duration(seconds: 10), fail);
      try {
        final metadata = await loadPanel(targetId);
        if (!active || !ref.mounted) return;
        publish(metadata);
        if (!metadata.groupsPending) {
          finish();
          return;
        }
        subscriptions.add(
          ref.listen(profilesProvider, (_, _) => fail(contextChanged: true)),
        );
        subscriptions.add(
          ref.listen(
            tailscaleManagedRecordsProvider,
            (_, _) => fail(contextChanged: true),
          ),
        );
        subscriptions.add(
          ref.listen(
            patchClashConfigProvider,
            (_, _) => fail(contextChanged: true),
          ),
        );
        // Observe table changes directly: listening to setupState would eagerly
        // assemble rules, scripts and MITM files just to invalidate this panel.
        databaseChanges = database.tableUpdates().listen(
          (_) => fail(contextChanged: true),
        );
        _inspectionPool.add(owner, inspect);
      } catch (error, stack) {
        if (!active) return;
        controller.addError(error, stack);
        finish();
      }
    }

    disposeLoad = finish;
    controller = StreamController<MountPanel>(
      onListen: () {
        _panelLoads.add(disposeLoad);
        unawaited(start());
      },
      onCancel: cancel,
    );
    return controller.stream;
  }

  /// Null while either is unread: a guessed list would undercount.
  _MountRelay? _relayOf(int targetId, MountTarget? groups) {
    final records = ref.read(tailscaleManagedRecordsProvider);
    if (groups == null || records == null) {
      return null;
    }
    return (
      names: groups.relay,
      managed: [
        for (final record in records)
          if (record.profileId == targetId) record.name,
      ],
    );
  }

  Future<MountSourceInspection?> _inspectCached(
    Profile source,
    _MountRelay relay, {
    required String? targetKey,
    required bool Function() isCurrent,
  }) async {
    String? key;
    final epoch = _cacheEpoch;
    final path = await appPath.getProfilePath(source.id.toString());
    if (!isCurrent()) return null;
    final input = (
      path: path,
      secret: source.ageSecretKey,
      target: targetKey,
      relay: relay.names,
      managed: relay.managed,
      version: ref.read(versionProvider).toString(),
    );
    if (targetKey != null) key = await compute(_mountSourceFingerprint, input);
    if (!isCurrent()) return null;
    if (key != null && epoch == _cacheEpoch) {
      final cached = _inspectionCache.remove(key);
      if (cached != null) {
        _inspectionCache[key] = cached;
        return cached;
      }
    }
    bool valid() => isCurrent() && epoch == _cacheEpoch;
    if (key != null) {
      final flight = _inspectionFlights[key];
      if (flight != null && flight.isCurrent()) {
        final result = await flight.result;
        if (valid() && result != null) return result;
        if (!valid()) return null;
      }
    }
    Future<MountSourceInspection?> inspect() async {
      final result = await _inspect(source, relay, isCurrent: valid);
      if (!valid()) return null;
      if (key != null &&
          result != null &&
          mountSourceItem(source, result).state.mountable) {
        if (key != await compute(_mountSourceFingerprint, input) || !valid()) {
          return null;
        }
        if (_inspectionCache.length >= 128) {
          _inspectionCache.remove(_inspectionCache.keys.first);
        }
        _inspectionCache[key!] = result;
      }
      return valid() ? result : null;
    }

    final result = inspect();
    final flight = (result: result, isCurrent: valid);
    if (key != null) _inspectionFlights[key] = flight;
    try {
      return await result;
    } finally {
      if (key != null && identical(_inspectionFlights[key]?.result, result)) {
        _inspectionFlights.remove(key);
      }
    }
  }

  Future<MountSourceInspection?> _inspect(
    Profile source,
    _MountRelay? relay, {
    bool Function()? isCurrent,
  }) async {
    try {
      final path = await appPath.getProfilePath(source.id.toString());
      if (isCurrent != null && !isCurrent()) return null;
      return await _core.inspectMountSource(
        path,
        ageSecretKey: source.ageSecretKey,
        relay: relay?.names,
        managed: relay?.managed,
      );
    } catch (error) {
      commonPrint.log(
        'mount source unreadable: ${compactError(error)}',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  Future<MountTarget> readGroups(int targetId) =>
      _inspectionPool.run(() => _readGroups(targetId));

  Future<MountTarget> _readGroups(
    int targetId, {
    bool Function()? isCurrent,
    Future<void> Function(({SetupBase? base, String? config}))? onInput,
  }) async {
    final input = await ref
        .read(setupActionProvider.notifier)
        .mountTargetProjectionInput(targetId);
    if (isCurrent != null && !isCurrent()) {
      throw StateError('mount inspection superseded');
    }
    await onInput?.call(input);
    if (isCurrent != null && !isCurrent()) {
      throw StateError('mount inspection superseded');
    }
    // Unread records leave the rules out, as the safer reading.
    final records = ref.read(tailscaleManagedRecordsProvider);
    final managed =
        records?.any(
          (record) =>
              record.profileId == targetId &&
              record.id.isNotEmpty &&
              record.attached,
        ) ??
        false;
    return _core.inspectMountTargetProjection(
      base: input.base,
      config: input.config,
      managedTarget: managed ? targetId : null,
    );
  }

  /// [expectedVersion] is the version the choice was made on, null for a
  /// target never mounted. A save that drops every source is never held up
  /// by its groups. [onStored] runs once the relation is written and its
  /// apply begins.
  Future<MountSaveResult> save(
    int targetId, {
    required int? expectedVersion,
    required List<int> sourceIds,
    VoidCallback? onStored,
  }) async {
    final intent = (_targetIntents[targetId] ?? 0) + 1;
    _targetIntents[targetId] = intent;
    try {
      final previous = await database.mountsDao.target(targetId);
      if (_targetIntents[targetId] == intent &&
          previous?.version == expectedVersion) {
        final profiles = ref.read(profilesActionProvider.notifier);
        for (final id in previous?.sourceIds ?? <int>[]) {
          if (!sourceIds.contains(id)) profiles.cancelSourceUpdate(id);
        }
      }
    } catch (_) {
      // The serialized save reports unreadability; it must not cancel sources
      // belonging to unrelated targets, or an active standalone refresh.
    }
    final result = await _scheduler.run(
      () => _save(targetId, expectedVersion, sourceIds, onStored),
    );
    return result.outcome == MountSaveOutcome.saved && result.state != null
        ? _applyAndSettle(result.state!)
        : result;
  }

  Future<MountSaveResult> _save(
    int targetId,
    int? expectedVersion,
    List<int> sourceIds,
    VoidCallback? onStored,
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
      version: (expectedVersion ?? 0) + 1,
    );
    final MountPreflight preflight;
    try {
      preflight = await _inspectionPool.run(() async {
        final input = await ref
            .read(setupActionProvider.notifier)
            .mountTargetInput(targetId);
        return _core.preflightMounts(
          base: input.base,
          config: input.config,
          mounts: mountSetupOf(
            candidate,
            ref.read(profilesProvider),
            await appPath.profilesPath,
          ),
        );
      });
    } catch (error) {
      return MountSaveResult(
        outcome: MountSaveOutcome.unchanged,
        message: _messageOf(error),
      );
    }
    if (preflight.error case final error?) {
      return MountSaveResult(
        outcome: MountSaveOutcome.unchanged,
        message: error,
      );
    }
    // Nodes no group takes are not mounted; a pure removal still goes on.
    final adds = sourceIds.any(
      (id) => !(current?.sourceIds.contains(id) ?? false),
    );
    if (adds && (preflight.report?.groups.isEmpty ?? true)) {
      return const MountSaveResult(outcome: MountSaveOutcome.needsGroup);
    }
    // Cached panel counts are advisory: the live guard is only authoritative here.
    final additions = sourceIds.where(
      (id) => !(current?.sourceIds.contains(id) ?? false),
    );
    _clearInspectionCache();
    for (final id in additions) {
      final reports = preflight.report?.sources.where(
        (source) => source.id == id,
      );
      if (reports == null || reports.length != 1) {
        return const MountSaveResult(outcome: MountSaveOutcome.unchanged);
      }
      final report = reports.single;
      if (report.status != MountSourceStatus.nodes ||
          report.nodes.isEmpty &&
              (report.tailscaleExcluded > 0 ||
                  report.relayExcluded > 0 ||
                  report.unsupportedExcluded > 0)) {
        return const MountSaveResult(outcome: MountSaveOutcome.unchanged);
      }
    }
    final MountTargetState saved;
    try {
      saved = await database.mountsDao.save(
        targetId: targetId,
        expectedVersion: expectedVersion,
        sourceIds: sourceIds,
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
    ref.invalidate(setupStateProvider(targetId));
    onStored?.call();
    _applyingTargets.add(saved.targetId);
    return MountSaveResult(outcome: MountSaveOutcome.saved, state: saved);
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
      if (_applyingTargets.contains(targetId)) {
        return MountSaveResult(
          outcome: MountSaveOutcome.locked,
          state: current,
        );
      }
      final outcome = await _confirm(current, applied: null);
      if (current.pending != null && outcome != MountSaveOutcome.unknown) {
        await _settle(current);
      }
      return MountSaveResult(outcome: outcome, state: current);
    });
  }

  /// Makes every in-flight save, source update or apply for [targetIds] lose
  /// ownership, so none of them lands over what a restore writes.
  void supersedeTargets(Iterable<int> targetIds) {
    for (final id in targetIds) {
      _targetIntents[id] = (_targetIntents[id] ?? 0) + 1;
    }
  }

  /// After a restore rebuilt [targetIds], each with its own pending record:
  /// one the Core does not run has no outcome to wait for and is settled. A
  /// running one stays pending until the user checks it again; nothing is
  /// applied from here. Returns the ids still pending.
  Future<List<int>> settleRestored(Iterable<int> targetIds) {
    return _scheduler.run(() async {
      final still = <int>[];
      for (final id in targetIds) {
        final current = await database.mountsDao.target(id);
        final pending = current?.pending;
        if (current == null || pending == null) continue;
        if (_isRunning(id) || _applyingTargets.contains(id)) {
          still.add(id);
          continue;
        }
        if (await database.mountsDao.settle(id, pending.version)) {
          ref.invalidate(setupStateProvider(id));
        } else {
          still.add(id);
        }
      }
      return still;
    });
  }

  Future<MountSaveResult> _applyAndSettle(MountTargetState saved) async {
    try {
      if (!_isRunning(saved.targetId)) {
        return await _scheduler.run(() async {
          await _settle(saved);
          return MountSaveResult(outcome: MountSaveOutcome.saved, state: saved);
        });
      }
      final setup = ref.read(setupActionProvider.notifier);
      final applied = await setup.applyProfile(silence: true);
      return await _scheduler.run(() async {
        final outcome = await _confirm(saved, applied: applied);
        if (outcome != MountSaveOutcome.unknown) await _settle(saved);
        return MountSaveResult(
          outcome: outcome,
          state: saved,
          lostSelections: setup.lostMountSelections,
        );
      });
    } finally {
      _applyingTargets.remove(saved.targetId);
    }
  }

  /// What the Core runs for [targetId], null when it runs another profile
  /// or cannot be read.
  Future<MountRuntimeState?> readRuntime(int targetId) async {
    if (!_isRunning(targetId)) {
      return null;
    }
    final state = await _readState();
    return state?.report?.target == targetId ? state : null;
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
      ref.invalidate(setupStateProvider(state.targetId));
    } catch (error) {
      commonPrint.log(
        'mount record not settled: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
  }

  String? _messageOf(Object error) => switch (error) {
    MessageException(:final message) => message,
    CoreMethodException(:final message) => message,
    _ => null,
  };

  /// A subscription's own problem does not hold the edit.
  Future<MountEditIssue?> preflightEdit(int targetId, List<int> data) async {
    final target = await database.mountsDao.target(targetId);
    if (target == null || target.sourceIds.isEmpty) return null;
    final mounts = mountSetupOf(
      target,
      ref.read(profilesProvider),
      await appPath.profilesPath,
    );
    if (mounts.sources.isEmpty) return null;
    final edited = File(await appPath.tempFilePath);
    final MountPreflight preflight;
    try {
      await edited.safeWriteAsBytes(data);
      preflight = await _inspectionPool.run(() async {
        final input = await ref
            .read(setupActionProvider.notifier)
            .mountTargetInput(targetId, profilePath: edited.path);
        return _core.preflightMounts(
          base: input.base,
          config: input.config,
          mounts: mounts,
        );
      });
    } finally {
      await edited.safeDelete();
    }
    final error = preflight.error;
    if (error == null) return null;
    commonPrint.log(
      'edited profile rejected with its mounts: $error',
      logLevel: LogLevel.warning,
    );
    return (
      reason: mountRejectedReason(
        error,
        currentAppLocalizations,
        sourceName: (id) => mounts.sources
            .where((source) => source.id == id)
            .firstOrNull
            ?.label,
      ),
      blocking: !isMountSourceProblem(error),
    );
  }

  /// Downloads are deliberately outside the mutation scheduler so a later
  /// refresh/removal owns its source immediately, even during a slow download.
  Future<MountSourceRefresh> refreshSource(
    int sourceId, {
    int? targetId,
  }) async {
    _clearInspectionCache();
    final profile = ref.read(profilesProvider).getProfile(sourceId);
    if (profile == null) return const MountSourceRefresh(updated: false);
    try {
      return await ref
          .read(profilesActionProvider.notifier)
          .refreshProfile(profile, showLoading: true);
    } catch (error) {
      return MountSourceRefresh(
        updated: false,
        message: _messageOf(error) ?? compactError(error),
      );
    }
  }

  /// A batch publishes at most one current-target operation. Other targets
  /// consume the canonical cache when selected; they are never built here.
  Future<Map<int, MountSourceRefresh>> completeSourceUpdates(
    List<Profile> updated, {
    required int? targetId,
    required String? previousRevision,
    required bool targetCurrent,
    required Map<int, String> previousLabels,
  }) async {
    if (updated.isEmpty) return const {};
    final profiles = ref.read(profilesActionProvider.notifier);
    final intent = _targetIntents[targetId] ?? 0;
    var selected = targetCurrent;
    final subscription = ref.listen(currentProfileIdProvider, (_, next) {
      if (next != targetId) selected = false;
    });
    bool current() =>
        ref.mounted &&
        selected &&
        ref.read(currentProfileIdProvider) == targetId &&
        (_targetIntents[targetId] ?? 0) == intent;
    Future<Map<int, MountSourceRefresh>> Function()? applyOutside;
    try {
      final result = await _scheduler.run(() async {
        final active = updated.where(profiles.isSourceUpdateCurrent).toList();
        final results = <int, MountSourceRefresh>{
          for (final profile in active)
            profile.id: MountSourceRefresh(
              updated: true,
              item: profiles.sourceUpdateItem(profile),
            ),
        };
        Map<int, MountSourceRefresh> superseded() => {
          for (final entry in results.entries)
            entry.key: entry.value.copyWith(
              application: MountSaveOutcome.unchanged,
            ),
        };
        if (!current()) return superseded();
        if (targetId == null || !_isRunning(targetId)) return results;
        final target = await database.mountsDao.target(targetId);
        if (!current()) return superseded();
        final mounted = active
            .where((profile) => target?.sourceIds.contains(profile.id) ?? false)
            .toList();
        final standalone = active.any((profile) => profile.id == targetId);
        if (!standalone && mounted.isEmpty) {
          // Preserve explicit custom-profile provider references, independently
          // of mount relations, without rebuilding unrelated inactive targets.
          applyOutside = () async {
            if (!current() || !active.every(profiles.isSourceUpdateCurrent)) {
              return superseded();
            }
            await ref
                .read(clashProvidersActionProvider.notifier)
                .applyIfReferenced(ProviderKind.proxy, {
                  for (final profile in active) profile.realLabel,
                }, force: true);
            return results;
          };
          return <int, MountSourceRefresh>{};
        }
        MountTargetState? expectedTarget;
        String? expectedRevision;
        String? profilesPath;
        bool owns() =>
            current() &&
            active.every(profiles.isSourceUpdateCurrent) &&
            (expectedTarget == null ||
                mountSetupOf(
                      expectedTarget,
                      ref.read(profilesProvider),
                      profilesPath!,
                    ).revision ==
                    expectedRevision);
        if (!owns()) return superseded();
        if (target?.pending != null) {
          for (final profile in mounted) {
            results[profile.id] = results[profile.id]!.copyWith(
              application: MountSaveOutcome.locked,
            );
          }
          return results;
        }
        if (standalone) {
          applyOutside = () async {
            final applied = await ref
                .read(setupActionProvider.notifier)
                .applyProfile(silence: true, owns: owns);
            for (final profile in active) {
              results[profile.id] = results[profile.id]!.copyWith(
                application: !owns()
                    ? MountSaveOutcome.unchanged
                    : applied
                    ? MountSaveOutcome.applied
                    : MountSaveOutcome.applyFailedKept,
              );
            }
            return results;
          };
          return <int, MountSourceRefresh>{};
        }
        // Record the attempted refresh before the IPC. An ambiguous response
        // leaves this existing durable lock for explicit readback/reconciliation.
        final pending = await database.mountsDao.save(
          targetId: targetId,
          expectedVersion: target!.version,
          sourceIds: target.sourceIds,
          pending: (version) => MountOperation(
            kind: MountOperationKind.save,
            version: version,
            sourceIds: target.sourceIds,
          ),
        );
        ref.invalidate(setupStateProvider(targetId));
        profilesPath = await appPath.profilesPath;
        final next = mountSetupOf(
          pending,
          ref.read(profilesProvider),
          profilesPath,
        );
        expectedTarget = pending;
        expectedRevision = next.revision;
        final labelsUnchanged = pending.sourceIds.every(
          (id) =>
              previousLabels[id] ==
              ref.read(profilesProvider).getProfile(id)?.realLabel,
        );
        var outcome = MountSaveOutcome.unknown;
        MountRuntimeState? runtime;
        String? message;
        var lost = <String>[];
        var needsApply = false;
        bool? fallbackApplied;
        Future<void> fullApply() async {
          if (!owns()) {
            outcome = MountSaveOutcome.unchanged;
            return;
          }
          final setup = ref.read(setupActionProvider.notifier);
          fallbackApplied = await setup.applyProfile(silence: true, owns: owns);
          lost = setup.lostMountSelections;
          runtime = null;
        }

        try {
          final digests = <int, String>{};
          for (final profile in mounted) {
            final path = await appPath.getProfilePath(profile.id.toString());
            digests[profile.id] =
                (await sha256.bind(File(path).openRead()).first).toString();
          }
          final before = await _readState();
          if (!owns()) {
            outcome = MountSaveOutcome.unchanged;
          } else if (before?.report?.target != targetId) {
            outcome = MountSaveOutcome.unknown;
          } else if (before!.blocked) {
            outcome = MountSaveOutcome.applyFailedBlocked;
          } else if (previousRevision == null) {
            outcome = MountSaveOutcome.unknown;
          } else if (before.report!.revision != previousRevision ||
              !labelsUnchanged) {
            // Labels/relations or a previously unapplied source changed before
            // this download. The native request cannot prove those inputs.
            needsApply = true;
          } else {
            final response = await _core.refreshMountSources(
              target: targetId,
              generation: before.generation,
              revision: before.report!.revision,
              nextRevision: next.revision,
              sources: digests,
            );
            runtime = response.state;
            message = response.error;
            switch (response.outcome) {
              case MountRefreshOutcome.applied:
                outcome = response.state.report?.target == targetId
                    ? confirmMounts(response.state, next.revision) ??
                          MountSaveOutcome.unknown
                    : MountSaveOutcome.unknown;
                lost = response.state.lost;
              case MountRefreshOutcome.requiresApply:
                needsApply = true;
              case MountRefreshOutcome.superseded:
                outcome = MountSaveOutcome.unchanged;
              case MountRefreshOutcome.kept:
                outcome = MountSaveOutcome.applyFailedKept;
              case MountRefreshOutcome.unknown:
                outcome = MountSaveOutcome.unknown;
            }
          }
        } catch (error) {
          message = _messageOf(error) ?? compactError(error);
        }
        Future<Map<int, MountSourceRefresh>> finish() async {
          if (fallbackApplied != null) {
            outcome = owns()
                ? await _confirm(pending, applied: fallbackApplied)
                : MountSaveOutcome.unchanged;
          }
          if (outcome != MountSaveOutcome.unknown) await _settle(pending);
          for (final profile in mounted) {
            MountSourceReport? report;
            if (outcome == MountSaveOutcome.applied ||
                outcome == MountSaveOutcome.appliedUnverified) {
              for (final source
                  in runtime?.report?.sources ?? <MountSourceReport>[]) {
                if (source.id == profile.id) report = source;
              }
            }
            results[profile.id] = MountSourceRefresh(
              updated: profiles.isSourceUpdateCurrent(profile),
              item: profiles.sourceUpdateItem(profile, report: report),
              application: current() ? outcome : MountSaveOutcome.unchanged,
              message: message,
              lostSelections: lost,
            );
          }
          return results;
        }

        if (needsApply) {
          if (!owns()) {
            outcome = MountSaveOutcome.unchanged;
            return finish();
          }
          // Setup may itself need a canonical install. Never wait for its
          // scheduler while holding the mount mutation scheduler.
          _applyingTargets.add(targetId);
          applyOutside = () async {
            try {
              try {
                await fullApply();
              } catch (error) {
                message = _messageOf(error) ?? compactError(error);
              }
              return await _scheduler.run(finish);
            } finally {
              _applyingTargets.remove(targetId);
            }
          };
          return <int, MountSourceRefresh>{};
        }
        return finish();
      });
      return applyOutside == null ? result : await applyOutside!();
    } finally {
      subscription.close();
    }
  }

  /// The profiles that mount [sourceId]; throws when they cannot be read,
  /// which must not pass for a source nobody mounts.
  Future<List<Profile>> sourceTargets(int sourceId) async {
    final ids = await database.mountsDao.targetsOf(sourceId);
    final profiles = ref.read(profilesProvider);
    return [for (final id in ids) ?profiles.getProfile(id)];
  }

  /// Whether a profile mounting [sourceId] has an operation whose outcome is
  /// not yet known; an unreadable record counts as one.
  Future<bool> hasPendingRemoval(int sourceId) async {
    try {
      for (final id in await database.mountsDao.targetsOf(sourceId)) {
        if ((await database.mountsDao.target(id))?.pending != null) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Unmounts [sourceId] from every target, applies the current one, then
  /// deletes the profile. Nothing happens while a target has a record
  /// pending; an apply without a known outcome keeps the profile until
  /// [recheck] resolves it and the deletion is retried. [unlink] is the
  /// Tailscale outcome that kept a profile already unmounted.
  Future<({MountSourceDeletion result, TailscaleUnlinkOutcome? unlink})>
  deleteSource(int sourceId) async {
    ref.read(profilesActionProvider.notifier).cancelSourceUpdate(sourceId);
    final List<MountTargetState> marked;
    try {
      marked = await _scheduler.run(() async {
        final targets = await database.mountsDao.beginSourceRemoval(sourceId);
        _applyingTargets.addAll(targets.map((target) => target.targetId));
        return targets;
      });
    } on MountOperationUnresolved {
      return (result: MountSourceDeletion.blocked, unlink: null);
    } catch (_) {
      return (result: MountSourceDeletion.unchanged, unlink: null);
    }
    for (final target in marked) {
      ref.invalidate(setupStateProvider(target.targetId));
    }
    var known = true;
    for (final target in marked) {
      final result = await _applyAndSettle(target);
      known &= result.outcome != MountSaveOutcome.unknown;
    }
    if (!known) return (result: MountSourceDeletion.unknown, unlink: null);
    return _scheduler.run(() async {
      if (await database.mountsDao.isMounted(sourceId)) {
        return (result: MountSourceDeletion.blocked, unlink: null);
      }
      final outcome = await ref
          .read(profilesActionProvider.notifier)
          .deleteProfile(sourceId);
      return (
        result: outcome == TailscaleUnlinkOutcome.done
            ? MountSourceDeletion.deleted
            : MountSourceDeletion.keptProfile,
        unlink: outcome,
      );
    });
  }
}

class _MountInspectionPool {
  final _waiting = <({Object owner, Future<void> Function() run})>[];
  final _background = <({Object owner, Future<void> Function() run})>[];
  var _active = 0;
  var _backgroundActive = false;

  Future<T> run<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    add(Object(), () async {
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  void add(
    Object owner,
    Future<void> Function() run, {
    bool background = false,
  }) {
    (background ? _background : _waiting).add((owner: owner, run: run));
    _drain();
  }

  void cancel(Object owner) {
    _waiting.removeWhere((job) => identical(job.owner, owner));
    _background.removeWhere((job) => identical(job.owner, owner));
  }

  void _drain() {
    while (_active < 4) {
      final background = _waiting.isEmpty;
      if (background && (_backgroundActive || _background.isEmpty)) return;
      final job = (background ? _background : _waiting).removeAt(0);
      _active++;
      if (background) _backgroundActive = true;
      unawaited(_run(job.run, background: background));
    }
  }

  Future<void> _run(
    Future<void> Function() run, {
    required bool background,
  }) async {
    try {
      await run();
    } finally {
      // Cancellation removes queued work, never a live RPC's slot.
      _active--;
      if (background) _backgroundActive = false;
      _drain();
    }
  }
}

Future<String?> _mountTargetFingerprint(
  ({SetupBase? base, String? config}) input,
) async {
  try {
    final base = input.base;
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              input.config,
              base?.path,
              base?.overlay,
              if (base != null)
                (await sha256.bind(File(base.path).openRead()).first)
                    .toString(),
            ]),
          ),
        )
        .toString();
  } catch (_) {
    return null;
  }
}

Future<String?> _mountSourceFingerprint(
  ({
    String path,
    String? secret,
    String? target,
    List<String> relay,
    List<String> managed,
    String version,
  })
  input,
) async {
  try {
    final digest = await sha256.bind(File(input.path).openRead()).first;
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              1,
              input.path,
              digest.toString(),
              input.secret,
              input.target,
              input.relay,
              input.managed,
              input.version,
            ]),
          ),
        )
        .toString();
  } catch (_) {
    return null;
  }
}
