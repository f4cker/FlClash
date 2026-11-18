import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'common.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua => [
    '$appCompatName/v$version',
    'clash-verge',
    'Platform/${Platform.operatingSystem}',
  ].join(' ');
}

/// Semantic version order (`1.2.3-pre.4+build`): a pre-release sorts before
/// its release, numeric identifiers compare as numbers, and the build number
/// only breaks a tie. Never throws on a suffix such as `15-mitm`.
int compareVersions(String version1, String version2) {
  final (core1, pre1, build1) = _splitVersion(version1);
  final (core2, pre2, build2) = _splitVersion(version2);
  for (var i = 0; i < 3; i++) {
    final order = _numericPart(core1, i).compareTo(_numericPart(core2, i));
    if (order != 0) return order;
  }
  final pre = _comparePreRelease(pre1, pre2);
  if (pre != 0) return pre;
  return (int.tryParse(build1) ?? 0).compareTo(int.tryParse(build2) ?? 0);
}

(List<String>, List<String>, String) _splitVersion(String version) {
  final plus = version.indexOf('+');
  final main = plus < 0 ? version : version.substring(0, plus);
  final build = plus < 0 ? '' : version.substring(plus + 1);
  final dash = main.indexOf('-');
  final core = dash < 0 ? main : main.substring(0, dash);
  final pre = dash < 0 ? '' : main.substring(dash + 1);
  return (core.split('.'), pre.isEmpty ? const [] : pre.split('.'), build);
}

int _numericPart(List<String> parts, int index) =>
    index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0;

int _comparePreRelease(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return b.length.compareTo(a.length).sign;
  for (var i = 0; i < a.length && i < b.length; i++) {
    final x = int.tryParse(a[i]), y = int.tryParse(b[i]);
    final order = switch ((x, y)) {
      (final int x, final int y) => x.compareTo(y),
      (int(), null) => -1,
      (null, int()) => 1,
      _ => a[i].compareTo(b[i]),
    };
    if (order != 0) return order;
  }
  return a.length.compareTo(b.length);
}

const releaseNotesBeginMarker = '<!-- flclash:changelog:begin -->';
const releaseNotesEndMarker = '<!-- flclash:changelog:end -->';

List<String> parseReleaseBody(String? body) {
  if (body == null) return [];
  final regex = RegExp(r'^[ \t]*-[ \t]+(.*)$', multiLine: true);
  return regex
      .allMatches(scopeReleaseNotes(body))
      .map((match) => match.group(1)?.trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String scopeReleaseNotes(String body) {
  final begin = body.indexOf(releaseNotesBeginMarker);
  if (begin < 0) return body;
  final start = begin + releaseNotesBeginMarker.length;
  final end = body.indexOf(releaseNotesEndMarker, start);
  return end < 0 ? body.substring(start) : body.substring(start, end);
}
