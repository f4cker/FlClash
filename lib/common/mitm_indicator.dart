import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';

String mitmPauseReasonText(AppLocalizations l, MitmPauseReason reason) =>
    switch (reason) {
      MitmPauseReason.coreStopped => l.mitmPauseCoreStopped,
      MitmPauseReason.coreIdentity => l.mitmPauseCoreIdentity,
      MitmPauseReason.notTrusted => l.mitmPauseNotTrusted,
      MitmPauseReason.liveness => l.mitmPauseLiveness,
      MitmPauseReason.indicatorPending => l.mitmPauseIndicatorPending,
      MitmPauseReason.unavailable => l.mitmPauseUnavailable,
    };

/// The status in a few words.
String mitmIndicatorLabel(AppLocalizations l, MitmIndicator indicator) =>
    switch (indicator.kind) {
      MitmIndicatorKind.decrypting => l.mitmIndicatorDecrypting,
      MitmIndicatorKind.paused => l.mitmIndicatorPaused,
      MitmIndicatorKind.unconfirmed => l.mitmIndicatorUnconfirmed,
    };

/// The whole status, with why it is paused: the tray item and the tooltip.
String mitmIndicatorText(AppLocalizations l, MitmIndicator indicator) =>
    switch (indicator.reason) {
      final reason? => l.mitmIndicatorPausedBecause(
        mitmPauseReasonText(l, reason),
      ),
      null => mitmIndicatorLabel(l, indicator),
    };
