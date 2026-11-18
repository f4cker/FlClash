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
  // #7A4FD6 at 12% on white.
  module(Color(0xFFEFEAFA), Color(0xFF5B36B0)),
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

  /// The fill of a source badge: opaque, and a shade deeper than [fill], so
  /// a badge reads the same on a plain row and on the highlighted one.
  Color badgeFillOf(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (colorScheme.brightness == Brightness.light) {
      return this == module ? fill : Color.lerp(fill, ink, 0.1)!;
    }
    return Color.alphaBlend(
      ink.withValues(alpha: 0.32),
      context.raisedSurfaceLevel.colorOf(colorScheme),
    );
  }
}

/// The longest name a badge or chip shows before it cuts the rest off.
const sourceNameLimit = 16;

/// [name] cut to [sourceNameLimit] characters, an ellipsis after the cut.
String shortSourceName(String name) {
  final characters = name.characters;
  if (characters.length <= sourceNameLimit) return name;
  return '${characters.take(sourceNameLimit)}…';
}

/// [label] with the name of the source it is, the name cut short; [full]
/// is the whole label, for a tooltip, when the name was cut.
({String label, String? full}) namedSourceLabel(String label, String name) {
  if (name.isEmpty) return (label: label, full: null);
  final short = shortSourceName(name);
  return (
    label: '$label · $short',
    full: short == name ? null : '$label · $name',
  );
}

/// The source a rule badge names, with the name of which one it is: the
/// profile, the rule set, the script or the module; null when the page
/// cannot tell. [profile] is the name of the profile the rules run from.
({String label, RuleTone tone, String? full})? ruleSourceBadge(
  BuildContext context,
  CoreRule rule,
  RuleSource? source, {
  String profile = '',
}) {
  final appLocalizations = context.appLocalizations;
  ({String label, RuleTone tone, String? full}) named(
    String label,
    String name,
    RuleTone tone,
  ) {
    final named = namedSourceLabel(label, name);
    return (label: named.label, tone: tone, full: named.full);
  }

  if (rule.managed) {
    return named(appLocalizations.ruleSourceManaged, '', RuleTone.gray);
  }
  final ruleSet = rule.ruleSet;
  final added =
      source?.kind == RuleSourceKind.addedProfile ||
      source?.kind == RuleSourceKind.addedGlobal;
  if (ruleSet != null && added) {
    // A set renamed past one of the profile's shows the name it was given.
    final name = ruleSet.name.startsWith(addedRuleSetPrefix)
        ? ruleSet.name.substring(addedRuleSetPrefix.length)
        : ruleSet.name;
    return named(appLocalizations.ruleSourceAddedSet, name, RuleTone.amber);
  }
  if (ruleSet != null) {
    return named(appLocalizations.ruleSet, ruleSet.name, RuleTone.purple);
  }
  if (source == null) return null;
  return switch (source.kind) {
    RuleSourceKind.subscription => named(
      appLocalizations.ruleSourceSubscription,
      profile,
      RuleTone.blue,
    ),
    RuleSourceKind.custom => named(
      appLocalizations.ruleSourceCustom,
      profile,
      RuleTone.blue,
    ),
    RuleSourceKind.addedProfile => named(
      appLocalizations.ruleSourceAdded,
      profile,
      RuleTone.amber,
    ),
    // Kept for every profile, so no one profile's name fits it.
    RuleSourceKind.addedGlobal => named(
      appLocalizations.ruleSourceAdded,
      '',
      RuleTone.amber,
    ),
    RuleSourceKind.script => named(
      appLocalizations.ruleSourceScript,
      source.name,
      RuleTone.scriptRed,
    ),
    RuleSourceKind.mitm => named(
      appLocalizations.ruleSourceMitm,
      source.name,
      RuleTone.module,
    ),
  };
}

class RuleBadge extends StatelessWidget {
  final String label;
  final RuleTone tone;
  final bool solid;

  /// The whole label, on hover, when [label] cuts a name short.
  final String? tooltip;

  const RuleBadge({
    super.key,
    required this.label,
    required this.tone,
    this.solid = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = this.tooltip;
    final badge = _buildBadge(context);
    return tooltip == null ? badge : Tooltip(message: tooltip, child: badge);
  }

  Widget _buildBadge(BuildContext context) {
    final colors = tone.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: ShapeDecoration(
        color: solid ? colors.ink : tone.badgeFillOf(context),
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
              .copyWith(color: solid ? tone.badgeFillOf(context) : colors.ink),
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

  /// The whole label, on hover, when [label] cuts a name short.
  final String? tooltip;

  const RulesFilterChip({
    super.key,
    required this.label,
    this.count,
    required this.selected,
    required this.onPressed,
    this.trailing,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = this.tooltip;
    final chip = _buildChip(context);
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }

  Widget _buildChip(BuildContext context) {
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
                // A chip wider than a narrow window cuts its label, never
                // its count.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.footnote
                        .of(context, emphasized: selected)
                        .copyWith(color: ink),
                  ),
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
