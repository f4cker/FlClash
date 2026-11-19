import 'dart:async';

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
        final requests = widget.filters.apply(state.list);
        return NullStatusSwitcher(
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
      },
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

  @override
  void initState() {
    super.initState();
    _scrollController =
        widget.scrollController ?? sheetScrollController(context);
  }

  @override
  Duration get pollInterval => const Duration(seconds: 1);

  Future<void> closeAll() => _close(_core.closeConnections);

  @override
  Future<void> poll(PollGuard isCurrent) async {
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

  /// One read on top of the polling, which carries on as it was; the newer of
  /// the two still wins.
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
    widget.listController.setTrackerInfos(trackerInfos);
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
        final connections = widget.filters.apply(state.list);
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
