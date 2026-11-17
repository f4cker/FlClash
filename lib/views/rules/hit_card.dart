import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'add_rule_dialog.dart';
import 'rules_logic.dart';
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

/// The one line a lookup says of the rules before the winner it cannot
/// decide: the kinds of information it lacks, listed together; the general
/// wording only when it knows none of them. Null when it decides them all.
String? uncertainNote(BuildContext context, RuleLookup lookup) {
  final appLocalizations = context.appLocalizations;
  final hits = undecidedHits(lookup);
  if (hits.isEmpty) return null;
  final reasons = {for (final hit in hits) hit.reason};
  final kinds = [
    if (reasons.contains('process') || reasons.contains('uid'))
      appLocalizations.uncertainKindApp,
    if (reasons.contains('port')) appLocalizations.uncertainKindPort,
    if (reasons.contains('ip')) appLocalizations.uncertainKindIp,
  ];
  if (kinds.isEmpty) return appLocalizations.uncertainOther;
  final listed = kinds.length == 1
      ? kinds.single
      : '${kinds.take(kinds.length - 1).join(appLocalizations.uncertainKindSeparator)}'
            '${appLocalizations.uncertainKindLastSeparator}${kinds.last}';
  return spaceCjkLatin(appLocalizations.uncertainKinds(listed));
}

/// The rules before the winner a lookup cannot decide, in rule order.
List<RuleHit> undecidedHits(RuleLookup lookup) => [
  for (final hit in lookup.uncertain)
    if (hit.reason != 'rematch') hit,
]..sort((a, b) => a.index.compareTo(b.index));

final _cjkThenLatin = RegExp(r'([\u3400-\u9fff])([A-Za-z0-9])');
final _latinThenCjk = RegExp(r'([A-Za-z0-9])([\u3400-\u9fff])');

/// [text] with a space wherever Chinese meets a Latin letter or digit, as
/// the copy sets them.
String spaceCjkLatin(String text) => text
    .replaceAllMapped(_cjkThenLatin, (m) => '${m[1]} ${m[2]}')
    .replaceAllMapped(_latinThenCjk, (m) => '${m[1]} ${m[2]}');

/// The card of the rule a lookup found the host takes.
class RuleHitCard extends StatelessWidget {
  static const uncertainKey = ValueKey('rules-hit-uncertain');

  final RuleLookup lookup;
  final RuleSource? source;
  final bool justAdded;

  /// False while the Core is stopped: the card dims and its actions rest.
  final bool enabled;

  /// True in global or direct mode, where rules do not route traffic.
  final bool rulesIdle;
  final VoidCallback? onChangeNode;
  final VoidCallback onAddRule;
  final VoidCallback onCopyRule;

  /// The name of the profile the rules run from, for the source badge.
  final String profile;

  const RuleHitCard({
    super.key,
    required this.lookup,
    required this.source,
    this.justAdded = false,
    this.enabled = true,
    this.rulesIdle = false,
    this.onChangeNode,
    required this.onAddRule,
    required this.onCopyRule,
    this.profile = '',
  });

  List<String> get _hops {
    final chain = [for (final hop in lookup.chain) hop.name];
    if (chain.isNotEmpty) return chain;
    final target = lookup.winner?.target ?? '';
    return target.isEmpty ? const ['DIRECT'] : [target];
  }

  /// The width of the detail labels: the widest of them, and a gap.
  double _labelWidth(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final style = AppTextStyle.caption1.of(context);
    var width = 0.0;
    for (final label in [
      appLocalizations.hitRuleLabel,
      appLocalizations.hitEntryLabel,
      appLocalizations.hitFromLabel,
      appLocalizations.hitIpLabel,
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > width) width = painter.width;
      painter.dispose();
    }
    return width.ceilToDouble() + 12;
  }

  /// The amber line under the source: what the lookup could not decide,
  /// the rules it means on hover.
  Widget _buildUncertain(BuildContext context, String note) {
    final ink = RuleTone.amber.of(context).ink;
    final rules = [
      for (final hit in undecidedHits(lookup))
        '#${hit.index + 1} ${hit.rule.text}',
    ].join('\n');
    return Padding(
      key: RuleHitCard.uncertainKey,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Tooltip(
        message: rules,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: GlyphIcon(AppGlyphs.warning, size: 14, color: ink),
            ),
            Expanded(
              child: Text(
                note,
                style: AppTextStyle.caption1.of(context).copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _labelWidth(context),
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
    final uncertain = lookupUncertain(lookup);
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
        : ruleSourceBadge(context, winner.rule, source, profile: profile);
    final ruleSet = winner?.ruleSet;
    final ipNote = switch (lookup.ipSource) {
      'hosts' => appLocalizations.ipSourceHosts,
      'mapping' => appLocalizations.ipSourceMapping,
      _ => null,
    };
    final showIp = lookup.ip.isNotEmpty && lookup.ipSource != 'input';
    final note = uncertainNote(context, lookup);
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
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: ShapeDecoration(
            color: context.raisedSurfaceLevel.colorOf(colorScheme),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                width: 1.5,
                color: rulesIdle
                    ? const Color(0xFFD6D4DA)
                    : uncertain
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
                      appLocalizations.hitCardTitle,
                      style: AppTextStyle.footnote
                          .of(context, emphasized: true)
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (winner != null)
                    Text(
                      appLocalizations.hitCardPosition(
                        groupedCount(winner.index + 1),
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
                        RuleBadge(
                          label: badge.label,
                          tone: badge.tone,
                          tooltip: badge.full,
                        ),
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
                if (note != null) _buildUncertain(context, note),
              ],
              if (showIp) ...[
                const SizedBox(height: 6),
                _detailRow(
                  context,
                  appLocalizations.hitIpLabel,
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: SelectableText(
                      ipNote == null ? lookup.ip : '${lookup.ip} · $ipNote',
                      style: AppTextStyle.footnote.of(context).toJetBrainsMono,
                    ),
                  ),
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
                        onPressed: enabled ? onChangeNode : null,
                      ),
                    _CardButton(
                      label: appLocalizations.addAddedRule,
                      fill: context.raisedSurfaceLevel.colorOf(colorScheme),
                      ink: colorScheme.onSurface,
                      border: colorScheme.outlineVariant,
                      onPressed: enabled ? onAddRule : null,
                    ),
                    _CardButton(
                      label: appLocalizations.copyRule,
                      ink: colorScheme.primary,
                      onPressed: enabled ? onCopyRule : null,
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
                  onPressed: enabled ? onAddRule : null,
                ),
              ],
            ],
          ),
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
  final VoidCallback? onPressed;

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
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: Container(
            height: 32,
            padding: EdgeInsets.symmetric(horizontal: fill == null ? 4 : 14),
            decoration: ShapeDecoration(
              color: fill,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(8),
                side: border == null
                    ? BorderSide.none
                    : BorderSide(color: border!),
              ),
            ),
            child: Align(
              widthFactor: 1,
              child: Text(
                label,
                style: AppTextStyle.footnote
                    .of(context, emphasized: true)
                    .copyWith(color: ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
