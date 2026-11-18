import 'dart:math' as math;

import 'package:fl_clash/common/mitm_module.dart';
import 'package:path/path.dart' as p;

/// The Core runs these two script types; any other is not supported yet.
enum MitmScriptKind {
  request('http-request'),
  response('http-response');

  const MitmScriptKind(this.type);

  final String type;

  static MitmScriptKind? of(String type) =>
      values.where((kind) => kind.type == type.toLowerCase()).firstOrNull;
}

class MitmScriptInfo {
  const MitmScriptInfo({
    required this.name,
    required this.kind,
    required this.pattern,
    required this.path,
    required this.params,
  });

  final String name;
  final MitmScriptKind kind;
  final String pattern;
  final String path;
  final Map<String, String> params;

  bool get requiresBody => _truthy(params['requires-body']);

  /// The run's limit in seconds, as the Core clamps it.
  int get timeout {
    final seconds = double.tryParse(params['timeout'] ?? '') ?? 10;
    return seconds <= 0 ? 10 : math.min(10, seconds.ceil());
  }

  String? get host => mitmPatternHost(pattern);

  /// Keeps only the keys the Core reads.
  String lineWith(String file, {Map<String, String> changes = const {}}) {
    final values = {...params, ...changes};
    final fields = {
      'type': kind.type,
      'pattern': values['pattern'] ?? pattern,
      for (final key in _keptKeys) key: ?values[key],
      'script-path': file,
    };
    final title = (values['name'] ?? name).replaceAll(RegExp('[=,]'), ' ');
    return '${title.trim()} = ${[for (final MapEntry(:key, :value) in fields.entries) '$key=${mitmScriptValue(value)}'].join(',')}';
  }
}

const _keptKeys = [
  'requires-body',
  'binary-body-mode',
  'max-size',
  'timeout',
  'argument',
  'argument-json',
];

bool _truthy(String? value) =>
    const {'1', 'true', 'yes', 'on'}.contains(value?.trim().toLowerCase());

MitmScriptInfo? parseMitmScriptInfo(String line) {
  final parts = mitmScriptLineParts(line);
  final kind = parts == null ? null : MitmScriptKind.of(parts.type);
  if (parts == null || kind == null) {
    return null;
  }
  final path = parts.params['script-path'] ?? '';
  return MitmScriptInfo(
    name: parts.name.isNotEmpty
        ? parts.name
        : p.url.basenameWithoutExtension(Uri.tryParse(path)?.path ?? path),
    kind: kind,
    pattern: parts.params['pattern'] ?? '',
    path: path,
    params: parts.params,
  );
}

/// The host a URL pattern starts with, as the Core's index reads it.
String? mitmPatternHost(String pattern) {
  final match = RegExp(
    r'^\^?(?:https\?|https|http)?(?::|\\:)?(?:\\?/){2}((?:[a-z0-9-]|\\\.)+)',
    caseSensitive: false,
  ).firstMatch(pattern);
  final host = match?.group(1)?.replaceAll(r'\.', '.').toLowerCase();
  return host == null || !host.contains('.') ? null : host;
}

enum MitmScriptPasteError { unsupportedType, unreadable, noPattern, noPath }

class MitmScriptDraft {
  const MitmScriptDraft({required this.info, this.bare = false});

  final MitmScriptInfo info;
  final bool bare;

  bool get isRemote =>
      info.path.startsWith('https://') || info.path.startsWith('http://');
}

class MitmScriptPaste {
  const MitmScriptPaste(this.drafts, this.errors);

  final List<MitmScriptDraft> drafts;

  /// By 1-based line number.
  final Map<int, MitmScriptPasteError> errors;

  bool get isBareUrl => drafts.length == 1 && drafts.single.bare;
}

final _scriptUrl = RegExp(r'^https?://\S+$', caseSensitive: false);

MitmScriptDraft mitmBareScriptDraft(
  String url, {
  MitmScriptKind kind = MitmScriptKind.response,
  String? pattern,
  bool? requiresBody,
}) {
  final uri = Uri.tryParse(url);
  final host = uri?.host ?? '';
  final body = requiresBody ?? kind == MitmScriptKind.response;
  return MitmScriptDraft(
    bare: true,
    info: MitmScriptInfo(
      name: p.url.basenameWithoutExtension(uri?.path ?? url),
      kind: kind,
      pattern: pattern ?? mitmDefaultPattern(host),
      path: url,
      params: {if (body) 'requires-body': '1'},
    ),
  );
}

String mitmDefaultPattern(String host) =>
    host.isEmpty ? '^https?://' : '^https?://${host.replaceAll('.', r'\.')}/';

MitmScriptPaste parseMitmScriptPaste(String text) {
  final drafts = <MitmScriptDraft>[];
  final errors = <int, MitmScriptPasteError>{};
  final lines = text.split('\n');
  final meaningful = [
    for (final (index, raw) in lines.indexed)
      if (raw.trim() case final line
          when line.isNotEmpty &&
              !line.startsWith('#') &&
              !line.startsWith('//') &&
              !line.startsWith(';') &&
              !(line.startsWith('[') && line.endsWith(']')))
        (index + 1, line),
  ];
  if (meaningful.length == 1 && _scriptUrl.hasMatch(meaningful.single.$2)) {
    return MitmScriptPaste([mitmBareScriptDraft(meaningful.single.$2)], {});
  }
  for (final (number, line) in meaningful) {
    final parts = mitmScriptLineParts(line);
    if (parts == null) {
      errors[number] = MitmScriptPasteError.unreadable;
      continue;
    }
    final info = parseMitmScriptInfo(line);
    if (info == null) {
      errors[number] = MitmScriptPasteError.unsupportedType;
    } else if (info.pattern.isEmpty) {
      errors[number] = MitmScriptPasteError.noPattern;
    } else if (!_scriptUrl.hasMatch(info.path)) {
      errors[number] = MitmScriptPasteError.noPath;
    } else {
      drafts.add(MitmScriptDraft(info: info));
    }
  }
  return MitmScriptPaste(drafts, errors);
}

enum MitmDiffKind { same, added, removed, folded }

class MitmDiffLine {
  const MitmDiffLine(this.kind, this.text, [this.count = 1]);

  final MitmDiffKind kind;
  final String text;

  /// For a folded run, how many unchanged lines it stands for.
  final int count;
}

/// Past [maxCells] the changed middle shows as wholly replaced.
List<MitmDiffLine> mitmLineDiff(
  String before,
  String after, {
  int context = 3,
  int maxCells = 4000000,
}) {
  final a = before.split('\n');
  final b = after.split('\n');
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var endA = a.length;
  var endB = b.length;
  while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }
  final midA = a.sublist(start, endA);
  final midB = b.sublist(start, endB);
  final middle = <MitmDiffLine>[];
  if (midA.length * midB.length > maxCells) {
    middle
      ..addAll(midA.map((line) => MitmDiffLine(MitmDiffKind.removed, line)))
      ..addAll(midB.map((line) => MitmDiffLine(MitmDiffKind.added, line)));
  } else {
    final n = midA.length;
    final m = midB.length;
    final table = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        table[i][j] = midA[i] == midB[j]
            ? table[i + 1][j + 1] + 1
            : math.max(table[i + 1][j], table[i][j + 1]);
      }
    }
    var i = 0;
    var j = 0;
    while (i < n || j < m) {
      if (i < n && j < m && midA[i] == midB[j]) {
        middle.add(MitmDiffLine(MitmDiffKind.same, midA[i]));
        i++;
        j++;
      } else if (j < m && (i == n || table[i][j + 1] >= table[i + 1][j])) {
        middle.add(MitmDiffLine(MitmDiffKind.added, midB[j++]));
      } else {
        middle.add(MitmDiffLine(MitmDiffKind.removed, midA[i++]));
      }
    }
  }
  final all = [
    for (final line in a.sublist(0, start))
      MitmDiffLine(MitmDiffKind.same, line),
    ...middle,
    for (final line in a.sublist(endA)) MitmDiffLine(MitmDiffKind.same, line),
  ];
  return _fold(all, context);
}

List<MitmDiffLine> _fold(List<MitmDiffLine> lines, int context) {
  final result = <MitmDiffLine>[];
  var i = 0;
  while (i < lines.length) {
    if (lines[i].kind != MitmDiffKind.same) {
      result.add(lines[i++]);
      continue;
    }
    var j = i;
    while (j < lines.length && lines[j].kind == MitmDiffKind.same) {
      j++;
    }
    final run = lines.sublist(i, j);
    final head = i == 0 ? 0 : context;
    final tail = j == lines.length ? 0 : context;
    if (run.length - head - tail > 6) {
      result
        ..addAll(run.take(head))
        ..add(MitmDiffLine(MitmDiffKind.folded, '', run.length - head - tail))
        ..addAll(run.skip(run.length - tail));
    } else {
      result.addAll(run);
    }
    i = j;
  }
  return result;
}

({int added, int removed}) mitmDiffCounts(List<MitmDiffLine> diff) => (
  added: diff.where((line) => line.kind == MitmDiffKind.added).length,
  removed: diff.where((line) => line.kind == MitmDiffKind.removed).length,
);

class MitmModuleChange {
  const MitmModuleChange({
    required this.addedHosts,
    required this.removedHosts,
    required this.addedScripts,
    required this.removedScripts,
    required this.rewritesBefore,
    required this.rewritesAfter,
  });

  final List<String> addedHosts;
  final List<String> removedHosts;
  final List<String> addedScripts;
  final List<String> removedScripts;
  final int rewritesBefore;
  final int rewritesAfter;

  bool get bringsAccess => addedHosts.isNotEmpty || addedScripts.isNotEmpty;
}

MitmModuleChange mitmModuleChange(
  MitmModuleContent before,
  MitmModuleContent after,
) {
  List<String> hosts(MitmModuleContent content) => [
    ...content.insertedHostname,
    ...content.hostname,
  ];
  List<String> scripts(MitmModuleContent content) => [
    for (final line in content.script)
      if (parseMitmScriptInfo(line) case final info?)
        '${info.name} · ${info.kind.type} · ${info.pattern}',
  ];
  int rewrites(MitmModuleContent content) =>
      content.urlRewrite.length +
      content.headerRewrite.length +
      content.bodyRewrite.length +
      content.mapLocal.length;
  final hostsBefore = hosts(before).toSet();
  final hostsAfter = hosts(after).toSet();
  final scriptsBefore = scripts(before).toSet();
  final scriptsAfter = scripts(after).toSet();
  return MitmModuleChange(
    addedHosts: [...hostsAfter.difference(hostsBefore)],
    removedHosts: [...hostsBefore.difference(hostsAfter)],
    addedScripts: [...scriptsAfter.difference(scriptsBefore)],
    removedScripts: [...scriptsBefore.difference(scriptsAfter)],
    rewritesBefore: rewrites(before),
    rewritesAfter: rewrites(after),
  );
}

/// Cron, event and generic scripts are not run yet.
List<String> mitmHttpScriptLines(Iterable<String> lines) => [
  for (final line in lines)
    if (parseMitmScriptInfo(line) != null) line,
];

/// Reads [text] as if its downloads were there, for previews.
MitmModuleContent previewMitmModule(
  String text, {
  Map<String, String> values = const {},
}) {
  final first = parseMitmModule(text, values: values);
  return parseMitmModule(
    text,
    values: values,
    resources: {for (final url in first.resourceUrls) url: url},
  );
}
