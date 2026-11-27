import 'dart:math';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

const proxyGridSpacing = 8.0;

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 +
      measure.textHeight(AppTextStyle.callout) +
      2 +
      measure.textHeight(AppTextStyle.caption1) +
      2;
}

/// The card's room around its content: the info button sits in the top end.
const nodeCardPadding = EdgeInsets.fromLTRB(12, 8, 12, 8);
const nodeCardRowGap = 6.0;
const nodeInfoRoom = 20.0;
const nodeBadgeGap = 4.0;
const nodeBadgeSize = 22.0;

/// The title row's first line, which the badge and the info button centre on.
double get nodeTitleBand => max(
  globalState.measure.textHeight(AppTextStyle.subheadline),
  nodeBadgeSize,
);

/// A card whose name stands [nameHeight] tall; a compact card's is one line.
double getItemHeight(ProxyCardType proxyCardType, {double? nameHeight}) {
  final measure = globalState.measure;
  final line = measure.textHeight(AppTextStyle.subheadline);
  final band = nodeTitleBand;
  final name = proxyCardType == ProxyCardType.compact
      ? line
      : nameHeight ?? line;
  final title = max(band, (band - line) / 2 + name);
  final details = switch (proxyCardType) {
    ProxyCardType.loose =>
      measure.textHeight(AppTextStyle.footnote) +
          nodeCardRowGap +
          measure.textHeight(AppTextStyle.caption2),
    _ => measure.textHeight(AppTextStyle.footnote),
  };
  return nodeCardPadding.vertical + title + nodeCardRowGap + details;
}

TextSpan _nameSpan(String name, EmojiFont? emoji) {
  if (emoji == null) return TextSpan(text: name);
  final style = TextStyle(fontFamily: emoji.family);
  final spans = <TextSpan>[];
  var end = 0;
  for (final match in emoji.pattern.allMatches(name)) {
    if (match.start > end) {
      spans.add(TextSpan(text: name.substring(end, match.start)));
    }
    spans.add(TextSpan(text: match.group(0), style: style));
    end = match.end;
  }
  if (end < name.length) spans.add(TextSpan(text: name.substring(end)));
  return TextSpan(children: spans);
}

final _nameLines = <(String, TextStyle, TextScaler, bool, Object?), _Name>{};

typedef _Name = ({double width, double line});

/// How tall a name stands on a card [cardWidth] wide, laid out as if it had
/// a badge, so selecting a card never changes its row. An emoji can stand a
/// line taller than the text around it.
double nodeNameHeight(
  BuildContext context,
  String name,
  double cardWidth,
  ProxyCardType proxyCardType,
) {
  final line = globalState.measure.textHeight(AppTextStyle.subheadline);
  if (proxyCardType == ProxyCardType.compact) return line;
  final style = AppTextStyle.subheadline.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final emoji = EmojiFont.of(context);
  final key = (
    name,
    style,
    scaler,
    MediaQuery.boldTextOf(context),
    emoji?.family,
  );
  if (_nameLines.length > 4096) _nameLines.clear();
  final measured = _nameLines[key] ??= () {
    final painter = TextPainter(
      text: TextSpan(style: style, children: [_nameSpan(name, emoji)]),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    try {
      return (
        width: EmojiText.widthOf(context, name, style),
        line: max(line, painter.height),
      );
    } finally {
      painter.dispose();
    }
  }();
  final room =
      cardWidth -
      nodeCardPadding.horizontal -
      nodeInfoRoom -
      nodeBadgeGap * 2 -
      nodeBadgeSize;
  return measured.line * (measured.width > room ? 2 : 1);
}

/// Each row's extent with the [spacing] after it: as tall as its tallest
/// name needs, so a row of one-line names keeps no empty line.
List<double> nodeRowExtents(
  BuildContext context,
  List<Proxy> proxies, {
  required int columns,
  required double cardWidth,
  required ProxyCardType proxyCardType,
  double spacing = proxyGridSpacing,
}) => [
  for (var start = 0; start < proxies.length; start += columns)
    getItemHeight(
          proxyCardType,
          nameHeight: proxies
              .skip(start)
              .take(columns)
              .map(
                (proxy) => nodeNameHeight(
                  context,
                  proxy.name,
                  cardWidth,
                  proxyCardType,
                ),
              )
              .fold<double>(0.0, max),
        ) +
        spacing,
];

/// The width of one of [columns] cards across [width] with 8 between them.
double nodeCardWidth(double width, int columns) =>
    max(0.0, width - nodeGridCrossSpacing * (columns - 1)) / columns;

const nodeGridCrossSpacing = 8.0;

double sumExtents(Iterable<double> extents) =>
    extents.fold(0.0, (a, b) => a + b);

/// A grid of [columns] whose rows each take their own extent from
/// [rowExtents], which include [mainAxisSpacing].
class NodeGridDelegate extends SliverGridDelegate {
  const NodeGridDelegate({
    required this.columns,
    required this.rowExtents,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = nodeGridCrossSpacing,
  });

  final int columns;
  final List<double> rowExtents;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final usable = max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (columns - 1),
    );
    final offsets = [0.0];
    for (final extent in rowExtents) {
      offsets.add(offsets.last + extent);
    }
    return _NodeGridLayout(
      columns: columns,
      cellWidth: usable / columns,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      offsets: offsets,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(NodeGridDelegate oldDelegate) =>
      columns != oldDelegate.columns ||
      mainAxisSpacing != oldDelegate.mainAxisSpacing ||
      crossAxisSpacing != oldDelegate.crossAxisSpacing ||
      !listEquals(rowExtents, oldDelegate.rowExtents);
}

class _NodeGridLayout extends SliverGridLayout {
  const _NodeGridLayout({
    required this.columns,
    required this.cellWidth,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.offsets,
    required this.reverseCrossAxis,
  });

  final int columns;
  final double cellWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final List<double> offsets;
  final bool reverseCrossAxis;

  int get _rows => offsets.length - 1;

  double _strideOf(int row) => row < _rows
      ? offsets[row + 1] - offsets[row]
      : (_rows > 0 ? offsets[_rows] - offsets[_rows - 1] : 0);

  double _offsetOf(int row) => row <= _rows
      ? offsets[row]
      : offsets[_rows] + (row - _rows) * _strideOf(_rows);

  /// Rows that end at or before [offset].
  int _rowsBefore(double offset) {
    var low = 0;
    var high = _rows;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (offsets[mid + 1] <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low == _rows && _rows > 0) {
      final stride = _strideOf(_rows);
      if (stride > 0) low += ((offset - offsets[_rows]) / stride).floor();
    }
    return low;
  }

  /// Rows that start before [offset].
  int _rowsStartedBy(double offset) {
    final before = _rowsBefore(offset);
    return _offsetOf(before) < offset ? before + 1 : before;
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      columns * _rowsBefore(scrollOffset);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) =>
      max(0, columns * _rowsStartedBy(scrollOffset) - 1);

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final row = index ~/ columns;
    final stride = cellWidth + crossAxisSpacing;
    final column = index % columns;
    final cross = reverseCrossAxis
        ? (columns - 1 - column) * stride
        : column * stride;
    return SliverGridGeometry(
      scrollOffset: _offsetOf(row),
      crossAxisOffset: cross,
      mainAxisExtent: max(0.0, _strideOf(row) - mainAxisSpacing),
      crossAxisExtent: cellWidth,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    if (childCount == 0) return 0;
    final rows = (childCount + columns - 1) ~/ columns;
    return _offsetOf(rows) - mainAxisSpacing;
  }
}

class GroupOffsets {
  const GroupOffsets(this.groups, this.offsets);

  static const empty = GroupOffsets(<Group>[], <double>[]);

  final List<Group> groups;
  final List<double> offsets;

  bool get isEmpty => offsets.isEmpty;

  double offsetOf(String groupName) {
    final index = groups.indexWhere((group) => group.name == groupName);
    if (index < 0 || index >= offsets.length) {
      return 0;
    }
    return offsets[index];
  }
}

double? selectedRowOffset({
  required List<Proxy> proxies,
  required String? selectedProxyName,
  required int columns,
  required List<double> rowExtents,
}) {
  final index = proxies.indexWhere((proxy) => proxy.name == selectedProxyName);
  if (index < 0) {
    return null;
  }
  return sumExtents(rowExtents.take(index ~/ columns));
}

/// Finds a card keyed `ValueKey(proxy.name)` in [proxies] once a refresh
/// moved it, so its element is kept rather than built again.
ChildIndexGetter proxyIndexFinder(List<Proxy> proxies) {
  Map<String, int>? indexes;
  return (key) {
    if (key case ValueKey<String>(:final value)) {
      indexes ??= {
        for (final (index, proxy) in proxies.indexed) proxy.name: index,
      };
      return indexes![value];
    }
    return null;
  };
}

void animateScrollTo(ScrollController controller, double offset) {
  if (!controller.hasClients) {
    return;
  }
  final position = controller.position;
  controller.animateTo(
    offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );
}
