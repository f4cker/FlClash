import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_indicator.dart';
import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/mitm.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _fade = Duration(milliseconds: 200);

/// Opens the MITM settings: the sidebar's page where it lists one, else over
/// whatever [context] shows, as the advanced settings do.
Future<void> openMitmSettings(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(isMobileViewProvider)) {
    container.read(currentPageLabelProvider.notifier).toPage(PageLabel.mitm);
    return;
  }
  await showNestedExtend<void>(
    context,
    builder: (_) => MitmView(isAndroid: system.isAndroid),
  );
}

/// Opens the setting that records request content, as the next page of
/// whatever [context] shows. It only shows the switch: nothing is turned on
/// for the user.
Future<void> openMitmCaptureSettings(BuildContext context) =>
    showNestedExtend<void>(
      context,
      builder: (_) => MitmCaptureView(isAndroid: system.isAndroid),
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

/// The dashboard's bar while decryption is on: green while it is ready or
/// decrypting, amber while paused, red when the Core failed its identity
/// check. It opens the MITM settings.
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
              onPressed: () => unawaited(openMitmSettings(context)),
            ),
    );
  }
}

/// A round button the size of the live status beside it; the status and
/// why it is paused are in its tooltip.
class MitmStatusCapsule extends StatelessWidget {
  final MitmIndicator indicator;
  final VoidCallback? onPressed;

  const MitmStatusCapsule({super.key, required this.indicator, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final l = context.appLocalizations;
    final (fill, onFill) = switch (indicator) {
      MitmIndicator(reason: MitmPauseReason.coreIdentity) => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      _ when mitmIndicatorNeedsAttention(indicator) => (
        colorScheme.warningContainer,
        colorScheme.onWarningContainer,
      ),
      _ => (colorScheme.successContainer, colorScheme.onSuccessContainer),
    };
    final pane = TonalButtonTheme.glassOf(context)
        ? LiquidGlassStyle.tinted(colorScheme, fill)
        : null;
    final text = mitmIndicatorText(l, indicator);
    return Padding(
      // The bar's gap to the actions after it.
      padding: const EdgeInsetsDirectional.only(end: barButtonGap),
      child: Semantics(
        label: '$text. ${l.mitmIndicatorOpenSettings}',
        button: true,
        excludeSemantics: true,
        child: Tooltip(
          message: '$text\n${l.mitmIndicatorOpenSettings}',
          excludeFromSemantics: true,
          child: IconButton.filled(
            style: ButtonStyle.from(
              backgroundColor: pane == null ? fill : Colors.transparent,
              foregroundColor: onFill,
              backgroundBuilder: pane == null
                  ? null
                  : LiquidGlass.buttonBackground((_) => pane),
              pressLook: PressLook.none,
            ),
            onPressed: onPressed,
            icon: GlyphIcon(switch (indicator.kind) {
              MitmIndicatorKind.on ||
              MitmIndicatorKind.decrypting => AppGlyphs.lockOpen,
              MitmIndicatorKind.paused ||
              MitmIndicatorKind.unconfirmed => AppGlyphs.lock,
            }, fill: 1),
          ),
        ),
      ),
    );
  }
}
