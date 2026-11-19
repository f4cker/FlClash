import 'dart:async';

import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/config_item.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BetaUpdateSetting extends ConsumerWidget {
  const BetaUpdateSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConfigToggleItem(
    key: const ValueKey('receive-beta-updates'),
    title: (l) => l.receiveBetaUpdates,
    subtitle: (l) => l.receiveBetaUpdatesDescription,
    selector: appSettingProvider.select((s) => s.receiveBetaUpdates),
    enabled: !ref.watch(updateInstallCommittedProvider),
    onChanged: (ref, value) {
      final action = ref.read(commonActionProvider.notifier);
      ref
          .read(appSettingProvider.notifier)
          .update((s) => s.copyWith(receiveBetaUpdates: value));
      unawaited(action.checkForAppUpdate());
    },
  );
}
