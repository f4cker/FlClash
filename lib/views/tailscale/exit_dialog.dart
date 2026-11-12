import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

const tailscaleExitOffDialogWidth = 600.0;

class TailscaleExitOffRows extends StatelessWidget {
  const TailscaleExitOffRows({
    super.key,
    required this.group,
    required this.plan,
  });

  final String group;
  final TailscaleExitOffPlan plan;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final body = AppTextStyle.body.of(context);
    final colorScheme = context.colorScheme;
    Widget row(String name, String to, Color color) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$name → '),
          TextSpan(
            text: to,
            style: TextStyle(color: color),
          ),
        ],
      ),
      style: body,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(appLocalizations.tsExitOffAffectedBody(group), style: body),
        if (plan.groupMove case final next?)
          row(group, next.member, colorScheme.onSurfaceVariant),
        for (final move in plan.moves)
          row(move.group, move.to, colorScheme.onSurfaceVariant),
        for (final name in plan.empty)
          row(name, appLocalizations.tsExitOffNoOption, colorScheme.error),
      ],
    );
  }
}
