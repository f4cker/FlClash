import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common.dart';
import 'node_fields.dart';

void selectGroupProxy(
  WidgetRef ref, {
  required String groupName,
  required GroupType groupType,
  required String proxyName,
}) {
  final isComputedSelected = groupType.isComputedSelected;
  if (isComputedSelected || groupType == GroupType.Selector) {
    final currentProxyName = ref.read(proxyNameProvider(groupName));
    final nextProxyName = switch (isComputedSelected) {
      true => currentProxyName == proxyName ? '' : proxyName,
      false => proxyName,
    };
    ref
        .read(proxiesActionProvider.notifier)
        .changeProxyDebounce(groupName, nextProxyName);
    return;
  }
  dialogs.showBanner(
    currentAppLocalizations.notSelectedTip,
    level: BannerLevel.warning,
  );
}

/// Built-ins and groups have no definition, and a custom profile's own proxies
/// are the local proxies already.
bool _isAddableToLocal(Proxy proxy, {required bool isCustomProfile}) {
  return (proxy.providerName != null || !isCustomProfile) &&
      !reservedCustomProxyNames.contains(proxy.name) &&
      GroupTypeExtension.getGroupType(proxy.type) == null;
}

class ProxyCard extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
  });

  Measure get measure => globalState.measure;

  Widget _buildProxyNameText(BuildContext context) {
    return EmojiText(
      proxy.name,
      maxLines: type == ProxyCardType.compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.subheadline.of(context),
    );
  }

  void _handleSelect(WidgetRef ref) {
    selectGroupProxy(
      ref,
      groupName: groupName,
      groupType: groupType,
      proxyName: proxy.name,
    );
  }

  void _handleAddToLocalProxies(WidgetRef ref) {
    final proxiesAction = ref.read(proxiesActionProvider.notifier);
    globalState.safeRun(() => proxiesAction.addToLocalProxies(proxy.name));
  }

  List<PopupMenuItem> _menuItems(
    BuildContext context,
    WidgetRef ref, {
    required bool inUse,
    required bool pinned,
    required bool addable,
  }) {
    final appLocalizations = context.appLocalizations;
    return [
      if (groupType == GroupType.Selector)
        PopupMenuItem(
          glyph: AppGlyphs.checkCircle,
          label: appLocalizations.select,
          checked: inUse,
          onPressed: () => _handleSelect(ref),
        )
      else if (groupType.isComputedSelected)
        PopupMenuItem(
          glyph: AppGlyphs.pin,
          label: appLocalizations.preferred,
          checked: pinned,
          onPressed: () => _handleSelect(ref),
        ),
      if (addable)
        PopupMenuItem(
          glyph: AppGlyphs.listAdd,
          label: appLocalizations.addToLocalProxies,
          onPressed: () => _handleAddToLocalProxies(ref),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measure = globalState.measure;
    final isLoose = type == ProxyCardType.loose;
    final exit = ref.watch(
      tailscaleExitRuntimeProvider.select(
        (report) => report.value?.cardOf(proxy.name),
      ),
    );
    final delayText = _DelayText(
      proxy: proxy,
      testUrl: testUrl,
      alignment: isLoose ? Alignment.centerLeft : Alignment.centerRight,
      unavailable: exit?.unavailable ?? false,
    );
    final typeLabel = exit?.node == true
        ? context.appLocalizations.tsExitGroupName
        : nodeProtocolName(proxy.type);
    final udp = watchNodeUdp(ref, proxy);
    final isGroup = GroupTypeExtension.getGroupType(proxy.type) != null;
    final current = isGroup
        ? ref.watch(
            realSelectedProxyStateProvider(
              proxy.name,
            ).select((state) => state.proxyName),
          )
        : proxy.name;
    final follows = current == proxy.name
        ? null
        : context.appLocalizations.nodeUdpFollowsNode(current);
    final fields = NodeField.onIn(
      proxy,
      udp: udp?.state,
      of: NodeField.rowFields,
      udpOff: watchGroupDisablesUdp(ref, groupName),
    );
    final proxyNameText = _buildProxyNameText(context);
    final line = measure.textHeight(AppTextStyle.subheadline);
    final band = nodeTitleBand;
    final typeStyle = AppTextStyle.footnote
        .of(context)
        .copyWith(
          overflow: TextOverflow.ellipsis,
          color: context.colorScheme.onSurface.opacity80,
        );
    final details = isLoose
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: measure.textHeight(AppTextStyle.footnote),
                child: NodeMetaLine(
                  proxy: proxy,
                  label: current == proxy.name
                      ? typeLabel
                      : '$typeLabel($current)',
                  style: typeStyle,
                  fields: fields,
                  udpNote: follows,
                ),
              ),
              const SizedBox(height: nodeCardRowGap),
              delayText,
            ],
          )
        : SizedBox(
            height: measure.textHeight(AppTextStyle.footnote),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 6,
              children: [
                Expanded(
                  child: NodeMetaLine(
                    proxy: proxy,
                    label: typeLabel,
                    style: typeStyle,
                    fields: fields,
                    udpNote: follows,
                  ),
                ),
                delayText,
              ],
            ),
          );
    return Consumer(
      builder: (context, ref, _) {
        final inUse = ref.watch(
          selectedProxyNameProvider(
            groupName,
          ).select((name) => name == proxy.name),
        );
        final pinned =
            groupType.isComputedSelected &&
            ref.watch(
              proxyNameProvider(groupName).select((name) => name == proxy.name),
            );
        final isCustomProfile = ref.watch(
          currentProfileProvider.select(
            (profile) => profile?.type == ProfileType.custom,
          ),
        );
        final card = ContextMenuRegion(
          menuItems: _menuItems(
            context,
            ref,
            inUse: inUse,
            pinned: pinned,
            addable: _isAddableToLocal(proxy, isCustomProfile: isCustomProfile),
          ),
          child: Card(
            radius: AppCorner.lg,
            enterActionsOnRight: true,
            key: key,
            onPressed: () => _handleSelect(ref),
            isSelected: inUse,
            padding: EdgeInsets.symmetric(horizontal: nodeCardPadding.left),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: nodeCardPadding.top),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: nodeBadgeGap,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: (band - line) / 2),
                          child: proxyNameText,
                        ),
                      ),
                      if (pinned || inUse)
                        Padding(
                          padding: EdgeInsets.only(
                            top: (band - nodeBadgeSize) / 2,
                          ),
                          child: pinned
                              ? SelectionBadge(
                                  size: nodeBadgeSize,
                                  glyph: Glyphs.pin,
                                  tonal: !inUse,
                                )
                              : const SelectionBadge(size: nodeBadgeSize),
                        ),
                      const SizedBox(width: nodeInfoRoom),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: nodeCardRowGap),
                    child: details,
                  ),
                ],
              ),
            ),
          ),
        );
        // Beside the card, not in it, so opening the info never selects.
        return Stack(
          children: [
            card,
            Positioned(
              top: nodeCardPadding.top + band / 2 - InfoButton.size / 2,
              right: 4,
              child: InfoButton(
                label: context.appLocalizations.nodeInfoButton(proxy.name),
                builder: (_) =>
                    NodeInfoView(proxy: proxy, groupName: groupName),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DelayText extends ConsumerStatefulWidget {
  const _DelayText({
    required this.proxy,
    required this.testUrl,
    required this.alignment,
    this.unavailable = false,
  });

  final Proxy proxy;
  final String? testUrl;
  final Alignment alignment;

  /// A Tailscale exit the Core refuses: shown as such, never as a delay.
  final bool unavailable;

  @override
  ConsumerState<_DelayText> createState() => _DelayTextState();
}

class _DelayTextState extends ConsumerState<_DelayText> {
  final FocusNode _focusNode = SkipTraversalFocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final isFocused = _focusNode.hasPrimaryFocus;
    if (isFocused == _isFocused) {
      return;
    }
    setState(() {
      _isFocused = isFocused;
    });
  }

  void _handleTestCurrentDelay() {
    ref
        .read(proxiesActionProvider.notifier)
        .proxyDelayTest(widget.proxy, widget.testUrl);
  }

  Widget _withFocusRing(BuildContext context, Widget child) {
    if (!_isFocused) {
      return child;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -2,
          right: -3,
          bottom: -2,
          left: -3,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: AppShape.xs.copyWith(
                  side: focusRingSide(context.colorScheme),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final measure = globalState.measure;
    final delay = ref.watch(
      delayProvider(proxyName: widget.proxy.name, testUrl: widget.testUrl),
    );
    final phase = ref.watch(
      delayTestPhaseProvider(
        proxyName: widget.proxy.name,
        testUrl: widget.testUrl,
      ),
    );
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTestCurrentDelay();
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: stepCardAction,
        child: SizedBox(
          height: measure.textHeight(AppTextStyle.caption2),
          child: FadeBox(
            alignment: widget.alignment,
            child: widget.unavailable && phase == null
                ? GestureDetector(
                    onTap: _handleTestCurrentDelay,
                    child: _withFocusRing(
                      context,
                      Text(
                        context.appLocalizations.tsExitUnavailableShort,
                        maxLines: 1,
                        style: AppTextStyle.caption2
                            .of(context, emphasized: true)
                            .copyWith(
                              overflow: TextOverflow.ellipsis,
                              color: context.colorScheme.error,
                            ),
                      ),
                    ),
                  )
                : phase != null || delay == null
                ? SizedBox(
                    height: measure.textHeight(AppTextStyle.caption2),
                    width: measure.textHeight(AppTextStyle.caption2),
                    child: _withFocusRing(context, switch (phase) {
                      DelayTestPhase.running => ActivityIndicator(
                        size: measure.textHeight(AppTextStyle.caption2),
                      ),
                      DelayTestPhase.queued => GlyphIcon(
                        AppGlyphs.clock,
                        size: measure.textHeight(AppTextStyle.caption2),
                        color: context.colorScheme.onSurfaceVariant.opacity38,
                      ),
                      null => HoverTooltip(
                        message: context.appLocalizations.delayTest,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleTestCurrentDelay,
                          child: GlyphIcon(
                            AppGlyphs.bolt,
                            size: measure.textHeight(AppTextStyle.caption2),
                          ),
                        ),
                      ),
                    }),
                  )
                : GestureDetector(
                    onTap: _handleTestCurrentDelay,
                    child: _withFocusRing(
                      context,
                      Text(
                        delay > 0
                            ? '$delay ms'
                            : delayFailureText(delay, context.appLocalizations),
                        maxLines: 1,
                        style: AppTextStyle.caption2
                            .of(context, emphasized: true)
                            .copyWith(
                              overflow: TextOverflow.ellipsis,
                              color: context.colorScheme.delayColor(delay),
                            ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
