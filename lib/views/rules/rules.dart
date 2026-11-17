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

/// How long typing rests before a host typed in looks itself up.
const _lookupDelay = Duration(milliseconds: 400);
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

/// Whether an added rule decides the host now, as a lookup after adding
/// it tells: it does, it does not, or the lookup cannot say.
enum _AddedState { effective, notHit, unconfirmed }

/// What the page says after it added a rule; [index] is the rule that
/// matches first instead, when the lookup confirms it.
typedef _AddedOutcome = ({
  _AddedState state,
  String host,
  String group,
  int? index,
  String text,
});

/// The rules the running Core holds, in the order they apply, and the one a
/// host or address takes.
class RulesView extends ConsumerStatefulWidget {
  /// Writes an added rule to a profile and reloads; null by default, which
  /// writes it to the profile's database and applies the profile.
  @visibleForTesting
  final Future<String?> Function(Profile profile, String text)? writeRule;

  const RulesView({super.key, this.writeRule});

  /// The scrolling part of the page, under its fixed title and search box.
  @visibleForTesting
  static const resultsKey = ValueKey('rules-results');
  static const headerKey = ValueKey('rules-header');
  static const infoKey = ValueKey('rules-lookup-info');
  static const ruleSetNoticeKey = ValueKey('rules-rule-set-notice');
  static const queryingKey = ValueKey('rules-querying');
  static const scrollEdgeKey = ValueKey('rules-scroll-edge');

  @override
  ConsumerState<RulesView> createState() => _RulesViewState();
}

class _RulesViewState extends ConsumerState<RulesView> {
  final _controller = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ScrollController _scrollController;
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
  Timer? _lookupTimer;
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

  /// Whether the last added rule was written but its profile not reloaded.
  bool _addedUnapplied = false;

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
    _lookupTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _coreRunning => ref.read(coreStatusProvider) == CoreStatus.connected;

  bool get _inLookup => _lookup != null;

  String get _profileName => ref.read(currentProfileProvider)?.realLabel ?? '';

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
    _filterTimer?.cancel();
    _lookupTimer?.cancel();
    if (text.trim().isEmpty) {
      _clearSearch();
      return;
    }
    if (wasEmpty && _scrollController.hasClients) {
      _savedOffset = _scrollController.offset;
    }
    final host = lookupHostOf(text);
    final port = lookupPortOf(text);
    final lookup = _lookup;
    final same = lookup != null && lookup.host == host && lookup.port == port;
    if (lookup != null && !same) {
      // Only the latest query's answer may show: one for older input is
      // dropped, in flight or not.
      _lookupSerial++;
      _lookup = null;
      _added = null;
      _showAll = false;
      _focusIndex = null;
    }
    _filterTimer = Timer(
      const Duration(milliseconds: 200),
      () => _runFilter(text),
    );
    // A host, a link or an address looks itself up once typing stops.
    if (host != null && !same) {
      _lookupTimer = Timer(_lookupDelay, () => _runLookup(host, port: port));
    }
    setState(() {});
  }

  void _clearSearch() {
    _filterTimer?.cancel();
    _lookupTimer?.cancel();
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

  void _submit() {
    _lookupTimer?.cancel();
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
    _lookupTimer?.cancel();
    _scaffoldKey.currentState?.openSearch();
    _filterTimer?.cancel();
    _runFilter(ask.host);
    _runLookup(
      ask.host,
      record: ask.rule.isEmpty
          ? null
          : (
              rule: ask.rule,
              payload: ask.rulePayload,
              text: recordRuleText(ask.rule, ask.rulePayload),
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
      if (!keep) {
        _added = null;
        _showAll = false;
        _focusIndex = null;
      }
    });
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
        _addChildren(items, hit.index, hit.rule, hit);
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
      _addChildren(items, index, rule, hits[index]);
    }
    return items;
  }

  /// The child rows of a rule set: every entry (paged) when expanded,
  /// otherwise just the entry that matched the lookup, if any.
  void _addChildren(
    List<RuleRowItem> items,
    int index,
    CoreRule rule,
    RuleHit? hit,
  ) {
    if (_expandable(rule) && _isExpanded(index)) {
      final page = _pageOf(index);
      for (final (position, entry) in page.entries.indexed) {
        items.add(
          RuleRowItem.entry(parent: index, position: position, text: entry),
        );
      }
      items.add(RuleRowItem.footer(parent: index));
    } else if (_matchedEntryOf(hit) case final entry?) {
      items.add(RuleRowItem.entry(parent: index, position: 0, text: entry));
    }
  }

  /// The rule-set entry [hit] matched, shown under its row while collapsed.
  String? _matchedEntryOf(RuleHit? hit) {
    if (!_inLookup || hit == null || hit.ruleSet == null) return null;
    return hit.entry.isEmpty ? null : hit.entry;
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

  /// Writes [text] as an added rule of [profile] and reloads it; null once
  /// the rule is written, or why it was not. A rule written whose reload
  /// failed counts as added, and the page says it cannot confirm it.
  Future<String?> _writeRule(Profile profile, String text) async {
    _addedUnapplied = false;
    if (widget.writeRule case final write?) return write(profile, text);
    final appLocalizations = context.appLocalizations;
    try {
      await putProfileRuleFirst(profile.id, Rule.parse(text));
    } catch (error) {
      return appLocalizations.addRuleWriteFailed('$error');
    }
    ref.invalidate(setupStateProvider(profile.id));
    final applied = await ref
        .read(setupActionProvider.notifier)
        .applyProfile(silence: true);
    _addedUnapplied = !applied;
    return null;
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
    final type = ruleTypeOf(text);
    final payload = fields.length > 1 ? fields[1] : '';
    bool isAdded(RuleHit hit) => hit.type == type && hit.payload == payload;
    final _AddedState state;
    int? index;
    if (_addedUnapplied || result == null || lookupUncertain(result)) {
      state = _AddedState.unconfirmed;
    } else if (now != null && isAdded(now)) {
      state = _AddedState.effective;
    } else {
      state = _AddedState.notHit;
      // The lookup names the rule that went first only when it lists the
      // added one as passed over by it.
      final shadowed = result.matches.any(
        (hit) => isAdded(hit) && hit.status == RuleHitStatus.shadowed,
      );
      if (now != null && shadowed) index = now.index;
    }
    setState(() {
      _added = (
        state: state,
        host: lookup.host,
        group: ruleTargetLabel(context, target),
        index: index,
        text: text,
      );
    });
  }

  void _lookupAgain() {
    final lookup = _lookup;
    if (lookup == null) return;
    _runLookup(
      lookup.host,
      port: lookup.port,
      record: lookup.record,
      keep: true,
    );
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
        : appLocalizations.rulesSubtitle(
            profileLabel,
            groupedCount(list.total),
          );
    return Scaffold(
      key: _scaffoldKey,
      title: appLocalizations.rules,
      searchState: AppBarSearchState(
        onSearch: _onChanged,
        controller: _controller,
        hintText: appLocalizations.rulesSearchHint,
        onSubmitted: (_) => _submit(),
        trailing: _lookup?.loading ?? false
            ? Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: ActivityIndicator(
                  key: RulesView.queryingKey,
                  size: 16,
                  color: colorScheme.primary,
                  semanticLabel: appLocalizations.rulesQuerying,
                ),
              )
            : null,
      ),
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
          return _buildBody(
            context,
            coreRunning: coreRunning,
            narrow: narrow,
            bottomInset: context.bottomInset,
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool coreRunning,
    required bool narrow,
    required double bottomInset,
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
    // The gap above the first block belongs to the pinned header, so
    // the scroll area starts right where the header's background ends.
    var first = true;
    Widget box(Widget child, {double top = 12}) {
      final gap = first ? 0.0 : top;
      first = false;
      return SliverPadding(
        padding: padding.copyWith(top: gap),
        sliver: SliverToBoxAdapter(child: child),
      );
    }

    final dimmed = !coreRunning;
    // The notices of the page's state and the search box stay put under
    // the title; only the results and rules below them scroll, clipped at
    // their own top, so nothing slides under the title or the search box.
    final header = ColoredBox(
      key: RulesView.headerKey,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: padding.copyWith(top: context.contentTopPadding, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            if (!coreRunning)
              RulesNotice(
                tone: RuleTone.red,
                glyph: AppGlyphs.error,
                text: appLocalizations.rulesCoreStopped,
              ),
            if (mode == 'global' || mode == 'direct')
              RulesNotice(
                tone: RuleTone.gray,
                glyph: AppGlyphs.info,
                text: mode == 'global'
                    ? appLocalizations.rulesModeGlobal
                    : appLocalizations.rulesModeDirect,
              ),
          ],
        ),
      ),
    );
    final results = CustomScrollView(
      key: RulesView.resultsKey,
      controller: _scrollController,
      slivers: [
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
        // A lookup with no answer yet shows its line, or its error, alone.
        if (lookup != null && lookup.result == null)
          const SliverToBoxAdapter()
        else if (list != null) ...[
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
            padding: padding.copyWith(bottom: 24 + bottomInset),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(child: results),
                // Once the results scroll, a hairline marks the cut so a
                // sliver of a card never reads as a stray line.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: ListenableBuilder(
                    listenable: _scrollController,
                    builder: (context, _) {
                      final scrolled =
                          _scrollController.hasClients &&
                          _scrollController.positions.length == 1 &&
                          _scrollController.offset > 0;
                      return Visibility(
                        visible: scrolled,
                        child: const Divider(
                          key: RulesView.scrollEdgeKey,
                          height: 1,
                          thickness: 1,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _reasonOf(Object error) {
    if (error is CoreMethodException) return error.message;
    return '$error';
  }

  /// What the lookup asked and that it may resolve, under the title bar.
  Widget? _buildLookupInfo(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final lookup = _lookup;
    final result = lookup?.result;
    if (lookup == null || result == null) return null;
    final info = [
      lookup.host,
      if (lookup.port != null) ':${lookup.port}',
      if (result.resolveWanted || result.ipSource == 'dns')
        ' · ${appLocalizations.lookupNoConnectNote}',
    ].join();
    return Padding(
      key: RulesView.infoKey,
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        info,
        style: AppTextStyle.caption1
            .of(context)
            .copyWith(color: context.colorScheme.onSurfaceVariant),
      ),
    );
  }

  /// Said while a lookup with nothing yet to show is on its way.
  Widget _buildQuerying(BuildContext context, String host) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        context.appLocalizations.rulesQueryingHost(host),
        style: AppTextStyle.caption1
            .of(context)
            .copyWith(color: context.colorScheme.onSurfaceVariant),
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
    // A stopped Core is said once, above the search box.
    if (error is _CoreStopped) return const [];
    if (error != null) {
      return [
        box(
          RulesNotice(
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
    if (result == null) {
      return [if (lookup.loading) box(_buildQuerying(context, lookup.host))];
    }
    final sources = _sources;
    final winner = result.winner;
    final notices = <Widget>[..._lookupNotices(context, lookup, result)];
    final added = _added;
    final source = winner == null
        ? null
        : sources?.elementAtOrNull(winner.index);
    final group = winner?.target ?? '';
    final coreRunning = ref.watch(
      coreStatusProvider.select((status) => status == CoreStatus.connected),
    );
    final card = RuleHitCard(
      profile: _profileName,
      lookup: result,
      source: source,
      enabled: coreRunning,
      rulesIdle: result.mode == 'global' || result.mode == 'direct',
      justAdded:
          added != null &&
          added.state == _AddedState.effective &&
          winner != null &&
          winner.type == ruleTypeOf(added.text),
      onChangeNode: winner == null || isBuiltinTarget(group)
          ? null
          : () => _revealGroup(group),
      onAddRule: _addRule,
      onCopyRule: () => _copy(winner?.rule.text ?? ''),
    );
    return [
      if (_buildLookupInfo(context) case final info?) box(info),
      box(
        top: 8,
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
    // The rule sets this answer read that are not whole, in one line with
    // one way to update them.
    final issues = [
      for (final set in result.ruleSets)
        ?switch (set.status) {
          'missing' => appLocalizations.ruleSetIssueMissing(set.name),
          'failed' => appLocalizations.ruleSetIssueFailed(set.name),
          _ when ruleSetOverdueDays(set, now) > 0 =>
            appLocalizations.ruleSetIssueExpired(set.name),
          _ => null,
        },
    ];
    if (issues.isNotEmpty) {
      notices.add(
        RulesNotice(
          key: RulesView.ruleSetNoticeKey,
          tone: RuleTone.warning,
          glyph: AppGlyphs.warning,
          text: appLocalizations.ruleSetIssuesNotice(
            issues.join(appLocalizations.ruleSetIssueSeparator),
          ),
          actionLabel: appLocalizations.goUpdate,
          onAction: _showResources,
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
      notices.add(
        RulesNotice(
          tone: same ? RuleTone.gray : RuleTone.warning,
          glyph: same ? AppGlyphs.info : AppGlyphs.warning,
          text: same
              ? appLocalizations.compareSame
              : appLocalizations.compareDiffer(record.text),
        ),
      );
    }
    final added = _added;
    if (added != null) {
      final index = added.index;
      notices.add(switch (added.state) {
        _AddedState.effective => RulesNotice(
          tone: RuleTone.green,
          glyph: AppGlyphs.checkCircle,
          text: appLocalizations.addedEffective(added.host, added.group),
        ),
        _AddedState.notHit => RulesNotice(
          tone: RuleTone.warning,
          glyph: AppGlyphs.warning,
          text: index == null
              ? appLocalizations.addedNotHit
              : '${appLocalizations.addedNotHit}'
                    '${appLocalizations.addedNotHitBy(index + 1)}',
          actionLabel: index == null ? null : appLocalizations.viewThatRule,
          onAction: index == null ? null : () => _scrollToRule(index),
        ),
        _AddedState.unconfirmed => RulesNotice(
          tone: RuleTone.warning,
          glyph: AppGlyphs.warning,
          text: appLocalizations.addedUnconfirmed,
          actionLabel: appLocalizations.relookup,
          onAction: _lookupAgain,
        ),
      });
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
    // A chip names its source when there is one of it: the profile, or the
    // one script; rule sets are many, each named on its own rows.
    final profile = _profileName;
    final scripts = {
      for (final source in sources ?? const <RuleSource?>[])
        if (source != null &&
            (source.kind == RuleSourceKind.script ||
                source.kind == RuleSourceKind.mitm))
          source.name,
    };
    final labels = {
      RuleSourceFilter.all: (label: appLocalizations.ruleSourceAll, full: null),
      RuleSourceFilter.subscription: namedSourceLabel(
        appLocalizations.ruleSourceSubscription,
        profile,
      ),
      RuleSourceFilter.ruleSet: (label: appLocalizations.ruleSet, full: null),
      RuleSourceFilter.added: namedSourceLabel(
        appLocalizations.ruleSourceAdded,
        profile,
      ),
      RuleSourceFilter.script: namedSourceLabel(
        appLocalizations.ruleSourceScript,
        scripts.length == 1 ? scripts.single : '',
      ),
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
              label: entry.value.label,
              tooltip: entry.value.full,
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
    if (items.isEmpty) {
      final filtered =
          !_inLookup &&
          (_liveFilter != null ||
              _source != RuleSourceFilter.all ||
              _group != null);
      if (!filtered) return const SliverToBoxAdapter(child: SizedBox());
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Text(
            context.appLocalizations.rulesEmptyFiltered,
            textAlign: TextAlign.center,
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
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
            final expandable = _expandable(rule);
            final set = rule.ruleSet;
            // Any visible child row, even only the matched entry, means
            // the row reads as open; a tap then shows every entry, and
            // the next one goes back to the matched entry alone.
            final open =
                _isExpanded(index) || _matchedEntryOf(item.hit) != null;
            row = RuleRow(
              profile: _profileName,
              key: index == highlighted ? _targetRowKey : ValueKey(index),
              rule: rule,
              hit: item.hit,
              winnerIndex: winner?.index,
              source: sources?.elementAtOrNull(index),
              narrow: narrow,
              highlighted: index == highlighted && _inLookup,
              showNode: !_inLookup || item.hit?.status == RuleHitStatus.winner,
              expanded: expandable ? open : null,
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
              highlighted:
                  _inLookup &&
                  winner != null &&
                  item.parent == winner.index &&
                  item.text == winner.entry,
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
