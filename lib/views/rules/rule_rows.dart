import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_rule_dialog.dart';
import 'rules_logic.dart';
import 'widgets.dart';

enum _RowKind { rule, entry, footer }

/// One row of the rules list: a rule, an entry of an unfolded rule set, or
/// the foot of those entries.
class RuleRowItem {
  final _RowKind _kind;
  final CoreRule? rule;
  final RuleHit? hit;
  final int parent;
  final int position;
  final String text;

  const RuleRowItem.rule(CoreRule this.rule, {this.hit})
    : _kind = _RowKind.rule,
      parent = -1,
      position = 0,
      text = '';

  const RuleRowItem.entry({
    required this.parent,
    required this.position,
    required this.text,
  }) : _kind = _RowKind.entry,
       rule = null,
       hit = null;

  const RuleRowItem.footer({required this.parent})
    : _kind = _RowKind.footer,
      rule = null,
      hit = null,
      position = 0,
      text = '';

  bool get isRule => _kind == _RowKind.rule;

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
  final detail = hit.detail.isNotEmpty ? hit.detail : hit.payload;
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
    RuleHitStatus.uncertain => RuleTag.tone(context, switch (hit.reason) {
      'process' || 'uid' => appLocalizations.ruleOnlyForApp(detail),
      'port' => appLocalizations.ruleOnlyForPort(detail),
      'network' => appLocalizations.ruleDependsOnNetwork,
      'inbound' => appLocalizations.ruleDependsOnInbound,
      'source' => appLocalizations.ruleDependsOnSource,
      'ip' => appLocalizations.ruleDependsOnIp,
      'rematch' => appLocalizations.ruleDependsOnRematch,
      _ => appLocalizations.ruleDependsOnOther,
    }, RuleTone.amber),
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
    final colorScheme = context.colorScheme;
    final badge = ruleSourceBadge(context, rule, source, named: false);
    final hit = this.hit;
    final tag = hit == null ? null : hitTagOf(context, hit, winnerIndex);
    final target = _RuleTarget(target: rule.target, showNode: showNode);
    final expanded = this.expanded;
    final number = rule.index + 1;
    final semantics = appLocalizations.ruleRowSemantics(
      number,
      rule.text,
      badge?.label ?? '',
      ruleTargetLabel(context, rule.target),
    );
    final menuItems = [
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
        if (badge != null) RuleBadge(label: badge.label, tone: badge.tone),
        ..._setExtras(context),
        ?tag,
        if (narrow) target,
      ],
    );
    final corners = _cornersOf(first: first, last: last);
    return Semantics(
      container: true,
      button: true,
      label: semantics,
      excludeSemantics: true,
      expanded: expanded,
      child: ContextMenuRegion(
        menuItems: menuItems,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              decoration: ShapeDecoration(
                color: highlighted
                    ? colorScheme.primary.withValues(alpha: 0.08)
                    : null,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
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
  final VoidCallback onTap;

  const RuleEntryRow({
    super.key,
    required this.parent,
    required this.position,
    required this.text,
    required this.last,
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
            color: _childFillOf(context),
            shape: RoundedSuperellipseBorder(
              borderRadius: _cornersOf(first: false, last: last),
            ),
          ),
          foregroundDecoration: BoxDecoration(
            border: _separatorOf(context, last),
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
