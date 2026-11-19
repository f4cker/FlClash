import 'dart:async';

import 'package:fl_clash/common/added_rule_edit.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/connection/process_view.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/mitm_modules.dart' show MitmModuleView;
import 'package:fl_clash/views/resources.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_rule_dialog.dart';
import 'hit_card.dart';
import 'rule_edit_dialogs.dart';
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
  final Metadata? metadata;
  final ({String rule, String payload, String text, bool ipOnly})? record;
  RuleLookup? result;
  Object? error;
  bool loading = true;

  _Lookup(this.host, {this.port, this.metadata, this.record});
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

/// A row the page edits: an added rule, with its rule set when it is one,
/// or a custom profile's own rule.
typedef _Editable = ({Rule rule, AddedRuleSet? set});

/// The rules the running Core holds, in the order they apply, and the one a
/// host or address takes.
class RulesView extends ConsumerStatefulWidget {
  /// Writes an added rule to a profile and reloads; null by default, which
  /// writes it to the profile's database and applies the profile.
  @visibleForTesting
  final Future<String?> Function(Profile profile, String text)? writeRule;

  const RulesView({super.key, this.writeRule});

  /// The page's scroll view, which runs under its bar.
  @visibleForTesting
  static const resultsKey = ValueKey('rules-results');
  static const subtitleKey = ValueKey('rules-subtitle');
  static const infoKey = ValueKey('rules-lookup-info');
  static const ruleSetNoticeKey = ValueKey('rules-rule-set-notice');
  static const queryingKey = ValueKey('rules-querying');
  static const addKey = ValueKey('rules-add');
  static const bannerKey = ValueKey('rules-banner');

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

  /// The added rules and rule sets of the profile the page shows.
  AddedRulesState? _editable;
  int? _editableProfileId;
  int _editableSerial = 0;

  /// The rule just saved, lit for a moment.
  int? _flashRuleId;
  Timer? _flashTimer;

  /// The note at the top after a change: what it did, or why it failed.
  ({String text, RuleTone tone, bool lookupAction})? _banner;
  Timer? _bannerTimer;

  /// The group the last rule added went through, for the next one.
  static String? _lastTarget;

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
    ref.listenManual(currentProfileIdProvider, (previous, next) {
      if (previous != next) unawaited(_loadEditable());
    });
    HardwareKeyboard.instance.addHandler(_onKey);
    _loadList();
    unawaited(_loadEditable());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _flashTimer?.cancel();
    _bannerTimer?.cancel();
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
    unawaited(_loadEditable());
    final lookup = _lookup;
    if (lookup != null && lookup.result != null) {
      _runLookup(
        lookup.host,
        port: lookup.port,
        metadata: lookup.metadata,
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
      port: int.tryParse(ask.metadata?.destinationPort ?? ''),
      metadata: ask.metadata,
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
    Metadata? metadata,
    ({String rule, String payload, String text, bool ipOnly})? record,
    bool keep = false,
  }) async {
    final serial = ++_lookupSerial;
    final previous = _lookup;
    final safePort = port != null && port > 0 && port <= 65535 ? port : null;
    final lookup = _Lookup(
      host,
      port: safePort,
      metadata: metadata,
      record: record,
    );
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
      final core = ref.read(coreHandlerProvider);
      final network = metadata?.network.toLowerCase();
      final params = RuleLookupParams(
        host: host,
        port: safePort,
        network: network == 'tcp' || network == 'udp' ? network : null,
      );
      final result = metadata == null
          ? await core.lookupRule(params)
          : await core.lookupRule(params, metadata: metadata);
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
    // The profile's own rules start under a divider once added ones show
    // above them; tracked as the rows are laid, since this runs every build.
    var addedAbove = false;
    var divided = false;
    // Each run of one module's rules sits under that module's title.
    (int?, String)? lastModule;
    final shown = <(int, CoreRule, RuleSource?)>[];
    for (final index in indexes) {
      final rule = list.rules.elementAtOrNull(index);
      if (rule == null) continue;
      final source = sources?.elementAtOrNull(index);
      if (!_inLookup &&
          !ruleShown(
            rule: rule,
            source: source,
            filter: _source,
            group: _group,
          )) {
        continue;
      }
      shown.add((index, rule, source));
    }
    for (final (position, (index, rule, source)) in shown.indexed) {
      final added = _isAddedSource(source);
      if (sources != null && !added && addedAbove && !divided) {
        final below = {
          for (final (_, _, source) in shown.skip(position))
            ?rulesBelowOf(source),
        };
        if (below.isNotEmpty) {
          items.add(
            RuleRowItem.divider(
              below: [
                for (final kind in RulesBelow.values)
                  if (below.contains(kind)) kind,
              ],
            ),
          );
        }
        divided = true;
      }
      final module = source?.kind == RuleSourceKind.mitm ? source : null;
      final key = module == null ? null : (module.moduleId, module.name);
      if (module != null && key != lastModule) {
        items.add(RuleRowItem.divider(module: module));
      }
      lastModule = key;
      addedAbove |= added;
      items.add(RuleRowItem.rule(rule, hit: hits[index]));
      _addChildren(items, index, rule, hits[index]);
    }
    return items;
  }

  bool _isAddedSource(RuleSource? source) =>
      source?.kind == RuleSourceKind.addedProfile ||
      source?.kind == RuleSourceKind.addedGlobal;

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

  // Adding and editing rules

  List<String> _targets() {
    final groups = ref.read(groupsProvider);
    return [
      for (final group in groups)
        if (group.name != GroupName.GLOBAL.name) group.name,
      'DIRECT',
      'REJECT',
    ];
  }

  AddedRulesAction get _actions => ref.read(addedRulesActionProvider.notifier);

  Future<void> _loadEditable() async {
    final profile = ref.read(currentProfileProvider);
    final serial = ++_editableSerial;
    if (profile == null) {
      if (mounted) setState(() => _editable = null);
      return;
    }
    try {
      final state = await _actions.load(profile);
      if (!mounted || serial != _editableSerial) return;
      setState(() {
        _editable = state;
        _editableProfileId = profile.id;
      });
    } catch (_) {
      // Without them the rows only read.
    }
  }

  /// The added rule, or custom profile's own, the row at [index] shows.
  _Editable? _editableAt(RuleSource? source) {
    final editable = _editable;
    final id = source?.ruleId;
    if (editable == null ||
        id == null ||
        _editableProfileId != ref.read(currentProfileIdProvider)) {
      return null;
    }
    final rule = editable.rules.where((rule) => rule.id == id).firstOrNull;
    if (rule == null) return null;
    final set = pairedAddedRuleSetFor(rule, editable.sets, _editableProfileId!);
    return (rule: rule, set: set);
  }

  /// The profile's own rules among the editable ones, in their order: the
  /// ones that move.
  List<Rule> get _ownRules => [
    for (final rule in _editable?.rules ?? const <Rule>[])
      if (rule.profileId != null) rule,
  ];

  List<String> _recentProcesses() {
    final names = <String>{};
    final requests = ref.read(requestsProvider).list;
    for (final request in requests.reversed) {
      final name = request.metadata.process.trim();
      if (name.isNotEmpty) names.add(name);
      if (names.length >= 30) break;
    }
    return names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyN ||
        !(HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) ||
        HardwareKeyboard.instance.isShiftPressed ||
        !mounted ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        !TickerMode.valuesOf(context).enabled) {
      return false;
    }
    unawaited(_openRuleDialog());
    return true;
  }

  /// Writes [rule] through the test hook, as the hit card's dialog did.
  Future<AddedRulesSave> _saveRule(
    Profile profile,
    Rule rule, {
    Rule? previous,
    bool last = false,
  }) async {
    _addedUnapplied = false;
    if (widget.writeRule case final write?) {
      final error = await write(profile, rule.rawValue);
      return (error: error, pending: false, ruleId: null);
    }
    final result = await _actions.putRule(
      profile,
      rule,
      previous: previous,
      last: last,
    );
    _addedUnapplied = result.pending;
    return result;
  }

  /// Opens the rule dialog: to add one, prefilled for a looked-up host when
  /// [host] is given, or to edit [editing].
  Future<void> _openRuleDialog({
    _Editable? editing,
    int? number,
    String? host,
  }) async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || !mounted) return;
    final prefill = host == null ? null : addedRulePrefill(host);
    final winner = host == null ? null : _lookup?.result?.winner;
    final targets = _targets();
    final rule = editing?.rule;
    final outcome = await dialogs.showCommonDialog<RuleEditOutcome>(
      dismissible: false,
      child: RuleEditDialog(
        profileLabel: profile.realLabel,
        coreRunning: _coreRunning,
        targets: targets,
        existing: _editable?.rules ?? const [],
        rule: rule,
        number: number,
        initialType: prefill?.type,
        initialValue: prefill?.value,
        initialTarget: winner?.target ?? _lastTarget,
        processNames: _recentProcesses(),
        onSave: (rule, {previous, last = false}) =>
            _saveRule(profile, rule, previous: previous, last: last),
        onDelete: rule == null
            ? null
            : () => _actions.deleteRule(profile, rule),
      ),
    );
    if (outcome == null || !mounted) return;
    if (!outcome.deleted) {
      final target = outcome.text.split(',').elementAtOrNull(2);
      if (target != null && target.isNotEmpty) _lastTarget = target;
    }
    await _afterSave(outcome, fromLookup: host != null);
  }

  Future<void> _openSetDialog({_Editable? editing, int? number}) async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || !mounted) return;
    final set = editing?.set;
    final rule = editing?.rule;
    final taken = {
      ..._actions.takenRuleSetNames(profile),
      for (final other in _editable?.sets ?? const <AddedRuleSet>[])
        if (other.id != set?.id) other.name,
    };
    final outcome = await dialogs.showCommonDialog<RuleEditOutcome>(
      dismissible: false,
      child: RuleSetEditDialog(
        profileLabel: profile.realLabel,
        coreRunning: _coreRunning,
        targets: _targets(),
        takenNames: taken,
        set: set,
        setTarget: rule?.ruleTarget,
        number: number,
        initialTarget: _lastTarget,
        onCheck: _actions.checkRuleSet,
        onSave: (built, {required target, check}) => _actions.putSet(
          profile,
          built.copyWith(profileId: profile.id),
          target: target,
          previous: set,
          rule: rule,
          content: check?.content,
        ),
        onDelete: set == null
            ? null
            : () => _actions.deleteSet(profile, set, rule: rule!),
        onRefresh: set == null ? null : () => _actions.refreshSet(profile, set),
      ),
    );
    if (outcome == null || !mounted) return;
    await _afterSave(outcome, fromLookup: false);
  }

  Future<void> _edit(_Editable editable, int number) {
    if (editable.set != null) {
      return _openSetDialog(editing: editable, number: number);
    }
    return _openRuleDialog(editing: editable, number: number);
  }

  /// Whether the rule dialog can show [rule]: one of the types it offers.
  bool _ruleDialogFits(Rule rule) =>
      addedRuleMainTypes.contains(rule.ruleAction) ||
      addedRuleMoreTypes.contains(rule.ruleAction);

  Future<void> _delete(_Editable editable) async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
    final set = editable.set;
    final text = editable.rule.rawValue;
    if (!await confirmRuleDelete(context, text: text, setName: set?.name)) {
      return;
    }
    final result = set != null
        ? await _actions.deleteSet(profile, set, rule: editable.rule)
        : await _actions.deleteRule(profile, editable.rule);
    if (!mounted) return;
    if (result.error case final error?) {
      _showBanner(error, RuleTone.red);
      return;
    }
    await _afterSave((
      text: text,
      name: set?.name ?? '',
      ruleId: null,
      pending: result.pending,
      isSet: set != null,
      edited: false,
      deleted: true,
    ), fromLookup: false);
  }

  Future<void> _move(_Editable editable, {required bool up}) async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
    final result = await _actions.moveRule(
      profile,
      editable.rule,
      up: up,
      expectedOrder: _ownRules,
    );
    if (!mounted) return;
    if (result.error case final error?) {
      _showBanner(context.appLocalizations.ruleMoveFailed(error), RuleTone.red);
    }
    await _loadEditable();
    await _loadList();
  }

  void _showBanner(String text, RuleTone tone, {bool lookupAction = false}) {
    _bannerTimer?.cancel();
    setState(
      () => _banner = (text: text, tone: tone, lookupAction: lookupAction),
    );
    // A failure stays until the next change; news goes after 4 s.
    if (tone != RuleTone.red) {
      _bannerTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _banner = null);
      });
    }
  }

  void _focusSearch() {
    setState(() => _banner = null);
    _scaffoldKey.currentState?.openSearch();
  }

  /// After a save: the list again, the saved row lit and in view, a note
  /// of what happened, and the current lookup run again.
  Future<void> _afterSave(
    RuleEditOutcome outcome, {
    required bool fromLookup,
  }) async {
    final appLocalizations = context.appLocalizations;
    final shown = outcome.isSet ? outcome.name : outcome.text;
    final text = outcome.deleted
        ? appLocalizations.ruleDeletedBanner
        : outcome.pending
        ? appLocalizations.ruleSavedPendingBanner
        : outcome.isSet
        ? (outcome.edited
              ? appLocalizations.ruleSetSavedBanner(shown)
              : appLocalizations.ruleSetAddedBanner(shown))
        : outcome.edited
        ? appLocalizations.ruleSavedBanner(shown)
        : appLocalizations.ruleAddedBanner(shown);
    _showBanner(
      text,
      RuleTone.green,
      lookupAction: !outcome.deleted && !outcome.pending && _lookup == null,
    );
    await _loadEditable();
    await _loadList();
    if (!mounted) return;
    final lookup = _lookup;
    if (lookup != null && lookup.result != null) {
      await _runLookup(
        lookup.host,
        port: lookup.port,
        metadata: lookup.metadata,
        record: lookup.record,
        keep: true,
      );
      if (!mounted) return;
      if (fromLookup && !outcome.deleted && !outcome.isSet) {
        _noteAddedOutcome(lookup, outcome.text);
      }
    }
    final ruleId = outcome.ruleId;
    if (ruleId != null && !outcome.deleted) _flashRule(ruleId);
  }

  void _flashRule(int ruleId) {
    _flashTimer?.cancel();
    setState(() => _flashRuleId = ruleId);
    _flashTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _flashRuleId = null);
    });
    final sources = _sources;
    final index = sources?.indexWhere((source) => source?.ruleId == ruleId);
    if (index == null || index < 0 || _inLookup) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealIndex(index));
  }

  /// Brings the row of rule [index] into view in the whole list.
  void _revealIndex(int index) {
    if (!mounted) return;
    final list = _list;
    final startContext = _listStartKey.currentContext;
    if (list == null || startContext == null || !_scrollController.hasClients) {
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
    final offset = start + position * _rowExtentGuess;
    final current = _scrollController.offset;
    if (offset >= current && offset + _rowExtentGuess <= current + viewport) {
      return;
    }
    _scrollController.animateTo(
      (offset - viewport / 3).clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Says whether the rule added from the hit card now decides the host.
  void _noteAddedOutcome(_Lookup lookup, String text) {
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

  Future<void> _addRule() async {
    final lookup = _lookup;
    if (lookup == null) return;
    await _openRuleDialog(host: lookup.host);
  }

  void _lookupAgain() {
    final lookup = _lookup;
    if (lookup == null) return;
    _runLookup(
      lookup.host,
      port: lookup.port,
      metadata: lookup.metadata,
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
      actions: [if (profile != null) _buildAddButton(context)],
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < _narrowWidth;
          return _buildBody(
            context,
            subtitle: subtitle,
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
    required String subtitle,
    required bool coreRunning,
    required bool narrow,
    required double bottomInset,
  }) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
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
      key: RulesView.resultsKey,
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: padding.copyWith(top: context.contentTopPadding),
          sliver: SliverToBoxAdapter(
            child: Text(
              subtitle,
              key: RulesView.subtitleKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        if (!coreRunning)
          box(
            RulesNotice(
              tone: RuleTone.red,
              glyph: AppGlyphs.error,
              text: appLocalizations.rulesCoreStopped,
            ),
          ),
        if (_banner case final banner?)
          box(
            Semantics(
              liveRegion: true,
              child: RulesNotice(
                key: RulesView.bannerKey,
                tone: banner.tone,
                glyph: banner.tone == RuleTone.red
                    ? AppGlyphs.error
                    : AppGlyphs.checkCircle,
                text: banner.text,
                actionLabel: banner.lookupAction
                    ? appLocalizations.ruleBannerLookup
                    : null,
                onAction: banner.lookupAction ? _focusSearch : null,
              ),
            ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (lookup.metadata case final metadata?)
            ConnectionProcessBuilder(
              metadata: metadata,
              builder: (context, process) => process.hasProcess
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        ProcessIcon(process: process, size: 16),
                        Text(processLabelOf(process)),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          Flexible(
            child: Text(
              info,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
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
    // A stopped Core is said once, at the top.
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
              metadata: lookup.metadata,
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
        if (source != null && source.kind == RuleSourceKind.script) source.name,
    };
    final modules = {
      for (final source in sources ?? const <RuleSource?>[])
        if (source != null && source.kind == RuleSourceKind.mitm) source.name,
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
      RuleSourceFilter.module: namedSourceLabel(
        appLocalizations.ruleSourceMitm,
        modules.length == 1 ? modules.single : '',
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
          if ((sources != null ||
                  entry.key == RuleSourceFilter.all ||
                  entry.key == RuleSourceFilter.ruleSet) &&
              (entry.key != RuleSourceFilter.module ||
                  (counts[entry.key] ?? 0) > 0 ||
                  _source == entry.key))
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

  Widget _buildAddButton(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return PopupAnchor(
      key: RulesView.addKey,
      placement: PopupPlacement.belowAnchorEnd,
      targetBuilder: (open) => Semantics(
        button: true,
        label: appLocalizations.rulesAddSemantics,
        excludeSemantics: true,
        child: IconButton(
          tooltip: appLocalizations.rulesAddTooltip,
          onPressed: open,
          icon: const GlyphIcon(AppGlyphs.add),
        ),
      ),
      popupBuilder: (_) => PopupMenu(
        width: 210,
        items: [
          PopupMenuItem(
            label: appLocalizations.rulesAddRuleMenu,
            onPressed: () => unawaited(_openRuleDialog()),
          ),
          PopupMenuItem(
            label: appLocalizations.rulesAddSetMenu,
            onPressed: () => unawaited(_openSetDialog()),
          ),
        ],
      ),
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
          if (item.isDivider) {
            final moduleId = item.module?.moduleId;
            row = RulesDividerRow(
              module: item.module?.name,
              below: item.below,
              onOpenModule: moduleId == null
                  ? null
                  : () => BaseNavigator.push(
                      context,
                      MitmModuleView(id: moduleId),
                    ),
            );
          } else if (item.isRule) {
            final rule = item.rule!;
            final index = rule.index;
            final expandable = _expandable(rule);
            final set = rule.ruleSet;
            // Any visible child row, even only the matched entry, means
            // the row reads as open; a tap then shows every entry, and
            // the next one goes back to the matched entry alone.
            final open =
                _isExpanded(index) || _matchedEntryOf(item.hit) != null;
            final source = sources?.elementAtOrNull(index);
            final editable = _editableAt(source);
            final own = _ownRules;
            final ownIndex = editable == null
                ? -1
                : own.indexWhere((rule) => rule.id == editable.rule.id);
            final number = index + 1;
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
              flashing: editable != null && editable.rule.id == _flashRuleId,
              onEdit:
                  editable == null ||
                      (editable.set == null && !_ruleDialogFits(editable.rule))
                  ? null
                  : () => _edit(editable, number),
              onDelete: editable == null ? null : () => _delete(editable),
              onMoveUp: ownIndex > 0 ? () => _move(editable!, up: true) : null,
              onMoveDown: ownIndex != -1 && ownIndex < own.length - 1
                  ? () => _move(editable!, up: false)
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
