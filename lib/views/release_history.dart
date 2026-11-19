import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/release_history.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/release_notes.dart';
import 'package:fl_clash/widgets/version_label.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReleaseHistoryView extends ConsumerStatefulWidget {
  const ReleaseHistoryView({super.key, this.store});

  final ReleaseHistoryStore? store;

  @override
  ConsumerState<ReleaseHistoryView> createState() => _ReleaseHistoryViewState();
}

class _ReleaseHistoryViewState extends ConsumerState<ReleaseHistoryView> {
  late final ReleaseHistoryStore _store;
  final _expanded = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _store =
        widget.store ??
        ReleaseHistoryStore(
          fetch: request.releaseHistory,
          readCache: preferences.getReleaseHistoryCache,
          writeCache: preferences.saveReleaseHistoryCache,
        );
    unawaited(_store.refresh());
  }

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(availableUpdateStateProvider);
    final package = globalState.packageInfo;
    final identity = ref.watch(installedMacReleaseProvider).value;
    final installed =
        identity?.fullVersion ??
        appVersionLabel(package.version, package.buildNumber);
    final l10n = context.appLocalizations;
    return Scaffold(
      title: l10n.releaseHistory,
      body: Builder(
        builder: (context) => ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final history = _store.history;
            final releases = history?.releases ?? const <PublishedRelease>[];
            final currentRelease =
                releases
                    .where((release) => release.version == installed)
                    .firstOrNull ??
                releases
                    .where(
                      (release) =>
                          release.version ==
                          (identity?.version ?? package.version),
                    )
                    .firstOrNull;
            final currentPresent = currentRelease != null;
            final showAvailable =
                available != null && available.versionLabel != installed;
            final entries = releases
                .where(
                  (release) =>
                      !showAvailable ||
                      !release.matchesAvailable(available) ||
                      release.tag == currentRelease?.tag,
                )
                .toList();
            final leadCount = showAvailable ? 2 : 1;
            return PrismListView(
              padding: EdgeInsets.fromLTRB(
                16,
                context.contentTopPadding,
                16,
                24 + context.bottomInset,
              ),
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              itemCount:
                  leadCount +
                  entries.length +
                  (history?.truncated == true ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text.rich(
                              versionMessageSpan(
                                (slots) => l10n.releaseInstalled(slots[0]),
                                [installed],
                                style: AppTextStyle.callout.of(
                                  context,
                                  emphasized: true,
                                ),
                                buildStyle: AppTextStyle.caption1.of(context),
                              ),
                            ),
                            if (identity?.channel == ReleaseChannel.beta)
                              Text(
                                l10n.releaseBeta,
                                style: AppTextStyle.footnote.of(context),
                              ),
                          ],
                        ),
                        if (history != null && !currentPresent)
                          Text(
                            l10n.releaseCurrentMissing,
                            style: AppTextStyle.footnote.of(context),
                          ),
                        if (history != null && releases.isEmpty)
                          Text(
                            l10n.releaseHistoryEmpty,
                            style: AppTextStyle.footnote.of(context),
                          ),
                        if (_store.stale && history != null)
                          Text(
                            l10n.releaseHistoryCached(_date(history.fetchedAt)),
                            style: AppTextStyle.footnote.of(context),
                          ),
                        if (_store.loading)
                          Semantics(
                            label: l10n.releaseHistoryLoading,
                            liveRegion: true,
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: RepaintBoundary(
                                child: ActivityIndicator(),
                              ),
                            ),
                          ),
                        TextButton(
                          onPressed: _store.loading ? null : _store.refresh,
                          child: Text(
                            _store.failed
                                ? l10n.releaseHistoryFailed
                                : l10n.tsRefresh,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (showAvailable && index == 1) {
                  final matching = releases
                      .where((release) => release.matchesAvailable(available))
                      .firstOrNull;
                  final body =
                      available.manifest?.notes ??
                      available.release['body'] as String? ??
                      matching?.body;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text.rich(
                              versionMessageSpan(
                                (slots) => l10n.releaseAvailable(slots[0]),
                                [available.versionLabel],
                                style: AppTextStyle.callout.of(
                                  context,
                                  emphasized: true,
                                ),
                                buildStyle: AppTextStyle.caption1.of(context),
                              ),
                            ),
                            if (available.manifest?.channel ==
                                ReleaseChannel.beta)
                              Text(
                                l10n.releaseBeta,
                                style: AppTextStyle.footnote.of(context),
                              ),
                          ],
                        ),
                        if (available.discoveryIncomplete)
                          Text(
                            l10n.betaUpdateCheckIncomplete,
                            style: AppTextStyle.footnote.of(context),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.releaseAvailableNotes,
                          style: AppTextStyle.footnote.of(
                            context,
                            emphasized: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ReleaseNotes(body: body),
                      ],
                    ),
                  );
                }
                final entryIndex = index - leadCount;
                if (entryIndex == entries.length) {
                  return TextButton(
                    onPressed: () => dialogs.openUrl(
                      'https://github.com/$releaseHistoryRepository/releases',
                    ),
                    child: Text(l10n.releaseHistoryLimited),
                  );
                }
                final release = entries[entryIndex];
                final current = release.tag == currentRelease?.tag;
                final expanded = _expanded[release.tag] ?? current;
                return _ReleaseEntry(
                  key: ValueKey(release.tag),
                  release: release,
                  label: current ? installed : release.version,
                  current: current,
                  installedBeta: identity?.channel == ReleaseChannel.beta,
                  expanded: expanded,
                  onToggle: () =>
                      setState(() => _expanded[release.tag] = !expanded),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _date(DateTime date) => date.toUtc().toIso8601String().split('T').first;

class _ReleaseEntry extends StatelessWidget {
  const _ReleaseEntry({
    super.key,
    required this.release,
    required this.label,
    required this.current,
    required this.installedBeta,
    required this.expanded,
    required this.onToggle,
  });

  final PublishedRelease release;
  final String label;
  final bool current;
  final bool installedBeta;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final color = context.colorScheme;
    final date = _date(release.published);
    return Stack(
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          left: 5.5,
          width: 1,
          child: ExcludeSemantics(
            child: ColoredBox(color: Divider.colorOf(context)),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              label: l10n.releaseEntryLabel(
                displayVersionLabel(label),
                date,
                [
                  if (current) l10n.releaseCurrent,
                  if ((current ? installedBeta : release.prerelease == true))
                    l10n.releaseBeta,
                ].join(', '),
                expanded ? l10n.releaseExpanded : l10n.releaseCollapsed,
              ),
              onTap: onToggle,
              excludeSemantics: true,
              child: PressSurface(
                fill: const Color(0x00000000),
                shape: AppShape.none,
                minimum: const BoxConstraints(minHeight: 64),
                onPressed: onToggle,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: current
                                ? color.primary
                                : color.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text.rich(
                                versionLabelSpan(
                                  label,
                                  style: AppTextStyle.callout.of(
                                    context,
                                    emphasized: true,
                                  ),
                                  buildStyle: AppTextStyle.caption1.of(context),
                                ),
                              ),
                              if ((current
                                  ? installedBeta
                                  : release.prerelease == true))
                                Text(
                                  l10n.releaseBeta,
                                  style: AppTextStyle.caption1.of(context),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                date,
                                style: AppTextStyle.caption1
                                    .of(context)
                                    .copyWith(color: color.onSurfaceVariant),
                              ),
                              if (current)
                                DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: color.primary.withValues(alpha: .1),
                                    shape: AppShape.full,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      l10n.releaseCurrent,
                                      style: AppTextStyle.caption1
                                          .of(context, emphasized: true)
                                          .copyWith(color: color.primary),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlyphIcon(
                      expanded ? AppGlyphs.chevronUp : AppGlyphs.chevronDown,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 0, 16),
                child: ReleaseNotes(body: release.body),
              ),
          ],
        ),
      ],
    );
  }
}
