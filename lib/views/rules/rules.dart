import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/resources.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_rule_dialog.dart';
import 'hit_card.dart';
import 'rule_rows.dart';
import 'rules_logic.dart';
import 'widgets.dart';

const _pageSize = 200;
const _narrowWidth = 560.0;
const _rowExtentGuess = 43.0;

/// A page of a rule set's entries as the list has read them, under the
/// filter it was read with.
class _SetPage {
  final String filter;
  final List<String> entries = [];
  int total = 0;
  bool loading = false;
  bool loaded = false;
  Object? error;

  _SetPage(this.filter);

  bool get done => loaded && entries.length >= total;
}

/// A lookup the page ran or runs; [record] is the rule a request took when
/// the lookup came from one.
class _Lookup {
  final String host;
  final int? port;
  final ({String rule, String payload, String text, bool ipOnly})? record;
  RuleLookup? result;
  Object? error;
  bool loading = true;

  _Lookup(this.host, {this.port, this.record});
}

/// What the page says after it added a rule: whether the rule now decides.
typedef _AddedOutcome = ({
  bool effective,
  String host,
  String group,
  int index,
  String source,
  String text,
});

/// The rules the running Core holds, in the order they apply, and the one a
/// host or address takes.
class RulesView extends ConsumerStatefulWidget {
  const RulesView({super.key});

  @override
  ConsumerState<RulesView> createState() => _RulesViewState();
}

class _RulesViewState extends ConsumerState<RulesView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final ScrollController _scrollController;
  final _panelLink = LayerLink();
  final _panel = OverlayPortalController();
  final _listStartKey = GlobalKey();
  final _targetRowKey = GlobalKey();

  RuleList? _list;
  Object? _listError;
  bool _listLoading = false;
  int _listSerial = 0;

  String _text = '';
  ({String text, List<int> indexes, Map<String, int> sets})? _filter;
  Timer? _filterTimer;
  int _filterSerial = 0;
  bool _panelDismissed = false;
  double _boxWidth = 0;
  double? _savedOffset;

  RuleSourceFilter _source = RuleSourceFilter.all;
  String? _group;

  final Map<int, _SetPage> _pages = {};
  final Set<int> _expanded = {};
  final Set<int> _collapsed = {};

  _Lookup? _lookup;
  int _lookupSerial = 0;
  bool _showAll = false;
  int? _focusIndex;
  _AddedOutcome? _added;

  @override
  void initState() {
    super.initState();
    _scrollController = sheetScrollController(context);
    ref.listenManual(rulesLookupRequestProvider, (_, ask) {
      if (ask != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _takeAsk(ask));
      }
    }, fireImmediately: true);
    ref.listenManual(appliedRuleSourcesStateProvider, (previous, next) {
      if (previous?.sources != next.sources ||
          previous?.profileId != next.profileId) {
        _refresh();
      }
    });
    ref.listenManual(coreStatusProvider, (previous, next) {
      if (next == CoreStatus.connected && previous != CoreStatus.connected) {
        _refresh();
      } else if (mounted) {
        setState(() {});
      }
    });
    ref.listenManual(patchClashConfigProvider.select((state) => state.mode), (
      previous,
      next,
    ) {
      if (previous != next) _refresh();
    });
    _loadList();
  }

  @override
  void dispose() {
    _filterTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _coreRunning => ref.read(coreStatusProvider) == CoreStatus.connected;

  bool get _inLookup => _lookup != null;

  void _refresh() {
    if (!mounted) return;
    _loadList();
    final lookup = _lookup;
    if (lookup != null && lookup.result != null) {
      _runLookup(
        lookup.host,
        port: lookup.port,
        record: lookup.record,
        keep: true,
      );
    }
  }

  Future<void> _loadList() async {
    if (!_coreRunning) {
      setState(() {});
      return;
    }
    final serial = ++_listSerial;
    setState(() => _listLoading = true);
    try {
      final list = await ref.read(coreHandlerProvider).listRules();
      if (!mounted || serial != _listSerial) return;
      final epochChanged = _list?.coreEpoch != list.coreEpoch;
      setState(() {
        _list = list;
        _listError = null;
        _listLoading = false;
        if (epochChanged) {
          _pages.clear();
          _expanded.removeWhere((index) => index >= list.rules.length);
        }
      });
      final applied = ref.read(appliedRuleSourcesStateProvider);
      final aligned = alignRuleSources(
        list: list,
        applied: applied.copyWith(epoch: null),
        profileId: ref.read(currentProfileIdProvider),
      );
      if (aligned != null) {
        ref.read(appliedRuleSourcesStateProvider.notifier).bind(list.coreEpoch);
      }
      for (final index in _expanded) {
        unawaited(_loadPage(index));
      }
      if (_text.trim().isNotEmpty) unawaited(_runFilter(_text));
    } catch (error) {
      if (!mounted || serial != _listSerial) return;
      setState(() {
        _listError = error;
        _listLoading = false;
      });
    }
  }

  List<RuleSource?>? get _sources {
    final list = _list;
    if (list == null) return null;
    return alignRuleSources(
      list: list,
      applied: ref.read(appliedRuleSourcesStateProvider),
      profileId: ref.read(currentProfileIdProvider),
    );
  }

  // Search

  void _onChanged(String text) {
    final wasEmpty = _text.trim().isEmpty;
    _text = text;
    _panelDismissed = false;
    _filterTimer?.cancel();
    if (text.trim().isEmpty) {
      _clearSearch();
      return;
    }
    if (wasEmpty && _scrollController.hasClients) {
      _savedOffset = _scrollController.offset;
    }
    final host = lookupHostOf(text);
    if (_inLookup && host == null) {
      _lookup = null;
      _added = null;
      _showAll = false;
    }
    _filterTimer = Timer(
      const Duration(milliseconds: 200),
      () => _runFilter(text),
    );
    setState(() {});
    _syncPanel();
  }

  void _clearSearch() {
    _filterTimer?.cancel();
    _filterSerial++;
    final offset = _savedOffset;
    setState(() {
      _text = '';
      _filter = null;
      _lookup = null;
      _lookupSerial++;
      _added = null;
      _showAll = false;
      _focusIndex = null;
      _collapsed.clear();
    });
    _syncPanel();
    if (offset != null) {
      _savedOffset = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            offset.clamp(0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }
  }

  Future<void> _runFilter(String text) async {
    if (!_coreRunning) return;
    final serial = ++_filterSerial;
    try {
      final result = await ref
          .read(coreHandlerProvider)
          .listRules(filter: text.trim());
      if (!mounted || serial != _filterSerial) return;
      setState(() {
        _filter = (
          text: text,
          indexes: result.filtered,
          sets: result.setMatches,
        );
        _collapsed.clear();
      });
      for (final index in _autoExpanded) {
        unawaited(_loadPage(index));
      }
    } catch (_) {
      // A filter that fails leaves the list as it was.
    }
  }

  ({String text, List<int> indexes, Map<String, int> sets})? get _liveFilter {
    final filter = _filter;
    if (filter == null || _text.trim().isEmpty) return null;
    return filter;
  }

  String? get _panelHost {
    if (_panelDismissed) return null;
    final host = lookupHostOf(_text);
    if (host == null) return null;
    final lookup = _lookup;
    if (lookup != null && lookup.host == host) return null;
    return host;
  }

  void _syncPanel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_panelHost != null) {
        _panel.show();
      } else {
        _panel.hide();
      }
    });
  }

  void _dismissPanel() {
    setState(() => _panelDismissed = true);
    _syncPanel();
  }

  void _submit() {
    final host = lookupHostOf(_text);
    if (host == null) return;
    final lookup = _lookup;
    if (lookup != null && lookup.loading && lookup.host == host) return;
    _runLookup(host, port: lookupPortOf(_text));
  }

  void _takeAsk(RulesLookupAsk ask) {
    if (!mounted) return;
    ref.read(rulesLookupRequestProvider.notifier).taken();
    _controller.text = ask.host;
    _text = ask.host;
    _filterTimer?.cancel();
    _runFilter(ask.host);
    _runLookup(
      ask.host,
      record: ask.rule.isEmpty
          ? null
          : (
              rule: ask.rule,
              payload: ask.rulePayload,
              text: ask.rulePayload.isEmpty
                  ? ask.rule
                  : '${ask.rule}(${ask.rulePayload})',
              ipOnly: isIpHost(ask.host),
            ),
    );
  }

  Future<void> _runLookup(
    String host, {
    int? port,
    ({String rule, String payload, String text, bool ipOnly})? record,
    bool keep = false,
  }) async {
    final serial = ++_lookupSerial;
    final previous = _lookup;
    final lookup = _Lookup(host, port: port, record: record);
    if (keep && previous != null && previous.host == host) {
      lookup.result = previous.result;
    } else if (previous != null && previous.host == host) {
      // Asked again: the old answer stays, dimmed, until the new one.
      lookup.result = previous.result;
    }
    setState(() {
      _lookup = lookup;
      _panelDismissed = true;
      if (!keep) {
        _added = null;
        _showAll = false;
        _focusIndex = null;
      }
    });
    _syncPanel();
    if (!_coreRunning) {
      setState(() {
        lookup.loading = false;
        lookup.result = null;
        lookup.error = const _CoreStopped();
      });
      return;
    }
    try {
      final result = await ref
          .read(coreHandlerProvider)
          .lookupRule(RuleLookupParams(host: host, port: port));
      if (!mounted || serial != _lookupSerial) return;
      setState(() {
        lookup.result = result;
        lookup.error = null;
        lookup.loading = false;
      });
      if (result.coreEpoch != _list?.coreEpoch) unawaited(_loadList());
    } catch (error) {
      if (!mounted || serial != _lookupSerial) return;
      setState(() {
        lookup.result = null;
        lookup.error = error;
        lookup.loading = false;
      });
    }
  }

  // Rule sets

  Iterable<int> get _autoExpanded sync* {
    final list = _list;
    final filter = _liveFilter;
    if (list == null || filter == null || _inLookup) return;
    for (final index in filter.indexes) {
      final set = list.rules.elementAtOrNull(index)?.ruleSet;
      if (set != null &&
          filter.sets.containsKey(set.name) &&
          !_collapsed.contains(index)) {
        yield index;
      }
    }
  }

  bool _isExpanded(int index) {
    if (_expanded.contains(index)) return true;
    if (_inLookup) return false;
    final list = _list;
    final filter = _liveFilter;
    final set = list?.rules.elementAtOrNull(index)?.ruleSet;
    return set != null &&
        filter != null &&
        filter.sets.containsKey(set.name) &&
        !_collapsed.contains(index);
  }

  String _pageFilterOf(int index) {
    final filter = _liveFilter;
    final set = _list?.rules.elementAtOrNull(index)?.ruleSet;
    if (filter == null || set == null || _inLookup) return '';
    return filter.sets.containsKey(set.name) ? filter.text.trim() : '';
  }

  bool _expandable(CoreRule rule) {
    final set = rule.ruleSet;
    return set != null && set.status == 'ok' && set.count > 0;
  }

  void _toggle(int index) {
    setState(() {
      if (_isExpanded(index)) {
        _expanded.remove(index);
        _collapsed.add(index);
      } else {
        _expanded.add(index);
        _collapsed.remove(index);
      }
    });
    if (_isExpanded(index)) unawaited(_loadPage(index));
  }

  _SetPage _pageOf(int index) {
    final filter = _pageFilterOf(index);
    final page = _pages[index];
    if (page != null && page.filter == filter) return page;
    return _pages[index] = _SetPage(filter);
  }

  Future<void> _loadPage(int index) async {
    final rule = _list?.rules.elementAtOrNull(index);
    final set = rule?.ruleSet;
    if (set == null || !_coreRunning) return;
    final page = _pageOf(index);
    if (page.loading || page.done || page.error != null) return;
    setState(() => page.loading = true);
    try {
      final entries = await ref
          .read(coreHandlerProvider)
          .getRuleSetEntries(
            set.name,
            offset: page.entries.length,
            limit: _pageSize,
            filter: page.filter,
          );
      if (!mounted || _pages[index] != page) return;
      setState(() {
        page.entries.addAll(entries.entries);
        page.total = page.filter.isEmpty ? entries.total : entries.matched;
        page.loaded = true;
        page.loading = false;
        if (entries.entries.isEmpty) page.total = page.entries.length;
      });
    } catch (error) {
      if (!mounted || _pages[index] != page) return;
      setState(() {
        page.error = error;
        page.loading = false;
      });
    }
  }

  // Rows

  List<RuleRowItem> _items({
    required RuleList list,
    required List<RuleSource?>? sources,
  }) {
    final items = <RuleRowItem>[];
    final lookup = _lookup?.result;
    if (_inLookup && !_showAll) {
      if (lookup == null) return items;
      for (final hit in lookupRows(lookup)) {
        items.add(RuleRowItem.rule(hit.rule, hit: hit));
        if (hit.ruleSet != null && hit.entry.isNotEmpty) {
          items.add(
            RuleRowItem.entry(parent: hit.index, position: 0, text: hit.entry),
          );
        }
      }
      return items;
    }
    final hits = <int, RuleHit>{
      if (_inLookup && lookup != null)
        for (final hit in lookupRows(lookup)) hit.index: hit,
    };
    final filter = _inLookup ? null : _liveFilter;
    final indexes =
        filter?.indexes ?? [for (var i = 0; i < list.rules.length; i++) i];
    for (final index in indexes) {
      final rule = list.rules.elementAtOrNull(index);
      if (rule == null) continue;
      if (!_inLookup &&
          !ruleShown(
            rule: rule,
            source: sources?.elementAtOrNull(index),
            filter: _source,
            group: _group,
          )) {
        continue;
      }
      items.add(RuleRowItem.rule(rule, hit: hits[index]));
      if (_expandable(rule) && _isExpanded(index)) {
        final page = _pageOf(index);
        for (final (position, entry) in page.entries.indexed) {
          items.add(
            RuleRowItem.entry(parent: index, position: position, text: entry),
          );
        }
        items.add(RuleRowItem.footer(parent: index));
      } else {
        final hit = hits[index];
        if (hit != null && hit.ruleSet != null && hit.entry.isNotEmpty) {
          items.add(
            RuleRowItem.entry(parent: index, position: 0, text: hit.entry),
          );
        }
      }
    }
    return items;
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    dialogs.showBanner(context.appLocalizations.copySuccess);
  }

  void _revealGroup(String group) {
    ref.read(proxiesRevealProvider.notifier).reveal(group);
  }

  void _showResources() {
    showNestedExtend<void>(context, builder: (_) => const ResourcesView());
  }

  /// Shows every rule and brings the one at [index] to the middle.
  void _scrollToRule(int index) {
    setState(() {
      _showAll = true;
      _focusIndex = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _targetRowKey.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(rowContext, alignment: 0.5);
        return;
      }
      final list = _list;
      final startContext = _listStartKey.currentContext;
      if (list == null ||
          startContext == null ||
          !_scrollController.hasClients) {
        return;
      }
      final items = _items(list: list, sources: _sources);
      final position = items.indexWhere(
        (item) => item.isRule && item.rule!.index == index,
      );
      if (position == -1) return;
      final sliver = startContext.findRenderObject();
      final start = sliver is RenderSliver
          ? sliver.constraints.precedingScrollExtent
          : 0.0;
      final viewport = _scrollController.position.viewportDimension;
      _scrollController.jumpTo(
        (start + position * _rowExtentGuess - viewport / 2).clamp(
          0,
          _scrollController.position.maxScrollExtent,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rowContext = _targetRowKey.currentContext;
        if (rowContext != null && mounted) {
          Scrollable.ensureVisible(rowContext, alignment: 0.5);
        }
      });
    });
  }

  // Adding a rule

  List<String> _targets() {
    final groups = ref.read(groupsProvider);
    return [
      for (final group in groups)
        if (group.name != GroupName.GLOBAL.name) group.name,
      'DIRECT',
      'REJECT',
    ];
  }

  Future<String?> _writeRule(Profile profile, String text) async {
    final appLocalizations = context.appLocalizations;
    try {
      await putProfileRuleFirst(profile.id, Rule.parse(text));
      ref.invalidate(setupStateProvider(profile.id));
      final applied = await ref
          .read(setupActionProvider.notifier)
          .applyProfile(silence: true);
      return applied ? null : appLocalizations.addRuleApplyFailed;
    } catch (error) {
      return appLocalizations.addRuleWriteFailed('$error');
    }
  }

  Future<void> _addRule() async {
    final lookup = _lookup;
    final profile = ref.read(currentProfileProvider);
    if (lookup == null || profile == null) return;
    final winner = lookup.result?.winner;
    final targets = _targets();
    final text = await dialogs.showCommonDialog<String>(
      dismissible: false,
      child: AddRuleDialog(
        host: lookup.host,
        profileLabel: profile.realLabel,
        targets: targets,
        initialTarget: winner?.target,
        onAdd: (text) => _writeRule(profile, text),
      ),
    );
    if (text == null || !mounted) return;
    await _runLookup(
      lookup.host,
      port: lookup.port,
      record: lookup.record,
      keep: true,
    );
    if (!mounted) return;
    final result = _lookup?.result;
    final now = result?.winner;
    final fields = text.split(',');
    final target = fields.length > 2 ? fields[2] : '';
    final effective =
        now != null &&
        now.type == ruleTypeOf(text) &&
        now.payload == (fields.length > 1 ? fields[1] : '');
    final sources = _sources;
    final badge = now == null
        ? null
        : ruleSourceBadge(
            context,
            now.rule,
            sources?.elementAtOrNull(now.index),
          );
    setState(() {
      _added = (
        effective: effective,
        host: lookup.host,
        group: ruleTargetLabel(context, target),
        index: (now?.index ?? 0) + 1,
        source: badge?.label ?? now?.type ?? '',
        text: text,
      );
    });
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final profile = ref.watch(currentProfileProvider);
    final coreRunning = ref.watch(
      coreStatusProvider.select((status) => status == CoreStatus.connected),
    );
    ref.watch(appliedRuleSourcesStateProvider);
    final list = _list;
    final profileLabel = profile?.realLabel ?? '';
    final subtitle = _inLookup || list == null
        ? appLocalizations.rulesSubtitleQuery(profileLabel)
        : appLocalizations.rulesSubtitle(profileLabel, list.total);
    return Scaffold(
      title: appLocalizations.rules,
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: 10,
        children: [
          Text(appLocalizations.rules),
          Flexible(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < _narrowWidth;
          return _buildBody(context, coreRunning: coreRunning, narrow: narrow);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool coreRunning,
    required bool narrow,
  }) {
    final appLocalizations = context.appLocalizations;
    final list = _list;
    final sources = _sources;
    final lookup = _lookup;
    final mode = list?.mode ?? lookup?.result?.mode ?? '';
    final items = list == null
        ? const <RuleRowItem>[]
        : _items(list: list, sources: sources);
    const padding = EdgeInsets.symmetric(horizontal: 16);
    Widget box(Widget child, {double top = 12}) => SliverPadding(
      padding: padding.copyWith(top: top),
      sliver: SliverToBoxAdapter(child: child),
    );
    final dimmed = !coreRunning;
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: context.contentTopPadding)),
        if (!coreRunning && lookup?.error is! _CoreStopped)
          box(
            RulesNotice(
              tone: RuleTone.red,
              glyph: AppGlyphs.error,
              text: appLocalizations.rulesCoreStopped,
            ),
            top: 0,
          ),
        if (mode == 'global' || mode == 'direct')
          box(
            RulesNotice(
              tone: RuleTone.gray,
              glyph: AppGlyphs.info,
              text: mode == 'global'
                  ? appLocalizations.rulesModeGlobal
                  : appLocalizations.rulesModeDirect,
            ),
            top: coreRunning ? 0 : 12,
          ),
        box(
          _buildSearchBox(context),
          top: coreRunning && mode == 'rule' ? 0 : 12,
        ),
        if (lookup != null) ..._buildLookupSlivers(context, lookup, box),
        if (_listError case final error? when list == null)
          box(
            RulesNotice(
              tone: RuleTone.red,
              glyph: AppGlyphs.error,
              text: appLocalizations.rulesLoadFailed(_reasonOf(error)),
              actionLabel: appLocalizations.retry,
              onAction: _loadList,
            ),
          ),
        if (list != null) ...[
          box(
            _inLookup
                ? _buildLookupChips(context)
                : _buildFilterChips(context, list, sources),
          ),
          SliverToBoxAdapter(
            key: _listStartKey,
            child: const SizedBox(height: 12),
          ),
          SliverPadding(
            padding: padding.copyWith(bottom: 24 + context.bottomInset),
            sliver: SliverOpacity(
              opacity: dimmed ? 0.45 : 1,
              sliver: _buildList(context, list, sources, items, narrow),
            ),
          ),
        ] else if (_listLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: ActivityIndicator()),
            ),
          ),
      ],
    );
  }

  String _reasonOf(Object error) {
    if (error is CoreMethodException) return error.message;
    return '$error';
  }

  Widget _buildSearchBox(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final loading = _lookup?.loading ?? false;
    final lookup = _lookup;
    final result = lookup?.result;
    String? info;
    if (lookup != null && result != null && !lookup.loading) {
      final ip = result.ip;
      final resolved = switch (result.ipSource) {
        'dns' => appLocalizations.lookupResolvedIp(
          ip,
          appLocalizations.ipSourceDns,
        ),
        'hosts' => appLocalizations.lookupResolvedIp(
          ip,
          appLocalizations.ipSourceHosts,
        ),
        'mapping' => appLocalizations.lookupResolvedIp(
          ip,
          appLocalizations.ipSourceMapping,
        ),
        'input' => appLocalizations.lookupInputIp(ip),
        _ => null,
      };
      info = [
        lookup.host,
        if (lookup.port != null) ':${lookup.port}',
        if (resolved != null && ip.isNotEmpty) ' · $resolved',
      ].join();
    }
    final field = _SearchField(
      controller: _controller,
      focusNode: _focusNode,
      loading: loading,
      onChanged: _onChanged,
      onSubmitted: (_) => _submit(),
      onEscape: _dismissPanel,
      onClear: () {
        _controller.clear();
        _clearSearch();
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            _boxWidth = constraints.maxWidth;
            return CompositedTransformTarget(
              link: _panelLink,
              child: OverlayPortal(
                controller: _panel,
                overlayChildBuilder: _buildPanel,
                child: field,
              ),
            );
          },
        ),
        if (info != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              info,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    final host = _panelHost;
    if (host == null) return const SizedBox.shrink();
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final filter = _filter;
    final count = filter != null && filter.text == _text
        ? filter.indexes.length
        : null;
    return CompositedTransformFollower(
      link: _panelLink,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, 6),
      child: Align(
        alignment: Alignment.topLeft,
        child: TextFieldTapRegion(
          child: Container(
            width: _boxWidth,
            padding: const EdgeInsets.all(6),
            decoration: ShapeDecoration(
              color: context.raisedSurfaceLevel.colorOf(colorScheme),
              shadows: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  button: true,
                  label: appLocalizations.rulesLookupSuggestionLabel(host),
                  excludeSemantics: true,
                  child: _PanelItem(
                    highlighted: true,
                    onTap: _submit,
                    child: Row(
                      spacing: 8,
                      children: [
                        GlyphIcon(
                          AppGlyphs.search,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        Expanded(
                          child: Text(
                            appLocalizations.rulesLookupSuggestion(host),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.subheadline
                                .of(context, emphasized: true)
                                .copyWith(color: colorScheme.primary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: ShapeDecoration(
                            shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ),
                          child: Text(
                            '↵',
                            style: AppTextStyle.caption1
                                .of(context)
                                .copyWith(color: colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _PanelItem(
                  onTap: _dismissPanel,
                  child: Text(
                    appLocalizations.rulesFilterOnly(count ?? '…'),
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLookupSlivers(
    BuildContext context,
    _Lookup lookup,
    Widget Function(Widget child, {double top}) box,
  ) {
    final appLocalizations = context.appLocalizations;
    final error = lookup.error;
    if (error != null) {
      return [
        box(
          error is _CoreStopped
              ? RulesNotice(
                  tone: RuleTone.red,
                  glyph: AppGlyphs.error,
                  text: appLocalizations.lookupCoreStopped,
                  actionLabel: appLocalizations.toDashboard,
                  onAction: () => ref
                      .read(currentPageLabelProvider.notifier)
                      .toPage(PageLabel.dashboard),
                )
              : RulesNotice(
                  tone: RuleTone.red,
                  glyph: AppGlyphs.error,
                  text: appLocalizations.lookupFailed(_reasonOf(error)),
                  actionLabel: appLocalizations.retry,
                  onAction: () => _runLookup(
                    lookup.host,
                    port: lookup.port,
                    record: lookup.record,
                  ),
                ),
        ),
      ];
    }
    final result = lookup.result;
    if (result == null) return const [];
    final sources = _sources;
    final winner = result.winner;
    final notices = <Widget>[..._lookupNotices(context, lookup, result)];
    final added = _added;
    final source = winner == null
        ? null
        : sources?.elementAtOrNull(winner.index);
    final group = winner?.target ?? '';
    final card = RuleHitCard(
      lookup: result,
      source: source,
      justAdded:
          added != null &&
          added.effective &&
          winner != null &&
          winner.type == ruleTypeOf(added.text),
      onChangeNode: winner == null || isBuiltinTarget(group)
          ? null
          : () => _revealGroup(group),
      onAddRule: _addRule,
      onCopyRule: () => _copy(winner?.rule.text ?? ''),
    );
    return [
      box(
        AnimatedOpacity(
          opacity: lookup.loading ? 0.45 : 1,
          duration: const Duration(milliseconds: 150),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Column(
              key: ValueKey(result),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [...notices, card],
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _lookupNotices(
    BuildContext context,
    _Lookup lookup,
    RuleLookup result,
  ) {
    final appLocalizations = context.appLocalizations;
    final notices = <Widget>[];
    final now = DateTime.now();
    final separator =
        appLocalizations.localeName.startsWith('zh') ||
            appLocalizations.localeName.startsWith('ja')
        ? '，'
        : ', ';
    final setItems = [
      for (final set in result.ruleSets)
        if (set.status == 'missing')
          appLocalizations.ruleSetNotDownloadedItem(set.name)
        else if (set.status == 'failed')
          appLocalizations.ruleSetFailedItem(set.name)
        else if (ruleSetOverdueDays(set, now) case final days when days > 0)
          appLocalizations.ruleSetExpiredItem(set.name, days),
    ];
    if (setItems.isNotEmpty) {
      notices.add(
        RulesNotice(
          tone: RuleTone.warning,
          glyph: AppGlyphs.warning,
          text: appLocalizations.ruleSetsIncomplete(setItems.join(separator)),
          actionLabel: appLocalizations.goUpdate,
          onAction: _showResources,
        ),
      );
    }
    if (result.resolveWanted &&
        result.resolveError.isNotEmpty &&
        result.ip.isEmpty) {
      notices.add(
        RulesNotice(
          tone: RuleTone.gray,
          glyph: AppGlyphs.info,
          text: appLocalizations.lookupResolveFailed,
        ),
      );
    }
    final record = lookup.record;
    final winner = result.winner;
    if (record != null) {
      final same =
          winner != null &&
          sameRuleAsRecord(
            winner.rule,
            recordRule: record.rule,
            recordPayload: record.payload,
          );
      final text = same
          ? appLocalizations.compareSame(record.text)
          : appLocalizations.compareDiffer(record.text);
      notices.add(
        RulesNotice(
          tone: same ? RuleTone.gray : RuleTone.warning,
          glyph: same ? AppGlyphs.info : AppGlyphs.warning,
          text: !same && record.ipOnly
              ? '$text ${appLocalizations.compareSniffNote}'
              : text,
        ),
      );
    }
    final added = _added;
    if (added != null) {
      notices.add(
        added.effective
            ? RulesNotice(
                tone: RuleTone.green,
                glyph: AppGlyphs.checkCircle,
                text: appLocalizations.addedEffective(added.host, added.group),
              )
            : RulesNotice(
                tone: RuleTone.warning,
                glyph: AppGlyphs.warning,
                text: appLocalizations.addedNotEffective(
                  added.index,
                  added.source,
                ),
                actionLabel: winner == null
                    ? null
                    : appLocalizations.viewThatRule,
                onAction: winner == null
                    ? null
                    : () => _scrollToRule(winner.index),
              ),
      );
    }
    return notices;
  }

  Widget _buildLookupChips(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final result = _lookup?.result;
    final count = result == null ? 0 : lookupRows(result).length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        RulesFilterChip(
          label: appLocalizations.rulesContaining(count),
          selected: !_showAll,
          onPressed: () => setState(() {
            _showAll = false;
            _focusIndex = null;
          }),
        ),
        RulesFilterChip(
          label: appLocalizations.rulesShowAll,
          selected: _showAll,
          onPressed: () {
            final winner = result?.winner;
            if (winner != null) {
              _scrollToRule(winner.index);
            } else {
              setState(() => _showAll = true);
            }
          },
        ),
      ],
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    RuleList list,
    List<RuleSource?>? sources,
  ) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final filter = _liveFilter;
    final indexes =
        filter?.indexes ?? [for (var i = 0; i < list.rules.length; i++) i];
    final counts = <RuleSourceFilter, int>{};
    for (final index in indexes) {
      final rule = list.rules.elementAtOrNull(index);
      if (rule == null) continue;
      if (_group != null && rule.target != _group) continue;
      counts.update(
        RuleSourceFilter.all,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final kind = sourceFilterOf(rule, sources?.elementAtOrNull(index));
      if (kind != null) {
        counts.update(kind, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final labels = {
      RuleSourceFilter.all: appLocalizations.ruleSourceAll,
      RuleSourceFilter.subscription: appLocalizations.ruleSourceSubscription,
      RuleSourceFilter.ruleSet: appLocalizations.ruleSet,
      RuleSourceFilter.added: appLocalizations.ruleSourceAdded,
      RuleSourceFilter.script: appLocalizations.ruleSourceScript,
    };
    final targets = _targets();
    final group = _group;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in labels.entries)
          // Without the build's sources only the Core's own kinds can show.
          if (sources != null ||
              entry.key == RuleSourceFilter.all ||
              entry.key == RuleSourceFilter.ruleSet)
            RulesFilterChip(
              label: entry.value,
              count: counts[entry.key] ?? 0,
              selected: _source == entry.key,
              onPressed: () => setState(() => _source = entry.key),
            ),
        PopupAnchor(
          placement: PopupPlacement.overAnchorStart,
          targetBuilder: (open) => RulesFilterChip(
            label: appLocalizations.rulesGroupFilter(
              group == null
                  ? appLocalizations.ruleSourceAll
                  : ruleTargetLabel(context, group),
            ),
            selected: group != null,
            onPressed: open,
            trailing: GlyphIcon(
              AppGlyphs.chevronDown,
              size: 12,
              color: group != null
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          popupBuilder: (_) => PopupMenu(
            maxVisibleItems: 10,
            items: [
              PopupMenuItem(
                label: appLocalizations.ruleSourceAll,
                checked: group == null,
                onPressed: () => setState(() => _group = null),
              ),
              for (final target in targets)
                PopupMenuItem(
                  label: ruleTargetLabel(context, target),
                  checked: group == target,
                  onPressed: () => setState(() => _group = target),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    RuleList list,
    List<RuleSource?>? sources,
    List<RuleRowItem> items,
    bool narrow,
  ) {
    final colorScheme = context.colorScheme;
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox());
    final winner = _lookup?.result?.winner;
    final highlighted = _focusIndex ?? winner?.index;
    final filter = _inLookup ? null : _liveFilter;
    return DecoratedSliver(
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      sliver: SliverPrismList(
        estimatedItemExtent: _rowExtentGuess,
        itemCount: items.length,
        itemBuilder: (context, position) {
          final item = items[position];
          final first = position == 0;
          final last = position == items.length - 1;
          final Widget row;
          if (item.isRule) {
            final rule = item.rule!;
            final index = rule.index;
            final expandable = !(_inLookup && !_showAll) && _expandable(rule);
            final set = rule.ruleSet;
            row = RuleRow(
              key: index == highlighted ? _targetRowKey : ValueKey(index),
              rule: rule,
              hit: item.hit,
              winnerIndex: winner?.index,
              source: sources?.elementAtOrNull(index),
              narrow: narrow,
              highlighted: index == highlighted && _inLookup,
              showNode: !_inLookup || item.hit?.status == RuleHitStatus.winner,
              expanded: expandable ? _isExpanded(index) : null,
              setMatches: set == null ? null : filter?.sets[set.name],
              first: first,
              last: last,
              onTap: expandable ? () => _toggle(index) : () => _copy(rule.text),
              onCopy: () => _copy(rule.text),
              onRevealGroup: isBuiltinTarget(rule.target)
                  ? null
                  : () => _revealGroup(rule.target),
              onUpdateSet: set != null && set.status != 'ok'
                  ? _showResources
                  : null,
            );
          } else if (item.isEntry) {
            row = RuleEntryRow(
              parent: item.parent,
              position: item.position,
              text: item.text,
              last: last,
              onTap: () => _copy(item.text),
            );
          } else {
            final page = _pageOf(item.parent);
            if (!page.loading && !page.done && page.error == null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _loadPage(item.parent),
              );
            }
            row = RuleSetFooterRow(
              loading: page.loading || !page.loaded,
              shown: page.entries.length,
              total: page.total,
              error: page.error == null ? null : _reasonOf(page.error!),
              last: last,
            );
          }
          return row;
        },
      ),
    );
  }
}

class _CoreStopped {
  const _CoreStopped();
}

class _PanelItem extends StatelessWidget {
  final bool highlighted;
  final VoidCallback onTap;
  final Widget child;

  const _PanelItem({
    this.highlighted = false,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: ShapeDecoration(
            color: highlighted
                ? colorScheme.primary.withValues(alpha: 0.08)
                : null,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The search box of the rules page: 44 high, its ring the primary color
/// with a soft halo while focused.
class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onEscape;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onChanged,
    required this.onSubmitted,
    required this.onEscape,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_update);
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_update);
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final focused = widget.focusNode.hasFocus;
    final hasText = widget.controller.text.isNotEmpty;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shadows: focused
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  spreadRadius: 3,
                ),
              ]
            : null,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            width: 1.5,
            color: focused ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        spacing: 8,
        children: [
          GlyphIcon(
            AppGlyphs.search,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          Expanded(
            child: Semantics(
              label: appLocalizations.rulesSearchLabel,
              textField: true,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      widget.onEscape,
                },
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  style: AppTextStyle.body.of(context),
                  decoration: InputDecoration.collapsed(
                    hintText: appLocalizations.rulesSearchHint,
                    hintStyle: AppTextStyle.body
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ),
          if (widget.loading)
            ActivityIndicator(
              size: 16,
              color: colorScheme.primary,
              semanticLabel: appLocalizations.rulesQuerying,
            )
          else if (hasText)
            Semantics(
              button: true,
              label: appLocalizations.clearSearch,
              child: GestureDetector(
                onTap: widget.onClear,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GlyphIcon(
                    AppGlyphs.clearField,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
