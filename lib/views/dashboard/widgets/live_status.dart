import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import 'live_status_deck.dart';

/// What is happening now and still needs the user: one card each in the deck,
/// in this order of importance.
sealed class LiveStatus {
  const LiveStatus({this.preview});

  /// Set on a card the developer page shows, which may share its kind with
  /// another and whose actions do nothing.
  final String? preview;

  Object get key => preview ?? runtimeType;
}

/// The macOS helper while it is not ready: one card whatever its state, so a
/// change of state updates the same card in place.
final class HelperLiveStatus extends LiveStatus {
  const HelperLiveStatus(this.view, {this.flow, super.preview});

  /// What the helper card shows, from [macHelperCardView] only.
  final MacHelperCardView view;

  /// The flow the card's actions run through; null for a preview, whose
  /// actions do nothing.
  final MacHelperMaintenance? flow;

  /// How loud the card is: [MacHelperBarTone.action] for something to do,
  /// [MacHelperBarTone.failure] for a failure, [MacHelperBarTone.waiting]
  /// while the helper only starts or switches.
  MacHelperBarTone get tone => macHelperBarKindOf(view.kind).$2;

  MacHelperBarKind get barKind => macHelperBarKindOf(view.kind).$1;

  /// An operation the helper runs right now: the card says so in place of
  /// its buttons and offers nothing to run again.
  bool get busy => flow?.busy ?? false;
}

/// The core's own phase. Starting and stopped lead the deck; a running core
/// is only there to reach its restart, so it comes last.
final class CoreLiveStatus extends LiveStatus {
  const CoreLiveStatus(this.phase, {super.preview});

  final CoreStatus phase;
}

final class UpdateStatus extends LiveStatus {
  const UpdateStatus(this.download, {super.preview});

  final UpdateDownload download;
}

/// Profiles, geo resources and providers updating now, from
/// [updatingKeysProvider] only: one card however many there are.
final class ResourcesStatus extends LiveStatus {
  const ResourcesStatus(this.items, {super.preview});

  final List<UpdatingResource> items;
}

typedef UpdatingResource = ({String name, bool isProfile});

final class MitmConsentStatus extends LiveStatus {
  const MitmConsentStatus(this.names, {super.preview});

  final List<String> names;
}

bool _isRunningCore(LiveStatus status) =>
    status is CoreLiveStatus && status.phase == CoreStatus.connected;

/// Whether [status] counts in the entry: everything but a healthy core.
bool countsInLiveStatus(LiveStatus status) => !_isRunningCore(status);

List<UpdatingResource> _updatingResources(
  Set<String> keys,
  List<Profile> profiles,
) {
  final profileNames = {
    for (final profile in profiles) profile.updatingKey: profile.realLabel,
  };
  final geoNames = {
    for (final resource in GeoResource.values) resource.updatingKey: resource,
  };
  return [
    for (final key in keys)
      if (profileNames[key] case final name?)
        (name: name, isProfile: true)
      else if (geoNames[key] case final resource?)
        (name: resource.name, isProfile: false)
      else if (key.startsWith('provider_'))
        (name: key.substring('provider_'.length), isProfile: false),
  ];
}

/// The deck's statuses in their order of importance:
///
/// 1. the helper, while it is not ready (failure, something to do, or a
///    wait);
/// 2. the core stopped or starting by itself, never one that only waits for
///    the helper ([coreWaitsForHelper]) or one the app cannot know
///    ([coreUnknown]);
/// 3. an update ready, then one downloading;
/// 4. resources updating;
/// 5. modules waiting for consent;
/// 6. the running core, which is not counted.
///
/// Pure, so the order is unit-tested without widgets.
List<LiveStatus> composeLiveStatuses({
  required CoreStatus core,
  required bool separateCore,
  UpdateDownload? download,
  List<UpdatingResource> resources = const [],
  List<String> awaitingConsent = const [],
  HelperLiveStatus? helper,
  bool coreWaitsForHelper = false,
  bool coreUnknown = false,
}) {
  final coreShown = !coreUnknown;
  final coreFault =
      coreShown &&
      !coreWaitsForHelper &&
      (core == CoreStatus.disconnected ||
          separateCore && core == CoreStatus.connecting);
  return [
    ?helper,
    if (coreFault) CoreLiveStatus(core),
    if (download is UpdateReady) UpdateStatus(download),
    if (download is UpdateDownloading) UpdateStatus(download),
    if (resources.isNotEmpty) ResourcesStatus(resources),
    if (awaitingConsent.isNotEmpty) MitmConsentStatus(awaitingConsent),
    if (coreShown && separateCore && core == CoreStatus.connected)
      const CoreLiveStatus(CoreStatus.connected),
  ];
}

/// What the helper adds to the live statuses: its card while it is not
/// ready, and whether the core's own status means anything now.
typedef HelperLiveState = ({
  HelperLiveStatus? card,
  bool coreWaitsForHelper,
  bool coreUnknown,
});

/// Reads [flow] as the deck sees it. Ready, the first check still running,
/// or a routine re-check of a ready helper add no card, so none of them
/// flickers into a problem. Any other state is exactly one card.
/// A stopped or starting core is the helper's consequence while the helper
/// is not ready, unless it stopped for a reason of its own
/// ([independentStop]): a crash or a start the helper did not refuse.
HelperLiveState macHelperLiveState(
  AppLocalizations l,
  MacHelperMaintenance? flow, {
  required bool independentStop,
}) {
  if (flow == null) {
    return (card: null, coreWaitsForHelper: false, coreUnknown: false);
  }
  final state = flow.state;
  final unsettled = flow.busy && !flow.routineCheck;
  final notReady = state != null && state != MacHelperState.enabled;
  return (
    card: notReady
        ? HelperLiveStatus(macHelperCardView(l, flow), flow: flow)
        : null,
    coreWaitsForHelper: (unsettled || notReady) && !independentStop,
    // A Core the old helper still runs is not known to this app while the
    // helper is not ready: say nothing about it rather than "stopped".
    coreUnknown: flow.client.hasCoreSession && (unsettled || notReady),
  );
}

/// The macOS helper flow the dashboard shows; null off macOS, in builds
/// without the managed helper, and in safe mode.
MacHelperMaintenance? dashboardMacHelper(
  WidgetRef ref, [
  MacHelperMaintenance? maintenance,
]) {
  if (ref.read(safeModeProvider)) return null;
  return maintenance ??
      (system.isMacOS && macosManagedHelperBuild ? macHelperMaintenance : null);
}

/// [separateCore] is a core in its own process, which the user can watch
/// start and restart; one inside the app only ever shows having stopped.
/// Listen to [helper] around this: its changes are not a provider's.
List<LiveStatus> watchLiveStatuses(
  WidgetRef ref, {
  required bool separateCore,
  MacHelperMaintenance? helper,
}) {
  final core = ref.watch(heldCoreStatusProvider);
  final download = ref.watch(updateDownloadStateProvider);
  final keys = ref.watch(updatingKeysProvider);
  final resources = keys.isEmpty
      ? const <UpdatingResource>[]
      : _updatingResources(keys, ref.watch(profilesProvider));
  final awaitingConsent = ref.watch(mitmModulesToAgreeProvider);
  final stopReason = ref.watch(coreStopReasonProvider);
  final helperState = macHelperLiveState(
    currentAppLocalizations,
    helper,
    independentStop: core == CoreStatus.disconnected && stopReason != null,
  );
  return composeLiveStatuses(
    core: core,
    separateCore: separateCore,
    download: download,
    resources: resources,
    awaitingConsent: [for (final module in awaitingConsent) module.name],
    helper: helperState.card,
    coreWaitsForHelper: helperState.coreWaitsForHelper,
    coreUnknown: helperState.coreUnknown,
  );
}

/// Opens the deck on one card of every kind, from the developer page.
void showLiveStatusPreview(BuildContext context) {
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final top = MediaQuery.paddingOf(context).top;
  final anchor = Rect.fromLTWH(overlay.size.width - 60, top + 8, 44, 44);
  final l = context.appLocalizations;
  const tag = 'v9.9.9';
  const mb = 1024 * 1024;
  unawaited(
    navigator.push(
      LiveStatusRoute(
        anchor: anchor,
        separateCore: true,
        barrierColor: context.colorScheme.alertScrim,
        barrierLabel: l.close,
        statuses: [
          HelperLiveStatus(
            MacHelperCardView(
              kind: MacHelperCardKind.approval,
              title: l.macHelperApprovalTitle,
              detail: l.macHelperAwaitingApprovalDetail,
              steps: [
                l.macHelperApprovalStep1,
                l.macHelperApprovalStep2,
                l.macHelperApprovalStep3,
              ],
              primary: MacHelperCardAction.openSettings,
              secondary: MacHelperCardAction.viewSteps,
            ),
            preview: 'helper',
          ),
          const CoreLiveStatus(CoreStatus.disconnected, preview: 'stopped'),
          const CoreLiveStatus(CoreStatus.connecting, preview: 'starting'),
          const UpdateStatus(UpdateReady(tag, ''), preview: 'ready'),
          const UpdateStatus(
            UpdateDownloading(tag, received: 18 * mb, total: 43 * mb),
            preview: 'downloading',
          ),
          const ResourcesStatus([
            (name: 'My subscription', isProfile: true),
            (name: 'GEOIP', isProfile: false),
            (name: 'ad-block', isProfile: false),
            (name: 'streaming', isProfile: false),
          ], preview: 'resources'),
          const MitmConsentStatus(['Ads', 'Scripts'], preview: 'consent'),
          const CoreLiveStatus(CoreStatus.connected, preview: 'running'),
        ],
      ),
    ),
  );
}

/// The dashboard's bar button: it wears the most important live status and
/// counts the rest. A running core alone shrinks it to a check, and with an
/// in-app core it is gone while nothing is happening.
///
/// On macOS it also stands for the helper: a helper that is not ready is the
/// deck's first card, and a feature that needs the helper opens the deck on
/// that card ([MacHelperPresenter]).
class LiveStatusButton extends ConsumerStatefulWidget {
  const LiveStatusButton({super.key, this.separateCore, this.maintenance});

  /// Whether the core runs in its own process; the build's core when null.
  final bool? separateCore;

  /// The macOS helper flow; the app's own when null.
  final MacHelperMaintenance? maintenance;

  @override
  ConsumerState<LiveStatusButton> createState() => _LiveStatusButtonState();
}

class _LiveStatusButtonState extends ConsumerState<LiveStatusButton>
    implements MacHelperPresenter {
  MacHelperMaintenance? _flow;
  AppLifecycleListener? _lifecycle;

  /// The deck this button opened, until it closes.
  Future<void>? _deck;

  /// Whether a feature that needs the helper opened the deck.
  final _requiredByFeature = ValueNotifier(false);

  bool get _separateCore => widget.separateCore ?? coreLib == null;

  @override
  MacHelperMaintenance get maintenance => _flow!;

  @override
  bool get canPresent {
    final flow = _flow;
    if (!mounted || flow == null) return false;
    // A feature only asks while the helper is not ready.
    final state = flow.state;
    if (state == null || state == MacHelperState.enabled) return false;
    if (_deck != null) return true;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return false;
    final route = ModalRoute.of(context);
    return PageActivityScope.isActiveOf(context) &&
        (route == null || route.isCurrent);
  }

  @override
  Future<void> present({required bool requiredByFeature}) {
    if (requiredByFeature) _requiredByFeature.value = true;
    return _deck ?? _open(focus: HelperLiveStatus);
  }

  @override
  void initState() {
    super.initState();
    final flow = dashboardMacHelper(ref, widget.maintenance);
    if (flow == null) return;
    _flow = flow;
    registerMacHelperPresenter(this);
    // Coming back from System Settings checks again.
    _lifecycle = AppLifecycleListener(onResume: flow.resumed);
    if (flow.state == null && !flow.busy) unawaited(flow.check());
  }

  @override
  void dispose() {
    final flow = _flow;
    if (flow != null) unregisterMacHelperPresenter(this);
    _lifecycle?.dispose();
    _requiredByFeature.dispose();
    super.dispose();
  }

  Future<void> _open({Object? focus}) {
    final navigator = Navigator.of(context);
    final box = context.findRenderObject()! as RenderBox;
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final deck = navigator
        .push(
          LiveStatusRoute(
            anchor: anchor,
            separateCore: _separateCore,
            barrierColor: context.colorScheme.alertScrim,
            barrierLabel: context.appLocalizations.close,
            helper: _flow,
            focus: focus,
            helperRequired: _requiredByFeature,
          ),
        )
        .whenComplete(() {
          _deck = null;
          _requiredByFeature.value = false;
        });
    _deck = deck;
    return deck;
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    if (flow == null) return _buildStatus(context);
    return ListenableBuilder(
      listenable: flow,
      builder: (context, _) => _buildStatus(context),
    );
  }

  Widget _buildStatus(BuildContext context) {
    final statuses = watchLiveStatuses(
      ref,
      separateCore: _separateCore,
      helper: _flow,
    );
    final top = statuses.firstOrNull;
    void open() => unawaited(_deck ?? _open());
    return FadeScaleBox(
      alignment: Alignment.centerRight,
      child: switch (top) {
        null => const SizedBox.shrink(),
        _ when _isRunningCore(top) => _RunningCoreButton(
          key: const ValueKey(CoreStatus.connected),
          onPressed: open,
        ),
        _ => _LiveStatusPill(
          key: ValueKey(_pillKindOf(top)),
          status: top,
          count: statuses.where(countsInLiveStatus).length,
          download: statuses
              .whereType<UpdateStatus>()
              .map((it) => it.download)
              .whereType<UpdateDownloading>()
              .firstOrNull,
          onPressed: open,
        ),
      },
    );
  }
}

Object _pillKindOf(LiveStatus status) => switch (status) {
  UpdateStatus(download: UpdateReady()) => UpdateReady,
  CoreLiveStatus(:final phase) => phase,
  _ => status.key,
};

/// The colors of a helper card's tone: amber for something to do, red for a
/// failure, the primary color for a wait.
({Color container, Color onContainer, Color accent, Color onAccent})
macHelperToneColors(ColorScheme colorScheme, MacHelperBarTone tone) =>
    switch (tone) {
      MacHelperBarTone.failure => (
        container: colorScheme.errorContainer,
        onContainer: colorScheme.onErrorContainer,
        accent: colorScheme.error,
        onAccent: colorScheme.onError,
      ),
      MacHelperBarTone.waiting => (
        container: colorScheme.primaryContainer,
        onContainer: colorScheme.onPrimaryContainer,
        accent: colorScheme.primary,
        onAccent: colorScheme.onPrimary,
      ),
      MacHelperBarTone.ready => (
        container: colorScheme.successContainer,
        onContainer: colorScheme.onSuccessContainer,
        accent: colorScheme.success,
        onAccent: colorScheme.onSuccess,
      ),
      MacHelperBarTone.action => (
        container: colorScheme.warningContainer,
        onContainer: colorScheme.onWarningContainer,
        accent: colorScheme.warning,
        onAccent: colorScheme.onWarning,
      ),
    };

/// The short reason a status gives, which the entry's label leads with.
String liveStatusReason(AppLocalizations l, LiveStatus status) =>
    switch (status) {
      HelperLiveStatus(:final view) => view.title,
      CoreLiveStatus(phase: CoreStatus.disconnected) => l.coreStopped,
      CoreLiveStatus(phase: CoreStatus.connecting) => l.connecting,
      CoreLiveStatus() => l.coreRunning,
      UpdateStatus(download: UpdateReady()) => l.updateReady,
      UpdateStatus() => l.downloadingUpdate,
      ResourcesStatus() => l.updatingResources,
      MitmConsentStatus() => l.mitmModulesTurnedOff,
    };

String _percentOf(UpdateDownloading download) => download.total > 0
    ? '${download.received * 100 ~/ download.total}%'
    : download.received.traffic.show;

/// The entry's spoken label: what leads, how many cards there are, and an
/// update's download progress.
String liveStatusEntryLabel(
  AppLocalizations l,
  LiveStatus top, {
  required int count,
  UpdateDownloading? download,
}) => [
  liveStatusReason(l, top),
  l.liveStatusItems(count),
  if (download != null) l.liveStatusUpdateDownload(_percentOf(download)),
].join(', ');

class _RunningCoreButton extends StatelessWidget {
  const _RunningCoreButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final fill = colorScheme.successContainer;
    final pane = TonalButtonTheme.glassOf(context)
        ? LiquidGlassStyle.tinted(colorScheme, fill)
        : null;
    return IconButton.filled(
      tooltip: context.appLocalizations.liveStatus,
      style: ButtonStyle.from(
        backgroundColor: pane == null ? fill : Colors.transparent,
        foregroundColor: colorScheme.onSuccessContainer,
        backgroundBuilder: pane == null
            ? null
            : LiquidGlass.buttonBackground((_) => pane),
        pressLook: PressLook.none,
      ),
      onPressed: onPressed,
      icon: const GlyphIcon(AppGlyphs.check, fill: 1),
    );
  }
}

/// The top status's glyph and one number: an update's download progress,
/// which beats the count, or how many cards there are beside others; the
/// cards say the rest.
class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill({
    super.key,
    required this.status,
    required this.count,
    required this.onPressed,
    this.download,
  });

  final LiveStatus status;
  final int count;
  final VoidCallback onPressed;

  /// An update downloading, wherever its card is in the deck.
  final UpdateDownloading? download;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final (fill, content) = switch (status) {
      HelperLiveStatus(:final tone) => () {
        final colors = macHelperToneColors(colorScheme, tone);
        return (colors.container, colors.onContainer);
      }(),
      CoreLiveStatus(phase: CoreStatus.disconnected) => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      UpdateStatus(download: UpdateReady()) => (
        colorScheme.successContainer,
        colorScheme.onSuccessContainer,
      ),
      MitmConsentStatus() => (
        colorScheme.warningContainer,
        colorScheme.onWarningContainer,
      ),
      _ => (null, null),
    };
    final download = this.download;
    final iconSize = globalState.measure.textHeight(AppTextStyle.subheadline);
    final icon = SizedBox.square(
      dimension: iconSize,
      child: switch (status) {
        _ when download != null => _PillProgressRing(
          value: download.total > 0 ? download.received / download.total : null,
        ),
        HelperLiveStatus(:final barKind) => GlyphIcon(
          macHelperBarGlyph(barKind),
          fill: 1,
        ),
        CoreLiveStatus(phase: CoreStatus.disconnected) => const GlyphIcon(
          AppGlyphs.error,
          fill: 1,
        ),
        CoreLiveStatus() || ResourcesStatus() => Builder(
          builder: (context) =>
              ActivityIndicator(color: IconTheme.of(context).color),
        ),
        UpdateStatus(download: UpdateReady()) => const GlyphIcon(
          AppGlyphs.checkCircle,
          fill: 1,
        ),
        UpdateStatus() => const _PillProgressRing(value: null),
        MitmConsentStatus() => const GlyphIcon(AppGlyphs.puzzle, fill: 1),
      },
    );
    final shown = switch (status) {
      _ when download != null => _percentOf(download),
      UpdateStatus(download: UpdateReady()) => '100%',
      _ when count > 1 => '$count',
      _ => null,
    };
    final pane = TonalButtonTheme.glassOf(context) && fill != null
        ? LiquidGlassStyle.tinted(colorScheme, fill)
        : null;
    final style = ButtonStyle.from(
      backgroundColor: pane == null ? fill : Colors.transparent,
      foregroundColor: content,
      backgroundBuilder: pane == null
          ? null
          : LiquidGlass.buttonBackground((_) => pane),
      pressLook: PressLook.none,
    );
    return Semantics(
      label: liveStatusEntryLabel(
        appLocalizations,
        status,
        count: count,
        download: download,
      ),
      excludeSemantics: true,
      button: true,
      child: shown != null
          ? Tooltip(
              message: appLocalizations.liveStatus,
              child: FilledButton.icon(
                onPressed: onPressed,
                style: style,
                icon: icon,
                label: Text(
                  shown,
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            )
          : IconButton.filled(
              tooltip: appLocalizations.liveStatus,
              style: style,
              onPressed: onPressed,
              icon: icon,
            ),
    );
  }
}

class _PillProgressRing extends StatelessWidget {
  const _PillProgressRing({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? context.colorScheme.onPrimary;
    return CustomPaint(
      painter: _RingPainter(value: value ?? 0, color: color),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.14;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.3);
    canvas.drawOval(rect, paint);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0, 1),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
