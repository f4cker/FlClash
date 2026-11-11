import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'state.dart';
import 'widgets.dart';

/// Search shows once the list is this long, design.md §3.5.
const tailscaleSearchThreshold = 8;

/// Below this the 系统 column goes first; 归属 then gives up width.
const _systemMinWidth = 600.0;
const _columnGap = 12.0;
const _copyWidth = 40.0;

/// One width definition for the header and every row, so they never drift
/// apart (user msg 1965). Address and status are as wide as their widest
/// text, so neither is ever cut.
class _TableLayout {
  const _TableLayout({
    required this.showSystem,
    required this.addressWidth,
    required this.statusWidth,
  });

  final bool showSystem;
  final double addressWidth;
  final double statusWidth;
}

double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width.ceilToDouble();
  painter.dispose();
  return width;
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.layout,
    required this.name,
    required this.address,
    required this.owner,
    required this.system,
    required this.status,
    required this.copy,
    this.minHeight = 52,
  });

  final _TableLayout layout;
  final Widget name;
  final Widget address;
  final Widget owner;
  final Widget system;
  final Widget status;
  final Widget copy;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Row(
        spacing: _columnGap,
        children: [
          Expanded(flex: 200, child: name),
          SizedBox(width: layout.addressWidth, child: address),
          Expanded(flex: 160, child: owner),
          if (layout.showSystem) Expanded(flex: 80, child: system),
          SizedBox(width: layout.statusWidth, child: status),
          SizedBox(width: _copyWidth, child: copy),
        ],
      ),
    );
  }
}

/// The conflict tag of [peer]: 地址冲突 while one of its addresses awaits a
/// choice, 归属冲突 while its name does.
String? tailscaleConflictTag(
  BuildContext context,
  TailscaleRoutes routes,
  TailscalePeer peer,
) {
  final appLocalizations = context.appLocalizations;
  final dnsName = peer.dnsName.endsWith('.')
      ? peer.dnsName.substring(0, peer.dnsName.length - 1)
      : peer.dnsName;
  for (final target in routes.pending) {
    final value = target.target.value;
    if (target.target.kind == tailscaleTargetIp &&
        peer.addresses.any((address) => address.split('/').first == value)) {
      return appLocalizations.tsAddressConflict;
    }
    if (target.target.kind != tailscaleTargetIp &&
        dnsName.isNotEmpty &&
        dnsName.toLowerCase() == value.toLowerCase()) {
      return appLocalizations.tsRoutingConflict;
    }
  }
  return null;
}

/// The owner filter's label for a group: real names, with the account when
/// two groups share a name, so users are never merged by name.
String tailscaleOwnerLabel(
  BuildContext context,
  TailscaleOwner owner, {
  Set<String> sharedNames = const {},
}) {
  final appLocalizations = context.appLocalizations;
  return switch (owner) {
    TailscaleOwnerMe() => appLocalizations.tsOwnerMine,
    TailscaleOwnerUser(:final user) => () {
      final name = user.displayName.takeFirstValid([user.loginName]);
      if (name.isEmpty) {
        return appLocalizations.tsOwnerUnknown;
      }
      return sharedNames.contains(name) && user.loginName.isNotEmpty
          ? '$name（${user.loginName}）'
          : name;
    }(),
    TailscaleOwnerTags(:final tags) => tags.join(', '),
    TailscaleOwnerUnknown() => appLocalizations.tsOwnerUnknown,
  };
}

class TailscaleDeviceSection extends StatelessWidget {
  const TailscaleDeviceSection({
    super.key,
    required this.status,
    required this.readFailed,
    required this.reading,
    required this.ownerKey,
    required this.query,
    required this.onOwnerChanged,
    required this.onQueryChanged,
    required this.searchController,
    required this.onRefresh,
    required this.onCopy,
    this.conflictOf,
  });

  /// The conflict tag of a device, when its routing has one.
  final String? Function(TailscalePeer peer)? conflictOf;
  final TailscaleStatus? status;
  final bool readFailed;
  final bool reading;
  final String? ownerKey;
  final String query;
  final ValueChanged<String?> onOwnerChanged;
  final ValueChanged<String> onQueryChanged;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final status = this.status;
    final devices = status == null
        ? const <TailscaleDevice>[]
        : tailscaleDevicesOf(status);
    final groups = tailscaleOwnerGroupsOf(devices);
    final showFilter = groups.length >= 2;
    final ownerKey =
        showFilter && groups.any((g) => g.owner.filterKey == this.ownerKey)
        ? this.ownerKey
        : null;
    final shown = filterTailscaleDevices(
      devices,
      ownerKey: ownerKey,
      query: query,
    );
    final showSearch = devices.length >= tailscaleSearchThreshold;
    final names = <String, int>{};
    for (final group in groups) {
      if (group.owner case TailscaleOwnerUser(:final user)) {
        final name = user.displayName.takeFirstValid([user.loginName]);
        names[name] = (names[name] ?? 0) + 1;
      }
    }
    final sharedNames = {
      for (final entry in names.entries)
        if (entry.value > 1) entry.key,
    };
    final header = Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          appLocalizations.tsDevices,
          style: AppTextStyle.title3.of(context, emphasized: true),
        ),
        if (showFilter)
          Semantics(
            label: appLocalizations.tsOwnerFilter,
            container: true,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  appLocalizations.tsOwnerFilter,
                  style: DashboardText.label(context),
                ),
                Chip(
                  label: '${appLocalizations.tsOwnerAll} ${devices.length}',
                  selected: ownerKey == null,
                  onPressed: () => onOwnerChanged(null),
                ),
                for (final group in groups)
                  Tooltip(
                    message: switch (group.owner) {
                      TailscaleOwnerMe(:final user) ||
                      TailscaleOwnerUser(
                        :final user,
                      ) => tailscaleUserDescription(user),
                      _ => '',
                    },
                    child: Chip(
                      label:
                          '${tailscaleOwnerLabel(context, group.owner, sharedNames: sharedNames)} ${group.count}',
                      selected: ownerKey == group.owner.filterKey,
                      onPressed: () => onOwnerChanged(group.owner.filterKey),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    final Widget body;
    if (status == null && readFailed) {
      body = TailscaleBanner(
        level: TailscaleBannerLevel.error,
        text: appLocalizations.tsDevicesFailed,
        actionLabel: appLocalizations.tsRefreshDevices,
        onAction: reading ? null : onRefresh,
      );
    } else if (devices.isEmpty) {
      body = _Empty(
        title: appLocalizations.tsDevicesEmpty,
        description: appLocalizations.tsDevicesEmptyTip,
      );
    } else if (shown.isEmpty) {
      body = ownerKey != null
          ? _Empty(
              title: query.trim().isEmpty
                  ? appLocalizations.tsOwnerFilterEmpty
                  : appLocalizations.tsFilterEmpty,
              actionLabel: appLocalizations.tsClearOwnerFilter,
              onAction: () => onOwnerChanged(null),
            )
          : _Empty(title: appLocalizations.tsSearchEmpty);
    } else {
      body = _Table(devices: shown, onCopy: onCopy, conflictOf: conflictOf);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            // Centred on the title and owner chips, not on the scope line.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 16,
              children: [
                Expanded(child: header),
                if (showSearch)
                  SizedBox(
                    width: 220,
                    child: SearchField(
                      controller: searchController,
                      height: 34,
                      fill: DashboardColors.of(context).card,
                      style: AppTextStyle.footnote.of(context),
                      hintText: appLocalizations.tsSearchHint,
                      onChanged: onQueryChanged,
                    ),
                  ),
              ],
            ),
            Text(
              appLocalizations.tsDevicesScope,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        if (status != null && readFailed)
          TailscaleBanner(
            level: TailscaleBannerLevel.warn,
            text: appLocalizations.tsDevicesStale,
            actionLabel: appLocalizations.tsRefreshDevices,
            onAction: reading ? null : onRefresh,
          ),
        if (devices.isNotEmpty)
          Text(
            appLocalizations.tsDevicesShown(shown.length),
            style: DashboardText.label(context),
          ),
        TailscaleCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: body,
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    final actionLabel = this.actionLabel;
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyle.headline.of(context),
            ),
            if (description != null)
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            if (actionLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TonalButton(label: actionLabel, onPressed: onAction),
              ),
          ],
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.devices, required this.onCopy, this.conflictOf});

  final String? Function(TailscalePeer peer)? conflictOf;
  final List<TailscaleDevice> devices;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final headerStyle = AppTextStyle.caption1
        .of(context, emphasized: true)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    Widget headerCell(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: headerStyle,
    );
    final separator = Padding(
      padding: const EdgeInsetsDirectional.only(start: 40),
      child: Container(height: 0.5, color: context.colorScheme.outlineVariant),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final footnote = AppTextStyle.footnote.of(context);
        double widest(TextStyle style, Iterable<String> texts) =>
            texts.map((text) => _textWidth(context, text, style)).max;
        final layout = _TableLayout(
          showSystem: constraints.maxWidth >= _systemMinWidth,
          addressWidth: math.max(
            widest(headerStyle, [appLocalizations.tsAddress]),
            widest(footnote.toTabular, [
              appLocalizations.tsAddressMissing,
              for (final device in devices) ?device.address,
            ]),
          ),
          statusWidth: math.max(
            widest(headerStyle, [appLocalizations.tsStatus]),
            widest(footnote, [
              appLocalizations.tsOnline,
              appLocalizations.tsOffline,
            ]),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TableRow(
              layout: layout,
              minHeight: 36,
              name: headerCell(appLocalizations.tsDeviceName),
              address: headerCell(appLocalizations.tsAddress),
              owner: headerCell(appLocalizations.tsOwner),
              system: headerCell(appLocalizations.tsSystem),
              status: headerCell(appLocalizations.tsStatus),
              copy: const SizedBox.shrink(),
            ),
            for (final (index, device) in devices.indexed) ...[
              if (index > 0) separator,
              _DeviceRow(
                device: device,
                layout: layout,
                onCopy: onCopy,
                conflict: conflictOf?.call(device.peer),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.layout,
    required this.onCopy,
    this.conflict,
  });

  final String? conflict;
  final TailscaleDevice device;
  final _TableLayout layout;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final peer = device.peer;
    final address = device.address;
    final muted = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final name = device.name;
    final colors = DashboardColors.of(context);
    final nameCell = Row(
      spacing: 10,
      children: [
        SizedBox.square(
          dimension: 30,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.tone,
                    shape: AppShape.all(8),
                  ),
                  child: Center(
                    child: GlyphIcon(
                      AppGlyphs.devices,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: ShapeDecoration(
                    color: peer.online
                        ? colors.onOkContainer
                        : colorScheme.outline,
                    shape: CircleBorder(
                      side: BorderSide(color: colors.card, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // The name keeps the line; the tag goes under it when both don't fit.
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                name ?? appLocalizations.tsNameMissing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: name == null
                    ? muted
                    : AppTextStyle.subheadline.of(context, emphasized: true),
              ),
              if (peer.exitNodeOption)
                TailscaleTag(label: appLocalizations.tsExitCapable),
              if (conflict case final conflict?)
                TailscaleTag(label: conflict, warn: true),
            ],
          ),
        ),
      ],
    );
    final addressCell = Text(
      address ?? appLocalizations.tsAddressMissing,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: address == null
          ? muted
          : AppTextStyle.footnote.of(context).toTabular,
    );
    final ownerCell = _OwnerCell(device: device);
    final osCell = Text(
      peer.os.isEmpty
          ? appLocalizations.tsSystemMissing
          : tailscaleSystemName(peer.os),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: muted,
    );
    final statusCell = Text(
      peer.online ? appLocalizations.tsOnline : appLocalizations.tsOffline,
      maxLines: 1,
      style: peer.online ? AppTextStyle.footnote.of(context) : muted,
    );
    final copyCell = address == null
        ? const SizedBox.shrink()
        : IconButton(
            tooltip: appLocalizations.tsCopyAddress,
            onPressed: () => onCopy(address),
            icon: const GlyphIcon(AppGlyphs.copy, size: 16),
          );
    return Semantics(
      container: true,
      label: [
        name ?? appLocalizations.tsNameMissing,
        address ?? appLocalizations.tsAddressMissing,
        peer.online ? appLocalizations.tsOnline : appLocalizations.tsOffline,
      ].join('，'),
      child: _TableRow(
        layout: layout,
        name: nameCell,
        address: addressCell,
        owner: ownerCell,
        system: osCell,
        status: statusCell,
        copy: copyCell,
      ),
    );
  }
}

/// "我" for the signed-in user by stable ID only, the account kept in the
/// tooltip; other users by their real text; the sharer apart from the owner.
class _OwnerCell extends StatelessWidget {
  const _OwnerCell({required this.device});

  final TailscaleDevice device;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final muted = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final owner = device.owner;
    final Widget main;
    String? description;
    switch (owner) {
      case TailscaleOwnerMe(:final user):
        description = tailscaleUserDescription(user);
        main = Row(
          spacing: 6,
          children: [
            TailscaleAvatar(
              name: user.displayName.takeFirstValid([user.loginName]),
              pictureUrl: user.profilePicUrl,
              isMe: true,
              size: 18,
            ),
            Text(
              appLocalizations.tsOwnerMe,
              style: AppTextStyle.footnote.of(context),
            ),
          ],
        );
      case TailscaleOwnerUser(:final user):
        description = tailscaleUserDescription(user);
        final name = tailscaleUserName(user);
        main = Row(
          spacing: 6,
          children: [
            TailscaleAvatar(
              name: user.displayName.takeFirstValid([name]),
              pictureUrl: user.profilePicUrl,
              size: 18,
            ),
            Flexible(
              child: Text(
                name.isEmpty ? appLocalizations.tsOwnerUnknown : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.footnote.of(context),
              ),
            ),
          ],
        );
      case TailscaleOwnerTags(:final tags):
        description = tags.join(', ');
        main = Text(
          description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.footnote.of(context),
        );
      case TailscaleOwnerUnknown():
        main = Text(appLocalizations.tsOwnerUnknown, style: muted);
    }
    final sharer = device.sharer;
    final shareLine = sharer != null
        ? appLocalizations.tsSharedBy(
            sharer.displayName.takeFirstValid([sharer.loginName]),
          )
        : device.peer.shareeNode
        ? appLocalizations.tsShared
        : null;
    Widget cell = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        main,
        if (shareLine != null)
          Text(
            shareLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption2
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
      ],
    );
    if (description != null && description.isNotEmpty) {
      cell = Tooltip(
        message: description,
        child: Semantics(
          label: '${appLocalizations.tsOwner} $description',
          child: cell,
        ),
      );
    }
    return cell;
  }
}
