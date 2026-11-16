import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The capsule's height: the bar's round buttons, the Core status one among
/// them.
final double macHelperBarHeight = TonalButtonSize.bar.button;

/// Below this window width the capsule shows its icon only.
const double macHelperBarCompactWidth = 720;

const _popoverWidth = 320.0;

/// The helper ships inside Flash and runs only when its signature matches
/// this build: its version is the app's.
String _appVersion() {
  final info = globalState.packageInfo;
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
}

const _fade = Duration(milliseconds: 200);
const _tint = 0.15;

/// The helper's place in the dashboard bar, left of the Core status button.
/// Nothing while the helper is ready; otherwise a capsule naming what is
/// wrong that opens the helper card in a popover under it. A feature that
/// needs the helper opens the same popover.
class MacHelperBarStatus extends ConsumerStatefulWidget {
  /// The macOS helper flow; the app's own when null.
  final MacHelperMaintenance? maintenance;

  /// The helper's version for its ready popover; the app's when null.
  final String? version;

  const MacHelperBarStatus({super.key, this.maintenance, this.version});

  @override
  ConsumerState<MacHelperBarStatus> createState() => _MacHelperBarStatusState();
}

class _MacHelperBarStatusState extends ConsumerState<MacHelperBarStatus>
    implements MacHelperPresenter {
  final _popover = OverlayPortalController();
  final _anchorKey = GlobalKey();
  final _popoverFocus = FocusNode();
  final _buttonFocus = FocusNode();
  AppLifecycleListener? _lifecycle;
  MacHelperMaintenance? _flow;
  Completer<void>? _shown;
  bool _requiredByFeature = false;
  String? _announced;
  bool _wasReady = false;

  @override
  MacHelperMaintenance get maintenance => _flow!;

  @override
  bool get canPresent {
    if (!mounted || _flow == null) return false;
    // A feature only asks while the helper is not ready.
    final view = macHelperBarView(context.appLocalizations, _flow!);
    if (view == null || view.isReady) return false;
    final route = ModalRoute.of(context);
    return PageActivityScope.isActiveOf(context) &&
        (route == null || route.isCurrent);
  }

  @override
  Future<void> present({required bool requiredByFeature}) {
    final shown = _shown;
    if (shown != null) {
      if (requiredByFeature && !_requiredByFeature) {
        setState(() => _requiredByFeature = true);
      }
      return shown.future;
    }
    final completer = Completer<void>();
    _shown = completer;
    setState(() => _requiredByFeature = requiredByFeature);
    _popover.show();
    return completer.future;
  }

  @override
  void initState() {
    super.initState();
    final flow =
        widget.maintenance ??
        (system.isMacOS && macosManagedHelperBuild
            ? macHelperMaintenance
            : null);
    if (flow == null || ref.read(safeModeProvider)) return;
    _flow = flow;
    flow.addListener(_changed);
    registerMacHelperPresenter(this);
    // Coming back from System Settings checks again.
    _lifecycle = AppLifecycleListener(onResume: flow.resumed);
    if (flow.state == null && !flow.busy) unawaited(flow.check());
  }

  @override
  void dispose() {
    _flow?.removeListener(_changed);
    unregisterMacHelperPresenter(this);
    _lifecycle?.dispose();
    _complete();
    _popoverFocus.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }

  void _complete() {
    final shown = _shown;
    _shown = null;
    if (shown != null && !shown.isCompleted) shown.complete();
  }

  void _hide() {
    if (_popover.isShowing) _popover.hide();
    _complete();
  }

  void _dismiss() {
    final focused = _popoverFocus.hasFocus;
    if (mounted) setState(_hide);
    if (focused) _buttonFocus.requestFocus();
  }

  void _changed() {
    // The first check can answer before the first build.
    if (!mounted || _announced == null) return;
    final view = macHelperBarView(context.appLocalizations, _flow!);
    // Becoming ready: the capsule collapses to the green button and its
    // popover closes; a start has nothing to show.
    final wasReady = _wasReady;
    _wasReady = view?.isReady ?? false;
    if (view == null || !view.opens || (view.isReady && !wasReady)) _hide();
    setState(() {});
    final title = view?.title ?? context.appLocalizations.macHelperOn;
    final first = _announced == null;
    if (_announced == title) return;
    _announced = title;
    // The open popover's card announces its own title.
    if (first || _popover.isShowing) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        title,
        Directionality.of(context),
      ),
    );
  }

  void _toggle() {
    if (_popover.isShowing) {
      _dismiss();
    } else {
      unawaited(present(requiredByFeature: false));
    }
  }

  Rect? _anchorIn(BuildContext overlayContext) {
    final anchor = _anchorKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(overlayContext).context.findRenderObject();
    if (anchor is! RenderBox || overlay is! RenderBox || !anchor.hasSize) {
      return null;
    }
    final origin = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = origin & anchor.size;
    // Right-aligned under the capsule: the layout puts the popover's left
    // edge at the rect's left and keeps it inside the window.
    return Rect.fromLTRB(
      rect.right - _popoverWidth,
      rect.top,
      rect.right,
      rect.bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    if (flow == null) return const SizedBox.shrink();
    final view = macHelperBarView(context.appLocalizations, flow);
    if (_announced == null) {
      _announced = view?.title ?? context.appLocalizations.macHelperOn;
      _wasReady = view?.isReady ?? false;
    }
    return AnimatedSwitcher(
      duration: _fade,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [...previous, ?current],
      ),
      child: view == null
          ? const SizedBox.shrink(key: ValueKey('unknown'))
          : Padding(
              key: const ValueKey('button'),
              // The bar's gap to the Core status button.
              padding: const EdgeInsetsDirectional.only(end: barButtonGap),
              child: TapRegion(
                groupId: this,
                child: OverlayPortal(
                  controller: _popover,
                  overlayChildBuilder: _buildPopover,
                  child: KeyedSubtree(
                    key: _anchorKey,
                    child: Focus(
                      focusNode: _buttonFocus,
                      skipTraversal: true,
                      child: MacHelperCapsule(
                        view: view,
                        compact:
                            ref.watch(viewWidthProvider) <
                            macHelperBarCompactWidth,
                        onPressed: view.opens ? _toggle : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPopover(BuildContext overlayContext) {
    final rect = _anchorIn(overlayContext);
    if (rect == null) return const SizedBox.shrink();
    return CustomSingleChildLayout(
      delegate: InfoPopoverLayout(
        glyphRect: rect,
        padding: MediaQuery.paddingOf(overlayContext),
      ),
      child: TapRegion(
        groupId: this,
        onTapOutside: (_) => _dismiss(),
        child: MacHelperPopover(
          maintenance: _flow!,
          version: widget.version ?? _appVersion(),
          requiredByFeature: _requiredByFeature,
          focusNode: _popoverFocus,
          onDismiss: _dismiss,
        ),
      ),
    );
  }
}

/// The helper's bar button. Ready, a round green button like the Core
/// check; otherwise it widens into a capsule with an icon and a short text,
/// amber when the user has something to do and red on a failure, 15% of that
/// color behind it and a stroke around it.
class MacHelperCapsule extends StatelessWidget {
  final MacHelperBarView view;

  /// Icon only, the text moving to the tooltip; for a narrow window.
  final bool compact;

  /// Null while the helper only starts: nothing to open.
  final VoidCallback? onPressed;

  const MacHelperCapsule({
    super.key,
    required this.view,
    required this.compact,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final l = context.appLocalizations;
    final round = compact || view.isReady;
    // The size animates outside the tooltip, which drops its wrapper when it
    // has nothing to say.
    return AnimatedSize(
      duration: _fade,
      curve: Curves.easeInOut,
      alignment: AlignmentDirectional.centerEnd,
      child: Semantics(
        label: view.isReady || !view.opens
            ? view.title
            : l.macHelperBarHint(view.title),
        button: view.opens,
        excludeSemantics: true,
        child: Tooltip(
          message: round ? view.label : '',
          excludeFromSemantics: true,
          // Ready wears the Core check's own colors; otherwise the tone's
          // color on 15% of it.
          child: TweenAnimationBuilder<Color?>(
            duration: _fade,
            tween: ColorTween(
              end: view.isReady
                  ? colorScheme.onSuccessContainer
                  : macHelperBarColor(colorScheme, view.tone),
            ),
            builder: (context, color, _) => TweenAnimationBuilder<Color?>(
              duration: _fade,
              tween: ColorTween(
                end: view.isReady
                    ? colorScheme.successContainer
                    : macHelperBarColor(
                        colorScheme,
                        view.tone,
                      ).withValues(alpha: _tint),
              ),
              builder: (context, fill, _) =>
                  _buildButton(context, color!, fill!, round: round),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    Color color,
    Color fill, {
    required bool round,
  }) {
    // Round, the glyph is as big as the Core check's; beside text, smaller.
    final iconSize = round
        ? TonalButtonSize.bar.icon
        : TonalButtonSize.section.icon;
    final icon = SizedBox.square(
      dimension: iconSize,
      child: view.kind == MacHelperBarKind.starting
          ? ActivityIndicator(size: iconSize, color: color)
          : GlyphIcon(
              macHelperBarGlyph(view.kind),
              size: iconSize,
              color: color,
            ),
    );
    final height = macHelperBarHeight;
    // Under Liquid Glass the ready button is tinted glass, as the Core check.
    final pane = view.isReady && TonalButtonTheme.glassOf(context)
        ? LiquidGlassStyle.tinted(context.colorScheme, fill)
        : null;
    final background = pane == null ? fill : Colors.transparent;
    // Ready matches the Core check: no stroke.
    final side = view.isReady ? BorderSide.none : BorderSide(color: color);
    final style = ButtonStyle.from(
      foregroundColor: color,
      disabledForegroundColor: color,
      backgroundColor: background,
      disabledBackgroundColor: background,
      backgroundBuilder: pane == null
          ? null
          : LiquidGlass.buttonBackground((_) => pane),
      shape: AppShape.full,
      minimumSize: Size.square(height),
      fixedSize: round ? Size.square(height) : Size.fromHeight(height),
      padding: round
          ? EdgeInsets.zero
          : const EdgeInsetsDirectional.only(start: 12, end: 14),
      tapTargetSize: TapTargetSize.shrinkWrap,
      pressLook: PressLook.tint,
    ).merge(ButtonStyle(side: WidgetStatePropertyAll(side)));
    return round
        ? IconButton.filled(onPressed: onPressed, style: style, icon: icon)
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: icon,
            // The button's own label style: semibold subheadline.
            label: Text(view.label, maxLines: 1),
          );
  }
}

/// The helper card under the capsule; from a feature's switch it first says
/// the feature needs the helper.
class MacHelperPopover extends StatelessWidget {
  final MacHelperMaintenance maintenance;
  final bool requiredByFeature;
  final FocusNode? focusNode;
  final VoidCallback onDismiss;

  /// Said under "Helper ready".
  final String? version;

  const MacHelperPopover({
    super.key,
    required this.maintenance,
    required this.onDismiss,
    this.version,
    this.requiredByFeature = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final l = context.appLocalizations;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onDismiss},
      child: Focus(
        focusNode: focusNode,
        autofocus: true,
        child: Semantics(
          container: true,
          scopesRoute: true,
          explicitChildNodes: true,
          label: l.macHelperTitle,
          child: SizedBox(
            width: _popoverWidth,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: SurfaceLevel.floatingOf(
                  colorScheme,
                ).colorOf(colorScheme),
                shape: AppShape.all(AppCorner.md),
                shadows: menuShadows(colorScheme),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (requiredByFeature) ...[
                      Text(
                        l.macHelperRequiredDetail,
                        style: AppTextStyle.footnote
                            .of(context)
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                    ],
                    MacHelperCard(
                      maintenance: maintenance,
                      embedded: true,
                      version: version,
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
