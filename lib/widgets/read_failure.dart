import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/rendering.dart';
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
    final colors = ReadFailureBannerColors.of(context.colorScheme);
    final style = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colors.foreground);
    final retry = RetryButton(
      busy: retrying,
      onRetry: onRetry,
      color: colors.action,
      style: ButtonStyle.from(
        foregroundColor: colors.action,
        minimumSize: const Size.square(minRetryTapTarget),
      ),
    );
    final text = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: GlyphIcon(AppGlyphs.error, size: 16, color: colors.icon),
        ),
        Expanded(child: Text(message, style: style)),
      ],
    );
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.background,
          shape: AppShape.all(AppCorner.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: _MessageAndAction(
            stackBelowWidth: _stackedBelowWidth,
            message: text,
            action: retry,
          ),
        ),
      ),
    );
  }
}

/// The smallest side of the banner's retry, so it stays easy to hit.
const minRetryTapTarget = 44.0;

/// The banner's colors. Light keeps the error container; dark sits on the
/// same-level grouped surface instead of a saturated red block, the failure
/// carried by the icon and the words.
class ReadFailureBannerColors {
  const ReadFailureBannerColors({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.action,
  });

  factory ReadFailureBannerColors.of(ColorScheme colorScheme) =>
      colorScheme.brightness == Brightness.dark
      ? ReadFailureBannerColors(
          background: colorScheme.surfaceContainerHigh,
          foreground: colorScheme.onSurface,
          icon: colorScheme.error,
          action: _legibleOn(
            colorScheme.primary,
            colorScheme.surfaceContainerHigh,
          ),
        )
      : ReadFailureBannerColors(
          background: colorScheme.errorContainer,
          foreground: colorScheme.onErrorContainer,
          icon: colorScheme.onErrorContainer,
          action: colorScheme.onErrorContainer,
        );

  final Color background;
  final Color foreground;
  final Color icon;
  final Color action;
}

/// Body text contrast, which the retry's label is held to as well.
const minTextContrast = 4.5;

/// [color], lightened only as far as it takes to read as text on [background]:
/// a vivid accent kept from its seed, the default blue among them, can fall
/// short on a raised dark surface.
Color _legibleOn(Color color, Color background) {
  var legible = color;
  for (var step = 0; step < 100; step++) {
    if (contrastRatio(legible, background) >= minTextContrast ||
        legible.tone >= 100) {
      break;
    }
    legible = legible.shiftTone(1);
  }
  return legible;
}

/// The WCAG contrast ratio of two opaque colors.
double contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

/// [message] with [action] at its end on one line when the whole message fits
/// there; otherwise, and always below [stackBelowWidth], [action] goes under
/// it. Neither is ever squeezed: the message wraps at the full width and the
/// action keeps its own size.
class _MessageAndAction extends MultiChildRenderObjectWidget {
  _MessageAndAction({
    required this.stackBelowWidth,
    required Widget message,
    required Widget action,
  }) : super(children: [message, action]);

  final double stackBelowWidth;

  @override
  _RenderMessageAndAction createRenderObject(BuildContext context) =>
      _RenderMessageAndAction(
        stackBelowWidth: stackBelowWidth,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMessageAndAction renderObject,
  ) {
    renderObject
      ..stackBelowWidth = stackBelowWidth
      ..textDirection = Directionality.of(context);
  }
}

class _MessageAndActionParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMessageAndAction extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MessageAndActionParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _MessageAndActionParentData
        > {
  _RenderMessageAndAction({
    required double stackBelowWidth,
    required TextDirection textDirection,
  }) : _stackBelowWidth = stackBelowWidth,
       _textDirection = textDirection;

  static const _gap = 10.0;
  static const _stackGap = 4.0;

  double _stackBelowWidth;
  set stackBelowWidth(double value) {
    if (value == _stackBelowWidth) return;
    _stackBelowWidth = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _message => firstChild!;
  RenderBox get _action => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MessageAndActionParentData) {
      child.parentData = _MessageAndActionParentData();
    }
  }

  bool _inline(double width, Size actionSize) =>
      width >= _stackBelowWidth &&
      _message.getMaxIntrinsicWidth(double.infinity) +
              _gap +
              actionSize.width <=
          width;

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : computeMaxIntrinsicWidth(double.infinity);
    final actionConstraints = BoxConstraints(maxWidth: width);
    final actionSize = dry
        ? _action.getDryLayout(actionConstraints)
        : (_action..layout(actionConstraints, parentUsesSize: true)).size;
    final inline = _inline(width, actionSize);
    final messageWidth = inline ? width - _gap - actionSize.width : width;
    final messageConstraints = BoxConstraints.tightFor(width: messageWidth);
    final messageSize = dry
        ? _message.getDryLayout(messageConstraints)
        : (_message..layout(messageConstraints, parentUsesSize: true)).size;
    final rtl = _textDirection == TextDirection.rtl;
    final height = inline
        ? math.max(messageSize.height, actionSize.height)
        : messageSize.height + _stackGap + actionSize.height;
    if (!dry) {
      final messageData = _message.parentData! as _MessageAndActionParentData;
      final actionData = _action.parentData! as _MessageAndActionParentData;
      final actionX = rtl ? 0.0 : width - actionSize.width;
      if (inline) {
        messageData.offset = Offset(
          rtl ? actionSize.width + _gap : 0,
          (height - messageSize.height) / 2,
        );
        actionData.offset = Offset(actionX, (height - actionSize.height) / 2);
      } else {
        messageData.offset = Offset.zero;
        actionData.offset = Offset(actionX, messageSize.height + _stackGap);
      }
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _message.getMinIntrinsicWidth(double.infinity),
    _action.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _message.getMaxIntrinsicWidth(double.infinity) +
      _gap +
      _action.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
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
