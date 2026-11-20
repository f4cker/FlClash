import 'dart:async';

import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How a status card tag that opens the IP detail looks; all of the tap
/// affordance lives here, so it can be tuned without touching the card.
abstract final class IpDetailTagStyle {
  /// Space between two tags, across and between lines.
  static const gap = 8.0;

  /// The smallest side of a tag's tap target.
  static const minHit = 44.0;

  static const horizontalPadding = 10.0;

  /// Kept around the text once it outgrows the chip; at 1× the chip holds
  /// its own height.
  static const verticalPadding = 6.0;

  static const chevronSize = 10.0;
  static const chevronGap = 6.0;

  static const hoverOpacity = 0.08;
  static const pressedOpacity = 0.12;

  static const focusRingWidth = 2.0;
  static const focusRingGap = 2.0;
}

/// A chip of the status card that opens the detail of the address shown,
/// with a trailing chevron. Off, it shows the bare chip and says there is
/// no address to view.
///
/// The visible chip keeps its place at the top start of a target at least
/// [IpDetailTagStyle.minHit] square, which grows downwards only, away from
/// the address above it.
class IpDetailTag extends StatefulWidget {
  const IpDetailTag({
    super.key,
    required this.label,
    this.tone = DashboardChipTone.idle,
    required this.height,
    required this.semanticLabel,
    this.semanticHint,
    this.tooltip,
    required this.onOpen,
  });

  final String label;
  final DashboardChipTone tone;

  /// The chip's own height at 1×.
  final double height;
  final String semanticLabel;
  final String? semanticHint;
  final String? tooltip;

  /// Opens the detail and completes once it is closed; null turns the tag
  /// off.
  final Future<void> Function()? onOpen;

  @override
  State<IpDetailTag> createState() => _IpDetailTagState();
}

class _IpDetailTagState extends State<IpDetailTag> {
  var _hovered = false;
  var _pressed = false;
  var _focused = false;

  /// The tag's own focus, under its press region.
  FocusNode? _node;

  Future<void> _open() async {
    final onOpen = widget.onOpen;
    if (onOpen == null) return;
    final node = _node;
    await onOpen();
    // Back from the detail, focus returns to the tag that opened it.
    if (mounted && node != null && node.canRequestFocus) {
      node.requestFocus();
    }
  }

  void _set(VoidCallback change) {
    if (mounted) setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onOpen != null;
    final VoidCallback? onPressed = enabled ? () => unawaited(_open()) : null;
    final colorScheme = context.colorScheme;
    final (background, foreground) = dashboardChipColors(context, widget.tone);
    final textScaler = MediaQuery.textScalerOf(context);
    final overlay = !enabled
        ? null
        : _pressed
        ? colorScheme.primary.withValues(alpha: IpDetailTagStyle.pressedOpacity)
        : _hovered
        ? colorScheme.primary.withValues(alpha: IpDetailTagStyle.hoverOpacity)
        : null;
    final fill = overlay == null
        ? background
        : Color.alphaBlend(overlay, background);
    final textStyle = AppTextStyle.caption1
        .of(context, emphasized: true)
        .toTabular
        .copyWith(color: foreground);
    final textHeight = textScaler.scale(
      (textStyle.fontSize ?? 12) * (textStyle.height ?? 1),
    );
    // At 1× the padding is whatever centres the text in the chip's own
    // height, up to the full padding.
    final vertical = ((widget.height - textHeight) / 2).clamp(
      0.0,
      IpDetailTagStyle.verticalPadding,
    );
    final chip = Container(
      constraints: BoxConstraints(minHeight: widget.height),
      padding: EdgeInsets.symmetric(
        horizontal: IpDetailTagStyle.horizontalPadding,
        vertical: vertical,
      ),
      decoration: ShapeDecoration(
        color: fill,
        // The pill of the plain chip.
        shape: AppShape.full.copyWith(
          side: _focused && enabled
              ? BorderSide(
                  color: colorScheme.primary,
                  width: IpDetailTagStyle.focusRingWidth,
                  // Outside the chip, the gap clear of its edge.
                  strokeAlign:
                      1 +
                      2 *
                          IpDetailTagStyle.focusRingGap /
                          IpDetailTagStyle.focusRingWidth,
                )
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: IpDetailTagStyle.chevronGap,
        children: [
          // One line while it fits; a label longer than the card is wide
          // wraps rather than being cut.
          Flexible(child: Text(widget.label, style: textStyle)),
          if (enabled)
            GlyphIcon(
              AppGlyphs.chevronForward,
              size: textScaler.scale(IpDetailTagStyle.chevronSize),
              color: foreground,
            ),
        ],
      ),
    );
    final Widget target = Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      hint: enabled ? widget.semanticHint : null,
      onTap: onPressed,
      // The chevron is decoration: the label says it all.
      excludeSemantics: true,
      child: PressRegion(
        onTap: onPressed,
        canRequestFocus: enabled,
        excludeFromSemantics: true,
        onHover: (value) => _set(() => _hovered = value),
        onPressedChanged: (value) => _set(() => _pressed = value),
        onFocusChange: (value) => _set(() => _focused = value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: IpDetailTagStyle.minHit,
            minHeight: IpDetailTagStyle.minHit,
          ),
          child: Builder(
            builder: (context) {
              _node = Focus.maybeOf(context);
              return Align(
                alignment: AlignmentDirectional.topStart,
                widthFactor: 1,
                heightFactor: 1,
                child: chip,
              );
            },
          ),
        ),
      ),
    );
    final tooltip = widget.tooltip;
    if (!enabled || tooltip == null) return target;
    return Tooltip(message: tooltip, excludeFromSemantics: true, child: target);
  }
}

/// Lays [child] out [bottom] shorter than it is, so what follows moves up
/// under it, while its whole height still takes taps: a tap target can
/// reach into the room below without growing the layout. What lies in
/// that room must not take taps itself.
class HitOverhang extends SingleChildRenderObjectWidget {
  const HitOverhang({super.key, required this.bottom, super.child});

  final double bottom;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderHitOverhang(bottom);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHitOverhang renderObject,
  ) {
    renderObject.bottom = bottom;
  }
}

/// The render object of [HitOverhang].
class RenderHitOverhang extends RenderProxyBox {
  RenderHitOverhang(this._bottom);

  double _bottom;

  double get bottom => _bottom;

  set bottom(double value) {
    if (value == _bottom) return;
    _bottom = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(
        minHeight: constraints.minHeight + bottom,
        maxHeight: constraints.maxHeight + bottom,
      );

  Size _sizeFor(BoxConstraints constraints, Size child) =>
      constraints.constrain(
        Size(child.width, (child.height - bottom).clamp(0, double.infinity)),
      );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return _sizeFor(
      constraints,
      child.getDryLayout(_childConstraints(constraints)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, child.size);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      (super.computeMinIntrinsicHeight(width) - bottom).clamp(
        0,
        double.infinity,
      );

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (super.computeMaxIntrinsicHeight(width) - bottom).clamp(
        0,
        double.infinity,
      );

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    final reach = Offset.zero & Size(size.width, size.height + bottom);
    if (child == null || !reach.contains(position)) return false;
    if (child.hitTest(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
