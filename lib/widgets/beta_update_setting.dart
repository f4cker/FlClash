import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/config_item.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BetaUpdateSetting extends ConsumerWidget {
  const BetaUpdateSetting({super.key, this.leading, this.stackable = false});

  final Widget? leading;

  /// Lets a narrow row give the description its own full-width line rather
  /// than a column squeezed between the leading slot and the switch.
  final bool stackable;

  static const _key = ValueKey('receive-beta-updates');
  static const _maxSideBySideLines = 2;

  // The row's padding, leading slot, title gap and switch column beside the
  // description, as ListRow lays them out with a 40 dp leading.
  static const _besideReserve = 16 + 40 + 16 + 16 + 51 + 8;

  static void _change(WidgetRef ref, bool value) {
    final action = ref.read(commonActionProvider.notifier);
    ref
        .read(appSettingProvider.notifier)
        .update((s) => s.copyWith(receiveBetaUpdates: value));
    unawaited(action.checkForAppUpdate());
  }

  bool _stacks(BuildContext context, double width) {
    if (!stackable || !width.isFinite) return false;
    final painter = TextPainter(
      text: TextSpan(
        text: context.appLocalizations.receiveBetaUpdatesDescription,
        style: context.listSubtitleStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(0, width - _besideReserve));
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines > _maxSideBySideLines;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) => _stacks(context, constraints.maxWidth)
        ? _StackedBetaUpdateRow(key: _key, leading: leading)
        : ConfigToggleItem(
            key: _key,
            leading: leading,
            title: (l) => l.receiveBetaUpdates,
            subtitle: (l) => l.receiveBetaUpdatesDescription,
            selector: appSettingProvider.select((s) => s.receiveBetaUpdates),
            enabled: !ref.watch(updateInstallCommittedProvider),
            onChanged: _change,
          ),
  );
}

class _StackedBetaUpdateRow extends ConsumerWidget {
  const _StackedBetaUpdateRow({super.key, this.leading});

  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(
      appSettingProvider.select((s) => s.receiveBetaUpdates),
    );
    final onChanged = ref.watch(updateInstallCommittedProvider)
        ? null
        : (bool value) => BetaUpdateSetting._change(ref, value);
    final leading = this.leading;
    return ListItem(
      padding: const EdgeInsets.only(left: 16, right: 8),
      onTap: onChanged == null ? null : () => onChanged(!value),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Row(
            spacing: 16,
            children: [
              ?leading,
              Expanded(child: Text(appLocalizations.receiveBetaUpdates)),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
          Text(
            appLocalizations.receiveBetaUpdatesDescription,
            style: context.listSubtitleStyle,
          ),
        ],
      ),
    );
  }
}
