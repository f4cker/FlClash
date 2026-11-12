import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add.dart';
import 'mount_groups.dart';

/// The glyph of every mount entry point.
const mountGlyph = AppGlyphs.cloudDownload;

/// A load that gives no answer in this long reads as a failure, design §6.
const mountLoadTimeout = Duration(seconds: 10);

/// Opens the mount sheet bound to [target], which it never switches to.
Future<void> showMountSheet(BuildContext context, Profile target) {
  return showSheet<void>(
    context: context,
    builder: (_) => MountSheet(targetId: target.id),
  );
}

/// How far a page bar's fade hangs past its foot (prism_ui's private
/// `_headerOverhang`); the list starts below it so nothing scrolls under it.
const double _barFadeOverhang = 16;

/// The banner a save, apply or readback leaves, design §4 and §11.
enum _Result {
  applying,
  savedUnconfirmed,
  unchanged,
  needsGroup,
  applyFailed,
  applyKept,
  applyBlocked,
  unknown,
}

enum MountGroupCase { auto, none, failed }

enum MountRunState { confirmed, unconfirmed, blocked }

/// An update read but refused: [kept] runs the last confirmed profile.
enum MountRefreshRefusal { kept, blocked }

MountRefreshRefusal? mountRefreshRefusalOf(MountSourceRefresh result) {
  if (!result.updated) {
    return null;
  }
  return switch (result.application) {
    MountSaveOutcome.applyFailedKept => MountRefreshRefusal.kept,
    MountSaveOutcome.applyFailedBlocked => MountRefreshRefusal.blocked,
    _ => null,
  };
}

MountGroupCase mountGroupCaseOf(MountTarget? target) {
  if (target == null) {
    return MountGroupCase.failed;
  }
  if (target.groups.any((group) => group.kind == MountGroupKind.auto)) {
    return MountGroupCase.auto;
  }
  return MountGroupCase.none;
}

class MountSheet extends ConsumerStatefulWidget {
  const MountSheet({super.key, required this.targetId});

  final int targetId;

  @override
  ConsumerState<MountSheet> createState() => _MountSheetState();
}

class _MountSheetState extends ConsumerState<MountSheet> {
  MountPanel? _panel;
  bool _loadFailed = false;
  MountRuntimeState? _runtime;
  var _generation = 0;

  Set<int> _selected = {};

  /// The groups row opens, and past eight rows shows them all, until the
  /// sheet reopens, design §12 and §13.
  bool _groupsOpen = false;
  bool _allGroups = false;

  /// The notices banner and the format help of each such row open in place
  /// and stay open until the sheet reopens, design §13.
  bool _noticesOpen = false;
  bool _groupDetailsOpen = false;
  final Set<int> _formatHelp = {};

  bool _saving = false;
  bool _removal = false;
  bool _rechecking = false;
  _Result? _result;

  /// A block the sheet saw happen locks it until one readback confirms it.
  bool _blockUnread = false;

  /// Keys the footer's primary button: a press replaces it, so a pressed
  /// button is never disabled in place, even when no frame passes between.
  var _presses = 0;

  final Set<int> _refreshing = {};
  final Set<int> _refreshUnconfirmed = {};
  final Map<int, MountRefreshRefusal> _refused = {};
  List<String> _lost = const [];

  MountAction get _mounts => ref.read(mountActionProvider.notifier);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Set<int> get _mounted => {...?_panel?.stored?.sourceIds};

  /// [resetChoice] puts the boxes back to what is stored; otherwise the
  /// staged choice survives, as across an import.
  Future<void> _load({bool resetChoice = true}) async {
    final generation = ++_generation;
    setState(() {
      _loadFailed = false;
      if (resetChoice) {
        _panel = null;
      }
    });
    MountPanel panel;
    try {
      panel = await _mounts
          .loadPanel(widget.targetId)
          .timeout(mountLoadTimeout);
    } catch (error) {
      commonPrint.log(
        'mount panel unreadable: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      if (mounted && generation == _generation) {
        setState(() => _loadFailed = true);
      }
      return;
    }
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() {
      final previous = _panel;
      _panel = panel;
      final sourceIds = {for (final item in panel.sources) item.profile.id};
      if (resetChoice || previous == null) {
        _selected = {...?panel.stored?.sourceIds};
      } else {
        _selected = {
          for (final id in _selected)
            if (sourceIds.contains(id)) id,
        };
      }
      if (panel.stored?.pending != null) {
        _result = _Result.unknown;
      }
    });
    unawaited(_loadRuntime());
  }

  Future<void> _loadRuntime() async {
    final runtime = await _mounts.readRuntime(widget.targetId);
    if (mounted) {
      setState(() => _runtime = runtime);
    }
  }

  bool get _blockSettled =>
      !_blockUnread && _panel?.stored?.pending == null && !_saving;

  bool get _locked =>
      _result == _Result.unknown ||
      _result == _Result.applyBlocked && _blockUnread;

  MountGroupCase get _groupCase => mountGroupCaseOf(_panel?.groups);

  bool get _dirty => !setEquals(_selected, _mounted);

  Set<int> get _additions => _selected.difference(_mounted);

  Set<int> get _removals => _mounted.difference(_selected);

  /// A change that only unchecks mounted sources needs no group.
  bool get _onlyRemoves => _additions.isEmpty;

  bool get _canSave {
    if (_panel == null || !_dirty || _locked || _saving || _rechecking) {
      return false;
    }
    return switch (_groupCase) {
      MountGroupCase.auto => true,
      MountGroupCase.none || MountGroupCase.failed => _onlyRemoves,
    };
  }

  /// Mounted sources keep their place; new ones follow in list order.
  List<int> get _orderedSelection {
    final stored = _panel?.stored?.sourceIds ?? const <int>[];
    return [
      for (final id in stored)
        if (_selected.contains(id)) id,
      for (final item in _panel!.sources)
        if (_selected.contains(item.profile.id) &&
            !stored.contains(item.profile.id))
          item.profile.id,
    ];
  }

  String _nameOf(int id) {
    for (final item in _panel?.sources ?? const <MountSourceItem>[]) {
      if (item.profile.id == id) {
        return item.profile.realLabel;
      }
    }
    return ref.read(profilesProvider).getProfile(id)?.realLabel ?? '';
  }

  Future<bool> _confirmChange() async {
    final removals = [
      for (final id in _panel!.stored!.sourceIds)
        if (_removals.contains(id)) id,
    ];
    final additions = [
      for (final item in _panel!.sources)
        if (_additions.contains(item.profile.id)) item.profile.id,
    ];
    final appLocalizations = context.appLocalizations;
    final profileName = _panel!.target.realLabel;
    final mixed = additions.isNotEmpty;
    final single = removals.length == 1;
    final res = await dialogs.showMessage(
      context: context,
      title: mixed
          ? appLocalizations.mountUpdateTitle
          : single
          ? appLocalizations.mountUnmountTitle
          : appLocalizations.mountUnmountManyTitle,
      body: _ChangeBody(
        body: single
            ? appLocalizations.mountUnmountBody(
                _nameOf(removals.single),
                profileName,
              )
            : appLocalizations.mountUnmountManyBody(
                removals.length,
                profileName,
              ),
        removed: [
          if (!single)
            for (final id in removals) _nameOf(id),
        ],
        alsoMounts: mixed
            ? appLocalizations.mountAlsoMounts(additions.length)
            : null,
        added: [for (final id in additions) _nameOf(id)],
      ),
      destructive: !mixed,
      cancelText: appLocalizations.cancel,
      confirmText: mixed
          ? appLocalizations.mountSave
          : appLocalizations.mountUnmount,
    );
    return res == true;
  }

  Future<void> _save() async {
    _presses++;
    final panel = _panel;
    if (panel == null || !_canSave) {
      return;
    }
    if (_removals.isNotEmpty && !await _confirmChange()) {
      return;
    }
    if (!mounted) {
      return;
    }
    final removal = _additions.isEmpty && _removals.isNotEmpty;
    setState(() {
      _saving = true;
      _removal = removal;
      _result = null;
    });
    final result = await _mounts.save(
      widget.targetId,
      expectedVersion: panel.stored?.version,
      sourceIds: _orderedSelection,
      onStored: () {
        if (mounted) {
          setState(() => _result = _Result.applying);
        }
      },
    );
    if (!mounted) {
      return;
    }
    final keepChoice = switch (result.outcome) {
      MountSaveOutcome.unchanged || MountSaveOutcome.needsGroup => true,
      _ => false,
    };
    setState(() {
      _saving = false;
      _result = _resultOf(result.outcome);
      _blockUnread = _result == _Result.applyBlocked;
      _lost = result.lostSelections;
      if (result.outcome == MountSaveOutcome.applied) {
        _refused.clear();
      }
    });
    _announce(result.outcome, removal: removal);
    await _load(resetChoice: !keepChoice);
  }

  _Result? _resultOf(MountSaveOutcome outcome) => switch (outcome) {
    MountSaveOutcome.applied => null,
    MountSaveOutcome.appliedUnverified ||
    MountSaveOutcome.saved => _Result.savedUnconfirmed,
    MountSaveOutcome.unchanged => _Result.unchanged,
    MountSaveOutcome.needsGroup => _Result.needsGroup,
    MountSaveOutcome.locked || MountSaveOutcome.unknown => _Result.unknown,
    MountSaveOutcome.applyFailedKept => _Result.applyKept,
    MountSaveOutcome.applyFailedBlocked => _Result.applyBlocked,
    MountSaveOutcome.applyFailed => _Result.applyFailed,
  };

  void _announce(MountSaveOutcome outcome, {required bool removal}) {
    if (outcome != MountSaveOutcome.applied) {
      return;
    }
    final appLocalizations = context.appLocalizations;
    dialogs.showBanner(
      removal ? appLocalizations.mountUnmounted : appLocalizations.mountUpdated,
      level: BannerLevel.success,
    );
  }

  /// Only a readback that resolves the outcome unlocks; finishing the read
  /// does not.
  Future<void> _recheck() async {
    _presses++;
    setState(() => _rechecking = true);
    final result = await _mounts.recheck(widget.targetId);
    if (!mounted) {
      return;
    }
    setState(() {
      _rechecking = false;
      if (result.outcome == MountSaveOutcome.applied) {
        _refused.clear();
      }
      if (result.outcome != MountSaveOutcome.unknown) {
        _blockUnread = false;
        _result = switch (result.outcome) {
          MountSaveOutcome.applied || MountSaveOutcome.saved => null,
          final outcome => _resultOf(outcome),
        };
      }
    });
    if (result.outcome != MountSaveOutcome.unknown) {
      await _load();
    }
  }

  Future<void> _refresh(int sourceId) async {
    setState(() => _refreshing.add(sourceId));
    final result = await _mounts.refreshSource(
      sourceId,
      targetId: widget.targetId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _refreshing.remove(sourceId);
      if (result.application == MountSaveOutcome.unknown) {
        _refreshUnconfirmed.add(sourceId);
      } else if (result.updated) {
        _refreshUnconfirmed.remove(sourceId);
      }
      if (result.updated) {
        _refused.remove(sourceId);
        if (mountRefreshRefusalOf(result) case final refusal?) {
          _refused[sourceId] = refusal;
        }
      }
      if (_refused[sourceId] == MountRefreshRefusal.blocked) {
        _result = _Result.applyBlocked;
        _blockUnread = true;
      }
      if (result.application != null) {
        _lost = result.lostSelections;
      }
      final item = result.item;
      final panel = _panel;
      if (item != null && panel != null) {
        _panel = panel.copyWith(
          sources: [
            for (final source in panel.sources)
              source.profile.id == sourceId
                  ? item.copyWith(mounted: source.mounted)
                  : source,
          ],
        );
      }
    });
    if (_reliablyUpdated(result)) {
      dialogs.showBanner(
        context.appLocalizations.mountNodesUpdated,
        level: BannerLevel.success,
      );
    }
    unawaited(_loadRuntime());
  }

  /// Nodes updated only when they were read, judged mountable and, where
  /// they are mounted on the running profile, applied, copy §4 and §8.
  bool _reliablyUpdated(MountSourceRefresh result) {
    if (!result.updated || !(result.item?.state.fetched ?? false)) {
      return false;
    }
    return switch (result.application) {
      null || MountSaveOutcome.applied || MountSaveOutcome.saved => true,
      _ => false,
    };
  }

  Future<void> _import() async {
    await importProfilesFromLinks(context, ref, showProfiles: false);
    if (mounted) {
      await _load(resetChoice: false);
    }
  }

  void _toggleSource(MountSourceItem item, bool value) {
    setState(() {
      if (value) {
        _selected.add(item.profile.id);
      } else {
        _selected.remove(item.profile.id);
      }
      if (_result != _Result.applying) {
        _result = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final target =
        _panel?.target ??
        ref.watch(profilesProvider).getProfile(widget.targetId);
    final panel = _panel;
    final Widget content;
    if (panel == null && _loadFailed) {
      content = _LoadFailed(onRetry: _load);
    } else if (panel == null) {
      content = const _LoadingRows();
    } else if (panel.sources.isEmpty) {
      content = _EmptySources(onImport: _import);
    } else {
      content = _buildSources(context, panel);
    }
    // The bar floats over the body with a fade; the list scrolls only
    // between it and the footer, both on the sheet's own surface.
    final background = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      title: appLocalizations.mountEntry,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: background,
            child: SizedBox(
              height:
                  context.appBarInset +
                  (context.isInCompactSheet ? 0 : _barFadeOverhang),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (target != null)
                    Row(
                      spacing: 4,
                      children: [
                        Flexible(
                          child: Text(
                            appLocalizations.mountTarget(target.realLabel),
                            style: AppTextStyle.body.of(
                              context,
                              emphasized: true,
                            ),
                          ),
                        ),
                        InfoButton(
                          label: appLocalizations.mountAbout,
                          paragraphs: [appLocalizations.mountAboutBody],
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    appLocalizations.mountDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  content,
                ],
              ),
            ),
          ),
          ColoredBox(color: background, child: _buildFooter(context)),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final List<Widget> buttons;
    if (_locked) {
      buttons = [
        TonalButton(
          label: appLocalizations.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        FilledButton.icon(
          key: ValueKey(('recheck', _presses)),
          onPressed: _rechecking ? null : _recheck,
          icon: _rechecking
              ? const ActivityIndicator(size: 14)
              : const GlyphIcon(AppGlyphs.sync, size: 16, fill: 1),
          label: Text(appLocalizations.mountReadStatus),
        ),
      ];
    } else {
      buttons = [
        TonalButton(
          label: appLocalizations.cancel,
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
        ),
        _saving
            ? FilledButton.icon(
                key: ValueKey(('saving', _presses)),
                onPressed: null,
                icon: const ActivityIndicator(size: 14),
                label: Text(
                  _removal
                      ? appLocalizations.mountUnmounting
                      : appLocalizations.mountSaving,
                ),
              )
            : FilledButton(
                key: ValueKey(('save', _presses)),
                onPressed: _canSave ? _save : null,
                child: Text(appLocalizations.mountSave),
              ),
      ];
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + context.bottomInset),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 10,
        runSpacing: 8,
        children: buttons,
      ),
    );
  }

  String? _resultText(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (_result) {
      null => null,
      _Result.applying => appLocalizations.mountApplying,
      _Result.savedUnconfirmed => appLocalizations.mountSavedUnconfirmed,
      _Result.unchanged => appLocalizations.mountUnchanged,
      _Result.needsGroup when mountIsolatedGroups(_panel?.groups).isNotEmpty =>
        appLocalizations.mountNoGroupIsolatedTitle,
      _Result.needsGroup => appLocalizations.mountNoGroupTitle,
      _Result.applyFailed => appLocalizations.mountApplyFailed,
      _Result.applyKept => appLocalizations.mountApplyKept,
      _Result.applyBlocked when _blockSettled =>
        appLocalizations.mountApplyBlockedConfirmed,
      _Result.applyBlocked => appLocalizations.mountApplyBlocked,
      _Result.unknown =>
        _removal
            ? appLocalizations.mountUnmountUnknown
            : appLocalizations.mountUnknown,
    };
  }

  Widget? _buildBanner(BuildContext context, MountPanel panel) {
    final appLocalizations = context.appLocalizations;
    if (_resultText(context) case final text?) {
      final info =
          _result == _Result.applying || _result == _Result.savedUnconfirmed;
      return MountBanner(
        lines: [text],
        level: info ? MountBannerLevel.info : MountBannerLevel.error,
      );
    }
    final renamed = (_confirmedReport(panel)?.renamed ?? 0) > 0;
    final tailscale = _tailscaleExcluded(panel);
    final unsupported = _unsupportedExcluded(panel);
    final isolated = _groupCase == MountGroupCase.auto
        ? mountIsolatedGroups(panel.groups)
        : const <MountGroupInfo>[];
    final lost = [if (_lost.isNotEmpty) appLocalizations.mountSelectionLost];
    final details = [
      if (renamed) appLocalizations.mountSameName,
      if (tailscale > 0) appLocalizations.mountTailscaleExcluded,
      if (unsupported > 0)
        appLocalizations.mountUnsupportedExcluded(unsupported),
      if (isolated.isNotEmpty)
        ...mountIsolatedGroupsLines(isolated, appLocalizations),
    ];
    if (details.isEmpty) {
      return lost.isEmpty
          ? null
          : MountBanner(lines: lost, level: MountBannerLevel.info);
    }
    if (_noticesOpen) {
      return MountBanner(
        lines: [...lost, ...details],
        level: MountBannerLevel.info,
        actionLabel: appLocalizations.mountShowLess,
        onAction: () => setState(() => _noticesOpen = false),
      );
    }
    final nodes = tailscale + unsupported > 0;
    final groups = isolated.isNotEmpty;
    // One short line, compact-copy: the case itself when it is the only one.
    final summary = switch ((renamed, nodes, groups)) {
      (true, false, false) => appLocalizations.mountSameNameShort,
      (false, true, false) => appLocalizations.mountNodesExcludedShort(
        tailscale + unsupported,
      ),
      (false, false, true) => appLocalizations.mountGroupsExcludedShort(
        isolated.length,
      ),
      (true, _, _) => appLocalizations.mountNamesAndExclusions,
      _ => appLocalizations.mountSomeExcluded,
    };
    return MountBanner(
      lines: [...lost, summary],
      level: MountBannerLevel.info,
      actionLabel: appLocalizations.mountDetails,
      onAction: () => setState(() => _noticesOpen = true),
    );
  }

  /// A readback of another revision describes sources no longer mounted:
  /// counts then come from inspecting the mounted sources.
  MountReport? _confirmedReport(MountPanel panel) {
    final runtime = _runtime;
    final revision = panel.revision;
    return switch (runtime == null || revision == null
        ? null
        : confirmMounts(runtime, revision)) {
      MountSaveOutcome.applied ||
      MountSaveOutcome.appliedUnverified => runtime!.report,
      _ => null,
    };
  }

  int _tailscaleExcluded(MountPanel panel) {
    final reported = _confirmedReport(panel)?.sources;
    if (reported != null && reported.isNotEmpty) {
      return reported.fold(0, (sum, source) => sum + source.tailscaleExcluded);
    }
    return panel.sources.fold(
      0,
      (sum, item) => item.mounted ? sum + item.tailscaleExcluded : sum,
    );
  }

  int _unsupportedExcluded(MountPanel panel) {
    final reported = _confirmedReport(panel)?.sources;
    if (reported != null && reported.isNotEmpty) {
      return reported.fold(
        0,
        (sum, source) =>
            sum + source.relayExcluded + source.unsupportedExcluded,
      );
    }
    return panel.sources.fold(
      0,
      (sum, item) => item.mounted
          ? sum + item.relayExcluded + item.unsupportedExcluded
          : sum,
    );
  }

  Widget _buildSources(BuildContext context, MountPanel panel) {
    final appLocalizations = context.appLocalizations;
    final banner = _buildBanner(context, panel);
    final interactive = !_saving && !_locked;
    final settled = panel.stored?.pending == null;
    final confirmed = settled && _result != _Result.unknown;
    final run = switch (_result) {
      _Result.applyBlocked => MountRunState.blocked,
      null ||
      _Result.unchanged ||
      _Result.needsGroup when settled => MountRunState.confirmed,
      _ => MountRunState.unconfirmed,
    };
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        _SectionLabel(appLocalizations.mountChooseSources),
        for (final item in panel.sources)
          MountSourceRow(
            item: item,
            checked: _selected.contains(item.profile.id),
            mountedTag: item.mounted && confirmed,
            refreshing: _refreshing.contains(item.profile.id),
            refreshUnconfirmed: _refreshUnconfirmed.contains(item.profile.id),
            refusal: _refused[item.profile.id],
            run: run,
            blockSettled: _result == _Result.applyBlocked && _blockSettled,
            onChanged: interactive
                ? (value) => _toggleSource(item, value)
                : null,
            onRefresh: item.mounted && !_refreshing.contains(item.profile.id)
                ? () => _refresh(item.profile.id)
                : null,
            formatHelpOpen: _formatHelp.contains(item.profile.id),
            onFormatHelp: () =>
                setState(() => _formatHelp.add(item.profile.id)),
          ),
        _buildGroups(context, panel, interactive: interactive),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        ?banner,
        IgnorePointer(
          ignoring: !interactive,
          child: Opacity(opacity: interactive ? 1 : 0.5, child: controls),
        ),
      ],
    );
  }

  Widget _buildGroups(
    BuildContext context,
    MountPanel panel, {
    required bool interactive,
  }) {
    final appLocalizations = context.appLocalizations;
    switch (_groupCase) {
      case MountGroupCase.failed:
        return MountGroupsBlock(
          children: [
            Text(
              appLocalizations.mountGroupsFailed,
              style: AppTextStyle.footnote
                  .of(context, emphasized: true)
                  .copyWith(color: context.colorScheme.error),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TonalButton(
                size: TonalButtonSize.compact,
                label: appLocalizations.mountReadAgain,
                onPressed: interactive ? () => _load(resetChoice: false) : null,
              ),
            ),
          ],
        );
      case MountGroupCase.none:
        final isolated = mountIsolatedGroups(panel.groups);
        if (isolated.isNotEmpty) {
          return MountBanner(
            level: MountBannerLevel.warn,
            title: appLocalizations.mountNoGroupIsolatedTitle,
            lines: [
              appLocalizations.mountNoGroupIsolatedDesc,
              if (_groupDetailsOpen)
                ...mountIsolatedGroupsLines(isolated, appLocalizations),
            ],
            actionLabel: _groupDetailsOpen
                ? appLocalizations.mountShowLess
                : appLocalizations.mountDetails,
            onAction: () =>
                setState(() => _groupDetailsOpen = !_groupDetailsOpen),
          );
        }
        return MountBanner(
          level: MountBannerLevel.warn,
          title: appLocalizations.mountNoGroupTitle,
          lines: [appLocalizations.mountNoGroupDesc],
        );
      case MountGroupCase.auto:
        return MountGroupsSection(
          view: _groupsView(panel),
          expanded: _groupsOpen,
          showAll: _allGroups,
          onToggle: () => setState(() => _groupsOpen = !_groupsOpen),
          onShowAll: () => setState(() => _allGroups = true),
        );
    }
  }

  /// Rows are pending while the ticks are not what is mounted, and say
  /// what runs only once a readback confirms the stored relation.
  MountGroupsView _groupsView(MountPanel panel) {
    final runtime = _runtime;
    final revision = panel.revision;
    final confirmed =
        runtime != null &&
        revision != null &&
        panel.stored?.pending == null &&
        _result != _Result.unknown &&
        confirmMounts(runtime, revision) == MountSaveOutcome.applied;
    return mountGroupsViewOf(
      panel.groups!,
      pending: _dirty && _selected.isNotEmpty,
      mounted: _mounted.isNotEmpty,
      applied: confirmed ? runtime : null,
      runtime: runtime,
      appLocalizations: context.appLocalizations,
    );
  }
}

/// What a group row says about its empty-group handling, design §11.
class MountGroupStatus {
  const MountGroupStatus({this.blockTag = false, this.line, this.warn = false});

  final bool blockTag;
  final String? line;
  final bool warn;
}

MountGroupStatus? mountGroupStatusOf(
  MountGroupInfo group, {
  required List<MountGroupReport>? report,
  required List<MountRuntimeGroup>? runtime,
  required AppLocalizations appLocalizations,
}) {
  MountGroupReport? reported;
  for (final item in report ?? const <MountGroupReport>[]) {
    if (item.name == group.name) {
      reported = item;
    }
  }
  MountRuntimeGroup? running;
  for (final item in runtime ?? const <MountRuntimeGroup>[]) {
    if (item.name == group.name) {
      running = item;
    }
  }
  final empty = reported != null && (running?.empty ?? false);
  if (reported?.protection == MountProtection.reject) {
    return MountGroupStatus(
      blockTag: true,
      line: empty
          ? appLocalizations.mountGroupEmpty(group.name)
          : appLocalizations.mountBlockDesc,
      warn: empty,
    );
  }
  final fallback = reported?.protection == MountProtection.base
      ? reported!.emptyFallback
      : group.emptyFallback ?? '';
  if (fallback.isNotEmpty) {
    return MountGroupStatus(
      line: [
        appLocalizations.mountBaseFallback(fallback),
        if (fallback == 'DIRECT') appLocalizations.mountBaseDirect,
      ].join(' '),
    );
  }
  if (!empty) {
    return null;
  }
  // Wholly empty, filtered or not: its own nodes are gone too, copy §4.
  return MountGroupStatus(
    line: appLocalizations.mountGroupEmpty(group.name),
    warn: true,
  );
}

/// The full lines on excluded groups, with the reported reason for each.
List<String> mountIsolatedGroupsLines(
  List<MountGroupInfo> groups,
  AppLocalizations appLocalizations,
) => [
  appLocalizations.mountIsolationFirst,
  appLocalizations.mountGroupsExcluded(groups.length),
  for (final group in groups) ...[
    appLocalizations.mountGroupsExcludedNames(group.name),
    _mountGroupReasonLabel(group.reason, appLocalizations),
  ],
];

String _mountGroupReasonLabel(
  MountGroupReason? reason,
  AppLocalizations appLocalizations,
) => switch (reason) {
  MountGroupReason.ruleUnknown => appLocalizations.mountGroupReasonRuleUnknown,
  MountGroupReason.providerUnknown =>
    appLocalizations.mountGroupReasonProviderUnknown,
  MountGroupReason.dns => appLocalizations.mountGroupReasonDns,
  MountGroupReason.dialer => appLocalizations.mountGroupReasonDialer,
  MountGroupReason.member => appLocalizations.mountGroupReasonMember,
  MountGroupReason.holds ||
  MountGroupReason.rule ||
  MountGroupReason.carrier ||
  MountGroupReason.global => appLocalizations.mountIsolationFirst,
  null => appLocalizations.serviceUnavailable,
};

enum MountBannerLevel { info, warn, error }

/// A banner in the sheet's single banner slot; [lines] stack in order.
class MountBanner extends StatelessWidget {
  const MountBanner({
    super.key,
    required this.level,
    required this.lines,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final MountBannerLevel level;
  final List<String> lines;
  final String? title;

  /// A text button after the lines, as 详情 on a collapsed banner.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (fill, foreground, glyph) = switch (level) {
      MountBannerLevel.info => (
        context.raisedSurfaceLevel.colorOf(colorScheme),
        colorScheme.onSurface,
        AppGlyphs.info,
      ),
      MountBannerLevel.warn => (
        colorScheme.warningContainer,
        colorScheme.onWarningContainer,
        AppGlyphs.warning,
      ),
      MountBannerLevel.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        AppGlyphs.error,
      ),
    };
    final style = AppTextStyle.footnote.of(context).copyWith(color: foreground);
    final title = this.title;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: AppShape.all(AppCorner.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: GlyphIcon(glyph, size: 16, color: foreground),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    if (title != null)
                      Text(
                        title,
                        style: AppTextStyle.footnote
                            .of(context, emphasized: true)
                            .copyWith(color: foreground),
                      ),
                    for (final line in lines) Text(line, style: style),
                  ],
                ),
              ),
              if (actionLabel case final label?)
                MountTextAction(label: label, onPressed: onAction),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: AppTextStyle.caption1
            .of(context, emphasized: true)
            .copyWith(color: context.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  @override
  Widget build(BuildContext context) {
    final fill = context.raisedSurfaceLevel.colorOf(context.colorScheme);
    return Column(
      spacing: 12,
      children: [
        for (var i = 0; i < 3; i++)
          SizedBox(
            height: 60,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: AppShape.all(AppCorner.md),
              ),
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        spacing: 12,
        children: [
          Text(
            appLocalizations.mountListFailed,
            textAlign: TextAlign.center,
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: context.colorScheme.error),
          ),
          TonalButton(
            glyph: AppGlyphs.sync,
            label: appLocalizations.mountReadAgain,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _EmptySources extends StatelessWidget {
  const _EmptySources({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        spacing: 12,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: ShapeDecoration(
              color: context.raisedSurfaceLevel.colorOf(colorScheme),
              shape: AppShape.all(AppCorner.xxl),
            ),
            alignment: Alignment.center,
            child: GlyphIcon(
              AppGlyphs.layers,
              size: 44,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            appLocalizations.mountEmptyTitle,
            textAlign: TextAlign.center,
            style: AppTextStyle.headline.of(context),
          ),
          Text(
            appLocalizations.mountEmptyDesc,
            textAlign: TextAlign.center,
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          TonalButton(
            glyph: AppGlyphs.addCircle,
            label: appLocalizations.mountImport,
            onPressed: onImport,
          ),
          Text(
            appLocalizations.mountImportHint,
            textAlign: TextAlign.center,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          Text(
            appLocalizations.mountFormatHelp,
            textAlign: TextAlign.center,
            style: AppTextStyle.caption2
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The body of an unmount or a mixed change: the names, at most five in
/// view before the list scrolls.
class _ChangeBody extends StatelessWidget {
  const _ChangeBody({
    required this.body,
    required this.removed,
    required this.alsoMounts,
    required this.added,
  });

  final String body;
  final List<String> removed;
  final String? alsoMounts;
  final List<String> added;

  @override
  Widget build(BuildContext context) {
    final alsoMounts = this.alsoMounts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(body),
        if (removed.isNotEmpty) MountNameList(names: removed),
        if (alsoMounts != null) ...[
          Text(alsoMounts),
          MountNameList(names: added),
        ],
      ],
    );
  }
}

/// Real names one per line in a block, five in view at most.
class MountNameList extends StatelessWidget {
  const MountNameList({super.key, required this.names});

  final List<String> names;

  static const _visible = 5;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.subheadline
        .of(context)
        .copyWith(color: context.colorScheme.onSurface, height: 1.7);
    final lineHeight = (style.fontSize ?? 15) * 1.7;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(context.colorScheme),
        shape: AppShape.all(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: lineHeight * _visible + 1),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final name in names) Text(name, style: style)],
            ),
          ),
        ),
      ),
    );
  }
}

class MountGroupsBlock extends StatelessWidget {
  const MountGroupsBlock({
    super.key,
    this.title,
    this.corner = AppCorner.md,
    required this.children,
  });

  final String? title;
  final double corner;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(context.colorScheme),
        shape: AppShape.all(corner),
      ),
      child: SurfaceScope(
        level: context.raisedSurfaceLevel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              if (title != null)
                Text(
                  title,
                  style: AppTextStyle.subheadline.of(context, emphasized: true),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A small inset tag after a name: a group type or 空组时拦截.
class MountTag extends StatelessWidget {
  const MountTag({super.key, required this.label, this.primary = false});

  final String label;
  final bool primary;

  static const _padding = 7.0;

  static double widthOf(BuildContext context, String label) =>
      EmojiText.widthOf(
        context,
        label,
        AppTextStyle.caption2.of(context, emphasized: true),
      ).ceilToDouble() +
      _padding * 2;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: _padding),
      decoration: ShapeDecoration(
        color: primary
            ? colorScheme.primary.opacity15
            : context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: AppShape.full,
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: AppTextStyle.caption2
              .of(context, emphasized: true)
              .copyWith(
                color: primary
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

/// The 20 dp box of the mount sheet, design §3: an empty box one can
/// check is outlined, one that cannot be checked is a faint fill.
class MountCheckbox extends StatelessWidget {
  const MountCheckbox({super.key, required this.value, this.enabled = true});

  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final outlined = !value && enabled;
    return AnimatedContainer(
      duration: context.motionDuration(commonDuration),
      width: 20,
      height: 20,
      decoration: ShapeDecoration(
        color: value
            ? colorScheme.primary
            : outlined
            ? colorScheme.primary.opacity0
            : SurfaceLevel.inset.colorOf(colorScheme),
        shape: AppShape.all(6).copyWith(
          side: BorderSide(
            color: outlined
                ? colorScheme.onSurfaceVariant
                : colorScheme.onSurfaceVariant.opacity0,
            width: 1.5,
          ),
        ),
      ),
      child: value
          ? GlyphIcon(AppGlyphs.check, size: 16, color: colorScheme.onPrimary)
          : null,
    );
  }
}

class MountSourceRow extends StatelessWidget {
  const MountSourceRow({
    super.key,
    required this.item,
    required this.checked,
    required this.mountedTag,
    required this.refreshing,
    required this.refreshUnconfirmed,
    required this.onChanged,
    required this.onRefresh,
    this.refusal,
    this.run = MountRunState.confirmed,
    this.blockSettled = false,
    this.formatHelpOpen = false,
    this.onFormatHelp,
  });

  /// A row whose format is not supported offers 详情 for the format help,
  /// design §13.4.
  final bool formatHelpOpen;
  final VoidCallback? onFormatHelp;

  final MountSourceItem item;
  final bool checked;
  final bool mountedTag;
  final bool refreshing;
  final bool refreshUnconfirmed;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onRefresh;
  final MountRefreshRefusal? refusal;
  final MountRunState run;
  final bool blockSettled;

  bool get _faded => !item.state.mountable && !item.mounted;

  bool get _checkable => !_faded || checked;

  bool get _formatError => item.state == MountSourceState.unsupported;

  String _detail(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    if (refreshing) {
      return appLocalizations.mountUpdatingNodes;
    }
    final updated = item.profile.lastUpdateDate;
    // Every node of an isolated source is one of the excluded kinds.
    final count = switch (item.state) {
      MountSourceState.nodes => item.count,
      MountSourceState.empty => 0,
      MountSourceState.tailscaleOnly ||
      MountSourceState.relayOnly ||
      MountSourceState.isolatedOnly =>
        item.tailscaleExcluded + item.relayExcluded + item.unsupportedExcluded,
      _ => null,
    };
    if (count == null || updated == null) {
      return appLocalizations.mountNotFetched;
    }
    if (refusal != null) {
      return [
        appLocalizations.mountNodesRead(count),
        appLocalizations.mountNodesReadAt(
          updated.getLastUpdateTimeDesc(context),
        ),
      ].join(' · ');
    }
    return [
      appLocalizations.mountNodeCount(count),
      appLocalizations.mountLastUpdated(updated.getLastUpdateTimeDesc(context)),
    ].join(' · ');
  }

  /// Each line with whether it reads as an error rather than a warning.
  List<(String, bool)> _states(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final refusal = this.refusal;
    if (refusal == null) {
      return [?_state(context)];
    }
    final blocked = refusal == MountRefreshRefusal.blocked;
    return switch (item.state) {
      MountSourceState.nodes => [
        (
          switch ((blocked, blockSettled)) {
            (true, true) =>
              appLocalizations.mountUpdateReadNotAppliedBlockedConfirmed,
            (true, false) => appLocalizations.mountUpdateReadNotAppliedBlocked,
            _ => appLocalizations.mountUpdateReadNotAppliedKept,
          },
          blocked,
        ),
      ],
      MountSourceState.empty => [
        (appLocalizations.mountUpdateReadEmptyNotApplied, false),
        _running(appLocalizations, blocked),
      ],
      _ => [?_state(context), _running(appLocalizations, blocked)],
    };
  }

  (String, bool) _running(AppLocalizations appLocalizations, bool blocked) => (
    switch ((blocked, blockSettled)) {
      (true, true) => appLocalizations.mountRunningBlockedConfirmed,
      (true, false) => appLocalizations.mountRunningBlocked,
      _ => appLocalizations.mountRunningKept,
    },
    blocked,
  );

  (String, bool)? _state(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final failed = item.record?.failure != null;
    return switch (item.state) {
      MountSourceState.unsupported => (
        appLocalizations.mountSourceNoNodeList,
        true,
      ),
      MountSourceState.unreadable => (appLocalizations.mountFetchFailed, true),
      MountSourceState.notFetched when failed => (
        appLocalizations.mountFetchFailed,
        true,
      ),
      MountSourceState.notFetched => null,
      MountSourceState.relayOnly => (
        appLocalizations.mountSourceRelayOnly,
        true,
      ),
      MountSourceState.isolatedOnly => (
        appLocalizations.mountSourceIsolatedOnly,
        true,
      ),
      MountSourceState.tailscaleOnly => (
        appLocalizations.mountSourceTailscaleOnly,
        true,
      ),
      _ when run == MountRunState.blocked && failed => (
        appLocalizations.mountUpdateFailedKeptBlocked,
        true,
      ),
      _ when failed || refreshUnconfirmed => (
        run == MountRunState.confirmed && !refreshUnconfirmed
            ? appLocalizations.mountUpdateFailedInUse
            : appLocalizations.mountUpdateFailedKept,
        false,
      ),
      MountSourceState.empty => (appLocalizations.mountSourceEmpty, false),
      MountSourceState.nodes => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final name = item.profile.realLabel;
    final detail = _detail(context);
    final states = _states(context);
    final onChanged = this.onChanged;
    final enabled = onChanged != null && _checkable;
    final semantics = [
      name,
      detail,
      for (final state in states) state.$1,
      mountedTag
          ? appLocalizations.mountMountedTag
          : appLocalizations.mountNotMounted,
    ].join(', ');
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Row(
          spacing: 6,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.subheadline.of(context, emphasized: true),
              ),
            ),
            if (mountedTag)
              MountTag(label: appLocalizations.mountMountedTag, primary: true),
          ],
        ),
        Text(
          detail,
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
        for (final (line, error) in states)
          Text(
            line,
            style: AppTextStyle.caption2
                .of(context, emphasized: true)
                .copyWith(
                  color: error ? colorScheme.error : colorScheme.warning,
                ),
          ),
        if (_formatError && formatHelpOpen)
          Text(
            appLocalizations.mountFormatHelp,
            style: AppTextStyle.caption2
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
      ],
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: AppShape.all(AppCorner.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                checked: checked,
                enabled: enabled,
                label: semantics,
                onTap: enabled ? () => onChanged(!checked) : null,
                excludeSemantics: true,
                child: PressRegion(
                  onTap: enabled ? () => onChanged(!checked) : null,
                  shape: AppShape.all(AppCorner.md),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(
                      spacing: 12,
                      children: [
                        Opacity(
                          opacity: _faded ? 0.4 : 1,
                          child: MountCheckbox(
                            value: checked,
                            enabled: _checkable,
                          ),
                        ),
                        Expanded(child: text),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_formatError && !formatHelpOpen)
              Padding(
                padding: EdgeInsets.only(right: item.mounted ? 4 : 10),
                child: MountTextAction(
                  label: appLocalizations.mountDetails,
                  onPressed: onFormatHelp,
                ),
              ),
            if (item.mounted)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox.square(
                  dimension: 32,
                  child: refreshing
                      ? const Center(child: ActivityIndicator(size: 14))
                      : IconButton(
                          onPressed: onRefresh,
                          tooltip: appLocalizations.mountUpdateNodes,
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          icon: Semantics(
                            label: appLocalizations.mountUpdateNodesOf(name),
                            child: const GlyphIcon(AppGlyphs.sync),
                          ),
                        ),
                ),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

/// The type tag of a group, design §11; a type it does not know shows as
/// written.
String mountGroupTypeTag(
  MountGroupInfo group,
  AppLocalizations appLocalizations,
) {
  final type = group.type.toLowerCase().replaceAll('-', '');
  return switch (type) {
    'select' || 'selector' => appLocalizations.mountTypeSelect,
    'urltest' => appLocalizations.mountTypeUrlTest,
    'fallback' => appLocalizations.mountTypeFallback,
    'loadbalance' => appLocalizations.mountTypeLoadBalance,
    _ => group.type,
  };
}

const _pillHeight = 28.0;
const _pillPadding = 12.0;
const _pillGlyph = 14.0;
const _pillGap = 6.0;
const _pillDot = 7.0;

/// The space a pill below the subtitle takes, design §1.1 narrow.
const mountPillBelowExtent = 8.0 + _pillHeight;

String _pillLabel(
  AppLocalizations appLocalizations,
  MountCardSummary? summary,
) {
  final mounted = summary?.mounted ?? 0;
  return mounted > 0
      ? appLocalizations.mountedCount(mounted)
      : appLocalizations.mountEntry;
}

/// The widest a pill gets, to tell whether it leaves the title its room.
double mountPillMaxWidth(BuildContext context) {
  final appLocalizations = context.appLocalizations;
  final style = AppTextStyle.caption1.of(context, emphasized: true);
  var widest = 0.0;
  for (final label in [
    appLocalizations.mountEntry,
    appLocalizations.mountedCount(99),
  ]) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    if (painter.width > widest) {
      widest = painter.width;
    }
    painter.dispose();
  }
  return _pillPadding * 2 + _pillGlyph + _pillGap * 2 + widest + _pillDot;
}

/// The mount entry on a profile card, design §1.1. [summary] is null with
/// [failed] for a status that could not be read: no count, a warn dot.
class MountPill extends StatelessWidget {
  const MountPill({
    super.key,
    required this.profile,
    required this.summary,
    this.unreadable = false,
  });

  final Profile profile;
  final MountCardSummary? summary;
  final bool unreadable;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final label = _pillLabel(appLocalizations, unreadable ? null : summary);
    final warn = unreadable || (summary?.failed ?? 0) > 0;
    final semantics = [
      appLocalizations.mountPillSemantics(label, profile.realLabel),
      if (warn) appLocalizations.mountPillFailedSemantics,
    ].join(', ');
    return Tooltip(
      message: appLocalizations.mountEntry,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        onTap: () => showMountSheet(context, profile),
        child: PressRegion(
          onTap: () => showMountSheet(context, profile),
          shape: AppShape.full,
          fill: context.raisedSurfaceLevel.colorOf(colorScheme),
          child: SizedBox(
            height: _pillHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pillPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: _pillGap,
                children: [
                  GlyphIcon(
                    mountGlyph,
                    size: _pillGlyph,
                    color: colorScheme.onSurface,
                  ),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.caption1
                          .of(context, emphasized: true)
                          .copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                  if (warn)
                    Container(
                      width: _pillDot,
                      height: _pillDot,
                      decoration: BoxDecoration(
                        color: colorScheme.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain text button in the primary color, as 详情 and 显示全部.
class MountTextAction extends StatelessWidget {
  const MountTextAction({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: PressRegion(
        onTap: onPressed,
        shape: AppShape.all(AppCorner.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Text(
            label,
            style: AppTextStyle.footnote
                .of(context, emphasized: true)
                .copyWith(color: context.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
