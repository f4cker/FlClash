import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'state.dart';
import 'widgets.dart';

/// The account the legacy login names, or the doc's text when it is missing.
String tailscaleLegacyAccount(
  BuildContext context,
  TailscaleLegacyIdentity legacy,
) {
  if (legacy.loginName.isNotEmpty) {
    return legacy.loginName;
  }
  if (legacy.displayName.isNotEmpty) {
    return legacy.displayName;
  }
  return context.appLocalizations.tsLegacyAccountUnconfirmed;
}

/// The legacy login block of the device card, legacy-login-copy.md.
class TailscaleLegacyBlock extends StatelessWidget {
  const TailscaleLegacyBlock({
    super.key,
    required this.node,
    required this.view,
    required this.state,
    required this.reading,
    required this.onRecheck,
    required this.onRead,
  });

  final TailscaleNode node;
  final TailscaleLegacyView view;
  final TailscaleLegacyState state;
  final bool reading;

  /// Settles a pending migration outcome; never migrates again.
  final VoidCallback onRecheck;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final legacy = node.legacy;
    return switch (view) {
      TailscaleLegacyView.hidden => const SizedBox.shrink(),
      TailscaleLegacyView.offer ||
      TailscaleLegacyView.failed ||
      TailscaleLegacyView.changed => _OfferBlock(
        node: node,
        legacy: legacy,
        notice: switch (view) {
          TailscaleLegacyView.failed => TailscaleBanner(
            level: TailscaleBannerLevel.error,
            text: appLocalizations.tsLegacyFailed,
          ),
          TailscaleLegacyView.changed => TailscaleBanner(
            level: TailscaleBannerLevel.warn,
            text: appLocalizations.tsLegacyChanged,
          ),
          _ => null,
        },
      ),
      TailscaleLegacyView.unknown => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: _unknownText(context),
        actionLabel: appLocalizations.tsReadStatus,
        onAction: reading ? null : onRecheck,
      ),
      TailscaleLegacyView.archiveError => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: _archiveErrorText(context),
        actionLabel: appLocalizations.tsReadStatus,
        onAction: reading ? null : onRecheck,
      ),
      TailscaleLegacyView.migrated => TailscaleBanner(
        level: TailscaleBannerLevel.info,
        glyph: AppGlyphs.key,
        text: appLocalizations.tsLegacyMigrated,
      ),
      TailscaleLegacyView.hasIdentity => TailscaleBanner(
        level: TailscaleBannerLevel.info,
        text: appLocalizations.tsLegacyHasIdentity,
      ),
      TailscaleLegacyView.controlMismatch => TailscaleBanner(
        level: TailscaleBannerLevel.info,
        text: appLocalizations.tsLegacyControlMismatch,
      ),
      TailscaleLegacyView.inUse => TailscaleBanner(
        level: TailscaleBannerLevel.info,
        text: appLocalizations.tsLegacyInUse,
        actionLabel: appLocalizations.tsReadStatus,
        onAction: reading ? null : onRead,
      ),
      TailscaleLegacyView.migratedElsewhere => TailscaleBanner(
        level: TailscaleBannerLevel.info,
        text: appLocalizations.tsLegacyMigratedElsewhere,
      ),
      TailscaleLegacyView.unreadable => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsLegacyUnreadable,
        actionLabel: appLocalizations.tsReadStatus,
        onAction: reading ? null : onRead,
      ),
      TailscaleLegacyView.unconfirmed => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsLegacyUnconfirmed,
        actionLabel: appLocalizations.tsReadStatus,
        onAction: reading ? null : onRead,
      ),
    };
  }

  /// "原记录仍保留" only while nothing says the archive changed.
  String _unknownText(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    if (state.archiveIntact) {
      return appLocalizations.tsLegacyUnknown;
    }
    final cause = state.archiveError ?? '';
    return cause.isEmpty
        ? appLocalizations.tsLegacyUnknownArchiveError
        : appLocalizations.tsLegacyUnknownArchiveErrorOf(cause);
  }

  String _archiveErrorText(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final cause = state.archiveError ?? '';
    return cause.isEmpty
        ? appLocalizations.tsLegacyArchiveError
        : appLocalizations.tsLegacyArchiveErrorOf(cause);
  }
}

class _OfferBlock extends StatelessWidget {
  const _OfferBlock({
    required this.node,
    required this.legacy,
    required this.notice,
  });

  final TailscaleNode node;
  final TailscaleLegacyIdentity? legacy;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final legacy = this.legacy;
    final caption = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final controlHost = tailscaleControlHost(
      legacy?.controlUrl.takeFirstValid([node.controlUrl]) ?? node.controlUrl,
    );
    final account = legacy == null
        ? appLocalizations.tsLegacyAccountUnconfirmed
        : tailscaleLegacyAccount(context, legacy);
    final known =
        legacy != null &&
        (legacy.loginName.isNotEmpty || legacy.displayName.isNotEmpty);
    final notice = this.notice;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: DashboardColors.of(context).tone,
        shape: AppShape.all(AppCorner.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 10,
              children: [
                GlyphIcon(
                  AppGlyphs.key,
                  size: 16,
                  color: colorScheme.onSurface,
                ),
                Expanded(
                  child: Text(
                    appLocalizations.tsLegacyTitle,
                    style: AppTextStyle.footnote.of(context, emphasized: true),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Semantics(
                    label:
                        '${appLocalizations.tsAccount} $account，'
                        '${appLocalizations.tsControlServer} $controlHost',
                    excludeSemantics: true,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (known)
                          TailscaleAvatar(
                            name: legacy.displayName.takeFirstValid([
                              legacy.loginName,
                            ]),
                          ),
                        Text(
                          account,
                          style: AppTextStyle.footnote
                              .of(context, emphasized: known)
                              .copyWith(
                                color: known
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (controlHost.isNotEmpty)
                          Text('· $controlHost', style: caption),
                      ],
                    ),
                  ),
                  Text(appLocalizations.tsLegacyBody, style: caption),
                  if (node.authKey)
                    Text(appLocalizations.tsLegacyAuthKeyNote, style: caption),
                ],
              ),
            ),
            ?notice,
          ],
        ),
      ),
    );
  }
}

/// The right column while the block offers the migration: one filled
/// button, and 重新登录 beside it; only 重新读取状态 while the outcome is
/// pending, as nothing may migrate or log in again until a read settles it.
List<Widget> tailscaleLegacyButtons(
  BuildContext context, {
  required TailscaleLegacyView view,
  required bool migrating,
  required bool loggingIn,
  required bool reading,
  required VoidCallback onMigrate,
  required VoidCallback onLogin,
  required VoidCallback onRecheck,
}) {
  final appLocalizations = context.appLocalizations;
  if (view == TailscaleLegacyView.unknown) {
    return [
      TonalButton(
        glyph: AppGlyphs.refresh,
        label: appLocalizations.tsReadStatus,
        onPressed: reading || migrating ? null : onRecheck,
      ),
    ];
  }
  final busy = migrating || loggingIn;
  return [
    FilledButton.icon(
      onPressed: busy ? null : onMigrate,
      icon: migrating
          ? tailscaleBusyIcon(context)
          : const GlyphIcon(AppGlyphs.key, fill: 1),
      label: Text(
        migrating
            ? appLocalizations.tsLegacyMigrating
            : view == TailscaleLegacyView.failed
            ? appLocalizations.tsLegacyRetry
            : appLocalizations.tsLegacyMigrate,
      ),
    ),
    TonalButton(
      glyph: AppGlyphs.openExternal,
      label: appLocalizations.tsRelogin,
      onPressed: busy ? null : onLogin,
    ),
  ];
}
