import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'mount.dart';

/// How many group rows show before 显示全部, design §12.
const mountGroupsShown = 8;

/// What a listed group says on its right, design §12.1.
enum MountGroupState { none, pending, applied, noMatch }

/// The collapsed row's one state, the worst first, design §13.
enum MountGroupsStatus { normal, pending, noMatch, unconfirmed }

class MountGroupLine {
  const MountGroupLine({
    required this.group,
    required this.state,
    this.mounted = 0,
    this.status,
  });

  final MountGroupInfo group;
  final MountGroupState state;
  final int mounted;
  final MountGroupStatus? status;
}

/// The groups block's content, apart from how it is laid out.
/// [unconfirmed]: the list is read but what runs could not be confirmed,
/// so no row says anything. [hidden] counts the hidden groups that take
/// mounts, which are never listed nor counted in [rows].
class MountGroupsView {
  const MountGroupsView({
    required this.rows,
    required this.hidden,
    required this.unconfirmed,
    this.hiddenBlocked = 0,
    this.hiddenNoMatch = 0,
  });

  final List<MountGroupLine> rows;
  final int hidden;
  final bool unconfirmed;
  final int hiddenBlocked;
  final int hiddenNoMatch;

  int get noMatch =>
      rows.where((row) => row.state == MountGroupState.noMatch).length +
      hiddenNoMatch;

  MountGroupsStatus get status {
    if (noMatch > 0) {
      return MountGroupsStatus.noMatch;
    }
    if (unconfirmed) {
      return MountGroupsStatus.unconfirmed;
    }
    if (rows.any((row) => row.state == MountGroupState.pending)) {
      return MountGroupsStatus.pending;
    }
    return MountGroupsStatus.normal;
  }

  /// A group down to its REJECT fallback refuses connections now: never
  /// left behind a collapsed row.
  bool get blocking =>
      hiddenBlocked > 0 || rows.any((row) => row.status?.warn ?? false);

  bool get forcedOpen => blocking || hiddenNoMatch > 0;
}

/// [pending]: the ticks are not what is applied, so rows are candidates
/// only. [applied] is a readback that confirms the stored relation runs;
/// without one, a stored relation is unconfirmed. Neither, for a target
/// with nothing mounted or ticked, says nothing on the rows. [runtime] is
/// any readback, enough for how an empty group is handled.
MountGroupsView mountGroupsViewOf(
  MountTarget target, {
  required bool pending,
  required bool mounted,
  required MountRuntimeState? applied,
  MountRuntimeState? runtime,
  required AppLocalizations appLocalizations,
}) {
  runtime ??= applied;
  final rows = <MountGroupLine>[];
  var hidden = 0;
  var hiddenBlocked = 0;
  var hiddenNoMatch = 0;
  final report = {
    for (final group in applied?.report?.groups ?? const <MountGroupReport>[])
      group.name: group,
  };
  final running = {
    for (final group in applied?.groups ?? const <MountRuntimeGroup>[])
      group.name: group,
  };
  final unconfirmed = !pending && mounted && applied == null;
  for (final group in target.groups) {
    if (group.kind != MountGroupKind.auto) {
      continue;
    }
    var state = MountGroupState.none;
    var count = 0;
    final status = mountGroupStatusOf(
      group,
      report: runtime?.report?.groups,
      runtime: runtime?.groups,
      appLocalizations: appLocalizations,
    );
    if (pending) {
      state = MountGroupState.pending;
    } else if (applied != null) {
      final runtime = running[group.name];
      if (report.containsKey(group.name) && (runtime?.present ?? false)) {
        count = runtime!.mounted;
        state = count > 0 ? MountGroupState.applied : MountGroupState.noMatch;
      }
    }
    if (group.hidden) {
      hidden++;
      if (status?.warn ?? false) {
        hiddenBlocked++;
      } else if (state == MountGroupState.noMatch) {
        hiddenNoMatch++;
      }
      continue;
    }
    rows.add(
      MountGroupLine(
        group: group,
        state: state,
        mounted: count,
        status: status,
      ),
    );
  }
  return MountGroupsView(
    rows: rows,
    hidden: hidden,
    unconfirmed: unconfirmed,
    hiddenBlocked: hiddenBlocked,
    hiddenNoMatch: hiddenNoMatch,
  );
}

/// The groups block, design §12, §12.1 and §13: one summary row that opens
/// to the read-only list.
class MountGroupsSection extends StatelessWidget {
  const MountGroupsSection({
    super.key,
    required this.view,
    required this.expanded,
    required this.showAll,
    required this.onToggle,
    required this.onShowAll,
  });

  final MountGroupsView view;
  final bool expanded;
  final bool showAll;
  final VoidCallback onToggle;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final open = expanded || view.forcedOpen;
    final (statusText, warn) = switch (view.status) {
      MountGroupsStatus.normal => (null, false),
      MountGroupsStatus.pending => (appLocalizations.mountGroupPending, false),
      MountGroupsStatus.noMatch => (
        appLocalizations.mountGroupsNoMatch(view.noMatch),
        true,
      ),
      MountGroupsStatus.unconfirmed => (
        appLocalizations.mountGroupsUnconfirmed,
        false,
      ),
    };
    final count = view.rows.isEmpty && view.hidden > 0
        ? appLocalizations.mountGroupsHiddenCount(view.hidden)
        : appLocalizations.mountGroupsCount(view.rows.length);
    final caption = AppTextStyle.caption2
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final header = Semantics(
      button: true,
      expanded: open,
      label: [appLocalizations.mountGroupsTitle, count, ?statusText].join(', '),
      excludeSemantics: true,
      onTap: view.forcedOpen ? null : onToggle,
      child: PressRegion(
        onTap: view.forcedOpen ? null : onToggle,
        shape: AppShape.all(AppCorner.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44 - 24),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      appLocalizations.mountGroupsTitle,
                      style: AppTextStyle.body.of(context, emphasized: true),
                    ),
                    Text(count, style: caption),
                  ],
                ),
              ),
              if (statusText != null)
                Text(
                  statusText,
                  style: warn
                      ? AppTextStyle.caption2
                            .of(context, emphasized: true)
                            .copyWith(color: colorScheme.warning)
                      : caption,
                ),
              GlyphIcon(
                open ? AppGlyphs.chevronDown : AppGlyphs.chevronForward,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
    final rows = showAll || view.rows.length <= mountGroupsShown
        ? view.rows
        : view.rows.take(mountGroupsShown).toList();
    return MountGroupsBlock(
      corner: AppCorner.lg,
      children: [
        header,
        if (open) ...[
          Text(
            appLocalizations.mountGroupsSummary,
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurface),
          ),
          if (view.unconfirmed)
            Text(appLocalizations.mountGroupsUnconfirmed, style: caption),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [for (final row in rows) MountGroupRow(line: row)],
          ),
          if (rows.length < view.rows.length)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MountTextAction(
                label: appLocalizations.mountShowAllGroups(view.rows.length),
                onPressed: onShowAll,
              ),
            ),
          if (view.hidden > 0)
            Text(appLocalizations.mountGroupsHidden, style: caption),
          for (final line in [
            if (view.hiddenBlocked > 0)
              appLocalizations.mountGroupsHiddenBlocked(view.hiddenBlocked),
            if (view.hiddenNoMatch > 0)
              appLocalizations.mountGroupsHiddenNoMatch(view.hiddenNoMatch),
          ])
            Text(
              line,
              style: AppTextStyle.caption2
                  .of(context, emphasized: true)
                  .copyWith(color: colorScheme.warning),
            ),
        ],
      ],
    );
  }
}

/// One read-only group: name, type tag, 空组时拦截 where it applies, and
/// its state on the right.
class MountGroupRow extends StatelessWidget {
  const MountGroupRow({super.key, required this.line});

  final MountGroupLine line;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final group = line.group;
    final status = line.status;
    final filtered = group.filter || group.excludeFilter || group.excludeType;
    final right = switch (line.state) {
      MountGroupState.none =>
        filtered ? appLocalizations.mountHintFiltered : null,
      MountGroupState.pending => appLocalizations.mountGroupPending,
      MountGroupState.applied => appLocalizations.mountGroupNodes(line.mounted),
      MountGroupState.noMatch => appLocalizations.mountGroupNoMatch,
    };
    final warn = line.state == MountGroupState.noMatch;
    final type = mountGroupTypeTag(group, appLocalizations);
    final emptyLine = status?.blockTag ?? false
        ? (status!.warn ? status.line : null)
        : status?.line;
    final warnLine = status?.warn ?? false;
    return Semantics(
      container: true,
      label: [group.name, type, ?right, ?emptyLine].join('，'),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 2,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        group.name,
                        style: AppTextStyle.subheadline.of(context),
                      ),
                      MountTag(label: type),
                      if (status?.blockTag ?? false)
                        Tooltip(
                          message: appLocalizations.mountBlockDesc,
                          child: MountTag(
                            label: appLocalizations.mountBlockTag,
                          ),
                        ),
                    ],
                  ),
                ),
                if (right != null)
                  Text(
                    right,
                    style: AppTextStyle.caption2
                        .of(context, emphasized: warn)
                        .copyWith(
                          color: warn
                              ? colorScheme.warning
                              : colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            if (emptyLine != null)
              Text(
                emptyLine,
                style: AppTextStyle.caption2
                    .of(context, emphasized: warnLine)
                    .copyWith(
                      color: warnLine
                          ? colorScheme.warning
                          : colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
