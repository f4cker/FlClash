import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Below this width the retry moves under the message, so neither is cut.
const _stackedBelowWidth = 440.0;

/// Says [message] to a screen reader once, for a read entering failure or
/// recovering; a poll that keeps failing says nothing more.
void announceReadState(BuildContext context, String message) {
  unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
  );
}

/// The retry label, standing in place while [busy]: both labels take the same
/// room, so the button keeps its width.
class RetryLabel extends StatelessWidget {
  const RetryLabel({super.key, required this.busy, this.color});

  final bool busy;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return IndexedStack(
      index: busy ? 1 : 0,
      alignment: Alignment.center,
      sizing: StackFit.loose,
      children: [
        Text(appLocalizations.retry),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            // Only spun while shown; hidden, it just keeps the room.
            if (busy)
              // The button's own label color, which a filled one inverts.
              ActivityIndicator(
                size: 14,
                color: color ?? DefaultTextStyle.of(context).style.color,
              )
            else
              const SizedBox.square(dimension: 14),
            Text(appLocalizations.retrying),
          ],
        ),
      ],
    );
  }
}

/// Retry, busy in place while [busy]: taps then go nowhere. It stays enabled
/// underneath, since disabling a button mid-press rebuilds it under itself.
class RetryButton extends StatelessWidget {
  const RetryButton({
    super.key,
    required this.busy,
    required this.onRetry,
    this.filled = false,
    this.style,
    this.color,
  });

  final bool busy;
  final VoidCallback onRetry;

  /// The primary action of a page with nothing else on it.
  final bool filled;
  final ButtonStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    void onPressed() {
      if (!busy) onRetry();
    }

    final label = RetryLabel(busy: busy, color: color);
    return IgnorePointer(
      ignoring: busy,
      child: filled
          ? FilledButton(onPressed: onPressed, style: style, child: label)
          : TextButton(onPressed: onPressed, style: style, child: label),
    );
  }
}

/// A read that failed while what it read last stays on screen: a message
/// with a retry, over that content and taking its own room.
class ReadFailureBanner extends StatelessWidget {
  const ReadFailureBanner({
    super.key,
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final String message;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final foreground = colorScheme.onErrorContainer;
    final style = AppTextStyle.footnote.of(context).copyWith(color: foreground);
    final retry = RetryButton(
      busy: retrying,
      onRetry: onRetry,
      color: foreground,
      style: ButtonStyle.from(
        foregroundColor: foreground,
        minimumSize: const Size(0, 32),
      ),
    );
    final text = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: GlyphIcon(AppGlyphs.error, size: 16, color: foreground),
        ),
        Expanded(child: Text(message, style: style)),
      ],
    );
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colorScheme.errorContainer,
          shape: AppShape.all(AppCorner.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < _stackedBelowWidth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    text,
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: retry,
                    ),
                  ],
                );
              }
              return Row(
                spacing: 10,
                children: [
                  Expanded(child: text),
                  retry,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Puts [banner] between the app bar and [child], in room of its own; without
/// one, [child] runs under the bar as before. [child] keeps its state either
/// way, its scroll position included.
class ReadFailureFrame extends StatefulWidget {
  const ReadFailureFrame({super.key, this.banner, required this.child});

  final Widget? banner;
  final Widget child;

  @override
  State<ReadFailureFrame> createState() => _ReadFailureFrameState();
}

class _ReadFailureFrameState extends State<ReadFailureFrame> {
  final _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _childKey, child: widget.child);
    final banner = widget.banner;
    if (banner == null) {
      return child;
    }
    return Padding(
      padding: EdgeInsets.only(top: context.contentTopPadding),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: FloatingBarScope(
          inset: 0,
          child: TopInsetScope(
            inset: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: banner,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
