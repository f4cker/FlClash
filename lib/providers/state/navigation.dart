part of '../state.dart';

@riverpod
NavigationItemsState navigationItemsState(Ref ref) {
  final openLogs = ref.watch(appSettingProvider).openLogs;
  final hasProfiles = ref.watch(
    profilesProvider.select((state) => state.isNotEmpty),
  );
  final hasProxies = ref.watch(
    currentGroupsStateProvider.select((state) => state.value.isNotEmpty),
  );
  final isInit = ref.watch(initProvider);
  // The rules are the running Core's: they show with a profile it runs, and
  // stay while open when the Core stops, so the page can say it did.
  final hasProfile = ref.watch(
    currentProfileProvider.select((profile) => profile != null),
  );
  final coreRunning = ref.watch(
    coreStatusProvider.select((status) => status == CoreStatus.connected),
  );
  final onRules = ref.watch(
    currentPageLabelProvider.select((label) => label == PageLabel.rules),
  );
  return NavigationItemsState(
    value:
        navigationPort?.getItems(
          openLogs: openLogs,
          hasProxies: !isInit ? hasProfiles : hasProxies,
          showRules: hasProfile && (coreRunning || onRules),
        ) ??
        const [],
  );
}

@riverpod
NavigationItemsState currentNavigationItemsState(Ref ref) {
  final viewWidth = ref.watch(viewWidthProvider);
  final navigationItemsState = ref.watch(navigationItemsStateProvider);
  final navigationItemMode = switch (viewWidth <= maxMobileWidth) {
    true => NavigationItemMode.mobile,
    false => NavigationItemMode.desktop,
  };
  return NavigationItemsState(
    value: navigationItemsState.value
        .where((element) => element.modes.contains(navigationItemMode))
        .toList(),
  );
}

PageLabel shownPageLabelOf(
  PageLabel pageLabel,
  List<NavigationItem> navigationItems,
) {
  if (navigationItems.isEmpty ||
      navigationItems.any((item) => item.label == pageLabel)) {
    return pageLabel;
  }
  return navigationItems.first.label;
}

@riverpod
PageLabel shownPageLabel(Ref ref) {
  return shownPageLabelOf(
    ref.watch(currentPageLabelProvider),
    ref.watch(currentNavigationItemsStateProvider).value,
  );
}

@riverpod
NavigationState navigationState(Ref ref) {
  final pageLabel = ref.watch(shownPageLabelProvider);
  final navigationItems = ref.watch(currentNavigationItemsStateProvider).value;
  final viewMode = ref.watch(viewModeProvider);
  final locale = ref.watch(appSettingProvider).locale;
  final index = navigationItems.lastIndexWhere(
    (element) => element.label == pageLabel,
  );
  final currentIndex = index == -1 ? 0 : index;
  return NavigationState(
    pageLabel: pageLabel,
    navigationItems: navigationItems,
    viewMode: viewMode,
    locale: locale,
    currentIndex: currentIndex,
  );
}

@riverpod
DashboardState dashboardState(Ref ref) {
  final dashboardWidgets = ref.watch(
    appSettingProvider.select((state) => state.dashboardWidgets),
  );
  return DashboardState(dashboardWidgets: dashboardWidgets);
}

@riverpod
MoreToolsSelectorState moreToolsSelectorState(Ref ref) {
  final viewMode = ref.watch(viewModeProvider);
  final navigationItems = ref
      .watch(
        navigationItemsStateProvider.select((state) {
          return SelectValue(
            state.value.where((element) {
              final isMore =
                  element.modes.contains(NavigationItemMode.more) ||
                  element.modes.contains(NavigationItemMode.moreFull);
              final isDesktop = element.modes.contains(
                NavigationItemMode.desktop,
              );
              if (isMore && !isDesktop) return true;
              if (viewMode != ViewMode.mobile || !isMore) {
                return false;
              }
              return true;
            }).toList(),
          );
        }),
      )
      .value;

  return MoreToolsSelectorState(navigationItems: navigationItems);
}

@riverpod
double overlayTopOffset(Ref ref) {
  final isMobileView = ref.watch(isMobileViewProvider);
  final version = ref.watch(versionProvider);
  ref.watch(viewSizeProvider);
  final showsHeader = showsWindowHeader(
    isDesktop: system.isDesktop,
    isMacOS: system.isMacOS,
    version: version,
    isMobileView: isMobileView,
  );
  // The window controls over a page sit within its app bar.
  return (showsHeader ? kHeaderHeight : 0) + bannerBarClearance;
}

bool defaultSidebarGroupCollapsed(
  NavigationGroup group, {
  required bool decrypting,
}) => switch (group) {
  NavigationGroup.decryption => !decrypting,
  NavigationGroup.network => true,
  NavigationGroup.routing || NavigationGroup.debug => false,
};

/// Whether each sidebar section is closed: the user's own choice once made,
/// otherwise its default, which for decryption follows whether it is on.
@riverpod
Map<NavigationGroup, bool> sidebarCollapsedGroups(Ref ref) {
  final chosen = ref.watch(
    appSettingProvider.select((state) => state.sidebarCollapsedGroups),
  );
  final decrypting = ref.watch(
    patchClashConfigProvider.select(
      (state) => mitmFeature && state.mitm.enable,
    ),
  );
  return {
    for (final group in NavigationGroup.values)
      group:
          chosen[group.name] ??
          defaultSidebarGroupCollapsed(group, decrypting: decrypting),
  };
}

/// A row's badge for [updates] pending updates and [errors] unloadable
/// items; an error outranks the count.
SidebarBadge? _updatesBadge({required int updates, required int errors}) {
  final appLocalizations = currentAppLocalizations;
  if (errors > 0) {
    return SidebarBadge(
      error: true,
      semanticLabel: appLocalizations.navBadgeError,
    );
  }
  if (updates > 0) {
    return SidebarBadge(
      count: updates,
      semanticLabel: appLocalizations.navBadgeUpdates(updates),
    );
  }
  return null;
}

/// What each sidebar row has to tell: the rewrite page its errors, the
/// scripts and modules pages their pending updates and unloadable items.
@riverpod
Map<PageLabel, SidebarBadge> navigationBadges(Ref ref) {
  if (!mitmFeature) {
    return const {};
  }
  final profileId = ref.watch(currentProfileIdProvider);
  final rewriteIssues = profileId == null
      ? 0
      : ref.watch(
              mitmRewriteIssuesProvider(
                profileId,
              ).select((value) => value.value?.length),
            ) ??
            0;
  final scripts = profileId == null
      ? null
      : ref.watch(
          profileMitmScriptsProvider(profileId).select(
            (value) => _updatesBadge(
              updates: value.value?.where((s) => s.hasPending).length ?? 0,
              errors: value.value?.where((s) => s.unloadable).length ?? 0,
            ),
          ),
        );
  final modules = !mitmModulesFeature
      ? null
      : ref.watch(
          mitmModulesProvider.select(
            (value) => _updatesBadge(
              updates: value.value?.where((m) => m.hasPending).length ?? 0,
              errors: value.value?.where((m) => m.unloadable).length ?? 0,
            ),
          ),
        );
  return {
    if (rewriteIssues > 0)
      PageLabel.mitmRewrite: SidebarBadge(
        error: true,
        semanticLabel: currentAppLocalizations.navBadgeError,
      ),
    PageLabel.mitmScripts: ?scripts,
    PageLabel.mitmModules: ?modules,
  };
}

/// Remembers the user's choice for [group], which from then on outranks its
/// default.
void setSidebarGroupCollapsed(
  WidgetRef ref,
  NavigationGroup group, {
  required bool collapsed,
}) {
  ref
      .read(appSettingProvider.notifier)
      .update(
        (state) => state.copyWith(
          sidebarCollapsedGroups: {
            ...state.sidebarCollapsedGroups,
            group.name: collapsed,
          },
        ),
      );
}
