import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'state.dart';
import 'widgets.dart';

/// Why a settings card takes no change now; null when it does.
String? tailscaleSettingsLock(
  BuildContext context, {
  required TailscaleNode node,
  required TailscalePhase phase,
  TailscaleAttachState attach = TailscaleAttachState.none,
}) {
  final appLocalizations = context.appLocalizations;
  if (phase == TailscalePhase.connected && node.managed && !node.attached) {
    // Locked until the account is in the profile, design.md §12.2.
    return switch (attach) {
      TailscaleAttachState.unknown => appLocalizations.tsAttachUnknownLockTip,
      TailscaleAttachState.failed || TailscaleAttachState.duplicate => null,
      _ => appLocalizations.tsAttachLockTip,
    };
  }
  if (phase == TailscalePhase.connected) {
    return node.overridable ? null : appLocalizations.tsOverrideAmbiguous;
  }
  return switch (phase) {
    TailscalePhase.signedOut ||
    TailscalePhase.preparing ||
    TailscalePhase.waitingBrowser ||
    TailscalePhase.needsReauth => appLocalizations.tsChangeAfterSignIn,
    _ => appLocalizations.tsAfterConnectSelectable,
  };
}

String? tailscaleSourceLabel(
  BuildContext context,
  TailscaleSettingSource source,
) {
  final appLocalizations = context.appLocalizations;
  return switch (source) {
    TailscaleSettingSource.subscription => appLocalizations.tsFromSubscription,
    TailscaleSettingSource.profile => appLocalizations.tsFromProfile,
    TailscaleSettingSource.provider => appLocalizations.tsFromProvider,
    TailscaleSettingSource.override => appLocalizations.tsFromLocal,
    TailscaleSettingSource.coreDefault => null,
  };
}

/// The small inset tag after a secondary line, design.md §9.
class TailscaleTag extends StatelessWidget {
  const TailscaleTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: ShapeDecoration(
        color: DashboardColors.of(context).tone2,
        shape: AppShape.all(AppCorner.full),
      ),
      // As wide as its label, also in a Wrap that offers the full row.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: AppTextStyle.caption2
              .of(context, emphasized: true)
              .copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _CardFootnote extends StatelessWidget {
  const _CardFootnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyle.caption1
          .of(context)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
  }
}

/// A settings block row: a title over a secondary line, then [trailing].
class _SettingBlock extends StatelessWidget {
  const _SettingBlock({
    required this.title,
    this.subtitle,
    this.detail,
    this.tag,
    this.trailing,
    this.onTap,
    this.dimmed = false,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;

  /// A further line under [subtitle], without a tag.
  final String? detail;
  final String? tag;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dimmed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final tag = this.tag;
    final subtitle = this.subtitle;
    final detail = this.detail;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardText.rowTitle(context).copyWith(
                    color: dimmed ? colorScheme.onSurfaceVariant : null,
                  ),
                ),
                if (subtitle != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(subtitle, style: DashboardText.label(context)),
                      if (tag != null) TailscaleTag(label: tag),
                    ],
                  ),
                if (detail != null)
                  Text(detail, style: DashboardText.label(context)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticLabel,
      child: DashboardBlock(
        radius: AppCorner.md,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class TailscaleExitCard extends StatelessWidget {
  const TailscaleExitCard({
    super.key,
    required this.node,
    required this.status,
    required this.phase,
    required this.panel,
    required this.onSelect,
    required this.onReadSettings,
    this.onRetry,
    this.savedExitName,
    this.attach = TailscaleAttachState.none,
  });

  final TailscaleAttachState attach;
  final TailscaleNode node;
  final TailscaleStatus? status;
  final TailscalePhase phase;
  final TailscalePanelNode panel;

  /// The name kept with the saved exit node, for display only.
  final String? savedExitName;

  /// Null is the explicit choice of no exit node.
  final ValueChanged<TailscalePeer?> onSelect;
  final VoidCallback onReadSettings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final lock = tailscaleSettingsLock(
      context,
      node: node,
      phase: phase,
      attach: attach,
    );
    final current = tailscaleCurrentExitPeer(node, status);
    final currentValue = tailscaleExitValue(node, status);
    final hasExit = current != null || currentValue != null;
    final candidates =
        [
          for (final peer in status?.peers ?? const <TailscalePeer>[])
            if (peer.exitNodeOption) peer,
        ]..sort((a, b) {
          if (a.online != b.online) {
            return a.online ? -1 : 1;
          }
          return (a.hostName).toLowerCase().compareTo(b.hostName.toLowerCase());
        });
    final stale = panel.readFailed;
    final applying = panel.applyingExit;
    final source = tailscaleSourceLabel(context, node.settings.exitNode.source);
    final Widget block;
    if (lock != null && phase == TailscalePhase.connected) {
      // The running node's exit is real; only changing it is refused.
      final title = hasExit
          ? _exitName(context, current, currentValue)
          : appLocalizations.tsNoExitNode;
      block = _SettingBlock(
        title: title,
        subtitle: lock,
        dimmed: true,
        semanticLabel: '${appLocalizations.tsExitNode}，$title，$lock',
      );
    } else if (lock != null) {
      final saved = node.settings.exitNode;
      String? savedLine;
      // Only a saved choice the Core reports is named, and never as live.
      if (saved.source == TailscaleSettingSource.override) {
        final peer = saved.value.isEmpty
            ? null
            : status?.peers.firstWhereOrNull(
                (peer) =>
                    peer.addresses.contains(saved.value) ||
                    peer.id == saved.value,
              );
        savedLine = appLocalizations.tsSavedValue(
          saved.value.isEmpty
              ? appLocalizations.tsNoExitNode
              : peer != null
              ? tailscaleDeviceName(context, peer)
              : savedExitName ?? saved.value,
        );
      }
      block = _SettingBlock(
        title: lock,
        subtitle: savedLine,
        dimmed: true,
        semanticLabel: [
          appLocalizations.tsExitNode,
          lock,
          ?savedLine,
        ].join('，'),
      );
    } else {
      final canChoose = !stale && candidates.isNotEmpty;
      final canTurnOff = hasExit;
      final String title;
      final String subtitle;
      var dimmed = false;
      if (hasExit) {
        title = _exitName(context, current, currentValue);
        subtitle = current == null
            ? appLocalizations.tsStatusUnknown
            : [
                ?tailscaleAddressOf(current),
                current.online
                    ? appLocalizations.tsOnline
                    : appLocalizations.tsOffline,
              ].join(' · ');
      } else if (candidates.isEmpty && !stale) {
        title = appLocalizations.tsNoExitCandidates;
        subtitle = appLocalizations.tsNoExitCandidatesTip;
        dimmed = true;
      } else {
        title = appLocalizations.tsNoExitNode;
        subtitle = appLocalizations.tsNoExitNodeTip;
      }
      final menuItems = [
        PopupMenuItem(
          label: appLocalizations.tsNoExitNode,
          checked: !hasExit,
          section: PopupMenuSection(title: appLocalizations.tsChooseExitNode),
          onPressed: hasExit ? () => onSelect(null) : null,
        ),
        if (canChoose)
          for (final (index, peer) in candidates.indexed)
            PopupMenuItem(
              label: [
                tailscaleDeviceName(context, peer),
                ?tailscaleAddressOf(peer),
              ].join(' · '),
              subtitle: peer.online
                  ? null
                  : appLocalizations.tsOfflineNotSelectable,
              checked: current?.id == peer.id,
              section: index == 0 ? const PopupMenuSection() : null,
              onPressed: peer.online && current?.id != peer.id
                  ? () => onSelect(peer)
                  : null,
            ),
      ];
      final interactive = !applying && (canChoose || canTurnOff);
      final staleSubtitle = stale ? appLocalizations.tsExitStale : null;
      block = PopupAnchor(
        targetBuilder: (open) => _SettingBlock(
          title: title,
          subtitle: applying
              ? appLocalizations.tsExitApplying
              : staleSubtitle ?? subtitle,
          tag: applying || stale ? null : source,
          dimmed: dimmed,
          semanticLabel: '${appLocalizations.tsExitNode}，$title',
          onTap: interactive ? open : null,
          trailing: applying
              ? const ActivityIndicator(size: 16)
              : interactive
              ? GlyphIcon(
                  AppGlyphs.chevronDown,
                  size: 16,
                  color: context.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        popupBuilder: (_) => PopupMenu(items: menuItems, maxVisibleItems: 8),
      );
    }
    return TailscaleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.vpn,
            title: appLocalizations.tsExitNode,
          ),
          block,
          ?_noticeBanner(context),
          _CardFootnote(appLocalizations.tsExitNodeTip),
          if (lock == null &&
              node.settings.exitNode.source == TailscaleSettingSource.override)
            _CardFootnote(appLocalizations.tsOverrideTip),
        ],
      ),
    );
  }

  String _exitName(
    BuildContext context,
    TailscalePeer? current,
    String? value,
  ) {
    if (current != null) {
      return tailscaleDeviceName(context, current);
    }
    return value ?? context.appLocalizations.tsNoExitNode;
  }

  Widget? _noticeBanner(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (panel.exitNotice) {
      null || TailscaleSettingNotice.updated => null,
      TailscaleSettingNotice.saved => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsSettingsSaved,
        actionLabel: appLocalizations.tsReadSettings,
        onAction: panel.reading ? null : onReadSettings,
      ),
      TailscaleSettingNotice.applyFailed => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsSettingsApplyFailed,
        actionLabel: appLocalizations.tsReadSettings,
        onAction: panel.reading ? null : onReadSettings,
      ),
      TailscaleSettingNotice.failed => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsExitFailed,
        actionLabel: onRetry == null ? null : appLocalizations.retry,
        onAction: onRetry,
      ),
      TailscaleSettingNotice.unknown => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsExitUnknown,
        actionLabel: appLocalizations.tsReadSettings,
        onAction: panel.reading ? null : onReadSettings,
      ),
    };
  }
}

class TailscaleRoutesCard extends StatelessWidget {
  const TailscaleRoutesCard({
    super.key,
    required this.node,
    required this.status,
    required this.phase,
    required this.panel,
    required this.onChanged,
    required this.onReadSettings,
    this.onRetry,
    this.attach = TailscaleAttachState.none,
  });

  final TailscaleAttachState attach;
  final TailscaleNode node;
  final TailscaleStatus? status;
  final TailscalePhase phase;
  final TailscalePanelNode panel;
  final ValueChanged<bool> onChanged;
  final VoidCallback onReadSettings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final lock = tailscaleSettingsLock(
      context,
      node: node,
      phase: phase,
      attach: attach,
    );
    final value = tailscaleAcceptsRoutes(node, status);
    final applying = panel.applyingRoutes;
    final enabled = lock == null && !applying;
    final source = tailscaleSourceLabel(
      context,
      node.settings.acceptRoutes.source,
    );
    final subtitle =
        lock ??
        (applying
            ? appLocalizations.tsRoutesApplying
            : value
            ? appLocalizations.tsOn
            : appLocalizations.tsOff);
    final saved = node.settings.acceptRoutes;
    final savedLine =
        lock != null &&
            phase != TailscalePhase.connected &&
            saved.source == TailscaleSettingSource.override
        ? appLocalizations.tsSavedValue(
            saved.value ? appLocalizations.tsOn : appLocalizations.tsOff,
          )
        : null;
    return TailscaleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.split,
            title: appLocalizations.tsSubnetRoutes,
          ),
          _SettingBlock(
            title: appLocalizations.tsAcceptRoutes,
            subtitle: subtitle,
            detail: savedLine,
            tag: lock == null && !applying ? source : null,
            dimmed: lock != null,
            semanticLabel: appLocalizations.tsAcceptRoutes,
            onTap: enabled ? () => onChanged(!value) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                if (applying) const ActivityIndicator(size: 16),
                DashboardSwitch(
                  value:
                      (lock == null || phase == TailscalePhase.connected) &&
                      value,
                  onChanged: enabled ? onChanged : null,
                  semanticLabel: appLocalizations.tsAcceptRoutes,
                  fadeWhenDisabled: true,
                ),
              ],
            ),
          ),
          ?_noticeBanner(context),
          _CardFootnote(appLocalizations.tsAcceptRoutesTip),
          if (lock == null &&
              node.settings.acceptRoutes.source ==
                  TailscaleSettingSource.override)
            _CardFootnote(appLocalizations.tsOverrideTip),
        ],
      ),
    );
  }

  Widget? _noticeBanner(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (panel.routesNotice) {
      null || TailscaleSettingNotice.updated => null,
      TailscaleSettingNotice.saved => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsSettingsSaved,
        actionLabel: appLocalizations.tsReadSettings,
        onAction: panel.reading ? null : onReadSettings,
      ),
      TailscaleSettingNotice.applyFailed => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsSettingsApplyFailed,
        actionLabel: appLocalizations.tsReadSettings,
        onAction: panel.reading ? null : onReadSettings,
      ),
      TailscaleSettingNotice.failed => TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsRoutesFailed,
        actionLabel: onRetry == null ? null : appLocalizations.retry,
        onAction: onRetry,
      ),
      TailscaleSettingNotice.unknown => TailscaleBanner(
        level: TailscaleBannerLevel.warn,
        text: appLocalizations.tsRoutesUnknown,
        actionLabel: appLocalizations.tsReadSettings,
        onAction: panel.reading ? null : onReadSettings,
      ),
    };
  }
}

/// Goes to the existing rules entry; the panel never edits rules itself.
/// [lines] say what the shown node's rules are, per its source and state.
class TailscaleRulesCard extends StatelessWidget {
  const TailscaleRulesCard({
    super.key,
    required this.onGoToRules,
    this.lines = const [],
  });

  final VoidCallback onGoToRules;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final body = lines.isEmpty ? [appLocalizations.tsBoundaryTip] : lines;
    return TailscaleCard(
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                DashboardCardHeader(
                  glyph: AppGlyphs.rules,
                  title: appLocalizations.rules,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    for (final line in body)
                      Text(
                        line,
                        style: AppTextStyle.footnote
                            .of(context)
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ],
            ),
          ),
          TonalButton(
            label: appLocalizations.tsGoToRules,
            trailingGlyph: AppGlyphs.chevronForward,
            onPressed: onGoToRules,
          ),
        ],
      ),
    );
  }
}
