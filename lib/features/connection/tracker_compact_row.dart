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

/// A host reads this much, as www.example.com, before anything trails it.
const _hostReadableChars = 15;

/// A running host reads this much, as www.exampl…, before its speeds.
const _liveHostReadableChars = 10;

/// The widest whole number a speed reads before its unit steps up.
const _speedValueTemplate = '999';

const _processMaxShare = 0.3;

const _iconPadding = EdgeInsetsDirectional.only(
  start: _rowPadding,
  end: _itemGap,
);

enum _Measured { process, host, note, exit }

/// What every compact row of one list shares at the current text size.
class TrackerCompactMetrics {
  final double rowHeight;
  final TextStyle process;
  final TextStyle host;
  final TextStyle secondary;
  final TextStyle speed;
  final double hostMinWidth;
  final double processMinWidth;
  final double arrowSize;

  final double speedWidth;
  final TextStyle _chip;
  final double _chipPadding;
  final _widths = <(_Measured, String), double>{};

  TrackerCompactMetrics._({
    required this.rowHeight,
    required this.process,
    required this.host,
    required this.secondary,
    required this.speed,
    required this.hostMinWidth,
    required this.processMinWidth,
    required this.arrowSize,
    required this.speedWidth,
    required TextStyle chip,
    required double chipPadding,
  }) : _chip = chip,
       _chipPadding = chipPadding;

  static final _cache = <Object, TrackerCompactMetrics>{};

  factory TrackerCompactMetrics.of(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final bold = MediaQuery.boldTextOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final direction = Directionality.of(context);
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
    final key = (scaler, bold, locale, direction, host, secondary);
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    if (_cache.length > 16) {
      _cache.clear();
    }
    final speed = secondary.toTabular;
    double widthOf(String text, TextStyle style) =>
        _measure(context, text, style);
    double heightOf(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Hg', style: style),
        textScaler: scaler,
        locale: locale,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      try {
        return painter.height;
      } finally {
        painter.dispose();
      }
    }

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
      arrowSize: arrowSize,
      speedWidth:
          2 * (arrowSize + 2 + widthOf(_speedValueTemplate, speed)) +
          _itemGap +
          unitWidth,
      chip: AppTextStyle.caption1.of(context, emphasized: true),
      chipPadding: TonalChip.widthOf(context, '').ceilToDouble(),
    );
  }

  /// As Text draws it, Bold Text and language included, rounded up.
  static double _measure(BuildContext context, String text, TextStyle style) =>
      EmojiText.widthOf(context, text, style).ceilToDouble();

  double _widthOf(BuildContext context, _Measured kind, String text) {
    if (_widths.length > 4096) _widths.clear();
    return _widths[(kind, text)] ??=
        _measure(context, text, switch (kind) {
          _Measured.process => process,
          _Measured.host => host,
          _Measured.note => secondary,
          _Measured.exit => _chip,
        }) +
        (kind == _Measured.exit ? _chipPadding : 0);
  }

  double processWidthOf(BuildContext context, String name) =>
      _widthOf(context, _Measured.process, name);

  /// [host] whole up to its readable length, then an ellipsis for the rest.
  double hostReadableWidthOf(
    BuildContext context,
    String target, {
    required String host,
    bool live = false,
  }) {
    final chars = live ? _liveHostReadableChars : _hostReadableChars;
    final head = host.length <= chars ? host : host.substring(0, chars);
    return _widthOf(
      context,
      _Measured.host,
      head == target ? head : '$head\u2026',
    );
  }

  double noteWidthOf(BuildContext context, String note) =>
      _widthOf(context, _Measured.note, note);

  double exitWidthOf(BuildContext context, String exit) =>
      _widthOf(context, _Measured.exit, exit);
}

enum TrackerTrailing { speed, exit, note }

/// What of a compact row fits in [width], after its icon, which always
/// stays. The name takes its own width up to 30% of the row; trailing parts
/// show while the host keeps [hostReadableWidth], dropped note, exit, then
/// speeds; only a row too narrow for [hostMinWidth] shrinks the name.
@visibleForTesting
({Set<TrackerTrailing> trailing, double? processWidth})
layoutTrackerCompactRow({
  required double width,
  required double leadWidth,
  required double marksWidth,
  required double? processWidth,
  required double processMinWidth,
  required double hostReadableWidth,
  required double hostMinWidth,
  double? speedWidth,
  double? exitWidth,
  double? noteWidth,
}) {
  final inner = width - 2 * _rowPadding;
  final shared = inner - leadWidth - marksWidth;
  double? process = processWidth == null
      ? null
      : min(processWidth, inner * _processMaxShare);
  final nameSpan = process == null ? 0.0 : process + _itemGap;
  final widths = {
    TrackerTrailing.speed: ?speedWidth,
    TrackerTrailing.exit: ?exitWidth,
    TrackerTrailing.note: ?noteWidth,
  };
  final room = shared - nameSpan - hostReadableWidth - _trailingGap;
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
  if (process != null && shared - nameSpan < hostMinWidth) {
    final least = min(processMinWidth, process);
    final left = shared - _itemGap - hostMinWidth;
    process = left >= least
        ? left
        : (shared - _itemGap) * least / (least + hostMinWidth);
    if (process < least / 2) process = null;
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
  // Rounded, 999.5 would read as four digits.
  while (top >= 999.5 && unit < units.length - 1) {
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

  String _summary(BuildContext context, String? processName, String? note) {
    final l = context.appLocalizations;
    final badge = MitmBadge.of(trackerInfo);
    final rewrite = MitmRewriteBadge.of(trackerInfo);
    final exit = trackerInfo.chains.firstOrNull ?? '';
    return [
      ?processName,
      trackerTargetText(trackerInfo),
      ?badge?.semanticsLabel(context),
      ?rewrite?.semanticsLabel(context),
      if (note != null && note.isNotEmpty) note,
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
    final exit = trackerInfo.chains.firstOrNull ?? '';
    final note = isLive ? null : trackerCompactNote(context, trackerInfo);
    final target = trackerTargetText(trackerInfo);
    const leadWidth = _iconSize + _itemGap;
    final marksWidth =
        (mitmOn ? MitmBadgeSlot.width : 0.0) +
        (MitmRewriteBadge.of(trackerInfo) != null
            ? MitmBadge.gap + MitmBadge.iconSize
            : 0.0);
    final colorScheme = context.colorScheme;
    return ContextMenuRegion(
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
          // On the node that opens the detail, so it is read with its action.
          child: Semantics(
            label: _summary(context, processName, note),
            child: SizedBox(
              height: metrics.rowHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = layoutTrackerCompactRow(
                    width: constraints.maxWidth,
                    leadWidth: leadWidth,
                    marksWidth: marksWidth,
                    processWidth: processName == null || processName.isEmpty
                        ? null
                        : metrics.processWidthOf(context, processName),
                    processMinWidth: metrics.processMinWidth,
                    hostReadableWidth: metrics.hostReadableWidthOf(
                      context,
                      target,
                      host: trackerInfo.title,
                      live: isLive,
                    ),
                    hostMinWidth: metrics.hostMinWidth,
                    speedWidth: isLive ? metrics.speedWidth : null,
                    exitWidth: exit.isEmpty
                        ? null
                        : metrics.exitWidthOf(context, exit),
                    noteWidth: note == null || note.isEmpty
                        ? null
                        : metrics.noteWidthOf(context, note),
                  );
                  const dividerStart = _rowPadding + leadWidth;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: _rowPadding,
                        ),
                        child: Row(
                          children: [
                            _buildIcon(context, process),
                            if (layout.processWidth case final width?) ...[
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: width),
                                child: ExcludeSemantics(
                                  child: Text(
                                    processName!,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    textWidthBasis: TextWidthBasis.longestLine,
                                    style: metrics.process,
                                  ),
                                ),
                              ),
                              const SizedBox(width: _itemGap),
                            ],
                            Expanded(
                              child: ExcludeSemantics(
                                child: MitmHostLine(
                                  trackerInfo: trackerInfo,
                                  host: Text(
                                    target,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    textWidthBasis: TextWidthBasis.longestLine,
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
          ? Semantics(
              container: true,
              child: ProcessFilterIcon(
                process: connection,
                size: _iconSize,
                targetHeight: metrics.rowHeight,
                targetPadding: _iconPadding,
              ),
            )
          : ExcludeSemantics(
              child: Padding(
                padding: _iconPadding,
                child: ProcessIcon(process: connection, size: _iconSize),
              ),
            );
    }
    return TrackerPackageIcon(
      packageName: trackerInfo.metadata.process,
      targetHeight: metrics.rowHeight,
      padding: _iconPadding,
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
      if (layout.trailing.contains(TrackerTrailing.exit))
        _ExitChip(exit: exit, height: metrics.rowHeight),
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
  final double height;

  const _ExitChip({required this.exit, required this.height});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final filter = RecordFilter(RecordFacetKind.proxy, exit);
    return _FilterTarget(
      label: context.appLocalizations.filterByThisNode,
      value: exit,
      height: height,
      filter: filter,
      child: TonalChip(
        label: exit,
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        foregroundColor: colorScheme.onSurfaceVariant,
        onPressed: _FilterTarget.offeredIn(context)
            ? () => RecordFilterScope.add(context, filter)
            : null,
      ),
    );
  }
}

/// Filters when pressed anywhere up the row's height, so a near miss does
/// not open the detail.
class _FilterTarget extends StatelessWidget {
  final String label;
  final String? value;
  final double height;
  final RecordFilter filter;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _FilterTarget({
    required this.label,
    this.value,
    required this.height,
    required this.filter,
    this.padding = EdgeInsets.zero,
    required this.child,
  });

  static bool offeredIn(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RecordFilterScope>() != null;

  @override
  Widget build(BuildContext context) {
    // Nothing to narrow: the row's own summary names what this shows.
    if (!offeredIn(context)) {
      return ExcludeSemantics(
        child: Padding(padding: padding, child: child),
      );
    }
    void onTap() => RecordFilterScope.add(context, filter);
    return Semantics(
      container: true,
      button: true,
      label: value == null ? label : '$label, $value',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: padding,
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

/// An Android row's app icon, or a glyph for an app without one.
class TrackerPackageIcon extends StatelessWidget {
  final String packageName;
  final double targetHeight;

  /// Room around the icon its press target covers too.
  final EdgeInsetsGeometry padding;

  const TrackerPackageIcon({
    super.key,
    required this.packageName,
    required this.targetHeight,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return OwnPackageIcon(
      packageName: packageName,
      size: _iconSize,
      builder: (context, icon) {
        final shown =
            icon ??
            (packageName.isEmpty
                ? null
                : const ProcessGlyphWell(
                    glyph: AppGlyphs.appsList,
                    size: _iconSize,
                  ));
        if (shown == null) {
          return Padding(
            padding: padding,
            child: const SizedBox.square(dimension: _iconSize),
          );
        }
        return _FilterTarget(
          label: context.appLocalizations.filterByThisApp,
          height: targetHeight,
          filter: RecordFilter(RecordFacetKind.app, packageName),
          padding: padding,
          child: shown,
        );
      },
    );
  }
}
