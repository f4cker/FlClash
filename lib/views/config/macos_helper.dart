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

  /// The previous build's helper was asked to exit after an app update and
  /// the new one is awaited: a calm wait, bounded by the switch window.
  switchingHelper,
  startSlow,
  signatureFailed,
  updateFailed,
  reinstall,
  move,
  unsupported,
  exitUnconfirmed,

  /// The helper did not become ready after a recovery, or old Cores are not
  /// confirmed stopped: "not ready yet", with the raw text behind details.
  notReady,

  /// FlashHelperLauncher refused the helper (signature, location or version
  /// unreadable), refused an older version than one that already ran, or
  /// could not prepare or start it. Only "View details": nothing here can
  /// run the helper anyway.
  launcherCheckFailed,
  launcherDowngrade,
  launcherFailed,

  /// SMAppService has no record of the intact, trusted bundle: "Repair"
  /// re-registers it (user action only); after a repair that did not help,
  /// only the details.
  serviceNotFound,
  serviceRepairFailed,

  /// The launcher's version record is unreadable: one button rebuilds it
  /// (administrator prompt), the raw reason stays behind "View details".
  launcherRecordDamaged,
}

enum MacHelperCardAction {
  migrate,
  retry,

  /// "Register" for a helper SMAppService does not know yet: the same
  /// [MacHelperMaintenance.openSettings], which registers first and opens
  /// System Settings only when the system then asks for approval.
  register,
  openSettings,
  recheck,
  repair,
  recover,
  repairRecord,

  /// "Repair" for serviceNotFound: the user-triggered recovery.
  repairRegistration,
  viewDetails,

  /// The written approval steps, in the status deck's details view.
  viewSteps,
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
    MacHelperCardKind.serviceRepairFailed ||
    MacHelperCardKind.unsupported ||
    MacHelperCardKind.launcherCheckFailed ||
    MacHelperCardKind.launcherDowngrade ||
    MacHelperCardKind.launcherFailed ||
    MacHelperCardKind.launcherRecordDamaged => true,
    _ => false,
  };
}

MacHelperCardKind macHelperCardKind(
  MacHelperState state,
  bool startSlow, {
  bool switching = false,
}) => switch (state) {
  MacHelperState.enabled => MacHelperCardKind.ready,
  MacHelperState.migrationRequired => MacHelperCardKind.migration,
  // Registered but not allowed yet, or not registered at all: the user
  // allows Flash in System Settings (registering it first if needed).
  MacHelperState.requiresApproval ||
  MacHelperState.notRegistered => MacHelperCardKind.approval,
  // Allowed before and switched off since: said as such, never as "waiting
  // for approval".
  MacHelperState.disabledByUser => MacHelperCardKind.disabledByUser,
  MacHelperState.starting || MacHelperState.staleHelper when switching =>
    MacHelperCardKind.switchingHelper,
  MacHelperState.starting ||
  MacHelperState.staleHelper ||
  MacHelperState.repairing =>
    startSlow ? MacHelperCardKind.startSlow : MacHelperCardKind.starting,
  MacHelperState.registrationStale ||
  MacHelperState.notReady ||
  MacHelperState.staleCore => MacHelperCardKind.notReady,
  // A reply that fails the app's verification is a failed security
  // check, never "the helper couldn't start": it is running.
  MacHelperState.signatureFailed ||
  MacHelperState.untrustedReply => MacHelperCardKind.signatureFailed,
  MacHelperState.updateFailed => MacHelperCardKind.updateFailed,
  MacHelperState.reinstallRequired => MacHelperCardKind.reinstall,
  MacHelperState.serviceNotFound => MacHelperCardKind.serviceNotFound,
  MacHelperState.serviceRepairFailed => MacHelperCardKind.serviceRepairFailed,
  MacHelperState.moveRequired => MacHelperCardKind.move,
  MacHelperState.unsupported ||
  MacHelperState.disabled => MacHelperCardKind.unsupported,
  MacHelperState.exitUnconfirmed => MacHelperCardKind.exitUnconfirmed,
  MacHelperState.launcherCheckFailed => MacHelperCardKind.launcherCheckFailed,
  MacHelperState.launcherDowngrade => MacHelperCardKind.launcherDowngrade,
  MacHelperState.launcherFailed => MacHelperCardKind.launcherFailed,
  MacHelperState.launcherRecordDamaged =>
    MacHelperCardKind.launcherRecordDamaged,
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
  if (state == null) {
    return MacHelperCardView(
      kind: MacHelperCardKind.starting,
      title: l.macHelperTitle,
      progress: l.macHelperChecking,
    );
  }
  final kind = macHelperCardKind(
    state,
    flow.startSlow,
    switching: flow.switchingHelper,
  );
  final busyText = switch (flow.progress) {
    MacHelperProgress.updating => l.macHelperUpdating,
    MacHelperProgress.repairingRecord => l.macHelperRecordRepairing,
    MacHelperProgress.checking ||
    MacHelperProgress.opening => l.macHelperChecking,
    MacHelperProgress.idle => null,
  };
  final raw = flow.rawDetail;
  // After a recovery re-registered the helper, the system may show Flash's
  // switch on while its daemon item is off: only then do the steps say to
  // turn it off and on again. Otherwise the last step is to turn it on.
  final recovered = flow.repairPending || flow.autoRecoveries > 0;
  final steps = [
    l.macHelperApprovalStep1,
    l.macHelperApprovalStep2,
    recovered ? l.macHelperApprovalStepReset : l.macHelperApprovalStep3,
  ];
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
    // Not registered yet: "Register", which registers and then opens System
    // Settings only if the system asks for approval.
    MacHelperCardKind.approval when state == MacHelperState.notRegistered =>
      MacHelperCardView(
        kind: kind,
        title: l.macHelperRegisterTitle,
        detail: l.macHelperRegisterDetail,
        steps: steps,
        progress: busyText,
        primary: MacHelperCardAction.register,
        secondary: MacHelperCardAction.viewSteps,
      ),
    MacHelperCardKind.approval => MacHelperCardView(
      kind: kind,
      title: l.macHelperApprovalTitle,
      detail: l.macHelperAwaitingApprovalDetail,
      steps: steps,
      progress: busyText,
      // The only thing the user is asked to do; Flash re-checks by itself.
      primary: MacHelperCardAction.openSettings,
      secondary: MacHelperCardAction.viewSteps,
    ),
    MacHelperCardKind.disabledByUser => MacHelperCardView(
      kind: kind,
      title: l.macHelperDisabledTitle,
      detail: l.macHelperDisabledByUserDetail,
      steps: steps,
      progress: busyText,
      primary: MacHelperCardAction.openSettings,
      secondary: MacHelperCardAction.viewSteps,
    ),
    MacHelperCardKind.starting => MacHelperCardView(
      kind: kind,
      title:
          state == MacHelperState.repairing ||
              flow.progress == MacHelperProgress.updating
          ? l.macHelperUpdating
          : l.macHelperStartingTitle,
      detail: l.macHelperStartingDetail,
      progress: l.macHelperStartingTitle,
      // A wait offers nothing to run; what it waits on stays readable.
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.switchingHelper => MacHelperCardView(
      kind: kind,
      title: l.macHelperSwitchingTitle,
      detail: l.macHelperStartingDetail,
      progress: l.macHelperSwitchingTitle,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.notReady => MacHelperCardView(
      kind: kind,
      title: l.macHelperNotReadyTitle,
      detail: state == MacHelperState.staleCore
          ? l.macHelperStaleCoreDetail
          : l.macHelperRegistrationFailedDetail,
      progress: busyText,
      primary: MacHelperCardAction.recover,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.startSlow => MacHelperCardView(
      kind: kind,
      // An unreadable status names no cause: "unavailable", with the raw
      // code behind "View details".
      title: state == MacHelperState.unavailable
          ? l.macHelperUnavailableTitle
          : l.macHelperStartSlowTitle,
      detail: state == MacHelperState.unavailable
          ? l.macHelperStatusUnreadable
          : l.macHelperStartSlowDetail,
      progress: busyText,
      primary: MacHelperCardAction.recheck,
      secondary: MacHelperCardAction.viewDetails,
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
    MacHelperCardKind.serviceNotFound => MacHelperCardView(
      kind: kind,
      title: l.macHelperServiceNotFoundTitle,
      detail: l.macHelperServiceNotFoundDetail,
      progress: busyText,
      primary: MacHelperCardAction.repairRegistration,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.serviceRepairFailed => MacHelperCardView(
      kind: kind,
      title: l.macHelperServiceNotFoundTitle,
      detail: l.macHelperServiceRepairFailedDetail,
      // No loop: the register error and status are behind "View details".
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
      // Stops the Core through the app, then asks the helper again.
      primary: MacHelperCardAction.repair,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    // What the launcher reported; the reason (result, detail, versions) is
    // only behind "View details". No action could make it run anyway.
    MacHelperCardKind.launcherCheckFailed => MacHelperCardView(
      kind: kind,
      title: l.macHelperLauncherCheckTitle,
      detail: l.macHelperLauncherCheckDetail,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.launcherDowngrade => MacHelperCardView(
      kind: kind,
      title: l.macHelperLauncherDowngradeTitle,
      detail: l.macHelperLauncherDowngradeDetail,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.launcherFailed => MacHelperCardView(
      kind: kind,
      title: l.macHelperLauncherFailedTitle,
      detail: l.macHelperLauncherFailedDetail,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
    MacHelperCardKind.launcherRecordDamaged => MacHelperCardView(
      kind: kind,
      title: l.macHelperRecordDamagedTitle,
      detail: switch (flow.recordRepair) {
        'failed' || 'denied' => l.macHelperRecordRepairFailed,
        _ => l.macHelperRecordDamagedDetail,
      },
      progress: busyText,
      primary: MacHelperCardAction.repairRecord,
      secondary: MacHelperCardAction.viewDetails,
      rawDetail: raw,
    ),
  };
}

String macHelperActionLabel(AppLocalizations l, MacHelperCardAction action) =>
    switch (action) {
      MacHelperCardAction.migrate => l.macHelperMigrationAction,
      MacHelperCardAction.retry => l.macHelperTryAgain,
      MacHelperCardAction.register => l.macHelperRegisterAction,
      MacHelperCardAction.openSettings => l.macHelperOpenSettings,
      MacHelperCardAction.recheck => l.macHelperCheckAgain,
      MacHelperCardAction.repair => l.macHelperRepair,
      MacHelperCardAction.recover => l.macHelperTryAgain,
      MacHelperCardAction.repairRecord => l.macHelperRecordRepairAction,
      MacHelperCardAction.repairRegistration =>
        l.macHelperServiceNotFoundAction,
      MacHelperCardAction.viewDetails => l.macHelperViewDetails,
      MacHelperCardAction.viewSteps => l.macHelperViewSteps,
    };

/// Whether [action] opens the card's own details rather than asking the
/// helper anything.
bool isMacHelperViewAction(MacHelperCardAction action) =>
    action == MacHelperCardAction.viewDetails ||
    action == MacHelperCardAction.viewSteps;

/// Runs a card's helper action through [flow], the one dispatch the settings
/// card and the status deck share. Nothing runs while an operation is in
/// flight, so a second tap never sends a second request; the view actions
/// are the card's own and do nothing here.
void runMacHelperAction(MacHelperMaintenance flow, MacHelperCardAction action) {
  if (isMacHelperViewAction(action) || flow.busy) return;
  switch (action) {
    // A failed update or registration step resumes the update itself,
    // never the generic recovery.
    case MacHelperCardAction.migrate:
    case MacHelperCardAction.retry:
      unawaited(flow.migrate(confirmed: true));
    case MacHelperCardAction.register:
    case MacHelperCardAction.openSettings:
      unawaited(flow.openSettings());
    case MacHelperCardAction.recheck:
      unawaited(flow.recheck());
    case MacHelperCardAction.repair:
      unawaited(flow.repair());
    case MacHelperCardAction.recover:
    case MacHelperCardAction.repairRegistration:
      unawaited(flow.retryRecovery());
    case MacHelperCardAction.repairRecord:
      unawaited(flow.repairRecord());
    case MacHelperCardAction.viewDetails:
    case MacHelperCardAction.viewSteps:
      break;
  }
}

/// One-line label for list items and tooltips.
String macHelperStatusLabel(AppLocalizations l, MacHelperMaintenance flow) =>
    macHelperCardView(l, flow).title;

/// What the helper's status says in short: its entry glyph and loudness.
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
  final (kind, tone) = macHelperBarKindOf(card.kind);
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

/// The short kind and the tone of a card: how loud the status entry is.
/// Pure and total, so every card kind has one.
(MacHelperBarKind, MacHelperBarTone) macHelperBarKindOf(
  MacHelperCardKind card,
) => switch (card) {
  MacHelperCardKind.ready => (MacHelperBarKind.ready, MacHelperBarTone.ready),
  MacHelperCardKind.migration => (
    MacHelperBarKind.update,
    MacHelperBarTone.action,
  ),
  MacHelperCardKind.approval || MacHelperCardKind.disabledByUser => (
    MacHelperBarKind.allow,
    MacHelperBarTone.action,
  ),
  MacHelperCardKind.starting || MacHelperCardKind.switchingHelper => (
    MacHelperBarKind.starting,
    MacHelperBarTone.waiting,
  ),
  // A slow start is not called a failure; the user can check again.
  MacHelperCardKind.startSlow ||
  MacHelperCardKind.exitUnconfirmed ||
  MacHelperCardKind.notReady ||
  MacHelperCardKind.serviceNotFound ||
  MacHelperCardKind.move => (
    MacHelperBarKind.notReady,
    MacHelperBarTone.action,
  ),
  MacHelperCardKind.updateFailed ||
  MacHelperCardKind.reinstall ||
  MacHelperCardKind.serviceRepairFailed ||
  MacHelperCardKind.unsupported ||
  MacHelperCardKind.launcherDowngrade ||
  MacHelperCardKind.launcherFailed ||
  MacHelperCardKind.launcherRecordDamaged => (
    MacHelperBarKind.notReady,
    MacHelperBarTone.failure,
  ),
  MacHelperCardKind.signatureFailed || MacHelperCardKind.launcherCheckFailed =>
    (MacHelperBarKind.failedCheck, MacHelperBarTone.failure),
};

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

/// The dashboard's live status entry while it is on screen: a feature that
/// needs the helper opens the status deck on the helper card instead of a
/// dialog.
abstract interface class MacHelperPresenter {
  MacHelperMaintenance get maintenance;

  /// Whether the entry is visible on the current page and can open.
  bool get canPresent;

  /// Opens the deck on the helper card; completes when the deck closes.
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
  recover: () => coreService!.recoverMacHelper(),
  settleRepair: () => coreService!.settleMacRepair(),
  repairPending: () => coreService!.macRepairPending(),
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
    if (isMacHelperViewAction(action)) {
      setState(() => _details = !_details);
      return;
    }
    if (action != MacHelperCardAction.openSettings &&
        action != MacHelperCardAction.register &&
        action != MacHelperCardAction.recheck) {
      setState(() => _details = false);
    }
    runMacHelperAction(widget.maintenance, action);
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
    final waiting =
        view.kind == MacHelperCardKind.starting ||
        view.kind == MacHelperCardKind.switchingHelper;
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
              // The steps are written out above: no "View steps" here.
              if (view.secondary != null &&
                  view.secondary != MacHelperCardAction.viewSteps &&
                  (view.secondary != MacHelperCardAction.viewDetails ||
                      view.rawDetail?.isNotEmpty == true))
                TextButton(
                  onPressed: busy ? null : () => _run(view.secondary!),
                  child: Text(macHelperActionLabel(l, view.secondary!)),
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
