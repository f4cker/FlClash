part of '../action.dart';

typedef _MountRelay = ({List<String> names, List<String> managed});

/// Mount operations run one at a time. Each save writes the relation with a
/// pending record first, and only a readback, or a target that is not
/// running, clears it; an unknown outcome keeps the target locked.
@Riverpod(keepAlive: true)
class MountAction extends _$MountAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  final _scheduler = SerialTaskScheduler();
  final _inspectionPool = _MountInspectionPool();
  final _panelLoads = <VoidCallback>{};
  final _inspectionCache = <String, MountSourceInspection>{};
  var _cacheEpoch = 0;

  void _clearInspectionCache() {
    _cacheEpoch++;
    _inspectionCache.clear();
  }

  @override
  void build() {
    ref.listen(initProvider, (_, _) => _clearInspectionCache());
    ref.listen(versionProvider, (_, _) => _clearInspectionCache());
    ref.listen(coreStatusProvider, (_, _) => _clearInspectionCache());
    ref.listen(coreHandlerProvider, (_, _) => _clearInspectionCache());
    ref.onDispose(() {
      for (final cancel in _panelLoads.toList()) {
        cancel();
      }
    });
  }

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

    void cancel() {
      active = false;
      deadline?.cancel();
      _inspectionPool.cancel(owner);
      for (final subscription in subscriptions) {
        subscription.close();
      }
      subscriptions.clear();
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
        subscriptions.add(
          ref.listen(
            setupStateProvider(targetId).future,
            (_, _) => fail(contextChanged: true),
          ),
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
    final result = await _inspect(source, relay, isCurrent: isCurrent);
    if (!isCurrent()) return null;
    if (key != null &&
        result != null &&
        mountSourceItem(source, result).state.mountable &&
        key == await compute(_mountSourceFingerprint, input) &&
        isCurrent() &&
        epoch == _cacheEpoch) {
      if (_inspectionCache.length >= 128) {
        _inspectionCache.remove(_inspectionCache.keys.first);
      }
      _inspectionCache[key] = result;
    }
    return result;
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
        .mountTargetInput(targetId);
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
    return _core.inspectMountTarget(
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
  }) {
    return _scheduler.run(
      () => _save(targetId, expectedVersion, sourceIds, onStored),
    );
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
    final setup = ref.read(setupActionProvider.notifier);
    final applied = await setup.applyProfile(silence: true);
    final outcome = await _confirm(saved, applied: applied);
    if (outcome != MountSaveOutcome.unknown) {
      await _settle(saved);
    }
    return MountSaveResult(
      outcome: outcome,
      state: saved,
      lostSelections: setup.lostMountSelections,
    );
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

  /// Updates [sourceId] and, when the current profile mounts it, applies
  /// and reads the result back.
  Future<MountSourceRefresh> refreshSource(int sourceId, {int? targetId}) {
    _clearInspectionCache();
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
      final item = await _item(sourceId, targetId);
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
      final setup = ref.read(setupActionProvider.notifier);
      final applied = await setup.applyProfile(silence: true);
      return MountSourceRefresh(
        updated: true,
        item: item,
        application: await _confirm(target, applied: applied),
        lostSelections: setup.lostMountSelections,
      );
    });
  }

  Future<MountSourceItem?> _item(int sourceId, int? targetId) async {
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
    _MountRelay? relay;
    if (targetId != null) {
      try {
        relay = _relayOf(targetId, await readGroups(targetId));
      } catch (error) {
        commonPrint.log(
          'mount groups unreadable: ${compactError(error)}',
          logLevel: LogLevel.warning,
        );
      }
    }
    return mountSourceItem(
      profile,
      relay == null
          ? null
          : await _inspectionPool.run(() => _inspect(profile, relay)),
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
  deleteSource(int sourceId) {
    return _scheduler.run(() async {
      final List<MountTargetState> marked;
      try {
        marked = await database.mountsDao.beginSourceRemoval(sourceId);
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
        if (!_isRunning(target.targetId)) {
          await _settle(target);
          continue;
        }
        final result = await _applyAndSettle(target);
        known &= result.outcome != MountSaveOutcome.unknown;
      }
      if (!known) {
        return (result: MountSourceDeletion.unknown, unlink: null);
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
  var _active = 0;

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

  void add(Object owner, Future<void> Function() run) {
    _waiting.add((owner: owner, run: run));
    _drain();
  }

  void cancel(Object owner) {
    _waiting.removeWhere((job) => identical(job.owner, owner));
  }

  void _drain() {
    while (_active < 4 && _waiting.isNotEmpty) {
      final job = _waiting.removeAt(0);
      _active++;
      unawaited(_run(job.run));
    }
  }

  Future<void> _run(Future<void> Function() run) async {
    try {
      await run();
    } finally {
      // Cancellation removes queued work, never a live RPC's slot.
      _active--;
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
