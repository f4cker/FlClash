import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

class CoreStatusButton extends ConsumerStatefulWidget {
  final MacHelperMaintenance? maintenance;

  const CoreStatusButton({super.key, this.maintenance});

  @override
  ConsumerState<CoreStatusButton> createState() => _CoreStatusButtonState();
}

class _CoreStatusButtonState extends ConsumerState<CoreStatusButton> {
  static const _holdDuration = Duration(milliseconds: 600);

  Timer? _holdTimer;
  CoreStatus _status = CoreStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _status = ref.read(coreStatusProvider);
    ref.listenManual(coreStatusProvider, (_, next) {
      _onStatusChanged(next);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onStatusChanged(CoreStatus next) {
    setState(() {
      _status = next;
      switch (next) {
        case CoreStatus.connecting:
          _holdTimer ??= Timer(_holdDuration, () {
            if (mounted) {
              setState(() {
                _holdTimer = null;
              });
            }
          });
          break;
        case CoreStatus.disconnected:
          _holdTimer?.cancel();
          _holdTimer = null;
          break;
        case CoreStatus.connected:
          break;
      }
    });
  }

  Future<void> _handleConnection() async {
    if (_holdTimer != null) {
      return;
    }
    final coreStatus = ref.read(coreStatusProvider);
    if (coreStatus == CoreStatus.connecting) {
      return;
    }
    final tip = coreStatus == CoreStatus.connected
        ? context.appLocalizations.forceRestartCoreTip
        : context.appLocalizations.restartCoreTip;
    final res = await dialogs.showMessage(message: TextSpan(text: tip));
    if (res != true || !mounted) {
      return;
    }
    try {
      await ref.read(coreActionProvider.notifier).restartCore();
    } catch (error) {
      dialogs.showBanner(error.toString(), level: BannerLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow =
        widget.maintenance ??
        (system.isMacOS && macosManagedHelperBuild
            ? macHelperMaintenance
            : null);
    if (flow == null || ref.watch(safeModeProvider)) {
      return _buildCoreStatus(context);
    }
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        if (!flow.busy &&
            (flow.state == null || flow.state == MacHelperState.enabled)) {
          return _buildCoreStatus(context);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCoreStatus(BuildContext context) {
    final coreStatus = _holdTimer != null ? CoreStatus.connecting : _status;
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final statusColor = switch (coreStatus) {
      CoreStatus.connecting => null,
      CoreStatus.connected => colorScheme.successContainer,
      CoreStatus.disconnected => colorScheme.errorContainer,
    };
    final statusForeground = switch (coreStatus) {
      CoreStatus.connecting => null,
      CoreStatus.connected => colorScheme.onSuccessContainer,
      CoreStatus.disconnected => colorScheme.onErrorContainer,
    };
    final pane = TonalButtonTheme.glassOf(context) && statusColor != null
        ? LiquidGlassStyle.tinted(colorScheme, statusColor)
        : null;
    final iconOnly =
        coreStatus == CoreStatus.connected || ViewScope.isMobileOf(context);
    final icon = switch (coreStatus) {
      CoreStatus.connecting => ActivityIndicator(
        color: iconOnly ? null : colorScheme.onPrimary,
      ),
      CoreStatus.connected => const GlyphIcon(AppGlyphs.check, fill: 1),
      CoreStatus.disconnected => const GlyphIcon(AppGlyphs.refresh, fill: 1),
    };
    return Tooltip(
      message: appLocalizations.coreStatus,
      child: FadeScaleBox(
        alignment: Alignment.centerRight,
        child: iconOnly
            ? IconButton.filled(
                key: ValueKey(coreStatus),
                style: ButtonStyle.from(
                  backgroundColor: pane == null
                      ? statusColor
                      : Colors.transparent,
                  foregroundColor: statusForeground,
                  backgroundBuilder: pane == null
                      ? null
                      : LiquidGlass.buttonBackground((_) => pane),
                  pressLook: PressLook.none,
                ),
                onPressed: _handleConnection,
                icon: icon,
              )
            : FilledButton.icon(
                key: ValueKey(coreStatus),
                onPressed: _handleConnection,
                style: ButtonStyle.from(
                  backgroundColor: pane == null
                      ? statusColor
                      : Colors.transparent,
                  foregroundColor: statusForeground,
                  backgroundBuilder: pane == null
                      ? null
                      : LiquidGlass.buttonBackground((_) => pane),
                  pressLook: PressLook.none,
                ),
                icon: SizedBox.square(
                  dimension: globalState.measure.textHeight(
                    AppTextStyle.subheadline,
                  ),
                  child: icon,
                ),
                label: Text(switch (coreStatus) {
                  CoreStatus.connecting => appLocalizations.connecting,
                  CoreStatus.connected => appLocalizations.connected,
                  CoreStatus.disconnected => appLocalizations.disconnected,
                }),
              ),
      ),
    );
  }
}

class MacHelperStatus extends ConsumerWidget {
  final Widget child;
  final MacHelperMaintenance? maintenance;

  const MacHelperStatus({super.key, required this.child, this.maintenance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow =
        maintenance ??
        (system.isMacOS && macosManagedHelperBuild
            ? macHelperMaintenance
            : null);
    if (flow == null || ref.watch(safeModeProvider)) return child;
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) {
        final visible =
            flow.busy ||
            (flow.state != null && flow.state != MacHelperState.enabled);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (visible)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  context.contentTopPadding,
                  16,
                  0,
                ),
                child: _buildHelperStatus(context, ref, flow),
              ),
            Expanded(
              child: TopInsetScope(
                inset: visible ? 12 : TopInsetScope.of(context),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelperStatus(
    BuildContext context,
    WidgetRef ref,
    MacHelperMaintenance flow,
  ) {
    final l = context.appLocalizations;
    final state = flow.state;
    final coreStatus = ref.watch(coreStatusProvider);
    final stopped =
        coreStatus == CoreStatus.disconnected && !flow.client.hasCoreSession;
    final sessionUnconfirmed =
        coreStatus != CoreStatus.connected && flow.client.hasCoreSession;
    final reason = flow.busy
        ? macHelperStatusLabel(l, flow)
        : switch (state) {
            MacHelperState.off || MacHelperState.installerRequired
                when stopped =>
              l.macHelperStartupInstall,
            MacHelperState.updateRequired || MacHelperState.incompatible
                when stopped =>
              l.macHelperStartupUpdate,
            MacHelperState.repairRequired when stopped =>
              l.macHelperStartupUnavailable,
            MacHelperState.repairRequired => l.macHelperUnavailable,
            MacHelperState.signingRequired => l.macHelperVerificationFailed,
            MacHelperState.unknown ||
            MacHelperState.unavailable => l.macHelperStatusUnknown,
            MacHelperState.exitUnconfirmed => l.macHelperCoreUnconfirmed,
            _ => macHelperStatusLabel(l, flow),
          };
    final action = flow.busy || state == null ? null : macHelperAction(state);
    final label = switch (action) {
      MacHelperAction.install => l.macHelperInstallAction,
      MacHelperAction.update => l.macHelperUpdateAction,
      MacHelperAction.settings => l.macHelperOpenSettings,
      MacHelperAction.retry => l.macHelperTryAgain,
      MacHelperAction.recheck => l.macHelperCheckAgain,
      null => l.macHelperMoreDetails,
    };
    return Tooltip(
      message: macHelperDetail(l, flow),
      child: TextButton.icon(
        onPressed: () {
          switch (action) {
            case MacHelperAction.recheck:
              unawaited(flow.check());
            case MacHelperAction.settings:
              unawaited(flow.openSettings());
            default:
              unawaited(showMacHelperFlow(context: context, maintenance: flow));
          }
        },
        icon: GlyphIcon(AppGlyphs.warning, color: context.colorScheme.warning),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sessionUnconfirmed && state != MacHelperState.exitUnconfirmed
                    ? '$reason\n${l.macHelperCoreUnconfirmed}'
                    : reason,
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: context.colorScheme.warning),
              ),
              Text(label, style: AppTextStyle.caption2.of(context)),
            ],
          ),
        ),
      ),
    );
  }
}
