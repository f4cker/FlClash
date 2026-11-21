import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'process_view.dart';
import 'tracker_info_item.dart';
import 'tracker_info_table.dart';
import 'tracker_search.dart';

class TrackerInfoListController extends ValueNotifier<TrackerInfosState> {
  TrackerInfoListController() : super(const TrackerInfosState());

  final _search = TrackerSearch();

  TrackerInfosState? _trackerInfosOf;
  List<TrackerInfo> _trackerInfos = const [];

  /// [value]'s connections as one list per state: the generated getter wraps
  /// them in a new view at each read, which no memo below would know again.
  List<TrackerInfo> get _stateTrackerInfos {
    if (!identical(value, _trackerInfosOf)) {
      _trackerInfosOf = value;
      _trackerInfos = value.trackerInfos;
    }
    return _trackerInfos;
  }

  /// What [TrackerInfosStateExt.list] gives for [value], searched once per
  /// list and query.
  List<TrackerInfo> get list => _search.apply(_stateTrackerInfos, value.query);

  List<TrackerInfo>? _filtered;
  List<RecordFilter>? _filteredBy;
  List<TrackerInfo> _shown = const [];
  final _appsChanges = ProcessAppsChanges();

  /// [list] narrowed by [filters], worked out again only when either or the
  /// apps moved, so a rebuild for anything else costs nothing per connection.
  List<TrackerInfo> shownBy(RecordFilterController<TrackerInfo> filters) {
    final list = this.list;
    final appsChanged = filters.isFiltering && _appsChanges.take();
    if (!appsChanged &&
        identical(list, _filtered) &&
        identical(filters.filters, _filteredBy)) {
      return _shown;
    }
    _filtered = list;
    _filteredBy = filters.filters;
    return _shown = filters.apply(list);
  }

  @override
  void dispose() {
    _search.dispose();
    _appsChanges.dispose();
    super.dispose();
  }

  void search(String query) {
    value = value.copyWith(query: query);
  }

  void setTrackerInfos(List<TrackerInfo> trackerInfos) {
    if (identical(trackerInfos, value.trackerInfos)) {
      return;
    }
    value = value.copyWith(
      trackerInfos: value.autoScrollToEnd
          ? trackerInfos
          : retainTrimmedHead(
              value.trackerInfos,
              trackerInfos,
              pausedMaxRequestsLength,
              keyOf: (trackerInfo) => trackerInfo.id,
            ),
    );
  }

  /// How many requests the list keeps at most now: what the source keeps,
  /// [followingLimit], while it follows; more while paused, see
  /// [setTrackerInfos].
  int limitOf(int followingLimit) =>
      value.autoScrollToEnd ? followingLimit : pausedMaxRequestsLength;

  void setAutoScrollToEnd(bool autoScrollToEnd) {
    value = value.copyWith(autoScrollToEnd: autoScrollToEnd);
  }

  void resumeAutoScrollToEnd(List<TrackerInfo> trackerInfos) {
    value = value.copyWith(autoScrollToEnd: true, trackerInfos: trackerInfos);
  }
}

RecordFilterController<TrackerInfo> trackerInfoFilterController(
  WidgetRef ref,
  String pageId,
) {
  return RecordFilterController(
    facets: trackerInfoFacets,
    groupers: trackerInfoGroupers,
    grouping: savedRecordGrouping(ref, pageId),
    onGroupingChanged: (grouping) => saveRecordGrouping(ref, pageId, grouping),
  );
}

class TrackerInfoList extends StatelessWidget {
  final List<TrackerInfo> trackerInfos;
  final String detailTitle;
  final RecordTable<TrackerInfo>? table;
  final ScrollController? controller;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<TrackerInfo>? onClose;

  const TrackerInfoList({
    super.key,
    required this.trackerInfos,
    required this.detailTitle,
    this.table,
    this.controller,
    this.reverse = false,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final table = this.table;
    return RecordFeedList<TrackerInfo>(
      reverse: reverse,
      shrinkWrap: shrinkWrap,
      physics: physics,
      controller: controller,
      padding: padding,
      items: trackerInfos,
      keyOf: (trackerInfo) => ValueKey(trackerInfo.id),
      gap: table == null ? recordListGap : 0,
      estimatedItemExtent: table?.rowHeight ?? recordListEstimatedExtent,
      itemBuilder: (trackerInfo, striped, latest) => MemoBuilder(
        inputs: table == null
            ? [..._shownInList(trackerInfo), detailTitle]
            : [trackerInfo, table, striped],
        builder: (_) => _buildTrackerInfoItem(
          trackerInfo,
          isLive: false,
          detailTitle: detailTitle,
          table: table,
          striped: striped,
          onClose: onClose,
          latest: latest,
        ),
      ),
    );
  }
}

/// What a finished row shows: it leaves out the traffic a request still
/// reports, which would rebuild the rows on screen at every refresh.
List<Object?> _shownInList(TrackerInfo trackerInfo) => [
  trackerInfo.start,
  trackerInfo.metadata,
  trackerInfo.chains,
  trackerInfo.rule,
  trackerInfo.rulePayload,
  trackerInfo.mitmOutcome,
  trackerInfo.mitmRewrite,
];

/// Same rows as [TrackerInfoList], but diffed by connection id so closed
/// connections collapse out and surviving rows slide to their new slot.
class TrackerInfoAnimatedList extends StatelessWidget {
  final List<TrackerInfo> trackerInfos;
  final String detailTitle;
  final RecordTable<TrackerInfo>? table;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<TrackerInfo>? onClose;

  const TrackerInfoAnimatedList({
    super.key,
    required this.trackerInfos,
    required this.detailTitle,
    this.table,
    this.controller,
    this.padding,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final table = this.table;
    final positions = table == null
        ? const <String, int>{}
        : {
            for (final (index, trackerInfo) in trackerInfos.indexed)
              trackerInfo.id: index,
          };
    return ArrivalCacheExtentBuilder(
      builder: (cacheExtent) => KeyedAnimatedList<TrackerInfo>(
        controller: controller,
        padding: padding,
        scrollCacheExtent: cacheExtent,
        items: trackerInfos,
        keyOf: (trackerInfo) => trackerInfo.id,
        estimatedItemExtent: table?.rowHeight ?? recordListEstimatedExtent,
        separator: table == null ? const SizedBox(height: recordListGap) : null,
        itemBuilder: (itemContext, trackerInfo) {
          final striped = positions[trackerInfo.id]?.isOdd ?? false;
          return MemoBuilder(
            key: ValueKey(trackerInfo.id),
            // A live row reads its age off the clock, which moves on its own.
            inputs: [
              trackerInfo,
              ...table == null
                  ? [
                      detailTitle,
                      trackerInfo.start.getLastUpdateTimeDesc(
                        itemContext,
                        compact: true,
                      ),
                    ]
                  : [table, striped],
            ],
            builder: (_) => _buildTrackerInfoItem(
              trackerInfo,
              isLive: true,
              detailTitle: detailTitle,
              table: table,
              striped: striped,
              onClose: onClose,
            ),
          );
        },
      ),
    );
  }
}

class TrackerInfoGroupedList extends ConsumerStatefulWidget {
  final List<RecordGroup<TrackerInfo>> groups;
  final RecordGrouping grouping;
  final bool isLive;
  final String detailTitle;
  final RecordTable<TrackerInfo>? table;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<TrackerInfo>? onClose;

  const TrackerInfoGroupedList({
    super.key,
    required this.groups,
    required this.grouping,
    required this.isLive,
    required this.detailTitle,
    this.table,
    this.controller,
    this.padding,
    this.onClose,
  });

  @override
  ConsumerState<TrackerInfoGroupedList> createState() =>
      _TrackerInfoGroupedListState();
}

class _TrackerInfoGroupedListState
    extends ConsumerState<TrackerInfoGroupedList> {
  Map<String, TrackerInfo>? _byId;
  final _leadings = <String, Widget>{};

  @override
  void didUpdateWidget(TrackerInfoGroupedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.groups, widget.groups)) {
      _byId = null;
    }
  }

  Widget? _leadingOf(String packageName) {
    if (packageName.isEmpty) {
      return null;
    }
    return _leadings[packageName] ??= OwnPackageIcon(
      packageName: packageName,
      size: 24,
      builder: (_, icon) => icon ?? const SizedBox.shrink(),
    );
  }

  TrackerInfo _latest(TrackerInfo trackerInfo) =>
      (_byId ??= {
        for (final group in widget.groups)
          for (final item in group.items) item.id: item,
      })[trackerInfo.id] ??
      trackerInfo;

  @override
  Widget build(BuildContext context) {
    final TrackerInfoGroupedList(
      :grouping,
      :isLive,
      :detailTitle,
      :table,
      :onClose,
    ) = widget;
    final showsIcons =
        grouping == RecordGrouping.app &&
        system.isAndroid &&
        ref.watch(packageIconSourceProvider) != null;
    final byProcess = grouping == RecordGrouping.app && !system.isAndroid;
    final showsTraffic = isLive || table != null;
    return RecordGroupedList<TrackerInfo>(
      groups: widget.groups,
      grouping: grouping,
      controller: widget.controller,
      padding: widget.padding,
      estimatedItemExtent: table?.rowHeight ?? recordListEstimatedExtent,
      leadingOf: byProcess
          ? (group) => _processLeading(group)
          : showsIcons
          ? (group) => _leadingOf(group.key)
          : null,
      labelOf: byProcess
          ? (group) => processLabelOf(
              processApps.processOf(group.items.first.metadata),
            )
          : null,
      trailingOf: isLive ? (group) => _buildSpeed(context, group.items) : null,
      itemBuilder: (_, trackerInfo, index) {
        final striped = index.isOdd;
        return MemoBuilder(
          key: ValueKey(trackerInfo.id),
          inputs: [
            ...showsTraffic ? [trackerInfo] : _shownInList(trackerInfo),
            detailTitle,
            table,
            striped,
            if (isLive && table == null)
              trackerInfo.start.getLastUpdateTimeDesc(context, compact: true),
          ],
          builder: (_) {
            final row = _buildTrackerInfoItem(
              trackerInfo,
              isLive: isLive,
              detailTitle: detailTitle,
              table: table,
              striped: striped,
              onClose: onClose,
              latest: () => _latest(trackerInfo),
            );
            return table == null
                ? Padding(
                    padding: const EdgeInsets.only(top: recordListGap),
                    child: row,
                  )
                : row;
          },
        );
      },
    );
  }

  Widget _processLeading(RecordGroup<TrackerInfo> group) => ProcessIcon(
    process: processApps.processOf(group.items.first.metadata),
    size: 24,
  );

  Widget _buildSpeed(BuildContext context, List<TrackerInfo> trackerInfos) {
    var upload = 0;
    var download = 0;
    for (final trackerInfo in trackerInfos) {
      upload += trackerInfo.uploadSpeed ?? 0;
      download += trackerInfo.downloadSpeed ?? 0;
    }
    final color = context.colorScheme.onSurfaceVariant;
    WidgetSpan arrow(Glyph glyph) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: GlyphIcon(glyph, size: 12, color: color),
    );
    return Text.rich(
      TextSpan(
        children: [
          arrow(AppGlyphs.arrowUp),
          TextSpan(text: ' ${upload.traffic.show}/s   '),
          arrow(AppGlyphs.arrowDown),
          TextSpan(text: ' ${download.traffic.show}/s'),
        ],
      ),
    );
  }
}

Widget _buildTrackerInfoItem(
  TrackerInfo trackerInfo, {
  required bool isLive,
  required String detailTitle,
  required RecordTable<TrackerInfo>? table,
  required bool striped,
  ValueChanged<TrackerInfo>? onClose,
  ValueGetter<TrackerInfo>? latest,
}) {
  if (table != null) {
    return TrackerInfoTableRow(
      key: ValueKey(trackerInfo.id),
      trackerInfo: trackerInfo,
      table: table,
      striped: striped,
      detailTitle: detailTitle,
      onClose: onClose,
    );
  }
  return TrackerInfoItem(
    key: ValueKey(trackerInfo.id),
    trackerInfo: trackerInfo,
    isLive: isLive,
    onClose: onClose,
    detailTitle: detailTitle,
    latest: latest,
  );
}
