import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import 'card.dart';
import 'live_status.dart';

const _cardHeight = 300.0;
const _cardSize = Size(320, _cardHeight);
const _cardInset = 8.0;
const _heroHeight = 156.0;
const _heroCorner = AppCorner.alert - _cardInset;
const _actionHeight = 44.0;
const _secondaryHeight = 32.0;
const _actionGap = 8.0;
const _textTop = 12.0;
const _actionBottom = 4.0;
// A card taller than its base grows to the window's safe area less this.
const _windowMargin = 32.0;
const _anchorGap = 8.0;
const _windowEdge = 16.0;
// Room above the front card for the cards behind it to show.
const _stackRise = 48.0;
const _rightGutter = 24.0;
const _dragExtent = 220.0;
const _flipDistance = 60.0;
const _flipVelocity = 700.0;
const _overscroll = 0.3;
const _settleDuration = Duration(milliseconds: 460);
const _settleCurve = Cubic(0.2, 0.9, 0.25, 1);
const _wheelInterval = Duration(milliseconds: 350);
const _labelFade = Duration(milliseconds: 160);
const _askDuration = Duration(milliseconds: 200);
const _askGap = 8.0;

typedef _Pose = ({
  double x,
  double y,
  double z,
  double tilt,
  double turn,
  double opacity,
});

typedef _Slot = ({_Pose pose, double depth});

// Positions -1 (swiped away) to 3, in the design's CSS frame: z points at the
// viewer and a positive tilt leans the top away.
const List<_Pose> _poses = [
  (x: 0, y: 110, z: 80, tilt: -14, turn: 0, opacity: 0),
  (x: 0, y: 0, z: 0, tilt: 0, turn: 0, opacity: 1),
  (x: -10, y: -44, z: -70, tilt: 14, turn: 8, opacity: 1),
  (x: 10, y: -92, z: -140, tilt: 24, turn: -8, opacity: 0.85),
  (x: 0, y: -120, z: -220, tilt: 32, turn: 0, opacity: 0),
];

_Pose _lerpPose(_Pose a, _Pose b, double t) {
  double mix(double from, double to) => from + (to - from) * t;
  return (
    x: mix(a.x, b.x),
    y: mix(a.y, b.y),
    z: mix(a.z, b.z),
    tilt: mix(a.tilt, b.tilt),
    turn: mix(a.turn, b.turn),
    opacity: mix(a.opacity, b.opacity),
  );
}

_Pose _faded(_Pose pose) => (
  x: pose.x,
  y: pose.y,
  z: pose.z,
  tilt: pose.tilt,
  turn: pose.turn,
  opacity: 0,
);

_Pose _poseAt(double position) {
  final t = position.clamp(-1.0, 3.0) + 1;
  final i = math.min(t.floor(), _poses.length - 2);
  return _lerpPose(_poses[i], _poses[i + 1], t - i);
}

_Slot _lerpSlot(_Slot a, _Slot b, double t) => (
  pose: _lerpPose(a.pose, b.pose, t),
  depth: a.depth + (b.depth - a.depth) * t,
);

/// A front card leaves as a swipe takes it; one behind fades in place.
_Slot _exitOf(_Slot slot) => slot.depth < 0.5
    ? (pose: _poseAt(-1), depth: -1)
    : (pose: _faded(slot.pose), depth: slot.depth);

bool _isFlat(_Pose pose) =>
    pose.x == 0 &&
    pose.y == 0 &&
    pose.z == 0 &&
    pose.tilt == 0 &&
    pose.turn == 0;

// A negative perspective entry keeps the CSS frame of [_poses].
Matrix4 _transformOf(_Pose pose) => _isFlat(pose)
    ? Matrix4.identity()
    : (Matrix4.identity()
        ..setEntry(3, 2, -0.001)
        ..multiply(Matrix4.translationValues(pose.x, pose.y, pose.z))
        ..rotateX(pose.tilt * math.pi / 180)
        ..rotateY(pose.turn * math.pi / 180));

Rect _frontOf(BuildContext context, Size size, {required Rect anchor}) {
  final padding = MediaQuery.paddingOf(context);
  final width = _cardSize.width;
  final height = _cardSize.height;
  if (ViewScope.isMobileOf(context)) {
    final safe = padding.deflateRect(Offset.zero & size);
    final left = math.min(
      safe.center.dx - width / 2,
      safe.right - width - _rightGutter,
    );
    return Rect.fromLTWH(
      math.max(0, left),
      safe.center.dy - height / 2,
      width,
      height,
    );
  }
  final bottom = size.height - padding.bottom - _windowEdge;
  final top = math.min(
    anchor.bottom + _anchorGap + _stackRise,
    bottom - height,
  );
  return Rect.fromLTWH(
    math.max(0, size.width - _windowEdge - _rightGutter - width),
    math.max(0, top),
    width,
    height,
  );
}

/// Opens the deck with an alert's scrim and motion, grown from its front card.
class LiveStatusRoute extends PopupRoute<void>
    with AlertMotionRouteMixin<void> {
  LiveStatusRoute({
    required this.anchor,
    required this.separateCore,
    required this.barrierColor,
    required this.barrierLabel,
    this.statuses,
    this.helper,
    this.focus,
    this.helperRequired,
  });

  /// The bar button, in the navigator's coordinates.
  final Rect anchor;

  final bool separateCore;

  /// What the deck shows in place of the live statuses.
  final List<LiveStatus>? statuses;

  /// The macOS helper flow whose card leads the deck while it is not ready.
  final MacHelperMaintenance? helper;

  /// The key of the card the deck opens on; the first card when null or not
  /// there.
  final Object? focus;

  /// Whether a feature that needs the helper opened the deck, which the
  /// helper card then says.
  final ValueListenable<bool>? helperRequired;

  @override
  final Color barrierColor;

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => true;

  @override
  AlertScaleOrigin get scaleOrigin => (context, size) {
    final center = _frontOf(context, size, anchor: anchor).center;
    return Alignment(
      center.dx / size.width * 2 - 1,
      center.dy / size.height * 2 - 1,
    );
  };

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) => LiveStatusDeck(
        separateCore: separateCore,
        statuses: statuses,
        helper: helper,
        focus: focus,
        helperRequired: helperRequired,
        front: _frontOf(context, constraints.biggest, anchor: anchor),
      ),
    );
  }
}

typedef _Placed = ({LiveStatus status, _Slot slot, bool leaving});

/// The live statuses as a stack of cards, the next ones leaning back above the
/// front one. A drag down brings the next card forward and a drag up takes it
/// back; the deck keeps the card it shows while the statuses change under it.
class LiveStatusDeck extends ConsumerStatefulWidget {
  const LiveStatusDeck({
    super.key,
    required this.separateCore,
    required this.front,
    this.statuses,
    this.helper,
    this.focus,
    this.helperRequired,
  });

  final bool separateCore;

  /// Where the front card sits at its base height.
  final Rect front;

  final List<LiveStatus>? statuses;

  final MacHelperMaintenance? helper;

  final Object? focus;

  final ValueListenable<bool>? helperRequired;

  @override
  ConsumerState<LiveStatusDeck> createState() => _LiveStatusDeckState();
}

class _LiveStatusDeckState extends ConsumerState<LiveStatusDeck>
    with TickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _reflow = AnimationController(
    vsync: this,
    duration: _settleDuration,
  )..addStatusListener(_onReflowStatus);
  late final Animation<double> _reflowProgress = CurvedAnimation(
    parent: _reflow,
    curve: _settleCurve,
  );
  late final AnimationController _asking = AnimationController(
    vsync: this,
    duration: _askDuration,
  )..addStatusListener(_onAskingStatus);
  late final Animation<double> _askProgress = CurvedAnimation(
    parent: _asking,
    curve: Curves.easeOut,
  );
  List<LiveStatus> _statuses = const [];
  int _count = 0;
  Object? _shownKey;
  Object? _askKey;

  /// The card showing its details instead of its front.
  Object? _detailKey;
  int _target = 0;
  double _dragOrigin = 0;
  double _dragDistance = 0;
  bool _dragging = false;
  bool _closing = false;
  Duration? _lastWheel;

  Map<Object, _Slot>? _reflowFrom;
  List<({LiveStatus status, _Slot from})> _leaving = const [];

  bool get _cycles => _statuses.length > 1;

  bool get _held => _askKey != null || _detailKey != null;

  int _indexOf(int target) => target % _statuses.length;

  @override
  void dispose() {
    _position.dispose();
    _reflow.dispose();
    _asking.dispose();
    super.dispose();
  }

  void _follow(List<LiveStatus> statuses) {
    if (_statuses.isNotEmpty &&
        statuses.isNotEmpty &&
        !_sameKeys(_statuses, statuses) &&
        !context.disableAnimations) {
      _startReflow(statuses);
    }
    _statuses = statuses;
    if (statuses.isEmpty) {
      _close();
      return;
    }
    if (_askKey != null &&
        !statuses.any((it) => it.key == _askKey && _confirmOf(it) != null)) {
      _askKey = null;
      _asking.value = 0;
    }
    if (_detailKey != null && !statuses.any((it) => it.key == _detailKey)) {
      _detailKey = null;
    }
    // The deck opens on [LiveStatusDeck.focus], then keeps the card it
    // shows whatever arrives or changes behind it.
    final wanted = _shownKey ?? widget.focus;
    final kept = statuses.indexWhere((status) => status.key == wanted);
    final shown = kept >= 0 ? kept : _indexOf(_target);
    _shownKey = statuses[shown].key;
    final recounted = statuses.length != _count;
    _count = statuses.length;
    if (_dragging || shown == _indexOf(_target) && !recounted) return;
    _target = shown;
    _position.value = shown.toDouble();
  }

  static bool _sameKeys(List<LiveStatus> a, List<LiveStatus> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key) return false;
    }
    return true;
  }

  /// Moves every card on from where it is drawn now, the ones that go too.
  void _startReflow(List<LiveStatus> next) {
    final drawn = _layout();
    final keys = {for (final status in next) status.key};
    _reflowFrom = {for (final it in drawn) it.status.key: it.slot};
    _leaving = [
      for (final it in drawn)
        if (!keys.contains(it.status.key)) (status: it.status, from: it.slot),
    ];
    unawaited(_reflow.forward(from: 0).orCancel.catchError((_) {}));
  }

  void _onReflowStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      _reflowFrom = null;
      _leaving = const [];
    });
  }

  List<_Placed> _layout() {
    final from = _reflowFrom;
    final t = _reflowProgress.value;
    final position = _position.value;
    _Slot slotAt(int index) {
      final slot = _slotOf(index - position);
      if (from == null) return slot;
      final start =
          from[_statuses[index].key] ??
          (pose: _faded(slot.pose), depth: slot.depth);
      return _lerpSlot(start, slot, t);
    }

    return [
      for (var i = 0; i < _statuses.length; i++)
        (status: _statuses[i], slot: slotAt(i), leaving: false),
      for (final (:status, from: start) in _leaving)
        (
          status: status,
          slot: _lerpSlot(start, _exitOf(start), t),
          leaving: true,
        ),
    ];
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isActive) return;
      if (route.isCurrent) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  void _onAskingStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _askKey != null) {
      setState(() => _askKey = null);
    }
  }

  void _runAsking({required bool forward}) {
    if (context.disableAnimations) {
      _asking.value = forward ? 1 : 0;
    } else if (forward) {
      unawaited(_asking.forward().orCancel.catchError((_) {}));
    } else {
      unawaited(_asking.reverse().orCancel.catchError((_) {}));
    }
  }

  void _ask(Object key) {
    setState(() => _askKey = key);
    _runAsking(forward: true);
  }

  void _unask() {
    setState(() {});
    _runAsking(forward: false);
  }

  void _settle(int index) {
    if (_statuses.isEmpty) return;
    final target = _cycles ? index : 0;
    _target = target;
    _shownKey = _statuses[_indexOf(target)].key;
    if (context.disableAnimations) {
      _position.value = target.toDouble();
      return;
    }
    unawaited(
      _position
          .animateTo(
            target.toDouble(),
            duration: _settleDuration,
            curve: _settleCurve,
          )
          .orCancel
          .catchError((_) {}),
    );
  }

  void _step(int delta) => _settle(_target + delta);

  double _resist(double value) => _cycles ? value : value * _overscroll;

  void _onDragStart(DragStartDetails details) {
    _position.stop();
    _dragging = true;
    _dragOrigin = _target.toDouble();
    _dragDistance = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dy;
    _position.value = _resist(_dragOrigin + _dragDistance / _dragExtent);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final velocity = details.primaryVelocity ?? 0;
    var target = _dragOrigin.round();
    if (_dragDistance > _flipDistance || velocity > _flipVelocity) {
      target += 1;
    } else if (_dragDistance < -_flipDistance || velocity < -_flipVelocity) {
      target -= 1;
    }
    _settle(target);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _held) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      final last = _lastWheel;
      if (last != null && scroll.timeStamp - last < _wheelInterval) return;
      if (scroll.scrollDelta.dy.abs() < 1) return;
      _lastWheel = scroll.timeStamp;
      _step(scroll.scrollDelta.dy > 0 ? 1 : -1);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_held || event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _step(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Where a card [offset] places from the front sits in the stack. Once the
  /// deck cycles, the card that passes the front leaves forward over the
  /// first half of the step and over the second drops in from one layer
  /// behind the rear, fading in as it settles there.
  _Slot _slotOf(double offset) {
    final count = _statuses.length;
    if (!_cycles) return (pose: _poseAt(offset), depth: offset);
    var wrapped = offset % count;
    if (wrapped > count - 1) wrapped -= count;
    if (wrapped >= 0) return (pose: _poseAt(wrapped), depth: wrapped);
    final passed = -wrapped;
    if (passed <= 0.5) {
      final forward = -passed * 2;
      return (pose: _poseAt(forward), depth: forward);
    }
    final arrived = passed * 2 - 1;
    final depth = count - arrived;
    final pose = _poseAt(depth);
    return (pose: _lerpPose(_faded(pose), pose, arrived), depth: depth);
  }

  @override
  Widget build(BuildContext context) {
    final helper = widget.helper;
    final required = widget.helperRequired;
    if (widget.statuses != null || helper == null && required == null) {
      return _buildDeck(context);
    }
    return ListenableBuilder(
      listenable: Listenable.merge([helper, required]),
      builder: (context, _) => _buildDeck(context),
    );
  }

  Widget _buildDeck(BuildContext context) {
    final statuses =
        widget.statuses ??
        watchLiveStatuses(
          ref,
          separateCore: widget.separateCore,
          helper: widget.helper,
        );
    _follow(statuses);
    final helperRequired = widget.helperRequired?.value ?? false;
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final fill = SurfaceLevel.floatingOf(colorScheme).colorOf(colorScheme);
    final held = _held;
    final asking = _asking.status.isForwardOrCompleted;
    final cards = <Object, Widget>{
      for (final status in statuses)
        status.key: RepaintBoundary(
          key: ValueKey(status.key),
          child: _StatusCard(
            status: status,
            asking: status.key == _askKey
                ? _askProgress
                : kAlwaysDismissedAnimation,
            confirming: status.key == _askKey && asking,
            onAsk: () => _ask(status.key),
            onUnask: _unask,
            detailed: status.key == _detailKey,
            onDetails: () => setState(() => _detailKey = status.key),
            onBack: () => setState(() => _detailKey = null),
            helperRequired: helperRequired,
          ),
        ),
      for (final (:status, from: _) in _leaving)
        status.key: RepaintBoundary(
          key: ValueKey(status.key),
          child: _StatusCard(
            status: status,
            asking: kAlwaysDismissedAnimation,
            confirming: false,
            onAsk: _inert,
            onUnask: _inert,
            detailed: false,
            onDetails: _inert,
            onBack: _inert,
          ),
        ),
    };
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Semantics(
        container: true,
        value: statuses.length > 1
            ? appLocalizations.liveStatusPosition(
                _indexOf(_target) + 1,
                statuses.length,
              )
            : null,
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: GestureDetector(
            onVerticalDragStart: held ? null : _onDragStart,
            onVerticalDragUpdate: held ? null : _onDragUpdate,
            onVerticalDragEnd: held ? null : _onDragEnd,
            onVerticalDragCancel: held
                ? null
                : () => _onDragEnd(DragEndDetails()),
            child: AnimatedBuilder(
              animation: Listenable.merge([_position, _reflow]),
              builder: (context, _) {
                final placed = _layout()
                  ..sort((a, b) => b.slot.depth.compareTo(a.slot.depth));
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final (:status, :slot, :leaving) in placed)
                      if (slot.depth > -1 && slot.depth < 3)
                        _placeCard(
                          card: cards[status.key]!,
                          status: status,
                          pose: slot.pose,
                          front: !leaving && slot.depth.abs() < 0.5,
                          fill: fill,
                          shadows: slot.depth < 0.5
                              ? _frontShadows(colorScheme)
                              : _backShadows(colorScheme),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeCard({
    required Widget card,
    required LiveStatus status,
    required _Pose pose,
    required bool front,
    required Color fill,
    required List<BoxShadow> shadows,
  }) {
    final padding = MediaQuery.paddingOf(context);
    return Positioned.fill(
      key: card.key,
      child: CustomSingleChildLayout(
        delegate: _CardSlot(
          front: widget.front,
          padding: padding,
          centered: ViewScope.isMobileOf(context),
        ),
        child: IgnorePointer(
          ignoring: !front,
          child: Opacity(
            opacity: pose.opacity.clamp(0, 1),
            child: Transform(
              alignment: Alignment.center,
              transform: _transformOf(pose),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill,
                  shape: AppShape.all(AppCorner.alert),
                  shadows: shadows,
                ),
                child: _LeaningRaster(
                  leaning: !_isFlat(pose),
                  content: status,
                  child: card,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Places a card at [front] at its base height. A taller card grows down to
/// the window's safe area less [_windowMargin], rising as far as it must; its
/// body scrolls past that. A centered (phone) card stays centered.
class _CardSlot extends SingleChildLayoutDelegate {
  const _CardSlot({
    required this.front,
    required this.padding,
    required this.centered,
  });

  final Rect front;
  final EdgeInsets padding;
  final bool centered;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final safe = constraints.maxHeight - padding.vertical;
    return BoxConstraints(
      minWidth: front.width,
      maxWidth: front.width,
      minHeight: front.height,
      maxHeight: math.max(front.height, safe - _windowMargin),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = padding.top + _windowMargin / 2;
    final bottom = size.height - padding.bottom - _windowMargin / 2;
    final preferred = centered
        ? front.center.dy - childSize.height / 2
        : front.top;
    final y = childSize.height <= front.height
        ? front.top
        : math.max(top, math.min(preferred, bottom - childSize.height));
    return Offset(front.left, y);
  }

  @override
  bool shouldRelayout(_CardSlot oldDelegate) =>
      oldDelegate.front != front ||
      oldDelegate.padding != padding ||
      oldDelegate.centered != centered;
}

/// Draws a card that leans from a snapshot, so its text is neither
/// rasterized at a new scale on every frame of a flip nor drawn under a
/// perspective transform, where Impeller has logged glyphs missing from its
/// atlas. A new [content] retakes it.
class _LeaningRaster extends StatefulWidget {
  const _LeaningRaster({
    required this.leaning,
    required this.content,
    required this.child,
  });

  final bool leaning;
  final Object content;
  final Widget child;

  @override
  State<_LeaningRaster> createState() => _LeaningRasterState();
}

class _LeaningRasterState extends State<_LeaningRaster> {
  late final _controller = SnapshotController(
    allowSnapshotting: widget.leaning,
  );

  @override
  void didUpdateWidget(_LeaningRaster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.content, widget.content)) {
      _controller.allowSnapshotting = false;
    }
    _controller.allowSnapshotting = widget.leaning;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SnapshotWidget(
      controller: _controller,
      mode: SnapshotMode.permissive,
      child: widget.child,
    );
  }
}

List<BoxShadow> _frontShadows(ColorScheme colorScheme) => [
  BoxShadow(
    color: colorScheme.shadow.withValues(alpha: 0.16),
    blurRadius: 40,
    offset: const Offset(0, 16),
  ),
  BoxShadow(
    color: colorScheme.shadow.withValues(alpha: 0.06),
    blurRadius: 6,
    offset: const Offset(0, 2),
  ),
];

List<BoxShadow> _backShadows(ColorScheme colorScheme) => [
  BoxShadow(
    color: colorScheme.shadow.withValues(alpha: 0.08),
    blurRadius: 18,
    offset: const Offset(0, 6),
  ),
];

String _progressText(UpdateDownloading download) {
  final received = download.received.traffic.show;
  if (download.total <= 0) {
    return received;
  }
  return '$received / ${download.total.traffic.show}';
}

String _readyTip(AppLocalizations appLocalizations) => system.isWindows
    ? '${appLocalizations.updateReadyTip}\n${appLocalizations.updateRestartTip}'
    : appLocalizations.updateReadyTip;

/// An action the card asks about in place before it runs.
enum _Confirm { forceRestart, stopDownload }

_Confirm? _confirmOf(LiveStatus status) => switch (status) {
  CoreLiveStatus(phase: CoreStatus.connected) => _Confirm.forceRestart,
  UpdateStatus(download: UpdateDownloading()) => _Confirm.stopDownload,
  _ => null,
};

void _inert() {}

/// A button of a card: what it says, what it runs (null while it cannot run)
/// and its colors.
typedef _CardAction = ({
  String label,
  VoidCallback? onPressed,
  Color background,
  Color foreground,
});

class _StatusCard extends ConsumerStatefulWidget {
  const _StatusCard({
    required this.status,
    required this.asking,
    required this.confirming,
    required this.onAsk,
    required this.onUnask,
    required this.detailed,
    required this.onDetails,
    required this.onBack,
    this.helperRequired = false,
  });

  final LiveStatus status;

  /// How far the card has turned into asking to confirm its action.
  final Animation<double> asking;

  /// Whether the card is asking or about to, which its button confirms.
  final bool confirming;

  final VoidCallback onAsk;

  final VoidCallback onUnask;

  /// Whether the card shows its details instead of its front.
  final bool detailed;

  final VoidCallback onDetails;

  final VoidCallback onBack;

  /// A feature that needs the helper opened the deck: the helper card says so.
  final bool helperRequired;

  @override
  ConsumerState<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends ConsumerState<_StatusCard> {
  /// The details' title, which takes the focus as they open.
  final _detailsTitle = FocusNode();

  /// The button that opened the details, which takes it back as they close.
  final _secondary = FocusNode();

  /// The body's scroll once the card can grow no taller.
  late final _bodyScroll = sheetScrollController(context);

  @override
  void didUpdateWidget(_StatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detailed == widget.detailed) return;
    final opened = widget.detailed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (opened) {
        _detailsTitle.requestFocus();
        return;
      }
      // Back on the front, the focus returns to the button that opened them.
      _secondary.descendants
          .where((node) => node.canRequestFocus && !node.skipTraversal)
          .firstOrNull
          ?.requestFocus();
    });
  }

  @override
  void dispose() {
    _detailsTitle.dispose();
    _secondary.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  Future<void> _restartCore(CoreAction core) async {
    try {
      await core.restartCore();
    } catch (error) {
      dialogs.showBanner(error.toString(), level: BannerLevel.error);
    }
  }

  void _install(BuildContext context) {
    final action = ref.read(commonActionProvider.notifier);
    Navigator.of(context).pop();
    unawaited(action.installUpdate());
  }

  /// Asks module by module, each as it stands when its turn comes, until the
  /// card goes or a prompt is dismissed.
  Future<void> _reviewModules(BuildContext context) async {
    final ids = [
      for (final module in ref.read(mitmModulesToAgreeProvider)) module.id,
    ];
    for (final id in ids) {
      if (!context.mounted) {
        return;
      }
      final module = ref
          .read(mitmModulesToAgreeProvider)
          .where((item) => item.id == id)
          .firstOrNull;
      if (module != null && !await answerMitmModule(ref, module)) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final asking = widget.asking;
    final confirming = widget.confirming;
    final onAsk = widget.onAsk;
    final onUnask = widget.onUnask;
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final action = ref.read(commonActionProvider.notifier);
    final level = SurfaceLevel.floatingOf(colorScheme);
    final neutral = level.next.colorOf(colorScheme);
    final core = ref.read(coreActionProvider.notifier);
    final effects = status.preview == null
        ? (
            restartCore: () => unawaited(_restartCore(core)),
            stopDownload: action.cancelUpdateDownload,
            install: () => _install(context),
            discard: ref.watch(updateInstallCommittedProvider)
                ? null
                : () => unawaited(action.discardUpdate()),
            reviewModules: () => unawaited(_reviewModules(context)),
          )
        : (
            restartCore: _inert,
            stopDownload: _inert,
            install: _inert,
            discard: _inert,
            reviewModules: _inert,
          );
    _CardAction primary(
      String label,
      VoidCallback? onPressed,
      (Color, Color) colors,
    ) => (
      label: label,
      onPressed: onPressed,
      background: colors.$1,
      foreground: colors.$2,
    );
    final (
      tint,
      hero,
      title,
      body,
      mainAction,
      secondaryLabel,
      busyText,
      details,
    ) = switch (status) {
      HelperLiveStatus() => _helperCard(context, status),
      CoreLiveStatus(phase: CoreStatus.disconnected) => (
        colorScheme.errorContainer,
        const _CoreHero(CoreStatus.disconnected),
        appLocalizations.coreStopped,
        (status.preview == null ? ref.watch(coreStopReasonProvider) : null) ??
            appLocalizations.coreStoppedDesc,
        primary(appLocalizations.restartCore, effects.restartCore, (
          colorScheme.error,
          colorScheme.onError,
        )),
        null,
        null,
        null,
      ),
      CoreLiveStatus(phase: CoreStatus.connecting) => (
        colorScheme.primaryContainer,
        const _CoreHero(CoreStatus.connecting),
        appLocalizations.coreStarting,
        appLocalizations.coreStartingDesc,
        null,
        null,
        null,
        null,
      ),
      CoreLiveStatus() => (
        neutral,
        const _CoreHero(CoreStatus.connected),
        appLocalizations.coreRunning,
        appLocalizations.coreRunningDesc,
        primary(appLocalizations.forceRestartCore, onAsk, (
          neutral,
          colorScheme.onSurface,
        )),
        null,
        null,
        null,
      ),
      UpdateStatus(download: final UpdateDownloading download) => (
        colorScheme.primaryContainer,
        _DownloadHero(download: download),
        appLocalizations.downloadingUpdate,
        _progressText(download),
        primary(appLocalizations.cancel, onAsk, (
          neutral,
          colorScheme.onSurface,
        )),
        null,
        null,
        null,
      ),
      UpdateStatus(download: final UpdateReady download) => (
        colorScheme.successContainer,
        _ReadyHero(tag: download.tag, onDiscard: effects.discard),
        appLocalizations.updateReady,
        _readyTip(appLocalizations),
        primary(appLocalizations.installUpdate, effects.install, (
          colorScheme.success,
          colorScheme.onSuccess,
        )),
        null,
        null,
        null,
      ),
      ResourcesStatus(:final items) => (
        neutral,
        _ResourcesHero(items: items),
        appLocalizations.updatingResources,
        appLocalizations.updatingResourcesCount(items.length),
        null,
        // The first rows are on the front; the whole list is behind View all.
        items.length > _HeroRows.shown ? appLocalizations.viewAll : null,
        null,
        items.length > _HeroRows.shown
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [for (final item in items) _ResourceRow(item)],
              )
            : null,
      ),
      MitmConsentStatus(:final names) => (
        colorScheme.warningContainer,
        _ConsentHero(names: names),
        appLocalizations.mitmModulesTurnedOff,
        names.length == 1
            ? appLocalizations.mitmModuleTurnedOffDesc(names.single)
            : appLocalizations.mitmModulesTurnedOffDesc(names.length),
        primary(appLocalizations.view, effects.reviewModules, (
          colorScheme.warning,
          colorScheme.onWarning,
        )),
        null,
        null,
        null,
      ),
    };
    final detailed = widget.detailed && details != null;
    final ask = switch (_confirmOf(status)) {
      _Confirm.forceRestart => (
        title: appLocalizations.forceRestartCoreAsk,
        body: appLocalizations.forceRestartCoreAskDesc,
        label: appLocalizations.restart,
        run: effects.restartCore,
      ),
      _Confirm.stopDownload => (
        title: appLocalizations.stopUpdateDownloadTip,
        body: appLocalizations.stopUpdateDownloadDesc,
        label: appLocalizations.stopDownload,
        run: effects.stopDownload,
      ),
      null => null,
    };
    final heroBox = DecoratedBox(
      decoration: ShapeDecoration(
        color: tint,
        shape: AppShape.all(_heroCorner),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _heroHeight),
        child: hero,
      ),
    );
    final footnote = AppTextStyle.footnote
        .of(context)
        .copyWith(
          color: colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    // The front says the title and at most two lines; the details say all.
    Widget lines(String title, String body) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          liveRegion: status is HelperLiveStatus,
          child: Text(title, style: AppTextStyle.headline.of(context)),
        ),
        const SizedBox(height: 2),
        Text(
          body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: footnote,
        ),
      ],
    );
    final restText = lines(title, body);
    final askText = ask == null ? null : lines(ask.title, ask.body);
    ButtonStyle buttonStyle(Color background, Color foreground) =>
        ButtonStyle.from(
          backgroundColor: background,
          foregroundColor: foreground,
          minimumSize: const Size.fromHeight(_actionHeight),
          tapTargetSize: TapTargetSize.shrinkWrap,
          shape: AppShape.full,
        );
    final button = busyText != null
        ? _BusyRow(text: busyText)
        : mainAction != null
        ? FilledButton(
            onPressed: mainAction.onPressed,
            style: buttonStyle(mainAction.background, mainAction.foreground),
            child: AnimatedSwitcher(
              duration: _labelFade,
              child: Text(
                mainAction.label,
                key: ValueKey(mainAction.label),
                textAlign: TextAlign.center,
              ),
            ),
          )
        : null;
    final secondary = secondaryLabel != null && details != null && !detailed
        ? Focus(
            focusNode: _secondary,
            canRequestFocus: false,
            skipTraversal: true,
            child: TextButton(
              onPressed: widget.onDetails,
              style: ButtonStyle.from(
                minimumSize: const Size.fromHeight(_secondaryHeight),
                tapTargetSize: TapTargetSize.shrinkWrap,
                shape: AppShape.full,
              ),
              child: Text(secondaryLabel, textAlign: TextAlign.center),
            ),
          )
        : null;
    final askButtons = ask == null
        ? null
        : Row(
            spacing: _askGap,
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onUnask,
                  style: buttonStyle(neutral, colorScheme.onSurface),
                  child: Text(appLocalizations.cancel),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ask.run();
                    onUnask();
                  },
                  style: buttonStyle(colorScheme.error, colorScheme.onError),
                  child: Text(ask.label),
                ),
              ),
            ],
          );
    Widget fade(double asked, Widget rest, Widget? question) {
      if (question == null || asked == 0) return rest;
      // Both lay out in full, so the card is as tall as the taller of them
      // and neither is cut.
      return Stack(
        alignment: AlignmentDirectional.topStart,
        children: [
          IgnorePointer(
            ignoring: confirming,
            child: Opacity(opacity: 1 - asked, child: rest),
          ),
          IgnorePointer(
            ignoring: !confirming,
            child: Opacity(opacity: asked, child: question),
          ),
        ],
      );
    }

    final front = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heroBox,
        Padding(
          padding: const EdgeInsets.fromLTRB(8, _textTop, 8, 0),
          child: AnimatedBuilder(
            animation: asking,
            builder: (context, _) => fade(asking.value, restText, askText),
          ),
        ),
      ],
    );
    final detailView = detailed
        ? _DetailsView(
            title: title,
            titleFocus: _detailsTitle,
            onBack: widget.onBack,
            child: details,
          )
        : null;
    return SurfaceScope(
      level: level,
      child: Padding(
        padding: const EdgeInsets.all(_cardInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The body scrolls once the card can grow no taller; the buttons
            // stay at the bottom.
            Flexible(
              child: SingleChildScrollView(
                controller: _bodyScroll,
                child: detailView ?? front,
              ),
            ),
            if (secondary != null || button != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  8,
                  _actionGap,
                  8,
                  _actionBottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _actionGap,
                  children: [
                    ?secondary,
                    if (button != null)
                      AnimatedBuilder(
                        animation: asking,
                        builder: (context, _) =>
                            fade(asking.value, button, askButtons),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The helper card, from [macHelperCardView] and its actions only: the
  /// tone's colors, the helper glyph, the card's title and detail, its
  /// primary action unless an operation runs, and its details or steps
  /// behind the secondary action.
  (Color, Widget, String, String, _CardAction?, String?, String?, Widget?)
  _helperCard(BuildContext context, HelperLiveStatus status) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final view = status.view;
    final colors = macHelperToneColors(colorScheme, status.tone);
    final flow = status.flow;
    final waiting =
        view.kind == MacHelperCardKind.starting ||
        view.kind == MacHelperCardKind.switchingHelper;
    // A wait, or an operation in flight: its text stands in for the button,
    // so nothing can be sent twice.
    final busyText = waiting || status.busy && view.progress != null
        ? view.progress ?? l.macHelperChecking
        : null;
    final primaryAction = view.primary;
    final mainAction = primaryAction == null || busyText != null
        ? null
        : (
            label: macHelperActionLabel(l, primaryAction),
            onPressed: flow == null || status.busy
                ? (flow == null ? _inert : null)
                : () => runMacHelperAction(flow, primaryAction),
            background: colors.accent,
            foreground: colors.onAccent,
          );
    final raw = view.rawDetail ?? '';
    final secondaryAction = switch (view.secondary) {
      MacHelperCardAction.viewSteps when view.steps.isNotEmpty =>
        MacHelperCardAction.viewSteps,
      MacHelperCardAction.viewDetails when raw.isNotEmpty =>
        MacHelperCardAction.viewDetails,
      _ => null,
    };
    final footnote = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant, height: 18 / 13);
    final details = secondaryAction == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              if (view.detail case final detail?) Text(detail, style: footnote),
              for (final (index, step) in view.steps.indexed)
                Semantics(
                  label: l.macHelperStepLabel('${index + 1}', step),
                  excludeSemantics: true,
                  child: Text('${index + 1}. $step', style: footnote),
                ),
              if (raw.isNotEmpty) ...[
                SelectableText(
                  raw,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: colorScheme.onSurface),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () =>
                        unawaited(Clipboard.setData(ClipboardData(text: raw))),
                    child: Text(l.copy),
                  ),
                ),
              ],
            ],
          );
    return (
      colors.container,
      ExcludeSemantics(
        child: _BadgeHero(
          color: colors.accent,
          glyph: AppGlyphs.helperDaemonSmall,
          glyphColor: colors.onAccent,
          chips: [
            if (widget.helperRequired)
              Flexible(
                child: Text(
                  l.macHelperRequiredTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: colors.onContainer),
                ),
              ),
          ],
        ),
      ),
      view.title,
      view.detail ?? '',
      mainAction,
      secondaryAction == null ? null : macHelperActionLabel(l, secondaryAction),
      busyText,
      details,
    );
  }
}

/// An operation's text in place of the card's button while it runs.
class _BusyRow extends StatelessWidget {
  const _BusyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _actionHeight),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            const ActivityIndicator(size: 14),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyle.subheadline.of(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card's details in place of its front: back, the title, which takes the
/// focus, and everything the front left out.
class _DetailsView extends StatelessWidget {
  const _DetailsView({
    required this.title,
    required this.titleFocus,
    required this.onBack,
    required this.child,
  });

  final String title;
  final FocusNode titleFocus;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 4,
          children: [
            DashboardIconButton(
              glyph: AppGlyphs.chevronBack,
              tooltip: l.back,
              onPressed: onBack,
            ),
            Expanded(
              child: Focus(
                focusNode: titleFocus,
                child: Semantics(
                  header: true,
                  focused: titleFocus.hasFocus,
                  child: Text(title, style: AppTextStyle.headline.of(context)),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: child,
        ),
      ],
    );
  }
}

/// The app and the core, joined by what lies between them now: a broken line
/// when the core stopped, a spinner while it starts, a line once it runs.
class _CoreHero extends StatelessWidget {
  const _CoreHero(this.phase);

  static const _linkWidth = 32.0;

  final CoreStatus phase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final nodeFill = SurfaceLevel.floatingOf(colorScheme).colorOf(colorScheme);
    final (labelColor, coreFill, coreColor, coreLabel) = switch (phase) {
      CoreStatus.disconnected => (
        colorScheme.onErrorContainer,
        colorScheme.error,
        colorScheme.onError,
        colorScheme.error,
      ),
      CoreStatus.connecting => (
        colorScheme.onPrimaryContainer,
        nodeFill,
        colorScheme.primary,
        colorScheme.onPrimaryContainer,
      ),
      CoreStatus.connected => (
        colorScheme.onSurfaceVariant,
        colorScheme.success,
        colorScheme.onSuccess,
        colorScheme.success,
      ),
    };
    final link = switch (phase) {
      CoreStatus.disconnected => SizedBox(
        width: _linkWidth,
        height: 2,
        child: CustomPaint(painter: _DashPainter(colorScheme.error)),
      ),
      CoreStatus.connecting => const SizedBox(
        width: _linkWidth,
        child: Center(child: ActivityIndicator(size: 16)),
      ),
      CoreStatus.connected => SizedBox(
        width: _linkWidth,
        height: 2,
        child: ColoredBox(color: colorScheme.success),
      ),
    };
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Node(
            glyph: AppGlyphs.devices,
            label: appLocalizations.app,
            fill: nodeFill,
            color: colorScheme.onSurfaceVariant,
            labelColor: labelColor,
          ),
          Padding(
            padding: EdgeInsets.only(bottom: _Node.labelRoom),
            child: link,
          ),
          _Node(
            glyph: AppGlyphs.cpu,
            label: appLocalizations.core,
            fill: coreFill,
            color: coreColor,
            labelColor: coreLabel,
            emphasized: phase != CoreStatus.connecting,
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.glyph,
    required this.label,
    required this.fill,
    required this.color,
    required this.labelColor,
    this.emphasized = false,
  });

  static const size = 44.0;
  static const _labelGap = 6.0;
  static final labelRoom = _labelGap + AppTextStyle.caption1.leading;

  final Glyph glyph;
  final String label;
  final Color fill;
  final Color color;
  final Color labelColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: _labelGap,
        children: [
          SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              decoration: ShapeDecoration(color: fill, shape: AppShape.circle),
              child: Center(child: GlyphIcon(glyph, size: 22, color: color)),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption1
                .of(context, emphasized: emphasized)
                .copyWith(color: labelColor),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = dash / 2; x < size.width; x += dash * 2) {
      canvas.drawLine(Offset(x, y), Offset(x + dash / 2, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

/// The download's ring with its percentage alone inside, and the whole
/// target version under it, wrapping as it must; the hero grows to fit.
class _DownloadHero extends StatelessWidget {
  const _DownloadHero({required this.download});

  static const _ring = 132.0;

  final UpdateDownloading download;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final total = download.total;
    final value = total > 0 ? download.received / total : null;
    const tabular = [FontFeature.tabularFigures()];
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            SizedBox.square(
              dimension: _ring,
              child: CustomPaint(
                painter: _TicksPainter(
                  value: value ?? 0,
                  on: colorScheme.primary,
                  off: colorScheme.primary.withValues(alpha: 0.22),
                ),
                child: Center(
                  child: Text(
                    value == null
                        ? download.received.traffic.show
                        : '${(value * 100).floor()}%',
                    maxLines: 1,
                    style: AppTextStyle.title1
                        .of(context, emphasized: true)
                        .copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontFeatures: tabular,
                        ),
                  ),
                ),
              ),
            ),
            Text(
              displayVersionLabel(download.tag),
              textAlign: TextAlign.center,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontFeatures: tabular,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicksPainter extends CustomPainter {
  const _TicksPainter({
    required this.value,
    required this.on,
    required this.off,
  });

  static const _count = 60;

  final double value;
  final Color on;
  final Color off;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 4;
    final lit = (value.clamp(0.0, 1.0) * _count).round();
    final paint = Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _count; i++) {
      final angle = i / _count * math.pi * 2 - math.pi / 2;
      final inner = outer - (i % 5 == 0 ? 13 : 8);
      final direction = Offset(math.cos(angle), math.sin(angle));
      paint.color = i < lit ? on : off;
      canvas.drawLine(
        center + direction * outer,
        center + direction * inner,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TicksPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.on != on ||
      oldDelegate.off != off;
}

class _BadgeHero extends StatelessWidget {
  const _BadgeHero({
    required this.color,
    required this.glyph,
    required this.glyphColor,
    required this.chips,
    this.fill,
  });

  final Color color;
  final Glyph glyph;
  final Color glyphColor;
  final double? fill;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            SizedBox.square(
              dimension: 60,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: color,
                  shape: AppShape.circle,
                ),
                child: Center(
                  child: GlyphIcon(
                    glyph,
                    size: 28,
                    fill: fill,
                    color: glyphColor,
                  ),
                ),
              ),
            ),
            if (chips.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: chips),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: SurfaceLevel.floatingOf(colorScheme).colorOf(colorScheme),
        shape: AppShape.full,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ),
    );
  }
}

/// A check over the two versions, one under the other: the one running now
/// and the one ready to install, each wrapping as it must, the build number
/// smaller after the version. The hero grows to fit.
class _ReadyHero extends StatelessWidget {
  const _ReadyHero({required this.tag, required this.onDiscard});

  final String tag;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final l = context.appLocalizations;
    final info = globalState.packageInfo;
    final next = versionLabelParts(tag.replaceFirst(RegExp('^v'), ''));
    const tabular = [FontFeature.tabularFigures()];
    Widget line(
      String version,
      String? build, {
      required Color color,
      bool emphasized = false,
    }) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: version,
            style: AppTextStyle.footnote
                .of(context, emphasized: emphasized)
                .copyWith(color: color, fontFeatures: tabular),
          ),
          if (build != null && build.isNotEmpty)
            TextSpan(
              text: ' ($build)',
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: color, fontFeatures: tabular),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 60,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colorScheme.success,
                      shape: AppShape.circle,
                    ),
                    child: Center(
                      child: GlyphIcon(
                        AppGlyphs.check,
                        size: 28,
                        color: colorScheme.onSuccess,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                line(
                  l.updateCurrentVersion(info.version),
                  info.buildNumber,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                line(
                  l.updateNewVersion(next.version),
                  next.build,
                  color: colorScheme.onSuccessContainer,
                  emphasized: true,
                ),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          top: 8,
          end: 8,
          child: DashboardIconButton(
            glyph: AppGlyphs.close,
            tooltip: context.appLocalizations.cancel,
            onPressed: onDiscard,
          ),
        ),
      ],
    );
  }
}

class _ConsentHero extends StatelessWidget {
  const _ConsentHero({required this.names});

  static const _shownNames = 2;

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final rest = names.length - _shownNames;
    return _BadgeHero(
      color: colorScheme.warning,
      glyph: AppGlyphs.puzzle,
      glyphColor: colorScheme.onWarning,
      fill: 1,
      chips: [
        for (final text in [...names.take(_shownNames), if (rest > 0) '+$rest'])
          Flexible(child: _HeroChip(text, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ResourcesHero extends StatelessWidget {
  const _ResourcesHero({required this.items});

  final List<UpdatingResource> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _HeroRows(
        children: [
          for (final item in items.take(_HeroRows.shown)) _ResourceRow(item),
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow(this.item);

  final UpdatingResource item;

  @override
  Widget build(BuildContext context) {
    return _HeroRow(
      leading: GlyphIcon(
        item.isProfile ? AppGlyphs.profiles : AppGlyphs.resources,
        size: 18,
        color: context.colorScheme.onSurfaceVariant,
      ),
      label: item.name,
      trailing: const ActivityIndicator(size: 16),
    );
  }
}

class _HeroRows extends StatelessWidget {
  const _HeroRows({required this.children});

  static const shown = 3;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 264,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: children,
        ),
      ),
    );
  }
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.leading, required this.label, this.trailing});

  final Widget leading;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final trailing = this.trailing;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: SurfaceLevel.floatingOf(colorScheme).colorOf(colorScheme),
          shape: AppShape.sm,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            spacing: 10,
            children: [
              leading,
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.subheadline.of(context),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
