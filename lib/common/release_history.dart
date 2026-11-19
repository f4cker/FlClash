import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_update.dart';

String releaseVersion(String tag) => tag.replaceFirst(RegExp(r'^v'), '');

@immutable
class PublishedRelease {
  const PublishedRelease({
    required this.tag,
    required this.published,
    this.body = '',
    this.prerelease,
  });

  final String tag;
  final DateTime published;
  final String body;
  final bool? prerelease;

  String get version => releaseVersion(tag);

  bool matchesInstalled(String version, String build) =>
      this.version == appVersionLabel(version, build) ||
      this.version == version;

  bool matchesAvailable(UpdateAvailable available) =>
      version == available.versionLabel ||
      version == releaseVersion(available.release['tag_name'] as String);

  static PublishedRelease? fromJson(Map<String, dynamic> json) {
    if (json['draft'] == true) return null;
    final tag = json['tag_name'];
    final date = DateTime.tryParse(json['published_at'] as String? ?? '');
    if (tag is! String || tag.isEmpty || date == null) return null;
    return PublishedRelease(
      tag: tag,
      published: date.toUtc(),
      body: json['body'] as String? ?? '',
      prerelease: json['prerelease'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'tag_name': tag,
    'published_at': published.toIso8601String(),
    'body': body,
    if (prerelease != null) 'prerelease': prerelease,
  };
}

@immutable
class ReleaseHistory {
  ReleaseHistory(
    Iterable<PublishedRelease> releases, {
    required this.fetchedAt,
    this.truncated = false,
  }) : releases = List.unmodifiable(
         {for (final release in releases) release.tag: release}.values.toList()
           ..sort((a, b) {
             final date = b.published.compareTo(a.published);
             return date == 0 ? b.tag.compareTo(a.tag) : date;
           }),
       );

  final List<PublishedRelease> releases;
  final DateTime fetchedAt;
  final bool truncated;

  String encode() => jsonEncode({
    'releases': releases.map((release) => release.toJson()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'truncated': truncated,
  });

  static ReleaseHistory? decode(String? value) {
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return ReleaseHistory(
        (json['releases'] as List)
            .map(
              (item) => PublishedRelease.fromJson(item as Map<String, dynamic>),
            )
            .nonNulls,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        truncated: json['truncated'] as bool,
      );
    } catch (_) {
      return null;
    }
  }
}

class ReleaseHistoryStore extends ChangeNotifier {
  ReleaseHistoryStore({
    required this.fetch,
    required this.readCache,
    required this.writeCache,
  });

  final Future<ReleaseHistory> Function() fetch;
  final Future<String?> Function() readCache;
  final Future<void> Function(String value) writeCache;
  ReleaseHistory? history;
  bool loading = false;
  bool failed = false;
  bool stale = false;
  bool _disposed = false;
  bool _started = false;

  Future<void> refresh() async {
    if (loading || _disposed) return;
    loading = true;
    failed = false;
    notifyListeners();
    if (!_started) {
      _started = true;
      try {
        history = ReleaseHistory.decode(await readCache());
        stale = history != null;
        if (!_disposed) notifyListeners();
      } catch (_) {
        // Cache availability never gates a network retry.
      }
    }
    if (_disposed) {
      loading = false;
      return;
    }
    try {
      final next = await fetch();
      if (_disposed) return;
      history = next;
      stale = false;
      try {
        await writeCache(next.encode());
      } catch (_) {
        // A fresh response is still usable when persistence is unavailable.
      }
    } catch (_) {
      failed = true;
      stale = history != null;
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
