import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'state.dart';

const _menuMaxWidth = 360.0;
const _menuMargin = 16.0;
const _menuGap = 8.0;
const _rowMinHeight = 56.0;
const _copySlotWidth = 42.0;

/// One line of the 复制地址 menu: what it is and its full value, or null
/// when the status does not give one.
typedef TailscaleAddressEntry = ({String label, String? value});

/// The four ways to reach this device, in the menu's order: the short host
/// name and the full MagicDNS name, then IPv6 and IPv4. Both names come only
/// from the device's own DNS name, never from its host or display name.
List<TailscaleAddressEntry> tailscaleAddressEntries(
  BuildContext context,
  TailscaleStatus? status,
) {
  final appLocalizations = context.appLocalizations;
  final self = status?.self;
  final dnsName = self == null
      ? null
      : tailscaleMagicDnsName(
          self,
          enabled: status?.tailnet?.magicDnsEnabled == true,
        );
  return [
    (
      label: appLocalizations.tsShortHostname,
      value: tailscaleShortDnsName(dnsName),
    ),
    (label: appLocalizations.tsFullDnsName, value: dnsName),
    (label: 'IPv6', value: tailscaleIpv6Of(self)),
    // Strict: an IPv6-only device has no IPv4 to copy.
    (label: 'IPv4', value: tailscaleIpv4Of(self)),
  ];
}

/// The first label of a full DNS name; null without one.
String? tailscaleShortDnsName(String? dnsName) {
  final label = dnsName?.split('.').first ?? '';
  return label.isEmpty ? null : label;
}

/// 复制地址 with its chevron, opening the addresses in a popover; a row
/// copies its whole value and closes it. Escape or a tap outside closes it
/// too, and focus goes back to the button.
class TailscaleAddressMenu extends StatefulWidget {
  const TailscaleAddressMenu({
    super.key,
    required this.entries,
    required this.onCopy,
  });

  final List<TailscaleAddressEntry> entries;
  final ValueChanged<String> onCopy;

  @override
  State<TailscaleAddressMenu> createState() => _TailscaleAddressMenuState();
}

class _TailscaleAddressMenuState extends State<TailscaleAddressMenu> {
  final _controller = OverlayPortalController();
  final _anchorKey = GlobalKey();
  final _buttonFocus = FocusNode();
  final _menuFocus = FocusNode();
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
    _buttonFocus.dispose();
    _menuFocus.dispose();
    super.dispose();
  }

  void _hide() {
    if (_controller.isShowing) {
      _controller.hide();
    }
  }

  /// Closes the menu; focus inside it goes back to the button.
  void _close() {
    final focused = _menuFocus.hasFocus;
    _hide();
    if (focused) {
      (_buttonFocus.descendants.firstOrNull ?? _buttonFocus).requestFocus();
    }
  }

  void _toggle() {
    if (_controller.isShowing) {
      _controller.hide();
    } else {
      _controller.show();
      // The button keeps focus otherwise, autofocus or not: the menu takes
      // it, so the next Tab lands on its first row.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isShowing) {
          _menuFocus.requestFocus();
        }
      });
    }
  }

  void _copy(String value) {
    _close();
    widget.onCopy(value);
  }

  Rect? _anchorIn(BuildContext overlayContext) {
    final anchor = _anchorKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(overlayContext).context.findRenderObject();
    if (anchor is! RenderBox || overlay is! RenderBox || !anchor.hasSize) {
      return null;
    }
    final origin = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    return origin & anchor.size;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
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
            delegate: TailscaleAddressMenuLayout(
              anchor: rect,
              padding: MediaQuery.paddingOf(overlayContext),
            ),
            child: TapRegion(
              groupId: this,
              onTapOutside: (_) => _close(),
              child: _AddressPopover(
                focusNode: _menuFocus,
                label: appLocalizations.tsCopyAddress,
                entries: widget.entries,
                onCopy: _copy,
                onDismiss: _close,
              ),
            ),
          );
        },
        child: Focus(
          key: _anchorKey,
          focusNode: _buttonFocus,
          skipTraversal: true,
          child: TonalButton(
            size: TonalButtonSize.bar,
            label: appLocalizations.tsCopyAddress,
            trailingGlyph: AppGlyphs.chevronDown,
            onPressed: _toggle,
          ),
        ),
      ),
    );
  }
}

/// Hangs the menu [_menuGap] under the button, left edges aligned and moved
/// in only as far as the window needs; above the button only when the room
/// below is too short and the room above is larger. At most 360 wide and
/// never closer than [_menuMargin] to either side.
class TailscaleAddressMenuLayout extends SingleChildLayoutDelegate {
  const TailscaleAddressMenuLayout({
    required this.anchor,
    this.padding = EdgeInsets.zero,
  });

  final Rect anchor;
  final EdgeInsets padding;

  double get _below => anchor.bottom + _menuGap;

  double get _above => anchor.top - _menuGap;

  double get _top => padding.top + _menuMargin;

  double _bottom(double height) => height - padding.bottom - _menuMargin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final room = math.max(
      _bottom(constraints.maxHeight) - _below,
      _above - _top,
    );
    final width = math.max(
      0.0,
      math.min(
        _menuMaxWidth,
        constraints.maxWidth - padding.horizontal - _menuMargin * 2,
      ),
    );
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0.0, room),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final spaceBelow = _bottom(size.height) - _below;
    final spaceAbove = _above - _top;
    final opensBelow =
        childSize.height <= spaceBelow || spaceBelow >= spaceAbove;
    final minLeft = padding.left + _menuMargin;
    final maxLeft = size.width - padding.right - _menuMargin;
    return Offset(
      anchor.left.clamp(minLeft, math.max(minLeft, maxLeft - childSize.width)),
      opensBelow ? _below : _above - childSize.height,
    );
  }

  @override
  bool shouldRelayout(TailscaleAddressMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor || padding != oldDelegate.padding;
}

class _AddressPopover extends StatelessWidget {
  const _AddressPopover({
    required this.focusNode,
    required this.label,
    required this.entries,
    required this.onCopy,
    required this.onDismiss,
  });

  final FocusNode focusNode;
  final String label;
  final List<TailscaleAddressEntry> entries;
  final ValueChanged<String> onCopy;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onDismiss,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            FocusScope.of(context).nextFocus(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            FocusScope.of(context).previousFocus(),
      },
      child: Focus(
        focusNode: focusNode,
        // Holds focus for the shortcuts only; never a Tab stop of its own.
        skipTraversal: true,
        child: FocusTraversalGroup(
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: label,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: SurfaceLevel.floatingOf(
                  colorScheme,
                ).colorOf(colorScheme),
                shape: AppShape.all(AppCorner.md),
                shadows: menuShadows(colorScheme),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, entry) in entries.indexed) ...[
                      if (index > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            height: 1,
                            child: ColoredBox(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                      _AddressRow(
                        // Per state, so a row never turns disabled under a
                        // press it is still answering.
                        key: ValueKey((entry.label, entry.value != null)),
                        entry: entry,
                        onCopy: onCopy,
                      ),
                    ],
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

/// The whole row is the one button: label, full value, copy glyph.
class _AddressRow extends StatelessWidget {
  const _AddressRow({super.key, required this.entry, required this.onCopy});

  final TailscaleAddressEntry entry;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final value = entry.value;
    final enabled = value != null;
    final muted = colorScheme.onSurfaceVariant;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 10, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    entry.label,
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: muted),
                  ),
                  Text(
                    value ?? appLocalizations.tsAddressMissing,
                    softWrap: true,
                    style: AppTextStyle.subheadline
                        .of(context)
                        .toTabular
                        .copyWith(
                          color: enabled
                              ? colorScheme.onSurface
                              : muted.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _copySlotWidth,
              child: Center(
                child: GlyphIcon(
                  AppGlyphs.copy,
                  size: 16,
                  color: enabled
                      ? colorScheme.onSurfaceVariant
                      : muted.withValues(alpha: 0.38),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!enabled) {
      // Nothing to copy: read as plain text, never as a button.
      return Semantics(
        container: true,
        label: appLocalizations.tsFieldValue(
          entry.label,
          appLocalizations.tsFieldUnavailable,
        ),
        excludeSemantics: true,
        child: content,
      );
    }
    return PressSurface(
      fill: const Color(0x00000000),
      shape: AppShape.all(AppCorner.sm),
      onPressed: () => onCopy(value),
      childFills: true,
      child: Semantics(
        label: appLocalizations.tsCopyFieldValue(entry.label, value),
        excludeSemantics: true,
        child: content,
      ),
    );
  }
}
