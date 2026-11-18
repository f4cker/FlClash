import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/features/mitm/rewrite.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tracker_info_item.dart';

/// What the rewrite rules did to one request: a header that says whether
/// they applied or one matched and failed, then a row for each rule that
/// matched, each opening the rule in the rewrite page.
class MitmRewriteHitsSection extends ConsumerWidget {
  final MitmExchange exchange;

  const MitmRewriteHitsSection({super.key, required this.exchange});

  static const typeWidth = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final hits = [
      for (final hit in exchange.actions)
        if (mitmListOfKey(hit.kind) != null) hit,
    ];
    final profileId = ref.watch(currentProfileIdProvider);
    final rules = {
      if (profileId != null)
        for (final rule
            in ref.watch(profileMitmRewritesProvider(profileId)).value ??
                const <MitmRewrite>[])
          '${rule.id}': rule,
    };
    final failed = hits.where((hit) => hit.skipped.isNotEmpty).firstOrNull;
    final badge = failed != null
        ? MitmRewriteBadge.failed
        : MitmRewriteBadge.applied;
    final color = badge.color(context);
    final secondary = context.colorScheme.onSurfaceVariant;
    final footnote = AppTextStyle.footnote.of(context);
    final failedRule = failed == null ? null : rules[failed.rule];
    // "Passed on unchanged" is said only once the request is over with no
    // error: before then, or after one, it is not known to be so.
    final passedThrough =
        failed != null && !exchange.pending && exchange.error.isEmpty;
    final header = ListItem(
      leading: GlyphIcon(badge.glyph, size: 18, color: color),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: failed != null
                  ? l.mitmRewriteFailedTitle(
                      mitmRewriteSkipText(l, failed.skipped),
                    )
                  : l.mitmRewriteAppliedTitle,
              style: AppTextStyle.body
                  .of(context, emphasized: true)
                  .copyWith(color: failed != null ? color : null),
            ),
            if (failed == null)
              TextSpan(
                text: ' · ${l.mitmRewriteHitCount(hits.length)}',
                style: TextStyle(color: secondary),
              ),
          ],
        ),
      ),
      subtitle: passedThrough
          ? Text(
              [
                l.mitmRewritePassedThrough,
                if (failedRule != null) l.mitmRewriteRuleRef(failedRule.line),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
    );
    return generateSection(
      title: l.mitmRewrite,
      items: [
        header,
        for (final hit in hits)
          _MitmRewriteHitRow(
            hit: hit,
            rule: rules[hit.rule],
            typeStyle: footnote.copyWith(color: secondary),
          ),
      ],
    );
  }
}

class _MitmRewriteHitRow extends StatelessWidget {
  final MitmAction hit;
  final MitmRewrite? rule;
  final TextStyle typeStyle;

  const _MitmRewriteHitRow({
    required this.hit,
    required this.rule,
    required this.typeStyle,
  });

  void _reveal(BuildContext context, MitmRewrite rule) {
    BaseNavigator.push(context, MitmRewriteView(revealRule: rule.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final rule = this.rule;
    final footnote = AppTextStyle.footnote.of(context);
    final mono = footnote.toJetBrainsMono;
    // The type is in the left column, so the result says only what was
    // done; a rule no longer stored has no words for it.
    final description = rule == null
        ? null
        : describeMitmRewrite(l, rule.section, rule.line);
    final result = hit.skipped.isNotEmpty
        ? mitmRewriteSkipText(l, hit.skipped)
        : description == null
        ? ''
        : description.detail.isEmpty
        ? description.action
        : description.detail;
    return ListItem(
      alignment: ListRowAlignment.top,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MitmRewriteHitsSection.typeWidth,
            child: Text(mitmRewriteHitType(l, hit), style: typeStyle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  rule?.line ?? l.mitmRewriteRuleRemoved,
                  style: rule == null ? footnote : mono,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (result.isNotEmpty)
                  Text(
                    result,
                    style: footnote.copyWith(
                      color: hit.skipped.isNotEmpty
                          ? MitmRewriteBadge.failed.color(context)
                          : typeStyle.color,
                    ),
                  ),
                if (rule != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => _reveal(context, rule),
                      child: Text(
                        l.mitmRewriteViewInList,
                        style: footnote.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
