part of '../action.dart';

typedef BackupDelivery = Future<bool> Function(String archivePath);

/// Returns the archive to restore, or null when the user backed out. A source
/// that downloads writes to [downloadPath], which is removed afterwards.
typedef BackupFetch = Future<String?> Function(String downloadPath);

/// Shown the mount plan of a restore before anything is written; false
/// cancels it. [mitmModules] are the backup's MITM modules the restore
/// writes, each turned off until consented to on this device; confirming
/// never consents to them.
typedef RestoreMountConfirm =
    Future<bool> Function(
      RestoreMountPlan plan, {
      List<RestoreMitmModule> mitmModules,
    });

/// What a committed restore did to mounts. [stillPending] are the targets
/// that stay locked until checked again.
class RestoreMountResult {
  final RestoreMountPlan plan;
  final List<RestoreMountProfile> stillPending;

  const RestoreMountResult(this.plan, this.stillPending);
}

@Riverpod(keepAlive: true)
class BackupAction extends _$BackupAction {
  @override
  void build() {}

  @visibleForTesting
  Future<void> Function()? afterRestoreCommit;

  /// A backup never carries another restore's commit marker.
  static Future<void> _dropRestoreCommits(String snapshotPath) async {
    final snapshot = Database(NativeDatabase(File(snapshotPath)));
    try {
      await snapshot.customStatement(
        'DROP TABLE IF EXISTS ${Database.restoreCommitsTable}',
      );
    } finally {
      await snapshot.close();
    }
  }

  /// Runs once the database guards accepted a restore, under the mount fence
  /// and before any staged file is published.
  @visibleForTesting
  Future<void> Function()? beforeRestorePublish;

  @visibleForTesting
  Future<void> Function()? promptMitmCaTrust;

  Future<bool> backup(BackupDelivery deliver, {bool includeMitmCa = false}) {
    return _withWorkDir((workDir) async {
      return deliver(
        await _createArchive(workDir, includeMitmCa: includeMitmCa),
      );
    });
  }

  /// False when the user backed out, before anything was written. A
  /// committed restore hands what it did to mounts to [onResult].
  Future<bool> restore(
    RestoreOption option,
    BackupFetch fetch, {
    RestoreMountConfirm? confirm,
    void Function(RestoreMountResult result)? onResult,
  }) {
    return _withWorkDir((workDir) async {
      final archivePath = await fetch(join(workDir, 'download.zip'));
      if (archivePath == null) {
        return false;
      }
      final stagingDirPath = join(workDir, 'staging');
      final MigrationData data;
      try {
        data = await restoreTask((
          archivePath: archivePath,
          stagingDirPath: stagingDirPath,
        ));
      } on BackupException catch (e) {
        throw MessageException(switch (e.failure) {
          BackupFailure.invalid => currentAppLocalizations.invalidBackupFile,
          BackupFailure.newerVersion =>
            currentAppLocalizations.backupFromNewerVersion,
        });
      }
      final result = await applyRestore(
        data,
        option,
        stagingDirPath: stagingDirPath,
        confirm: confirm,
      );
      if (result == null) return false;
      onResult?.call(result);
      return true;
    });
  }

  Future<bool> _withWorkDir(Future<bool> Function(String workDir) run) async {
    final workDir = Directory(join(await appPath.tempPath, 'backup$uniqueId'));
    await workDir.create(recursive: true);
    try {
      return await run(workDir.path);
    } finally {
      await workDir.safeDelete(recursive: true);
      await _discardLegacyStaging();
    }
  }

  /// Earlier versions staged restores in the home directory and never removed
  /// the downloaded archive.
  Future<void> _discardLegacyStaging() async {
    final homeDirPath = await appPath.homeDirPath;
    await File(join(homeDirPath, 'backup.zip')).safeDelete();
    await Directory(join(homeDirPath, 'restore')).safeDelete(recursive: true);
  }

  Future<String> _createArchive(
    String workDir, {
    bool includeMitmCa = false,
  }) async {
    final databaseSnapshotPath = join(workDir, backupDatabaseName);
    await database.customStatement('VACUUM INTO ?', [databaseSnapshotPath]);
    await _dropRestoreCommits(databaseSnapshotPath);
    final entries = await BackupEntries.ofDatabaseSnapshot(
      databaseSnapshotPath,
    );
    final configMap = await backupConfigMap(includeMitmCa: includeMitmCa);
    configMap['version'] = await preferences.getVersion();
    final archivePath = join(workDir, 'backup.zip');
    await backupTask((
      archivePath: archivePath,
      configMap: configMap,
      databaseSnapshotPath: databaseSnapshotPath,
      homeDirPath: await appPath.homeDirPath,
      entries: entries,
    ));
    return archivePath;
  }

  /// A pending or replaced CA never; the one in use only if [includeMitmCa].
  @visibleForTesting
  Future<Map<String, Object?>> backupConfigMap({
    bool includeMitmCa = false,
  }) async {
    final config = ref.read(configProvider);
    final mitm = config.patchClashConfig.mitm;
    final ca = mitm.coreCa;
    final passphrase = includeMitmCa && ca != null
        ? await ref
              .read(mitmPassphraseStoreProvider)
              ?.readPassphrase(ca.fingerprint)
        : null;
    final kept = passphrase != null;
    final configMap =
        json.decode(
              json.encode(
                config.copyWith.patchClashConfig(
                  mitm: mitm.copyWith(
                    caP12: kept ? mitm.caP12 : null,
                    caCertificate: kept ? mitm.caCertificate : null,
                    pendingCaP12: null,
                    pendingCaCertificate: null,
                    retiredCaCertificate: null,
                  ),
                ),
              ),
            )
            as Map<String, Object?>;
    if (passphrase != null) configMap[mitmCaPassphraseKey] = passphrase;
    return configMap;
  }

  /// Keeps this Mac's CA unless the backup carries another, untrusted here.
  (Mitm, _MitmKeychainChange?) _restoredMitm(
    Mitm restored,
    Map<String, Object?> configMap,
  ) {
    final local = ref.read(patchClashConfigProvider).mitm;
    final passphrase = configMap[mitmCaPassphraseKey];
    final carried = restored.coreCa;
    if (carried != null &&
        passphrase is String &&
        passphrase.isNotEmpty &&
        carried.fingerprint != local.coreCa?.fingerprint) {
      final dropped = local.pendingCaCertificate?.fingerprint;
      return (
        restored.copyWith(
          trustedFingerprint: null,
          pendingCaP12: null,
          pendingCaCertificate: null,
          retiredCaCertificate:
              local.coreCa != null &&
                  local.coreCa!.fingerprint != carried.fingerprint
              ? local.coreCa
              : local.retiredCaCertificate,
        ),
        (
          fingerprint: carried.fingerprint,
          passphrase: passphrase,
          forget: dropped == carried.fingerprint ? null : dropped,
        ),
      );
    }
    return (
      restored.copyWith(
        caP12: local.caP12,
        caCertificate: local.caCertificate,
        pendingCaP12: local.pendingCaP12,
        pendingCaCertificate: local.pendingCaCertificate,
        retiredCaCertificate: local.retiredCaCertificate,
        trustedFingerprint: local.trustedFingerprint,
      ),
      null,
    );
  }

  Future<void> _storeRestoredMitm(_MitmKeychainChange change) async {
    final store = ref.read(mitmPassphraseStoreProvider);
    await store?.writePassphrase(change.fingerprint, change.passphrase);
    if (change.forget case final fingerprint?) {
      try {
        await store?.deletePassphrase(fingerprint);
      } catch (error) {
        commonPrint.log(
          'Deleting a MITM CA passphrase failed: ${compactError(error)}',
          logLevel: LogLevel.warning,
        );
      }
    }
  }

  Future<void> _promptMitmCaTrust() async {
    final appLocalizations = currentAppLocalizations;
    final trust = await mitmRestoredCaPort?.call();
    if (trust != true || !ref.mounted) return;
    await globalState.safeRun(
      () => ref.read(mitmTrustStateProvider.notifier).install(),
      title: appLocalizations.mitmInstallAndTrust,
    );
  }

  /// Called at each [RestoreCheckpoint]; a test throws [RestoreCrash] here
  /// to stop the restore as a crash would.
  @visibleForTesting
  Future<void> Function(RestoreCheckpoint point)? onRestoreCheckpoint;

  Future<void> _checkpoint(RestoreCheckpoint point) async {
    await onRestoreCheckpoint?.call(point);
  }

  static String? get _appBuild {
    try {
      final info = globalState.packageInfo;
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }

  /// Null when [confirm] declined the mount plan; nothing was written. A
  /// plan with losses is never written unconfirmed.
  @visibleForTesting
  Future<RestoreMountResult?> applyRestore(
    MigrationData data,
    RestoreOption option, {
    String? stagingDirPath,
    RestoreMountConfirm? confirm,
  }) async {
    final configMap = data.configMap;
    final config = option == RestoreOption.onlyProfiles || configMap == null
        ? null
        : Config.fromJson(configMap);
    final previewOverride =
        ref.read(appSettingProvider).restoreStrategy ==
        RestoreStrategy.override;
    // Read outside the restore lanes: the user may take a while to decide.
    final RestoreMountPlan preview;
    try {
      preview = await database.checkRestore(
        data.profiles,
        data.scripts,
        data.rules,
        data.disabledRules,
        data.proxyGroups,
        clashProviders: data.clashProviders,
        customProxies: data.customProxies,
        proxyDialers: data.proxyDialers,
        mitmModules: data.mitmModules,
        addedRuleSets: data.addedRuleSets,
        isOverride: previewOverride,
        mountsCarried: data.mountsCarried,
        mountTargets: data.mountTargets,
        mountSourceStatuses: data.mountSourceStatuses,
      );
    } on RestoreBlockedError catch (error, stack) {
      Error.throwWithStackTrace(await _restoreBlocked(error), stack);
    }
    // MITM modules are written off until consented to here, which is said
    // before the restore even when no mount changes.
    // Every module in the backup is written, by id, so each is listed once.
    final mitmModules = [
      for (final m in {for (final m in data.mitmModules) m.id: m}.values)
        RestoreMitmModule(m.id, m.name),
    ];
    // An override deletes local items the backup lacks, so it is always
    // confirmed; a compatible restore with nothing listed is not asked.
    if (previewOverride || !preview.isEmpty || mitmModules.isNotEmpty) {
      final accepted = switch (confirm) {
        final confirm? => await confirm(preview, mitmModules: mitmModules),
        null => !preview.hasLosses,
      };
      if (!accepted) return null;
    }
    var plan = preview;
    RestorePartialException? partial;
    StackTrace? partialStack;
    var restoredMitmCa = false;
    var keptMitmCa = false;
    _MitmKeychainChange? mitmKeychain;
    final lanes = ref
        .read(addedRulesActionProvider.notifier)
        .runRestoreInLane(
          () => ref.read(setupActionProvider.notifier).runRestoreBeforeApply(
            () async {
              final isOverride = previewOverride;
              final homeDirPath = await appPath.homeDirPath;
              final restoredSets = await compute(reserveRestoredAddedCaches, (
                homeDirPath,
                data.addedRuleSets,
              ));
              final previous = await database.clashProvidersDao.query().get();
              Config? restoredConfig;
              String? committedFingerprint;
              late final RestoreJournal journal;
              Future<String?> writeRows({required bool checkOnly}) async {
                if (checkOnly) {
                  final current = await database.checkRestore(
                    data.profiles,
                    data.scripts,
                    data.rules,
                    data.disabledRules,
                    data.proxyGroups,
                    clashProviders: data.clashProviders,
                    customProxies: data.customProxies,
                    proxyDialers: data.proxyDialers,
                    mitmModules: data.mitmModules,
                    addedRuleSets: restoredSets,
                    isOverride: isOverride,
                    mountsCarried: data.mountsCarried,
                    mountTargets: data.mountTargets,
                    mountSourceStatuses: data.mountSourceStatuses,
                  );
                  // The list the user confirmed must still be the truth.
                  if (current.digest != preview.digest) {
                    throw RestoreBlockedError(
                      RestoreBlockedReason.mountStateChanged,
                      [for (final target in current.pendingCheck) target.id],
                    );
                  }
                  return null;
                }
                final (fingerprint, written) = await database.restore(
                  data.profiles,
                  data.scripts,
                  data.rules,
                  data.disabledRules,
                  data.proxyGroups,
                  clashProviders: data.clashProviders,
                  customProxies: data.customProxies,
                  proxyDialers: data.proxyDialers,
                  mitmModules: data.mitmModules,
                  addedRuleSets: restoredSets,
                  isOverride: isOverride,
                  mountsCarried: data.mountsCarried,
                  mountTargets: data.mountTargets,
                  mountSourceStatuses: data.mountSourceStatuses,
                  expectedMountDigest: preview.digest,
                  commitId: journal.id,
                );
                plan = written;
                return fingerprint;
              }

              // Staged files replace live ones a mount apply may be reading,
              // so none is published before the guards pass, and no mount
              // operation starts between that check and the commit.
              try {
                await ref.read(mountActionProvider.notifier).runExclusive(
                  () async {
                    await writeRows(checkOnly: true);
                    _supersedeRestored(data, preview);
                    await beforeRestorePublish?.call();
                    if (config != null) {
                      final accessControlProps =
                          config.vpnProps.accessControlProps.hasPackages
                          ? config.vpnProps.accessControlProps
                          : ref.read(vpnSettingProvider).accessControlProps;
                      final (mitm, change) = _restoredMitm(
                        config.patchClashConfig.mitm,
                        configMap!,
                      );
                      mitmKeychain = change;
                      restoredMitmCa = change != null;
                      keptMitmCa =
                          change == null &&
                          mitm.coreCa != null &&
                          config.patchClashConfig.mitm.coreCa == null;
                      restoredConfig = config.copyWith(
                        davProps:
                            config.davProps ?? ref.read(davSettingProvider),
                        vpnProps: config.vpnProps.copyWith(
                          accessControlProps: accessControlProps,
                        ),
                        patchClashConfig: config.patchClashConfig.copyWith(
                          mitm: mitm,
                        ),
                      );
                    }
                    journal = await RestoreJournal.create(
                      homeDirPath: homeDirPath,
                      id: snowflake.id,
                      config: switch (restoredConfig) {
                        final value? =>
                          json.decode(json.encode(value))
                              as Map<String, Object?>,
                        null => null,
                      },
                      previousProviderFiles: [
                        for (final provider in previous) provider.fileName,
                      ],
                      restoredLocalProviderFiles: [
                        for (final provider in data.clashProviders)
                          if (!provider.isRemote) provider.fileName,
                      ],
                      mountTargets: [
                        for (final write in preview.writes) write.targetId,
                      ],
                      mitmModules: [
                        for (final module in data.mitmModules) module.id,
                      ],
                      appBuild: _appBuild,
                    );
                    // Before the commit: the restored consent is another
                    // device's until it is rechecked here.
                    restoreRecovery.holdMitm(journal.id, journal.mitmModules);
                    try {
                      await _checkpoint(RestoreCheckpoint.prepared);
                      if (stagingDirPath != null) {
                        await _publishStagedFiles(
                          journal,
                          data,
                          stagingDirPath,
                        );
                      }
                      await journal.advance(
                        RestorePhase.published,
                        prefsBefore: await storedConfigHash(preferences),
                      );
                      await _checkpoint(RestoreCheckpoint.published);
                      committedFingerprint = await writeRows(checkOnly: false);
                    } on RestoreCrash {
                      rethrow;
                    } catch (_) {
                      // Nothing committed: the rows rolled back, so the
                      // files go back too. If that fails, the journal stays
                      // for the next launch.
                      try {
                        final kept = await journal.rollBack();
                        restoreRecovery.releaseMitm(journal.id);
                        if (kept.isNotEmpty) {
                          commonPrint.log(
                            'restore rollback left changed files: $kept',
                            logLevel: LogLevel.warning,
                          );
                        }
                      } catch (error) {
                        commonPrint.log(
                          'restore rollback failed: $error',
                          logLevel: LogLevel.error,
                        );
                      }
                      rethrow;
                    }
                  },
                );
              } on RestoreBlockedError catch (error, stack) {
                // Thrown before any row, file or setting is written.
                Error.throwWithStackTrace(await _restoreBlocked(error), stack);
              }
              // Keep both restore lanes until all dependent publication and
              // cleanup completes; a later restore must not overtake these.
              // A failure leaves the journal for the next launch to finish.
              try {
                await journal.advance(
                  RestorePhase.committed,
                  dbFingerprint: committedFingerprint,
                );
                await _checkpoint(RestoreCheckpoint.committed);
                await afterRestoreCommit?.call();
                if (mitmKeychain case final change?) {
                  await _storeRestoredMitm(change);
                }
                await _afterCommit(
                  journal,
                  restoredConfig: restoredConfig,
                  mixedPort: config == null
                      ? null
                      : (configMap?['patchClashConfig'], config),
                );
              } on RestoreCrash {
                rethrow;
              } catch (error, stack) {
                commonPrint.log(
                  'restore step after commit failed: $error',
                  logLevel: LogLevel.error,
                );
                Error.throwWithStackTrace(
                  RestorePartialException(
                    _partialMessage(journal.remainingSteps()),
                    steps: journal.remainingSteps(),
                  ),
                  stack,
                );
              }
            },
          ),
        );
    try {
      await lanes;
    } on RestorePartialException catch (error, stack) {
      partial = error;
      partialStack = stack;
    }
    if (restoredMitmCa) {
      unawaited((promptMitmCaTrust ?? _promptMitmCaTrust)());
    } else if (keptMitmCa) {
      dialogs.showBanner(currentAppLocalizations.mitmRestoreKeptCa);
    }
    // Outside both lanes: settling takes the mount scheduler only.
    List<RestoreMountProfile>? pending;
    try {
      final still = await ref.read(mountActionProvider.notifier).settleRestored(
        [for (final write in plan.writes) write.targetId],
      );
      pending = [
        for (final target in plan.pendingCheck)
          if (still.contains(target.id)) target,
      ];
    } catch (error) {
      // Unknown, never empty: a partial result then says it can't tell.
      if (partial == null) rethrow;
      commonPrint.log(
        'restored mounts unreadable: $error',
        logLevel: LogLevel.warning,
      );
    }
    if (partial != null) {
      Error.throwWithStackTrace(
        partial.withPendingChecks(pending),
        partialStack!,
      );
    }
    return RestoreMountResult(plan, pending!);
  }

  /// The restored targets among [targetIds] still pending once settled;
  /// null when that can't be read.
  Future<List<RestoreMountProfile>?> _stillPending(Set<int> targetIds) async {
    if (targetIds.isEmpty) return const [];
    try {
      final still = await ref
          .read(mountActionProvider.notifier)
          .settleRestored(targetIds);
      return await pendingMountProfiles(database, still);
    } catch (error) {
      commonPrint.log(
        'restored mounts unreadable: $error',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  /// Downloads and mount operations already under way for anything the
  /// restore writes lose ownership, so none lands over the restored rows or
  /// files afterwards.
  void _supersedeRestored(MigrationData data, RestoreMountPlan plan) {
    final profiles = ref.read(profilesActionProvider.notifier);
    final ids = {
      for (final profile in data.profiles) profile.id,
      for (final write in plan.writes) ...[write.targetId, ...write.sourceIds],
      for (final removal in plan.removals) ...[
        removal.relation.target.id,
        removal.relation.source.id,
      ],
    };
    for (final id in ids) {
      profiles.cancelSourceUpdate(id);
    }
    ref.read(mountActionProvider.notifier).supersedeTargets(ids);
  }

  static String _partialMessage(List<RestoreStep> steps) =>
      restoreRecoveryMessage(
        RestoreRecoveryReport(
          RestoreRecoveryOutcome.pending,
          skippedSteps: steps,
          followUp: RestoreFollowUp.retryNow,
        ),
        currentAppLocalizations,
      );

  /// Every step after the commit skips what the journal records as done,
  /// so [resumeRestore] can run it again.
  Future<void> _afterCommit(
    RestoreJournal journal, {
    required Config? restoredConfig,
    (Object?, Config)? mixedPort,
  }) async {
    if (journal.phase.index < RestorePhase.cachesCleared.index) {
      await journal.clearCaches(database);
      await journal.advance(RestorePhase.cachesCleared);
      await _checkpoint(RestoreCheckpoint.cachesCleared);
    }
    if (journal.phase.index < RestorePhase.configSaved.index) {
      if (restoredConfig case final value?) {
        writeConfig(ref, value);
        // Saved now rather than debounced: until this lands, a crash would
        // leave the committed rows with old settings.
        debouncer.cancel(FunctionTag.savePreferences);
        await _checkpoint(RestoreCheckpoint.configWritten);
        final saving = ref.read(configProvider);
        await journal.advance(journal.phase, prefsTarget: configHash(saving));
        if (!await preferences.saveConfig(saving)) {
          throw StateError('saving the restored settings failed');
        }
        await _checkpoint(RestoreCheckpoint.configStored);
      }
      await journal.advance(
        RestorePhase.configSaved,
        dbFingerprint: await database.restoreFingerprint(),
      );
      await _checkpoint(RestoreCheckpoint.configSaved);
    }
    if (mixedPort case (final patch, final config)) {
      if (unusableMixedPort(patch) case final value?) {
        dialogs.showMixedPortReset(value, config.patchClashConfig.mixedPort);
      }
    }
    final mitm = ref.read(mitmModulesActionProvider.notifier);
    if (journal.phase.index < RestorePhase.mitmDone.index) {
      await mitm.recheckRestored();
      await journal.advance(
        RestorePhase.mitmDone,
        dbFingerprint: await database.restoreFingerprint(),
      );
      await _checkpoint(RestoreCheckpoint.mitmDone);
    }
    restoreRecovery.releaseMitm(journal.id);
    await journal.finish(database);
    if (ref.mounted) {
      unawaited(mitm.autoUpdate());
    }
  }

  /// Runs what a restore committed in this session still owes, after a
  /// step failed. Journals without a commit marker are left to the launch.
  /// Returns the restored targets still to check; null when unknown.
  Future<List<RestoreMountProfile>?> resumeRestore() async {
    final targets = <int>{};
    RestorePartialException? partial;
    StackTrace? partialStack;
    final lanes = ref
        .read(addedRulesActionProvider.notifier)
        .runRestoreInLane(
          () => ref.read(setupActionProvider.notifier).runRestoreBeforeApply(
            () async {
              final home = await appPath.homeDirPath;
              for (final (id, journal) in await RestoreJournal.pending(home)) {
                if (journal == null) continue;
                if (await database.restoreCommit(id) == null) continue;
                targets.addAll(journal.mountTargets);
                try {
                  await _afterCommit(
                    journal,
                    restoredConfig: switch (journal.config) {
                      final map? => Config.fromJson(map),
                      null => null,
                    },
                  );
                } catch (error, stack) {
                  Error.throwWithStackTrace(
                    RestorePartialException(
                      _partialMessage(journal.remainingSteps()),
                      steps: journal.remainingSteps(),
                    ),
                    stack,
                  );
                }
              }
            },
          ),
        );
    try {
      await lanes;
    } on RestorePartialException catch (error, stack) {
      partial = error;
      partialStack = stack;
    }
    final pending = await _stillPending(targets);
    if (partial != null) {
      Error.throwWithStackTrace(
        partial.withPendingChecks(pending),
        partialStack!,
      );
    }
    return pending;
  }

  /// An id without a local profile row is left out rather than guessed.
  Future<RestoreBlockedException> _restoreBlocked(
    RestoreBlockedError error,
  ) async {
    final l10n = currentAppLocalizations;
    final local = [
      for (final profile in await database.profilesDao.query().get())
        if (error.profileIds.contains(profile.id)) profile,
    ];
    final names = local
        .map((profile) => profile.realLabel)
        .join(l10n.mountNameSeparator);
    return RestoreBlockedException(
      switch (error.reason) {
        RestoreBlockedReason.mountPending when local.isEmpty =>
          l10n.restoreBlockedMountPending,
        RestoreBlockedReason.mountPending =>
          l10n.restoreBlockedMountPendingNamed(names),
        RestoreBlockedReason.mountStateChanged =>
          l10n.restoreBlockedMountStateChanged,
      },
      reason: error.reason,
      profileIds: [for (final profile in local) profile.id],
      profileNames: [for (final profile in local) profile.realLabel],
    );
  }

  /// Each file is journaled before it is overwritten, so a crash at any
  /// point can put it back.
  Future<void> _publishStagedFiles(
    RestoreJournal journal,
    MigrationData data,
    String stagingDirPath,
  ) async {
    for (final entry in BackupEntries.ofData(data).toSet()) {
      final staged = File(BackupEntries.resolve(stagingDirPath, entry));
      if (!await staged.exists()) {
        continue;
      }
      await journal.publish(entry, staged);
      await _checkpoint(RestoreCheckpoint.filePublished);
    }
  }
}

typedef _MitmKeychainChange = ({
  String fingerprint,
  String passphrase,
  String? forget,
});
