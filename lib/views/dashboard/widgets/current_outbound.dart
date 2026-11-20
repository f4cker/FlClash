import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/features/ip_quality/ip_quality_sheet.dart';
import 'package:fl_clash/features/ip_quality/labels.dart';
import 'package:fl_clash/models/models.dart';
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
import 'ip_detail_tag.dart';

const _builtinOutbounds = {'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS'};

bool isBuiltinOutbound(String name) => _builtinOutbounds.contains(name);

/// What a hidden address shows in its place, whatever its family.
const ipMask = '•••.•••.•••.•••';

const _decorationGrowth = 0.12;

const _decorationTurn = 2 * math.pi / 12;

/// The smallest side of a tap target on the card.
const _minHitSize = 44.0;

/// Two answers came back over one route: neither the Core, the host nor the
/// proxying changed, and no node was picked in between.
bool _sameRoute(RouteStamp a, RouteStamp b) =>
    a.coreEpoch == b.coreEpoch &&
    a.hostEpoch == b.hostEpoch &&
    a.proxied == b.proxied &&
    a.routeVersion == b.routeVersion;

/// A lookup that actually ran on the route in use and failed; a failure
/// left from another route, or one no lookup stands behind, is no answer.
bool _erred(ProbeEntry<IpInfo> entry, RouteState route) {
  final stamp = entry.stamp;
  return entry.phase == ProbePhase.failed &&
      stamp != null &&
      route.isFresh(stamp);
}

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

  /// The last address each lookup found and the route it was found on: a
  /// lookup that fails on that same route leaves it shown.
  final _kept = <String, ({RouteStamp stamp, IpInfo info})>{};

  /// The user switched to the local address.
  var _wantsLocal = false;

  /// The user switched this session: from then on only the badge asks.
  var _switched = false;

  /// A retry asked for and not yet under way.
  var _requested = false;

  /// The exit the badge was tapped on, until its lookup settles: its
  /// lookup is announced.
  String? _userAsked;

  /// The exit the card opens a session on has not answered yet: its first
  /// lookup is announced. Later lookups the probe starts on its own, as when
  /// the route moves, are not.
  var _opening = true;

  /// Addresses whose report the card may ask ipx.al for: the exit shown
  /// before any switch, and the address the country badge was tapped on.
  /// Anything else shows only what is cached.
  final _askable = <String>{};

  @override
  void initState() {
    super.initState();
    _probe = ref.read(outboundIpProbeProvider.notifier)
      ..watch(routedOutbound)
      ..watch(directOutbound);
    ref.listenManual(
      outboundIpProbeProvider,
      (_, next) => _onProbe(next),
      fireImmediately: true,
    );
    ref.listenManual(isStartProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      if (next) {
        // A new session opens on the proxy exit, asked about unprompted.
        _wantsLocal = false;
        _switched = false;
        _opening = true;
      } else {
        _kept.remove(routedOutbound);
      }
      _settleAnnouncements(ref.read(outboundIpProbeProvider));
      _askDefault(ref.read(outboundIpProbeProvider));
    });
  }

  @override
  void dispose() {
    _probe
      ..unwatch(routedOutbound)
      ..unwatch(directOutbound);
    super.dispose();
  }

  void _onProbe(RoutedProbeState<String, IpInfo> state) {
    for (final target in const [routedOutbound, directOutbound]) {
      final entry = state.entryOf(target);
      final value = entry.value;
      final stamp = entry.stamp;
      if (value != null && stamp != null) {
        _kept[target] = (stamp: stamp, info: value);
      } else if (entry.phase == ProbePhase.empty) {
        _kept.remove(target);
      }
    }
    _settleAnnouncements(state);
    _askDefault(state);
  }

  /// Lets go of the lookups to announce once they have answered.
  void _settleAnnouncements(RoutedProbeState<String, IpInfo> state) {
    if (_opening) {
      final target = ref.read(isStartProvider)
          ? routedOutbound
          : directOutbound;
      final entry = state.entryOf(target);
      final stamp = entry.stamp;
      // Answered on the route in use: one left from before the session
      // does not count.
      if (!entry.isLoading &&
          stamp != null &&
          ref.read(routeTrackerProvider).isFresh(stamp)) {
        _opening = false;
      }
    }
    if (_userAsked case final asked?
        when !_requested && !state.entryOf(asked).isLoading) {
      _userAsked = null;
    }
  }

  /// The exit the card opens on may have its report asked for unprompted,
  /// until the user first switches this session.
  void _askDefault(RoutedProbeState<String, IpInfo> state) {
    if (_switched) {
      return;
    }
    final isStart = ref.read(isStartProvider);
    final route = ref.read(routeTrackerProvider);
    final target = isStart ? routedOutbound : directOutbound;
    if (_infoOf(target, state.entryOf(target), route)?.ip case final ip?) {
      _askable.add(ip);
    }
  }

  /// What [entry] shows: its value, the one it holds while its route is
  /// checked again, or after a failure the last one found on the same route.
  IpInfo? _infoOf(String target, ProbeEntry<IpInfo> entry, RouteState route) {
    // A failure shows only what was found on its own route, never a value
    // carried over from the one before.
    if (entry.phase != ProbePhase.failed) {
      if (entry.displayValue case final info?) {
        return info;
      }
    }
    final kept = _kept[target];
    if (!_erred(entry, route) ||
        kept == null ||
        !_sameRoute(kept.stamp, entry.stamp!)) {
      return null;
    }
    return kept.info;
  }

  void _switch(bool toLocal) {
    setState(() {
      _switched = true;
      _wantsLocal = toLocal;
      _opening = false;
      // A switch shows what is at hand and asks for nothing.
      _askable.clear();
    });
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
    setState(() {
      _requested = true;
      _userAsked = target;
      // The report of the address on show, and of it alone.
      if (ip != null) {
        _askable.add(ip);
      }
    });
    _probe.refresh({target, ...missing});
    if (ip != null) {
      if (ref.exists(ipxLookupProvider(ip)) &&
          ref.read(ipxLookupProvider(ip)).phase == IpxPhase.failed) {
        ref.read(ipxLookupProvider(ip).notifier).retry();
      }
    }
    // The probe launches the lookup in a microtask of its own, queued
    // before this one: by now it is under way, or there is no route to ask
    // on and nothing to wait for.
    scheduleMicrotask(() {
      if (mounted) {
        setState(() {
          _requested = false;
          _settleAnnouncements(ref.read(outboundIpProbeProvider));
        });
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
    final route = ref.watch(routeTrackerProvider);
    // While Flash is not running there is no proxy exit: the device's own
    // address is the one traffic leaves by.
    final exitInfo = isStart ? _infoOf(routedOutbound, exitEntry, route) : null;
    final localInfo = _infoOf(directOutbound, localEntry, route);
    final shown = !isStart || (_wantsLocal && localInfo != null)
        ? StatusCardExit.local
        : StatusCardExit.proxy;
    final local = shown == StatusCardExit.local;
    final target = local ? directOutbound : routedOutbound;
    final entry = local ? localEntry : exitEntry;
    final info = local ? localInfo : exitInfo;
    final other = local ? exitInfo : localInfo;
    final otherEntry = local ? exitEntry : localEntry;
    final busy = entry.isLoading || _requested;
    final failed = _erred(entry, route);
    // A failure from another route, or with no lookup behind it, says
    // nothing about this exit: it waits for a lookup.
    final pending = info == null && entry.phase == ProbePhase.failed && !failed;
    // No live route (the Core is not connected, e.g. while the helper cannot
    // start it) and nothing out: no answer is coming, so the placeholders hold
    // still instead of pulsing, which would redraw the window every frame.
    final still =
        info == null && entry.phase != ProbePhase.probing && !route.live;
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
                      // The tags' targets reach below the row into the gap
                      // and the cells' labels, which take no taps, so the
                      // card keeps its height.
                      HitOverhang(
                        bottom: ipDetailTagReach(
                          _chipHeight(!density.isDesktop),
                        ),
                        child: _ExitRow(
                          info: info,
                          shown: shown,
                          // Only while running is there another exit to tell
                          // this one apart from.
                          marked: isStart && local,
                          failed: failed && info == null,
                          staleFailed: failed && info != null,
                          pending: pending,
                          still: still,
                          busy: busy,
                          announceBusy: _opening || _userAsked == target,
                          facts: facts,
                          active: isStart,
                          metrics: metrics,
                          large: !density.isDesktop,
                          onRetry: () => _retry(
                            target: target,
                            ip: info?.ip,
                            busy: busy,
                            missing: [
                              // The other exit's address alone, not its report;
                              // one already being looked up is left to it.
                              if (other == null &&
                                  !otherEntry.isLoading &&
                                  (local ? isStart : true))
                                local ? routedOutbound : directOutbound,
                            ],
                          ),
                          onSwitch: other == null
                              ? null
                              : () => _switch(!local),
                        ),
                      ),
                      SizedBox(height: metrics.cellsTop),
                      if (density.isDesktop) const Spacer(),
                      TickerMode(
                        enabled: !still,
                        // Plain text, under the reach of the tags' targets.
                        child: IgnorePointer(
                          child: _Cells(
                            organization: facts?.organization,
                            // Running, an exit is always meant: what is not
                            // known about it is unknown, not absent.
                            known: info != null || isStart,
                            loading: info == null
                                ? !failed && !pending
                                : facts!.loading,
                            active: isStart && !suspended,
                            gap: metrics.cellGap,
                          ),
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

  /// What ipx.al says about [info]. Only an address in [_askable] is asked
  /// about; for any other the card reads what is cached and otherwise says
  /// it is not looked up.
  _IpFacts _factsOf(IpInfo info) {
    final ip = info.ip;
    final appLocalizations = context.appLocalizations;
    final askable = _askable.contains(ip);
    if (!askable && !ref.exists(ipxLookupProvider(ip))) {
      // The country is the lookup's own answer for this very address.
      return _IpFacts(
        countryCode: info.countryCode.isNotEmpty ? info.countryCode : null,
        loading: false,
        pending: true,
      );
    }
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
    // No report: the card says so and stands by what it has, as it did in
    // beta 3; the IP quality sources are left to the detail sheet.
    return _IpFacts(
      countryCode: country,
      organization: briefNetwork,
      loading: ipx.retrying,
      reportFailed: !ipx.retrying,
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
    this.pending = false,
  });

  /// Nothing has been asked about this address yet.
  final bool pending;

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
    required this.pending,
    required this.still,
    required this.busy,
    required this.announceBusy,
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

  /// No lookup has answered for this exit on the route in use.
  final bool pending;

  /// Placeholders do not pulse: nothing is on its way.
  final bool still;
  final bool busy;

  /// The lookup was asked for by the user or opens the session, so its
  /// start is announced.
  final bool announceBusy;
  final _IpFacts? facts;
  final bool active;
  final _OutboundMetrics metrics;
  final bool large;
  final VoidCallback onRetry;

  /// Null while the other exit has no address.
  final VoidCallback? onSwitch;

  /// The detail of the address shown when the tag was tapped, as far as
  /// it is known: it switches nothing and asks nothing.
  Future<void> _openDetail(BuildContext context, IpInfo info, _IpFacts? facts) {
    final countryCode =
        facts?.countryCode ??
        (info.countryCode.isNotEmpty ? info.countryCode : null);
    return showIpDetailSheet(
      context,
      ip: info.ip,
      countryCode: countryCode,
      title: switch (shown) {
        StatusCardExit.proxy => context.appLocalizations.exitIp,
        StatusCardExit.local => context.appLocalizations.localPublicIp,
      },
    );
  }

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
            pending: facts?.pending ?? false,
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
                child: failed || pending
                    ? Text(
                        failed
                            ? appLocalizations.queryFailed
                            : appLocalizations.pendingQuery,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                          color: failed
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
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
            announceChecking: announceBusy,
            state: staleFailed
                ? _BadgeState.stale
                : failed
                ? _BadgeState.failed
                : pending || (facts?.pending ?? false)
                ? _BadgeState.pending
                : _BadgeState.known,
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
                  height: _tagRowHeight(large),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: SizedBox(
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
                    ),
                  ),
                )
              else if (pending)
                SizedBox(height: _tagRowHeight(large))
              else
                TickerMode(
                  enabled: !still,
                  child: _IpChips(
                    ip: info?.ip,
                    facts: facts,
                    loading: info == null || facts!.loading,
                    marked: marked,
                    large: large,
                    onOpenDetail: info == null
                        ? null
                        : () => _openDetail(context, info, facts),
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
    required this.pending,
    required this.padding,
    required this.lineHeight,
  });

  final String ip;

  /// Nothing has been asked about the address yet.
  final bool pending;
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
        if (pending) appLocalizations.pendingQuery,
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
      // The hint is read out with the label; the tooltip is for the eye.
      child: hint == null
          ? target
          : Tooltip(message: hint, excludeFromSemantics: true, child: target),
    );
  }
}

double _chipHeight(bool large) => large ? 28 : 24;

/// The row under the address: the tags' tap targets, at least 44 high.
double _tagRowHeight(bool large) =>
    math.max(_chipHeight(large), IpDetailTagStyle.minHit);

const _chipSkeletonWidths = [48.0, 72.0];

class _IpChips extends ConsumerWidget {
  const _IpChips({
    required this.ip,
    required this.facts,
    required this.loading,
    required this.marked,
    required this.large,
    required this.onOpenDetail,
  });

  /// The address shown; null while there is none.
  final String? ip;
  final _IpFacts? facts;
  final bool loading;
  final bool marked;
  final bool large;

  /// Opens the shown address's detail; null while there is no address.
  final Future<void> Function()? onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    final facts = this.facts;
    final ip = this.ip;
    final height = _chipHeight(large);
    final onOpenDetail = ip == null ? null : this.onOpenDetail;
    Widget tag(
      String label, {
      DashboardChipTone tone = DashboardChipTone.idle,
    }) => IpDetailTag(
      label: label,
      tone: tone,
      height: height,
      semanticLabel: onOpenDetail == null
          ? [
              label,
              appLocalizations.ipTagNoIp,
            ].join(appLocalizations.semanticsSeparator)
          : hidden
          ? appLocalizations.ipTagOpenDetailHidden(label)
          : appLocalizations.ipTagOpenDetail(label, ip!),
      semanticHint: appLocalizations.ipTagOpenDetailHint,
      onOpen: onOpenDetail,
    );
    final known = [
      if (facts?.type case final type?) tag(type),
      if (facts?.quality case (final label, final tone)) tag(label, tone: tone),
    ];
    // Every tag shows whole: those that do not fit wrap onto a line of
    // their own, and the card grows to hold it.
    // Whatever ends a line leaves the reach of a tag's target empty below
    // it, so the last line never paints into the room the card lays over
    // the cells (see HitOverhang): a chip or a skeleton keeps it too.
    Widget reach(Widget child) => Padding(
      padding: EdgeInsets.only(bottom: ipDetailTagReach(height)),
      child: child,
    );
    final skeletons = [
      for (final width in _chipSkeletonWidths)
        reach(SkeletonPill(width: width, height: height)),
    ];
    final wrap = Wrap(
      spacing: IpDetailTagStyle.gap,
      runSpacing: IpDetailTagStyle.gap,
      children: [
        if (marked)
          reach(
            DashboardChip(
              label: appLocalizations.localExit,
              dot: true,
              dotColor: context.colorScheme.primary,
              large: large,
            ),
          ),
        if (known.isNotEmpty)
          ...known
        else if (loading)
          if (ip == null)
            Semantics(
              container: true,
              label: appLocalizations.ipTagNoIp,
              child: Wrap(spacing: IpDetailTagStyle.gap, children: skeletons),
            )
          else
            ...skeletons
        else
          tag(
            facts?.reportFailed ?? false
                ? appLocalizations.ipxNoResponse
                : facts?.pending ?? false
                ? appLocalizations.pendingQuery
                : appLocalizations.ipTypeUnknown,
          ),
      ],
    );
    // Every card, desktop or narrow, grows to take the tags that wrap:
    // none is clipped. At one line it keeps its height.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _tagRowHeight(large)),
      child: wrap,
    );
  }
}

const _spinPeriod = Duration(milliseconds: 1500);

/// What the badge knows of the shown exit.
enum _BadgeState {
  known,

  /// Nothing has been asked about it on the route in use.
  pending,

  /// The lookup failed with nothing to show.
  failed,

  /// The lookup failed; the last result for this route stays shown.
  stale,
}

/// The exit's country on a clover that looks the address up again when
/// tapped and turns while it is being looked up.
class _CountryBadge extends StatefulWidget {
  const _CountryBadge({
    required this.countryCode,
    required this.size,
    required this.box,
    required this.active,
    required this.checking,
    required this.announceChecking,
    required this.state,
    required this.onRefresh,
  });

  final String? countryCode;
  final double size;

  /// The tap target around the clover, no smaller than 44.
  final double box;
  final bool active;
  final bool checking;

  /// Says so when [checking] starts; a lookup the probe starts on its own
  /// goes by unannounced.
  final bool announceChecking;
  final _BadgeState state;
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
      // Only the lookup's own course is announced: the start of one the
      // user or the session's opening asked for, and a failure at its end.
      final appLocalizations = context.appLocalizations;
      final message = widget.checking
          ? (widget.announceChecking ? appLocalizations.statusQuerying : null)
          : switch (widget.state) {
              _BadgeState.failed => appLocalizations.queryFailed,
              _BadgeState.stale => appLocalizations.queryFailedShowingLast,
              _BadgeState.known || _BadgeState.pending => null,
            };
      if (message != null) {
        announceReadState(context, message);
      }
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
    final stale = widget.state == _BadgeState.stale && !widget.checking;
    final name = widget.checking
        ? appLocalizations.requery
        : switch (widget.state) {
            _BadgeState.known => appLocalizations.requery,
            _BadgeState.pending => appLocalizations.pendingQueryAction,
            _BadgeState.failed => appLocalizations.queryFailedTapToRetry,
            _BadgeState.stale => appLocalizations.queryFailedShowingLast,
          };
    final separator = appLocalizations.semanticsSeparator;
    // The globe stands in for a country, so it is never read as a global
    // exit: it says the region is unknown, to the eye and to a screen reader.
    final country = code?.toUpperCase() ?? '';
    final globe = country.isEmpty;
    final color = Color.alphaBlend(
      foreground.withValues(alpha: enabled && _hovered ? 0.08 : 0),
      DashboardColors.of(context).tone2,
    );
    // The label below names the badge once; the tooltip is for the eye.
    return Tooltip(
      message: globe
          ? [name, appLocalizations.regionUnknown].join(separator)
          : name,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: [
          name,
          globe ? appLocalizations.regionUnknown : country,
          if (widget.checking) appLocalizations.statusQuerying,
        ].join(separator),
        onTap: enabled ? widget.onRefresh : null,
        excludeSemantics: true,
        child: PressRegion(
          // Stays focusable while a lookup is out; the tap is ignored then.
          onTap: () {
            if (!widget.checking) {
              widget.onRefresh();
            }
          },
          mouseCursor: enabled ? null : SystemMouseCursors.basic,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          excludeFromSemantics: true,
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
                      child: globe
                          ? GlyphIcon(
                              AppGlyphs.proxies,
                              size: size * 0.42,
                              color: foreground,
                            )
                          : Text(
                              country,
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
                    if (stale)
                      PositionedDirectional(
                        top: -2,
                        end: -2,
                        child: _StaleMark(size: size < 48 ? 16 : 18),
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

/// An exclamation on the badge's corner: the last lookup failed and what
/// it found before is still shown.
class _StaleMark extends StatelessWidget {
  const _StaleMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // The glyph's circle spans 17.6 of its 24: grown to fill the mark, it
    // leaves a 1.5 ring of the card around it.
    final glyph = (size - 3) * 24 / 17.6;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: DashboardColors.of(context).card,
          shape: const CircleBorder(),
        ),
        child: OverflowBox(
          maxWidth: glyph,
          maxHeight: glyph,
          child: GlyphIcon(
            AppGlyphs.error,
            fill: 1,
            size: glyph,
            color: context.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

class _Cells extends StatelessWidget {
  const _Cells({
    required this.organization,
    required this.known,
    required this.loading,
    required this.active,
    required this.gap,
  });

  final String? organization;

  /// There is an exit to tell of, so a missing organization is unknown.
  final bool known;
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
                : known
                ? _CellText(appLocalizations.unknown)
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
