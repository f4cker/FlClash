import 'dart:convert';

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

  String get summary => detail.isEmpty ? action : '$action · $detail';
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
      response ? l.mitmRewriteActResponseHeader : l.mitmRewriteActRequestHeader,
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

/// An error as the app shows it: [text] in the user's language, and [raw]
/// the Core's or the system's own text, untranslated, for the details
/// behind 查看原始错误; null when there is none to show.
typedef MitmShownError = ({String text, String? raw});

/// A value the Core quoted (Go strconv.Quote) as the user wrote it, for a
/// sentence that already sets it off after a colon. An empty value, or one
/// with spaces at its ends, keeps its quotes so it can be seen; a value Go
/// quoted in a way JSON does not read (\x, \a, \v, \U) stays as it came.
String mitmUnquotedArg(String value) {
  if (value.length < 2 || !value.startsWith('"') || !value.endsWith('"')) {
    return value;
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is! String || decoded.isEmpty || decoded.trim() != decoded) {
      return value;
    }
    return decoded;
  } on FormatException {
    return value;
  }
}

/// [issue] as the app shows it: its code in the user's words, the Core's
/// own text behind the details. [scriptName] is the script's name as the
/// user knows it, for the file the Core names by its stored name.
MitmShownError mitmIssueError(
  AppLocalizations l,
  MitmRewriteIssue issue, {
  String? scriptName,
}) => (
  text: mitmRewriteIssueText(l, issue, scriptName: scriptName),
  raw: issue.message.trim().isEmpty ? null : issue.message,
);

/// [issue] for the script [name] under a sentence that names it already,
/// as "{name} can't be loaded: …": the reason names no file, so the name
/// reads once; the stored name only in the details.
MitmShownError mitmScriptCannotLoadError(
  AppLocalizations l,
  String name,
  MitmRewriteIssue issue,
) {
  final error = mitmIssueError(l, issue);
  return (text: l.mitmScriptCannotLoad(name, error.text), raw: error.raw);
}

const _storedIssueMark = '\u0001mitm-issue:';

/// [issue] as a script row keeps it in its error text, so the row can word
/// it in whatever language the app is in when it is shown, and keep the
/// Core's own text for the details.
String mitmStoredIssue(MitmRewriteIssue issue) =>
    '$_storedIssueMark${jsonEncode({'kind': issue.kind, 'args': issue.args, 'message': issue.message})}';

/// The issue [mitmStoredIssue] kept in [error]; null for text the app wrote
/// as it is, as a download failure or a row from before issues were kept.
MitmRewriteIssue? mitmIssueOfStored(String? error) {
  if (error == null || !error.startsWith(_storedIssueMark)) return null;
  try {
    final json = jsonDecode(error.substring(_storedIssueMark.length));
    if (json case {
      'kind': final String kind,
      'message': final String message,
    }) {
      return MitmRewriteIssue(
        section: MitmList.script.key,
        kind: kind,
        args: [
          if (json['args'] case final List args)
            for (final arg in args) '$arg',
        ],
        message: message,
      );
    }
  } on FormatException {
    // Not ours after all: shown as it is.
  }
  return null;
}

/// A script row's error text as the app shows it; [scriptName] as for
/// [mitmIssueError].
MitmShownError mitmStoredError(
  AppLocalizations l,
  String error, {
  String? scriptName,
}) => switch (mitmIssueOfStored(error)) {
  final issue? => mitmIssueError(l, issue, scriptName: scriptName),
  null when error.startsWith(_storedIssueMark) => (
    text: l.mitmRewriteErrorGeneric,
    raw: null,
  ),
  null => (text: error, raw: null),
};

/// Why a rule or a script cannot be taken, in the user's language, from the
/// stable code the Core gives it; a code this app does not know reads as a
/// generic format error, with the Core's own text left for the details.
/// A script's compile error is never put in these words: only in the
/// details.
///
/// The Core names a script file by the name the app stored it under, a
/// hash the user never sees: [scriptName], the name on the row, stands for
/// it, and without one the words name no file. The stored name is only in
/// the details.
String mitmRewriteIssueText(
  AppLocalizations l,
  MitmRewriteIssue issue, {
  String? scriptName,
}) {
  final value = issue.args.firstOrNull ?? '';
  final file = switch (scriptName?.trim()) {
    final name? when name.isNotEmpty => name,
    _ => null,
  };
  return switch (issue.kind) {
    'scriptLine' => l.mitmScriptErrorLine,
    'scriptType' => l.mitmScriptErrorType(mitmUnquotedArg(value)),
    'scriptPattern' => l.mitmScriptErrorPattern,
    'scriptPath' => l.mitmScriptErrorPath,
    'scriptMaxSize' => l.mitmScriptErrorMaxSize(mitmUnquotedArg(value)),
    'scriptTimeout' => l.mitmScriptErrorTimeout(mitmUnquotedArg(value)),
    'scriptArgument' => l.mitmScriptErrorArgument,
    'scriptUnreadable' => switch (file) {
      final file? => l.mitmScriptErrorUnreadable(file),
      null => l.mitmScriptErrorUnreadableNoName,
    },
    'scriptTooLarge' => switch (file) {
      final file? => l.mitmScriptErrorTooLarge(file),
      null => l.mitmScriptErrorTooLargeNoName,
    },
    'scriptSyntax' => l.mitmScriptErrorSyntax,
    'framingHeader' => l.mitmRewriteErrorFramingHeader(value),
    'needsValue' => l.mitmRewriteErrorNeedsValue(value),
    'bodyHead' => l.mitmRewriteErrorBodyHead,
    'headerLineBreak' => l.mitmRewriteErrorHeaderLineBreak,
    'needsReplacementURL' => l.mitmRewriteErrorNeedsReplacementUrl,
    'dataURL' => l.mitmRewriteErrorDataUrl,
    'dataBase64' => l.mitmRewriteErrorDataBase64,
    'dataFileName' => l.mitmRewriteErrorDataFileName(value),
    'fileNeedsData' => l.mitmRewriteErrorFileNeedsData,
    'bodyTooLarge' => l.mitmRewriteErrorBodyTooLarge,
    'emptyRegex' => l.mitmRewriteErrorEmptyRegex,
    'emptyRule' => l.mitmRewriteErrorEmptyRule,
    'urlFieldCount' => l.mitmRewriteErrorUrlFieldCount(value),
    'bodyPairs' => l.mitmRewriteErrorBodyPairs,
    'headerFields' => l.mitmRewriteErrorHeaderFields,
    'keyValue' => l.mitmRewriteErrorKeyValue(value),
    'headerFormat' => l.mitmRewriteErrorHeaderFormat,
    'headerReplaceRegex' => l.mitmRewriteErrorHeaderReplaceRegex,
    'urlRegex' => l.mitmRewriteErrorUrlRegex,
    'bodyRegex' => l.mitmRewriteErrorBodyRegex(value),
    'invalidHeader' => l.mitmRewriteErrorInvalidHeader(value),
    'headerName' => l.mitmRewriteErrorHeaderName(value),
    'headerRegex' => l.mitmRewriteErrorHeaderRegex,
    'jq' => l.mitmRewriteErrorJq,
    'localUnreadable' => l.mitmRewriteErrorLocalUnreadable(value),
    'localTooLarge' => l.mitmRewriteErrorLocalTooLarge(value),
    'regexTimeout' => l.mitmRewriteErrorRegexTimeout,
    'statusCode' => l.mitmRewriteErrorStatusCode(value),
    'urlType' => l.mitmRewriteErrorUrlType(value),
    'dataType' => l.mitmRewriteErrorDataType(value),
    'headerAction' => l.mitmRewriteErrorHeaderAction(value),
    'parameter' => l.mitmRewriteErrorParameter(value),
    'section' => l.mitmRewriteErrorSection(value),
    'unterminatedQuote' => l.mitmRewriteErrorUnterminatedQuote(value),
    'outsideSection' => l.mitmRewriteErrorOutsideSection,
    _ => l.mitmRewriteErrorGeneric,
  };
}
