import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

// The node row's marks are provisional until the design settles: each field's
// glyph and label are set here and nowhere else. A row shows a field only when
// the config turns it on; off and unknown are told apart in the info alone.

const _assetDir = 'assets/images/node_fields';

// Which Core types read each option, from mihomo's adapter/outbound.
const _tcpDialed = {
  'Shadowsocks',
  'ShadowsocksR',
  'Snell',
  'Socks5',
  'Http',
  'Vmess',
  'Vless',
  'Trojan',
  'Ssh',
  'Mieru',
  'AnyTLS',
  'Sudoku',
  'TrustTunnel',
  'OpenVPN',
  'GostRelay',
  'Direct',
};
const _smuxTypes = {'Shadowsocks', 'Vmess', 'Vless', 'Trojan', 'GostRelay'};

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

  bool get needsUdp => this == uot || this == xudp;

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

  bool appliesTo(String type) => switch (this) {
    uot => type == 'Shadowsocks',
    xudp => type == 'Vmess' || type == 'Vless',
    tfo => _tcpDialed.contains(type) || type == 'Hysteria' || type == 'Tuic',
    mptcp => _tcpDialed.contains(type),
    smux => _smuxTypes.contains(type),
    _ => true,
  };

  /// A switch as configured, null when unknown, not read by the protocol, or
  /// a named field. The Core sends false for every switch of every node.
  bool? switchOf(Proxy proxy) {
    final value = switch (this) {
      uot => proxy.uot,
      xudp => proxy.xudp,
      tfo => proxy.tfo,
      mptcp => proxy.mptcp,
      smux => proxy.smux,
      _ => null,
    };
    // Only UoT reports a protocol's nature rather than its config when on.
    if (value == true && this != uot) return true;
    return appliesTo(proxy.type) ? value : null;
  }

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
    bool udpOff = false,
  }) {
    final noUdp =
        udpOff || udp == NodeUdp.disabled || udp == NodeUdp.disabledByGroup;
    return [
      if (udp == NodeUdp.enabled && !udpOff) NodeField.udp,
      ...of.where((field) => field.isOn(proxy) && !(noUdp && field.needsUdp)),
    ];
  }
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

typedef UdpOf = ({NodeUdp state, String? by});

UdpOf _udp(NodeUdp state) => (state: state, by: null);

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
UdpOf groupUdpOf(
  Group group, {
  required List<Group> groups,
  required Map<String, String> selectedMap,
  int depth = 0,
}) {
  if (group.disableUdp == true) {
    return (state: NodeUdp.disabledByGroup, by: group.name);
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
          _udp(NodeUdp.unknown);
    }
  }
  return _udp(NodeUdp.of(group.udp));
}

/// Null for an action such as REJECT, which carries no traffic to judge.
UdpOf? nodeUdpOf(
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
      return (state: NodeUdp.disabledByGroup, by: proxy.name);
    }
  }
  return _udp(NodeUdp.of(proxy.udp));
}

UdpOf? watchNodeUdp(WidgetRef ref, Proxy proxy) {
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
          : groupUdpOf(group, groups: groups, selectedMap: selectedMap).state;
    }),
  );
}

bool watchGroupDisablesUdp(WidgetRef ref, String? groupName) {
  if (groupName == null) return false;
  return ref.watch(
    groupsProvider.select(
      (groups) => groups.getGroup(groupName)?.disableUdp == true,
    ),
  );
}

/// Shows [message] on hover and on focus, which arrow keys in a card give.
class FieldTip extends StatelessWidget {
  const FieldTip({
    super.key,
    required this.message,
    required this.child,
    this.focusable = true,
  });

  final String message;
  final Widget child;
  final bool focusable;

  @override
  Widget build(BuildContext context) {
    final content = Semantics(
      label: message,
      excludeSemantics: true,
      child: child,
    );
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      child: !focusable
          ? content
          : Builder(
              builder: (context) => _FocusTip(
                onFocusChange: (focused) {
                  if (focused) {
                    context
                        .findAncestorStateOfType<RawTooltipState>()
                        ?.ensureTooltipVisible();
                  } else {
                    RawTooltip.dismissAllToolTips();
                  }
                },
                child: content,
              ),
            ),
    );
  }
}

class _FocusTip extends StatefulWidget {
  const _FocusTip({required this.onFocusChange, required this.child});

  final ValueChanged<bool> onFocusChange;
  final Widget child;

  @override
  State<_FocusTip> createState() => _FocusTipState();
}

class _FocusTipState extends State<_FocusTip> {
  final _focusNode = SkipTraversalFocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = Focus(
      focusNode: _focusNode,
      onKeyEvent: stepCardAction,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        widget.onFocusChange(focused);
      },
      child: widget.child,
    );
    if (!_focused) return child;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: AppShape.xs.copyWith(side: focusRingSide(context.colorScheme)),
      ),
      child: child,
    );
  }
}

/// Arrows between a card's icons and delay in the order they sit; left from
/// the leftmost goes back to the card.
KeyEventResult stepCardAction(FocusNode node, KeyEvent event) {
  final key = event.logicalKey;
  final right = key == LogicalKeyboardKey.arrowRight;
  if (event is! KeyDownEvent ||
      (!right && key != LogicalKeyboardKey.arrowLeft)) {
    return KeyEventResult.ignored;
  }
  final card = node.ancestors.firstWhereOrNull(
    (ancestor) => ancestor.canRequestFocus && !ancestor.skipTraversal,
  );
  if (card == null) return KeyEventResult.ignored;
  final actions =
      card.descendants
          .where((other) => other.skipTraversal && other.canRequestFocus)
          .toList()
        ..sort((a, b) => a.rect.left.compareTo(b.rect.left));
  final index = actions.indexOf(node);
  final next = right
      ? actions.elementAtOrNull(index + 1)
      : (index > 0 ? actions[index - 1] : card);
  if (next == null) return KeyEventResult.ignored;
  next.requestFocus();
  return KeyEventResult.handled;
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
    this.focusable = true,
  });

  final NodeField field;
  final Proxy proxy;

  /// The text line the icon sits in, which bounds its size.
  final AppTextStyle line;

  /// What follows the state, as the node a group's UDP comes from.
  final String? note;

  final bool focusable;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final size = nodeMarkSize(context, line);
    return FieldTip(
      focusable: focusable,
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

/// How many of at most three icons fit after [label] in [width], and whether
/// +N does; icons fold first, then +N, and the protocol stays.
@visibleForTesting
({int shown, bool more}) foldNodeFields({
  required int count,
  required double width,
  required double label,
  required double icon,
  required double gap,
  required double Function(int rest) plus,
}) {
  double need(int shown) {
    final rest = count - shown;
    return label + shown * (gap + icon) + (rest > 0 ? gap + plus(rest) : 0);
  }

  var shown = math.min(3, count);
  while (shown > 0 && need(shown) > width) {
    shown--;
  }
  return (shown: shown, more: shown < count && need(shown) <= width);
}

/// The protocol and up to three fields the config turns on, the rest folded
/// into +N, and fewer as the row narrows.
class NodeMetaLine extends StatelessWidget {
  const NodeMetaLine({
    super.key,
    required this.proxy,
    required this.label,
    required this.style,
    required this.fields,
    this.udpNote,
  });

  final Proxy proxy;
  final String label;
  final TextStyle style;
  final List<NodeField> fields;
  final String? udpNote;

  static const _gap = 6.0;

  double _width(BuildContext context, String text) {
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
    final size = nodeMarkSize(context);
    final labelWidth = _width(context, label);
    final plusWidths = <int, double>{};
    return LayoutBuilder(
      builder: (context, constraints) {
        final fold = foldNodeFields(
          count: fields.length,
          width: constraints.maxWidth,
          label: labelWidth,
          icon: size,
          gap: _gap,
          plus: (rest) =>
              plusWidths.putIfAbsent(rest, () => _width(context, '+$rest')),
        );
        final rest = fields.sublist(fold.shown);
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
            for (final field in fields.take(fold.shown))
              NodeFieldIcon(
                field: field,
                proxy: proxy,
                note: field == NodeField.udp ? udpNote : null,
              ),
            if (fold.more)
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

/// A node's facts from the current config, as seen from [groupName].
class NodeInfoView extends ConsumerWidget {
  const NodeInfoView({super.key, required this.proxy, this.groupName});

  final Proxy proxy;
  final String? groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final udp = watchNodeUdp(ref, proxy);
    final groupUdpOff =
        groupName != proxy.name && watchGroupDisablesUdp(ref, groupName);
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
        if (udp != null) row(l.nodeFieldUdp, udp.state.state(l)),
        if (udp?.by case final by?)
          Text(
            by == proxy.name ? l.nodeGroupUdpDisabled : l.nodeUdpDisabledBy(by),
            style: valueStyle,
          ),
        if (groupUdpOff) row(l.nodeFieldThisGroup, l.nodeGroupDisablesUdp),
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
