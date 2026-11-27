import 'dart:async';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';
import 'hidden_group_name.dart';
import 'node_fields.dart';
import 'unfold.dart';

const _headerInset = 10.0;
const _headerButtonInset = 4.0;
const _liftDistance = 16.0;
const _groupMinWidth = 360.0;
const _groupMaxColumns = 3;
const _lastRowGrowth = _headerInset - proxyGridSpacing;
const _headerActionsGap = 6.0;
final _headerActionsRow = TonalButtonSize.compact.button + _headerActionsGap;

/// Whether [group]'s name would be cut beside its actions in [width], which
/// then move to a row of their own.
bool _headerStacks(
  BuildContext context,
  Group group,
  double width,
  ProxiesIconStyle iconStyle,
) {
  final scaler = MediaQuery.textScalerOf(context);
  double widthOf(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  final button = TonalButtonSize.compact.button;
  final typeWidth = widthOf(
    group.type.name,
    AppTextStyle.caption1.of(context, emphasized: true),
  );
  final actions = max(button * 2, typeWidth) + _headerActionsGap + button;
  final iconSide = listHeaderHeight - _headerInset * 2;
  final icon = switch (iconStyle) {
    ProxiesIconStyle.filled => iconSide + 12,
    ProxiesIconStyle.plain => iconSide + 12,
    ProxiesIconStyle.hidden => 4.0,
  };
  final name = widthOf(
    group.name,
    AppTextStyle.callout.of(context, emphasized: true),
  );
  return name > width - _headerInset * 2 - icon - actions;
}

class ProxiesListView extends ConsumerStatefulWidget {
  const ProxiesListView({super.key});

  @override
  ConsumerState<ProxiesListView> createState() => _ProxiesListViewState();
}

class _ProxiesListViewState extends ConsumerState<ProxiesListView> {
  late final ScrollController _controller;
  int _columns = 1;
  double _cardWidth = 0;
  Map<String, double> _headerHeights = const {};
  int _groupColumns = 1;
  double _gap = 0;

  @override
  void initState() {
    super.initState();
    _controller = sheetScrollController(context);
    ref.listenManual(proxiesRevealProvider, (_, next) {
      if (next != null) _reveal(next.group, next.serial);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Timer? _revealTimer;

  /// Unfolds a group the rules page asked for, brings it into view and lets
  /// its header's mark fade after a moment.
  void _reveal(String groupName, int serial) {
    final unfoldSet = ref.read(unfoldSetProvider);
    if (!unfoldSet.contains(groupName)) {
      ref.read(proxiesActionProvider.notifier).updateCurrentUnfoldSet({
        ...unfoldSet,
        groupName,
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final offset = _getGroupOffset(groupName);
      _controller.jumpTo(
        offset.clamp(
          _controller.position.minScrollExtent,
          _controller.position.maxScrollExtent,
        ),
      );
    });
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 1500), () {
      if (ref.read(proxiesRevealProvider)?.serial == serial) {
        ref.read(proxiesRevealProvider.notifier).taken();
      }
    });
  }

  void _handleChange(String groupName) {
    _autoScrollToGroup(groupName);
    final tempUnfoldSet = Set<String>.from(ref.read(unfoldSetProvider));
    if (!tempUnfoldSet.remove(groupName)) {
      tempUnfoldSet.add(groupName);
    }
    ref
        .read(proxiesActionProvider.notifier)
        .updateCurrentUnfoldSet(tempUnfoldSet);
  }

  GroupOffsets _getGroupOffsets() {
    final state = ref.read(proxiesListStateProvider);
    final offsets = <double>[];
    final columnOffsets = List.filled(_groupColumns, 0.0);
    for (final (index, group) in state.groups.indexed) {
      final column = index % _groupColumns;
      offsets.add(columnOffsets[column]);
      columnOffsets[column] += _headerHeightOf(group.name) + _gap;
      if (state.currentUnfoldSet.contains(group.name)) {
        columnOffsets[column] += _rowsExtent(
          _rowExtentsOf(group, state.proxyCardType),
        );
      }
    }
    return GroupOffsets(state.groups, offsets);
  }

  List<double> _rowExtentsOf(Group group, ProxyCardType cardType) =>
      nodeRowExtents(
        context,
        group.all,
        columns: _columns,
        cardWidth: _cardWidth,
        proxyCardType: cardType,
      );

  double _headerHeightOf(String groupName) =>
      _headerHeights[groupName] ?? listHeaderHeight;

  double _getGroupOffset(String groupName) {
    if (!_controller.hasClients || _controller.position.maxScrollExtent == 0) {
      return 0;
    }
    return _getGroupOffsets().offsetOf(groupName);
  }

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 24,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    final isElementVisible = start >= visibleStart && end <= visibleEnd;
    if (isElementVisible) {
      return;
    }

    double targetScrollOffset;

    if (end <= visibleStart) {
      targetScrollOffset = start;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      if (visibleTopPart.abs() >= visibleBottomPart.abs()) {
        targetScrollOffset = end - containerHeight + padding;
      } else {
        targetScrollOffset = start;
      }
    }

    targetScrollOffset = targetScrollOffset.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );

    _controller.jumpTo(targetScrollOffset);
  }

  void _autoScrollToGroup(String groupName) {
    final pixels = _controller.position.pixels;
    final offset = _getGroupOffset(groupName);
    _scrollToMakeVisibleWithPadding(
      containerHeight: max(
        _controller.position.viewportDimension - context.contentTopPadding,
        0,
      ),
      pixels: pixels,
      start: offset,
      end: offset + _headerHeightOf(groupName),
    );
  }

  void _scrollToGroupSelected(String groupName) {
    final cardType = ref.read(proxiesListStateProvider).proxyCardType;
    final group = ref.read(proxiesListStateProvider).groups.getGroup(groupName);
    if (group == null) {
      return;
    }
    final rowOffset = selectedRowOffset(
      proxies: group.all,
      selectedProxyName: ref.read(selectedProxyNameProvider(groupName)),
      columns: _columns,
      rowExtents: _rowExtentsOf(group, cardType),
    );
    if (rowOffset == null) {
      return;
    }
    animateScrollTo(_controller, _getGroupOffset(groupName) + rowOffset);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Consumer(
      builder: (_, ref, _) {
        final groups = ref.watch(
          proxiesListStateProvider.select((state) => state.groups),
        );
        final cardType = ref.watch(
          proxiesListStateProvider.select((state) => state.proxyCardType),
        );
        ref.watch(themeSettingProvider.select((state) => state.textScale));
        final iconStyle = ref.watch(
          proxiesStyleSettingProvider.select((state) => state.iconStyle),
        );
        final viewMode = ref.watch(viewModeProvider);
        final proxiesLayout = ref.watch(
          proxiesStyleSettingProvider.select((state) => state.layout),
        );
        final isSearching = ref.watch(
          queryProvider(
            QueryTag.proxies,
          ).select((query) => SearchQuery(query).isNotEmpty),
        );
        return NullStatusSwitcher(
          isEmpty: groups.isEmpty,
          isSearching: isSearching,
          nullStatus: NullStatus(
            illustration: NullStatusIllustration.proxies,
            label: appLocalizations.nullTip(appLocalizations.proxies),
          ),
          child: WidthBuilder(
            builder: (_, maxWidth) {
              final gap = cardSpacingOf(context, viewMode);
              final margin = context.listInsets.margin;
              final width = max(maxWidth - margin * 2, 0.0);
              final groupColumns = viewMode == ViewMode.mobile
                  ? 1
                  : ((width + gap) / (_groupMinWidth + gap)).floor().clamp(
                      1,
                      _groupMaxColumns,
                    );
              final groupWidth =
                  (width - gap * (groupColumns - 1)) / groupColumns;
              final columns = getProxiesColumns(
                max(groupWidth - _headerInset * 2, 0),
                proxiesLayout,
                textScale: MediaQuery.textScalerOf(context).scale(1),
              );
              _columns = columns;
              _cardWidth = nodeCardWidth(
                max(groupWidth - _headerInset * 2, 0),
                columns,
              );
              _groupColumns = groupColumns;
              _gap = gap;
              _headerHeights = {
                for (final group in groups)
                  group.name:
                      listHeaderHeight +
                      (_headerStacks(context, group, groupWidth, iconStyle)
                          ? _headerActionsRow
                          : 0),
              };
              Widget buildGroup(Group group) => _GroupSliver(
                key: _GroupSliverKey(group.name),
                group: group,
                headerHeight: _headerHeightOf(group.name),
                columns: columns,
                cardWidth: _cardWidth,
                cardType: cardType,
                gap: gap,
                onChange: _handleChange,
                onScrollToSelected: _scrollToGroupSelected,
              );
              return Scrollbar(
                controller: _controller,
                thumbVisibility: true,
                child: CustomScrollView(
                  key: proxiesListStoreKey,
                  controller: _controller,
                  slivers: [
                    PinnedHeaderSliver(
                      child: SizedBox(height: context.contentTopPadding),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: margin),
                      sliver: groupColumns == 1
                          ? SliverMainAxisGroup(
                              slivers: groups.map(buildGroup).toList(),
                            )
                          : SliverCrossAxisGroup(
                              slivers: [
                                for (
                                  var column = 0;
                                  column < groupColumns;
                                  column++
                                ) ...[
                                  if (column > 0)
                                    SliverConstrainedCrossAxis(
                                      maxExtent: gap,
                                      sliver: const SliverToBoxAdapter(),
                                    ),
                                  SliverCrossAxisExpanded(
                                    flex: 1,
                                    sliver: SliverMainAxisGroup(
                                      slivers: [
                                        for (
                                          var index = column;
                                          index < groups.length;
                                          index += groupColumns
                                        )
                                          buildGroup(groups[index]),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: 16 + context.bottomInset),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

double _rowsExtent(List<double> rowExtents) =>
    rowExtents.isEmpty ? 0 : sumExtents(rowExtents) + _lastRowGrowth;

class _GroupSliverKey extends ValueKey<String> {
  const _GroupSliverKey(super.value);
}

/// Watches only its own group's fold state, so folding one group leaves the
/// cards of every other group untouched, and keeps its rows sliver while the
/// inputs that shape it are equal.
class _GroupSliver extends ConsumerStatefulWidget {
  const _GroupSliver({
    super.key,
    required this.group,
    required this.headerHeight,
    required this.columns,
    required this.cardWidth,
    required this.cardType,
    required this.gap,
    required this.onChange,
    required this.onScrollToSelected,
  });

  final Group group;
  final double headerHeight;
  final int columns;
  final double cardWidth;
  final ProxyCardType cardType;
  final double gap;
  final void Function(String groupName) onChange;
  final void Function(String groupName) onScrollToSelected;

  @override
  ConsumerState<_GroupSliver> createState() => _GroupSliverState();
}

class _GroupSliverState extends ConsumerState<_GroupSliver>
    with SingleTickerProviderStateMixin {
  Widget? _rows;
  (List<double>, double)? _rowsShape;
  List<double> _unfoldedExtents = const [];
  late final _controller = AnimationController(
    vsync: this,
    value: ref.read(unfoldSetProvider).contains(widget.group.name) ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((_) => setState(() {}));
    ref.listenManual(
      unfoldSetProvider.select((state) => state.contains(widget.group.name)),
      (_, isExpand) => _handleUnfold(isExpand),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleUnfold(bool isExpand) {
    UnfoldMotion.run(
      _controller,
      open: isExpand,
      animate: !context.disableAnimations,
    );
  }

  @override
  void didUpdateWidget(_GroupSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.group != oldWidget.group ||
        widget.columns != oldWidget.columns ||
        widget.cardType != oldWidget.cardType) {
      _rows = null;
    }
  }

  List<double> _extents = const [];

  List<double> _rowExtents() => nodeRowExtents(
    context,
    widget.group.all,
    columns: widget.columns,
    cardWidth: widget.cardWidth,
    proxyCardType: widget.cardType,
  );

  Widget _buildCard(Proxy proxy) {
    final group = widget.group;
    final cardType = widget.cardType;
    return MemoBuilder(
      inputs: [proxy, group.name, group.type, group.testUrl, cardType],
      builder: (context) => SurfaceScope(
        level: context.raisedSurfaceLevel,
        child: Padding(
          padding: const EdgeInsets.only(bottom: proxyGridSpacing),
          child: ProxyCard(
            key: ValueKey('${group.name}.${proxy.name}'),
            testUrl: group.testUrl,
            type: cardType,
            groupType: group.type,
            proxy: proxy,
            groupName: group.name,
          ),
        ),
      ),
    );
  }

  /// Rows past the [count] the unfolding shows stay hidden until it settles,
  /// and build one after another behind the ones it shows.
  Widget _buildRows(List<double> extents, double unfoldingExtent, int count) {
    final proxies = widget.group.all;
    final columns = widget.columns;
    final ends = [
      for (var row = 0, end = 0.0; row < extents.length; row++)
        end += extents[row],
    ];
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: _headerInset),
      sliver: SliverGrid(
        gridDelegate: NodeGridDelegate(columns: columns, rowExtents: extents),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final row = index ~/ columns;
            final proxy = proxies[index];
            return UnfoldRow(
              key: ValueKey(proxy.name),
              motion: _controller,
              buildAfter: row < count
                  ? max(0.0, 1 - ends[row] / unfoldingExtent)
                  : min(0.6 + 0.1 * (row - count), 0.95),
              builder: (_) => _buildCard(proxy),
            );
          },
          childCount: proxies.length,
          addAutomaticKeepAlives: false,
          findChildIndexCallback: proxyIndexFinder(proxies),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.group.name;
    final isExpand = ref.watch(
      unfoldSetProvider.select((state) => state.contains(groupName)),
    );
    final unfolded = _controller.isCompleted;
    _extents = _controller.isDismissed ? const [] : _rowExtents();
    Widget? rows;
    if (!_controller.isDismissed && widget.group.all.isNotEmpty) {
      final extents = _extents;
      final rowCount = extents.length;
      final height = MediaQuery.sizeOf(context).height;
      var visible = 0;
      for (var end = extents.first; end <= height; end += extents[visible]) {
        if (++visible == rowCount) break;
      }
      final count = min(rowCount, visible + 1);
      final unfoldingExtent =
          sumExtents(extents.take(count)) +
          (count == rowCount ? _lastRowGrowth : 0);
      final shape = _rowsShape;
      if (_rows == null ||
          shape == null ||
          !listEquals(shape.$1, extents) ||
          shape.$2 != unfoldingExtent) {
        _rows = _buildRows(extents, unfoldingExtent, count);
        _rowsShape = (extents, unfoldingExtent);
      }
      if (unfolded) {
        _unfoldedExtents = extents;
      }
      rows = UnfoldSliver(
        motion: _controller,
        unfoldingExtent: unfoldingExtent,
        reach: AppCorner.xl.ap(context),
        decoration: ShapeDecoration(
          color: context.raisedSurfaceLevel.colorOf(context.colorScheme),
          shape: AppShape.vertical(
            top: AppCorner.none,
            bottom: AppCorner.xl.ap(context),
          ),
        ),
        sliver: SliverMainAxisGroup(
          slivers: [
            _rows!,
            const SliverToBoxAdapter(child: SizedBox(height: _lastRowGrowth)),
          ],
        ),
      );
    } else {
      _rows = null;
    }
    Widget buildHeader({double floating = 0, double lift = 0}) => SizedBox(
      height: widget.headerHeight,
      child: ListHeader(
        stacked: widget.headerHeight > listHeaderHeight,
        enterAnimated: false,
        floating: floating,
        lift: lift,
        onScrollToSelected: widget.onScrollToSelected,
        key: ValueKey(groupName),
        isExpand: isExpand,
        unfolded: unfolded,
        unfold: _controller,
        group: widget.group,
        onChange: widget.onChange,
      ),
    );
    return SliverPadding(
      padding: EdgeInsets.only(bottom: widget.gap),
      sliver: SliverMainAxisGroup(
        slivers: [_buildPinnedHeader(isExpand, buildHeader), ?rows],
      ),
    );
  }

  /// Rounds the header and lifts it as its own rows scroll under it, and lets
  /// the shadow go before the end of the group pushes it out. The page color
  /// behind its upper half hides the rows that went under it, which would
  /// otherwise show around its top corners and above it. Every header is laid
  /// out on every pass, so one beyond the cache area builds nothing.
  Widget _buildPinnedHeader(
    bool isExpand,
    Widget Function({double floating, double lift}) buildHeader,
  ) {
    final rowsExtent = isExpand ? _rowsExtent(_unfoldedExtents) : 0.0;
    final headerHeight = widget.headerHeight;
    final groupExtent =
        headerHeight + (_controller.isDismissed ? 0.0 : _rowsExtent(_extents));
    final coversRows = !_controller.isDismissed;
    (double, double, double, Color)? headerState;
    Widget? header;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final beyondCache =
            constraints.remainingCacheExtent <= 0 ||
            constraints.scrollOffset + constraints.cacheOrigin >= groupExtent;
        final under = isExpand
            ? constraints.scrollOffset + constraints.overlap
            : 0.0;
        final state = beyondCache
            ? null
            : (
                (under / _liftDistance).clamp(0.0, 1.0),
                (min(under, rowsExtent - under) / _liftDistance).clamp(
                  0.0,
                  1.0,
                ),
                isExpand ? constraints.overlap : 0.0,
                context.surfaceLevel.colorOf(context.colorScheme),
              );
        if (header != null && state == headerState) {
          return header!;
        }
        headerState = state;
        if (state == null) {
          return header = PinnedHeaderSliver(
            child: SizedBox(height: headerHeight),
          );
        }
        final (floating, lift, cover, pageColor) = state;
        return header = PinnedHeaderSliver(
          child: RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (coversRows)
                  Positioned(
                    top: -cover,
                    left: 0,
                    right: 0,
                    height: cover + headerHeight / 2,
                    child: ColoredBox(color: pageColor),
                  ),
                buildHeader(floating: floating, lift: lift),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ListHeader extends ConsumerWidget {
  final Group group;

  final Function(String groupName) onChange;
  final Function(String groupName) onScrollToSelected;
  final bool isExpand;

  /// Whether the rows have settled under the header, squaring its bottom.
  final bool unfolded;

  final bool enterAnimated;

  /// Puts the actions on a row under the name, which would be cut beside them.
  final bool stacked;

  /// How far the group's own rows have scrolled under the pinned header, as a
  /// fraction of the distance that rounds its bottom corners.
  final double floating;

  /// The shadow that lifts the header off the rows under it.
  final double lift;

  final Animation<double> unfold;

  const ListHeader({
    super.key,
    this.enterAnimated = true,
    this.stacked = false,
    this.floating = 0,
    this.lift = 0,
    required this.group,
    required this.onChange,
    required this.onScrollToSelected,
    required this.isExpand,
    required this.unfolded,
    required this.unfold,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupName = group.name;
    final isDelayTesting = ref.watch(
      delayTestingGroupsProvider.select((state) => state.contains(groupName)),
    );
    final showHiddenTag =
        group.isConfigHidden &&
        ref.watch(
          proxiesStyleSettingProvider.select((state) => state.showHiddenGroups),
        );
    final colorScheme = context.colorScheme;
    final level = floating > 0
        ? SurfaceLevel.floatingOf(colorScheme)
        : context.raisedSurfaceLevel;
    final radius = AppCorner.xl.ap(context);
    final revealed = ref.watch(
      proxiesRevealProvider.select((reveal) => reveal?.group == groupName),
    );
    final title = Row(
      children: [
        _GroupIcon(src: group.icon, name: groupName),
        Flexible(
          child: _GroupSummary(groupName: groupName, hidden: showHiddenTag),
        ),
      ],
    );
    final actions = _GroupActions(
      isExpand: isExpand,
      unfold: unfold,
      isDelayTesting: isDelayTesting,
      groupType: group.type.name,
      onScrollToSelected: () {
        onScrollToSelected(groupName);
      },
      onDelayTest: () {
        ref.read(proxiesActionProvider.notifier).delayTestPageGroup(groupName);
      },
      onToggle: () {
        onChange(groupName);
      },
    );
    final card = Card(
      enterActionsOnRight: true,
      enterAnimated: enterAnimated,
      key: key,
      radius: radius - _headerButtonInset,
      fill: const Color(0x00000000),
      child: Padding(
        padding: const EdgeInsets.all(_headerInset - _headerButtonInset),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: _headerActionsGap,
                children: [
                  SizedBox(
                    height: listHeaderHeight - _headerInset * 2,
                    child: title,
                  ),
                  actions,
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: title),
                  actions,
                ],
              ),
      ),
      onPressed: () {
        onChange(groupName);
      },
    );
    final shape = AppShape.vertical(
      top: radius,
      bottom: unfolded ? radius * floating : radius,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: level.colorOf(colorScheme),
        shape: shape,
        shadows: lift == 0 ? null : _floatingShadows(colorScheme, lift),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: revealed ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: shape,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(_headerButtonInset),
            child: SurfaceScope(
              // Card fills one level above its scope.
              level: SurfaceLevel.values[level.index - 1],
              child: card,
            ),
          ),
        ],
      ),
    );
  }
}

List<BoxShadow> _floatingShadows(ColorScheme colorScheme, double lift) {
  final strength = colorScheme.brightness == Brightness.dark ? 3.0 : 1.0;
  return [
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.08 * strength * lift),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.04 * strength * lift),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];
}

class _GroupIcon extends ConsumerWidget {
  const _GroupIcon({required this.src, required this.name});

  final String src;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconStyle = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.iconStyle),
    );
    return switch (iconStyle) {
      ProxiesIconStyle.filled => LayoutBuilder(
        builder: (_, constraints) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                height: constraints.maxHeight,
                width: constraints.maxWidth,
                alignment: Alignment.center,
                padding: EdgeInsets.all(6.ap(context)),
                decoration: ShapeDecoration(
                  color: context.raisedSurfaceLevel.colorOf(
                    context.colorScheme,
                  ),
                  shape: AppShape.all(AppCorner.xl.ap(context) - _headerInset),
                ),
                clipBehavior: Clip.antiAlias,
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: constraints.maxHeight - 12.ap(context),
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  child: CommonTargetIcon(
                    src: src,
                    fallback: GroupMonogram(name),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      ProxiesIconStyle.plain => Container(
        margin: const EdgeInsets.only(left: 2, right: 10),
        child: LayoutBuilder(
          builder: (_, constraints) {
            return IconTheme.merge(
              data: IconThemeData(
                size: constraints.maxHeight,
                color: context.colorScheme.primary,
              ),
              child: CommonTargetIcon(src: src, fallback: GroupMonogram(name)),
            );
          },
        ),
      ),
      // Lines the title up with the proxy card names below, which sit at the
      // row inset plus the card padding.
      ProxiesIconStyle.hidden => const SizedBox(width: 4),
    };
  }
}

class _GroupSummary extends StatelessWidget {
  const _GroupSummary({required this.groupName, required this.hidden});

  final String groupName;

  /// Tags a group the config hides, shown because the user asked to see it.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final name = EmojiText(
      groupName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.callout.of(context, emphasized: true),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hidden) HiddenGroupName(name: groupName, child: name) else name,
        const SizedBox(height: 2),
        Flexible(flex: 1, child: _SelectedProxyName(groupName: groupName)),
      ],
    );
  }
}

class _SelectedProxyName extends ConsumerWidget {
  const _SelectedProxyName({required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref
        .watch(selectedProxyNameProvider(groupName))
        .takeFirstValid([]);
    if (proxyName.isEmpty) {
      return const SizedBox.shrink();
    }
    final name = EmojiText(
      proxyName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.caption1.of(context, emphasized: true).toLight,
    );
    if (watchGroupUdp(ref, groupName) != NodeUdp.enabled) {
      return name;
    }
    return Row(
      spacing: 6,
      children: [
        Flexible(child: name),
        NodeFieldIcon(
          field: NodeField.udp,
          proxy: Proxy(name: groupName, type: ''),
          line: AppTextStyle.caption1,
          note: context.appLocalizations.nodeUdpFollowsNode(proxyName),
          // Arrow right in the header goes to its buttons.
          focusable: false,
        ),
      ],
    );
  }
}

class _GroupActions extends StatelessWidget {
  const _GroupActions({
    required this.isExpand,
    required this.unfold,
    required this.isDelayTesting,
    required this.groupType,
    required this.onScrollToSelected,
    required this.onDelayTest,
    required this.onToggle,
  });

  final bool isExpand;
  final Animation<double> unfold;
  final bool isDelayTesting;
  final String groupType;
  final VoidCallback onScrollToSelected;
  final VoidCallback onDelayTest;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TonalButtonTheme(
      size: TonalButtonSize.compact,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isExpand)
            TonalButtonGroup(
              size: TonalButtonSize.compact,
              children: [
                IconButton(
                  tooltip: context.appLocalizations.scrollToSelected,
                  onPressed: onScrollToSelected,
                  iconSize: 19,
                  icon: const GlyphIcon(AppGlyphs.locate),
                ),
                IconButton(
                  tooltip: context.appLocalizations.delayTest,
                  onPressed: isDelayTesting ? null : onDelayTest,
                  icon: isDelayTesting
                      ? const ActivityIndicator(size: 24)
                      : const GlyphIcon(AppGlyphs.bolt),
                ),
              ],
            )
          else
            Text(
              groupType,
              style: AppTextStyle.caption1
                  .of(context, emphasized: true)
                  .toLight,
            ),
          const SizedBox(width: 6),
          ElasticPress(
            child: IconButton(
              tooltip: isExpand
                  ? context.appLocalizations.showLess
                  : context.appLocalizations.showMore,
              onPressed: onToggle,
              icon: RotationTransition(
                turns: unfold.drive(UnfoldMotion.chevronTurns),
                child: const GlyphIcon(Glyphs.caretDown, fill: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
