import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';

/// The groups the rewrite page lists rules in, in its order. URL Rewrite
/// lines split into the rejects and the rest (redirects and URL rewrites).
enum MitmRewriteGroup { reject, redirect, header, body, mapLocal }

extension MitmRewriteGroupLabel on MitmRewriteGroup {
  String label(AppLocalizations l) => switch (this) {
    MitmRewriteGroup.reject => l.mitmRewriteGroupReject,
    MitmRewriteGroup.redirect => l.mitmRewriteGroupRedirect,
    MitmRewriteGroup.header => l.mitmRewriteGroupHeader,
    MitmRewriteGroup.body => l.mitmRewriteGroupBody,
    MitmRewriteGroup.mapLocal => l.mapLocal,
  };
}

const _urlTypes = {
  'header',
  '302',
  '307',
  'reject',
  'reject-200',
  'reject-img',
  'reject-dict',
  'reject-array',
  'reject-drop',
  'reject-tinygif',
};

/// Splits a line into fields as the Core does: a field that opens with a
/// quote and closes with it before a space is one field, quotes kept.
List<String> mitmRewriteFields(String line) {
  final fields = <String>[];
  var i = 0;
  bool space(int at) => line[at] == ' ' || line[at] == '\t';
  while (i < line.length) {
    while (i < line.length && space(i)) {
      i++;
    }
    if (i >= line.length) break;
    final q = line[i];
    if (q == '"' || q == "'") {
      final close = line.indexOf(q, i + 1);
      if (close >= 0 && (close + 1 == line.length || space(close + 1))) {
        fields.add(line.substring(i, close + 1));
        i = close + 1;
        continue;
      }
    }
    final start = i;
    while (i < line.length && !space(i)) {
      i++;
    }
    fields.add(line.substring(start, i));
  }
  return fields;
}

String _unquote(String field) {
  if (field.length >= 2 &&
      field[0] == field[field.length - 1] &&
      (field[0] == '"' || field[0] == "'")) {
    return field.substring(1, field.length - 1);
  }
  return field;
}

Map<String, String> _params(String text) {
  final params = <String, String>{};
  final pattern = RegExp(r'([A-Za-z-]+)=("[^"]*"|\S*)');
  for (final match in pattern.allMatches(text)) {
    params[match[1]!.toLowerCase()] = _unquote(match[2]!);
  }
  return params;
}

/// A rule in plain words: its group, the action word the row leads with,
/// what it does, and the URL pattern it matches. Only as much of the line
/// is read as these need; whether it is valid is the Core's word.
class MitmRewriteDescription {
  final MitmRewriteGroup group;
  final String action;
  final String detail;
  final String match;

  const MitmRewriteDescription({
    required this.group,
    required this.action,
    required this.detail,
    required this.match,
  });

  String get summary =>
      detail.isEmpty ? action : '$action · $detail';
}

/// The URL rewrite type of a line, lowercased, or null if it names none.
String? _urlType(List<String> fields) {
  switch (fields.length) {
    case 2:
      final type = fields[1].toLowerCase();
      return type.startsWith('reject') && _urlTypes.contains(type)
          ? type
          : 'header';
    case 3:
      final type = fields[2].toLowerCase();
      if (_urlTypes.contains(type)) return type;
      final swapped = fields[1].toLowerCase();
      return _urlTypes.contains(swapped) ? swapped : null;
  }
  return null;
}

/// Which group a rule of [section] is listed in.
MitmRewriteGroup mitmRewriteGroupOf(MitmList section, String line) {
  return switch (section) {
    MitmList.urlRewrite =>
      (_urlType(mitmRewriteFields(line.trim())) ?? '').startsWith('reject')
          ? MitmRewriteGroup.reject
          : MitmRewriteGroup.redirect,
    MitmList.headerRewrite => MitmRewriteGroup.header,
    MitmList.bodyRewrite => MitmRewriteGroup.body,
    _ => MitmRewriteGroup.mapLocal,
  };
}

String _rejectText(AppLocalizations l, String type) => switch (type) {
  'reject-200' => l.mitmRewriteReject200,
  'reject-img' || 'reject-tinygif' => l.mitmRewriteRejectImage,
  'reject-dict' => l.mitmRewriteRejectDict,
  'reject-array' => l.mitmRewriteRejectArray,
  'reject-drop' => l.mitmRewriteRejectDrop,
  _ => l.mitmRewriteRejectError,
};

/// Describes [line] of [section], or null when it cannot be read.
MitmRewriteDescription? describeMitmRewrite(
  AppLocalizations l,
  MitmList section,
  String line, {
  int bodyLimit = 0,
  String Function(int bytes)? sizeText,
}) {
  final fields = mitmRewriteFields(line.trim());
  if (fields.isEmpty) return null;
  final group = mitmRewriteGroupOf(section, line);
  switch (section) {
    case MitmList.urlRewrite:
      final type = _urlType(fields);
      if (type == null) return null;
      final match = _unquote(fields[0]);
      if (type.startsWith('reject')) {
        return MitmRewriteDescription(
          group: group,
          action: l.mitmRewriteActReject,
          detail: l.mitmRewriteRejectDetail(_rejectText(l, type), type),
          match: match,
        );
      }
      final target = fields.length == 3
          ? _unquote(fields[1].toLowerCase() == type ? fields[2] : fields[1])
          : _unquote(fields[1]);
      return MitmRewriteDescription(
        group: group,
        action: type == 'header'
            ? l.mitmRewriteActUrl
            : l.mitmRewriteActRedirect(type),
        detail: '→ $target',
        match: match,
      );
    case MitmList.headerRewrite:
      var rest = fields;
      var response = false;
      final head = rest.first.toLowerCase();
      if (head == 'http-request' || head == 'http-response') {
        response = head == 'http-response';
        rest = rest.sublist(1);
      }
      if (rest.length < 3) return null;
      final name = _unquote(rest[2]);
      final detail = switch (rest[1].toLowerCase()) {
        'header-add' => l.mitmRewriteHeaderAdd(name),
        'header-del' => l.mitmRewriteHeaderDel(name),
        'header-replace' => l.mitmRewriteHeaderReplace(name),
        'header-replace-regex' => l.mitmRewriteHeaderReplaceRegex(name),
        _ => null,
      };
      if (detail == null) return null;
      return MitmRewriteDescription(
        group: group,
        action: response
            ? l.mitmRewriteActResponseHeader
            : l.mitmRewriteActRequestHeader,
        detail: detail,
        match: _unquote(rest[0]),
      );
    case MitmList.bodyRewrite:
      final head = fields.first.toLowerCase();
      if (head != 'http-request' && head != 'http-response') return null;
      if (fields.length < 4 || fields.length.isOdd) return null;
      final pairs = (fields.length - 2) ~/ 2;
      return MitmRewriteDescription(
        group: group,
        action: head == 'http-response'
            ? l.mitmRewriteActResponseBody
            : l.mitmRewriteActRequestBody,
        detail: [
          l.mitmRewriteBodyReplace(pairs),
          if (bodyLimit > 0 && sizeText != null)
            l.mitmRewriteBodyLimit(sizeText(bodyLimit)),
        ].join(' · '),
        match: _unquote(fields[1]),
      );
    case MitmList.mapLocal:
      final params = _params(line.trim().substring(fields[0].length));
      final type = params['data-type'] ?? 'file';
      final status = params['status-code'];
      return MitmRewriteDescription(
        group: group,
        action: l.mitmRewriteActMapLocal,
        detail: [?status, type].join(' · '),
        match: _unquote(fields[0]),
      );
    default:
      return null;
  }
}

/// What a skip reason from the Core says, in words.
String mitmRewriteSkipText(AppLocalizations l, String skipped) {
  return switch (skipped) {
    'oversize' => l.mitmRewriteSkipOversize,
    'decodeFailed' => l.mitmRewriteSkipDecode,
    'notText' || 'notUTF8' => l.mitmRewriteSkipNotText,
    'unsupportedEncoding' => l.mitmRewriteSkipEncoding,
    'regexTimeout' => l.mitmRewriteSkipTimeout,
    'crossHost' => l.mitmRewriteSkipCrossHost,
    'invalidURL' => l.mitmRewriteSkipInvalidUrl,
    'streaming' || 'framing' => l.mitmRewriteSkipStreaming,
    'uploading' => l.mitmRewriteSkipUploading,
    'bodyReadFailed' => l.mitmRewriteSkipRead,
    _ => l.mitmRewriteSkipOther,
  };
}

/// What kind of change a hit the Core reported made, as a row's tooltip and
/// the detail name it: the list it is from, and the side for headers and
/// bodies.
String mitmRewriteHitType(AppLocalizations l, MitmAction hit) {
  final response = hit.phase == 'response';
  return switch (hit.kind) {
    'url-rewrite' => switch (hit.detail) {
      final detail when detail.startsWith('reject') => l.mitmRewriteActReject,
      '302' || '307' => l.mitmRewriteActRedirect(hit.detail),
      _ => l.mitmRewriteActUrl,
    },
    'header-rewrite' =>
      response
          ? l.mitmRewriteActResponseHeader
          : l.mitmRewriteActRequestHeader,
    'body-rewrite' =>
      response ? l.mitmRewriteActResponseBody : l.mitmRewriteActRequestBody,
    'map-local' => l.mitmRewriteActMapLocal,
    _ => hit.kind,
  };
}

/// The section a Core key ([MitmList.key]) names.
MitmList? mitmListOfKey(String key) {
  for (final list in mitmRewriteLists) {
    if (list.key == key) return list;
  }
  return null;
}

/// Surge's section title for [list].
String mitmRewriteSectionTitle(MitmList list) => switch (list) {
  MitmList.urlRewrite => '[URL Rewrite]',
  MitmList.headerRewrite => '[Header Rewrite]',
  MitmList.bodyRewrite => '[Body Rewrite]',
  _ => '[Map Local]',
};

/// [rewrites] as Surge sections, in the page's group order.
String mitmRewriteSurgeText(Iterable<MitmRewrite> rewrites) {
  final sections = <String>[];
  for (final list in const [
    MitmList.urlRewrite,
    MitmList.headerRewrite,
    MitmList.bodyRewrite,
    MitmList.mapLocal,
  ]) {
    final lines = [
      for (final rewrite in rewrites)
        if (rewrite.section == list) rewrite.line,
    ];
    if (lines.isEmpty) continue;
    sections.add([mitmRewriteSectionTitle(list), ...lines].join('\n'));
  }
  return sections.join('\n\n');
}

/// The stored rules of a profile, as text the Core's paste parser reads
/// back line for line: the number of each rule's line, by rule ID.
({String text, Map<int, int> lines}) mitmRewriteCheckText(
  List<MitmRewrite> rewrites,
) {
  final buffer = <String>[];
  final lines = <int, int>{};
  MitmList? section;
  for (final rewrite in rewrites) {
    if (rewrite.section != section) {
      section = rewrite.section;
      buffer.add(mitmRewriteSectionTitle(section));
    }
    buffer.add(rewrite.line);
    lines[buffer.length] = rewrite.id;
  }
  return (text: buffer.join('\n'), lines: lines);
}
