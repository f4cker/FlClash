import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_indicator.dart';
import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/mitm.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Below this window width the capsule leaves the reason to its tooltip.
const double mitmBarCompactWidth = 720;

const _fade = Duration(milliseconds: 200);
const _tint = 0.15;

/// Opens the MITM settings over whatever [context] shows, as the advanced
/// settings do.
Future<void> openMitmSettings(BuildContext context) => showNestedExtend<void>(
  context,
  builder: (_) => MitmView(isAndroid: system.isAndroid),
);

/// From the tray: the window comes forward with the settings open.
Future<void> openMitmSettingsFromTray() async {
  await window?.show();
  final context = globalState.navigatorKey.currentContext;
  if (context == null || !context.mounted) {
    return;
  }
  await openMitmSettings(context);
}

/// Every page's bar while decryption is on: amber while it decrypts,
/// muted while paused, red when the Core failed its identity check. It opens
/// the MITM settings.
class MitmBarStatus extends ConsumerWidget {
  const MitmBarStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indicator = ref.watch(mitmIndicatorProvider);
    return AnimatedSwitcher(
      duration: _fade,
      child: indicator == null
          ? const SizedBox.shrink(key: ValueKey('off'))
          : MitmStatusCapsule(
              key: const ValueKey('on'),
              indicator: indicator,
              compact: ref.watch(viewWidthProvider) < mitmBarCompactWidth,
              onPressed: () => unawaited(openMitmSettings(context)),
            ),
    );
  }
}

class MitmStatusCapsule extends StatelessWidget {
  final MitmIndicator indicator;

  /// The status without its reason, which moves to the tooltip; for a
  /// narrow window. The words stay: an icon alone would not say it decrypts.
  final bool compact;
  final VoidCallback? onPressed;

  const MitmStatusCapsule({
    super.key,
    required this.indicator,
    required this.compact,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final l = context.appLocalizations;
    final color = switch (indicator) {
      MitmIndicator(kind: MitmIndicatorKind.decrypting) => colorScheme.warning,
      MitmIndicator(reason: MitmPauseReason.coreIdentity) => colorScheme.error,
      _ => colorScheme.onSurfaceVariant,
    };
    final text = mitmIndicatorText(l, indicator);
    final height = TonalButtonSize.bar.button;
    final icon = GlyphIcon(
      indicator.kind == MitmIndicatorKind.decrypting
          ? AppGlyphs.lockOpen
          : AppGlyphs.lock,
      size: TonalButtonSize.section.icon,
      color: color,
    );
    final fill = color.withValues(alpha: _tint);
    final style =
        ButtonStyle.from(
          foregroundColor: color,
          backgroundColor: fill,
          shape: AppShape.full,
          minimumSize: Size.square(height),
          fixedSize: Size.fromHeight(height),
          padding: const EdgeInsetsDirectional.only(start: 12, end: 14),
          tapTargetSize: TapTargetSize.shrinkWrap,
          pressLook: PressLook.tint,
        ).merge(
          ButtonStyle(side: WidgetStatePropertyAll(BorderSide(color: color))),
        );
    return Padding(
      // The bar's gap to the actions after it.
      padding: const EdgeInsetsDirectional.only(end: barButtonGap),
      child: AnimatedSize(
        duration: _fade,
        curve: Curves.easeInOut,
        alignment: AlignmentDirectional.centerEnd,
        child: Semantics(
          label: '$text. ${l.mitmIndicatorOpenSettings}',
          button: true,
          excludeSemantics: true,
          child: Tooltip(
            message: '$text\n${l.mitmIndicatorOpenSettings}',
            excludeFromSemantics: true,
            child: FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: icon,
              // The reason too, as far as the bar has room for it.
              label: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 160 : 300),
                child: Text(
                  compact ? mitmIndicatorLabel(l, indicator) : text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
