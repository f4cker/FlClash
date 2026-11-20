import 'dart:async';

import 'package:fl_clash/common/restore_journal.dart';
import 'package:fl_clash/common/restore_mount_plan.dart';
import 'package:fl_clash/common/restore_result.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Below this width everything scrolls as one page, with the actions in
/// the flow rather than pinned.
const restoreNarrowWidth = 600.0;

/// Below this height the same, so the details are never squeezed away.
const restoreShortHeight = 520.0;

const _desktopWidth = 820.0;
const _gutter = 28.0;

/// The design's light palette. Dark appearance uses the system's dynamic
/// colors instead; it has not been visually accepted.
class _Palette {
  final Color text;
  final Color secondary;
  final Color surface;
  final Color grey;
  final Color separator;
  final Color danger;
  final Color warning;
  final Color warningFill;
  final Color warningBorder;
  final Color info;
  final Color infoFill;
  final Color infoBorder;
  final Color accent;

  const _Palette({
    required this.text,
    required this.secondary,
    required this.surface,
    required this.grey,
    required this.separator,
    required this.danger,
    required this.warning,
    required this.warningFill,
    required this.warningBorder,
    required this.info,
    required this.infoFill,
    required this.infoBorder,
    required this.accent,
  });

  static const light = _Palette(
    text: Color(0xFF1D1D1F),
    secondary: Color(0xFF606066),
    surface: Color(0xFFFFFFFF),
    grey: Color(0xFFF5F5F7),
    separator: Color(0xFFD9D9DE),
    danger: Color(0xFFB42318),
    warning: Color(0xFF805500),
    warningFill: Color(0xFFFFF7E6),
    warningBorder: Color(0xFFF0D9A8),
    info: Color(0xFF1D3F6E),
    infoFill: Color(0xFFEEF5FF),
    infoBorder: Color(0xFFCFE0F7),
    accent: Color(0xFF007AFF),
  );

  static _Palette of(BuildContext context) {
    final scheme = context.colorScheme;
    if (scheme.brightness == Brightness.light) return light;
    return _Palette(
      text: scheme.onSurface,
      secondary: scheme.onSurfaceVariant,
      surface: scheme.surface,
      grey: scheme.surfaceContainerHigh,
      separator: scheme.outlineVariant,
      danger: scheme.error,
      warning: const Color(0xFFFFD27A),
      warningFill: const Color(0x33FFB020),
      warningBorder: const Color(0x66FFB020),
      info: const Color(0xFFB5D3FF),
      infoFill: const Color(0x33007AFF),
      infoBorder: const Color(0x66007AFF),
      accent: scheme.primary,
    );
  }
}

// The design's sizes sit off the Dynamic Type scale; AppTextStyle.custom
// builds them on the theme's font and its CJK fallback.
TextStyle _body(BuildContext context, _Palette p) =>
    AppTextStyle.custom(context, size: 14, leading: 21).copyWith(color: p.text);

TextStyle _aux(BuildContext context, _Palette p) => AppTextStyle.custom(
  context,
  size: 12,
  leading: 18,
).copyWith(color: p.secondary);

TextStyle _title(BuildContext context, _Palette p) => AppTextStyle.custom(
  context,
  size: 22,
  leading: 28.6,
  weight: FontWeight.w600,
).copyWith(color: p.text);

TextStyle _group(BuildContext context, _Palette p) =>
    _body(context, p).merge(AppTextStyle.emphasis);

/// A profile's full name, with its id when the name may not be unique, and
/// never a guessed name.
String restoreProfileName(
  RestoreMountProfile profile,
  AppLocalizations l10n, {
  bool withId = false,
}) {
  final label = profile.label;
  if (label == null || label.isEmpty) {
    return l10n.restoreMountNameUnavailable('${profile.id}');
  }
  return withId ? l10n.restoreMountWithId(label, '${profile.id}') : label;
}

String restoreMountReasonText(
  RestoreMountReason reason,
  AppLocalizations l10n,
) => switch (reason) {
  RestoreMountReason.self => l10n.restoreMountReasonSelf,
  RestoreMountReason.sourceNotSubscription =>
    l10n.restoreMountReasonNotSubscription,
  RestoreMountReason.sourceMissing => l10n.restoreMountReasonMissing,
  RestoreMountReason.targetMissing => l10n.restoreMountReasonTargetMissing,
  RestoreMountReason.notInBackup => l10n.restoreMountReasonNotInBackup,
};

/// One group of the confirmation list, with its true total.
enum RestoreMountGroup { remove, replace, keep, check, invalid }

/// A row as the list shows it; the confirmation sheet and its tests read
/// the same data.
class RestoreMountRow {
  final RestoreMountGroup group;
  final RestoreMountProfile owner;
  final String source;
  final String? note;

  /// The stable reason id, for rows that have one.
  final String? reasonId;
  final String tag;

  const RestoreMountRow({
    required this.group,
    required this.owner,
    required this.source,
    required this.tag,
    this.note,
    this.reasonId,
  });
}

/// Groups the plan for the list: remove, replace, keep, then to check, and
/// last the backup relations that are not written.
Map<RestoreMountGroup, List<RestoreMountRow>> restoreMountRows(
  RestoreMountPlan plan,
  AppLocalizations l10n,
) {
  // Names that appear twice in a group get their ids, so two rows never
  // look the same.
  bool dup(Iterable<RestoreMountProfile> all, RestoreMountProfile p) =>
      all.where((o) => o.label == p.label && o.id != p.id).isNotEmpty;
  final allProfiles = <RestoreMountProfile>[
    for (final r in plan.removals) ...[r.relation.target, r.relation.source],
    for (final r in plan.replacements) ...[r.target, ...r.before, ...r.after],
    for (final k in plan.kept) ...[k.relation.target, k.relation.source],
    ...plan.pendingCheck,
    for (final r in plan.invalid) ...[r.relation.target, r.relation.source],
  ];
  String name(RestoreMountProfile p, {bool withId = false}) =>
      restoreProfileName(p, l10n, withId: withId || dup(allProfiles, p));
  String names(List<RestoreMountProfile> list) => list.isEmpty
      ? l10n.restoreMountNone
      : list.map((p) => name(p)).join(l10n.mountNameSeparator);
  RestoreMountRow removal(RestoreMountRemoval r, RestoreMountGroup group) =>
      RestoreMountRow(
        group: group,
        owner: r.relation.target,
        source: name(
          r.relation.source,
          withId: r.reason == RestoreMountReason.sourceMissing,
        ),
        note: restoreMountReasonText(r.reason, l10n),
        reasonId: r.reason.id,
        tag: group == RestoreMountGroup.invalid
            ? l10n.restoreMountTagInvalid
            : l10n.restoreMountTagRemove,
      );
  return {
    RestoreMountGroup.remove: [
      for (final r in plan.removals) removal(r, RestoreMountGroup.remove),
    ],
    RestoreMountGroup.replace: [
      for (final r in plan.replacements)
        RestoreMountRow(
          group: RestoreMountGroup.replace,
          owner: r.target,
          source: l10n.restoreMountAfter(names(r.after)),
          note: l10n.restoreMountBefore(names(r.before)),
          tag: l10n.restoreMountTagReplace,
        ),
    ],
    RestoreMountGroup.keep: [
      for (final k in plan.kept)
        RestoreMountRow(
          group: RestoreMountGroup.keep,
          owner: k.relation.target,
          source: name(k.relation.source),
          tag: k.origin == RestoreMountOrigin.backup
              ? l10n.restoreMountTagRestore
              : l10n.restoreMountTagKeep,
        ),
    ],
    RestoreMountGroup.check: [
      for (final p in plan.pendingCheck)
        RestoreMountRow(
          group: RestoreMountGroup.check,
          owner: p,
          source: '',
          note: l10n.restoreMountCheckNote,
          tag: l10n.restoreMountTagCheck,
        ),
    ],
    RestoreMountGroup.invalid: [
      for (final r in plan.invalid) removal(r, RestoreMountGroup.invalid),
    ],
  };
}

/// Lays out a sheet: on a wide, tall window the details scroll on their
/// own between a pinned header and footer; otherwise the whole page
/// scrolls and the footer sits in the flow.
class _SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> header;
  final List<Widget> Function(bool paged) slivers;
  final Widget footer;

  const _SheetFrame({
    required this.title,
    required this.header,
    required this.slivers,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    // Sized by the window, not a LayoutBuilder: stateful parts of a sheet
    // (the recheck button) must rebuild in the normal build scope.
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final paged =
        width <= restoreNarrowWidth ||
        height < restoreShortHeight ||
        media.textScaler.scale(14) >= 24;
    final gutter = width <= restoreNarrowWidth ? 20.0 : _gutter;
    final head = SliverPadding(
      padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 0),
      sliver: SliverList.list(children: header),
    );
    final body = [
      for (final sliver in slivers(paged))
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: sliver,
        ),
    ];
    final foot = DecoratedBox(
      decoration: BoxDecoration(
        color: p.grey,
        border: Border(top: BorderSide(color: p.separator)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 20),
        child: footer,
      ),
    );
    final Widget content;
    if (paged) {
      content = CustomScrollView(
        slivers: [
          head,
          ...body,
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: foot),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: CustomScrollView(
              shrinkWrap: true,
              slivers: [
                head,
                ...body,
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
          foot,
        ],
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopWidth, maxHeight: height),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(
              width <= restoreNarrowWidth ? 12 : 14,
            ),
            child: ColoredBox(
              color: p.surface,
              // Built on the theme's body style: a sheet may sit above
              // any DefaultTextStyle, and the user's font and its CJK
              // fallback must carry through.
              child: DefaultTextStyle(style: _body(context, p), child: content),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Glyph icon;
  final Color iconColor;
  final String title;
  final List<String> lines;
  final FocusNode? titleFocus;

  const _Header({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.lines,
    this.titleFocus,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final narrow = MediaQuery.sizeOf(context).width <= restoreNarrowWidth;
    // Focus lands on the title, never on an action Enter could trigger.
    final heading = Focus(
      focusNode: titleFocus,
      autofocus: true,
      child: Semantics(
        header: true,
        child: Text(title, style: _title(context, p)),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              line,
              style: _body(context, p).copyWith(color: p.secondary),
            ),
          ),
      ],
    );
    if (narrow) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              color: p.infoFill,
              shape: AppShape.all(9),
            ),
            child: Center(child: GlyphIcon(icon, size: 22, color: iconColor)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: text),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  final String lead;
  final String? note;
  final bool warning;

  const _Callout({required this.lead, this.note, this.warning = true});

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final color = warning ? p.warning : p.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ShapeDecoration(
        color: warning ? p.warningFill : p.infoFill,
        shape: AppShape.all(9).copyWith(
          side: BorderSide(color: warning ? p.warningBorder : p.infoBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lead, style: _group(context, p).copyWith(color: color)),
          if (note case final note?)
            Text(note, style: _body(context, p).copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool loss;

  const _Chip(this.label, {this.loss = false});

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: loss ? p.warningFill : p.grey,
        shape: AppShape.all(6),
      ),
      child: Text(
        label,
        style: _aux(context, p).copyWith(color: loss ? p.warning : p.text),
      ),
    );
  }
}

/// A group heading with its real total, then its rows, built lazily so a
/// list of a thousand stays cheap; every row is still reachable by
/// scrolling, and so by VoiceOver.
List<Widget> _groupSlivers(
  BuildContext context,
  String heading,
  List<RestoreMountRow> rows,
) {
  if (rows.isEmpty) return const [];
  final p = _Palette.of(context);
  final l10n = AppLocalizations.of(context);
  final narrow = MediaQuery.sizeOf(context).width <= restoreNarrowWidth;
  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Semantics(
          header: true,
          child: Text(heading, style: _group(context, p)),
        ),
      ),
    ),
    DecoratedSliver(
      decoration: ShapeDecoration(
        shape: AppShape.all(9).copyWith(side: BorderSide(color: p.separator)),
      ),
      sliver: SliverPrismList(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final danger =
              row.group == RestoreMountGroup.remove ||
              row.group == RestoreMountGroup.check;
          final tag = Text(
            row.tag,
            style: _aux(
              context,
              p,
            ).copyWith(color: danger ? p.danger : p.accent),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.restoreMountOwner(restoreProfileName(row.owner, l10n)),
                style: _group(context, p),
              ),
              if (row.source.isNotEmpty)
                Text(
                  row.group == RestoreMountGroup.replace
                      ? row.source
                      : l10n.restoreMountSource(row.source),
                ),
              if (row.note case final note?)
                Text(note, style: _aux(context, p)),
            ],
          );
          // Rows after the first carry the separator above them.
          return DecoratedBox(
            decoration: BoxDecoration(
              border: index == 0
                  ? null
                  : Border(top: BorderSide(color: p.separator)),
            ),
            child: MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                // Narrow: the tag goes under the text, which keeps the width.
                child: narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [details, const SizedBox(height: 6), tag],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 12),
                          tag,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    ),
  ];
}

/// Asks before a restore changes mounts. Pops true only once the user
/// confirmed; any other way out writes nothing.
class RestoreMountConfirmSheet extends StatefulWidget {
  final RestoreMountPlan plan;

  /// The backup's name, as the user picked it, when known.
  final String? backupName;

  const RestoreMountConfirmSheet({
    super.key,
    required this.plan,
    this.backupName,
  });

  @override
  State<RestoreMountConfirmSheet> createState() =>
      _RestoreMountConfirmSheetState();
}

class _RestoreMountConfirmSheetState extends State<RestoreMountConfirmSheet> {
  bool _acknowledged = false;
  bool _submitted = false;

  void _cancel() => Navigator.of(context).pop(false);

  void _confirm() {
    if (_submitted) return;
    _submitted = true;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final l10n = AppLocalizations.of(context);
    final p = _Palette.of(context);
    final rows = restoreMountRows(plan, l10n);
    final title = plan.isOverride
        ? l10n.restoreMountTitleOverride
        : l10n.restoreMountTitleMerge;
    final (lead, note) = !plan.mountsCarried
        ? (l10n.restoreMountLegacyLead, l10n.restoreMountLegacyNote)
        : plan.isOverride
        ? (l10n.restoreMountOverrideLead, l10n.restoreMountOverrideNote)
        : (l10n.restoreMountMergeLead, l10n.restoreMountMergeNote);
    final losses = plan.hasLosses;
    final enabled = !_submitted && (!losses || _acknowledged);
    final counts = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          l10n.restoreMountRemoveCount('${plan.removalCount}'),
          loss: plan.removalCount > 0,
        ),
        _Chip(
          l10n.restoreMountReplaceCount('${plan.replacementCount}'),
          loss: plan.replacementCount > 0,
        ),
        _Chip(l10n.restoreMountKeepCount('${plan.kept.length}')),
        _Chip(l10n.restoreMountCheckCount('${plan.pendingCheck.length}')),
        if (plan.invalid.isNotEmpty)
          _Chip(l10n.restoreMountInvalidCount('${plan.invalid.length}')),
      ],
    );
    final checkbox = losses
        ? MergeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _submitted
                  ? null
                  : () => setState(() => _acknowledged = !_acknowledged),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The box keeps its 48 dp target centred on the
                  // 18 × 22 slot; it must not be shifted out of the row,
                  // or taps on it miss.
                  SizedBox(
                    width: 18,
                    height: 22,
                    child: OverflowBox(
                      maxWidth: 48,
                      maxHeight: 48,
                      child: Checkbox(
                        value: _acknowledged,
                        onChanged: _submitted
                            ? null
                            : (value) => setState(
                                () => _acknowledged = value ?? false,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.restoreMountAcknowledge(
                        '${plan.removalCount}',
                        '${plan.replacementCount}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : null;
    final narrow = MediaQuery.sizeOf(context).width <= restoreNarrowWidth;
    final cancel = TextButton(onPressed: _cancel, child: Text(l10n.cancel));
    final confirm = FilledButton(
      onPressed: enabled ? _confirm : null,
      child: Text(
        plan.isOverride
            ? l10n.restoreMountConfirmOverride
            : l10n.restoreMountConfirmMerge,
      ),
    );
    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (checkbox != null) ...[checkbox, const SizedBox(height: 12)],
        if (narrow) ...[
          Text(l10n.restoreCancelWritesNothing, style: _aux(context, p)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SizedBox(height: 44, child: cancel)),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(height: 44, child: confirm)),
            ],
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.restoreCancelWritesNothing,
                  style: _aux(context, p),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: cancel,
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: confirm,
              ),
            ],
          ),
      ],
    );
    // Enter never triggers the destructive action; Escape cancels while
    // nothing has been written.
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter):
            DoNothingAndStopPropagationIntent(),
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
        child: FocusScope(
          autofocus: true,
          child: _SheetFrame(
            title: title,
            header: [
              _Header(
                icon: AppGlyphs.undo,
                iconColor: p.accent,
                title: title,
                lines: [?widget.backupName, l10n.restoreIrreversible],
              ),
              const SizedBox(height: 20),
              _Callout(lead: lead, note: note, warning: plan.mountsCarried),
              const SizedBox(height: 16),
              counts,
              if (plan.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(l10n.restoreMountNoChanges),
                ),
            ],
            slivers: (_) => [
              ..._groupSlivers(
                context,
                l10n.restoreMountRemoveSection(
                  '${rows[RestoreMountGroup.remove]!.length}',
                ),
                rows[RestoreMountGroup.remove]!,
              ),
              ..._groupSlivers(
                context,
                l10n.restoreMountReplaceSection(
                  '${rows[RestoreMountGroup.replace]!.length}',
                ),
                rows[RestoreMountGroup.replace]!,
              ),
              ..._groupSlivers(
                context,
                l10n.restoreMountKeepSection(
                  '${rows[RestoreMountGroup.keep]!.length}',
                ),
                rows[RestoreMountGroup.keep]!,
              ),
              ..._groupSlivers(
                context,
                l10n.restoreMountCheckSection(
                  '${rows[RestoreMountGroup.check]!.length}',
                ),
                rows[RestoreMountGroup.check]!,
              ),
              ..._groupSlivers(
                context,
                l10n.restoreMountInvalidSection(
                  '${rows[RestoreMountGroup.invalid]!.length}',
                ),
                rows[RestoreMountGroup.invalid]!,
              ),
            ],
            footer: footer,
          ),
        ),
      ),
    );
  }
}

/// The states of an explicit check; it never runs by itself.
enum RestoreRecheckState { idle, checking, passed, failed, unavailable }

/// What a check found: [failure] is the real reason when it failed.
typedef RestoreRecheckOutcome = ({RestoreRecheckState state, String? failure});

/// A "check again" button that cannot be pressed twice while it runs, and
/// says what it found in words, not only colour.
class RestoreRecheckButton extends StatefulWidget {
  final Future<RestoreRecheckOutcome> Function() onCheck;

  /// Called once a check passed.
  final VoidCallback? onPassed;

  const RestoreRecheckButton({super.key, required this.onCheck, this.onPassed});

  @override
  State<RestoreRecheckButton> createState() => _RestoreRecheckButtonState();
}

class _RestoreRecheckButtonState extends State<RestoreRecheckButton> {
  var _state = RestoreRecheckState.idle;
  String? _failure;

  Future<void> _run() async {
    if (_state == RestoreRecheckState.checking) return;
    setState(() {
      _state = RestoreRecheckState.checking;
      _failure = null;
    });
    RestoreRecheckOutcome outcome;
    try {
      outcome = await widget.onCheck();
    } catch (error) {
      outcome = (state: RestoreRecheckState.failed, failure: '$error');
    }
    if (!mounted) return;
    setState(() {
      _state = outcome.state;
      _failure = outcome.failure;
    });
    final l10n = AppLocalizations.of(context);
    final status = _statusText(l10n);
    if (status != null) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          status,
          Directionality.of(context),
        ),
      );
    }
    if (outcome.state == RestoreRecheckState.passed) widget.onPassed?.call();
  }

  String? _statusText(AppLocalizations l10n) => switch (_state) {
    RestoreRecheckState.idle => null,
    RestoreRecheckState.checking => l10n.restoreRecheckChecking,
    RestoreRecheckState.passed => l10n.restoreRecheckPassed,
    RestoreRecheckState.failed => l10n.restoreRecheckFailed(_failure ?? ''),
    RestoreRecheckState.unavailable => l10n.restoreRecheckUnavailable,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = _Palette.of(context);
    final status = _statusText(l10n);
    final checking = _state == RestoreRecheckState.checking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          // A new button per state: prism_ui's PressSurface updates its
          // states controller from didUpdateWidget when a pressed button
          // turns disabled, which marks the button dirty mid-build.
          key: ValueKey(checking),
          onPressed: checking ? null : _run,
          child: Text(l10n.macHelperCheckAgain),
        ),
        if (status != null)
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              style: _aux(context, p).copyWith(
                color: _state == RestoreRecheckState.failed
                    ? p.danger
                    : p.secondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// A restore refused because a mount operation was already pending. It
/// offers only an explicit check; nothing continues the old operation and
/// nothing removes the lock.
class RestorePendingRefusal extends StatelessWidget {
  final List<RestoreMountProfile> profiles;
  final Future<RestoreRecheckOutcome> Function() onCheck;

  const RestorePendingRefusal({
    super.key,
    required this.profiles,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = _Palette.of(context);
    final title = l10n.restoreResultRefused;
    return _SheetFrame(
      title: title,
      header: [
        _Header(
          icon: AppGlyphs.warning,
          iconColor: p.warning,
          title: title,
          lines: [
            if (profiles.isEmpty)
              l10n.restoreBlockedMountPending
            else
              l10n.restoreBlockedMountPendingNamed(
                profiles
                    .map((p) => restoreProfileName(p, l10n, withId: true))
                    .join(l10n.mountNameSeparator),
              ),
          ],
        ),
      ],
      slivers: (_) => _groupSlivers(
        context,
        l10n.restoreResultPendingSection('${profiles.length}'),
        [
          for (final profile in profiles)
            RestoreMountRow(
              group: RestoreMountGroup.check,
              owner: profile,
              source: '',
              tag: l10n.restoreMountTagCheck,
            ),
        ],
      ),
      footer: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: RestoreRecheckButton(onCheck: onCheck)),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

String restoreResultTitle(RestoreResultKind kind, AppLocalizations l10n) =>
    switch (kind) {
      RestoreResultKind.notStarted => l10n.restoreResultNotStarted,
      RestoreResultKind.rolledBack => l10n.restoreResultRolledBack,
      RestoreResultKind.rollbackUnverified => l10n.restoreResultUnverified,
      RestoreResultKind.committedLocked => l10n.restoreRestoredPending,
      RestoreResultKind.foreignSkipped => l10n.restoreOldVersionSkipped,
      RestoreResultKind.completed => l10n.restoreResultCompleted,
      RestoreResultKind.needsCheck => l10n.restoreResultNeedsCheck,
      RestoreResultKind.refusedPending => l10n.restoreResultRefused,
    };

/// The outcome of a restore, titled strictly by [evidence].
class RestoreResultView extends StatefulWidget {
  final RestoreEvidence evidence;

  /// Opens the profiles page; only navigates.
  final VoidCallback? onOpenProfiles;

  /// Runs the remaining steps, when this session really can.
  final Future<void> Function()? onContinue;

  const RestoreResultView({
    super.key,
    required this.evidence,
    this.onOpenProfiles,
    this.onContinue,
  });

  @override
  State<RestoreResultView> createState() => _RestoreResultViewState();
}

class _RestoreResultViewState extends State<RestoreResultView> {
  final _titleFocus = FocusNode();
  bool _continuing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final title = restoreResultTitle(widget.evidence.kind, l10n);
      // A major failure is said once, firmly, with focus on the title.
      if (widget.evidence.isMajorFailure) _titleFocus.requestFocus();
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          title,
          Directionality.of(context),
          assertiveness: widget.evidence.isMajorFailure
              ? Assertiveness.assertive
              : Assertiveness.polite,
        ),
      );
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final evidence = widget.evidence;
    final kind = evidence.kind;
    final l10n = AppLocalizations.of(context);
    final p = _Palette.of(context);
    final title = restoreResultTitle(kind, l10n);
    final pendingSteps = evidence.pendingSteps;
    final skippedSteps = evidence.skippedSteps;
    final checks = evidence.pendingChecks;
    final committed = evidence.committed == true;
    final unknown =
        committed &&
        (pendingSteps == null || skippedSteps == null || checks == null);
    final pendingRows = <RestoreMountRow>[
      for (final step in pendingSteps ?? const <RestoreStep>[])
        RestoreMountRow(
          group: RestoreMountGroup.check,
          owner: RestoreMountProfile(-1, label: restoreStepLabel(step, l10n)),
          source: '',
          tag: l10n.restoreMountTagCheck,
        ),
      for (final profile in checks ?? const <RestoreMountProfile>[])
        RestoreMountRow(
          group: RestoreMountGroup.check,
          owner: profile,
          source: '',
          note: l10n.restoreMountCheckNote,
          tag: l10n.restoreMountTagCheck,
        ),
    ];
    final skippedRows = <RestoreMountRow>[
      for (final step in skippedSteps ?? const <RestoreStep>[])
        RestoreMountRow(
          group: RestoreMountGroup.remove,
          owner: RestoreMountProfile(-1, label: restoreStepLabel(step, l10n)),
          source: '',
          tag: l10n.restoreMountTagInvalid,
        ),
    ];
    final lines = <String>[
      if (kind == RestoreResultKind.rollbackUnverified)
        l10n.restoreResultUnverifiedDetail,
      if (kind == RestoreResultKind.needsCheck)
        l10n.restoreResultNeedsCheckDetail,
      if (kind == RestoreResultKind.foreignSkipped)
        l10n.restoreResultSkippedNote,
    ];
    final locked =
        kind == RestoreResultKind.committedLocked ||
        kind == RestoreResultKind.foreignSkipped;
    return _SheetFrame(
      title: title,
      header: [
        _Header(
          icon: kind == RestoreResultKind.completed
              ? AppGlyphs.checkCircle
              : AppGlyphs.error,
          iconColor: kind == RestoreResultKind.completed ? p.accent : p.danger,
          title: title,
          lines: lines,
          titleFocus: _titleFocus,
        ),
        if (locked && pendingRows.isNotEmpty) ...[
          const SizedBox(height: 20),
          _Callout(lead: l10n.restoreResultLockedNote('${pendingRows.length}')),
        ],
        if (unknown) ...[
          const SizedBox(height: 20),
          _Callout(lead: l10n.restoreResultUnknownItems),
        ],
      ],
      slivers: (_) => [
        ..._groupSlivers(
          context,
          l10n.restoreResultPendingSection('${pendingRows.length}'),
          pendingRows,
        ),
        ..._groupSlivers(
          context,
          l10n.restoreResultSkippedSection('${skippedRows.length}'),
          skippedRows,
        ),
        if (committed && widget.onOpenProfiles != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.restoreResultNavigateOnly,
                style: _aux(context, p),
              ),
            ),
          ),
      ],
      footer: Wrap(
        alignment: WrapAlignment.end,
        spacing: 10,
        runSpacing: 10,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
          if (widget.onContinue case final run? when evidence.canContinue)
            TextButton(
              // See RestoreRecheckButton: never disable a pressed button
              // in place.
              key: ValueKey(_continuing),
              onPressed: _continuing
                  ? null
                  : () async {
                      setState(() => _continuing = true);
                      try {
                        await run();
                      } finally {
                        if (mounted) setState(() => _continuing = false);
                      }
                    },
              child: Text(l10n.restoreContinue),
            ),
          if (committed && widget.onOpenProfiles != null)
            FilledButton(
              onPressed: widget.onOpenProfiles,
              child: Text(l10n.restoreBlockedViewProfiles),
            ),
        ],
      ),
    );
  }
}
