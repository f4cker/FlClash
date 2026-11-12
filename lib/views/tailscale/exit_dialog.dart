import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

enum TailscaleExitOffChoice { turnOff, openProxies }

/// Turning the exit node off while policies use the exit group: each one
/// with the option it falls back to, or a re-pick first when that is unknown.
class TailscaleExitOffDialog extends StatelessWidget {
  const TailscaleExitOffDialog({
    super.key,
    required this.group,
    required this.affected,
  });

  final String group;
  final List<TailscaleExitParent> affected;

  bool get needsRepick => affected.any((parent) => parent.replacement == null);

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final body = AppTextStyle.body.of(context);
    return AlertDialog(
      title: appLocalizations.tsExitOffAffectedTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        if (needsRepick)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(TailscaleExitOffChoice.openProxies),
            child: Text(appLocalizations.tsExitOpenProxies),
          ),
        TextButton(
          onPressed: needsRepick
              ? null
              : () => Navigator.of(context).pop(TailscaleExitOffChoice.turnOff),
          child: Text(appLocalizations.tsExitTurnOff),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            needsRepick
                ? appLocalizations.tsExitOffRepickBody
                : appLocalizations.tsExitOffAffectedBody(group),
            style: body,
          ),
          for (final parent in affected)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${parent.name} → '),
                  TextSpan(
                    text:
                        parent.replacement ??
                        appLocalizations.tsExitRepickFirst,
                    style: TextStyle(
                      color: parent.replacement == null
                          ? DashboardColors.of(context).warn
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              style: body,
            ),
        ],
      ),
    );
  }
}
