import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

// The node row's marks are provisional until the design settles: each field's
// glyph and label are set here and nowhere else. A row shows a field only when
// the config turns it on; off and unknown are told apart in the info alone.

const _assetDir = 'assets/images/node_fields';

enum NodeField {
  udp('udp'),
  uot('uot'),
  xudp('xudp'),
  tfo('tfo'),
  mptcp('mptcp'),
  smux('mux'),
  dialerProxy('relay'),
  interfaceName('interface'),
  provider('provider');

  const NodeField(this._asset);

  final String _asset;

  String get asset => '$_assetDir/$_asset.svg';

  String label(AppLocalizations l) => switch (this) {
    udp => l.nodeFieldUdp,
    uot => l.nodeFieldUot,
    xudp => l.nodeFieldXudp,
    tfo => l.nodeFieldTfo,
    mptcp => l.nodeFieldMptcp,
    smux => l.nodeFieldSmux,
    dialerProxy => l.nodeFieldDialerProxy,
    interfaceName => l.nodeFieldInterface,
    provider => l.nodeFieldProvider,
  };

  /// The configured name for a field that carries one, null for a switch.
  String? valueOf(Proxy proxy) => switch (this) {
    dialerProxy => proxy.dialerProxy,
    interfaceName => proxy.interfaceName,
    provider => proxy.providerName,
    _ => null,
  };

  /// A switch as configured, null when unknown or for a named field.
  bool? switchOf(Proxy proxy) => switch (this) {
    uot => proxy.uot,
    xudp => proxy.xudp,
    tfo => proxy.tfo,
    mptcp => proxy.mptcp,
    smux => proxy.smux,
    _ => null,
  };

  /// UDP is judged by [nodeUdpOf], which a group's selection decides.
  bool isOn(Proxy proxy) => switch (this) {
    udp => false,
    uot || xudp || tfo || mptcp || smux => switchOf(proxy) == true,
    _ => valueOf(proxy)?.isNotEmpty == true,
  };

  /// What a node row may show; its source is in the info alone.
  static const rowFields = [
    uot,
    xudp,
    tfo,
    mptcp,
    smux,
    dialerProxy,
    interfaceName,
  ];

  static List<NodeField> onIn(
    Proxy proxy, {
    NodeUdp? udp,
    List<NodeField> of = values,
  }) => [
    if (udp == NodeUdp.enabled) NodeField.udp,
    ...of.where((field) => field.isOn(proxy)),
  ];
}

enum NodeUdp {
  enabled,
  disabled,
  disabledByGroup,
  unknown;

  static NodeUdp of(bool? udp) => switch (udp) {
    true => enabled,
    false => disabled,
    null => unknown,
  };

  String state(AppLocalizations l) => switch (this) {
    enabled => l.nodeConfigEnabled,
    disabled || disabledByGroup => l.nodeConfigDisabled,
    unknown => l.nodeStatusUnknown,
  };
}

const _actionTypes = {
  'Reject',
  'RejectDrop',
  'Compatible',
  'Pass',
  'PassRule',
  'Rematch',
  'Dns',
};

const _protocolNames = {
  'Shadowsocks': 'SS',
  'ShadowsocksR': 'SSR',
  'Socks5': 'SOCKS5',
  'Http': 'HTTP',
  'Vmess': 'VMess',
  'Vless': 'VLESS',
  'Hysteria2': 'Hysteria 2',
  'Tuic': 'TUIC',
  'Ssh': 'SSH',
  'Dns': 'DNS',
};

String nodeProtocolName(String type) => _protocolNames[type] ?? type;

/// A group follows the member it routes through, unless it disables UDP
/// itself; a load balance or relay answers only as a whole.
NodeUdp groupUdpOf(
  Group group, {
  required List<Group> groups,
  required Map<String, String> selectedMap,
  int depth = 0,
}) {
  if (group.disableUdp == true) {
    return NodeUdp.disabledByGroup;
  }
  final follows =
      group.type.isComputedSelected || group.type == GroupType.Selector;
  if (follows && depth < 8) {
    final name = group.getCurrentSelectedName(selectedMap[group.name] ?? '');
    final member = group.all.firstWhereOrNull((proxy) => proxy.name == name);
    if (member != null) {
      return nodeUdpOf(
            member,
            groups: groups,
            selectedMap: selectedMap,
            depth: depth + 1,
          ) ??
          NodeUdp.unknown;
    }
  }
  return NodeUdp.of(group.udp);
}

/// Null for an action such as REJECT, which carries no traffic to judge.
NodeUdp? nodeUdpOf(
  Proxy proxy, {
  required List<Group> groups,
  required Map<String, String> selectedMap,
  int depth = 0,
}) {
  if (_actionTypes.contains(proxy.type)) {
    return null;
  }
  if (GroupTypeExtension.getGroupType(proxy.type) != null) {
    final group = groups.getGroup(proxy.name);
    if (group != null) {
      return groupUdpOf(
        group,
        groups: groups,
        selectedMap: selectedMap,
        depth: depth,
      );
    }
    if (proxy.disableUdp == true) {
      return NodeUdp.disabledByGroup;
    }
  }
  return NodeUdp.of(proxy.udp);
}

NodeUdp? watchNodeUdp(WidgetRef ref, Proxy proxy) {
  if (GroupTypeExtension.getGroupType(proxy.type) == null) {
    return nodeUdpOf(proxy, groups: const [], selectedMap: const {});
  }
  final selectedMap = ref.watch(selectedMapProvider);
  return ref.watch(
    groupsProvider.select(
      (groups) => nodeUdpOf(proxy, groups: groups, selectedMap: selectedMap),
    ),
  );
}

NodeUdp watchGroupUdp(WidgetRef ref, String groupName) {
  final selectedMap = ref.watch(selectedMapProvider);
  return ref.watch(
    groupsProvider.select((groups) {
      final group = groups.getGroup(groupName);
      return group == null
          ? NodeUdp.unknown
          : groupUdpOf(group, groups: groups, selectedMap: selectedMap);
    }),
  );
}

/// Shows [message] on hover and while keyboard focus rests on [child].
class FieldTip extends StatelessWidget {
  const FieldTip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      child: Builder(
        // Off the tab order, as the delay is: arrow keys reach it.
        builder: (context) => Focus(
          skipTraversal: true,
          onFocusChange: (focused) {
            if (focused) {
              context
                  .findAncestorStateOfType<RawTooltipState>()
                  ?.ensureTooltipVisible();
            } else {
              RawTooltip.dismissAllToolTips();
            }
          },
          child: Semantics(
            label: message,
            excludeSemantics: true,
            child: child,
          ),
        ),
      ),
    );
  }
}

double nodeMarkSize(
  BuildContext context, [
  AppTextStyle line = AppTextStyle.footnote,
]) => math.min(
  MediaQuery.textScalerOf(context).scale(16),
  globalState.measure.textHeight(line),
);

class NodeFieldIcon extends StatelessWidget {
  const NodeFieldIcon({
    super.key,
    required this.field,
    required this.proxy,
    this.note,
    this.line = AppTextStyle.footnote,
  });

  final NodeField field;
  final Proxy proxy;

  /// The text line the icon sits in, which bounds its size.
  final AppTextStyle line;

  /// What follows the state, as the node a group's UDP comes from.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final size = nodeMarkSize(context, line);
    return FieldTip(
      message: [
        l.nodeFieldState(
          field.label(l),
          field.valueOf(proxy) ?? l.nodeConfigEnabled,
        ),
        ?note,
      ].join(' '),
      child: SvgPicture.asset(
        field.asset,
        width: size,
        height: size,
        excludeFromSemantics: true,
        theme: SvgTheme(currentColor: context.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// The protocol and up to three fields the config turns on, the rest folded
/// into +N, and fewer as the row narrows.
class NodeMetaLine extends StatelessWidget {
  const NodeMetaLine({
    super.key,
    required this.proxy,
    required this.label,
    required this.style,
    required this.udp,
    this.udpNote,
  });

  final Proxy proxy;
  final String label;
  final TextStyle style;
  final NodeUdp? udp;
  final String? udpNote;

  static const _gap = 6.0;
  static const _maxFields = 3;

  double _width(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final fields = NodeField.onIn(proxy, udp: udp, of: NodeField.rowFields);
    final size = nodeMarkSize(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = _width(context, label, style);
        double need(int shown) {
          final rest = fields.length - shown;
          return labelWidth +
              shown * (_gap + size) +
              (rest > 0 ? _gap + _width(context, '+$rest', style) : 0);
        }

        // Every icon folds before the protocol is cut, and +N goes too when
        // only the protocol fits; the info still lists them all.
        var shown = math.min(_maxFields, fields.length);
        while (shown > 0 && need(shown) > constraints.maxWidth) {
          shown--;
        }
        final fits =
            shown > 0 ||
            need(0) <= constraints.maxWidth ||
            labelWidth > constraints.maxWidth;
        final rest = fits ? fields.sublist(shown) : const <NodeField>[];
        return Row(
          spacing: _gap,
          children: [
            Flexible(
              child: TooltipText(
                text: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
            for (final field in fields.take(shown))
              NodeFieldIcon(
                field: field,
                proxy: proxy,
                note: field == NodeField.udp ? udpNote : null,
              ),
            if (rest.isNotEmpty)
              FieldTip(
                message: l.nodeFieldsMore(
                  rest.length,
                  rest.map((field) => field.label(l)).join(', '),
                ),
                child: Text('+${rest.length}', maxLines: 1, style: style),
              ),
          ],
        );
      },
    );
  }
}

/// The read-only facts behind a node's marks, from the current config.
class NodeInfoView extends ConsumerWidget {
  const NodeInfoView({super.key, required this.proxy});

  final Proxy proxy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final udp = watchNodeUdp(ref, proxy);
    final isGroup = GroupTypeExtension.getGroupType(proxy.type) != null;
    final current = isGroup
        ? ref.watch(
            realSelectedProxyStateProvider(
              proxy.name,
            ).select((state) => state.proxyName),
          )
        : '';
    final keyStyle = AppTextStyle.body
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final valueStyle = AppTextStyle.body
        .of(context)
        .copyWith(color: colorScheme.onSurface);
    Widget row(String key, String value) => Semantics(
      container: true,
      child: Wrap(
        spacing: 8,
        children: [
          Text(key, style: keyStyle),
          EmojiText(value, style: valueStyle),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        EmojiText(
          proxy.name,
          style: AppTextStyle.headline.of(context, emphasized: true),
        ),
        row(l.nodeFieldProtocol, nodeProtocolName(proxy.type)),
        if (isGroup && current.isNotEmpty && current != proxy.name)
          row(l.nodeFieldCurrentNode, current),
        if (udp != null) row(l.nodeFieldUdp, udp.state(l)),
        if (udp == NodeUdp.disabledByGroup)
          Text(l.nodeGroupUdpDisabled, style: valueStyle),
        // Off is said here only; unknown, as everywhere, is left out.
        for (final field in NodeField.values)
          if (field.valueOf(proxy) case final value? when value.isNotEmpty)
            row(field.label(l), value)
          else if (field.switchOf(proxy) case final on?)
            row(
              field.label(l),
              on ? l.nodeConfigEnabled : l.nodeConfigDisabled,
            ),
        const SizedBox(height: 8),
        Text(
          l.nodeInfoConfigNote,
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
