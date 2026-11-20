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
              final restoredSets = await compute(reserveRestoredAddedCaches, (
                await appPath.homeDirPath,
                data.addedRuleSets,
              ));
              final previous = await database.clashProvidersDao.query().get();
              Future<void> writeRows({required bool checkOnly}) =>
                  (checkOnly ? database.checkRestore : database.restore)(
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
              // Staged files replace live ones a mount apply may be reading,
              // so none is published before the guards pass, and no mount
              // operation starts between that check and the commit.
              try {
                await ref.read(mountActionProvider.notifier).runExclusive(
                  () async {
                    await writeRows(checkOnly: true);
                    await beforeRestorePublish?.call();
                    final putBack = stagingDirPath == null
                        ? null
                        : await _copyStagedFiles(data, stagingDirPath);
                    try {
                      await writeRows(checkOnly: false);
                    } catch (_) {
                      await putBack?.call();
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
              try {
                await afterRestoreCommit?.call();
                await _clearReplacedProviderCaches(previous);
                await _clearOutdatedCompiledRuleSets(data.clashProviders);
                if (config != null) {
                  final accessControlProps =
                      config.vpnProps.accessControlProps.hasPackages
                      ? config.vpnProps.accessControlProps
                      : ref.read(vpnSettingProvider).accessControlProps;
                  writeConfig(
                    ref,
                    config.copyWith(
                      davProps: config.davProps ?? ref.read(davSettingProvider),
                      vpnProps: config.vpnProps.copyWith(
                        accessControlProps: accessControlProps,
                      ),
                    ),
                  );
                }
                if (config != null) {
                  if (unusableMixedPort(configMap?['patchClashConfig'])
                      case final value?) {
                    dialogs.showMixedPortReset(
                      value,
                      config.patchClashConfig.mixedPort,
                    );
                  }
                }
                await _restoreMitmModules();
              } catch (error, stack) {
                Error.throwWithStackTrace(
                  MessageException(
                    'Restore partially completed: database changes were committed, '
                    'but a later step failed. $error',
                  ),
                  stack,
                );
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

  Future<void> _restoreMitmModules() async {
    final action = ref.read(mitmModulesActionProvider.notifier);
    await action.recheckConsent();
    await action.clean();
    if (ref.mounted) {
      unawaited(action.autoUpdate());
    }
  }

  /// The files go in before the rows that name them, so the returned callback
  /// is how a restore whose rows fail takes them back out.
  Future<Future<void> Function()> _copyStagedFiles(
    MigrationData data,
    String stagingDirPath,
  ) async {
    final homeDirPath = await appPath.homeDirPath;
    final replacedDirPath = join(stagingDirPath, 'replaced');
    final copied = <String, bool>{};
    Future<void> putBack() async {
      for (final MapEntry(key: entry, value: replaced) in copied.entries) {
        final target = BackupEntries.resolve(homeDirPath, entry);
        if (replaced) {
          await File(
            BackupEntries.resolve(replacedDirPath, entry),
          ).safeCopy(target);
        } else {
          await File(target).safeDelete();
        }
      }
    }

    try {
      for (final entry in BackupEntries.ofData(data).toSet()) {
        final staged = File(BackupEntries.resolve(stagingDirPath, entry));
        if (!await staged.exists()) {
          continue;
        }
        final target = File(BackupEntries.resolve(homeDirPath, entry));
        final replaced = await target.exists();
        if (replaced) {
          await target.safeCopy(BackupEntries.resolve(replacedDirPath, entry));
        }
        copied[entry] = replaced;
        await staged.safeCopy(target.path);
      }
    } catch (_) {
      await putBack();
      rethrow;
    }
    return putBack;
  }

  Future<void> _clearReplacedProviderCaches(
    List<ClashProvider> previousProviders,
  ) async {
    final kept = (await database.clashProvidersDao.fileNames().get()).toSet();
    for (final provider in previousProviders) {
      if (kept.contains(provider.fileName)) {
        continue;
      }
      await File(await provider.path).safeDelete();
      await File(await provider.compiledPath).safeDelete();
    }
  }

  /// A restored source outdates the mrs compiled from the one it replaced.
  Future<void> _clearOutdatedCompiledRuleSets(
    List<ClashProvider> restored,
  ) async {
    for (final provider in restored) {
      if (!provider.isRemote) {
        await File(await provider.compiledPath).safeDelete();
      }
    }
  }
}
