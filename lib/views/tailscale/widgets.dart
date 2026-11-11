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
    this.glyph,
    this.actionLabel,
    this.onAction,
  });

  final TailscaleBannerLevel level;
  final String text;
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
              child: Text(
                text,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: foreground),
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
