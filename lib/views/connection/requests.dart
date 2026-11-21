import 'dart:async';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// From this many connections a search runs at most once per
/// [searchThrottle]: the first keystroke after a pause is searched at once,
/// the ones typed within the interval only by their last query at its end, so
/// fast typing does not run over the whole list at every keystroke.
@visibleForTesting
const throttledSearchLength = 2000;

@visibleForTesting
const searchThrottle = Duration(milliseconds: 150);

class RequestsView extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final RequestFeed? initialFeed;
  final Future<List<TrackerInfo>> Function()? connectionsReader;

  const RequestsView({
    super.key,
    this.scrollController,
    this.initialFeed,
    @visibleForTesting this.connectionsReader,
  });

  @override
  ConsumerState<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends ConsumerState<RequestsView>
    with RouteMotionHoldMixin<RequestsView> {
  final _recent = TrackerInfoListController();
  final _live = TrackerInfoListController();
  final _liveFeed = GlobalKey<_LiveFeedState>();
  Timer? _requestRefresh;
  Timer? _searchCooldown;
  String? _queuedSearch;
  late final _filters = trackerInfoFilterController(ref, 'requests');
  late var _feed =
      widget.initialFeed ?? ref.read(appSettingProvider).requestFeed;

  @override
  void initState() {
    super.initState();
    if (_feed == RequestFeed.recent) {
      _showLatestRequests();
    }
    ref.listenManual(requestsProvider.select((state) => state.revision), (
      _,
      _,
    ) {
      updateRequestsThrottler();
    });
  }

  @override
  void dispose() {
    _requestRefresh?.cancel();
    _searchCooldown?.cancel();
    _recent.dispose();
    _live.dispose();
    _filters.dispose();
    super.dispose();
  }

  void _setRequests(List<TrackerInfo> requests) {
    _recent.setTrackerInfos(requests);
    _filters.offer(_recent.value.trackerInfos);
  }

  void _showLatestRequests() {
    _recent.resumeAutoScrollToEnd(ref.read(requestsProvider).list);
    _filters.offer(_recent.value.trackerInfos);
  }

  void updateRequestsThrottler() {
    _requestRefresh ??= Timer(renderThrottleDuration, () {
      _requestRefresh = null;
      if (!mounted || _feed != RequestFeed.recent) return;
      updateWhenRouteSettled(
        () => _setRequests(ref.read(requestsProvider).list),
      );
    });
  }

  void _search(String query) {
    final length = max(
      _recent.value.trackerInfos.length,
      _live.value.trackerInfos.length,
    );
    if (query.isEmpty || length < throttledSearchLength) {
      // Nothing waits behind a clear: the next keystroke is a fresh start.
      _searchCooldown?.cancel();
      _searchCooldown = null;
      _queuedSearch = null;
      _applySearch(query);
      return;
    }
    if (_searchCooldown != null) {
      _queuedSearch = query;
      return;
    }
    _applySearch(query);
    _startSearchCooldown();
  }

  void _startSearchCooldown() {
    _searchCooldown = Timer(searchThrottle, () {
      _searchCooldown = null;
      final query = _queuedSearch;
      if (query == null) {
        return;
      }
      _queuedSearch = null;
      _applySearch(query);
      _startSearchCooldown();
    });
  }

  void _applySearch(String query) {
    _recent.search(query);
    _live.search(query);
  }

  void _selectFeed(RequestFeed feed) {
    if (feed == _feed) {
      return;
    }
    // Offered before the feed mounts: a build below this page can't notify it.
    if (feed == RequestFeed.recent) {
      _showLatestRequests();
    }
    setState(() => _feed = feed);
    if (widget.initialFeed == null) {
      ref
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(requestFeed: feed));
    }
  }

  List<IconButtonData> _buildActions() {
    if (_feed != RequestFeed.live) {
      return const [];
    }
    return [
      IconButtonData(
        glyph: AppGlyphs.clearAll,
        tooltip: context.appLocalizations.closeConnections,
        onPressed: () => _liveFeed.currentState?.closeAll(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final body = RecordFilterScope(
      onFilter: _filters.add,
      child: ListenableBuilder(
        listenable: Listenable.merge([_filters, processApps]),
        builder: (_, _) => _buildBody(),
      ),
    );
    return ListenableBuilder(
      listenable: Listenable.merge([_filters, _filters.options]),
      child: body,
      builder: (context, body) {
        final pinned = !ViewScope.isMobileOf(context);
        return Scaffold(
          title: _labelOf(_feed),
          titleMenuItems: _buildFeedMenu(),
          searchState: AppBarSearchState(onSearch: _search),
          keywords: _filters.keywordsOf(pinned: pinned),
          iconActions: _buildActions(),
          menuItems: _filters.menuItems(context, pinned: pinned),
          body: body!,
        );
      },
    );
  }

  String _labelOf(RequestFeed feed) => switch (feed) {
    RequestFeed.recent => context.appLocalizations.recentRequests,
    RequestFeed.live => context.appLocalizations.running,
  };

  List<PopupMenuItem> _buildFeedMenu() {
    return [
      for (final feed in RequestFeed.values)
        PopupMenuItem(
          label: _labelOf(feed),
          checked: feed == _feed,
          onPressed: () => _selectFeed(feed),
        ),
    ];
  }

  Widget _buildBody() {
    return switch (_feed) {
      RequestFeed.recent => _RecentFeed(
        listController: _recent,
        filters: _filters,
        scrollController: widget.scrollController,
        onResumeToEnd: _showLatestRequests,
      ),
      RequestFeed.live => _LiveFeed(
        key: _liveFeed,
        listController: _live,
        filters: _filters,
        scrollController: widget.scrollController,
        connectionsReader: widget.connectionsReader,
      ),
    };
  }
}

class _RecentFeed extends StatefulWidget {
  final TrackerInfoListController listController;
  final RecordFilterController<TrackerInfo> filters;
  final ScrollController? scrollController;
  final VoidCallback onResumeToEnd;

  const _RecentFeed({
    required this.listController,
    required this.filters,
    required this.scrollController,
    required this.onResumeToEnd,
  });

  @override
  State<_RecentFeed> createState() => _RecentFeedState();
}

class _RecentFeedState extends State<_RecentFeed> {
  late final ScrollController _scrollController;
  late final _physics = FollowEndScrollPhysics(
    isFollowing: () => widget.listController.value.autoScrollToEnd,
  );

  @override
  void initState() {
    super.initState();
    _scrollController =
        widget.scrollController ?? sheetScrollController(context);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ValueListenableBuilder<TrackerInfosState>(
      valueListenable: widget.listController,
      builder: (context, state, _) {
        final requests = widget.listController.shownBy(widget.filters);
        final feed = NullStatusSwitcher(
          isEmpty: requests.isEmpty,
          isSearching: state.isSearching || widget.filters.isFiltering,
          nullStatus: NullStatus(
            label: appLocalizations.nullTip(appLocalizations.requests),
            illustration: NullStatusIllustration.requests,
          ),
          child: ProcessLookupOffNotice(
            visible: requests,
            child: RecordTableFrame<TrackerInfo>(
              tableId: 'requests',
              items: requests,
              reverse: true,
              columnsOf: (width) =>
                  trackerInfoColumns(context, width: width, isLive: false),
              builder: (context, table, requests) {
                final padding = EdgeInsets.only(
                  top: context.contentTopPadding,
                  bottom: 16 + context.bottomInset,
                );
                final detailTitle = appLocalizations.details(
                  appLocalizations.request,
                );
                final groups = widget.filters.groupsOf(requests, reverse: true);
                if (groups != null) {
                  return FloatingScrollbar(
                    controller: _scrollController,
                    hintBuilder: (fraction) {
                      final index = (fraction * (groups.length - 1)).round();
                      return groups[index].items.first.start.showFull;
                    },
                    child: TrackerInfoGroupedList(
                      groups: groups,
                      grouping: widget.filters.value.grouping!,
                      isLive: false,
                      controller: _scrollController,
                      padding: padding,
                      table: table,
                      detailTitle: detailTitle,
                    ),
                  );
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: FloatingScrollbar(
                    controller: _scrollController,
                    hintBuilder: (fraction) {
                      final index = (fraction * (requests.length - 1)).round();
                      return requests[index].start.showFull;
                    },
                    child: ScrollToEndBox(
                      controller: _scrollController,
                      enable: state.autoScrollToEnd,
                      onCancelToEnd: () {
                        widget.listController.setAutoScrollToEnd(false);
                      },
                      onResumeToEnd: () {
                        widget.onResumeToEnd();
                      },
                      child: TrackerInfoList(
                        reverse: true,
                        shrinkWrap: true,
                        physics: _physics,
                        controller: _scrollController,
                        padding: padding,
                        trackerInfos: requests,
                        table: table,
                        detailTitle: detailTitle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        return Consumer(
          builder: (context, ref, feed) => RequestsSearchScopeNote(
            count: state.trackerInfos.length,
            limit: widget.listController.limitOf(
              ref.watch(requestsProvider.select((list) => list.maxLength)),
            ),
            child: feed!,
          ),
          child: feed,
        );
      },
    );
  }
}

/// Above the recent requests, whether searched, filtered, sorted or not:
/// all of these reach only the [count] requests the list keeps now, at most
/// [limit], never older ones.
class RequestsSearchScopeNote extends StatelessWidget {
  final int count;
  final int limit;
  final Widget child;

  const RequestsSearchScopeNote({
    super.key,
    required this.count,
    required this.limit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // The note takes the place of the space the feed leaves under the bar.
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
                  // Not a live region: the count moves with every request
                  // while following, and would be read out each time.
                  child: Text(
                    context.appLocalizations.requestsSearchScopeHint(
                      count,
                      limit,
                    ),
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
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

class _LiveFeed extends ConsumerStatefulWidget {
  final TrackerInfoListController listController;
  final RecordFilterController<TrackerInfo> filters;
  final ScrollController? scrollController;
  final Future<List<TrackerInfo>> Function()? connectionsReader;

  const _LiveFeed({
    super.key,
    required this.listController,
    required this.filters,
    required this.scrollController,
    required this.connectionsReader,
  });

  @override
  ConsumerState<_LiveFeed> createState() => _LiveFeedState();
}

class _LiveFeedState extends ConsumerState<_LiveFeed>
    with
        WidgetsBindingObserver,
        ActivePollingMixin<_LiveFeed>,
        RouteMotionHoldMixin<_LiveFeed> {
  CoreController get _core => ref.read(coreHandlerProvider);

  var _ranking = TrackerRanking.empty;
  var _reads = 0;
  var _shownRead = 0;
  late final ScrollController _scrollController;
  var _loaded = false;

  /// Whether the last read shown failed.
  var _failed = false;

  /// Whether any read here succeeded, an empty one included: after that a
  /// failure keeps the last result on screen instead of standing in for it.
  var _succeeded = false;
  var _retrying = false;

  /// The last snapshot read, before the Core's MITM reports are laid over.
  List<TrackerInfo>? _snapshot;
  final _mitmOverlay = MitmStatusOverlay();
  Timer? _mitmRefresh;

  @override
  void initState() {
    super.initState();
    _scrollController =
        widget.scrollController ?? sheetScrollController(context);
    // A report on an open connection marks its row in place, without
    // waiting for the next read.
    ref.listenManual(
      requestsProvider.select((state) => state.revision),
      (_, _) => _scheduleMitmRefresh(),
    );
  }

  void _scheduleMitmRefresh() {
    if (_snapshot == null) {
      return;
    }
    _mitmRefresh ??= Timer(renderThrottleDuration, () {
      _mitmRefresh = null;
      if (!mounted) return;
      updateWhenRouteSettled(() => _showSnapshot());
    });
  }

  @override
  Duration get pollInterval => const Duration(seconds: 1);

  Future<void> closeAll() => _close(_core.closeConnections);

  @override
  Future<void> poll(PollGuard isCurrent) async {
    // A retry in flight is this tick's read; one beside it would only race.
    if (_retrying) {
      return;
    }
    final read = await _readConnections();
    if (!isCurrent()) {
      return;
    }
    _showConnections(read);
  }

  Future<void> _refreshConnections() async {
    final read = await _readConnections();
    if (!mounted) {
      return;
    }
    _showConnections(read);
  }

  /// One read now; polling skips its ticks until it is done, and of it and a
  /// poll already under way the newer read still wins.
  Future<void> _retry() async {
    if (_retrying) {
      return;
    }
    setState(() => _retrying = true);
    try {
      await _refreshConnections();
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  /// Null when a newer read has already been shown.
  Future<_ConnectionsRead?> _readConnections() async {
    final read = ++_reads;
    final rank = rankAfter(_ranking);
    final connectionsReader = widget.connectionsReader;
    try {
      final ranked = connectionsReader != null
          ? rank(await connectionsReader())
          : ref.read(coreStatusProvider) == CoreStatus.connected
          ? await _core.getConnectionsWith(rank)
          : rank(const []);
      // A refresh after closing a connection can overlap a poll.
      if (read < _shownRead) {
        return null;
      }
      _shownRead = read;
      _ranking = ranked.ranking;
      return _ConnectionsRead(ranked.trackerInfos);
    } catch (error) {
      if (!mounted) {
        return null;
      }
      commonPrint.log(
        'updateConnections error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      if (read < _shownRead) {
        return null;
      }
      _shownRead = read;
      // A Core that stopped under the read has no connections, not a failure.
      if (connectionsReader == null &&
          ref.read(coreStatusProvider) != CoreStatus.connected) {
        _ranking = TrackerRanking.empty;
        return const _ConnectionsRead([]);
      }
      return const _ConnectionsRead(null);
    }
  }

  void _showConnections(_ConnectionsRead? read) {
    if (read == null) {
      return;
    }
    if (!_loaded) {
      showFirstContent(() {
        setState(() => _loaded = true);
        // A failed read must not leave the controller's list from the last visit.
        _applyConnections(read.trackerInfos ?? const []);
        _applyFailure(read.failed);
      });
      return;
    }
    updateWhenRouteSettled(() {
      _applyConnections(read.trackerInfos);
      _applyFailure(read.failed);
    });
  }

  void _applyConnections(List<TrackerInfo>? trackerInfos) {
    if (trackerInfos == null) {
      return;
    }
    _snapshot = trackerInfos;
    ref
        .read(requestsProvider.notifier)
        .retainMitmStatuses(trackerInfos.map((info) => info.id));
    _showSnapshot();
  }

  void _showSnapshot() {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return;
    }
    widget.listController.setTrackerInfos(_mitmOverlay.apply(snapshot, ref));
    widget.filters.offer(widget.listController.value.trackerInfos);
  }

  /// Says the change once: polls that keep failing, or keep succeeding,
  /// leave the page and a screen reader alone.
  void _applyFailure(bool failed) {
    if (!failed) {
      _succeeded = true;
    }
    if (failed == _failed || !mounted) {
      return;
    }
    setState(() => _failed = failed);
    final appLocalizations = context.appLocalizations;
    announceReadState(
      context,
      failed
          ? (_succeeded
                ? appLocalizations.connectionsRefreshFailedStale
                : appLocalizations.connectionsReadFailed)
          : appLocalizations.connectionsRefreshed,
    );
  }

  Future<void> _closeConnection(TrackerInfo trackerInfo) =>
      _close(() => _core.closeConnection(trackerInfo.id));

  Future<void> _close(Future<void> Function() close) async {
    await globalState.safeRun(close, title: 'close connections');
    if (mounted) {
      await _refreshConnections();
    }
  }

  @override
  void dispose() {
    _mitmRefresh?.cancel();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ValueListenableBuilder<TrackerInfosState>(
      valueListenable: widget.listController,
      builder: (context, state, _) {
        final connections = widget.listController.shownBy(widget.filters);
        // Nothing read yet: the failure stands in the content, never the
        // empty state.
        final unread = _failed && !_succeeded;
        final stale = _failed && _succeeded;
        return ReadFailureFrame(
          banner: stale
              ? ReadFailureBanner(
                  message: appLocalizations.connectionsRefreshFailedStale,
                  retrying: _retrying,
                  onRetry: _retry,
                )
              : null,
          child: NullStatusSwitcher(
            isLoading: !_loaded,
            loadingStatus: const Center(child: ActivityIndicator.page()),
            isEmpty: unread || connections.isEmpty,
            isSearching:
                !unread && (state.isSearching || widget.filters.isFiltering),
            nullStatus: unread
                ? NullStatus(
                    label: appLocalizations.connectionsReadFailed,
                    description: appLocalizations.connectionsReadFailedDesc,
                    illustration: NullStatusIllustration.error,
                    action: RetryButton(
                      busy: _retrying,
                      onRetry: _retry,
                      filled: true,
                    ),
                  )
                : NullStatus(
                    label: appLocalizations.nullTip(
                      appLocalizations.connections,
                    ),
                    illustration: NullStatusIllustration.connections,
                  ),
            child: ProcessLookupOffNotice(
              visible: connections,
              child: RecordTableFrame<TrackerInfo>(
                tableId: 'connections',
                items: connections,
                columnsOf: (width) =>
                    trackerInfoColumns(context, width: width, isLive: true),
                builder: (context, table, connections) {
                  final padding = EdgeInsets.only(
                    top: context.contentTopPadding,
                    bottom: 16 + context.bottomInset,
                  );
                  final detailTitle = appLocalizations.details(
                    appLocalizations.connection,
                  );
                  final groups = widget.filters.groupsOf(connections);
                  if (groups != null) {
                    return TrackerInfoGroupedList(
                      groups: groups,
                      grouping: widget.filters.value.grouping!,
                      isLive: true,
                      controller: _scrollController,
                      padding: padding,
                      table: table,
                      detailTitle: detailTitle,
                      onClose: _closeConnection,
                    );
                  }
                  return TrackerInfoAnimatedList(
                    controller: _scrollController,
                    padding: padding,
                    trackerInfos: connections,
                    table: table,
                    detailTitle: detailTitle,
                    onClose: _closeConnection,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionsRead {
  const _ConnectionsRead(this.trackerInfos);

  /// Null for a read that failed.
  final List<TrackerInfo>? trackerInfos;

  bool get failed => trackerInfos == null;
}
