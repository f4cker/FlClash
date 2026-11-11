import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'widgets.dart';

typedef _OwnerLabel =
    ({String account, String network}) Function(TailscaleRouteOwner owner);

/// The choices for the targets awaiting one, design.md §13.4, [focus]
/// first even when it already has one; null when cancelled. A target left
/// unchosen stays blocked.
Future<List<TailscaleRouteAssignment>?> showTailscaleAssignDialog(
  BuildContext context, {
  required TailscaleRoutes routes,
  required ({String account, String network}) Function(
    TailscaleRouteOwner owner,
  )
  labelOf,
  TailscaleRouteTarget? focus,
}) {
  final focused = focus == null
      ? null
      : routes.targetOf(focus.kind, focus.value);
  return dialogs.showCommonDialog<List<TailscaleRouteAssignment>>(
    context: context,
    child: _AssignDialog(
      targets: [
        ?focused,
        for (final target in routes.pending)
          if (target.target != focus) target,
      ],
      labelOf: labelOf,
    ),
  );
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({required this.targets, required this.labelOf});

  final List<TailscaleRouteTargetReport> targets;
  final _OwnerLabel labelOf;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  final Map<TailscaleRouteTarget, TailscaleRouteOwner> _chosen = {};

  /// A saved choice shows as chosen; one awaiting reconfirmation does not.
  TailscaleRouteOwner? _savedOf(TailscaleRouteTargetReport target) =>
      switch (target.state) {
        TailscaleRouteState.assigned ||
        TailscaleRouteState.unavailable => target.owner,
        _ => null,
      };

  void _save() {
    Navigator.of(context).pop([
      for (final MapEntry(:key, :value) in _chosen.entries)
        TailscaleRouteAssignment(target: key, owner: value),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    return AlertDialog(
      title: appLocalizations.tsAssignTitle,
      width: 440,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.tsCancel),
        ),
        TextButton(
          onPressed: _chosen.isEmpty ? null : _save,
          child: Text(appLocalizations.tsSaveChoices),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(
            appLocalizations.tsAssignBody,
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          for (final target in widget.targets)
            _TargetBlock(
              target: target,
              chosen: _chosen[target.target] ?? _savedOf(target),
              labelOf: widget.labelOf,
              onChosen: (owner) => setState(() {
                _chosen[target.target] = owner;
              }),
            ),
        ],
      ),
    );
  }
}

class _TargetBlock extends StatelessWidget {
  const _TargetBlock({
    required this.target,
    required this.chosen,
    required this.labelOf,
    required this.onChosen,
  });

  final TailscaleRouteTargetReport target;
  final TailscaleRouteOwner? chosen;
  final _OwnerLabel labelOf;
  final ValueChanged<TailscaleRouteOwner> onChosen;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final value = target.target.value;
    final title = target.target.kind == tailscaleTargetIp
        ? appLocalizations.tsTargetAddress(value)
        : appLocalizations.tsTargetDomain(value);
    return Semantics(
      label: title,
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: DashboardColors.of(context).tone,
          shape: AppShape.all(AppCorner.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              _TargetTitle(title: title, value: value),
              if (target.state == TailscaleRouteState.reconfirm)
                Text(
                  appLocalizations.tsReconfirm,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
              for (final candidate in target.candidates)
                if (!candidate.removed)
                  _CandidateRow(
                    candidate: candidate,
                    label: labelOf(candidate.owner),
                    selected: candidate.owner == chosen,
                    onTap: () => onChosen(candidate.owner),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The address or domain itself in monospace, its label as written.
class _TargetTitle extends StatelessWidget {
  const _TargetTitle({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.subheadline.of(context, emphasized: true);
    final at = title.indexOf(value);
    if (at < 0) {
      return Text(title, style: style.toJetBrainsMono);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: title.substring(0, at)),
          TextSpan(text: value, style: style.toJetBrainsMono),
          TextSpan(text: title.substring(at + value.length)),
        ],
      ),
      style: style,
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final TailscaleRouteCandidate candidate;
  final ({String account, String network}) label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final account = candidate.label.takeFirstValid([label.account]);
    final network = candidate.tailnet.takeFirstValid([label.network]);
    final device = candidate.device.takeFirstValid([account]);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            spacing: 10,
            children: [
              _RadioMark(selected: selected),
              TailscaleAvatar(name: account),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.subheadline.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                    Text(
                      appLocalizations.tsCandidate(account, network),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.outline;
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: CircleBorder(side: BorderSide(color: color, width: 1.5)),
      ),
      child: selected
          ? DecoratedBox(
              decoration: ShapeDecoration(color: color, shape: AppShape.circle),
              child: const SizedBox.square(dimension: 8),
            )
          : null,
    );
  }
}
