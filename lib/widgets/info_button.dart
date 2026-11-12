import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _buttonSize = 28.0;
const _glyphSize = 16.0;
const _popoverMaxWidth = 360.0;
const _popoverGap = 8.0;
const _popoverMargin = 8.0;

/// The one place an explanation lives once it leaves the normal state: an
/// info glyph right after a title that opens [paragraphs] in a popover.
/// Problems never go here; they stay inline where they happen.
class InfoButton extends StatefulWidget {
  const InfoButton({super.key, required this.paragraphs, this.label});

  final List<String> paragraphs;

  /// The tooltip and the name a screen reader reads; 说明 when null.
  final String? label;

  @override
  State<InfoButton> createState() => _InfoButtonState();
}

class _InfoButtonState extends State<InfoButton> {
  final _controller = OverlayPortalController();
  final _anchorKey = GlobalKey();
  ScrollPosition? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_hide);
      _scroll = scroll?..addListener(_hide);
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_hide);
    super.dispose();
  }

  void _hide() {
    if (_controller.isShowing) {
      _controller.hide();
    }
  }

  void _toggle() {
    if (_controller.isShowing) {
      _controller.hide();
    } else {
      _controller.show();
    }
  }

  Rect? _anchorIn(BuildContext overlayContext) {
    final anchor = _anchorKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(overlayContext).context.findRenderObject();
    if (anchor is! RenderBox || overlay is! RenderBox || !anchor.hasSize) {
      return null;
    }
    final origin = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    return Rect.fromCenter(
      center: (origin & anchor.size).center,
      width: _glyphSize,
      height: _glyphSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label ?? context.appLocalizations.infoAbout;
    final color = context.colorScheme.onSurfaceVariant;
    return TapRegion(
      groupId: this,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (overlayContext) {
          final rect = _anchorIn(overlayContext);
          if (rect == null) {
            return const SizedBox.shrink();
          }
          return CustomSingleChildLayout(
            delegate: InfoPopoverLayout(
              glyphRect: rect,
              padding: MediaQuery.paddingOf(overlayContext),
            ),
            child: TapRegion(
              groupId: this,
              onTapOutside: (_) => _hide(),
              child: _Popover(
                label: label,
                paragraphs: widget.paragraphs,
                onDismiss: _hide,
              ),
            ),
          );
        },
        child: SizedBox(
          key: _anchorKey,
          width: _buttonSize,
          // A title row shorter than the button would squeeze it into a pill.
          child: OverflowBox(
            fit: OverflowBoxFit.deferToChild,
            minHeight: _buttonSize,
            maxHeight: _buttonSize,
            child: IconButton(
              tooltip: label,
              padding: EdgeInsets.zero,
              iconSize: _glyphSize,
              style: ButtonStyle.from(
                minimumSize: const Size.square(_buttonSize),
                fixedSize: const Size.square(_buttonSize),
                tapTargetSize: TapTargetSize.shrinkWrap,
                foregroundColor: color,
                // The same quiet glyph on a card, a list or a bar.
                backgroundColor: const Color(0x00000000),
              ),
              onPressed: _toggle,
              icon: GlyphIcon(
                AppGlyphs.info,
                size: _glyphSize,
                fill: 0,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hangs the popover [_popoverGap] below the glyph with their left edges
/// aligned, shifted left only as far as the right edge needs, and above the
/// glyph only when the room below is too short and the room above is larger.
class InfoPopoverLayout extends SingleChildLayoutDelegate {
  const InfoPopoverLayout({
    required this.glyphRect,
    this.padding = EdgeInsets.zero,
  });

  final Rect glyphRect;
  final EdgeInsets padding;

  double get _below => glyphRect.bottom + _popoverGap;

  double get _above => glyphRect.top - _popoverGap;

  double get _top => padding.top + _popoverMargin;

  double _bottom(double height) => height - padding.bottom - _popoverMargin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final room = math.max(
      _bottom(constraints.maxHeight) - _below,
      _above - _top,
    );
    return BoxConstraints(
      maxWidth: math.max(
        0.0,
        constraints.maxWidth - padding.horizontal - _popoverMargin * 2,
      ),
      maxHeight: math.max(0.0, room),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final spaceBelow = _bottom(size.height) - _below;
    final spaceAbove = _above - _top;
    final opensBelow =
        childSize.height <= spaceBelow || spaceBelow >= spaceAbove;
    final minLeft = padding.left + _popoverMargin;
    final maxLeft = size.width - padding.right - _popoverMargin;
    return Offset(
      glyphRect.left.clamp(
        minLeft,
        math.max(minLeft, maxLeft - childSize.width),
      ),
      opensBelow ? _below : _above - childSize.height,
    );
  }

  @override
  bool shouldRelayout(InfoPopoverLayout oldDelegate) =>
      glyphRect != oldDelegate.glyphRect || padding != oldDelegate.padding;
}

class _Popover extends StatelessWidget {
  const _Popover({
    required this.label,
    required this.paragraphs,
    required this.onDismiss,
  });

  final String label;
  final List<String> paragraphs;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final shape = AppShape.all(AppCorner.md);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onDismiss},
      child: Focus(
        autofocus: true,
        child: Semantics(
          container: true,
          label: label,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _popoverMaxWidth),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: SurfaceLevel.floatingOf(
                  colorScheme,
                ).colorOf(colorScheme),
                shape: shape,
                shadows: menuShadows(colorScheme),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    for (final paragraph in paragraphs)
                      Text(
                        paragraph,
                        style: AppTextStyle.body
                            .of(context)
                            .copyWith(color: colorScheme.onSurface),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
