import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MacHelperAction { enable, installer, disable, retry, repair, recheck }

MacHelperAction? macHelperAction(MacHelperState state) => switch (state) {
  MacHelperState.off => MacHelperAction.enable,
  MacHelperState.approvalRequired ||
  MacHelperState.installerRequired ||
  MacHelperState.protectedInstallationRequired => MacHelperAction.installer,
  MacHelperState.enabled => MacHelperAction.disable,
  MacHelperState.unavailable || MacHelperState.denied => MacHelperAction.retry,
  MacHelperState.repairRequired ||
  MacHelperState.incompatible => MacHelperAction.repair,
  MacHelperState.exitUnconfirmed => MacHelperAction.recheck,
  _ => null,
};

String macHelperLabel(AppLocalizations l, MacHelperState state) =>
    switch (state) {
      MacHelperState.off => l.macHelperOff,
      MacHelperState.installerRequired ||
      MacHelperState.protectedInstallationRequired => l.macHelperPending,
      MacHelperState.enabled => l.macHelperOn,
      MacHelperState.approvalRequired => l.macHelperPending,
      MacHelperState.unavailable ||
      MacHelperState.denied => l.macHelperUnavailable,
      MacHelperState.repairRequired ||
      MacHelperState.incompatible => l.macHelperRepair,
      MacHelperState.exitUnconfirmed => l.macHelperStopUnknown,
      _ => l.macHelperCannotUse,
    };

String _actionLabel(AppLocalizations l, MacHelperAction action) =>
    switch (action) {
      MacHelperAction.enable => l.macHelperTurnOn,
      MacHelperAction.installer => l.macHelperOpenSettings,
      MacHelperAction.disable => l.macHelperTurnOff,
      MacHelperAction.retry => l.macHelperTryAgain,
      MacHelperAction.repair => l.macHelperRepairAction,
      MacHelperAction.recheck => l.macHelperCheckAgain,
    };

class MacHelperItem extends ConsumerStatefulWidget {
  final MacHelperClient? client;
  final Future<CoreLifecycleResult> Function()? stop;

  const MacHelperItem({super.key, this.client, this.stop});

  @override
  ConsumerState<MacHelperItem> createState() => _MacHelperItemState();
}

class _MacHelperItemState extends ConsumerState<MacHelperItem> {
  MacHelperState? _state;
  bool _busy = false;

  MacHelperClient get _client => widget.client ?? macosHelperClient;

  Future<void> _show() async {
    if (_busy || ref.read(safeModeProvider)) return;
    setState(() => _busy = true);
    try {
      final state = await _client.status();
      if (!mounted) return;
      setState(() => _state = state);
      final l = context.appLocalizations;
      final action = macHelperAction(state);
      final detail = switch (state) {
        MacHelperState.approvalRequired ||
        MacHelperState.installerRequired ||
        MacHelperState.protectedInstallationRequired ||
        MacHelperState.off ||
        MacHelperState.repairRequired ||
        MacHelperState.incompatible ||
        MacHelperState.enabled => l.macHelperPendingDetail,
        MacHelperState.unavailable ||
        MacHelperState.denied => l.macHelperUnavailableDetail,
        _ => '',
      };
      if (action == null) {
        await dialogs.showAlert(
          title: l.macHelperTitle,
          message: TextSpan(text: macHelperLabel(l, state)),
        );
        return;
      }
      final confirmed = await dialogs.showMessage(
        context: context,
        title: l.macHelperTitle,
        message: TextSpan(
          text:
              '${macHelperLabel(l, state)}${detail.isEmpty ? '' : '\n\n$detail'}',
        ),
        confirmText: _actionLabel(l, action),
        destructive: action == MacHelperAction.disable,
      );
      if (confirmed != true || !mounted || ref.read(safeModeProvider)) return;
      final MacHelperState next;
      switch (action) {
        case MacHelperAction.enable || MacHelperAction.installer:
          next = await _client.installerInstructions(confirmed: true);
        case MacHelperAction.disable:
          next = await MacHelperMaintenance(
            _client,
            stop:
                widget.stop ??
                () async {
                  final result = await ref.read(coreHandlerProvider).stop();
                  if (result.outcome != CoreLifecycleOutcome.superseded) {
                    ref.read(coreStatusProvider.notifier).value =
                        CoreStatus.disconnected;
                  }
                  return result;
                },
          ).turnOff(confirmed: true);
        case MacHelperAction.retry || MacHelperAction.recheck:
          next = await _client.status();
        case MacHelperAction.repair:
          next = await _client.installerInstructions(confirmed: true);
      }
      if (mounted) {
        setState(() => _state = next);
        if (next == MacHelperState.installerRequired) {
          await dialogs.showAlert(
            title: l.macHelperTitle,
            message: TextSpan(text: l.macHelperPendingDetail),
          );
        }
      }
    } on Exception {
      if (mounted) setState(() => _state = MacHelperState.unavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return ListItem(
      title: Text(l.macHelperTitle),
      subtitle: _state == null ? null : Text(macHelperLabel(l, _state!)),
      onTap: _busy ? null : _show,
    );
  }
}
