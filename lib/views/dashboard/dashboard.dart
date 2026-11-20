import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/mitm_status.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'edit.dart';
import 'layout.dart';
import 'style.dart';
import 'widget_registry.dart';
import 'widgets/widgets.dart';

// Narrower columns leave a pair of service cells too tight for a status, so
// the grid stacks them in one.
const _servicePairColumnMin = 290.0;

const _maxColumnWidth = 440.0;

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key, this.platform});

  /// The host's platform when null.
  final SupportPlatform? platform;

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  var _editing = false;
  final _cardKeys = <DashboardWidget, GlobalKey>{};
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = sheetScrollController(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setEditing(bool editing) {
    setState(() => _editing = editing);
  }

  GlobalKey _cardKeyOf(DashboardWidget widget) =>
      _cardKeys.putIfAbsent(widget, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final platform = widget.platform ?? SupportPlatform.currentPlatform;
    final viewSize = ref.watch(viewSizeProvider);
    final sideWidth = ref.watch(sideWidthProvider);
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
    final size = Size(viewSize.width - sideWidth, viewSize.height) / scale;
    final editable = !DashboardDensity.of(size).isDesktop;
    if (!editable) {
      _editing = false;
    }
    final editing = _editing;
    final gap = cardSpacingOf(context, ref.watch(viewModeProvider));
    final appLocalizations = context.appLocalizations;
    // Decryption is said on the dashboard alone, and by the tray's dot.
    return ScaffoldBarStatus(
      status: mitmFeature ? const MitmBarStatus() : null,
      child: Scaffold(
        backgroundColor: DashboardColors.of(context).page,
        title: editing
            ? appLocalizations.editDashboard
            : appLocalizations.dashboard,
        actions: [
          if (!editing) const LiveStatusButton(),
          if (editable && !editing)
            AppBarActionButton(
              data: IconButtonData(
                glyph: AppGlyphs.edit,
                tooltip: appLocalizations.editDashboard,
                onPressed: () => _setEditing(true),
              ),
            ),
        ],
        confirmationAction: editing
            ? IconButtonData(
                glyph: AppGlyphs.check,
                tooltip: appLocalizations.done,
                onPressed: () => _setEditing(false),
              )
            : null,
        // The providers learn a resize a frame late, too late for the cards.
        body: LayoutBuilder(
          builder: (context, constraints) {
            final room = constraints.biggest / scale;
            final layout = DashboardDensity.of(room);
            return DashboardDensityScope(
              density: layout,
              scale: scale,
              child: layout.isDesktop
                  ? _DesktopDashboard(
                      platform: platform,
                      columns: dashboardColumnsOf(room.width),
                      gap: gap,
                    )
                  : _MobileDashboard(
                      controller: _controller,
                      platform: platform,
                      gap: gap,
                      editing: editing,
                      cardKeyOf: _cardKeyOf,
                      onDone: () => _setEditing(false),
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// Four columns fill the window, the tables taking what the rows above them
/// leave. A window too short for the tables, and every two column one, gets
/// the summary cards instead, so no list scrolls inside a page that scrolls.
class _DesktopDashboard extends StatelessWidget {
  const _DesktopDashboard({
    required this.platform,
    required this.columns,
    required this.gap,
  });

  final SupportPlatform platform;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final compact = density.isCompact;
    final scale = DashboardDensityScope.scaleOf(context);
    final base = EdgeInsetsDirectional.fromSTEB(
      16,
      context.contentTopPadding,
      24,
      24 + MediaQuery.paddingOf(context).bottom,
    );
    // Reserve the status card's own height (its chips and cells stacked);
    // the row itself sizes to content.
    final topHeight = (compact ? 174 : 186) * math.max(1, scale);
    final controlHeight = (compact ? 56 : 64) * scale;
    final middleHeight = (compact ? 152 : 176) * scale;
    final tablesHeight = connectionsTableMinHeight(density, scale);
    final summaryHeight = (compact ? 112 : 120) * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final room =
            constraints.maxWidth - base.horizontal - gap * (columns - 1);
        final column = math.min(room / columns, _maxColumnWidth * scale);
        final inset = (room - column * columns) / 2;
        final padding = base.copyWith(
          start: base.start + inset,
          end: base.end + inset,
        );
        double span(int columns) => column * columns + gap * (columns - 1);
        Widget row(List<(int, Widget)> cards) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            for (final (columns, card) in cards)
              SizedBox(
                width: span(columns),
                child: RepaintBoundary(child: card),
              ),
          ],
        );
        Widget sized(double height, Widget child) =>
            SizedBox(height: height, child: child);
        Widget topRow(Widget child) => IntrinsicHeight(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 160),
            child: child,
          ),
        );
        final switches =
            DashboardWidget.networkTakeover.platforms.contains(platform)
            ? const [
                (1, NetworkTakeoverTile(TakeoverSwitch.systemProxy)),
                (1, NetworkTakeoverTile(TakeoverSwitch.tun)),
              ]
            : const [(2, VpnTile())];
        final half = columns ~/ 2;
        final summaries = row([
          (half, const ConnectionStatsCard()),
          (half, const ProxyGroupsSummaryCard()),
        ]);
        if (columns == 2) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: Column(
              spacing: gap,
              children: [
                topRow(const RepaintBoundary(child: CurrentOutboundCard())),
                topRow(
                  row(const [
                    (1, SpeedCard(direction: TrafficDirection.upload)),
                    (1, SpeedCard(direction: TrafficDirection.download)),
                  ]),
                ),
                sized(
                  controlHeight,
                  const RepaintBoundary(child: OutboundModeBar()),
                ),
                sized(controlHeight, row(switches)),
                sized(
                  middleHeight,
                  row(const [(1, IntranetIpCard()), (1, ProfilesCard())]),
                ),
                sized(
                  middleHeight,
                  row(const [(1, ServiceStatusCard()), (1, MemoryInfo())]),
                ),
                sized(summaryHeight, summaries),
              ],
            ),
          );
        }
        final rows = [
          topRow(
            row(const [
              (2, CurrentOutboundCard()),
              (1, SpeedCard(direction: TrafficDirection.upload)),
              (1, SpeedCard(direction: TrafficDirection.download)),
            ]),
          ),
          sized(
            controlHeight,
            row([(2, const OutboundModeBar()), ...switches]),
          ),
          sized(
            middleHeight,
            row([
              (1, const IntranetIpCard()),
              (1, const ProfilesCard()),
              (
                1,
                ServiceStatusCard(
                  columns: column >= _servicePairColumnMin * scale ? 2 : 1,
                ),
              ),
              (1, const MemoryInfo()),
            ]),
          ),
        ];
        final rowsHeight =
            padding.vertical +
            topHeight +
            controlHeight +
            middleHeight +
            gap * 3;
        final tablesFit = constraints.maxHeight >= rowsHeight + tablesHeight;
        final fills = constraints.maxHeight >= rowsHeight + summaryHeight;
        // The rows take what they need, the status card more than reserved
        // when its tags wrap; the last block fills what is left of the
        // window, but never less than its minimum: rather than shrink it,
        // the page scrolls.
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: padding,
            child: _FillLast(
              gap: gap,
              fill: fills && constraints.maxHeight.isFinite
                  ? constraints.maxHeight - padding.vertical
                  : null,
              lastMin: tablesFit ? tablesHeight : summaryHeight,
              children: [
                ...rows,
                if (tablesFit)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: gap,
                    children: const [
                      Expanded(
                        flex: 3,
                        child: RepaintBoundary(child: ConnectionsTableCard()),
                      ),
                      Expanded(
                        flex: 2,
                        child: RepaintBoundary(child: ProxyGroupsCard()),
                      ),
                    ],
                  )
                else
                  summaries,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A column whose children before the last take their own height, [gap]
/// apart, and whose last fills up to [fill] in all, but never less than
/// [lastMin]; without [fill] it is [lastMin] high.
class _FillLast extends MultiChildRenderObjectWidget {
  const _FillLast({
    required this.gap,
    required this.fill,
    required this.lastMin,
    required super.children,
  });

  final double gap;
  final double? fill;
  final double lastMin;

  @override
  _RenderFillLast createRenderObject(BuildContext context) =>
      _RenderFillLast(gap: gap, fill: fill, lastMin: lastMin);

  @override
  void updateRenderObject(BuildContext context, _RenderFillLast renderObject) {
    renderObject
      ..gap = gap
      ..fill = fill
      ..lastMin = lastMin;
  }
}

class _FillLastParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFillLast extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FillLastParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FillLastParentData> {
  _RenderFillLast({
    required double gap,
    required double? fill,
    required double lastMin,
  }) : _gap = gap,
       _fill = fill,
       _lastMin = lastMin;

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double? _fill;
  set fill(double? value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsLayout();
  }

  double _lastMin;
  set lastMin(double value) {
    if (value == _lastMin) return;
    _lastMin = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FillLastParentData) {
      child.parentData = _FillLastParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    var y = 0.0;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _FillLastParentData;
      final last = child == lastChild;
      if (child != firstChild) y += _gap;
      if (last) {
        final fill = _fill;
        final height = math.max(_lastMin, fill == null ? 0.0 : fill - y);
        child.layout(BoxConstraints.tightFor(width: width, height: height));
      } else {
        child.layout(
          BoxConstraints.tightFor(width: width),
          parentUsesSize: true,
        );
      }
      data.offset = Offset(0, y);
      y += last ? child.constraints.maxHeight : child.size.height;
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _MobileDashboard extends ConsumerWidget {
  const _MobileDashboard({
    required this.controller,
    required this.platform,
    required this.gap,
    required this.editing,
    required this.cardKeyOf,
    required this.onDone,
  });

  final ScrollController controller;
  final SupportPlatform platform;
  final double gap;
  final bool editing;
  final GlobalKey Function(DashboardWidget widget) cardKeyOf;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      dashboardStateProvider.select((state) => state.dashboardWidgets),
    );
    final top = context.contentTopPadding;
    final bottom = 16 + context.bottomInset;
    return CustomScrollView(
      controller: controller,
      // A viewport per card lays them all out and holds the scroll end still.
      scrollCacheExtent: editing
          ? ScrollCacheExtent.viewport(DashboardWidget.values.length.toDouble())
          : null,
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final side = dashboardMobileSideOf(constraints.crossAxisExtent);
            final widgets = [
              for (final widget in saved)
                if (widget.platforms.contains(platform)) widget,
            ];
            if (editing) {
              return DashboardEditor(
                platform: platform,
                widgets: widgets,
                cardKeyOf: cardKeyOf,
                padding: EdgeInsets.fromLTRB(side, top, side, bottom),
                gap: gap,
                onDone: onDone,
              );
            }
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(side, top, side, bottom),
              // A lazy list estimates the cards it has not laid out from the
              // ones it has; cards this uneven move the scroll end as it goes.
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: [
                    for (final widget in widgets)
                      RepaintBoundary(
                        key: cardKeyOf(widget),
                        child: widget.card,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
