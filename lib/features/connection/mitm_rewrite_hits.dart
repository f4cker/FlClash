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
    // A skip from an error is a failure; one for what the message is (too
    // big, not text, still streaming) is a rewrite not applied.
    final failed = hits.where(_isFailure).firstOrNull;
    final notApplied = hits
        .where((hit) => hit.skipped.isNotEmpty && !_isFailure(hit))
        .firstOrNull;
    final applied = hits.where((hit) => hit.skipped.isEmpty).length;
    // Applied is said once the request is over with no error; until then a
    // rule has only matched.
    final settled = !exchange.pending && exchange.error.isEmpty;
    final skipped = failed ?? (applied == 0 ? notApplied : null);
    final badge = skipped != null
        ? MitmRewriteBadge.failed
        : MitmRewriteBadge.applied;
    final color = badge.color(context);
    final secondary = context.colorScheme.onSurfaceVariant;
    final footnote = AppTextStyle.footnote.of(context);
    final String title;
    if (failed != null) {
      title = l.mitmRewriteFailedTitle(mitmRewriteSkipText(l, failed.skipped));
    } else if (skipped != null) {
      title = l.mitmRewriteNotAppliedTitle(
        mitmRewriteSkipText(l, skipped.skipped),
      );
    } else {
      title = settled ? l.mitmRewriteAppliedTitle : l.mitmRewriteMatchedTitle;
    }
    // "Passed on unchanged" only when no rule changed the request and it is
    // over with no error: before then, or after one, it is not known. The
    // rule itself is in its row below, said once.
    final passedThrough = applied == 0 && skipped != null && settled;
    final header = ListItem(
      leading: GlyphIcon(badge.glyph, size: 18, color: color),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: AppTextStyle.body
                  .of(context, emphasized: true)
                  .copyWith(color: skipped != null ? color : null),
            ),
            if (skipped == null)
              TextSpan(
                text: ' · ${l.mitmRewriteHitCount(hits.length)}',
                style: TextStyle(color: secondary),
              ),
          ],
        ),
      ),
      subtitle: passedThrough ? Text(l.mitmRewritePassedThrough) : null,
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

bool _isFailure(MitmAction hit) => switch (hit.skipped) {
  'decodeFailed' || 'regexTimeout' || 'bodyReadFailed' || 'invalidURL' => true,
  _ => false,
};

/// How long an applied rule took, as the detail ends its result with; null
/// when the Core did not measure it, never a zero.
String? mitmRewriteTookText(MitmAction hit) {
  if (hit.skipped.isNotEmpty || hit.tookNs <= 0) return null;
  final ms = hit.tookNs / 1e6;
  if (ms < 0.1) return '<0.1\u00a0ms';
  return ms < 10 ? '${ms.toStringAsFixed(1)}\u00a0ms' : '${ms.round()}\u00a0ms';
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
                // The result, its time, and the way to the rule share one
                // line: the result gives way, the button never wraps.
                if (result.isNotEmpty ||
                    rule != null ||
                    mitmRewriteTookText(hit) != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          [
                            result,
                            ?mitmRewriteTookText(hit),
                          ].where((part) => part.isNotEmpty).join('\u00a0· '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: footnote.copyWith(
                            color: hit.skipped.isNotEmpty
                                ? MitmRewriteBadge.failed.color(context)
                                : typeStyle.color,
                          ),
                        ),
                      ),
                      if (rule != null)
                        TextButton(
                          onPressed: () => _reveal(context, rule),
                          child: Text(
                            l.mitmRewriteViewInList,
                            maxLines: 1,
                            style: footnote.copyWith(
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
