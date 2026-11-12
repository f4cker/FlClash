import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/rules.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef TailscaleRulesAccount = ({String id, String label, bool attached});

/// The panel's own routing, design.md §13.3–13.4: each account's automatic
/// rules, read-only, then the targets a choice decides.
class TailscaleRulesView extends ConsumerWidget {
  const TailscaleRulesView({
    super.key,
    required this.accounts,
    required this.labelOf,
    required this.onAssign,
  });

  final List<TailscaleRulesAccount> accounts;
  final String Function(TailscaleRouteOwner owner) labelOf;
  final ValueChanged<TailscaleRouteTarget> onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final routes = ref.watch(tailscaleRoutesReportProvider).value;
    final targets = [
      for (final target in routes?.targets ?? const [])
        if (target.state != TailscaleRouteState.bound) target,
    ];
    return Scaffold(
      title: appLocalizations.rules,
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Flexible(
            child: Text(
              appLocalizations.rules,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InfoButton(
            label: appLocalizations.tsAboutRules,
            paragraphs: [appLocalizations.tsManagedPriority],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => showInSheet<void>(
            context,
            builder: (_) => const AddedRulesView(),
          ),
          child: Text(appLocalizations.addedRules),
        ),
      ],
      body: Builder(
        builder: (context) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: context.contentTopPadding),
            ),
            for (final account in accounts)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _AccountHeader(
                        title: account.label,
                        about: [appLocalizations.tsUnverifiedBlocked],
                      ),
                      generateGroup(_accountRows(context, routes, account)),
                    ],
                  ),
                ),
              ),
            if (targets.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: ListHeader(title: appLocalizations.tsAssignedTargets),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + context.bottomInset),
              sliver: SliverPrismList(
                itemCount: targets.length,
                itemBuilder: (context, index) => ItemPositionProvider(
                  position: ItemPosition.get(index, targets.length),
                  child: _TargetRow(
                    target: targets[index],
                    labelOf: labelOf,
                    onAssign: onAssign,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _accountRows(
    BuildContext context,
    TailscaleRoutes? routes,
    TailscaleRulesAccount account,
  ) {
    final appLocalizations = context.appLocalizations;
    Widget row(String title, [String? subtitle]) => ListItem(
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(color: context.colorScheme.onSurfaceVariant),
            ),
    );
    if (!account.attached || routes == null || !routes.active) {
      return [row(appLocalizations.tsRulesPending)];
    }
    final report = routes.accountOf(account.id);
    final verified = report != null && report.fresh && !report.loggedOut;
    final stale = !verified && !(report?.loggedOut ?? false);
    return [
      row(
        appLocalizations.tsAttached,
        stale ? appLocalizations.tsRulesUnconfirmed : null,
      ),
      if (verified && report.domain.isNotEmpty)
        row(appLocalizations.tsRulesDomain(report.domain)),
      if (verified) row(appLocalizations.tsRulesAddresses(report.addresses)),
    ];
  }
}

/// A group title with its explanation right after the name, behind the info
/// button.
class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.title, required this.about});

  final String title;
  final List<String> about;

  @override
  Widget build(BuildContext context) {
    final padding = listHeaderPaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        padding.left,
        math.max(0, padding.top - _headerOverhang),
        padding.right,
        math.max(0, padding.bottom - _headerOverhang),
      ),
      child: Row(
        spacing: 4,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.headline
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ),
          InfoButton(paragraphs: about),
        ],
      ),
    );
  }
}

/// Half of what the info button stands above a headline line.
const _headerOverhang = 3.0;

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.target,
    required this.labelOf,
    required this.onAssign,
  });

  final TailscaleRouteTargetReport target;
  final String Function(TailscaleRouteOwner owner) labelOf;
  final ValueChanged<TailscaleRouteTarget> onAssign;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final owner = target.owner;
    final assigned = owner == null ? null : labelOf(owner);
    final canChoose = target.candidates.any((candidate) => !candidate.removed);
    final (status, action, blocked) = switch (target.state) {
      TailscaleRouteState.assigned when assigned != null => (
        appLocalizations.tsAssignedTo(assigned),
        appLocalizations.tsReassign,
        false,
      ),
      TailscaleRouteState.unavailable => (
        [
          if (assigned != null) appLocalizations.tsAssignedTo(assigned),
          appLocalizations.tsAssignedUnavailable,
        ].join(' '),
        appLocalizations.tsReassign,
        true,
      ),
      TailscaleRouteState.reconfirm => (
        appLocalizations.tsReconfirm,
        appLocalizations.tsReassign,
        false,
      ),
      TailscaleRouteState.unconfirmed => (
        '${appLocalizations.tsTargetUnconfirmed} · '
            '${appLocalizations.tsTargetUnconfirmedTip}',
        canChoose ? appLocalizations.tsChooseAccountFor : null,
        false,
      ),
      _ => (
        appLocalizations.tsNotAssigned,
        appLocalizations.tsChooseAccountFor,
        true,
      ),
    };
    final warning = context.colorScheme.warning;
    return ListItem(
      title: Text(
        target.target.value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyle.body.of(context).toJetBrainsMono,
      ),
      subtitle: blocked
          ? Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: GlyphIcon(
                        AppGlyphs.warning,
                        size: 12,
                        color: warning,
                      ),
                    ),
                  ),
                  TextSpan(text: status),
                ],
              ),
              style: TextStyle(color: warning),
            )
          : Text(status),
      trailing: action == null || !canChoose
          ? null
          : TextButton(
              onPressed: () => onAssign(target.target),
              child: Text(action),
            ),
    );
  }
}
