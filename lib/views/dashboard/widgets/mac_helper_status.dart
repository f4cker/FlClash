import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

class MacHelperStatus extends ConsumerWidget {
  final Widget child;
  final MacHelperMaintenance? maintenance;

  const MacHelperStatus({super.key, required this.child, this.maintenance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow =
        maintenance ??
        (system.isMacOS && macosManagedHelperBuild
            ? macHelperMaintenance
            : null);
    if (flow == null || ref.watch(safeModeProvider)) return child;
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final visible =
            flow.busy ||
            (flow.state != null && flow.state != MacHelperState.enabled);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (visible)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  context.contentTopPadding,
                  16,
                  0,
                ),
                child: _buildHelperStatus(context, ref, flow),
              ),
            Expanded(
              child: TopInsetScope(
                inset: visible ? 12 : TopInsetScope.of(context),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelperStatus(
    BuildContext context,
    WidgetRef ref,
    MacHelperMaintenance flow,
  ) {
    final l = context.appLocalizations;
    final state = flow.state;
    final coreStatus = ref.watch(coreStatusProvider);
    final stopped =
        coreStatus == CoreStatus.disconnected && !flow.client.hasCoreSession;
    final sessionUnconfirmed =
        coreStatus != CoreStatus.connected && flow.client.hasCoreSession;
    final reason = flow.busy
        ? macHelperStatusLabel(l, flow)
        : switch (state) {
            MacHelperState.off || MacHelperState.installerRequired
                when stopped =>
              l.macHelperStartupInstall,
            MacHelperState.updateRequired || MacHelperState.incompatible
                when stopped =>
              l.macHelperStartupUpdate,
            MacHelperState.repairRequired when stopped =>
              l.macHelperStartupUnavailable,
            MacHelperState.repairRequired => l.macHelperUnavailable,
            MacHelperState.signingRequired => l.macHelperVerificationFailed,
            MacHelperState.unknown ||
            MacHelperState.unavailable => l.macHelperStatusUnknown,
            MacHelperState.exitUnconfirmed => l.macHelperCoreUnconfirmed,
            _ => macHelperStatusLabel(l, flow),
          };
    final action = flow.busy || state == null ? null : macHelperAction(state);
    final label = switch (action) {
      MacHelperAction.install => l.macHelperInstallAction,
      MacHelperAction.update => l.macHelperUpdateAction,
      MacHelperAction.settings => l.macHelperOpenSettings,
      MacHelperAction.retry => l.macHelperTryAgain,
      MacHelperAction.recheck => l.macHelperCheckAgain,
      null => l.macHelperMoreDetails,
    };
    return Tooltip(
      message: macHelperDetail(l, flow),
      child: TextButton.icon(
        onPressed: () {
          switch (action) {
            case MacHelperAction.recheck:
              unawaited(flow.check());
            case MacHelperAction.settings:
              unawaited(flow.openSettings());
            default:
              unawaited(showMacHelperFlow(context: context, maintenance: flow));
          }
        },
        icon: GlyphIcon(AppGlyphs.warning, color: context.colorScheme.warning),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sessionUnconfirmed && state != MacHelperState.exitUnconfirmed
                    ? '$reason\n${l.macHelperCoreUnconfirmed}'
                    : reason,
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: context.colorScheme.warning),
              ),
              Text(label, style: AppTextStyle.caption2.of(context)),
            ],
          ),
        ),
      ),
    );
  }
}
