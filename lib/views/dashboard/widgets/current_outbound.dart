import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ip_quality/labels.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/shapes/shapes.dart';

import 'card.dart';

const _builtinOutbounds = {'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS'};

bool isBuiltinOutbound(String name) => _builtinOutbounds.contains(name);

/// What a hidden address shows in its place, whatever its family.
const ipMask = '•••.•••.•••.•••';

const _decorationGrowth = 0.12;

const _decorationTurn = 2 * math.pi / 12;

/// The smallest side of a tap target on the card.
const _minHitSize = 44.0;

/// The address the card shows: the proxy's exit, or this device's own.
enum StatusCardExit { proxy, local }

/// The status, the exit's address with what is known about it, and the
/// start button.
///
/// The country badge looks the shown address up again; the address switches
/// between the proxy's exit and the local one, among those already found.
class CurrentOutboundCard extends ConsumerStatefulWidget {
  const CurrentOutboundCard({super.key});

  @override
  ConsumerState<CurrentOutboundCard> createState() =>
      _CurrentOutboundCardState();
}

class _CurrentOutboundCardState extends ConsumerState<CurrentOutboundCard> {
  late final OutboundIpProbe _probe;

  /// The last address each lookup found: a failed lookup leaves it shown.
  final _kept = <String, IpInfo>{};

  /// The user switched to the local address.
  var _wantsLocal = false;

  /// A retry asked for and not yet under way.
  var _requested = false;

  @override
  void initState() {
    super.initState();
    _probe = ref.read(outboundIpProbeProvider.notifier)
      ..watch(routedOutbound)
      ..watch(directOutbound);
  }

  @override
  void dispose() {
    _probe
      ..unwatch(routedOutbound)
      ..unwatch(directOutbound);
    super.dispose();
  }

  IpInfo? _valueOf(String target, ProbeEntry<IpInfo> entry) {
    if (entry.displayValue case final info?) {
      return _kept[target] = info;
    }
    return _kept[target];
  }

  void _retry({
    required String target,
    required String? ip,
    required bool busy,
    required Iterable<String> missing,
  }) {
    // Read afresh: a second tap may land before the card rebuilds.
    if (busy ||
        _requested ||
        ref.read(outboundIpProbeProvider).entryOf(target).isLoading) {
      return;
    }
    setState(() => _requested = true);
    _probe.refresh({target, ...missing});
    if (ip != null) {
      final ipx = ref.read(ipxLookupProvider(ip));
      if (ipx.phase == IpxPhase.failed) {
        ref.read(ipxLookupProvider(ip).notifier).retry();
      }
      // Only a fallback already asked for: reading one would start it.
      if (ref.exists(ipQualityProvider(ip)) &&
          ref.read(ipQualityProvider(ip)).hasError) {
        ref.invalidate(ipQualityProvider(ip));
      }
    }
    // The probe launches the lookup in a microtask of its own, queued
    // before this one: by now it is under way, or there is no route to ask
    // on and nothing to wait for.
    scheduleMicrotask(() {
      if (mounted) {
        setState(() => _requested = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    final isStart = ref.watch(isStartProvider);
    final suspended = isStart && ref.watch(suspendProvider);
    final rootAccess =
        mitmFeature && (ref.watch(rootAccessProvider).value ?? false);
    final exitEntry = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(routedOutbound)),
    );
    final localEntry = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(directOutbound)),
    );
    if (!isStart) {
      _kept.remove(routedOutbound);
    }
    // While Flash is not running there is no proxy exit: the device's own
    // address is the one traffic leaves by.
    final exitInfo = isStart ? _valueOf(routedOutbound, exitEntry) : null;
    final localInfo = _valueOf(directOutbound, localEntry);
    final shown = !isStart || (_wantsLocal && localInfo != null)
        ? StatusCardExit.local
        : StatusCardExit.proxy;
    final local = shown == StatusCardExit.local;
    final target = local ? directOutbound : routedOutbound;
    final entry = local ? localEntry : exitEntry;
    final info = local ? localInfo : exitInfo;
    final other = local ? exitInfo : localInfo;
    final busy = entry.isLoading || _requested;
    final failed = entry.phase == ProbePhase.failed;
    // No live route (the Core is not connected, e.g. while the helper cannot
    // start it) and nothing out: no answer is coming, so the placeholders hold
    // still instead of pulsing, which would redraw the window every frame.
    final still =
        info == null &&
        entry.phase != ProbePhase.probing &&
        !ref.watch(routeTrackerProvider.select((state) => state.live));
    final facts = info == null ? null : _factsOf(info);
    final metrics = _OutboundMetrics.of(density);
    final padding = metrics.padding.resolve(Directionality.of(context));
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final (chipLabel, chipTone) = suspended
        ? (appLocalizations.suspended, DashboardChipTone.warn)
        : isStart
        ? (appLocalizations.running, DashboardChipTone.ok)
        : (appLocalizations.notRunning, DashboardChipTone.idle);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: rootAccess ? 1 : 0),
      duration: context.motionDuration(commonDuration),
      builder: (context, root, child) => DashboardCard(
        padding: EdgeInsets.zero,
        semanticLabel: rootAccess
            ? '${appLocalizations.status} ${appLocalizations.root}'
            : appLocalizations.status,
        side: root == 0
            ? BorderSide.none
            : BorderSide(
                color: context.colorScheme.primary.withValues(alpha: root),
                width: 1.5,
              ),
        child: child!,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: AppShape.all(dashboardCardRadius(density)),
                textDirection: Directionality.of(context),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedDirectional(
                    end: metrics.decorationEnd,
                    top: metrics.decorationTop,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: isStart ? 1 : 0),
                      duration: context.motionDuration(_morphDuration),
                      curve: Curves.easeOutBack,
                      builder: (_, progress, _) => Transform.rotate(
                        angle: _decorationTurn * progress,
                        child: Transform.scale(
                          scale: 1 + _decorationGrowth * progress,
                          child: ShapeBadge(
                            shape: MaterialShapes.cookie12Sided,
                            color: Color.lerp(
                              colors.tone,
                              Color.alphaBlend(
                                colorScheme.primary.withValues(alpha: 0.1),
                                colors.card,
                              ),
                              progress.clamp(0, 1),
                            )!,
                            size: metrics.decorationSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: Row(
              spacing: metrics.gap,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardCardHeader(
                        glyph: AppGlyphs.status,
                        title: appLocalizations.status,
                        leading: [
                          DashboardChip(
                            label: chipLabel,
                            tone: chipTone,
                            dot: isStart,
                          ),
                        ],
                      ),
                      _ExitRow(
                        info: info,
                        shown: shown,
                        // Only while running is there another exit to tell
                        // this one apart from.
                        marked: isStart && local,
                        failed: failed && info == null,
                        staleFailed: failed && info != null,
                        still: still,
                        busy: busy,
                        facts: facts,
                        active: isStart,
                        metrics: metrics,
                        large: !density.isDesktop,
                        onRetry: () => _retry(
                          target: target,
                          ip: info?.ip,
                          busy: busy,
                          missing: [
                            if (other == null && (local ? isStart : true))
                              local ? routedOutbound : directOutbound,
                          ],
                        ),
                        onSwitch: other == null
                            ? null
                            : () => setState(() => _wantsLocal = !local),
                      ),
                      SizedBox(height: metrics.cellsTop),
                      if (density.isDesktop) const Spacer(),
                      TickerMode(
                        enabled: !still,
                        child: _Cells(
                          organization: facts?.organization,
                          loading: info == null ? !failed : facts!.loading,
                          active: isStart && !suspended,
                          gap: metrics.cellGap,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: metrics.buttonSlot,
                  child: Transform.translate(
                    offset: Offset(0, (padding.bottom - padding.top) / 2),
                    child: Center(
                      child: _StartToggle(
                        size: metrics.buttonSize,
                        enabled: hasProfile,
                        running: isStart,
                        suspended: suspended,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What ipx.al says about [info], or the IP quality sources when it has
  /// nothing; asked only for the address on show.
  _IpFacts _factsOf(IpInfo info) {
    final ip = info.ip;
    final appLocalizations = context.appLocalizations;
    final ipx = ref.watch(ipxLookupProvider(ip));
    final report = ipx.report;
    final brief = ipx.brief;
    final country = info.countryCode.isNotEmpty
        ? info.countryCode
        : report?.countryCode ?? brief?.countryCode;
    String? network(String? organization, int? asn) =>
        organization != null && organization.isNotEmpty
        ? organization
        : asn == null
        ? null
        : 'AS$asn';
    if (report != null) {
      final grade = report.grade;
      return _IpFacts(
        countryCode: country,
        type: report.type == IpxIpType.unknown
            ? null
            : report.type.label(context),
        quality: grade == null
            ? null
            : (
                '${appLocalizations.ipQualityShort} ${grade.label(context)}',
                switch (grade) {
                  IpxGrade.aPlus || IpxGrade.a => DashboardChipTone.ok,
                  IpxGrade.b => DashboardChipTone.idle,
                  IpxGrade.c => DashboardChipTone.warn,
                  IpxGrade.d => DashboardChipTone.error,
                },
              ),
        scoreLabel: report.score == null || grade == null
            ? null
            : appLocalizations.ipxScoreSemantics(
                '${report.score}',
                grade.letter,
              ),
        organization: network(report.organization, report.asn),
        loading: false,
      );
    }
    final briefNetwork = network(brief?.organization, brief?.asn);
    if (ipx.phase != IpxPhase.failed) {
      return _IpFacts(
        countryCode: country,
        organization: briefNetwork,
        loading: true,
      );
    }
    // No report: the IP quality sources stand in, as the detail sheet does.
    final fallback = ref.watch(ipQualityProvider(ip));
    final quality = fallback.value;
    if (quality != null) {
      return _IpFacts(
        countryCode: country,
        type: quality.type.label(context),
        quality: (
          '${appLocalizations.ipQualityShort} ${quality.level.label(context)}',
          switch (quality.level) {
            IpQualityLevel.good => DashboardChipTone.ok,
            IpQualityLevel.normal => DashboardChipTone.idle,
            IpQualityLevel.risky => DashboardChipTone.warn,
          },
        ),
        organization:
            briefNetwork ?? network(quality.organization, quality.asn),
        loading: false,
      );
    }
    return _IpFacts(
      countryCode: country,
      organization: briefNetwork,
      loading: fallback.isLoading || ipx.retrying,
      // The address is known; only the report about it is missing.
      reportFailed: !fallback.isLoading && !ipx.retrying,
    );
  }
}

/// What the card shows about one address.
@immutable
class _IpFacts {
  const _IpFacts({
    required this.countryCode,
    this.type,
    this.quality,
    this.scoreLabel,
    this.organization,
    required this.loading,
    this.reportFailed = false,
  });

  final String? countryCode;
  final String? type;
  final (String, DashboardChipTone)? quality;

  /// ipx.al's health score, read out with the address.
  final String? scoreLabel;
  final String? organization;
  final bool loading;
  final bool reportFailed;
}

class _OutboundMetrics {
  const _OutboundMetrics({
    required this.padding,
    required this.gap,
    required this.ipTop,
    required this.ipBottom,
    required this.cellsTop,
    required this.cellGap,
    required this.badgeSize,
    required this.ip,
    required this.buttonSize,
    required this.buttonSlot,
    required this.decorationSize,
    required this.decorationEnd,
    required this.decorationTop,
  });

  factory _OutboundMetrics.of(DashboardDensity density) => switch (density) {
    DashboardDensity.standard => _OutboundMetrics(
      padding: dashboardCardPadding(density).copyWith(bottom: 20),
      gap: 16,
      ipTop: 10,
      ipBottom: 4,
      cellsTop: 12,
      cellGap: 28,
      badgeSize: 48,
      ip: AppTextStyle.title1,
      buttonSize: 104,
      buttonSlot: 120,
      decorationSize: 290,
      decorationEnd: -64,
      decorationTop: -87,
    ),
    DashboardDensity.compact => _OutboundMetrics(
      padding: dashboardCardPadding(density).copyWith(bottom: 20),
      gap: 16,
      ipTop: 8,
      // The address's tap target reaches 44 without covering the chips.
      ipBottom: 8,
      cellsTop: 8,
      cellGap: 22,
      badgeSize: 40,
      ip: AppTextStyle.title2,
      buttonSize: 84,
      buttonSlot: 100,
      decorationSize: 250,
      decorationEnd: -64,
      decorationTop: -75,
    ),
    DashboardDensity.mobile => const _OutboundMetrics(
      padding: EdgeInsetsDirectional.fromSTEB(20, 18, 16, 18),
      gap: 10,
      ipTop: 12,
      ipBottom: 4,
      cellsTop: 16,
      cellGap: 24,
      badgeSize: 48,
      ip: AppTextStyle.title2,
      buttonSize: 88,
      buttonSlot: 88,
      decorationSize: 240,
      decorationEnd: -60,
      decorationTop: -66,
    ),
  };

  final EdgeInsetsGeometry padding;
  final double gap;

  /// Above and below the address, inside its tap target.
  final double ipTop;
  final double ipBottom;

  /// The least room between the chips and the cells; a taller desktop row
  /// gives the cells the rest, pinned to the bottom.
  final double cellsTop;
  final double cellGap;
  final double badgeSize;
  final AppTextStyle ip;
  final double buttonSize;
  final double buttonSlot;
  final double decorationSize;
  final double decorationEnd;
  final double decorationTop;
}

class _ExitRow extends StatelessWidget {
  const _ExitRow({
    required this.info,
    required this.shown,
    required this.marked,
    required this.failed,
    required this.staleFailed,
    required this.still,
    required this.busy,
    required this.facts,
    required this.active,
    required this.metrics,
    required this.large,
    required this.onRetry,
    required this.onSwitch,
  });

  final IpInfo? info;
  final StatusCardExit shown;

  /// Says which exit this is, next to the chips.
  final bool marked;

  /// The lookup failed with nothing to show.
  final bool failed;

  /// The last lookup failed; what it found before stays.
  final bool staleFailed;

  /// Placeholders do not pulse: nothing is on its way.
  final bool still;
  final bool busy;
  final _IpFacts? facts;
  final bool active;
  final _OutboundMetrics metrics;
  final bool large;
  final VoidCallback onRetry;

  /// Null while the other exit has no address.
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final style = DashboardText.figure(
      context,
      metrics.ip,
      color: active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
    ).copyWith(letterSpacing: 0);
    final info = this.info;
    final facts = this.facts;
    final lineHeight =
        metrics.ip.leading * DashboardDensityScope.scaleOf(context);
    final chipHeight = _chipHeight(large);
    final badgeBox = math.max(_minHitSize, metrics.badgeSize);
    final badgeTop = math.max(
      0.0,
      metrics.ipTop +
          (lineHeight + metrics.ipBottom + chipHeight - badgeBox) / 2,
    );
    final Widget ip = info != null
        ? _IpTarget(
            ip: info.ip,
            shown: shown,
            style: style,
            onSwitch: onSwitch,
            scoreLabel: facts?.scoreLabel,
            padding: EdgeInsets.only(
              top: metrics.ipTop,
              bottom: metrics.ipBottom,
            ),
            lineHeight: lineHeight,
          )
        : Padding(
            padding: EdgeInsets.only(
              top: metrics.ipTop,
              bottom: metrics.ipBottom,
            ),
            child: SizedBox(
              height: lineHeight,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: failed
                    ? Text(
                        appLocalizations.serviceFailed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(color: colorScheme.error),
                      )
                    : TickerMode(
                        enabled: !still,
                        child: SkeletonText(width: 140, style: style),
                      ),
              ),
            ),
          );
    return Row(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: badgeTop),
          child: _CountryBadge(
            countryCode: facts?.countryCode ?? info?.countryCode,
            size: metrics.badgeSize,
            box: badgeBox,
            active: active,
            checking: busy,
            failed: staleFailed,
            onRefresh: onRetry,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ip,
              if (failed)
                SizedBox(
                  height: chipHeight,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      appLocalizations.tapIconToRetry,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardText.label(context),
                    ),
                  ),
                )
              else
                TickerMode(
                  enabled: !still,
                  child: _IpChips(
                    facts: facts,
                    loading: info == null || facts!.loading,
                    marked: marked,
                    large: large,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The address, which switches to the other exit when there is one.
class _IpTarget extends ConsumerWidget {
  const _IpTarget({
    required this.ip,
    required this.shown,
    required this.style,
    required this.onSwitch,
    required this.scoreLabel,
    required this.padding,
    required this.lineHeight,
  });

  final String ip;
  final StatusCardExit shown;
  final TextStyle style;
  final VoidCallback? onSwitch;
  final String? scoreLabel;

  /// Inside the tap target, so it reaches 44 without growing the row.
  final EdgeInsets padding;
  final double lineHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    final name = switch (shown) {
      StatusCardExit.proxy => appLocalizations.exitIp,
      StatusCardExit.local => appLocalizations.localPublicIp,
    };
    final onSwitch = this.onSwitch;
    final hint = onSwitch == null
        ? null
        : switch (shown) {
            StatusCardExit.proxy => appLocalizations.switchToLocalExit,
            StatusCardExit.local => appLocalizations.switchToProxyExit,
          };
    final Widget target = Semantics(
      container: true,
      button: onSwitch != null,
      label: [
        name,
        hidden ? appLocalizations.hideIp : ip,
        ?scoreLabel,
      ].join(appLocalizations.semanticsSeparator),
      hint: hint,
      onTap: onSwitch,
      excludeSemantics: true,
      child: FocusRing(
        shape: AppShape.xs,
        child: PressRegion(
          onTap: onSwitch,
          canRequestFocus: onSwitch != null,
          excludeFromSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _minHitSize),
            child: Padding(
              padding: padding,
              child: SizedBox(
                height: lineHeight,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 1,
                  child: DashboardFitText(hidden ? ipMask : ip, style: style),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: hint == null ? target : Tooltip(message: hint, child: target),
    );
  }
}

double _chipHeight(bool large) => large ? 28 : 24;

const _chipSkeletonWidths = [48.0, 72.0];

class _IpChips extends StatelessWidget {
  const _IpChips({
    required this.facts,
    required this.loading,
    required this.marked,
    required this.large,
  });

  final _IpFacts? facts;
  final bool loading;
  final bool marked;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final facts = this.facts;
    final height = _chipHeight(large);
    final known = [
      if (facts?.type case final type?)
        DashboardChip(label: type, large: large),
      if (facts?.quality case (final label, final tone))
        DashboardChip(label: label, tone: tone, large: large),
    ];
    // Chips that do not fit wrap onto a clipped second line; the details
    // sheet still lists them all.
    return SizedBox(
      height: height,
      child: ClipRect(
        child: Wrap(
          spacing: 6,
          runSpacing: height,
          children: [
            if (marked)
              DashboardChip(
                label: appLocalizations.localExit,
                dot: true,
                dotColor: context.colorScheme.primary,
                large: large,
              ),
            if (known.isNotEmpty)
              ...known
            else if (loading)
              for (final width in _chipSkeletonWidths)
                SkeletonPill(width: width, height: height)
            else
              DashboardChip(
                label: facts?.reportFailed ?? false
                    ? appLocalizations.ipxNoResponse
                    : appLocalizations.ipTypeUnknown,
                large: large,
              ),
          ],
        ),
      ),
    );
  }
}

const _spinPeriod = Duration(milliseconds: 1500);

/// The exit's country on a clover that looks the address up again when
/// tapped and turns while it is being looked up.
class _CountryBadge extends StatefulWidget {
  const _CountryBadge({
    required this.countryCode,
    required this.size,
    required this.box,
    required this.active,
    required this.checking,
    required this.failed,
    required this.onRefresh,
  });

  final String? countryCode;
  final double size;

  /// The tap target around the clover, no smaller than 44.
  final double box;
  final bool active;
  final bool checking;

  /// The last lookup failed under an address still shown.
  final bool failed;
  final VoidCallback onRefresh;

  @override
  State<_CountryBadge> createState() => _CountryBadgeState();
}

class _CountryBadgeState extends State<_CountryBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: _spinPeriod,
  );
  var _hovered = false;
  var _focused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _spin();
  }

  @override
  void didUpdateWidget(_CountryBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checking != widget.checking) {
      _spin();
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  void _spin() {
    if (context.disableAnimations) {
      _turns.value = 0;
    } else if (widget.checking) {
      _turns.repeat();
    } else {
      // A clover looks the same every quarter turn, so it stops on the next.
      final rest = (_turns.value * 4).ceil() / 4;
      _turns.animateTo(rest, duration: _spinPeriod * (rest - _turns.value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final foreground = widget.active
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    final enabled = !widget.checking;
    final size = widget.size;
    final code = widget.countryCode;
    final tooltip = appLocalizations.requery;
    final separator = appLocalizations.semanticsSeparator;
    final color = Color.alphaBlend(
      foreground.withValues(alpha: enabled && _hovered ? 0.08 : 0),
      DashboardColors.of(context).tone2,
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: [
          tooltip,
          if (code != null && code.isNotEmpty) code.toUpperCase(),
          if (widget.checking) appLocalizations.querying,
          if (widget.failed) appLocalizations.queryFailed,
        ].join(separator),
        excludeSemantics: true,
        child: PressRegion(
          onTap: enabled ? widget.onRefresh : null,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          excludeFromSemantics: !enabled,
          child: SizedBox.square(
            dimension: widget.box,
            child: Center(
              child: ElasticPress(
                enabled: enabled,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _turns,
                      builder: (_, child) => ShapeBadge(
                        shape: MaterialShapes.clover4Leaf,
                        color: color,
                        size: size,
                        rotation: _turns.value * 2 * math.pi,
                        ring: _focused ? focusRingSide(colorScheme) : null,
                        child: child,
                      ),
                      child: code == null || code.isEmpty
                          ? GlyphIcon(
                              AppGlyphs.proxies,
                              size: size * 0.42,
                              color: foreground,
                            )
                          : Text(
                              code.toUpperCase(),
                              maxLines: 1,
                              style: AppTextStyle.footnote
                                  .of(context, emphasized: true)
                                  .copyWith(
                                    color: foreground,
                                    letterSpacing:
                                        0.04 * AppTextStyle.footnote.size,
                                  ),
                            ),
                    ),
                    if (widget.failed && !widget.checking)
                      PositionedDirectional(
                        top: size * 0.06,
                        end: size * 0.06,
                        child: SizedBox.square(
                          dimension: 8,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: colorScheme.error,
                              shape: CircleBorder(
                                side: BorderSide(
                                  color: DashboardColors.of(context).card,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cells extends StatelessWidget {
  const _Cells({
    required this.organization,
    required this.loading,
    required this.active,
    required this.gap,
  });

  final String? organization;
  final bool loading;
  final bool active;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final organization = this.organization;
    return Row(
      spacing: gap,
      children: [
        _Cell(
          label: appLocalizations.runTime,
          value: active ? const _RunTimeValue() : const _Placeholder(),
        ),
        Flexible(
          child: _Cell(
            label: appLocalizations.ipOrganization,
            value: organization != null
                ? _CellText(organization)
                : loading
                ? SkeletonText(width: 96, style: _cellStyle(context))
                : const _Placeholder(),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.label(context),
        ),
        const SizedBox(height: 2),
        value,
      ],
    );
  }
}

TextStyle _cellStyle(BuildContext context) =>
    AppTextStyle.subheadline.of(context, emphasized: true).toTabular;

class _CellText extends StatelessWidget {
  const _CellText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _cellStyle(context),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Text('—', maxLines: 1, style: _cellStyle(context));
  }
}

class _RunTimeValue extends ConsumerWidget {
  const _RunTimeValue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CellText(getTimeText(ref.watch(runTimeProvider)));
  }
}

const _morphDuration = Duration(milliseconds: 450);
const _stateDuration = Duration(milliseconds: 150);

final _startMorph = Morph(MaterialShapes.circle, MaterialShapes.cookie9Sided);

Path _morphPath(double progress) => _startMorph.toPath(progress: progress);

double _morphTurn(double progress) => progress * 2 * math.pi / 9;

/// A circle with a play glyph while stopped that grows the cookie-9 of a
/// running tunnel, the way the M3 Expressive loader morphs between shapes.
class _StartToggle extends ConsumerStatefulWidget {
  const _StartToggle({
    required this.size,
    required this.enabled,
    required this.running,
    required this.suspended,
  });

  final double size;
  final bool enabled;
  final bool running;
  final bool suspended;

  @override
  ConsumerState<_StartToggle> createState() => _StartToggleState();
}

class _StartToggleState extends ConsumerState<_StartToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _morphDuration,
    value: widget.running ? 1 : 0,
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  var _hovered = false;
  var _pressed = false;
  var _focused = false;

  /// The M3 state layer, painted inside the shape: the card's decoration
  /// covers the button, so ink on the card would never show.
  double get _overlay => !widget.enabled
      ? 0
      : _focused
      ? 0.1
      : _hovered
      ? 0.08
      : 0;

  @override
  void didUpdateWidget(_StartToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) {
      widget.running ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final glass = LiquidGlassScope.of(context);
    final size = widget.size;
    final enabled = widget.enabled;
    final fill = enabled
        ? colorScheme.primary
        : DashboardColors.of(context).tone2;
    final ink = enabled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final tooltip = widget.suspended
        ? appLocalizations.suspended
        : widget.running
        ? appLocalizations.stop
        : appLocalizations.start;
    final stateDuration = context.motionDuration(_stateDuration);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: PressRegion(
          onTap: enabled ? _toggle : null,
          onHover: (value) => setState(() => _hovered = value),
          onPressedChanged: (value) => setState(() => _pressed = value),
          onFocusChange: (value) => setState(() => _focused = value),
          child: ElasticPress(
            enabled: enabled,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _overlay),
              duration: stateDuration,
              builder: (_, overlay, child) => AnimatedBuilder(
                animation: _progress,
                builder: (_, child) {
                  final progress = _progress.value;
                  final color = Color.alphaBlend(
                    ink.withValues(alpha: overlay),
                    fill,
                  );
                  return CustomPaint(
                    painter: _MorphPainter(
                      progress: progress,
                      color: glass ? null : color,
                      shadow: enabled
                          ? colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                      ring: _focused
                          ? focusRingSide(colorScheme, standsOff: true)
                          : null,
                    ),
                    child: glass
                        ? LiquidGlass(
                            style: LiquidGlassStyle.tinted(colorScheme, color),
                            clipper: _MorphClipper(progress),
                            pressed: _pressed,
                            child: child,
                          )
                        : child,
                  );
                },
                child: child,
              ),
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: widget.suspended
                      ? GlyphIcon(
                          AppGlyphs.wifiOff,
                          size: size * 0.34,
                          color: ink,
                          fill: 1,
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween(end: widget.running ? 1 : 0),
                          duration: _morphDuration,
                          curve: Curves.easeOutBack,
                          builder: (_, progress, _) => GlyphIcon(
                            AppGlyphs.playPause(progress),
                            size: size * 0.34,
                            color: ink,
                            fill: 1,
                          ),
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

/// Fills the morph, or with no [color] leaves its inside to glass and casts
/// [shadow] only outside it, as one under glass would show through.
class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.progress,
    required this.color,
    required this.shadow,
    required this.ring,
  });

  static const _shadowOffset = Offset(0, 6);
  static const _shadowBlur = 14.0;

  final double progress;
  final Color? color;
  final Color shadow;
  final BorderSide? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _morphPath(progress);
    final color = this.color;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(_morphTurn(progress))
      ..scale(size.width, size.height)
      ..translate(-0.5, -0.5);
    if (shadow.a > 0) {
      canvas.save();
      if (color == null) {
        canvas.clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(const Rect.fromLTRB(-1, -1, 2, 2))
            ..addPath(path, Offset.zero),
        );
      }
      canvas
        ..translate(
          _shadowOffset.dx / size.width,
          _shadowOffset.dy / size.height,
        )
        ..drawPath(
          path,
          Paint()
            ..color = shadow
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _shadowBlur / 2 / size.width,
            ),
        )
        ..restore();
    }
    if (color != null) {
      canvas.drawPath(path, Paint()..color = color);
    }
    if (ring case final ring?) {
      strokeUnitShape(canvas, path, size.width, ring);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MorphPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.shadow != shadow ||
      oldDelegate.ring != ring;
}

class _MorphClipper extends CustomClipper<Path> {
  const _MorphClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final transform =
        Matrix4.translationValues(size.width / 2, size.height / 2, 0)
          ..rotateZ(_morphTurn(progress))
          ..scaleByDouble(size.width, size.height, 1, 1)
          ..translateByDouble(-0.5, -0.5, 0, 1);
    return _morphPath(progress).transform(transform.storage);
  }

  @override
  bool shouldReclip(_MorphClipper oldClipper) =>
      oldClipper.progress != progress;
}
