import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:fl_clash/common/file.dart';
import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' show join;

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// Null when [path] cannot be read, which no fingerprint matches.
Future<String?> storedSha256(String path) async {
  try {
    return (await sha256.bind(File(path).openRead()).first).toString();
  } on FileSystemException {
    return null;
  }
}

/// What a server said about the copy kept of one resource, and the
/// fingerprint of that copy as it was stored.
///
/// The validators are only ever sent while the copy on disk still has
/// [fingerprint]: a 304 then means "what you hold is current", and nothing
/// is trusted that was not checked when it was stored.
class ResourceValidators {
  const ResourceValidators({
    this.etag,
    this.lastModified,
    required this.fingerprint,
    required this.storedAt,
  });

  final String? etag;
  final String? lastModified;
  final String fingerprint;
  final DateTime storedAt;

  bool get canRevalidate => etag != null || lastModified != null;

  Map<String, String> get headers => {
    HttpHeaders.ifNoneMatchHeader: ?etag,
    HttpHeaders.ifModifiedSinceHeader: ?lastModified,
  };

  Map<String, Object?> toJson() => {
    if (etag != null) 'etag': etag,
    if (lastModified != null) 'lastModified': lastModified,
    'fingerprint': fingerprint,
    'storedAt': storedAt.toUtc().toIso8601String(),
  };

  static ResourceValidators? fromJson(Object? json) {
    if (json is! Map) return null;
    final fingerprint = json['fingerprint'];
    final storedAt = DateTime.tryParse('${json['storedAt']}');
    final etag = json['etag'];
    final lastModified = json['lastModified'];
    if (fingerprint is! String ||
        fingerprint.isEmpty ||
        storedAt == null ||
        etag is! String? ||
        lastModified is! String?) {
      return null;
    }
    return ResourceValidators(
      etag: etag,
      lastModified: lastModified,
      fingerprint: fingerprint,
      storedAt: storedAt,
    );
  }
}

/// The validators of every downloaded resource, in one JSON file of the app
/// home. It only saves traffic: a lost, unreadable or stale file costs one
/// full download per resource and never decides what is trusted.
class ResourceValidatorStore {
  ResourceValidatorStore({Future<String> Function()? path})
    : _path = path ?? _defaultPath;

  static const fileName = 'resource_validators.json';
  static const maxEntries = 1024;

  /// Nothing else has looked up the app home before the first download
  /// only in tests, which then keep no validators.
  static Future<String> _defaultPath() async {
    if (!AppPath.created) {
      throw StateError('app paths not set up');
    }
    return join(await appPath.homeDirPath, fileName);
  }

  final Future<String> Function() _path;
  String? _loadedPath;
  Map<String, ResourceValidators> _entries = {};
  Future<void> _saving = Future.value();

  /// Null when there is no place to keep them, which only costs traffic.
  Future<Map<String, ResourceValidators>?> _load() async {
    final String path;
    try {
      path = await _path();
    } catch (_) {
      return null;
    }
    if (_loadedPath == path) {
      return _entries;
    }
    final entries = <String, ResourceValidators>{};
    try {
      final file = File(path);
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is Map) {
          for (final MapEntry(:key, :value) in decoded.entries) {
            final validators = ResourceValidators.fromJson(value);
            if (key is String && validators != null) {
              entries[key] = validators;
            }
          }
        }
      }
    } catch (e) {
      commonPrint.log(
        'resource validators unreadable, starting over: ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
    }
    if (_loadedPath != path) {
      _loadedPath = path;
      _entries = entries;
    }
    return _entries;
  }

  Future<ResourceValidators?> get(String key) async => (await _load())?[key];

  Future<void> put(String key, ResourceValidators validators) async {
    final entries = await _load();
    if (entries == null) return;
    entries.remove(key);
    entries[key] = validators;
    while (entries.length > maxEntries) {
      entries.remove(entries.keys.first);
    }
    await _save();
  }

  Future<void> remove(String key) async {
    final entries = await _load();
    if (entries?.remove(key) != null) {
      await _save();
    }
  }

  /// Saves run one after another, each writing the whole map as it is then.
  Future<void> _save() {
    final path = _loadedPath;
    if (path == null) return Future.value();
    return _saving = _saving.then((_) async {
      if (_loadedPath != path) return;
      try {
        await File(path).writeAsStringAtomically(
          json.encode({
            for (final MapEntry(:key, :value) in _entries.entries)
              key: value.toJson(),
          }),
        );
      } catch (e) {
        commonPrint.log(
          'resource validators not saved: ${compactError(e)}',
          logLevel: LogLevel.warning,
        );
      }
    });
  }

  @visibleForTesting
  Future<void> get saved => _saving;
}

sealed class ResourceFetch {
  const ResourceFetch();
}

/// The server answered 304 to validators sent for a copy that, before and
/// after the request, still has [validators]' fingerprint.
final class ResourceNotModified extends ResourceFetch {
  const ResourceNotModified(this.validators);

  final ResourceValidators validators;
}

final class ResourceDownloaded extends ResourceFetch {
  ResourceDownloaded(this.bytes, {this.etag, this.lastModified});

  final Uint8List bytes;
  final String? etag;
  final String? lastModified;

  late final String sha256 = sha256Hex(bytes);
}

/// Conditional downloads for the resources the app keeps a copy of.
///
/// Every caller says how to check its copy against a fingerprint ([holds]).
/// Validators are sent only while that check passes; when it fails (copy
/// missing, changed or corrupt) they are dropped and the resource is fetched
/// whole. Validators are recorded only through [commit], once the caller has
/// stored and checked what it downloaded.
class ResourceCache {
  ResourceCache(this.store);

  final ResourceValidatorStore store;

  static String keyOf(String kind, String url) => '$kind|$url';

  Future<ResourceFetch> fetch(
    String kind,
    String url, {
    required Future<bool> Function(String fingerprint) holds,
  }) async {
    final key = keyOf(kind, url);
    final stored = await store.get(key);
    ResourceValidators? sent;
    if (stored != null) {
      if (stored.canRevalidate && await holds(stored.fingerprint)) {
        sent = stored;
      } else {
        await store.remove(key);
      }
    }
    final response = await request.getConditionalFileResponseForUrl(
      url,
      headers: sent?.headers ?? const {},
    );
    if (response.statusCode == HttpStatus.notModified) {
      if (sent != null && await holds(sent.fingerprint)) {
        return ResourceNotModified(sent);
      }
      // The copy changed while the request ran, or a server answered 304 to
      // nothing: only a whole download says what is current.
      await store.remove(key);
      if (sent == null) {
        throw HttpException('Unexpected 304 for $url', uri: Uri.tryParse(url));
      }
      return fetch(kind, url, holds: (_) async => false);
    }
    return ResourceDownloaded(
      response.data ?? Uint8List(0),
      etag: response.headers.value(HttpHeaders.etagHeader),
      lastModified: response.headers.value(HttpHeaders.lastModifiedHeader),
    );
  }

  /// Records what [download] said, for a copy stored with [fingerprint]
  /// (by default the hash of the downloaded bytes).
  Future<void> commit(
    String kind,
    String url,
    ResourceDownloaded download, {
    String? fingerprint,
  }) async {
    final key = keyOf(kind, url);
    if (download.etag == null && download.lastModified == null) {
      await store.remove(key);
      return;
    }
    await store.put(
      key,
      ResourceValidators(
        etag: download.etag,
        lastModified: download.lastModified,
        fingerprint: fingerprint ?? download.sha256,
        storedAt: DateTime.now(),
      ),
    );
  }

  Future<void> forget(String kind, String url) =>
      store.remove(keyOf(kind, url));
}

final resourceCache = ResourceCache(ResourceValidatorStore());

abstract final class ResourceKind {
  static const mitmModule = 'mitm-module';
  static const mitmResource = 'mitm-resource';
  static const mitmScript = 'mitm-script';
  static const iconSet = 'icon-set';
  static const script = 'script';
}
