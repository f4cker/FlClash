import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/models/changelog.dart';
import 'package:flutter/widgets.dart';

TextStyle _notesStyle(BuildContext context, {bool emphasized = false}) =>
    AppTextStyle.custom(
      context,
      size: 14,
      leading: 21,
    ).merge(emphasized ? AppTextStyle.emphasis : null);

List<InlineSpan> releaseNotesSpans(BuildContext context, String? body) {
  final style = _notesStyle(context);
  final version = parseReleaseChangelog(body);
  if (version != null && version.visibleGroups.isNotEmpty) {
    return [
      for (final group in version.visibleGroups) ...[
        TextSpan(
          text:
              '\n${changelogGroupTitle(context.appLocalizations, group.type)}\n',
          style: _notesStyle(context, emphasized: true).copyWith(
            color: group.type == ChangelogType.breaking
                ? context.colorScheme.error
                : context.colorScheme.primary,
          ),
        ),
        for (final entry in group.entries)
          ..._inline(context, '• ${entry.text}\n', style),
      ],
    ];
  }
  final notes = scopeReleaseNotes(
    body ?? '',
  ).replaceAll(RegExp(r'<!--[\s\S]*?-->'), '').trim();
  if (notes.isEmpty) {
    return [
      TextSpan(text: context.appLocalizations.releaseNotesEmpty, style: style),
    ];
  }
  final spans = <InlineSpan>[];
  var code = false;
  for (final line in notes.split('\n')) {
    if (line.trimLeft().startsWith('```')) {
      code = !code;
      continue;
    }
    final heading = RegExp(r'^#{1,6}\s+').hasMatch(line);
    final text = line
        .replaceFirst(RegExp(r'^#{1,6}\s+'), '')
        .replaceFirst(RegExp(r'^\s*[-*+]\s+'), '• ')
        .replaceFirst(RegExp(r'^>\s?'), '');
    spans.addAll(
      code
          ? [TextSpan(text: '$line\n', style: style)]
          : _inline(
              context,
              '$text\n',
              heading ? _notesStyle(context, emphasized: true) : style,
            ),
    );
  }
  return spans;
}

List<InlineSpan> _inline(BuildContext context, String text, TextStyle style) {
  final spans = <InlineSpan>[];
  final tokens = RegExp(
    r'\[([^\]]+)\]\((https?://[^\s)]+)\)|\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`|\*([^*]+)\*',
  );
  var start = 0;
  for (final match in tokens.allMatches(text)) {
    spans.add(TextSpan(text: text.substring(start, match.start), style: style));
    if (match[2] != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: TextButton(
            onPressed: () => dialogs.openUrl(match[2]!),
            child: Text(
              match[1]!,
              textScaler: TextScaler.noScaling,
              style: style.copyWith(color: context.colorScheme.primary),
            ),
          ),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: match[3] ?? match[4] ?? match[5] ?? match[6],
          style: match[3] != null || match[4] != null
              ? _notesStyle(context, emphasized: true)
              : style,
        ),
      );
    }
    start = match.end;
  }
  spans.add(TextSpan(text: text.substring(start), style: style));
  return spans;
}

class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes({super.key, required this.body});

  final String? body;

  @override
  Widget build(BuildContext context) =>
      Text.rich(TextSpan(children: releaseNotesSpans(context, body)));
}
