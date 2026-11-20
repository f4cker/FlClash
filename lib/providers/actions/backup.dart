part of '../action.dart';

typedef BackupDelivery = Future<bool> Function(String archivePath);

/// Returns the archive to restore, or null when the user backed out. A source
/// that downloads writes to [downloadPath], which is removed afterwards.
typedef BackupFetch = Future<String?> Function(String downloadPath);

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

  Future<bool> backup(BackupDelivery deliver) {
    return _withWorkDir((workDir) async {
      return deliver(await _createArchive(workDir));
    });
  }

  Future<bool> restore(RestoreOption option, BackupFetch fetch) {
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
      await applyRestore(data, option, stagingDirPath: stagingDirPath);
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

  Future<String> _createArchive(String workDir) async {
    final databaseSnapshotPath = join(workDir, backupDatabaseName);
    await database.customStatement('VACUUM INTO ?', [databaseSnapshotPath]);
    await _dropRestoreCommits(databaseSnapshotPath);
    final entries = await BackupEntries.ofDatabaseSnapshot(
      databaseSnapshotPath,
    );
    final configMap = ref.read(configProvider).toJson();
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

  @visibleForTesting
  Future<void> applyRestore(
    MigrationData data,
    RestoreOption option, {
    String? stagingDirPath,
  }) async {
    final configMap = data.configMap;
    final config = option == RestoreOption.onlyProfiles || configMap == null
        ? null
        : Config.fromJson(configMap);
    await ref
        .read(addedRulesActionProvider.notifier)
        .runRestoreInLane(
          () => ref.read(setupActionProvider.notifier).runRestoreBeforeApply(
            () async {
              final isOverride =
                  ref.read(appSettingProvider).restoreStrategy ==
                  RestoreStrategy.override;
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
                  await database.checkRestore(
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
                  );
                  return null;
                }
                return database.restore(
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
                  commitId: journal.id,
                );
              }

              // Staged files replace live ones a mount apply may be reading,
              // so none is published before the guards pass, and no mount
              // operation starts between that check and the commit.
              try {
                await ref.read(mountActionProvider.notifier).runExclusive(
                  () async {
                    await writeRows(checkOnly: true);
                    await beforeRestorePublish?.call();
                    if (config != null) {
                      final accessControlProps =
                          config.vpnProps.accessControlProps.hasPackages
                          ? config.vpnProps.accessControlProps
                          : ref.read(vpnSettingProvider).accessControlProps;
                      restoredConfig = config.copyWith(
                        davProps:
                            config.davProps ?? ref.read(davSettingProvider),
                        vpnProps: config.vpnProps.copyWith(
                          accessControlProps: accessControlProps,
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
                      appBuild: _appBuild,
                    );
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
      await mitm.recheckConsent();
      await mitm.clean();
      await journal.advance(
        RestorePhase.mitmDone,
        dbFingerprint: await database.restoreFingerprint(),
      );
      await _checkpoint(RestoreCheckpoint.mitmDone);
    }
    await journal.finish(database);
    if (ref.mounted) {
      unawaited(mitm.autoUpdate());
    }
  }

  /// Runs what a restore committed in this session still owes, after a
  /// step failed. Journals without a commit marker are left to the launch.
  Future<void> resumeRestore() {
    return ref
        .read(addedRulesActionProvider.notifier)
        .runRestoreInLane(
          () => ref.read(setupActionProvider.notifier).runRestoreBeforeApply(
            () async {
              final home = await appPath.homeDirPath;
              for (final (id, journal) in await RestoreJournal.pending(home)) {
                if (journal == null) continue;
                if (await database.restoreCommit(id) == null) continue;
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
        RestoreBlockedReason.mountPending => l10n.restoreBlockedMountPending,
        RestoreBlockedReason.overrideWithMountGuards =>
          l10n.restoreBlockedOverrideMounts,
        RestoreBlockedReason.mergeWithMountGuards ||
        RestoreBlockedReason.mergeWithMountLinks when local.isEmpty =>
          l10n.restoreBlockedMergeMountsUnnamed,
        RestoreBlockedReason.mergeWithMountGuards ||
        RestoreBlockedReason.mergeWithMountLinks =>
          l10n.restoreBlockedMergeMounts(names),
      },
      reason: error.reason,
      profileIds: [for (final profile in local) profile.id],
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
