import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'state.dart';

enum TailscaleBannerLevel { info, warn, error }

/// A dashboard card whose content scopes to the card level, so a tonal
/// button or a block inside steps away from it.
class TailscaleCard extends StatelessWidget {
  const TailscaleCard({super.key, this.padding, required this.child});

  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: padding,
      child: SurfaceScope(level: SurfaceLevel.card, child: child),
    );
  }
}

/// A state message inside a card, design.md §3.1.
class TailscaleBanner extends StatelessWidget {
  const TailscaleBanner({
    super.key,
    required this.level,
    required this.text,
    this.title,
    this.glyph,
    this.actionLabel,
    this.onAction,
  });

  final TailscaleBannerLevel level;
  final String text;

  /// An emphasized line above [text].
  final String? title;
  final Glyph? glyph;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (fill, foreground) = switch (level) {
      TailscaleBannerLevel.info => (
        DashboardColors.of(context).tone,
        colorScheme.onSurface,
      ),
      TailscaleBannerLevel.warn => (
        colorScheme.warningContainer,
        colorScheme.onWarningContainer,
      ),
      TailscaleBannerLevel.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };
    final glyph =
        this.glyph ??
        switch (level) {
          TailscaleBannerLevel.info => AppGlyphs.info,
          TailscaleBannerLevel.warn => AppGlyphs.warning,
          TailscaleBannerLevel.error => AppGlyphs.error,
        };
    final actionLabel = this.actionLabel;
    final title = this.title;
    final style = AppTextStyle.footnote.of(context).copyWith(color: foreground);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: AppShape.all(AppCorner.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          spacing: 10,
          children: [
            GlyphIcon(glyph, size: 16, color: foreground),
            Expanded(
              child: title == null
                  ? Text(text, style: style)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          title,
                          style: AppTextStyle.footnote
                              .of(context, emphasized: true)
                              .copyWith(color: foreground),
                        ),
                        Text(text, style: style),
                      ],
                    ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: ButtonStyle.from(
                  foregroundColor: foreground,
                  minimumSize: const Size(0, 32),
                ),
                child: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}

/// A label over a value, one item of the device card's meta row.
class TailscaleMetaItem extends StatelessWidget {
  const TailscaleMetaItem({
    super.key,
    required this.label,
    required this.value,
    this.leading,
    this.tooltip,
    this.muted = false,
  });

  final String label;
  final String value;
  final Widget? leading;
  final String? tooltip;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final leading = this.leading;
    final tooltip = this.tooltip;
    Widget text = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.subheadline
          .of(context, emphasized: !muted)
          .copyWith(
            color: muted ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
          ),
    );
    if (tooltip != null) {
      text = Tooltip(message: tooltip, child: text);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(label, style: DashboardText.label(context)),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            ?leading,
            Flexible(child: text),
          ],
        ),
      ],
    );
  }
}

/// The inset tag after a name: 可作出口节点, 面板添加, or a conflict in the
/// warning colours, its text never colour-only.
class TailscaleTag extends StatelessWidget {
  const TailscaleTag({super.key, required this.label, this.warn = false});

  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: ShapeDecoration(
        color: warn
            ? colorScheme.warningContainer
            : DashboardColors.of(context).tone,
        shape: AppShape.all(AppCorner.full),
      ),
      // As wide as its label, also in a Wrap that offers the full row.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: AppTextStyle.caption2
              .of(context, emphasized: true)
              .copyWith(
                color: warn
                    ? colorScheme.onWarningContainer
                    : colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

/// An identity mark: the profile picture, or the first letter on a fill.
class TailscaleAvatar extends StatelessWidget {
  const TailscaleAvatar({
    super.key,
    required this.name,
    this.pictureUrl = '',
    this.isMe = false,
    this.size = 20,
  });

  final String name;
  final String pictureUrl;
  final bool isMe;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (fill, foreground) = isMe
        ? (colorScheme.primary, colorScheme.onPrimary)
        : (DashboardColors.of(context).tone2, colorScheme.onSurfaceVariant);
    final letter = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    final fallback = DecoratedBox(
      decoration: ShapeDecoration(color: fill, shape: AppShape.circle),
      child: Center(
        child: Text(
          letter,
          style: AppTextStyle.custom(
            context,
            size: size * 0.5,
            leading: size * 0.6,
            weight: FontWeight.w600,
          ).copyWith(color: foreground),
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: pictureUrl.isEmpty
            ? fallback
            : ClipOval(
                child: ImageCacheWidget(
                  src: pictureUrl,
                  defaultWidget: fallback,
                  logsSource: false,
                ),
              ),
      ),
    );
  }
}

/// The avatar of an entry no account has signed in to yet.
class TailscaleNewAccountAvatar extends StatelessWidget {
  const TailscaleNewAccountAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: DashboardColors.of(context).tone2,
        shape: AppShape.circle,
      ),
      child: GlyphIcon(
        AppGlyphs.add,
        size: 14,
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The account switcher's target, design.md §13.1: avatar, account, state
/// and a dot in the state's colour.
class TailscaleAccountPill extends StatelessWidget {
  const TailscaleAccountPill({
    super.key,
    required this.account,
    required this.tone,
    required this.semanticsLabel,
    required this.onPressed,
    this.state,
    this.newAccount = false,
  });

  final String account;
  final String? state;
  final DashboardChipTone tone;
  final bool newAccount;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final dot = switch (tone) {
      DashboardChipTone.ok => colors.ok,
      DashboardChipTone.warn => colors.warn,
      DashboardChipTone.error => colorScheme.error,
      DashboardChipTone.idle => colorScheme.outline,
    };
    // A narrow bar keeps the dot and drops the state text, design.md §13.1.
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final state = narrow ? null : this.state;
    final shape = AppShape.all(AppCorner.full);
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.card,
          shape: shape,
          shadows: DashboardShadows.e1(context),
        ),
        child: PressSurface(
          fill: colors.card,
          shape: shape,
          onPressed: onPressed,
          padding: const EdgeInsets.only(left: 8, right: 12),
          child: SizedBox(
            height: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                if (newAccount)
                  const TailscaleNewAccountAvatar()
                else
                  TailscaleAvatar(name: account),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: narrow ? 140 : 240),
                  child: Text(
                    account,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.subheadline.of(
                      context,
                      emphasized: true,
                    ),
                  ),
                ),
                if (state != null)
                  Text(
                    '· $state',
                    maxLines: 1,
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: dot,
                    shape: AppShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 7),
                ),
                GlyphIcon(
                  AppGlyphs.chevronDown,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String tailscaleUserName(TailscaleUser user) =>
    user.loginName.isNotEmpty ? user.loginName : user.displayName;

/// The display name and the login name, as a tooltip and screen reader read
/// them.
String tailscaleUserDescription(TailscaleUser user) => [
  if (user.displayName.isNotEmpty) user.displayName,
  if (user.loginName.isNotEmpty && user.loginName != user.displayName)
    user.loginName,
].join(' · ');

/// A busy button keeps its width and swaps its glyph for a spinner.
Widget tailscaleBusyIcon(BuildContext context, {Color? color}) =>
    SizedBox.square(
      dimension: 16,
      child: ActivityIndicator(size: 16, color: color),
    );

String tailscaleDeviceName(BuildContext context, TailscalePeer peer) =>
    tailscalePeerName(peer) ?? context.appLocalizations.tsNameMissing;

/// A date and time without locale data, as 2026-11-14 12:00.
String tailscaleDateTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
