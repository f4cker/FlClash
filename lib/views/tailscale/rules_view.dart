import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/config/rules.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets.dart';

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
    final tag = TailscaleTag(label: appLocalizations.tsAddedInPanel);
    return Scaffold(
      title: appLocalizations.rules,
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
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                context.contentTopPadding,
                16,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: ListFooter(text: appLocalizations.tsManagedPriority),
              ),
            ),
            for (final account in accounts)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ListHeader(title: account.label, trailing: tag),
                      generateGroup(_accountRows(context, routes, account)),
                    ],
                  ),
                ),
              ),
            if (targets.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: ListHeader(
                    title: appLocalizations.tsAssignedTargets,
                    trailing: tag,
                  ),
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
      subtitle: subtitle == null ? null : Text(subtitle),
    );
    if (!account.attached || routes == null || !routes.active) {
      return [row(appLocalizations.tsRulesPending)];
    }
    final report = routes.accountOf(account.id);
    final verified = report != null && report.fresh && !report.loggedOut;
    return [
      row(appLocalizations.tsAttached, appLocalizations.tsAttachedTip),
      if (verified && report.domain.isNotEmpty)
        row(appLocalizations.tsRulesDomain(report.domain)),
      if (verified) row(appLocalizations.tsRulesAddresses(report.addresses)),
      row(appLocalizations.tsUnverifiedBlocked),
    ];
  }
}

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
    final (status, action) = switch (target.state) {
      TailscaleRouteState.assigned when assigned != null => (
        appLocalizations.tsAssignedTo(assigned),
        appLocalizations.tsReassign,
      ),
      TailscaleRouteState.unavailable => (
        [
          if (assigned != null) appLocalizations.tsAssignedTo(assigned),
          appLocalizations.tsAssignedUnavailable,
        ].join(' '),
        appLocalizations.tsReassign,
      ),
      TailscaleRouteState.reconfirm => (
        appLocalizations.tsReconfirm,
        appLocalizations.tsReassign,
      ),
      TailscaleRouteState.unconfirmed => (
        '${appLocalizations.tsTargetUnconfirmed} · '
            '${appLocalizations.tsTargetUnconfirmedTip}',
        canChoose ? appLocalizations.tsChooseAccountFor : null,
      ),
      _ => (
        appLocalizations.tsNotAssigned,
        appLocalizations.tsChooseAccountFor,
      ),
    };
    return ListItem(
      title: Text(
        target.target.value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyle.body.of(context).toJetBrainsMono,
      ),
      subtitle: Text(status),
      trailing: action == null || !canChoose
          ? null
          : TextButton(
              onPressed: () => onAssign(target.target),
              child: Text(action),
            ),
    );
  }
}
