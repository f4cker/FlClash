import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_rule_dialog.dart';
import 'rules_logic.dart';
import 'widgets.dart';

enum _RowKind { rule, entry, footer, divider }

/// The sources the note under the added rules can name, in its order.
enum RulesBelow { subscription, script, module }

RulesBelow? rulesBelowOf(RuleSource? source) => switch (source?.kind) {
  RuleSourceKind.subscription ||
  RuleSourceKind.custom => RulesBelow.subscription,
  RuleSourceKind.script => RulesBelow.script,
  RuleSourceKind.mitm => RulesBelow.module,
  _ => null,
};

String rulesBelowText(AppLocalizations l, List<RulesBelow> below) {
  final names = [
    for (final kind in below)
      switch (kind) {
        RulesBelow.subscription => l.rulesBelowSubscription,
        RulesBelow.script => l.rulesBelowScript,
        RulesBelow.module => l.rulesBelowModule,
      },
  ];
  final separator =
      l.localeName.startsWith('zh') || l.localeName.startsWith('ja')
      ? '、'
      : ', ';
  final list = names.length < 2
      ? names.join()
      : l.rulesBelowListLast(
          names.sublist(0, names.length - 1).join(separator),
          names.last,
        );
  return l.rulesAddedDivider(list);
}

/// One row of the rules list: a rule, an entry of an unfolded rule set, or
/// the foot of those entries.
class RuleRowItem {
  final _RowKind _kind;
  final CoreRule? rule;

  final RuleSource? module;

  final List<RulesBelow> below;
  final RuleHit? hit;
  final int parent;
  final int position;
  final String text;

  const RuleRowItem.rule(CoreRule this.rule, {this.hit})
    : _kind = _RowKind.rule,
      module = null,
      below = const [],
      parent = -1,
      position = 0,
      text = '';

  const RuleRowItem.entry({
    required this.parent,
    required this.position,
    required this.text,
  }) : _kind = _RowKind.entry,
       module = null,
       below = const [],
       rule = null,
       hit = null;

  const RuleRowItem.footer({required this.parent})
    : _kind = _RowKind.footer,
      module = null,
      below = const [],
      rule = null,
      hit = null,
      position = 0,
      text = '';

  const RuleRowItem.divider({this.module, this.below = const []})
    : _kind = _RowKind.divider,
      rule = null,
      hit = null,
      parent = -1,
      position = 0,
      text = '';

  bool get isRule => _kind == _RowKind.rule;

  bool get isDivider => _kind == _RowKind.divider;

  bool get isEntry => _kind == _RowKind.entry;
}

const _separatorAlpha = 0.5;

BorderRadius _cornersOf({required bool first, required bool last}) {
  return BorderRadius.vertical(
    top: first ? const Radius.circular(14) : Radius.zero,
    bottom: last ? const Radius.circular(14) : Radius.zero,
  );
}

Border? _separatorOf(BuildContext context, bool last) {
  if (last) return null;
  return Border(
    bottom: BorderSide(
      color: context.colorScheme.outlineVariant.withValues(
        alpha: _separatorAlpha,
      ),
    ),
  );
}

Color _childFillOf(BuildContext context) =>
    context.colorScheme.onSurface.withValues(alpha: 0.025);

/// The tag a looked-up rule carries: taken, passed over, or what it waits on.
Widget? hitTagOf(BuildContext context, RuleHit hit, int? winnerIndex) {
  final appLocalizations = context.appLocalizations;
  return switch (hit.status) {
    RuleHitStatus.winner => RuleTag.primary(
      context,
      appLocalizations.ruleHitTag,
    ),
    RuleHitStatus.shadowed => RuleTag.gray(
      context,
      winnerIndex == null
          ? appLocalizations.ruleHitTag
          : appLocalizations.ruleShadowedBy(winnerIndex + 1),
    ),
    RuleHitStatus.pass => RuleTag.gray(context, appLocalizations.rulePassTag),
    RuleHitStatus.noAdapter => RuleTag.gray(
      context,
      appLocalizations.ruleNoAdapterTag,
    ),
    RuleHitStatus.noUdp => RuleTag.gray(context, appLocalizations.ruleNoUdpTag),
    RuleHitStatus.uncertain => RuleTag.tone(
      context,
      hit.reason == 'rematch'
          ? appLocalizations.ruleDependsOnRematch
          : appLocalizations.ruleUncertainTag,
      RuleTone.amber,
    ),
  };
}

/// A rule of the list: its place, its text and source, and where it goes.
class RuleRow extends StatelessWidget {
  final CoreRule rule;
  final RuleHit? hit;
  final int? winnerIndex;
  final RuleSource? source;
  final bool narrow;
  final bool highlighted;
  final bool showNode;

  /// Null for a row that does not unfold.
  final bool? expanded;

  /// How many entries of the rule's set hold the text searched for.
  final int? setMatches;
  final bool first;
  final bool last;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback? onRevealGroup;
  final VoidCallback? onUpdateSet;

  /// The name of the profile the rules run from, for the source badge.
  final String profile;

  /// Set on a row the page edits: an added rule or rule set, or a custom
  /// profile's own rule. [onMoveUp] and [onMoveDown] are null at the ends.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  /// Lit for a moment after the rule was saved.
  final bool flashing;

  bool get editable => onDelete != null;

  const RuleRow({
    super.key,
    required this.rule,
    this.hit,
    this.winnerIndex,
    this.source,
    required this.narrow,
    this.highlighted = false,
    this.showNode = true,
    this.expanded,
    this.setMatches,
    required this.first,
    required this.last,
    required this.onTap,
    required this.onCopy,
    this.onRevealGroup,
    this.onUpdateSet,
    this.profile = '',
    this.onEdit,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    this.flashing = false,
  });

  List<Widget> _setExtras(BuildContext context) {
    final set = rule.ruleSet;
    if (set == null) return const [];
    final appLocalizations = context.appLocalizations;
    final caption = AppTextStyle.caption1
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    final loaded = set.loadedAt;
    final overdue = ruleSetOverdueDays(set, DateTime.now());
    return [
      if (set.status == 'ok' || set.count > 0)
        Text(
          loaded == null
              ? appLocalizations.ruleSetCountOnly(groupedCount(set.count))
              : appLocalizations.ruleSetSummary(
                  groupedCount(set.count),
                  loaded.getLastUpdateTimeDesc(context),
                ),
          style: caption,
        ),
      if (set.status == 'missing')
        RuleTag.tone(context, appLocalizations.ruleSetMissing, RuleTone.amber),
      if (set.status == 'failed')
        RuleTag.tone(context, appLocalizations.ruleSetFailed, RuleTone.red),
      if (set.status == 'absent')
        RuleTag.gray(context, appLocalizations.ruleSetAbsent),
      if (overdue > 0)
        RuleTag.tone(
          context,
          appLocalizations.ruleSetExpired(overdue),
          RuleTone.amber,
        ),
      if (setMatches case final count? when count > 0)
        Text(
          appLocalizations.ruleSetFilterMatches(count, set.name),
          style: caption,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final badge = ruleSourceBadge(context, rule, source, profile: profile);
    final hit = this.hit;
    final tag = hit == null ? null : hitTagOf(context, hit, winnerIndex);
    final target = _RuleTarget(target: rule.target, showNode: showNode);
    final number = rule.index + 1;
    final semantics = appLocalizations.ruleRowSemantics(
      number,
      rule.text,
      badge?.label ?? '',
      ruleTargetLabel(context, rule.target),
    );
    final menuItems = editable
        ? [
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
          ]
        : [
            PopupMenuItem(
              glyph: AppGlyphs.copy,
              label: appLocalizations.copyRule,
              onPressed: onCopy,
            ),
            if (onRevealGroup != null)
              PopupMenuItem(
                glyph: AppGlyphs.proxies,
                label: appLocalizations.viewGroup,
                onPressed: onRevealGroup,
              ),
            if (onUpdateSet != null)
              PopupMenuItem(
                glyph: AppGlyphs.resources,
                label: appLocalizations.goUpdate,
                onPressed: onUpdateSet,
              ),
          ];
    final content = Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RuleCode(ruleBodyOf(rule)),
        if (badge != null)
          RuleBadge(label: badge.label, tone: badge.tone, tooltip: badge.full),
        ..._setExtras(context),
        ?tag,
        if (narrow) target,
      ],
    );
    final corners = _cornersOf(first: first, last: last);
    if (!editable) {
      return _buildRow(
        context,
        semantics,
        menuItems,
        content,
        target,
        corners,
        false,
      );
    }
    return RuleRowHover(
      builder: (context, shown) => _buildRow(
        context,
        semantics,
        menuItems,
        content,
        target,
        corners,
        shown,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final number = rule.index + 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (onEdit != null)
          RuleRowAction(
            glyph: AppGlyphs.edit,
            color: const Color(0xFF3F3E45),
            label: appLocalizations.ruleEditSemantics(number),
            onPressed: onEdit!,
          ),
        RuleRowAction(
          glyph: AppGlyphs.delete,
          color: const Color(0xFFB3261E),
          label: appLocalizations.ruleDeleteSemantics(number),
          onPressed: onDelete!,
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    String semantics,
    List<PopupMenuItem> menuItems,
    Widget content,
    Widget target,
    BorderRadius corners,
    bool showActions,
  ) {
    final colorScheme = context.colorScheme;
    final expanded = this.expanded;
    final number = rule.index + 1;
    return Semantics(
      container: true,
      button: true,
      label: semantics,
      excludeSemantics: !showActions,
      expanded: expanded,
      child: ContextMenuRegion(
        menuItems: menuItems,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onDoubleTap: onEdit,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              constraints: const BoxConstraints(minHeight: 42),
              decoration: ShapeDecoration(
                color: flashing
                    ? const Color(0x1A007AFF)
                    : highlighted
                    ? colorScheme.primary.withValues(alpha: 0.08)
                    : colorScheme.primary.withValues(alpha: 0),
                shape: RoundedSuperellipseBorder(borderRadius: corners),
              ),
              foregroundDecoration: BoxDecoration(
                border: _separatorOf(context, last),
              ),
              child: Stack(
                children: [
                  if (highlighted)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: ColoredBox(color: colorScheme.primary),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 9, 16, 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            '$number',
                            textAlign: TextAlign.end,
                            style: AppTextStyle.caption1
                                .of(context)
                                .copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 14,
                          child: expanded == null
                              ? null
                              : GlyphIcon(
                                  expanded
                                      ? AppGlyphs.chevronDown
                                      : AppGlyphs.chevronForward,
                                  size: 10,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: content),
                        if (!narrow) ...[const SizedBox(width: 12), target],
                        if (showActions) ...[
                          const SizedBox(width: 8),
                          _buildActions(context),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a rule goes: its group and the node the group is on now, or the
/// built-in outbound in words.
class _RuleTarget extends ConsumerWidget {
  final String target;
  final bool showNode;

  const _RuleTarget({required this.target, required this.showNode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final green = RuleTone.green.of(context).ink;
    final arrowStyle = AppTextStyle.caption1.of(context).copyWith(color: green);
    if (isBuiltinTarget(target)) {
      return EmojiText(
        '→ ${ruleTargetLabel(context, target)}',
        style: arrowStyle,
      );
    }
    final node = showNode
        ? ref.watch(
            realSelectedProxyStateProvider(
              target,
            ).select((state) => state.proxyName),
          )
        : '';
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: RouteChip(label: target, height: 22),
        ),
        if (node.isNotEmpty && node != target)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: EmojiText(
              '→ ${ruleTargetLabel(context, node)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: arrowStyle,
            ),
          ),
      ],
    );
  }
}

/// An entry of an unfolded rule set, numbered under its rule.
class RuleEntryRow extends StatelessWidget {
  final int parent;
  final int position;
  final String text;
  final bool last;

  /// Whether this is the entry a lookup matched, marked as its rule is.
  final bool highlighted;
  final VoidCallback onTap;

  const RuleEntryRow({
    super.key,
    required this.parent,
    required this.position,
    required this.text,
    required this.last,
    this.highlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
          decoration: ShapeDecoration(
            color: highlighted
                ? colorScheme.primary.withValues(alpha: 0.08)
                : _childFillOf(context),
            shape: RoundedSuperellipseBorder(
              borderRadius: _cornersOf(first: false, last: last),
            ),
          ),
          foregroundDecoration: BoxDecoration(
            border: Border(
              left: highlighted
                  ? BorderSide(color: colorScheme.primary, width: 3)
                  : BorderSide.none,
              bottom: last
                  ? BorderSide.none
                  : BorderSide(
                      color: colorScheme.outlineVariant.withValues(
                        alpha: _separatorAlpha,
                      ),
                    ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  '${parent + 1}.${position + 1}',
                  textAlign: TextAlign.end,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
              const SizedBox(width: 14),
              Flexible(child: RuleCode(text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The foot of an unfolded rule set: loading more, or how much shows.
class RuleSetFooterRow extends StatelessWidget {
  final bool loading;
  final int shown;
  final int total;
  final String? error;
  final bool last;

  const RuleSetFooterRow({
    super.key,
    required this.loading,
    required this.shown,
    required this.total,
    this.error,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final caption = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final error = this.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(70, 8, 16, 8),
      decoration: ShapeDecoration(
        color: _childFillOf(context),
        shape: RoundedSuperellipseBorder(
          borderRadius: _cornersOf(first: false, last: last),
        ),
      ),
      foregroundDecoration: BoxDecoration(border: _separatorOf(context, last)),
      child: error != null
          ? Text(
              appLocalizations.rulesLoadFailed(error),
              style: caption.copyWith(color: colorScheme.error),
            )
          : loading
          ? Row(
              spacing: 6,
              children: [
                const ActivityIndicator(size: 12),
                Text(appLocalizations.rulesLoadingMore, style: caption),
              ],
            )
          : Text(
              appLocalizations.rulesShown(
                groupedCount(shown),
                groupedCount(total),
              ),
              style: caption,
            ),
    );
  }
}

/// Whether a row shows its edit buttons: while the pointer is over it or
/// focus is in it, so Tab reaches them too.
class RuleRowHover extends StatefulWidget {
  final Widget Function(BuildContext context, bool shown) builder;

  const RuleRowHover({super.key, required this.builder});

  @override
  State<RuleRowHover> createState() => _RuleRowHoverState();
}

class _RuleRowHoverState extends State<RuleRowHover> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Focus(child: widget.builder(context, _hovered || _focused)),
      ),
    );
  }
}

/// A 26-square button at the end of an editable row.
class RuleRowAction extends StatelessWidget {
  final Glyph glyph;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const RuleRowAction({
    super.key,
    required this.glyph,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.colorScheme.brightness == Brightness.dark;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onPressed();
                return null;
              },
            ),
          },
          // The row double-clicks to edit, which would hold a click here
          // for the double-click wait; the button takes its press at once.
          child: RawGestureDetector(
            gestures: {
              _EagerTapRecognizer:
                  GestureRecognizerFactoryWithHandlers<_EagerTapRecognizer>(
                    _EagerTapRecognizer.new,
                    (recognizer) => recognizer.onTap = onPressed,
                  ),
            },
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: dark ? const Color(0x33FFFFFF) : const Color(0xFFF2F1F5),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: GlyphIcon(
                glyph,
                size: 14,
                color: dark
                    ? Color.lerp(color, const Color(0xFFFFFFFF), 0.5)
                    : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Under the added rules; over a module's rules, names and links to it.
class RulesDividerRow extends StatelessWidget {
  const RulesDividerRow({
    super.key,
    this.module,
    this.below = const [],
    this.onOpenModule,
  });

  final String? module;
  final List<RulesBelow> below;
  final VoidCallback? onOpenModule;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final l = context.appLocalizations;
    final module = this.module;
    final caption = AppTextStyle.caption1.of(context);
    return Container(
      height: 28,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: colorScheme.brightness == Brightness.light
          ? const Color(0xFFF2F1F5)
          : colorScheme.onSurface.withValues(alpha: 0.06),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Text(
              module == null
                  ? rulesBelowText(l, below)
                  : l.rulesFromModule(module),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: caption.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          if (onOpenModule case final open?)
            GestureDetector(
              onTap: open,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  l.rulesViewInModule,
                  style: caption.copyWith(color: colorScheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A tap that claims its pointer on the press, ahead of the row's.
class _EagerTapRecognizer extends TapGestureRecognizer {
  _EagerTapRecognizer() : super(supportedDevices: null);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}
