import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/features/features.dart';
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
import 'package:flutter/services.dart';
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

const _nameWidth = 64.0;
const _rowInset = EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 7);
const _lineHeight = 22.0;
const _secondLineHeight = 18.0;
const _ipMaxWidth = 150.0;
const _tagHeight = 20.0;
const _tagGap = 6.0;
const _copiedFor = Duration(milliseconds: 1500);
const _failureRed = Color(0xFFB3261E);
const _retryBlue = Color(0xFF0062CC);
const _retryBlueDark = Color(0xFF4DA3FF);

/// Where the traffic leaves by and the address this device has without
/// Flash, next to the start button.
class CurrentOutboundCard extends ConsumerStatefulWidget {
  const CurrentOutboundCard({super.key});

  @override
  ConsumerState<CurrentOutboundCard> createState() =>
      _CurrentOutboundCardState();
}

class _CurrentOutboundCardState extends ConsumerState<CurrentOutboundCard> {
  late final OutboundIpProbe _probe;

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
    final exit = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(routedOutbound)),
    );
    final local = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(directOutbound)),
    );
    // No live route (the Core is not connected, e.g. while the helper cannot
    // start it) and nothing out: no answer is coming, so the placeholders hold
    // still instead of pulsing, which would redraw the window every frame.
    final live = ref.watch(routeTrackerProvider.select((state) => state.live));
    bool stillFor(ProbeEntry<IpInfo> entry) =>
        entry.value == null && entry.phase != ProbePhase.probing && !live;
    final metrics = _OutboundMetrics.of(density);
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final exitIp = isStart ? _answerOf(exit) : null;
    final localIp = _answerOf(local);
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
            padding: metrics.padding,
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
                          _StatusChip(running: isStart, suspended: suspended),
                        ],
                      ),
                      const SizedBox(height: 12 - 7),
                      // Above the start button the rows lean out by their
                      // inset, so their text lines up with the title.
                      Transform.translate(
                        offset: Offset(
                          Directionality.of(context) == TextDirection.ltr
                              ? -8
                              : 8,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TickerMode(
                              enabled: !stillFor(exit),
                              child: ExitIpRow(
                                answer: exitIp,
                                running: isStart,
                                onRetry: () =>
                                    _probe.refresh(const [routedOutbound]),
                              ),
                            ),
                            _RowDivider(
                              end: metrics.dividerEnd(
                                Directionality.of(context),
                                grown: isStart ? 1 : 0,
                              ),
                            ),
                            TickerMode(
                              enabled: !stillFor(local),
                              child: LocalIpRow(
                                answer: localIp,
                                sameAsExit:
                                    exitIp?.ip != null &&
                                    exitIp?.ip == localIp.ip,
                                onRetry: () =>
                                    _probe.refresh(const [directOutbound]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: metrics.buttonSlot,
                  child: Center(
                    child: _StartToggle(
                      size: metrics.buttonSize,
                      enabled: hasProfile,
                      running: isStart,
                      suspended: suspended,
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
}

/// What a lookup has come to: an address, a failure, or neither yet.
@immutable
class IpAnswer {
  const IpAnswer.found(IpInfo this.info, {this.revalidating = false})
    : failed = false;

  const IpAnswer.failed() : info = null, failed = true, revalidating = false;

  const IpAnswer.pending() : info = null, failed = false, revalidating = false;

  final IpInfo? info;
  final bool failed;
  final bool revalidating;

  String? get ip => info?.ip;
}

IpAnswer _answerOf(ProbeEntry<IpInfo> entry) {
  if (entry.displayValue case final info?) {
    return IpAnswer.found(info, revalidating: entry.isLoading);
  }
  return entry.phase == ProbePhase.failed
      ? const IpAnswer.failed()
      : const IpAnswer.pending();
}

/// 运行中 · 02:14:05 while running; the time ticks here alone.
class _StatusChip extends ConsumerWidget {
  const _StatusChip({required this.running, required this.suspended});

  final bool running;
  final bool suspended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    if (suspended) {
      return DashboardChip(
        label: appLocalizations.suspended,
        tone: DashboardChipTone.warn,
        dot: true,
      );
    }
    if (!running) {
      return DashboardChip(label: appLocalizations.notRunning);
    }
    final time = getTimeText(ref.watch(runTimeProvider));
    return DashboardChip(
      label: '${appLocalizations.running} · $time',
      tone: DashboardChipTone.ok,
      dot: true,
    );
  }
}

class _OutboundMetrics {
  const _OutboundMetrics({
    required this.padding,
    required this.gap,
    required this.buttonSize,
    required this.buttonSlot,
    required this.decorationSize,
    required this.decorationEnd,
    required this.decorationTop,
  });

  factory _OutboundMetrics.of(DashboardDensity density) => switch (density) {
    DashboardDensity.standard => _OutboundMetrics(
      padding: dashboardCardPadding(density),
      gap: 16,
      buttonSize: 104,
      buttonSlot: 120,
      decorationSize: 290,
      decorationEnd: -64,
      decorationTop: -87,
    ),
    DashboardDensity.compact => _OutboundMetrics(
      padding: dashboardCardPadding(density),
      gap: 16,
      buttonSize: 84,
      buttonSlot: 100,
      decorationSize: 250,
      decorationEnd: -64,
      decorationTop: -75,
    ),
    DashboardDensity.mobile => const _OutboundMetrics(
      padding: EdgeInsetsDirectional.fromSTEB(20, 18, 16, 18),
      gap: 10,
      buttonSize: 88,
      buttonSlot: 88,
      decorationSize: 240,
      decorationEnd: -60,
      decorationTop: -66,
    ),
  };

  final EdgeInsetsGeometry padding;
  final double gap;
  final double buttonSize;
  final double buttonSlot;
  final double decorationSize;
  final double decorationEnd;
  final double decorationTop;

  /// How far the divider stops short of the rows' end, so that it ends
  /// [_dividerClearance] before the backdrop behind the start button. The
  /// rows lean out by their 8 inset, and the backdrop sits [decorationEnd]
  /// in from the card's end.
  /// [grown] runs from the resting backdrop at 0 to the running one at 1,
  /// which swells about its centre by [_decorationGrowth]. Its rounded
  /// lobes stand [_decorationInset] of its size in from its box.
  double dividerEnd(TextDirection direction, {required double grown}) {
    final end = padding.resolve(direction).end(direction);
    final size = decorationSize * (1 + _decorationGrowth * grown);
    final left =
        decorationEnd -
        (size - decorationSize) / 2 +
        size * (1 - _decorationInset);
    return math.max(0, left + _dividerClearance - 8 - gap - buttonSlot - end);
  }
}

/// How far the cookie's leftmost lobe sits in from its box, of its size.
const double _decorationInset = 0.015;

const double _dividerClearance = 16;

extension on EdgeInsets {
  double end(TextDirection direction) =>
      direction == TextDirection.ltr ? right : left;
}

/// The flag emoji of a two-letter country [code], from its regional
/// indicators; none for anything else.
@visibleForTesting
String? flagOf(String? code) {
  if (code == null || !RegExp(r'^[A-Za-z]{2}$').hasMatch(code)) {
    return null;
  }
  const regionalA = 0x1F1E6;
  return String.fromCharCodes([
    for (final unit in code.toUpperCase().codeUnits) regionalA + unit - 0x41,
  ]);
}

TextStyle _nameStyle(BuildContext context) => AppTextStyle.caption1
    .of(context)
    .copyWith(color: context.colorScheme.onSurfaceVariant);

TextStyle _ipStyle(BuildContext context) => AppTextStyle.subheadline
    .of(context, emphasized: true)
    .copyWith(color: context.colorScheme.onSurface, height: 1.2)
    .toJetBrainsMono;

TextStyle _detailStyle(BuildContext context) => AppTextStyle.caption1
    .of(context)
    .copyWith(color: context.colorScheme.onSurfaceVariant);

class _Name extends StatelessWidget {
  const _Name(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _nameWidth,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _nameStyle(context),
      ),
    );
  }
}

/// [ip], or the mask while addresses are hidden, no wider than
/// [_ipMaxWidth]: a long IPv6 address loses its middle, never its ends.
class _IpText extends ConsumerWidget {
  const _IpText(this.ip);

  final String ip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    final style = _ipStyle(context);
    // An IPv4 address always fits; only IPv6 runs long enough to cut.
    final text = hidden
        ? ipMask
        : !ip.contains(':')
        ? ip
        : middleEllipsis(
            ip,
            style: style,
            maxWidth: _ipMaxWidth,
            textScaler: MediaQuery.textScalerOf(context),
          );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _ipMaxWidth),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: style,
      ),
    );
  }
}

/// [text] whole if it fits [maxWidth], else its two ends around an ellipsis.
String middleEllipsis(
  String text, {
  required TextStyle style,
  required double maxWidth,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  double widthOf(String value) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  if (widthOf(text) <= maxWidth) {
    return text;
  }
  var keep = text.length - 1;
  while (keep > 2) {
    final head = (keep + 1) ~/ 2;
    final candidate =
        '${text.substring(0, head)}…${text.substring(text.length - (keep - head))}';
    if (widthOf(candidate) <= maxWidth) {
      return candidate;
    }
    keep--;
  }
  return '…';
}

/// A small label after the address: idle grey unless [background] says
/// otherwise.
class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.background, this.foreground});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = DashboardColors.of(context);
    return Container(
      height: _tagHeight,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: ShapeDecoration(
        color: background ?? colors.tone,
        shape: AppShape.all(8),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: AppTextStyle.caption1
              .of(context, emphasized: true)
              .toTabular
              .copyWith(
                color: foreground ?? context.colorScheme.onSurfaceVariant,
                height: 1,
              ),
        ),
      ),
    );
  }
}

(Color, Color)? _gradeColors(BuildContext context, IpxGrade grade) {
  final colors = DashboardColors.of(context);
  return switch (grade) {
    IpxGrade.aPlus || IpxGrade.a => (colors.okContainer, colors.onOkContainer),
    IpxGrade.b => null,
    IpxGrade.c => (colors.warnContainer, colors.onWarnContainer),
    IpxGrade.d => (
      context.colorScheme.errorContainer,
      context.colorScheme.onErrorContainer,
    ),
  };
}

/// 查询失败 in red and a 重试 after it.
class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry, this.label, this.quiet = false});

  final VoidCallback onRetry;

  /// What failed; the lookup of the address itself otherwise.
  final String? label;

  /// Only a report is missing under an address in hand: it says so in the
  /// detail's grey, not the failure's red.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final dark = context.colorScheme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Flexible(
          child: Text(
            label ?? appLocalizations.queryFailed,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: quiet
                ? _detailStyle(context)
                : AppTextStyle.subheadline
                      .of(context, emphasized: true)
                      .copyWith(
                        color: dark ? context.colorScheme.error : _failureRed,
                        height: 1.2,
                      ),
          ),
        ),
        FocusRing(
          shape: AppShape.xs,
          standsOff: true,
          child: PressRegion(
            onTap: onRetry,
            shape: AppShape.xs,
            overlay: PressRegion.focusOverlay,
            child: Semantics(
              button: true,
              child: Text(
                appLocalizations.retry,
                maxLines: 1,
                style: AppTextStyle.footnote
                    .of(context, emphasized: true)
                    .copyWith(color: dark ? _retryBlueDark : _retryBlue),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The exit: its address, ipx.al's grade and verdicts, and who runs it
/// where. It opens the full report.
class ExitIpRow extends ConsumerWidget {
  const ExitIpRow({
    super.key,
    required this.answer,
    required this.running,
    required this.onRetry,
  });

  /// Null while Flash is not running: there is no exit to show.
  final IpAnswer? answer;
  final bool running;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final answer = this.answer;
    final info = answer?.info;
    final detailStyle = _detailStyle(context);
    final ipStyle = _ipStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    // Larger text grows each line with it.
    Widget line(double height, Widget child) => SizedBox(
      height: scaler.scale(height),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    );
    Widget detail(String text) => Tooltip(
      message: text,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: detailStyle,
      ),
    );

    if (answer == null || info == null) {
      final first = switch (answer) {
        null => Text('—', style: ipStyle),
        IpAnswer(failed: true) => _Failure(onRetry: onRetry),
        _ => const Row(
          spacing: _tagGap,
          children: [
            SkeletonPill(width: 120, height: 14),
            SkeletonPill(width: 44, height: _tagHeight),
          ],
        ),
      };
      final second = switch (answer) {
        null => detail(appLocalizations.exitNotRunning),
        IpAnswer(failed: true) => detail(appLocalizations.exitIpLookupFailed),
        _ => const SkeletonPill(width: 180, height: 10),
      };
      return Padding(
        padding: _rowInset,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(_lineHeight, _Name(appLocalizations.exitIpRow)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(_lineHeight, first),
                  line(_secondLineHeight, second),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final ip = info.ip;
    final lookup = ref.watch(ipxLookupProvider(ip));
    final report = lookup.report;
    final brief = lookup.brief;
    final grade = report?.grade;
    final score = report?.score;
    final gradeColors = grade == null ? null : _gradeColors(context, grade);
    final type = report?.type;
    final nativity = report?.nativity;
    final typeLabel = type == null || type == IpxIpType.unknown
        ? null
        : type.label(context);
    final nativityLabel = switch (nativity) {
      IpxNativity.native => appLocalizations.ipxNativeShort,
      IpxNativity.broadcast => appLocalizations.ipxBroadcastShort,
      _ => null,
    };
    final organization = report?.organization ?? brief?.organization;
    final asn = report?.asn ?? brief?.asn;
    final network = organization ?? (asn == null ? null : 'AS$asn');
    final country =
        report?.countryCode ?? brief?.countryCode ?? info.countryCode;
    final city = report?.city ?? brief?.city;
    final place = [if (country.isNotEmpty) country, ?city].join(' ');
    final flag = flagOf(country);
    final shownPlace = [?flag, if (place.isNotEmpty) place].join(' ');
    final summary = [
      if (answer.revalidating) appLocalizations.querying,
      ?network,
      if (shownPlace.isNotEmpty) shownPlace,
    ].join(' · ');
    final pending = lookup.isLoading && report == null;
    // The address is known; only ipx.al's report about it is missing.
    final reportFailed =
        lookup.phase == IpxPhase.failed && report == null && !lookup.retrying;
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    final separator = appLocalizations.semanticsSeparator;
    final semanticLabel = [
      appLocalizations.exitIp,
      if (answer.revalidating) appLocalizations.querying,
      hidden ? appLocalizations.hideIp : ip,
      if (score != null && grade != null)
        appLocalizations.ipxScoreSemantics('$score', grade.letter),
      ?typeLabel,
      ?nativityLabel,
      ?network,
      if (place.isNotEmpty) place,
      if (reportFailed) appLocalizations.ipxNoResponse,
    ].join(separator);
    final second = summary.isNotEmpty || !pending
        ? detail(summary)
        : const SkeletonPill(width: 180, height: 10);
    void open() => unawaited(
      showIpQualitySheet(
        context,
        ip: ip,
        countryCode: info.countryCode,
        title: appLocalizations.exitIp,
      ),
    );
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      hint: appLocalizations.exitIpOpenHint,
      onTap: open,
      excludeSemantics: true,
      child: FocusRing(
        shape: AppShape.all(10),
        child: PressRegion(
          onTap: open,
          shape: AppShape.all(10),
          overlay: PressRegion.hoverOverlay,
          child: Padding(
            padding: _rowInset,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(_lineHeight, _Name(appLocalizations.exitIpRow)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(
                        _lineHeight,
                        ClipRect(
                          child: Row(
                            children: [
                              _IpText(ip),
                              const SizedBox(width: _tagGap),
                              Flexible(
                                child: Wrap(
                                  spacing: _tagGap,
                                  runSpacing: _lineHeight,
                                  clipBehavior: Clip.hardEdge,
                                  children: [
                                    if (score != null && grade != null)
                                      _Tag(
                                        '$score · ${grade.letter}',
                                        background: gradeColors?.$1,
                                        foreground: gradeColors?.$2,
                                      ),
                                    if (typeLabel != null) _Tag(typeLabel),
                                    if (nativityLabel != null)
                                      _Tag(nativityLabel),
                                    if (reportFailed)
                                      _Failure(
                                        label: appLocalizations.ipxNoResponse,
                                        quiet: true,
                                        onRetry: () => ref
                                            .read(
                                              ipxLookupProvider(ip).notifier,
                                            )
                                            .retry(),
                                      ),
                                    if (pending)
                                      const SkeletonPill(
                                        width: 44,
                                        height: _tagHeight,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      line(_secondLineHeight, second),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A hairline under the exit, from the address column on.
class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.end});

  /// Where it stops short of the rows' end.
  final double end;

  @override
  Widget build(BuildContext context) {
    final dark = context.colorScheme.brightness == Brightness.dark;
    return AnimatedPadding(
      duration: context.motionDuration(_morphDuration),
      curve: Curves.easeOutBack,
      padding: EdgeInsetsDirectional.only(
        start: 8 + _nameWidth + 2,
        end: end,
        top: 8 - 7,
        bottom: 6,
      ),
      child: SizedBox(
        height: 1,
        child: ColoredBox(
          color: dark
              ? context.colorScheme.onSurface.withValues(alpha: 0.1)
              : const Color(0xFFEEEBEF),
        ),
      ),
    );
  }
}

/// The address this device has on its own, looked up straight, never
/// through a node; nothing to open.
class LocalIpRow extends ConsumerWidget {
  const LocalIpRow({
    super.key,
    required this.answer,
    required this.sameAsExit,
    required this.onRetry,
  });

  final IpAnswer answer;

  /// Both lookups answered, with the same address.
  final bool sameAsExit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final ip = answer.ip;
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    final Widget content = switch (answer) {
      IpAnswer(failed: true) => _Failure(onRetry: onRetry),
      IpAnswer(ip: null) => const SkeletonPill(width: 110, height: 14),
      _ => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label:
                '${appLocalizations.localPublicIp}'
                '${appLocalizations.semanticsSeparator}'
                '${hidden ? appLocalizations.hideIp : ip}'
                '${answer.revalidating ? '${appLocalizations.semanticsSeparator}${appLocalizations.querying}' : ''}',
            excludeSemantics: true,
            child: _IpText(ip!),
          ),
          if (!hidden) ...[
            const SizedBox(width: 2),
            _CopyButton(text: ip, tooltip: appLocalizations.copyLocalPublicIp),
          ],
          if (answer.revalidating || sameAsExit)
            Padding(
              padding: EdgeInsetsDirectional.only(start: hidden ? 8 : 4),
              child: Text(
                answer.revalidating
                    ? appLocalizations.querying
                    : appLocalizations.sameAsExit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _detailStyle(context),
              ),
            ),
        ],
      ),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      child: SizedBox(
        height: MediaQuery.textScalerOf(context).scale(_lineHeight),
        child: Row(
          children: [
            ExcludeSemantics(
              excluding: ip != null,
              child: _Name(appLocalizations.localPublicIpRow),
            ),
            Expanded(
              child: ClipRect(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies [text] and shows a tick for a moment.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text, required this.tooltip});

  final String text;
  final String tooltip;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) {
      return;
    }
    _reset?.cancel();
    setState(() => _reset = Timer(_copiedFor, _done));
  }

  void _done() {
    if (mounted) {
      setState(() => _reset = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _lineHeight,
      child: DashboardIconButton(
        glyph: _reset == null ? AppGlyphs.copy : AppGlyphs.check,
        glyphSize: 16,
        tooltip: widget.tooltip,
        onPressed: _copy,
      ),
    );
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
