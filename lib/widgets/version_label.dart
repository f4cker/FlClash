import 'package:fl_clash/common/common.dart';
import 'package:flutter/widgets.dart';

/// `version (build)`, the build in [buildStyle] on the version's baseline.
TextSpan versionLabelSpan(
  String label, {
  TextStyle? style,
  required TextStyle buildStyle,
}) {
  final parts = versionLabelParts(label);
  return TextSpan(
    text: parts.version,
    style: style,
    children: [
      if (parts.build case final build?)
        TextSpan(text: ' ($build)', style: buildStyle),
    ],
  );
}

const _firstSlot = 0xE000;

/// [format] gets one private-use marker per label, replaced by its span.
TextSpan versionMessageSpan(
  String Function(List<String> slots) format,
  List<String> labels, {
  TextStyle? style,
  required TextStyle buildStyle,
}) {
  final message = format([
    for (var i = 0; i < labels.length; i++) String.fromCharCode(_firstSlot + i),
  ]);
  final children = <InlineSpan>[];
  final text = StringBuffer();
  for (final rune in message.runes) {
    final slot = rune - _firstSlot;
    if (slot < 0 || slot >= labels.length) {
      text.writeCharCode(rune);
      continue;
    }
    if (text.isNotEmpty) {
      children.add(TextSpan(text: text.toString()));
      text.clear();
    }
    children.add(versionLabelSpan(labels[slot], buildStyle: buildStyle));
  }
  if (text.isNotEmpty) children.add(TextSpan(text: text.toString()));
  return TextSpan(style: style, children: children);
}
