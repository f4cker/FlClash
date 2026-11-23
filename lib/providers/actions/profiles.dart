part of '../action.dart';

class _SourceUpdateBatch {
  _SourceUpdateBatch(this.targetId, this.priorRevision, this.labels);

  final Map<int, String> labels;
  final int? targetId;
  final Future<String?> priorRevision;
  var targetCurrent = true;
  ProviderSubscription<int?>? selection;
  var pending = 0;
  final updated = <int, Profile>{};
  final done = Completer<Map<int, MountSourceRefresh>>();
}

@Riverpod(keepAlive: true)
class ProfilesAction extends _$ProfilesAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  final _sourceUpdates = <int, Object>{};
  final _sourceResults = Expando<Object>();
  final _sourceInspections = Expando<MountSourceInspection>();
  _SourceUpdateBatch? _updateBatch;

  _SourceUpdateBatch _newUpdateBatch() {
    final targetId = ref.read(currentProfileIdProvider);
    final before = [...ref.read(profilesProvider)];
    final batch = _SourceUpdateBatch(targetId, () async {
      try {
        final target = targetId == null
            ? null
            : await database.mountsDao.target(targetId);
        if (target == null) return null;
        return mountSetupOf(
          target,
          before,
          await appPath.profilesPath,
        ).revision;
      } catch (_) {
        return null;
      }
    }(), {for (final profile in before) profile.id: profile.realLabel});
    batch.selection = ref.listen(currentProfileIdProvider, (_, next) {
      if (next != targetId) batch.targetCurrent = false;
    });
    return batch;
  }

  bool isSourceUpdateCurrent(Profile profile) {
    final token = _sourceResults[profile];
    final latest = ref.read(profilesProvider).getProfile(profile.id);
    return token != null &&
        identical(_sourceUpdates[profile.id], token) &&
        latest != null &&
        latest.url == profile.url &&
        latest.type == profile.type &&
        latest.ageSecretKey == profile.ageSecretKey &&
        latest.realLabel == profile.realLabel &&
        latest.lastUpdateDate == profile.lastUpdateDate;
  }

  MountSourceItem sourceUpdateItem(
    Profile profile, {
    MountSourceReport? report,
  }) {
    final inspection = report == null
        ? _sourceInspections[profile]
        : MountSourceInspection(
            status: report.status,
            count: report.nodes.length,
            tailscaleExcluded: report.tailscaleExcluded,
            relayExcluded: report.relayExcluded,
            unsupportedExcluded: report.unsupportedExcluded,
          );
    return mountSourceItem(profile, inspection, mounted: true);
  }

  void _releaseUpdateBatch(_SourceUpdateBatch batch) {
    if (--batch.pending != 0) return;
    if (identical(_updateBatch, batch)) _updateBatch = null;
    unawaited(() async {
      try {
        final results = await ref
            .read(mountActionProvider.notifier)
            .completeSourceUpdates(
              batch.updated.values.toList(),
              targetId: batch.targetId,
              previousRevision: await batch.priorRevision,
              targetCurrent: batch.targetCurrent,
              previousLabels: batch.labels,
            );
        batch.done.complete(results);
      } catch (error) {
        batch.done.complete({
          for (final profile in batch.updated.values)
            profile.id: MountSourceRefresh(
              updated: true,
              application: MountSaveOutcome.unknown,
              message: compactError(error),
            ),
        });
      } finally {
        batch.selection?.close();
      }
    }());
  }

  Future<void> _updateMany(List<int> ids, {bool automatic = false}) async {
    final batch = _updateBatch ??= _newUpdateBatch();
    batch.pending++;
    try {
      for (final id in ids) {
        final profile = ref.read(profilesProvider).getProfile(id);
        if (profile == null || profile.type != ProfileType.url) continue;
        if (automatic &&
            (!profile.autoUpdate ||
                profile.lastUpdateDate
                        ?.add(profile.autoUpdateDuration)
                        .isBeforeNow ==
                    false)) {
          continue;
        }
        try {
          await refreshProfile(
            profile,
            showLoading: !automatic,
            waitForApplication: false,
          );
        } catch (error) {
          if (!automatic) rethrow;
          logUpdateFailure(profile.realLabel, error);
        }
      }
    } finally {
      _releaseUpdateBatch(batch);
    }
    await batch.done.future;
  }

  void cancelSourceUpdate(int sourceId) {
    _sourceUpdates.remove(sourceId);
  }

  @override
  void build() {}

  void updateCurrentSelectedMap(String groupName, String proxyName) =>
      updateCurrentSelections({groupName: proxyName});

  /// One write for all of [choices], so none is read back stale.
  void updateCurrentSelections(Map<String, String> choices) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile != null &&
        choices.entries.any(
          (choice) => currentProfile.selectedMap[choice.key] != choice.value,
        )) {
      final selectedMap = {...currentProfile.selectedMap, ...choices};
      ref
          .read(profilesProvider.notifier)
          .put(currentProfile.copyWith(selectedMap: selectedMap));
    }
  }

  /// An empty [proxyName] forgets the group's pick.
  void setSelection(int profileId, String groupName, String proxyName) {
    final profile = ref.read(profilesProvider).getProfile(profileId);
    if (profile == null ||
        (profile.selectedMap[groupName] ?? '') == proxyName) {
      return;
    }
    final selectedMap = Map<String, String>.from(profile.selectedMap);
    if (proxyName.isEmpty) {
      selectedMap.remove(groupName);
    } else {
      selectedMap[groupName] = proxyName;
    }
    ref
        .read(profilesProvider.notifier)
        .put(profile.copyWith(selectedMap: selectedMap));
  }

  /// Leaves the profile in place when its Tailscale accounts cannot be
  /// unbound. Throws [MountSourceInUse] for a source still mounted, which
  /// [MountAction.deleteSource] unmounts first.
  Future<TailscaleUnlinkOutcome> deleteProfile(int id) async {
    cancelSourceUpdate(id);
    if (await database.mountsDao.isMounted(id)) {
      throw const MountSourceInUse();
    }
    final outcome = await ref
        .read(tailscaleActionProvider.notifier)
        .unlinkProfile(id, () => ref.read(profilesProvider.notifier).del(id));
    if (outcome != TailscaleUnlinkOutcome.done) {
      return outcome;
    }
    await clearEffect(id);
    final currentProfileId = ref.read(currentProfileIdProvider);
    if (currentProfileId == id) {
      final profiles = ref.read(profilesProvider);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        ref.read(currentProfileIdProvider.notifier).value = updateId;
      } else {
        ref.read(currentProfileIdProvider.notifier).value = null;
        unawaited(ref.read(setupActionProvider.notifier).setRunning(false));
      }
    }
    return outcome;
  }

  Future<String?> validateConfigWithData(List<int> data) async {
    return _core.validateConfigWithData(data);
  }

  Future<void> autoUpdateProfiles() => _updateMany([
    for (final profile in ref.read(profilesProvider)) profile.id,
  ], automatic: true);

  void putProfile(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (ref.read(currentProfileIdProvider) != null) return;
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }

  Future<List<Profile>> providerUsers(Profile profile) async {
    if (profile.type == ProfileType.custom) {
      return const [];
    }
    final users = await ref
        .read(clashProvidersActionProvider.notifier)
        .profilesReferencing(ProviderKind.proxy, profile.realLabel);
    return [
      for (final user in users)
        if (user.id != profile.id) user,
    ];
  }

  /// Where a profile's own group takes a name, the name stands for that group.
  Future<List<Profile>> proxyUsers(Set<String> names) async {
    final (ruleTargets, dialerTargets) = await (
      database.rulesDao.targetsNaming(names),
      database.proxyDialersDao.targetsNaming(names),
    ).wait;
    final users = <Profile>[];
    for (final profile in ref.read(profilesProvider)) {
      if (profile.type != ProfileType.custom) {
        continue;
      }
      final groups = await database.proxyGroupsDao.query(profile.id).get();
      final inUse = proxyNamesInUse(
        names.difference({for (final group in groups) group.name}),
        groups: groups,
        ruleTargets: ruleTargets[profile.id] ?? const {},
        dialerTargets: dialerTargets[profile.id] ?? const {},
        overrides: profile.overrides,
      );
      if (inUse.isNotEmpty) {
        users.add(profile);
      }
    }
    return users;
  }

  Future<Set<String>> groupsInUse(int profileId, Set<int> groupIds) async {
    final groups = await database.proxyGroupsDao.query(profileId).get();
    final names = {
      for (final group in groups)
        if (groupIds.contains(group.id)) group.name,
    };
    final (ruleTargets, dialerTargets) = await (
      database.rulesDao.targetsNaming(names),
      database.proxyDialersDao.targetsNaming(names),
    ).wait;
    return proxyNamesInUse(
      names,
      groups: groups.where((group) => !groupIds.contains(group.id)),
      ruleTargets: ruleTargets[profileId] ?? const {},
      dialerTargets: dialerTargets[profileId] ?? const {},
      overrides:
          ref.read(profilesProvider).getProfile(profileId)?.overrides ??
          const ProfileOverrides(),
    );
  }

  Future<void> updateProfiles() => _updateMany([
    for (final profile in ref.read(profilesProvider)) profile.id,
  ]);

  Future<void> updateProfile(
    Profile profile, {
    bool showLoading = false,
  }) async {
    await refreshProfile(profile, showLoading: showLoading);
  }

  /// Every caller joins the in-flight download batch. Only the final download
  /// schedules runtime work; explicit update-all also holds the batch open.
  Future<MountSourceRefresh> refreshProfile(
    Profile profile, {
    bool showLoading = false,
    bool waitForApplication = true,
  }) async {
    final current = ref.read(profilesProvider).getProfile(profile.id);
    if (current == null || current.type != ProfileType.url) {
      return const MountSourceRefresh(updated: false);
    }
    profile = current;
    final batch = _updateBatch ??= _newUpdateBatch();
    batch.pending++;
    final operation = showLoading
        ? ref.read(updatingKeysProvider.notifier).start(profile.updatingKey)
        : null;
    Profile? committed;
    try {
      final downloaded = await fetchSource(
        profile.id,
        (validate, publish, install) => profile.update(
          validate: validate,
          publish: publish,
          install: install,
        ),
      );
      if (downloaded != null) committed = commitSourceUpdate(downloaded);
      if (committed != null) batch.updated[profile.id] = committed;
    } finally {
      _releaseUpdateBatch(batch);
      if (operation != null) {
        ref
            .read(updatingKeysProvider.notifier)
            .stop(profile.updatingKey, operation);
      }
    }
    if (committed == null) return const MountSourceRefresh(updated: false);
    if (!waitForApplication) {
      return MountSourceRefresh(
        updated: true,
        item: sourceUpdateItem(committed),
      );
    }
    final results = await batch.done.future;
    if (!isSourceUpdateCurrent(committed)) {
      return const MountSourceRefresh(updated: false);
    }
    return results[profile.id] ?? const MountSourceRefresh(updated: false);
  }

  Profile? commitSourceUpdate(Profile updated) {
    final token = _sourceResults[updated];
    final latest = ref.read(profilesProvider).getProfile(updated.id);
    if (token == null ||
        !identical(_sourceUpdates[updated.id], token) ||
        latest == null ||
        latest.url != updated.url ||
        latest.ageSecretKey != updated.ageSecretKey ||
        latest.type != updated.type) {
      return null;
    }
    final merged = latest.copyWith(
      label: latest.label.takeFirstValid([updated.label]),
      subscriptionInfo: updated.subscriptionInfo,
      lastUpdateDate: updated.lastUpdateDate,
    );
    ref.read(profilesProvider.notifier).put(merged);
    _sourceResults[merged] = token;
    _sourceInspections[merged] = _sourceInspections[updated];
    return merged;
  }

  Future<Profile?> ensureSource(Profile profile) async {
    if (profile.type != ProfileType.url) return null;
    final path = await appPath.getProfilePath(profile.id.toString());
    if (await File(path).exists()) return null;
    final latest = ref.read(profilesProvider).getProfile(profile.id);
    if (latest == null ||
        latest.type != profile.type ||
        latest.url != profile.url ||
        latest.ageSecretKey != profile.ageSecretKey) {
      return null;
    }
    return fetchSource(
      profile.id,
      (validate, publish, install) =>
          latest.update(validate: validate, publish: publish, install: install),
    );
  }

  /// Runs a download of [sourceId]. A mounted source must still hold a node
  /// list, or its cache stays as it was; its outcome is recorded either way.
  /// A null result is a download that did not run.
  Future<Profile?> fetchSource(
    int sourceId,
    Future<Profile?> Function(
      ValidateConfig validate,
      PublishProfile publish,
      InstallProfile install,
    )
    fetch,
  ) async {
    final original = ref.read(profilesProvider).getProfile(sourceId);
    if (original == null) return null;
    final token = Object();
    _sourceUpdates[sourceId] = token;
    final priorRevision = _updateBatch?.priorRevision;
    var unchanged = true;
    final subscription = ref.listen(profilesProvider, (_, next) {
      final latest = next.getProfile(sourceId);
      if (latest?.url != original.url ||
          latest?.ageSecretKey != original.ageSecretKey ||
          latest?.type != original.type) {
        unchanged = false;
      }
    });
    bool isCurrent() =>
        ref.mounted && unchanged && identical(_sourceUpdates[sourceId], token);
    bool? mounted;
    var mountLookupFailed = false;
    var fullValidated = false;
    Future<bool> isMounted() async {
      try {
        return mounted ??= await database.mountsDao.isMounted(sourceId);
      } catch (_) {
        mountLookupFailed = true;
        return mounted = true;
      }
    }

    var unsupported = false;
    MountSourceInspection? inspected;
    Future<String?> validate(String path, String key) async {
      final mounted = await isMounted();
      if (!mounted ||
          mountLookupFailed ||
          ref.read(currentProfileIdProvider) == sourceId) {
        final issue = await _core.validateProfile(path, key);
        if (issue != null) {
          unsupported = mounted;
          return issue;
        }
        fullValidated = true;
      }
      if (!mounted) return null;
      final inspection = await ref
          .read(mountActionProvider.notifier)
          .inspectDownloadedSource(path, key);
      inspected = inspection;
      switch (inspection.status) {
        case MountSourceStatus.nodes:
          return null;
        case MountSourceStatus.unsupported || MountSourceStatus.invalid:
          unsupported = true;
          return currentAppLocalizations.mountSourceNoNodeList;
        case MountSourceStatus.missing || MountSourceStatus.readError:
          throw const FileSystemException('downloaded file unreadable');
      }
    }

    var updated = false;
    try {
      // Capture the old mount revision before any candidate can replace bytes.
      // Ownership was acquired above, so this wait cannot revive an older intent.
      await priorRevision;
      if (!isCurrent()) return null;
      final fetched = await fetch(
        validate,
        () =>
            isCurrent() &&
            (fullValidated || ref.read(currentProfileIdProvider) != sourceId),
        (install) => ref
            .read(mountActionProvider.notifier)
            .installSource(sourceId, install),
      );
      if (!isCurrent()) return null;
      if (fetched != null && await isMounted() && isCurrent()) {
        await _recordSource(sourceId, null, isCurrent);
      }
      if (!isCurrent()) return null;
      updated = fetched?.type == ProfileType.url;
      if (fetched != null) {
        _sourceResults[fetched] = token;
        _sourceInspections[fetched] = inspected;
      }
      return fetched;
    } on ProfileUpdateSuperseded {
      return null;
    } catch (_) {
      if (!isCurrent()) return null;
      if (await isMounted() && isCurrent()) {
        await _recordSource(
          sourceId,
          unsupported
              ? MountSourceFailure.unsupported
              : MountSourceFailure.fetch,
          isCurrent,
        );
      }
      rethrow;
    } finally {
      subscription.close();
      if (!updated && identical(_sourceUpdates[sourceId], token)) {
        _sourceUpdates.remove(sourceId);
      }
    }
  }

  /// On the mount scheduler, which a restore holds from superseding this
  /// update to its commit: the status lands before the restore's rows, or
  /// not at all.
  Future<void> _recordSource(
    int sourceId,
    MountSourceFailure? failure,
    bool Function() isCurrent,
  ) => ref.read(mountActionProvider.notifier).runExclusive(() async {
    if (!isCurrent()) return;
    try {
      await database.mountsDao.recordSourceResult(
        sourceId,
        failure: failure,
        at: DateTime.now(),
      );
    } catch (error) {
      commonPrint.log(
        'mount source status not saved: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
  });

  Future<void> addProfileFormFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile == null) return;
    final bytes = await platformFile.readBytes();
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    ref.read(currentPageLabelProvider.notifier).toProfiles();
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () => _withAgeSecretKey(
        Profile.normal(label: platformFile.name),
        (profile) => profile.saveFile(
          bytes,
          validate: (path, key) => _core.validateProfile(path, key),
        ),
      ),
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  int addCustomProfile(String label) {
    final profile = Profile.custom(label: label);
    putProfile(profile);
    return profile.id;
  }

  void touchProfile(int id) {
    final profile = ref.read(profilesProvider).getProfile(id);
    if (profile == null) return;
    ref
        .read(profilesProvider.notifier)
        .put(profile.copyWith(lastUpdateDate: DateTime.now()));
  }

  Future<CustomProfileImport> readCustomImport(
    int profileId,
    Uint8List bytes,
  ) async {
    final profiles = ref.read(profilesProvider);
    final (ruleProviders, proxies, groupNames) = await (
      database.clashProvidersDao.query().get(),
      database.customProxiesDao.query().get(),
      database.proxyGroupsDao.names(except: profileId).get(),
    ).wait;
    final CustomImportApp app = (
      profileLabels: {
        for (final profile in profiles) ...[profile.label, profile.realLabel],
      },
      profileSources: {
        for (final profile in profiles)
          if (profile.type == ProfileType.url)
            (url: profile.url, ageSecretKey: profile.ageSecretKey):
                profile.realLabel,
      },
      ruleProviderLabels: {
        for (final provider in ruleProviders) provider.label,
      },
      ruleProviderSources: {
        for (final provider in ruleProviders)
          if (provider.isRemote)
            (url: provider.url, ageSecretKey: ''): provider.label,
      },
      proxies: [for (final proxy in proxies) proxy.definition],
      groupNames: groupNames.toSet(),
    );
    try {
      return await compute(readCustomProfileImport, (bytes: bytes, app: app));
    } on CustomImportException catch (error) {
      final appLocalizations = currentAppLocalizations;
      throw MessageException(switch (error.issue) {
        CustomImportIssue.unreadable => appLocalizations.importConfigInvalid,
        CustomImportIssue.ruleType => appLocalizations.failedItem(
          error.item,
          appLocalizations.ruleTextInvalid,
        ),
        CustomImportIssue.entry => appLocalizations.failedItem(
          error.item,
          error.detail,
        ),
      });
    }
  }

  /// [config] replaces what [profileId] holds. The providers it adds are saved
  /// before the groups and rules naming them, and loaded afterwards; the
  /// future completes once they have loaded.
  Future<void> importCustomProfile(int profileId, CustomProfileImport config) {
    final profiles = ref.read(profilesProvider.notifier);
    final clashProviders = ref.read(clashProvidersProvider.notifier);
    final loads = <({String label, Future<void> Function() load})>[];
    for (final (:label, :url, :ageSecretKey, :content)
        in config.proxyProviders) {
      final profile = Profile.normal(
        label: label,
        url: url,
      ).copyWith(ageSecretKey: ageSecretKey);
      profiles.put(profile);
      loads.add((
        label: label,
        load: url.isNotEmpty
            ? () => updateProfile(profile, showLoading: true)
            : () async => profiles.put(
                await profile.saveFile(
                  utf8.encode(content),
                  validate: (path, key) => _core.validateProfile(path, key),
                ),
              ),
      ));
    }
    for (final (:label, :url, ageSecretKey: _, :content)
        in config.ruleProviders) {
      final provider = ClashProvider.create(label: label, url: url);
      clashProviders.put(provider);
      loads.add((
        label: label,
        load: url.isNotEmpty
            ? () => ref
                  .read(resourcesActionProvider.notifier)
                  .updateRuleProvider(provider)
            : () => ref
                  .read(clashProvidersActionProvider.notifier)
                  .putProvider(provider, content: utf8.encode(content)),
      ));
    }
    final customProxies = ref.read(customProxiesProvider.notifier);
    customProxies.putAll([
      for (final definition in config.proxies)
        CustomProxy.fromDefinition(definition),
    ]);
    final proxyIds = {
      for (final proxy in customProxies.value) proxy.name: proxy.id,
    };
    ref.read(proxyGroupsProvider(profileId).notifier).setAll([
      for (final group in config.proxyGroups) group.copyWith(id: snowflake.id),
    ]);
    ref.read(profileRulesProvider(profileId).notifier).setAll([
      for (final rule in config.rules) rule.copyWith(id: snowflake.id),
    ]);
    ref.read(proxyDialersProvider(profileId).notifier).setAll({
      for (final MapEntry(:key, :value) in config.dialers.entries)
        ?proxyIds[key]: value,
    });
    profiles.updateProfile(
      profileId,
      (profile) => profile.copyWith(overrides: config.overrides),
    );
    return globalState.batchRun(
      loads,
      (item) => item.load(),
      label: (item) => item.label,
      concurrency: maxConcurrentImports,
      tag: null,
    );
  }

  void _showProfiles() {
    if (globalState.navigatorKey.currentState?.canPop() ?? false) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    ref.read(currentPageLabelProvider.notifier).value = PageLabel.profiles;
  }

  /// [showProfiles] false leaves the routes open, for an import made from a
  /// sheet the user returns to.
  Future<void> addProfileFromLink(
    String link, {
    String? label,
    String ageSecretKey = '',
    bool showProfiles = true,
  }) async {
    if (showProfiles) {
      _showProfiles();
    }
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () => link.isShareLink
          ? _fromShareLinks(Profile.normal(label: label), [link])
          : _withAgeSecretKey(
              Profile.normal(
                label: label,
                url: link,
              ).copyWith(ageSecretKey: ageSecretKey),
              _download,
            ),
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  /// Ids are taken up front so the list keeps the order of [links]; the share
  /// links among them make up one profile, in the place of the first.
  Future<void> addProfilesFromLinks(
    List<String> links, {
    bool showProfiles = true,
  }) async {
    if (showProfiles) {
      _showProfiles();
    }
    final shareLinks = [
      for (final link in links)
        if (link.isShareLink) link,
    ];
    await globalState.batchRun(
      [
        for (final link in links)
          if (!link.isShareLink)
            (profile: Profile.normal(url: link), shareLinks: const <String>[])
          else if (link == shareLinks.first)
            (profile: Profile.normal(), shareLinks: shareLinks),
      ],
      (item) async => putProfile(
        await (item.shareLinks.isEmpty
            ? _download(item.profile)
            : _fromShareLinks(item.profile, item.shareLinks)),
      ),
      label: (item) => item.shareLinks.firstOrNull ?? item.profile.url,
      concurrency: maxConcurrentImports,
      tag: LoadingTag.profiles,
    );
  }

  Future<Profile> _download(Profile profile) {
    return profile.update(
      validate: (path, key) => _core.validateProfile(path, key),
    );
  }

  Future<Profile> _withAgeSecretKey(
    Profile profile,
    Future<Profile> Function(Profile profile) save,
  ) async {
    try {
      return await save(profile);
    } on AgeSecretKeyRequiredException {
      final key = (await dialogs.showAgeSecretKeyInput())?.trim();
      if (key == null || key.isEmpty) {
        rethrow;
      }
      return save(profile.copyWith(ageSecretKey: key));
    }
  }

  Future<Profile> _fromShareLinks(Profile profile, List<String> links) async {
    final appLocalizations = currentAppLocalizations;
    final decoded = await _core.decodeShareLinks(links);
    final taken = {...reservedCustomProxyNames};
    final proxies = <Map<String, dynamic>>[];
    for (final (index, definitions) in decoded.indexed) {
      if (definitions.isEmpty) {
        throw MessageException(
          links.length == 1
              ? appLocalizations.shareLinksInvalid
              : appLocalizations.shareLinkUnreadable(links[index]),
        );
      }
      for (final definition in definitions) {
        final name = freeProxyName(linkProxyName(definition), taken);
        proxies.add({...definition, 'name': name});
      }
    }
    final first = proxies.first['name'] as String;
    final label = proxies.length == 1
        ? first
        : appLocalizations.proxiesProfileLabel(first, proxies.length);
    final config = await encodeYamlTask({'proxies': proxies});
    return profile
        .copyWith(label: profile.label.takeFirstValid([label]))
        .saveFile(
          utf8.encode(config),
          validate: (path, _) => _core.validateConfig(path),
        );
  }

  Future<void> addProfileFormQrCode() async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return;
    unawaited(addProfileFromLink(url));
  }

  Future<void> clearEffect(int profileId) async {
    final profilePath = await appPath.getProfilePath(profileId.toString());
    final profileFile = File(profilePath);
    final isExists = await profileFile.exists();
    if (isExists) {
      await profileFile.safeDelete(recursive: true);
    }
    try {
      await _core.clearEffect(profileId);
    } catch (error) {
      commonPrint.log(
        'clearEffect($profileId) failed: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }
}
