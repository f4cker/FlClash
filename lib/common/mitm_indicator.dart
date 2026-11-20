import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';

String mitmPauseReasonText(AppLocalizations l, MitmPauseReason reason) =>
    switch (reason) {
      MitmPauseReason.coreStopped => l.mitmPauseCoreStopped,
      MitmPauseReason.coreIdentity => l.mitmPauseCoreIdentity,
      MitmPauseReason.notTrusted => l.mitmPauseNotTrusted,
      MitmPauseReason.notApplied => l.mitmNotApplied,
      MitmPauseReason.liveness => l.mitmPauseLiveness,
      MitmPauseReason.indicatorPending => l.mitmPauseIndicatorPending,
      MitmPauseReason.partialConnections => l.mitmPartialConnections,
      MitmPauseReason.appUnavailable => l.mitmPauseAppUnavailable,
      MitmPauseReason.signTimeout => l.mitmPauseSignTimeout,
      MitmPauseReason.signRefused => l.mitmPauseSignRefused,
      MitmPauseReason.leafUnusable => l.mitmPauseLeafUnusable,
      MitmPauseReason.unavailable => l.mitmPauseUnavailable,
    };

/// What to do about a pause the signer caused, or null when nothing helps.
String? mitmPauseReasonHint(AppLocalizations l, MitmPauseReason reason) =>
    switch (reason) {
      MitmPauseReason.appUnavailable => l.mitmPauseAppUnavailableHint,
      MitmPauseReason.signTimeout => l.mitmPauseSignTimeoutHint,
      MitmPauseReason.signRefused => l.mitmPauseSignRefusedHint,
      MitmPauseReason.leafUnusable => l.mitmPauseLeafUnusableHint,
      MitmPauseReason.unavailable => l.mitmPauseUnavailableHint,
      _ => null,
    };

/// The status in a few words.
String mitmIndicatorLabel(AppLocalizations l, MitmIndicator indicator) =>
    switch (indicator) {
      MitmIndicator(reason: MitmPauseReason.partialConnections) =>
        l.mitmPartialConnections,
      _ => switch (indicator.kind) {
        MitmIndicatorKind.on => l.mitmIndicatorOn,
        MitmIndicatorKind.decrypting => l.mitmIndicatorDecrypting,
        MitmIndicatorKind.paused => l.mitmIndicatorPaused,
        MitmIndicatorKind.unconfirmed => l.mitmIndicatorUnconfirmed,
      },
    };

/// The whole status, with why it is paused: the tray item and the tooltip.
String mitmIndicatorText(AppLocalizations l, MitmIndicator indicator) =>
    switch (indicator.reason) {
      // A whole sentence of its own: decryption is not paused, it never began.
      MitmPauseReason.notApplied => l.mitmNotApplied,
      MitmPauseReason.partialConnections => l.mitmPartialConnections,
      final reason? => l.mitmIndicatorPausedBecause(
        mitmPauseReasonText(l, reason),
      ),
      null => mitmIndicatorLabel(l, indicator),
    };

/// Whether the status asks for action rather than restating that decryption
/// runs. The Core's partialConnections caveat is information, not a fault.
bool mitmIndicatorNeedsAttention(MitmIndicator indicator) =>
    switch (indicator) {
      MitmIndicator(reason: MitmPauseReason.partialConnections) => false,
      MitmIndicator(
        kind: MitmIndicatorKind.on || MitmIndicatorKind.decrypting,
        reason: null,
      ) =>
        false,
      _ => true,
    };
