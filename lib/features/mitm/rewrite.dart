import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/mitm_status.dart' show openMitmSettings;
import 'package:fl_clash/views/profiles/mount.dart'
    show MountBanner, MountBannerLevel;
import 'package:fl_clash/views/rules/rule_rows.dart'
    show RuleRowAction, RuleRowHover;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rewrite_dialogs.dart';

const mitmRewriteErrorInk = Color(0xFFB3261E);
// #FF8A80 on the dark card reads at over 4.5:1.
const _errorInkDark = Color(0xFFFF8A80);

// An invalid row keeps the plain card, with red text and an icon only, as
// on the scripts and modules pages. Its turned-off switch keeps a grey track.
const _disabledTrackLight = Color(0xFFE5E5EA);
const _disabledTrackDark = Color(0xFF3A3A3C);
const _flashFill = Color(0x1A007AFF);
const _flashDuration = Duration(milliseconds: 1500);

Color mitmRewriteErrorColor(BuildContext context) =>
    context.colorScheme.brightness == Brightness.dark
    ? _errorInkDark
    : mitmRewriteErrorInk;

/// Hands the Core [next] as the profile's rewrite rules, then stores them:
/// it returns once the Core runs them (or, with decryption off, another
/// profile current or the Core not connected, once they are stored) and
/// throws, nothing changed, if the Core refuses them.
Future<void> commitMitmRewrites(
  WidgetRef ref,
  int profileId,
  List<MitmRewrite> next,
) async {
  final notifier = ref.read(profileMitmRewritesProvider(profileId).notifier);
  final setup = ref.read(mitmSetupProvider);
  final core = ref.read(coreHandlerProvider);
  final live =
      setup != null &&
      ref.read(currentProfileIdProvider) == profileId &&
      ref.read(coreStatusProvider) == CoreStatus.connected;
  if (live) {
    await core.updateMitm(
      composeMitmSetup(
        ref.read(patchClashConfigProvider).mitm,
        rewrites: next,
        scripts: ref.read(currentMitmScriptsProvider),
        modules:
            ref.read(enabledMitmModuleRulesProvider).value ??
            MitmModuleRules.empty,
      ),
    );
  }
  try {
    await notifier.commit(next);
  } catch (_) {
    if (live) {
      // The Core runs rules no longer stored; it goes back to the stored.
      unawaited(
        core.updateMitm(ref.read(mitmSetupProvider)).catchError((Object _) {}),
      );
    }
    rethrow;
  }
}

/// Where [added] go among [current]: each at the end (or [atStart], the
/// start) of its page group, in the order given; a group not yet there
/// starts at the end of the list.
List<MitmRewrite> placeMitmRewrites(
  List<MitmRewrite> current,
  List<MitmRewrite> added, {
  bool atStart = false,
}) {
  final result = [...current];
  final groupOf = <int, MitmRewriteGroup>{
    for (final rewrite in [...current, ...added])
      rewrite.id: mitmRewriteGroupOf(rewrite.section, rewrite.line),
  };
  final insertedAtStart = <MitmRewriteGroup, int>{};
  for (final rewrite in added) {
    final group = groupOf[rewrite.id]!;
    final members = [
      for (final (index, item) in result.indexed)
        if (groupOf[item.id] == group) index,
    ];
    if (members.isEmpty) {
      result.add(rewrite);
      insertedAtStart[group] = 1;
      continue;
    }
    if (atStart) {
      final placed = insertedAtStart[group] ?? 0;
      final at = placed < members.length ? members[placed] : members.last + 1;
      result.insert(at, rewrite);
      insertedAtStart[group] = placed + 1;
    } else {
      result.insert(members.last + 1, rewrite);
    }
  }
  return result;
}

/// The row on the decryption page that opens [MitmRewriteView].
class MitmRewriteEntryItem extends ConsumerWidget {
  const MitmRewriteEntryItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final profileId = ref.watch(currentProfileIdProvider);
    final count = profileId == null
        ? 0
        : ref.watch(
                profileMitmRewritesProvider(
                  profileId,
                ).select((value) => value.value?.length),
              ) ??
              0;
    final invalid = profileId == null || count == 0
        ? 0
        : ref.watch(
                mitmRewriteIssuesProvider(
                  profileId,
                ).select((value) => value.value?.length),
              ) ??
              0;
    final style = AppTextStyle.footnote
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    return ListItem.open(
      leading: const GlyphIcon(AppGlyphs.wand),
      title: Text(appLocalizations.mitmRewrite),
      subtitle: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: count == 0
                  ? appLocalizations.mitmRewriteNoneAdded
                  : appLocalizations.mitmRewriteRuleCount(count),
            ),
            if (invalid > 0)
              TextSpan(
                text: ' · ${appLocalizations.mitmRewriteInvalidCount(invalid)}',
                style: TextStyle(color: mitmRewriteErrorColor(context)),
              ),
          ],
        ),
      ),
      widget: const MitmRewriteView(),
    );
  }
}

/// The current profile's rewrite rules, by group. [revealRule] scrolls to
/// that rule and lights it a moment.
class MitmRewriteView extends ConsumerStatefulWidget {
  final int? revealRule;

  const MitmRewriteView({super.key, this.revealRule});

  static const pasteKey = ValueKey('mitm-rewrite-paste');

  @override
  ConsumerState<MitmRewriteView> createState() => _MitmRewriteViewState();
}

class _MitmRewriteViewState extends ConsumerState<MitmRewriteView> {
  String _query = '';
  final _pending = <int>{};
  final _flashing = <int>{};
  final _rowKeys = <int, GlobalKey>{};
  String? _error;
  Timer? _flashTimer;
  bool _revealed = false;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  GlobalKey _keyOf(int id) => _rowKeys.putIfAbsent(id, GlobalKey.new);

  void _flash(Iterable<int> ids, {bool scroll = true}) {
    _flashTimer?.cancel();
    setState(() {
      _flashing
        ..clear()
        ..addAll(ids);
    });
    if (scroll && ids.isNotEmpty) {
      runAfterFrame(() {
        final rowContext = _rowKeys[ids.first]?.currentContext;
        if (rowContext != null && rowContext.mounted) {
          Scrollable.ensureVisible(rowContext, alignment: 0.3);
        }
      });
    }
    _flashTimer = Timer(_flashDuration, () {
      if (mounted) setState(_flashing.clear);
    });
  }

  List<MitmRewrite> _rewrites(int profileId) =>
      ref.read(profileMitmRewritesProvider(profileId)).value ?? const [];

  Future<bool> _commit(int profileId, List<MitmRewrite> next) async {
    try {
      await commitMitmRewrites(ref, profileId, next);
      if (mounted && _error != null) setState(() => _error = null);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = context.appLocalizations.mitmRewriteNotApplied(
            mitmRewriteFailureText(context.appLocalizations, error),
          );
        });
      }
      return false;
    }
  }

  Future<void> _toggle(int profileId, MitmRewrite rewrite, bool value) async {
    if (_pending.contains(rewrite.id)) return;
    setState(() => _pending.add(rewrite.id));
    await _commit(profileId, [
      for (final item in _rewrites(profileId))
        item.id == rewrite.id ? item.copyWith(enabled: value) : item,
    ]);
    if (mounted) setState(() => _pending.remove(rewrite.id));
  }

  Future<void> _setAllEnabled(int profileId, bool value) async {
    final rewrites = _rewrites(profileId);
    final changed = {
      for (final item in rewrites)
        if (item.enabled != value) item.id,
    };
    if (changed.isEmpty) return;
    setState(() => _pending.addAll(changed));
    await _commit(profileId, [
      for (final item in rewrites) item.copyWith(enabled: value),
    ]);
    if (mounted) setState(() => _pending.removeAll(changed));
  }

  Future<void> _move(int profileId, MitmRewrite rewrite, int step) async {
    final rewrites = [..._rewrites(profileId)];
    final group = mitmRewriteGroupOf(rewrite.section, rewrite.line);
    final members = [
      for (final (index, item) in rewrites.indexed)
        if (mitmRewriteGroupOf(item.section, item.line) == group) index,
    ];
    final at = members.indexWhere((index) => rewrites[index].id == rewrite.id);
    final other = at + step;
    if (at < 0 || other < 0 || other >= members.length) return;
    final a = members[at];
    final b = members[other];
    rewrites[a] = rewrites[b];
    rewrites[b] = rewrite;
    await _commit(profileId, rewrites);
  }

  Future<void> _delete(int profileId, Iterable<int> ids) async {
    final removed = ids.toSet();
    await _commit(profileId, [
      for (final item in _rewrites(profileId))
        if (!removed.contains(item.id)) item,
    ]);
  }

  Future<void> _confirmDelete(int profileId, MitmRewrite rewrite) async {
    final appLocalizations = context.appLocalizations;
    final res = await dialogs.showMessage(
      context: context,
      title: appLocalizations.ruleDeleteTitle,
      message: TextSpan(text: appLocalizations.ruleDeleteBody(rewrite.line)),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res == true) await _delete(profileId, [rewrite.id]);
  }

  Future<void> _deleteInvalid(int profileId, Set<int> invalid) async {
    final appLocalizations = context.appLocalizations;
    final res = await dialogs.showMessage(
      context: context,
      title: appLocalizations.mitmRewriteDeleteInvalid,
      message: TextSpan(
        text: appLocalizations.mitmRewriteDeleteInvalidConfirm(invalid.length),
      ),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res == true) await _delete(profileId, invalid);
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) dialogs.showBanner(context.appLocalizations.copySuccess);
  }

  Future<void> _paste(int profileId) async {
    final result = await showMitmRewritePasteDialog(
      context,
      existing: _rewrites(profileId),
      onImport: (added, atStart) => commitMitmRewrites(
        ref,
        profileId,
        placeMitmRewrites(_rewrites(profileId), added, atStart: atStart),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    // The count is of rules now stored, not of lines the check passed; that
    // they are saved says nothing yet of traffic, so the banner says
    // imported, not applied.
    final ids = {
      for (final rewrite in _rewrites(profileId))
        if (result.any((added) => added.id == rewrite.id)) rewrite.id,
    };
    if (ids.isEmpty) return;
    dialogs.showBanner(
      context.appLocalizations.mitmRewriteImported(ids.length),
      level: BannerLevel.success,
    );
    final first = _rewrites(profileId).firstWhere(
      (rewrite) => ids.contains(rewrite.id),
      orElse: () => result.first,
    );
    _flash([first.id, ...ids.where((id) => id != first.id)]);
  }

  Future<void> _edit(int profileId, MitmRewrite rewrite, int number) async {
    final appLocalizations = context.appLocalizations;
    final group = mitmRewriteGroupOf(rewrite.section, rewrite.line);
    final saved = await showMitmRewriteEditDialog(
      context,
      rewrite: rewrite,
      subtitle: appLocalizations.mitmRewriteEditSubtitle(
        group.label(appLocalizations),
        number,
      ),
      onSave: (line) => commitMitmRewrites(ref, profileId, [
        for (final item in _rewrites(profileId))
          item.id == rewrite.id ? item.copyWith(line: line) : item,
      ]),
      onDelete: () => commitMitmRewrites(ref, profileId, [
        for (final item in _rewrites(profileId))
          if (item.id != rewrite.id) item,
      ]),
    );
    if (saved == true && mounted) _flash([rewrite.id], scroll: false);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final profileId = ref.watch(currentProfileIdProvider);
    final profileLabel = ref.watch(
      currentProfileProvider.select((profile) => profile?.realLabel ?? ''),
    );
    final decrypting = ref.watch(
      patchClashConfigProvider.select((state) => state.mitm.enable),
    );
    final value = profileId == null
        ? null
        : ref.watch(profileMitmRewritesProvider(profileId));
    final rewrites = value?.value ?? const <MitmRewrite>[];
    final issues = profileId == null
        ? const <int, MitmRewriteIssue>{}
        : ref.watch(mitmRewriteIssuesProvider(profileId)).value ??
              const <int, MitmRewriteIssue>{};
    final bodyLimit = ref.watch(mitmRewriteBodyLimitProvider).value ?? 0;
    final invalid = {
      for (final rewrite in rewrites)
        if (issues.containsKey(rewrite.id)) rewrite.id,
    };
    final enabledCount = rewrites
        .where((rewrite) => rewrite.enabled && !invalid.contains(rewrite.id))
        .length;
    if (!_revealed && widget.revealRule != null && rewrites.isNotEmpty) {
      _revealed = true;
      if (rewrites.any((rewrite) => rewrite.id == widget.revealRule)) {
        runAfterFrame(() {
          if (mounted) _flash([widget.revealRule!]);
        });
      }
    }
    final subtitle = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: appLocalizations.mitmRewriteSubtitle(
              profileLabel,
              rewrites.length,
              enabledCount,
            ),
          ),
          if (invalid.isNotEmpty)
            TextSpan(
              text:
                  ' · ${appLocalizations.mitmRewriteInvalidCount(invalid.length)}',
              style: TextStyle(color: mitmRewriteErrorColor(context)),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.footnote
          .of(context)
          .copyWith(color: colorScheme.onSurfaceVariant),
    );
    return Scaffold(
      title: appLocalizations.mitmRewrite,
      searchState: rewrites.isEmpty
          ? null
          : AppBarSearchState(
              onSearch: (query) => setState(() => _query = query),
              hintText: appLocalizations.mitmRewriteSearchHint,
            ),
      // With no rules the empty state's own button is the one way in.
      actions: [
        if (profileId != null && rewrites.isNotEmpty)
          FilledButton(
            key: MitmRewriteView.pasteKey,
            onPressed: () => _paste(profileId),
            child: Text(appLocalizations.mitmRewritePaste),
          ),
      ],
      menuItems: profileId == null || rewrites.isEmpty
          ? const []
          : [
              PopupMenuItem(
                label: appLocalizations.mitmRewriteEnableAll,
                onPressed: () => _setAllEnabled(profileId, true),
              ),
              PopupMenuItem(
                label: appLocalizations.mitmRewriteDisableAll,
                onPressed: () => _setAllEnabled(profileId, false),
              ),
              PopupMenuItem(
                glyph: AppGlyphs.copy,
                label: appLocalizations.mitmRewriteCopyAll,
                onPressed: () => _copy(mitmRewriteSurgeText(rewrites)),
              ),
              PopupMenuItem(
                glyph: AppGlyphs.delete,
                label: appLocalizations.mitmRewriteDeleteInvalid,
                danger: true,
                section: const PopupMenuSection(),
                onPressed: invalid.isEmpty
                    ? null
                    : () => _deleteInvalid(profileId, invalid),
              ),
            ],
      body: Builder(
        builder: (context) => _buildBody(
          context,
          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
            top: context.contentTopPadding,
            bottom: 16 + context.bottomInset,
          ),
          profileId: profileId,
          loading: value != null && value.isLoading && !value.hasValue,
          rewrites: rewrites,
          subtitle: subtitle,
          issues: issues,
          bodyLimit: bodyLimit,
          decrypting: decrypting,
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required EdgeInsets padding,
    required Widget subtitle,
    required int? profileId,
    required bool loading,
    required List<MitmRewrite> rewrites,
    required Map<int, MitmRewriteIssue> issues,
    required int bodyLimit,
    required bool decrypting,
  }) {
    final appLocalizations = context.appLocalizations;
    final banners = [
      if (_error case final error?)
        MountBanner(level: MountBannerLevel.error, lines: [error]),
      if (!decrypting)
        MountBanner(
          level: MountBannerLevel.info,
          lines: [appLocalizations.mitmRewriteOff],
          actionLabel: appLocalizations.mitmRewriteGoTurnOn,
          onAction: () async {
            if (!await Navigator.of(context).maybePop() && context.mounted) {
              await openMitmSettings(context);
            }
          },
        ),
    ];
    if (profileId == null || rewrites.isEmpty) {
      return Column(
        children: [
          if (banners.isNotEmpty)
            Padding(
              padding: padding.copyWith(bottom: 0),
              child: Column(spacing: 8, children: banners),
            ),
          Expanded(
            child: NullStatusSwitcher(
              isLoading: loading,
              isEmpty: true,
              nullStatus: NullStatus(
                label: appLocalizations.mitmRewriteEmptyTitle,
                description: appLocalizations.mitmRewriteEmptyDesc,
                illustration: NullStatusIllustration.rewrites,
                action: profileId == null
                    ? null
                    : FilledButton(
                        onPressed: () => _paste(profileId),
                        child: Text(appLocalizations.mitmRewritePaste),
                      ),
              ),
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      );
    }
    final query = _query.trim().toLowerCase();
    final described = [
      for (final (index, rewrite) in rewrites.indexed)
        (
          rewrite: rewrite,
          index: index,
          description: describeMitmRewrite(
            appLocalizations,
            rewrite.section,
            rewrite.line,
            bodyLimit: bodyLimit,
            sizeText: (bytes) => bytes.traffic.show,
          ),
          group: mitmRewriteGroupOf(rewrite.section, rewrite.line),
        ),
    ];
    final shown = query.isEmpty
        ? described
        : [
            for (final item in described)
              if (item.rewrite.line.toLowerCase().contains(query) ||
                  (item.description?.summary.toLowerCase().contains(query) ??
                      false))
                item,
          ];
    final sections = <Widget>[];
    for (final group in MitmRewriteGroup.values) {
      final members = [
        for (final item in shown)
          if (item.group == group) item,
      ];
      if (members.isEmpty) continue;
      final all = [
        for (final item in described)
          if (item.group == group) item.rewrite.id,
      ];
      sections.add(
        Column(
          children: [
            ListHeader(
              title: group.label(appLocalizations),
              trailing: Text(
                '${members.length}',
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ),
            generateGroup([
              for (final item in members)
                _MitmRewriteRow(
                  key: _keyOf(item.rewrite.id),
                  rewrite: item.rewrite,
                  description: item.description,
                  issue: issues[item.rewrite.id],
                  pending: _pending.contains(item.rewrite.id),
                  flashing: _flashing.contains(item.rewrite.id),
                  onToggle: (value) => _toggle(profileId, item.rewrite, value),
                  onEdit: () => _edit(
                    profileId,
                    item.rewrite,
                    all.indexOf(item.rewrite.id) + 1,
                  ),
                  onDelete: () => _confirmDelete(profileId, item.rewrite),
                  onCopy: () => _copy(item.rewrite.line),
                  onMoveUp: all.first == item.rewrite.id
                      ? null
                      : () => _move(profileId, item.rewrite, -1),
                  onMoveDown: all.last == item.rewrite.id
                      ? null
                      : () => _move(profileId, item.rewrite, 1),
                ),
            ]),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: subtitle),
          if (banners.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(spacing: 8, children: banners),
            ),
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: NullStatus(
                label: UiLocalizations.of(context).noSearchResults,
                illustration: Illustration.search,
              ),
            ),
          ...sections,
        ],
      ),
    );
  }
}

class _MitmRewriteRow extends StatelessWidget {
  final MitmRewrite rewrite;
  final MitmRewriteDescription? description;
  final MitmRewriteIssue? issue;
  final bool pending;
  final bool flashing;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _MitmRewriteRow({
    super.key,
    required this.rewrite,
    required this.description,
    required this.issue,
    required this.pending,
    required this.flashing,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final description = this.description;
    final issue = this.issue;
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final menuItems = [
      PopupMenuItem(
        glyph: AppGlyphs.edit,
        label: appLocalizations.ruleEditMenu,
        onPressed: onEdit,
      ),
      PopupMenuItem(
        glyph: AppGlyphs.arrowUp,
        label: appLocalizations.ruleMoveUp,
        onPressed: onMoveUp,
      ),
      PopupMenuItem(
        glyph: AppGlyphs.arrowDown,
        label: appLocalizations.ruleMoveDown,
        onPressed: onMoveDown,
      ),
      PopupMenuItem(
        glyph: AppGlyphs.copy,
        label: appLocalizations.copyRule,
        onPressed: onCopy,
      ),
      PopupMenuItem(
        glyph: AppGlyphs.delete,
        label: appLocalizations.delete,
        danger: true,
        section: const PopupMenuSection(),
        onPressed: onDelete,
      ),
    ];
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 3,
      children: [
        Tooltip(
          message: rewrite.line,
          hoverDelay: const Duration(milliseconds: 500),
          excludeFromSemantics: true,
          child: Text(
            rewrite.line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.footnote.of(context).toJetBrainsMono,
          ),
        ),
        if (description != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: description.action,
                  style: AppTextStyle.footnote
                      .of(context, emphasized: true)
                      .copyWith(color: colorScheme.onSurface),
                ),
                if (description.detail.isNotEmpty)
                  TextSpan(
                    text: description.detail.startsWith('→')
                        ? ' ${description.detail}'
                        : ' · ${description.detail}',
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: secondary,
          ),
        if (issue != null)
          // The Core's own words stay in the details, never in the red line.
          Tooltip(
            message: issue.message,
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: GlyphIcon(
                        AppGlyphs.warning,
                        size: 13,
                        color: mitmRewriteErrorColor(context),
                      ),
                    ),
                  ),
                  TextSpan(
                    text: appLocalizations.mitmRewriteInvalid(
                      mitmRewriteIssueText(appLocalizations, issue),
                    ),
                  ),
                ],
              ),
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: mitmRewriteErrorColor(context)),
            ),
          ),
      ],
    );
    final toggleLabel = issue != null
        ? appLocalizations.mitmRewriteInvalidSpoken(
            mitmRewriteIssueText(appLocalizations, issue),
          )
        : appLocalizations.mitmRewriteToggleLabel(
            description?.action ?? rewrite.section.key,
            description?.match ?? rewrite.line,
          );
    final toggle = pending
        ? SizedBox(
            width: Switch.trackWidth,
            child: Center(
              child: ActivityIndicator(
                size: 16,
                color: colorScheme.primary,
                semanticLabel: toggleLabel,
              ),
            ),
          )
        : Switch(
            value: rewrite.enabled && issue == null,
            semanticLabel: toggleLabel,
            fadeWhenDisabled: true,
            onChanged: issue != null ? null : onToggle,
          );
    final dark = colorScheme.brightness == Brightness.dark;
    final shownToggle = issue == null || pending
        ? toggle
        : Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: dark ? _disabledTrackDark : _disabledTrackLight,
                  shape: AppShape.full,
                ),
                child: const SizedBox(
                  width: Switch.trackWidth,
                  height: Switch.trackHeight,
                ),
              ),
              toggle,
            ],
          );
    final desktop = system.isDesktop;
    return RuleRowHover(
      builder: (context, shown) => ContextMenuRegion(
        menuItems: menuItems,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: desktop ? onEdit : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            // Shaped as the row's card, so the light keeps its corners.
            foregroundDecoration: ShapeDecoration(
              color: flashing ? _flashFill : const Color(0x00007AFF),
              shape: AppShape.of(
                listItemRadiusOf(ItemPositionProvider.of(context)?.position),
              ),
            ),
            child: DecorationListItem(
              onPressed: desktop ? null : onEdit,
              title: title,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  if (shown && desktop) ...[
                    RuleRowAction(
                      glyph: AppGlyphs.edit,
                      color: const Color(0xFF3F3E45),
                      label: appLocalizations.edit,
                      onPressed: onEdit,
                    ),
                    RuleRowAction(
                      glyph: AppGlyphs.delete,
                      color: mitmRewriteErrorInk,
                      label: appLocalizations.delete,
                      onPressed: onDelete,
                    ),
                  ],
                  shownToggle,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The plain-language separator a list of counts takes in [l]'s language.
String mitmRewriteListSeparator(AppLocalizations l) =>
    l.localeName.startsWith('zh') ? '、' : ', ';
