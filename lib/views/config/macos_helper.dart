import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/service.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the single "Helper" card shows for a state. Pure, so it is unit-tested
/// without widgets.
enum MacHelperCardKind {
  ready,
  migration,
  approval,
  disabledByUser,
  starting,
  startSlow,
  signatureFailed,
  updateFailed,
  reinstall,
  move,
  unsupported,
  exitUnconfirmed,
}

enum MacHelperCardAction {
  migrate,
  retry,
  openSettings,
  recheck,
  repair,
  registerRepair,
  viewDetails,
}

final class MacHelperCardView {
  final MacHelperCardKind kind;
  final String title;
  final String? detail;
  final List<String> steps;

  /// The in-progress text replaces the buttons, never the card content.
  final String? progress;
  final MacHelperCardAction? primary;
  final MacHelperCardAction? secondary;

  /// Copyable raw text behind "View details"; never interpreted further.
  final String? rawDetail;

  const MacHelperCardView({
    required this.kind,
    required this.title,
    this.detail,
    this.steps = const [],
    this.progress,
    this.primary,
    this.secondary,
    this.rawDetail,
  });

  bool get isProblem => switch (kind) {
    MacHelperCardKind.signatureFailed ||
    MacHelperCardKind.updateFailed ||
    MacHelperCardKind.reinstall ||
    MacHelperCardKind.unsupported => true,
    _ => false,
  };
}

MacHelperCardKind macHelperCardKind(MacHelperState state, bool startSlow) =>
    switch (state) {
      MacHelperState.enabled => MacHelperCardKind.ready,
      MacHelperState.migrationRequired => MacHelperCardKind.migration,
      MacHelperState.requiresApproval ||
      MacHelperState.notRegistered => MacHelperCardKind.approval,
      MacHelperState.disabledByUser => MacHelperCardKind.disabledByUser,
      MacHelperState.starting || MacHelperState.staleHelper =>
        startSlow ? MacHelperCardKind.startSlow : MacHelperCardKind.starting,
      MacHelperState.signatureFailed => MacHelperCardKind.signatureFailed,
      MacHelperState.updateFailed => MacHelperCardKind.updateFailed,
      MacHelperState.reinstallRequired => MacHelperCardKind.reinstall,
      MacHelperState.moveRequired => MacHelperCardKind.move,
      MacHelperState.unsupported ||
      MacHelperState.disabled => MacHelperCardKind.unsupported,
      MacHelperState.exitUnconfirmed => MacHelperCardKind.exitUnconfirmed,
      // A status that could not be read is handled like a slow start: no
      // failure is claimed, the user can check again or view the raw code.
      MacHelperState.unavailable => MacHelperCardKind.startSlow,
    };

String macHelperFailedStepText(AppLocalizations l, MacHelperFailedStep step) =>
    switch (step) {
      MacHelperFailedStep.stopOld => l.macHelperFailedStopOld,
      MacHelperFailedStep.removeOld => l.macHelperFailedRemoveOld,
      MacHelperFailedStep.registerNew => l.macHelperFailedRegisterNew,
      MacHelperFailedStep.unknown => l.macHelperFailedUnknown,
    };

MacHelperCardView macHelperCardView(
  AppLocalizations l,
  MacHelperMaintenance flow,
) {
  final state = flow.state;
  if (flow.repairError != null && !flow.repairPending) {
    return MacHelperCardView(
      kind: MacHelperCardKind.exitUnconfirmed,
      title: l.macHelperCoreUnconfirmed,
      detail: l.macHelperRepairFailedDetail,
      progress: flow.busy ? l.macHelperChecking : null,
      primary: MacHelperCardAction.recheck,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: flow.repairError,
    );
  }
  if (flow.repairPending) {
    return MacHelperCardView(
      kind: MacHelperCardKind.exitUnconfirmed,
      title: l.macHelperCoreUnconfirmed,
      detail: flow.explicitRetryAvailable
          ? l.macHelperRepairFailedDetail
          : flow.repairError == null
          ? l.macHelperRepairPendingDetail
          : flow.client.lastRegistrationSettled
          ? '${l.macHelperRepairPendingDetail}\n${flow.repairError}'
          : '${l.macHelperRepairPendingDetail}\n${l.macHelperRepairUnknownOutcome}\n${flow.repairError}',
      progress: flow.busy ? l.macHelperChecking : null,
      primary: flow.explicitRetryAvailable
          ? MacHelperCardAction.repair
          : MacHelperCardAction.registerRepair,
      secondary: MacHelperCardAction.openSettings,
    );
  }
  if (state == null) {
    return MacHelperCardView(
      kind: MacHelperCardKind.starting,
      title: l.macHelperTitle,
      progress: l.macHelperChecking,
    );
  }
  final kind = macHelperCardKind(state, flow.startSlow);
  final busyText = switch (flow.progress) {
    MacHelperProgress.updating => l.macHelperUpdating,
    MacHelperProgress.checking ||
    MacHelperProgress.opening => l.macHelperChecking,
    MacHelperProgress.idle => null,
  };
  final raw = [
    if (flow.failure?.detail.isNotEmpty == true) flow.failure!.detail,
    if (flow.lastCode != null) 'status: ${flow.lastCode}',
  ].join('\n');
  return switch (kind) {
    MacHelperCardKind.ready => MacHelperCardView(
      kind: kind,
      title: l.macHelperOn,
    ),
    MacHelperCardKind.migration => MacHelperCardView(
      kind: kind,
      title: l.macHelperMigrationTitle,
      detail: l.macHelperMigrationDetail,
      progress: busyText,
      primary: MacHelperCardAction.migrate,
    ),
    MacHelperCardKind.approval => MacHelperCardView(
      kind: kind,
      title: l.macHelperApprovalTitle,
      detail: l.macHelperApprovalDetail,
      steps: [
        l.macHelperApprovalStep1,
        l.macHelperApprovalStep2,
        l.macHelperApprovalStep3,
      ],
      progress: busyText,
      primary: MacHelperCardAction.openSettings,
      secondary: MacHelperCardAction.recheck,
    ),
    MacHelperCardKind.disabledByUser => MacHelperCardView(
      kind: kind,
      title: l.macHelperDisabledTitle,
      detail: l.macHelperDisabledDetail,
      progress: busyText,
      primary: MacHelperCardAction.openSettings,
      secondary: MacHelperCardAction.recheck,
    ),
    MacHelperCardKind.starting => MacHelperCardView(
      kind: kind,
      title: l.macHelperStartingTitle,
      detail: l.macHelperStartingDetail,
      progress: l.macHelperStartingTitle,
    ),
    MacHelperCardKind.startSlow => MacHelperCardView(
      kind: kind,
      title: l.macHelperStartSlowTitle,
      detail: l.macHelperStartSlowDetail,
      progress: busyText,
      primary: MacHelperCardAction.recheck,
      secondary: MacHelperCardAction.repair,
      rawDetail: raw,
    ),
    MacHelperCardKind.signatureFailed => MacHelperCardView(
      kind: kind,
      title: l.macHelperSignatureTitle,
      detail: l.macHelperSignatureDetail,
      // Deliberately no action that could run the helper anyway.
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.updateFailed => MacHelperCardView(
      kind: kind,
      title: l.macHelperFailedTitle,
      detail: macHelperFailedStepText(
        l,
        flow.failure?.step ?? MacHelperFailedStep.unknown,
      ),
      progress: busyText,
      primary: MacHelperCardAction.retry,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.reinstall => MacHelperCardView(
      kind: kind,
      title: l.macHelperReinstallTitle,
      detail: l.macHelperReinstallDetail,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.move => MacHelperCardView(
      kind: kind,
      title: l.macHelperMoveTitle,
      detail: l.macHelperMoveDetail,
    ),
    MacHelperCardKind.unsupported => MacHelperCardView(
      kind: kind,
      title: l.macHelperReinstallTitle,
      detail: l.macHelperUnsupportedDetail,
    ),
    MacHelperCardKind.exitUnconfirmed => MacHelperCardView(
      kind: kind,
      title: l.macHelperCoreUnconfirmed,
      detail: l.macHelperStatusUnknown,
      progress: busyText,
      primary: MacHelperCardAction.recheck,
      // Stops the Core, then retires a stale daemon or registers it again.
      secondary: MacHelperCardAction.repair,
    ),
  };
}

String macHelperActionLabel(AppLocalizations l, MacHelperCardAction action) =>
    switch (action) {
      MacHelperCardAction.migrate => l.macHelperMigrationAction,
      MacHelperCardAction.retry => l.macHelperTryAgain,
      MacHelperCardAction.openSettings => l.macHelperOpenSettings,
      MacHelperCardAction.recheck => l.macHelperCheckAgain,
      MacHelperCardAction.repair => l.macHelperRepair,
      MacHelperCardAction.registerRepair => l.macHelperRegisterPending,
      MacHelperCardAction.viewDetails => l.macHelperViewDetails,
    };

/// One-line label for list items and tooltips.
String macHelperStatusLabel(AppLocalizations l, MacHelperMaintenance flow) =>
    macHelperCardView(l, flow).title;

/// What the top bar capsule beside the Core status button says.
enum MacHelperBarKind { ready, update, allow, starting, notReady, failedCheck }

/// How loud the button is: all well, something for the user to do, a
/// failure, or only a wait.
enum MacHelperBarTone { ready, action, failure, waiting }

final class MacHelperBarView {
  final MacHelperBarKind kind;
  final MacHelperBarTone tone;

  /// The short capsule text.
  final String label;

  /// The card's full title, which a screen reader reads.
  final String title;

  const MacHelperBarView({
    required this.kind,
    required this.tone,
    required this.label,
    required this.title,
  });

  /// A start in progress only waits; there is nothing to open.
  bool get opens => kind != MacHelperBarKind.starting;

  /// The round green button: nothing to fix.
  bool get isReady => kind == MacHelperBarKind.ready;
}

/// The bar button for the card the helper would show: a round green one when
/// ready, a capsule naming the problem otherwise; null until the first check
/// answers.
/// Pure, so it is unit-tested without widgets.
MacHelperBarView? macHelperBarView(
  AppLocalizations l,
  MacHelperMaintenance flow,
) {
  if (flow.state == null) return null;
  final card = macHelperCardView(l, flow);
  final (kind, tone) = switch (card.kind) {
    MacHelperCardKind.ready => (MacHelperBarKind.ready, MacHelperBarTone.ready),
    MacHelperCardKind.migration => (
      MacHelperBarKind.update,
      MacHelperBarTone.action,
    ),
    MacHelperCardKind.approval || MacHelperCardKind.disabledByUser => (
      MacHelperBarKind.allow,
      MacHelperBarTone.action,
    ),
    MacHelperCardKind.starting => (
      MacHelperBarKind.starting,
      MacHelperBarTone.waiting,
    ),
    // A slow start is not called a failure; the user can check again.
    MacHelperCardKind.startSlow ||
    MacHelperCardKind.exitUnconfirmed ||
    MacHelperCardKind.move => (
      MacHelperBarKind.notReady,
      MacHelperBarTone.action,
    ),
    MacHelperCardKind.updateFailed ||
    MacHelperCardKind.reinstall ||
    MacHelperCardKind.unsupported => (
      MacHelperBarKind.notReady,
      MacHelperBarTone.failure,
    ),
    MacHelperCardKind.signatureFailed => (
      MacHelperBarKind.failedCheck,
      MacHelperBarTone.failure,
    ),
  };
  return MacHelperBarView(
    kind: kind,
    tone: tone,
    title: card.title,
    label: switch (kind) {
      MacHelperBarKind.ready => l.macHelperOn,
      MacHelperBarKind.update => l.macHelperBarUpdate,
      MacHelperBarKind.allow => l.macHelperBarAllow,
      MacHelperBarKind.starting => l.macHelperBarStarting,
      MacHelperBarKind.notReady => l.macHelperBarNotReady,
      MacHelperBarKind.failedCheck => l.macHelperBarFailedCheck,
    },
  );
}

/// The bar button's icon, which the card's title repeats: the helper's gear
/// in its arrows, or a shield for a failed security check. A start shows a
/// progress ring instead.
/// The helper glyph is always the simpler one, solid gear and big hole, so
/// the bar, the popover and the card show one shape.
Glyph macHelperBarGlyph(MacHelperBarKind kind) => switch (kind) {
  MacHelperBarKind.failedCheck => AppGlyphs.shieldAlert,
  _ => AppGlyphs.helperDaemonSmall,
};

/// Green when ready, amber for something the user does, red for a failure.
Color macHelperBarColor(ColorScheme colorScheme, MacHelperBarTone tone) =>
    switch (tone) {
      MacHelperBarTone.ready => colorScheme.success,
      MacHelperBarTone.action => colorScheme.warning,
      MacHelperBarTone.failure => colorScheme.error,
      MacHelperBarTone.waiting => colorScheme.onSurfaceVariant,
    };

/// The top bar capsule while it is on screen: a feature that needs the helper
/// opens its popover instead of a dialog.
abstract interface class MacHelperPresenter {
  MacHelperMaintenance get maintenance;

  /// Whether the capsule is visible on the current page and can open.
  bool get canPresent;

  /// Opens the popover; completes when it closes.
  Future<void> present({required bool requiredByFeature});
}

MacHelperPresenter? _presenter;

void registerMacHelperPresenter(MacHelperPresenter presenter) =>
    _presenter = presenter;

void unregisterMacHelperPresenter(MacHelperPresenter presenter) {
  if (identical(_presenter, presenter)) _presenter = null;
}

final macHelperMaintenance = MacHelperMaintenance(
  macosHelperClient,
  stop: () => globalState.container.read(coreHandlerProvider).stop(),
  explicitRepair: () => coreService!.repairMacHelper(confirmed: true),
  recoverRepair: () => coreService!.recoverMacRepair(),
  canRetryExplicit: () => coreService!.canRetryMacExplicitRepair(),
  registerRepair: () => coreService!.registerPendingMacRepair(),
  observeLifecycle: true,
);

/// The "Helper" card. Switches content by state; collapses to one line when
/// ready; re-checks when Flash returns to the foreground.
class MacHelperCard extends StatefulWidget {
  final MacHelperMaintenance maintenance;

  /// Inside a dialog the card is not wrapped in its own [Card] surface.
  final bool embedded;

  /// The helper's version, said in grey under "Helper ready". The helper
  /// ships inside Flash and runs only when its code signature matches this
  /// build, so it is the app's version.
  final String? version;

  const MacHelperCard({
    super.key,
    required this.maintenance,
    this.embedded = false,
    this.version,
  });

  @override
  State<MacHelperCard> createState() => _MacHelperCardState();
}

class _MacHelperCardState extends State<MacHelperCard> {
  bool _details = false;
  String? _announced;

  @override
  void initState() {
    super.initState();
    if (widget.maintenance.state == null && !widget.maintenance.busy) {
      unawaited(widget.maintenance.check());
    }
  }

  void _announce(BuildContext context, String title) {
    if (_announced == title) return;
    final first = _announced == null;
    _announced = title;
    if (first) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        title,
        Directionality.of(context),
      ),
    );
  }

  void _run(MacHelperCardAction action) {
    final flow = widget.maintenance;
    switch (action) {
      case MacHelperCardAction.migrate:
      case MacHelperCardAction.retry:
        setState(() => _details = false);
        unawaited(flow.migrate(confirmed: true));
      case MacHelperCardAction.openSettings:
        unawaited(
          flow.repairPending ? flow.openRepairSettings() : flow.openSettings(),
        );
      case MacHelperCardAction.recheck:
        unawaited(flow.recheck());
      case MacHelperCardAction.repair:
        setState(() => _details = false);
        unawaited(_confirmRepair());
      case MacHelperCardAction.registerRepair:
        unawaited(flow.registerPendingRepair());
      case MacHelperCardAction.viewDetails:
        setState(() => _details = !_details);
    }
  }

  Future<void> _confirmRepair() async {
    final l = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      context: context,
      title: l.macHelperRepair,
      message: TextSpan(text: l.macHelperExplicitRepairWarning),
      confirmText: l.macHelperRepair,
    );
    if (confirmed == true && mounted) {
      await widget.maintenance.explicitRepair(confirmed: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.maintenance,
      builder: (context, _) {
        final l = context.appLocalizations;
        final view = macHelperCardView(l, widget.maintenance);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _announce(context, view.title);
        });
        final content = view.kind == MacHelperCardKind.ready
            ? _buildReady(context, view)
            : _buildContent(context, view);
        if (widget.embedded) return content;
        // A plain surface, not a [Card]: the card is not pressable, so it must
        // neither read as a button nor draw its text in disabled colors.
        final colorScheme = context.colorScheme;
        return Surface(
          color: view.isProblem
              ? colorScheme.errorContainer
              : context.raisedSurfaceLevel.colorOf(colorScheme),
          shape: AppShape.all(AppCorner.md),
          child: Padding(padding: const EdgeInsets.all(14), child: content),
        );
      },
    );
  }

  Widget _buildReady(BuildContext context, MacHelperCardView view) {
    final colorScheme = context.colorScheme;
    final version = widget.version;
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlyphIcon(
                AppGlyphs.helperDaemonSmall,
                color: colorScheme.success,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  view.title,
                  style: AppTextStyle.subheadline.of(context),
                ),
              ),
            ],
          ),
          if (version != null && version.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              context.appLocalizations.macHelperVersionLine(version),
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, MacHelperCardView view) {
    final l = context.appLocalizations;
    final busy = widget.maintenance.busy;
    final waiting = view.kind == MacHelperCardKind.starting;
    final footnote = AppTextStyle.footnote
        .of(context)
        .copyWith(height: 20 / 13);
    // The same icon and color as the capsule in the bar.
    final bar = macHelperBarView(l, widget.maintenance);
    final glyph = bar == null ? AppGlyphs.warning : macHelperBarGlyph(bar.kind);
    final glyphColor = bar == null
        ? context.colorScheme.warning
        : macHelperBarColor(context.colorScheme, bar.tone);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Row(
            children: [
              if (waiting)
                const ActivityIndicator(size: 16)
              else
                GlyphIcon(glyph, color: glyphColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  view.title,
                  style: AppTextStyle.subheadline.of(context),
                ),
              ),
            ],
          ),
        ),
        if (view.detail != null) ...[
          const SizedBox(height: 6),
          Text(view.detail!, style: footnote),
        ],
        for (final (index, step) in view.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              label: l.macHelperStepLabel('${index + 1}', step),
              excludeSemantics: true,
              child: Text('${index + 1}. $step', style: footnote),
            ),
          ),
        const SizedBox(height: 10),
        if (busy && view.progress != null && !waiting)
          Row(
            children: [
              const ActivityIndicator(size: 14),
              const SizedBox(width: 8),
              Text(view.progress!, style: footnote),
            ],
          )
        else if (!waiting)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (view.primary != null)
                FilledButton(
                  onPressed: busy ? null : () => _run(view.primary!),
                  child: Text(macHelperActionLabel(l, view.primary!)),
                ),
              if (view.secondary != null)
                TextButton(
                  onPressed: busy ? null : () => _run(view.secondary!),
                  child: Text(macHelperActionLabel(l, view.secondary!)),
                ),
              if (view.kind == MacHelperCardKind.startSlow &&
                  view.rawDetail != null &&
                  view.rawDetail!.isNotEmpty)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _run(MacHelperCardAction.viewDetails),
                  child: Text(l.macHelperViewDetails),
                ),
            ],
          ),
        if (_details && view.rawDetail != null && view.rawDetail!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    view.rawDetail!,
                    style: AppTextStyle.caption1.of(context),
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(
                    Clipboard.setData(ClipboardData(text: view.rawDetail!)),
                  ),
                  child: Text(l.copy),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void>? _visibleHelperDialog;

/// Shows the helper card in a dialog. With [requiredByFeature], a feature that
/// needs the helper (TUN, starting the Core) first explains why; its switch
/// stays off.
Future<void> showMacHelperFlow({
  BuildContext? context,
  MacHelperMaintenance? maintenance,
  bool requiredByFeature = false,
}) {
  final visible = _visibleHelperDialog;
  if (visible != null) return visible;
  final flow = maintenance ?? macHelperMaintenance;
  final presenter = _presenter;
  if (presenter != null &&
      identical(presenter.maintenance, flow) &&
      presenter.canPresent) {
    return presenter.present(requiredByFeature: requiredByFeature);
  }
  final operation = dialogs.showCommonDialog<void>(
    context: context,
    child: MacHelperDialog(
      maintenance: flow,
      requiredByFeature: requiredByFeature,
    ),
  );
  _visibleHelperDialog = operation;
  unawaited(operation.whenComplete(() => _visibleHelperDialog = null));
  return operation;
}

class MacHelperDialog extends StatefulWidget {
  final MacHelperMaintenance maintenance;
  final bool requiredByFeature;

  const MacHelperDialog({
    super.key,
    required this.maintenance,
    this.requiredByFeature = false,
  });

  @override
  State<MacHelperDialog> createState() => _MacHelperDialogState();
}

class _MacHelperDialogState extends State<MacHelperDialog> {
  late bool _gate = widget.requiredByFeature;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    if (_gate) {
      return AlertDialog(
        title: l.macHelperRequiredTitle,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => setState(() => _gate = false),
            child: Text(l.macHelperViewSetup),
          ),
        ],
        child: Text(
          l.macHelperRequiredDetail,
          textAlign: TextAlign.center,
          style: AppTextStyle.footnote.of(context).copyWith(height: 20 / 13),
        ),
      );
    }
    return AlertDialog(
      title: l.macHelperTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
      child: MacHelperCard(maintenance: widget.maintenance, embedded: true),
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
        subtitle: Text(macHelperStatusLabel(l, _flow)),
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
