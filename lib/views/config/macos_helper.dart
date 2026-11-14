import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MacHelperAction { install, update, settings, retry, recheck }

MacHelperAction? macHelperAction(MacHelperState state) => switch (state) {
  MacHelperState.off ||
  MacHelperState.installerRequired => MacHelperAction.install,
  MacHelperState.updateRequired ||
  MacHelperState.repairRequired ||
  MacHelperState.incompatible => MacHelperAction.update,
  MacHelperState.approvalRequired => MacHelperAction.settings,
  MacHelperState.cancelled ||
  MacHelperState.failed ||
  MacHelperState.denied => MacHelperAction.retry,
  MacHelperState.unavailable ||
  MacHelperState.unknown ||
  MacHelperState.exitUnconfirmed => MacHelperAction.recheck,
  _ => null,
};

String macHelperLabel(AppLocalizations l, MacHelperState state) =>
    switch (state) {
      MacHelperState.off || MacHelperState.installerRequired => l.macHelperOff,
      MacHelperState.enabled => l.macHelperOn,
      MacHelperState.approvalRequired => l.macHelperPending,
      MacHelperState.protectedInstallationRequired => l.macHelperMoveTitle,
      MacHelperState.updateRequired ||
      MacHelperState.repairRequired ||
      MacHelperState.incompatible => l.macHelperRepair,
      MacHelperState.unavailable ||
      MacHelperState.unknown ||
      MacHelperState.exitUnconfirmed => l.macHelperStopUnknown,
      MacHelperState.cancelled => l.macHelperInstallCancelled,
      MacHelperState.failed ||
      MacHelperState.denied => l.macHelperInstallFailed,
      _ => l.macHelperCannotUse,
    };

String _statusLabel(AppLocalizations l, MacHelperMaintenance flow) {
  return switch (flow.progress) {
    MacHelperProgress.checking => l.macHelperChecking,
    MacHelperProgress.authorizing => l.macHelperAuthorizing,
    MacHelperProgress.installing => l.macHelperInstalling,
    MacHelperProgress.updating => l.macHelperUpdating,
    MacHelperProgress.idle => switch (flow.state) {
      null => l.macHelperChecking,
      MacHelperState.cancelled when flow.isUpdate => l.macHelperUpdateCancelled,
      MacHelperState.failed ||
      MacHelperState.denied when flow.isUpdate => l.macHelperUpdateFailed,
      final state => macHelperLabel(l, state),
    },
  };
}

String _detail(AppLocalizations l, MacHelperMaintenance flow) {
  if (flow.progress == MacHelperProgress.checking) return l.macHelperChecking;
  if (flow.busy) return l.macHelperAuthorizing;
  return switch (flow.state) {
    MacHelperState.off ||
    MacHelperState.installerRequired => l.macHelperInstallDetail,
    MacHelperState.updateRequired ||
    MacHelperState.incompatible ||
    MacHelperState.repairRequired => l.macHelperUpdateDetail,
    MacHelperState.protectedInstallationRequired => l.macHelperMoveDetail,
    MacHelperState.approvalRequired => l.macHelperApprovalDetail,
    MacHelperState.denied => l.macHelperDeniedDetail,
    MacHelperState.signingRequired => l.macHelperVerificationDetail,
    MacHelperState.failed => switch (flow.client.failureCode) {
      'installerPayloadInvalid' => l.macHelperPayloadDetail,
      'verificationFailed' || 'incompatible' => l.macHelperVerificationDetail,
      _ => l.macHelperFailedDetail,
    },
    MacHelperState.exitUnconfirmed ||
    MacHelperState.unknown ||
    MacHelperState.unavailable => l.macHelperUnknownDetail,
    MacHelperState.enabled => l.macHelperReadyDetail,
    _ => '',
  };
}

final macHelperMaintenance = MacHelperMaintenance(
  macosHelperClient,
  stop: () => globalState.container.read(coreHandlerProvider).stop(),
);

Future<void>? _visibleHelperDialog;

Future<void> showMacHelperFlow({
  BuildContext? context,
  MacHelperMaintenance? maintenance,
}) {
  final visible = _visibleHelperDialog;
  if (visible != null) return visible;
  final flow = maintenance ?? macHelperMaintenance;
  final operation = dialogs.showCommonDialog<void>(
    context: context,
    child: MacHelperDialog(maintenance: flow),
  );
  _visibleHelperDialog = operation;
  unawaited(operation.whenComplete(() => _visibleHelperDialog = null));
  return operation;
}

class MacHelperDialog extends StatefulWidget {
  final MacHelperMaintenance maintenance;

  const MacHelperDialog({super.key, required this.maintenance});

  @override
  State<MacHelperDialog> createState() => _MacHelperDialogState();
}

class _MacHelperDialogState extends State<MacHelperDialog> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.maintenance.state == null && !widget.maintenance.busy) {
      unawaited(widget.maintenance.check());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.maintenance,
      builder: (context, _) {
        final flow = widget.maintenance;
        final l = context.appLocalizations;
        final action = flow.state == null ? null : macHelperAction(flow.state!);
        final invitation =
            !flow.busy &&
            (action == MacHelperAction.install ||
                action == MacHelperAction.update);
        final update = action == MacHelperAction.update;
        final status = _statusLabel(l, flow);
        final detail = _detail(l, flow);
        final failure =
            flow.state == MacHelperState.failed ||
            flow.state == MacHelperState.denied;
        return AlertDialog(
          title: invitation
              ? (update ? l.macHelperUpdateTitle : l.macHelperInstallTitle)
              : status,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                invitation
                    ? (update
                          ? l.macHelperNotNowUpdate
                          : l.macHelperNotNowInstall)
                    : flow.busy || flow.state == MacHelperState.enabled
                    ? l.close
                    : l.macHelperLater,
              ),
            ),
            if (!flow.busy && action != null)
              TextButton(
                onPressed: () {
                  switch (action) {
                    case MacHelperAction.install ||
                        MacHelperAction.update ||
                        MacHelperAction.retry:
                      unawaited(flow.install(confirmed: true));
                    case MacHelperAction.settings:
                      unawaited(flow.openSettings());
                    case MacHelperAction.recheck:
                      unawaited(flow.check());
                  }
                },
                child: Text(switch (action) {
                  MacHelperAction.install => l.macHelperInstall,
                  MacHelperAction.update => l.macHelperUpdate,
                  MacHelperAction.retry => l.macHelperTryAgain,
                  MacHelperAction.settings => l.macHelperOpenSettings,
                  MacHelperAction.recheck => l.macHelperCheckAgain,
                }),
              ),
          ],
          child: Semantics(
            liveRegion: true,
            label: status,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  detail,
                  maxLines: failure && !_expanded ? 3 : null,
                  overflow: failure && !_expanded
                      ? TextOverflow.ellipsis
                      : null,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(height: 20 / 13),
                ),
                if (failure)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded
                          ? l.macHelperLessDetails
                          : l.macHelperMoreDetails,
                    ),
                  ),
                if (!flow.busy && action == MacHelperAction.settings)
                  TextButton(
                    onPressed: () => unawaited(flow.check()),
                    child: Text(l.macHelperCheckAgain),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MacHelperItem extends ConsumerStatefulWidget {
  final MacHelperClient? client;
  final Future<CoreLifecycleResult> Function()? stop;

  const MacHelperItem({super.key, this.client, this.stop});

  @override
  ConsumerState<MacHelperItem> createState() => _MacHelperItemState();
}

class _MacHelperItemState extends ConsumerState<MacHelperItem> {
  late final MacHelperMaintenance _flow;

  @override
  void initState() {
    super.initState();
    _flow = widget.client == null
        ? macHelperMaintenance
        : MacHelperMaintenance(
            widget.client!,
            stop: widget.stop ?? () => ref.read(coreHandlerProvider).stop(),
          );
    if (!ref.read(safeModeProvider) && _flow.state == null) {
      unawaited(_flow.check());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return ListenableBuilder(
      listenable: _flow,
      builder: (context, _) => ListItem(
        title: Text(l.macHelperTitle),
        subtitle: Text(_statusLabel(l, _flow)),
        onTap: ref.watch(safeModeProvider)
            ? null
            : () async {
                if (!_flow.busy && _flow.state == MacHelperState.enabled) {
                  await _flow.check();
                  if (_flow.state == MacHelperState.enabled) return;
                }
                if (context.mounted) {
                  await showMacHelperFlow(context: context, maintenance: _flow);
                }
              },
      ),
    );
  }
}
