import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'legacy_notice.dart';
import 'state.dart';
import 'widgets.dart';

class TailscaleCardActions {
  const TailscaleCardActions({
    required this.onLogin,
    required this.onRelogin,
    required this.onReopen,
    required this.onRead,
    required this.onLogout,
    required this.onRetryStart,
    required this.onGoToProfiles,
    required this.onCopy,
    required this.onMigrate,
    required this.onRecheckLegacy,
  });

  final VoidCallback onLogin;
  final VoidCallback onRelogin;
  final VoidCallback onReopen;
  final VoidCallback onRead;
  final VoidCallback onLogout;
  final VoidCallback onRetryStart;
  final VoidCallback onGoToProfiles;
  final ValueChanged<String> onCopy;
  final VoidCallback onMigrate;
  final VoidCallback onRecheckLegacy;
}

class TailscaleDeviceCard extends StatelessWidget {
  const TailscaleDeviceCard({
    super.key,
    required this.node,
    required this.phase,
    required this.status,
    required this.actions,
    required this.legacyView,
    required this.legacyState,
    required this.now,
    this.stale = false,
    this.notice,
    this.loggingIn = false,
    this.loggingOut = false,
    this.reading = false,
    this.restarting = false,
    this.wide = true,
  });

  final TailscaleNode node;
  final TailscalePhase phase;
  final TailscaleStatus? status;
  final TailscaleCardActions actions;
  final TailscaleLegacyView legacyView;
  final TailscaleLegacyState legacyState;
  final DateTime now;

  /// The last read is kept, but reading it again failed.
  final bool stale;
  final TailscaleCardNotice? notice;
  final bool loggingIn;
  final bool loggingOut;
  final bool reading;
  final bool restarting;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final (chipLabel, chipTone) = _chipOf(context);
    final busyChip =
        phase == TailscalePhase.starting || phase == TailscalePhase.preparing;
    final legacyShown = legacyView != TailscaleLegacyView.hidden;
    final banners = [
      if (_noticeBanner(context) case final banner?)
        banner
      else if (legacyShown)
        TailscaleLegacyBlock(
          node: node,
          view: legacyView,
          state: legacyState,
          reading: reading,
          onRecheck: actions.onRecheckLegacy,
          onRead: actions.onRead,
        )
      else
        ?_stateBanner(context),
      if (stale && phase != TailscalePhase.loadFailed)
        TailscaleBanner(
          level: TailscaleBannerLevel.error,
          text: appLocalizations.tsLoadFailedTip,
          actionLabel: appLocalizations.tsReadStatus,
          onAction: reading ? null : actions.onRead,
        ),
    ];
    final offers = legacyShown && _legacyOffers;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [?_address(context), if (!offers) ?_meta(context), ...banners],
    );
    final buttons = _actions(context);
    return Semantics(
      container: true,
      label: [
        appLocalizations.tsCurrentDevice,
        node.name,
        ?tailscaleAddressOf(status?.self),
        chipLabel,
      ].join('，'),
      child: TailscaleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            DashboardCardHeader(
              glyph: AppGlyphs.devices,
              title: appLocalizations.tsCurrentDevice,
              leading: [
                Flexible(
                  child: Text(
                    '· ${appLocalizations.tsNodeOf(node.name)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                ),
                Semantics(
                  label: appLocalizations.tsStatusOf(chipLabel),
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      if (busyChip)
                        const RepaintBoundary(
                          child: ActivityIndicator(size: 12),
                        ),
                      DashboardChip(
                        label: chipLabel,
                        tone: chipTone,
                        dot: !busyChip,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (wide)
              Row(
                spacing: 20,
                children: [
                  Expanded(child: left),
                  if (buttons.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 8,
                      children: buttons,
                    ),
                ],
              )
            else ...[
              left,
              if (buttons.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: buttons),
            ],
          ],
        ),
      ),
    );
  }

  bool get _legacyOffers => const {
    TailscaleLegacyView.offer,
    TailscaleLegacyView.failed,
    TailscaleLegacyView.changed,
    TailscaleLegacyView.unknown,
  }.contains(legacyView);

  (String, DashboardChipTone) _chipOf(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (phase) {
      TailscalePhase.loadFailed => (
        appLocalizations.tsStateLoadFailed,
        DashboardChipTone.error,
      ),
      TailscalePhase.preparing => (
        appLocalizations.tsStatePreparing,
        DashboardChipTone.idle,
      ),
      TailscalePhase.starting => (
        appLocalizations.tsStateStarting,
        DashboardChipTone.idle,
      ),
      TailscalePhase.signedOut => (
        appLocalizations.tsStateSignedOut,
        DashboardChipTone.idle,
      ),
      TailscalePhase.waitingBrowser => (
        appLocalizations.tsStateWaitingBrowser,
        DashboardChipTone.warn,
      ),
      TailscalePhase.needsApproval => (
        appLocalizations.tsStateNeedsApproval,
        DashboardChipTone.warn,
      ),
      TailscalePhase.connected => (
        appLocalizations.tsStateConnected,
        DashboardChipTone.ok,
      ),
      TailscalePhase.needsReauth => (
        appLocalizations.tsStateNeedsReauth,
        DashboardChipTone.warn,
      ),
      TailscalePhase.stopped => (
        appLocalizations.tsStateStopped,
        DashboardChipTone.idle,
      ),
      TailscalePhase.startFailed => (
        appLocalizations.tsStateStartFailed,
        DashboardChipTone.error,
      ),
      TailscalePhase.unconfirmed => (
        appLocalizations.tsStateUnconfirmed,
        DashboardChipTone.idle,
      ),
    };
  }

  Widget? _address(BuildContext context) {
    final self = status?.self;
    final ipv4 = tailscaleAddressOf(self);
    final usable = phase == TailscalePhase.connected;
    if (ipv4 == null || !(usable || phase == TailscalePhase.needsReauth)) {
      return null;
    }
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final ipv6 = tailscaleIpv6Of(self);
    final muted = usable ? colorScheme.onSurface : colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Row(
          spacing: 4,
          children: [
            Flexible(
              child: Text(
                ipv4,
                maxLines: 1,
                style: AppTextStyle.title1
                    .of(context, emphasized: true)
                    .toTabular
                    .copyWith(color: muted),
              ),
            ),
            if (usable)
              IconButton(
                tooltip: appLocalizations.tsCopyAddress,
                onPressed: () => actions.onCopy(ipv4),
                icon: const GlyphIcon(AppGlyphs.copy, size: 18),
              ),
          ],
        ),
        if (ipv6 != null)
          Semantics(
            button: usable,
            label: usable ? '${appLocalizations.tsCopyAddress} $ipv6' : null,
            child: GestureDetector(
              onTap: usable ? () => actions.onCopy(ipv6) : null,
              child: Text(
                ipv6,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.footnote
                    .of(context)
                    .toTabular
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }

  Widget? _meta(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final status = this.status;
    final controlHost = tailscaleControlHost(node.controlUrl);
    final hostname = status?.self?.hostName.takeFirstValid([node.hostname]);
    final items = <Widget>[
      if (hostname != null && hostname.isNotEmpty)
        TailscaleMetaItem(
          label: appLocalizations.tsDeviceName,
          value: hostname,
        ),
      ...switch (phase) {
        TailscalePhase.connected ||
        TailscalePhase.needsApproval ||
        TailscalePhase.needsReauth ||
        TailscalePhase.stopped => _identity(context, status),
        TailscalePhase.signedOut ||
        TailscalePhase.preparing ||
        TailscalePhase.waitingBrowser => [
          TailscaleMetaItem(
            label: appLocalizations.tsAccount,
            value: appLocalizations.tsStateSignedOut,
            muted: true,
          ),
          TailscaleMetaItem(
            label: appLocalizations.tsNetwork,
            value: appLocalizations.tsAfterLogin,
            muted: true,
          ),
        ],
        TailscalePhase.loadFailed => [
          TailscaleMetaItem(
            label: appLocalizations.tsAccount,
            value: appLocalizations.tsIdentityFailed,
            muted: true,
          ),
        ],
        TailscalePhase.starting ||
        TailscalePhase.startFailed ||
        TailscalePhase.unconfirmed => const <Widget>[],
      },
      if (controlHost.isNotEmpty)
        TailscaleMetaItem(
          label: appLocalizations.tsControlServer,
          value: controlHost,
        ),
    ];
    if (items.isEmpty) {
      return null;
    }
    return Wrap(spacing: 28, runSpacing: 10, children: items);
  }

  List<Widget> _identity(BuildContext context, TailscaleStatus? status) {
    final appLocalizations = context.appLocalizations;
    final user = status?.loginUser;
    final userName = user == null ? '' : tailscaleUserName(user);
    final tailnet = status?.tailnet?.name ?? '';
    return [
      if (user == null || userName.isEmpty)
        TailscaleMetaItem(
          label: appLocalizations.tsAccount,
          value: appLocalizations.tsAccountMissing,
          muted: true,
        )
      else
        TailscaleMetaItem(
          label: appLocalizations.tsAccount,
          value: userName,
          tooltip: tailscaleUserDescription(user),
          leading: TailscaleAvatar(
            name: user.displayName.takeFirstValid([userName]),
            pictureUrl: user.profilePicUrl,
            isMe: true,
          ),
        ),
      if (tailnet.isEmpty)
        TailscaleMetaItem(
          label: appLocalizations.tsNetwork,
          value: appLocalizations.tsNetworkMissing,
          muted: true,
        )
      else
        TailscaleMetaItem(label: appLocalizations.tsNetwork, value: tailnet),
    ];
  }

  Widget? _noticeBanner(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (notice) {
      null => null,
      TailscaleCardNotice.browserFailed => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsBrowserFailed,
        actionLabel: appLocalizations.tsReopenLogin,
        onAction: actions.onReopen,
      ),
      TailscaleCardNotice.urlRejected => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsUrlRejected,
        actionLabel: appLocalizations.tsGoToProfiles,
        onAction: actions.onGoToProfiles,
      ),
      TailscaleCardNotice.urlMissing => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsUrlMissing,
        actionLabel: appLocalizations.tsPrepareAgain,
        onAction: loggingIn ? null : actions.onLogin,
      ),
      TailscaleCardNotice.loginUnconfirmed => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsLoginUnconfirmed,
        actionLabel: appLocalizations.tsReadStatus,
        onAction: reading ? null : actions.onRead,
      ),
      TailscaleCardNotice.nodeChanged => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsNodeChanged,
      ),
      TailscaleCardNotice.logoutFailed => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsLogoutFailed,
        actionLabel: appLocalizations.tsReadStatus,
        onAction: reading ? null : actions.onRead,
      ),
      TailscaleCardNotice.logoutUnknown => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsLogoutUnknown,
        actionLabel: appLocalizations.tsReadStatus,
        onAction: reading ? null : actions.onRead,
      ),
    };
  }

  Widget? _stateBanner(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (phase) {
      TailscalePhase.loadFailed => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsLoadFailedTip,
      ),
      TailscalePhase.preparing => TailscaleBanner(
        level: TailscaleBannerLevel.info,
        text: appLocalizations.tsPreparingTip,
      ),
      TailscalePhase.starting => null,
      TailscalePhase.signedOut => TailscaleBanner(
        level: TailscaleBannerLevel.info,
        text: node.loggedOut
            ? appLocalizations.tsLoggedOutTip
            : appLocalizations.tsSignedOutTip,
      ),
      TailscalePhase.waitingBrowser => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsWaitingBrowserTip,
      ),
      TailscalePhase.needsApproval => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        glyph: AppGlyphs.lock,
        text: appLocalizations.tsNeedsApprovalTip,
      ),
      TailscalePhase.connected => switch (tailscaleExpiryReminder(
        status,
        now,
      )) {
        final expiry? => TailscaleBanner(
          level: TailscaleBannerLevel.warn,
          glyph: AppGlyphs.key,
          text: appLocalizations.tsExpiryTip(
            tailscaleDateTime(expiry.toLocal()),
          ),
          actionLabel: appLocalizations.tsRelogin,
          onAction: loggingIn ? null : actions.onRelogin,
        ),
        null => null,
      },
      TailscalePhase.needsReauth => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        glyph: AppGlyphs.key,
        text: appLocalizations.tsNeedsReauthTip,
      ),
      TailscalePhase.stopped => TailscaleBanner(
        level: TailscaleBannerLevel.info,
        text: appLocalizations.tsStoppedTip,
      ),
      TailscalePhase.startFailed => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsStartFailedTip,
      ),
      TailscalePhase.unconfirmed => TailscaleBanner(
        level: TailscaleBannerLevel.info,
        text: appLocalizations.tsUnconfirmedTip,
      ),
    };
  }

  List<Widget> _actions(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final read = TonalButton(
      glyph: AppGlyphs.refresh,
      label: appLocalizations.tsReadStatus,
      onPressed: reading ? null : actions.onRead,
    );
    if (_legacyOffers) {
      return tailscaleLegacyButtons(
        context,
        view: legacyView,
        migrating: legacyState.migrating,
        loggingIn: loggingIn,
        reading: reading,
        onMigrate: actions.onMigrate,
        onLogin: actions.onLogin,
        onRecheck: actions.onRecheckLegacy,
      );
    }
    if (legacyView == TailscaleLegacyView.archiveError) {
      return [
        _filled(
          context,
          label: appLocalizations.tsRelogin,
          onPressed: actions.onLogin,
        ),
      ];
    }
    if (legacyView == TailscaleLegacyView.migrated) {
      return const [];
    }
    return switch (phase) {
      TailscalePhase.loadFailed ||
      TailscalePhase.needsApproval ||
      TailscalePhase.stopped ||
      TailscalePhase.unconfirmed => [read],
      TailscalePhase.preparing => [
        FilledButton.icon(
          onPressed: null,
          icon: tailscaleBusyIcon(context),
          label: Text(appLocalizations.tsStatePreparing),
        ),
      ],
      TailscalePhase.starting => const [],
      TailscalePhase.signedOut => [
        _filled(
          context,
          label: appLocalizations.tsLogin,
          onPressed: actions.onLogin,
        ),
      ],
      TailscalePhase.waitingBrowser => [
        _filled(
          context,
          label: appLocalizations.tsReopenLogin,
          onPressed: actions.onReopen,
        ),
      ],
      TailscalePhase.connected => [
        if (loggingOut)
          FilledButton.icon(
            onPressed: null,
            icon: tailscaleBusyIcon(context),
            label: Text(appLocalizations.tsLoggingOut),
          )
        else
          TonalButton(
            label: appLocalizations.tsLogout,
            onPressed: actions.onLogout,
          ),
      ],
      TailscalePhase.needsReauth => [
        _filled(
          context,
          label: appLocalizations.tsRelogin,
          onPressed: actions.onLogin,
        ),
      ],
      TailscalePhase.startFailed => [
        FilledButton.icon(
          onPressed: restarting ? null : actions.onRetryStart,
          icon: restarting
              ? tailscaleBusyIcon(context)
              : const GlyphIcon(AppGlyphs.refresh, fill: 1),
          label: Text(appLocalizations.retry),
        ),
        read,
      ],
    };
  }

  Widget _filled(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: loggingIn ? null : onPressed,
      icon: loggingIn
          ? tailscaleBusyIcon(context)
          : const GlyphIcon(AppGlyphs.openExternal, fill: 1),
      label: Text(label),
    );
  }
}
