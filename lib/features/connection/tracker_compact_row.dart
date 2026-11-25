import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'process_view.dart';
import 'route_reason.dart';
import 'tracker_info_item.dart';

const _rowMinHeight = 48.0;
const _rowPadding = 12.0;
const _rowMargin = 4.0;
const _itemGap = 4.0;
const _trailingGap = 8.0;
const _iconSize = 24.0;
const _hostMinChars = 6;

/// The widest whole number a speed reads before its unit steps up.
const _speedValueTemplate = '1024';

const _processMaxChars = 9;

const _processMaxShare = 0.3;

/// What every compact row of one list shares at the current text size.
@immutable
class TrackerCompactMetrics {
  final double rowHeight;
  final TextStyle process;
  final TextStyle host;
  final TextStyle secondary;
  final TextStyle speed;
  final double hostMinWidth;
  final double processMinWidth;
  final double processMaxWidth;
  final double arrowSize;

  final double speedWidth;

  const TrackerCompactMetrics._({
    required this.rowHeight,
    required this.process,
    required this.host,
    required this.secondary,
    required this.speed,
    required this.hostMinWidth,
    required this.processMinWidth,
    required this.processMaxWidth,
    required this.arrowSize,
    required this.speedWidth,
  });

  static final _cache = <Object, TrackerCompactMetrics>{};

  factory TrackerCompactMetrics.of(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final colorScheme = context.colorScheme;
    final host = AppTextStyle.subheadline
        .of(context)
        .copyWith(color: colorScheme.onSurface);
    final process = AppTextStyle.subheadline
        .of(context, emphasized: true)
        .copyWith(color: colorScheme.onSurface);
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final key = (scaler, MediaQuery.boldTextOf(context), host, secondary);
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    if (_cache.length > 16) {
      _cache.clear();
    }
    final measure = MeasureScope.of(context);
    final speed = secondary.toTabular;
    double widthOf(String text, TextStyle style) =>
        measure.computeTextSize(Text(text, style: style)).width;
    double heightOf(TextStyle style) =>
        measure.computeTextSize(Text('Hg', style: style)).height;
    final tallest = [
      heightOf(process),
      heightOf(host),
      heightOf(secondary),
    ].reduce(max);
    final arrowSize = scaler.scale(12);
    final unitWidth = TrafficUnit.values
        .map((unit) => widthOf(' ${unit.name}/s', speed))
        .reduce(max);
    return _cache[key] = TrackerCompactMetrics._(
      rowHeight: max(_rowMinHeight, tallest + 12),
      process: process,
      host: host,
      secondary: secondary,
      speed: speed,
      hostMinWidth: widthOf('0' * _hostMinChars, host),
      processMinWidth: widthOf('0' * _hostMinChars, process),
      processMaxWidth: widthOf('0' * _processMaxChars, process),
      arrowSize: arrowSize,
      speedWidth:
          2 * (arrowSize + 2 + widthOf(_speedValueTemplate, speed)) +
          _itemGap +
          unitWidth,
    );
  }
}

enum TrackerTrailing { speed, exit, note }

/// What of a compact row fits in [width], after its icon, which always
/// stays. The process name column takes its share of the row, between
/// [processMinWidth] and [processMaxWidth], and the host keeps at least
/// [hostMinWidth]; a live list's column gives way to its least so speeds
/// fit, alike on every row but for [rewriteWidth], a mark only some carry.
/// Then trailing parts fit in what is left or go, note first,
/// then exit, then speeds, each whole and never cut short. Only a row still
/// too narrow shrinks the name with the host, and drops it under half its
/// least. [processWidth] in the result is null where the name goes.
@visibleForTesting
({Set<TrackerTrailing> trailing, double? processWidth})
layoutTrackerCompactRow({
  required double width,
  required double leadWidth,
  required double marksWidth,
  double rewriteWidth = 0,
  required double hostMinWidth,
  required double processMinWidth,
  required double processMaxWidth,
  double? speedWidth,
  double? exitWidth,
  double? noteWidth,
}) {
  final inner = width - 2 * _rowPadding;
  var column = (inner * _processMaxShare)
      .clamp(processMinWidth, max(processMinWidth, processMaxWidth))
      .toDouble();
  final aligned = inner - leadWidth - marksWidth - _itemGap;
  if (speedWidth != null) {
    final yielded = aligned - hostMinWidth - _trailingGap - speedWidth;
    if (yielded < column) column = max(processMinWidth, yielded);
  }
  final shared = aligned - rewriteWidth;
  final widths = {
    TrackerTrailing.speed: ?speedWidth,
    TrackerTrailing.exit: ?exitWidth,
    TrackerTrailing.note: ?noteWidth,
  };
  final room = shared - column - hostMinWidth - _trailingGap;
  double trailing() => widths.isEmpty
      ? 0
      : widths.values.reduce((a, b) => a + b) + _itemGap * (widths.length - 1);
  for (final part in [
    TrackerTrailing.note,
    TrackerTrailing.exit,
    TrackerTrailing.speed,
  ]) {
    if (trailing() <= room) break;
    widths.remove(part);
  }
  double? process = column;
  if (shared - hostMinWidth < column) {
    final least = processMinWidth / (processMinWidth + hostMinWidth);
    process = shared - hostMinWidth >= processMinWidth
        ? shared - hostMinWidth
        : shared * least;
    if (process < processMinWidth / 2) process = null;
  }
  return (trailing: widths.keys.toSet(), processWidth: process);
}

/// Both speeds of a live row as whole numbers in the larger one's unit,
/// as the row reads them: up, down, and the unit they share.
@visibleForTesting
(String, String, String) trackerCompactSpeeds(num up, num down) {
  const units = TrafficUnit.values;
  var top = max(up, down).toDouble();
  var unit = 0;
  while (top >= 1024 && unit < units.length - 1) {
    top /= 1024;
    unit++;
  }
  final scale = pow(1024, unit);
  String value(num speed) {
    final scaled = speed / scale;
    return scaled > 0 && scaled < 0.5 ? '<1' : scaled.toStringAsFixed(0);
  }

  return (value(up), value(down), '${units[unit].name}/s');
}

String trackerTargetText(TrackerInfo trackerInfo) {
  final port = trackerInfo.metadata.destinationPort;
  final title = trackerInfo.title;
  return port.isEmpty ? title : '$title:$port';
}

/// A note a recent row may show where its network goes: the short reason
/// the Core gave for a request no rule matched, else the network.
String trackerCompactNote(BuildContext context, TrackerInfo trackerInfo) {
  final metadata = trackerInfo.metadata;
  if (trackerInfo.rule.isEmpty &&
      (metadata.routeReason.isNotEmpty || metadata.udpSkipped.isNotEmpty)) {
    return RouteReason(trackerInfo).short(context.appLocalizations);
  }
  return metadata.network.toUpperCase();
}

/// One connection on one line, under [recordTableMinWidth]: app icon,
/// decryption mark, host and port, rewrite mark, then what fits after it.
class TrackerCompactRow extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final bool isLive;
  final String detailTitle;
  final TrackerCompactMetrics metrics;
  final ValueChanged<TrackerInfo>? onClose;
  final ValueGetter<TrackerInfo>? latest;

  const TrackerCompactRow({
    super.key,
    required this.trackerInfo,
    required this.isLive,
    required this.detailTitle,
    required this.metrics,
    this.onClose,
    this.latest,
  });

  String _summary(BuildContext context, String? processName) {
    final l = context.appLocalizations;
    final badge = MitmBadge.of(trackerInfo);
    final rewrite = MitmRewriteBadge.of(trackerInfo);
    final exit = trackerInfo.chains.firstOrNull ?? '';
    return [
      ?processName,
      trackerTargetText(trackerInfo),
      ?badge?.semanticsLabel(context),
      ?rewrite?.semanticsLabel(context),
      if (exit.isNotEmpty) '${l.outboundExit} $exit',
    ].join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (system.isAndroid) {
      final package = trackerInfo.metadata.process;
      return _buildRow(context, ref, null, package.isEmpty ? null : package);
    }
    return ConnectionProcessBuilder(
      metadata: trackerInfo.metadata,
      builder: (context, process) => _buildRow(
        context,
        ref,
        process,
        process.kind == ProcessKind.unknown ? null : processLabelOf(process),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    WidgetRef ref,
    ConnectionProcess? process,
    String? processName,
  ) {
    final mitmOn =
        MitmBadge.of(trackerInfo) != null ||
        (mitmFeature &&
            ref.watch(
              patchClashConfigProvider.select((state) => state.mitm.enable),
            ));
    final hasRewrite = MitmRewriteBadge.of(trackerInfo) != null;
    final exit = trackerInfo.chains.firstOrNull ?? '';
    final note = isLive ? null : trackerCompactNote(context, trackerInfo);
    final measure = MeasureScope.of(context);
    const leadWidth = _iconSize + _itemGap;
    const rewriteMark = MitmBadge.gap + MitmBadge.iconSize;
    // With decryption on, every row keeps room for a rewrite mark, so the
    // rows of a list line up whichever carry one.
    final marksWidth = mitmOn ? MitmBadgeSlot.width + rewriteMark : 0.0;
    final rewriteWidth = hasRewrite && !mitmOn ? rewriteMark : 0.0;
    final colorScheme = context.colorScheme;
    return Semantics(
      container: true,
      label: _summary(context, processName),
      child: ContextMenuRegion(
        menuBuilder: (menuContext) =>
            trackerInfoMenuItems(context, trackerInfo, onClose: onClose),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _rowMargin),
          child: PressSurface(
            fill: const Color(0x00000000),
            shape: AppShape.md,
            childFills: true,
            onPressed: () => showTrackerInfoDetail(
              context,
              latest?.call() ?? trackerInfo,
              detailTitle,
            ),
            child: SizedBox(
              height: metrics.rowHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = layoutTrackerCompactRow(
                    width: constraints.maxWidth,
                    leadWidth: leadWidth,
                    marksWidth: marksWidth,
                    rewriteWidth: rewriteWidth,
                    hostMinWidth: metrics.hostMinWidth,
                    processMinWidth: metrics.processMinWidth,
                    processMaxWidth: metrics.processMaxWidth,
                    speedWidth: isLive ? metrics.speedWidth : null,
                    exitWidth: exit.isEmpty
                        ? null
                        : TonalChip.widthOf(context, exit),
                    noteWidth: note == null || note.isEmpty
                        ? null
                        : measure
                              .computeTextSize(
                                Text(note, style: metrics.secondary),
                              )
                              .width,
                  );
                  const dividerStart = _rowPadding + leadWidth;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _rowPadding,
                        ),
                        child: Row(
                          children: [
                            _buildIcon(context, process),
                            const SizedBox(width: _itemGap),
                            // Held without a name so hosts line up.
                            if (layout.processWidth case final width?) ...[
                              SizedBox(
                                width: width,
                                child: ExcludeSemantics(
                                  child: Text(
                                    processName ?? '',
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: metrics.process,
                                  ),
                                ),
                              ),
                              const SizedBox(width: _itemGap),
                            ],
                            Expanded(
                              child: MitmHostLine(
                                trackerInfo: trackerInfo,
                                host: ExcludeSemantics(
                                  child: Text(
                                    trackerTargetText(trackerInfo),
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: metrics.host,
                                  ),
                                ),
                              ),
                            ),
                            ..._buildTrailing(context, layout, exit, note),
                          ],
                        ),
                      ),
                      PositionedDirectional(
                        start: dividerStart,
                        end: 0,
                        bottom: 0,
                        child: Container(
                          height: 0,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.14,
                                ),
                                width: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, ConnectionProcess? connection) {
    if (connection != null) {
      return connection.hasProcess
          ? ProcessFilterIcon(process: connection, size: _iconSize)
          : ExcludeSemantics(
              child: ProcessIcon(process: connection, size: _iconSize),
            );
    }
    final process = trackerInfo.metadata.process;
    return OwnPackageIcon(
      packageName: process,
      size: _iconSize,
      builder: (context, icon) => icon == null
          ? const SizedBox.square(dimension: _iconSize)
          : Semantics(
              button: true,
              label: context.appLocalizations.filterByThisApp,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => RecordFilterScope.add(
                  context,
                  RecordFilter(RecordFacetKind.app, process),
                ),
                child: icon,
              ),
            ),
    );
  }

  List<Widget> _buildTrailing(
    BuildContext context,
    ({Set<TrackerTrailing> trailing, double? processWidth}) layout,
    String exit,
    String? note,
  ) {
    final parts = <Widget>[
      if (layout.trailing.contains(TrackerTrailing.speed)) _buildSpeed(context),
      if (layout.trailing.contains(TrackerTrailing.exit)) _ExitChip(exit: exit),
      if (layout.trailing.contains(TrackerTrailing.note))
        ExcludeSemantics(
          child: Text(
            note!,
            maxLines: 1,
            softWrap: false,
            style: metrics.secondary,
          ),
        ),
    ];
    if (parts.isEmpty) return const [];
    // The part kept longest ends the row, where it lines up down the list.
    return [
      const SizedBox(width: _trailingGap),
      for (final (index, part) in parts.reversed.indexed) ...[
        if (index > 0) const SizedBox(width: _itemGap),
        part,
      ],
    ];
  }

  Widget _buildSpeed(BuildContext context) {
    final color = context.colorScheme.onSurfaceVariant;
    final (up, down, unit) = trackerCompactSpeeds(
      trackerInfo.uploadSpeed ?? 0,
      trackerInfo.downloadSpeed ?? 0,
    );
    Text text(String value) =>
        Text(value, maxLines: 1, softWrap: false, style: metrics.speed);
    // Read in the detail: a screen reader is not read new speeds each second.
    return ExcludeSemantics(
      child: SizedBox(
        width: metrics.speedWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GlyphIcon(AppGlyphs.arrowUp, size: metrics.arrowSize, color: color),
            const SizedBox(width: 2),
            text(up),
            const SizedBox(width: _itemGap),
            GlyphIcon(
              AppGlyphs.arrowDown,
              size: metrics.arrowSize,
              color: color,
            ),
            const SizedBox(width: 2),
            text('$down $unit'),
          ],
        ),
      ),
    );
  }
}

class _ExitChip extends StatelessWidget {
  final String exit;

  const _ExitChip({required this.exit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Semantics(
      button: true,
      label: '${context.appLocalizations.filterByThisNode} $exit',
      excludeSemantics: true,
      child: TonalChip(
        label: exit,
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        foregroundColor: colorScheme.onSurfaceVariant,
        onPressed: () => RecordFilterScope.add(
          context,
          RecordFilter(RecordFacetKind.proxy, exit),
        ),
      ),
    );
  }
}
