part of '../state.dart';

@riverpod
ProfilesState profilesState(Ref ref) {
  final currentProfileId = ref.watch(currentProfileIdProvider);
  final profiles = ref.watch(profilesProvider);
  return ProfilesState(profiles: profiles, currentProfileId: currentProfileId);
}

@riverpod
Profile? currentProfile(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  return ref.watch(
    profilesProvider.select((state) => state.getProfile(profileId)),
  );
}

@riverpod
Profile? profile(Ref ref, int? profileId) {
  return ref.watch(
    profilesProvider.select((state) => state.getProfile(profileId)),
  );
}

@riverpod
Future<ClashConfig> clashConfig(Ref ref, int profileId) async {
  final type = ref.read(profileProvider(profileId))?.type;
  if (type == ProfileType.custom) {
    return const ClashConfig();
  }
  final outbounds = await ref
      .read(coreHandlerProvider)
      .getProfileOutbounds(profileId);
  return clashConfigTask(outbounds);
}

/// The groups a script leaves for a MATCH target; null without a script.
@Riverpod(retry: _noRetry)
Future<ClashConfig?> scriptOutbounds(Ref ref, int profileId) async {
  final scriptId = ref.watch(
    profileProvider(profileId).select(
      (state) => state?.type == ProfileType.custom ? null : state?.scriptId,
    ),
  );
  if (scriptId == null) {
    return null;
  }
  // The script as the list last read it: a later read of the list failing
  // keeps it, so a database error is never taken for the script failing.
  final (:loaded, :script) = ref.watch(
    scriptsProvider.select(
      (state) => (
        loaded: state.hasValue,
        script: state.value?.firstWhereOrNull((item) => item.id == scriptId),
      ),
    ),
  );
  if (!loaded) {
    // Not read yet: the first read decides, a failed one included. Its rows
    // arriving rebuild this through the select above.
    await ref.read(scriptsProvider.future);
    return null;
  }
  final content = await script?.content;
  if (content == null || content.isEmpty) {
    return null;
  }
  final config = await ref.read(coreHandlerProvider).readConfig(profileId);
  return evaluateOutbounds(content, config);
}

@Riverpod(retry: _noRetry)
Future<String?> profileMatchTarget(Ref ref, int profileId) async {
  final (:type, updated: _) = ref.watch(
    profileProvider(
      profileId,
    ).select((state) => (type: state?.type, updated: state?.lastUpdateDate)),
  );
  if (type == null || type == ProfileType.custom) {
    return null;
  }
  final scripted = await ref.watch(scriptOutboundsProvider(profileId).future);
  if (scripted != null) {
    return matchTargetOf(scripted.rules);
  }
  return ref.read(coreHandlerProvider).getProfileMatchTarget(profileId);
}

@riverpod
ProfileOverrides profileOverrides(Ref ref, int? profileId) {
  final profile = ref.watch(profileProvider(profileId));
  return profile?.type == ProfileType.custom
      ? ref.watch(
          patchClashConfigProvider.select(
            (state) => profile!.overrides.overAppTun(
              state.tunOverride,
              state.tunOverrideKeys,
            ),
          ),
        )
      : ref.watch(
          patchClashConfigProvider.select(
            (state) => ProfileOverrides(
              dns: state.dns,
              dnsOverrideKeys: state.dnsOverrideKeys.intersection(
                DnsOverrideKey.normalProfileKeys,
              ),
              tun: state.tunOverride,
              tunOverrideKeys: state.tunOverrideKeys,
            ),
          ),
        );
}

@riverpod
Future<SetupState> setupState(Ref ref, int? profileId) async {
  final profile = ref.watch(profileProvider(profileId));
  final scriptId = profile?.scriptId;
  final profileLastUpdateDate = profile?.lastUpdateDate?.millisecondsSinceEpoch;
  final profileType = profile?.type ?? ProfileType.file;
  final overrides = ref.watch(profileOverridesProvider(profileId));
  final allProfileProviders = ref.watch(profileProvidersProvider);
  final profiles = ref.read(profilesProvider);
  final mountable = profileId != null && profileType != ProfileType.custom;
  MountTargetState? readTarget;
  if (mountable) {
    ref.watch(profilesProvider.select(_mountSourceStamp));
    ref.listen(mountTargetProvider(profileId), (_, next) {
      if (next case AsyncData(:final value) when value != readTarget) {
        ref.invalidateSelf();
      }
    });
  }
  final mitmModules =
      mitmFeature &&
          mitmModulesFeature &&
          ref.watch(
            patchClashConfigProvider.select((state) => state.mitm.enable),
          )
      ? ref.watch(mitmModulesProvider.future)
      : null;
  final mitmHold = mitmModules == null
      ? RestoreMitmHold.none
      : ref.watch(restoreMitmHoldStateProvider);
  List<ProxyGroup> proxyGroups = [];
  List<Rule> rules = [];
  List<Rule> addedRules = [];
  List<ClashProvider> clashProviders = [];
  List<AddedRuleSet> addedRuleSets = [];
  Map<String, int> profileProviders = const {};
  List<CustomProxy> appProxies = [];
  Map<int, String> proxyDialers = const {};
  Script? script;
  if (profileId != null) {
    addedRuleSets = await database.addedRuleSetsDao.query(profileId).get();
    if (profileType == ProfileType.custom) {
      rules = await database.rulesDao.queryProfileRules(profileId).get();
      proxyGroups = await database.proxyGroupsDao.query(profileId).get();
      clashProviders = await database.clashProvidersDao.query().get();
      profileProviders = allProfileProviders;
      appProxies = await database.customProxiesDao.query().get();
      proxyDialers = {
        for (final dialer
            in await database.proxyDialersDao.query(profileId).get())
          dialer.proxyId: dialer.target,
      };
    } else {
      addedRules = await database.rulesDao.queryAddedRules(profileId).get();
      script = scriptId == null
          ? null
          : await database.scriptsDao.get(scriptId).getSingleOrNull();
    }
  }
  final mountTarget = readTarget = mountable
      ? await database.mountsDao.target(profileId)
      : null;
  final mounts = mountTarget == null
      ? null
      : mountSetupOf(mountTarget, profiles, await appPath.profilesPath);
  return SetupState(
    mounts: mounts,
    mitmModules: mitmModules == null
        ? const []
        : await mitmRoutingSources(await mitmModules, hold: mitmHold),
    clashProviders: clashProviders,
    profileProviders: profileProviders,
    appProxies: appProxies,
    proxyDialers: proxyDialers,
    rules: rules,
    proxyGroups: proxyGroups,
    profileId: profileId,
    profileLastUpdateDate: profileLastUpdateDate,
    profileType: profileType,
    addedRules: addedRules,
    addedRuleSets: addedRuleSets,
    script: script,
    overrides: overrides,
    exitTargets: profile?.exitTargets ?? const {},
  );
}

/// What a mount revision reads from the subscriptions it may mount.
String _mountSourceStamp(List<Profile> profiles) => json.encode([
  for (final profile in profiles)
    if (profile.type == ProfileType.url)
      [
        profile.id,
        profile.realLabel,
        profile.lastUpdateDate?.millisecondsSinceEpoch,
      ],
]);

/// A module not yet downloaded adds nothing until it is.
Future<List<MitmModuleSource>> mitmRoutingSources(
  Iterable<MitmModule> modules, {
  RestoreMitmHold hold = RestoreMitmHold.none,
}) async {
  final directory = await appPath.mitmModulesDirPath;
  final sources = <MitmModuleSource>[];
  for (final module in modules) {
    if (!module.runsUnder(hold) || !module.rulesEnabled) {
      continue;
    }
    final file = File(join(directory, module.fileName));
    if (!await file.exists()) {
      continue;
    }
    sources.add(
      MitmModuleSource(
        id: module.id,
        content: await file.readAsString(),
        name: module.name,
        arguments: module.arguments,
        resources: module.resources,
      ),
    );
  }
  return sources;
}

/// Subscription profiles double as proxy providers for custom profiles.
@riverpod
Map<String, int> profileProviders(Ref ref) {
  final profiles = ref.watch(profilesProvider);
  return {
    for (final profile in profiles)
      if (profile.type != ProfileType.custom) profile.realLabel: profile.id,
  };
}
