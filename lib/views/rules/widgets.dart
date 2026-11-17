import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'rules_logic.dart';

/// The fixed colors of the rules page, as the design gives them for light
/// mode; dark mode keeps their hue on a dimmed fill.
enum RuleTone {
  blue(Color(0xFFE8F0FE), Color(0xFF0B57D0)),
  purple(Color(0xFFEDE7F6), Color(0xFF5B3AA6)),
  amber(Color(0xFFFFF1DD), Color(0xFF8A5300)),
  scriptRed(Color(0xFFFCE8E6), Color(0xFFA1271C)),
  red(Color(0xFFFDECEA), Color(0xFF8C1D18)),
  green(Color(0xFFE8F5EC), Color(0xFF16632C)),
  warning(Color(0xFFFFF4E5), Color(0xFF6B4100)),
  gray(Color(0xFFF2F1F5), Color(0xFF3F3E45));

  final Color fill;
  final Color ink;

  const RuleTone(this.fill, this.ink);

  ({Color fill, Color ink}) of(BuildContext context) {
    if (context.colorScheme.brightness == Brightness.light) {
      return (fill: fill, ink: ink);
    }
    return (
      fill: ink.withValues(alpha: 0.28),
      ink: Color.lerp(ink, const Color(0xFFFFFFFF), 0.6)!,
    );
  }
}

/// The source a rule badge names; null when the page cannot tell.
({String label, RuleTone tone})? ruleSourceBadge(
  BuildContext context,
  CoreRule rule,
  RuleSource? source, {
  bool named = true,
}) {
  final appLocalizations = context.appLocalizations;
  // A rule set's name is in the rule's text already; a script's or a
  // module's is not, so it shows wherever the source does.
  String withName(String label, String name, {bool always = false}) =>
      (named || always) && name.isNotEmpty ? '$label · $name' : label;
  if (rule.managed) {
    return (label: appLocalizations.ruleSourceManaged, tone: RuleTone.gray);
  }
  final ruleSet = rule.ruleSet;
  if (ruleSet != null) {
    return (
      label: withName(appLocalizations.ruleSet, ruleSet.name),
      tone: RuleTone.purple,
    );
  }
  if (source == null) return null;
  return switch (source.kind) {
    RuleSourceKind.subscription => (
      label: appLocalizations.ruleSourceSubscription,
      tone: RuleTone.blue,
    ),
    RuleSourceKind.custom => (
      label: appLocalizations.ruleSourceCustom,
      tone: RuleTone.blue,
    ),
    RuleSourceKind.addedProfile || RuleSourceKind.addedGlobal => (
      label: appLocalizations.ruleSourceAdded,
      tone: RuleTone.amber,
    ),
    RuleSourceKind.script => (
      label: withName(
        appLocalizations.ruleSourceScript,
        source.name,
        always: true,
      ),
      tone: RuleTone.scriptRed,
    ),
    RuleSourceKind.mitm => (
      label: withName(
        appLocalizations.ruleSourceMitm,
        source.name,
        always: true,
      ),
      tone: RuleTone.scriptRed,
    ),
  };
}

class RuleBadge extends StatelessWidget {
  final String label;
  final RuleTone tone;
  final bool solid;

  const RuleBadge({
    super.key,
    required this.label,
    required this.tone,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = tone.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: ShapeDecoration(
        color: solid ? colors.ink : colors.fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.caption1
              .of(context, emphasized: true)
              .copyWith(color: solid ? colors.fill : colors.ink),
        ),
      ),
    );
  }
}

/// A tag on a rule row: the rule that was taken, or why another was not.
class RuleTag extends StatelessWidget {
  final String label;
  final Color fill;
  final Color ink;

  const RuleTag({
    super.key,
    required this.label,
    required this.fill,
    required this.ink,
  });

  factory RuleTag.primary(BuildContext context, String label) => RuleTag(
    label: label,
    fill: context.colorScheme.primary,
    ink: context.colorScheme.onPrimary,
  );

  factory RuleTag.gray(BuildContext context, String label) {
    final colors = RuleTone.gray.of(context);
    return RuleTag(label: label, fill: colors.fill, ink: colors.ink);
  }

  factory RuleTag.tone(BuildContext context, String label, RuleTone tone) {
    final colors = tone.of(context);
    return RuleTag(label: label, fill: colors.fill, ink: colors.ink);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyle.caption1
            .of(context, emphasized: true)
            .copyWith(color: ink),
      ),
    );
  }
}

/// [text] with its emoji set in the app's emoji font, for text that cannot
/// be an [EmojiText], such as selectable text.
TextSpan emojiSpanOf(BuildContext context, String text, TextStyle style) {
  final emojiFont = EmojiFont.of(context);
  if (emojiFont == null) return TextSpan(text: text, style: style);
  final spans = <TextSpan>[];
  var end = 0;
  for (final match in emojiFont.pattern.allMatches(text)) {
    if (match.start > end) {
      spans.add(TextSpan(text: text.substring(end, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: TextStyle(fontFamily: emojiFont.family),
      ),
    );
    end = match.end;
  }
  if (end < text.length) spans.add(TextSpan(text: text.substring(end)));
  return TextSpan(style: style, children: spans);
}

/// A rule's text in monospace on its own fill.
class RuleCode extends StatelessWidget {
  final String text;
  final bool selectable;

  const RuleCode(this.text, {super.key, this.selectable = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final style = AppTextStyle.footnote
        .of(context)
        .toJetBrainsMono
        .copyWith(color: colorScheme.onSurface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: colorScheme.brightness == Brightness.light
            ? const Color(0xFFF6F5F8)
            : colorScheme.surfaceContainerHighest,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: selectable
          ? IntrinsicWidth(
              child: SelectableText.rich(emojiSpanOf(context, text, style)),
            )
          : EmojiText(text, style: style),
    );
  }
}

/// A notice above the results: a warning, a note, an error or a success.
class RulesNotice extends StatelessWidget {
  final RuleTone tone;
  final Glyph glyph;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const RulesNotice({
    super.key,
    required this.tone,
    required this.glyph,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = tone.of(context);
    final action = actionLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(
        color: colors.fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          GlyphIcon(glyph, size: 18, color: colors.ink),
          Expanded(
            child: Text(
              text,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colors.ink),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  action,
                  style: AppTextStyle.footnote
                      .of(context, emphasized: true)
                      .copyWith(color: colors.ink),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A group or node in a route, as the design's chips show them.
class RouteChip extends StatelessWidget {
  final String label;
  final RuleTone tone;
  final double height;

  const RouteChip({
    super.key,
    required this.label,
    this.tone = RuleTone.gray,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    final colors = tone.of(context);
    final small = height < 28;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12),
      decoration: ShapeDecoration(
        color: colors.fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
      child: Align(
        widthFactor: 1,
        child: EmojiText(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (small
                      ? AppTextStyle.footnote.of(context, emphasized: true)
                      : AppTextStyle.custom(
                          context,
                          size: 14,
                          leading: 19,
                          weight: FontWeight.w600,
                        ))
                  .copyWith(color: colors.ink),
        ),
      ),
    );
  }
}

/// A single-choice chip of the filter rows, with its count.
class RulesFilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onPressed;
  final Widget? trailing;

  const RulesFilterChip({
    super.key,
    required this.label,
    this.count,
    required this.selected,
    required this.onPressed,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final ink = selected ? colorScheme.onPrimary : colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: ShapeDecoration(
              color: selected
                  ? colorScheme.primary
                  : context.raisedSurfaceLevel.colorOf(colorScheme),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(14),
                side: selected
                    ? BorderSide.none
                    : BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(
                  label,
                  style: AppTextStyle.footnote
                      .of(context, emphasized: selected)
                      .copyWith(color: ink),
                ),
                if (count != null)
                  Text(
                    groupedCount(count!),
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(
                          color: selected
                              ? colorScheme.onPrimary.withValues(alpha: 0.8)
                              : colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
