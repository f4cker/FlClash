import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'add_rule_dialog.dart';
import 'widgets.dart';

/// The route a lookup ends on, group by group to the node, as chips; DIRECT
/// and REJECT read in words.
List<Widget> routeChips(
  BuildContext context,
  List<String> hops, {
  double height = 28,
}) {
  final colorScheme = context.colorScheme;
  final arrowStyle = AppTextStyle.title3
      .of(context)
      .copyWith(color: colorScheme.onSurfaceVariant);
  return [
    for (final (index, hop) in hops.indexed) ...[
      if (index > 0) Text('→', style: arrowStyle),
      RouteChip(
        height: height,
        label: ruleTargetLabel(context, hop),
        tone: switch (hop.toUpperCase()) {
          'DIRECT' => RuleTone.gray,
          'REJECT' || 'REJECT-DROP' => RuleTone.red,
          _ when index == hops.length - 1 && hops.length > 1 => RuleTone.green,
          _ => RuleTone.gray,
        },
      ),
    ],
  ];
}

/// What a lookup says of the rules before the winner it cannot decide, one
/// line for each kind of condition.
List<String> uncertainNotes(BuildContext context, RuleLookup lookup) {
  final appLocalizations = context.appLocalizations;
  final counts = <String, int>{};
  for (final hit in lookup.uncertain) {
    if (hit.reason == 'rematch') continue;
    final kind = switch (hit.reason) {
      'process' || 'uid' => 'process',
      'port' => 'port',
      'ip' => 'ip',
      _ => 'other',
    };
    counts.update(kind, (count) => count + 1, ifAbsent: () => 1);
  }
  return [
    if (counts['process'] case final count?)
      appLocalizations.uncertainProcess(count),
    if (counts['port'] case final count?) appLocalizations.uncertainPort(count),
    if (counts['ip'] case final count?) appLocalizations.uncertainIp(count),
    if (counts['other'] case final count?)
      appLocalizations.uncertainOther(count),
  ];
}

/// The card of the rule a lookup found the host takes.
class RuleHitCard extends StatelessWidget {
  final RuleLookup lookup;
  final RuleSource? source;
  final bool justAdded;
  final VoidCallback? onChangeNode;
  final VoidCallback onAddRule;
  final VoidCallback onCopyRule;

  const RuleHitCard({
    super.key,
    required this.lookup,
    required this.source,
    this.justAdded = false,
    this.onChangeNode,
    required this.onAddRule,
    required this.onCopyRule,
  });

  List<String> get _hops {
    final chain = [for (final hop in lookup.chain) hop.name];
    if (chain.isNotEmpty) return chain;
    final target = lookup.winner?.target ?? '';
    return target.isEmpty ? const ['DIRECT'] : [target];
  }

  Widget _detailRow(BuildContext context, String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final winner = lookup.winner;
    final uncertain = lookup.uncertain.isNotEmpty;
    final fallback = winner?.type == 'MATCH';
    final hops = _hops;
    final caption = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final tabular = caption.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final conclusion = AppTextStyle.title3.of(context, emphasized: true);
    final badge = winner == null
        ? null
        : ruleSourceBadge(context, winner.rule, source);
    final ruleSet = winner?.ruleSet;
    final notes = uncertainNotes(context, lookup);
    final group = winner?.target ?? '';
    final semantics = winner == null
        ? null
        : [
            if (uncertain) appLocalizations.uncertainPrefix,
            appLocalizations.hitSemantics(
              winner.index + 1,
              winner.rule.text,
              badge?.label ?? '',
              ruleTargetLabel(context, group),
              ruleTargetLabel(context, hops.last),
            ),
          ].join('，');
    return Semantics(
      container: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: ShapeDecoration(
          color: context.raisedSurfaceLevel.colorOf(colorScheme),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              width: 1.5,
              color: uncertain
                  ? const Color(0xFFE2B97F)
                  : colorScheme.primary.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    uncertain
                        ? appLocalizations.hitCardTitleUncertain
                        : appLocalizations.hitCardTitle,
                    style: AppTextStyle.footnote
                        .of(context, emphasized: true)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                if (winner != null)
                  Text(
                    fallback
                        ? appLocalizations.hitCardLast
                        : appLocalizations.hitCardPosition(
                            winner.index + 1,
                            lookup.total,
                          ),
                    style: tabular,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  winner == null
                      ? appLocalizations.hitNoRule
                      : fallback
                      ? '${appLocalizations.hitFallback} ${appLocalizations.hitGoes}'
                      : appLocalizations.hitGoes,
                  style: conclusion,
                ),
                ...routeChips(context, hops),
              ],
            ),
            if (lookup.undetermined == 'rematch') ...[
              const SizedBox(height: 10),
              Text(
                appLocalizations.hitRematch,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (winner != null) ...[
              const SizedBox(height: 14),
              _detailRow(
                context,
                appLocalizations.hitRuleLabel,
                RuleCode(winner.rule.text, selectable: true),
              ),
              if (winner.entry.isNotEmpty) ...[
                const SizedBox(height: 6),
                _detailRow(
                  context,
                  appLocalizations.hitEntryLabel,
                  RuleCode(winner.entry, selectable: true),
                ),
              ],
              if (badge != null) ...[
                const SizedBox(height: 6),
                _detailRow(
                  context,
                  appLocalizations.hitFromLabel,
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RuleBadge(label: badge.label, tone: badge.tone),
                      if (ruleSet?.loadedAt case final loaded?)
                        Text(
                          appLocalizations.ruleUpdatedAt(
                            loaded.getLastUpdateTimeDesc(context),
                          ),
                          style: caption,
                        )
                      else if (justAdded)
                        Text(appLocalizations.ruleJustAdded, style: caption),
                    ],
                  ),
                ),
              ],
            ],
            for (final note in notes) ...[
              const SizedBox(height: 12),
              RulesNotice(
                tone: RuleTone.warning,
                glyph: AppGlyphs.warning,
                text: note,
              ),
            ],
            if (winner != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onChangeNode != null)
                    _CardButton(
                      label: appLocalizations.changeNode,
                      fill: colorScheme.primary.withValues(alpha: 0.12),
                      ink: colorScheme.primary,
                      onPressed: onChangeNode!,
                    ),
                  _CardButton(
                    label: appLocalizations.addAddedRule,
                    fill: context.raisedSurfaceLevel.colorOf(colorScheme),
                    ink: colorScheme.onSurface,
                    border: colorScheme.outlineVariant,
                    onPressed: onAddRule,
                  ),
                  _CardButton(
                    label: appLocalizations.copyRule,
                    ink: colorScheme.primary,
                    onPressed: onCopyRule,
                  ),
                ],
              ),
            ] else if (lookup.mode == 'rule' || lookup.mode.isEmpty) ...[
              const SizedBox(height: 14),
              _CardButton(
                label: appLocalizations.addAddedRule,
                fill: context.raisedSurfaceLevel.colorOf(colorScheme),
                ink: colorScheme.onSurface,
                border: colorScheme.outlineVariant,
                onPressed: onAddRule,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final Color? fill;
  final Color ink;
  final Color? border;
  final VoidCallback onPressed;

  const _CardButton({
    required this.label,
    this.fill,
    required this.ink,
    this.border,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 32,
            padding: EdgeInsets.symmetric(horizontal: fill == null ? 4 : 14),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: fill,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(8),
                side: border == null
                    ? BorderSide.none
                    : BorderSide(color: border!),
              ),
            ),
            child: Text(
              label,
              style: AppTextStyle.footnote
                  .of(context, emphasized: true)
                  .copyWith(color: ink),
            ),
          ),
        ),
      ),
    );
  }
}
