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

  /// How long validators are trusted: after this a resource downloads whole
  /// once more, whatever the server would say to them.
  static const maxAge = Duration(days: 7);

  bool get canRevalidate => etag != null || lastModified != null;

  bool isStale(DateTime now) => now.difference(storedAt) > maxAge;

  /// The ETag when there is one; a date only stands in for a missing ETag,
  /// as a server that sends both judges by the ETag (RFC 9110 13.1.3).
  Map<String, String> get headers => etag != null
      ? {HttpHeaders.ifNoneMatchHeader: etag!}
      : {HttpHeaders.ifModifiedSinceHeader: ?lastModified};

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
///
/// Entries are keyed by a hash of kind and url, so no url, and no token or
/// credential in one, is ever written to the file. Keys of any other shape,
/// such as the plain `kind|url` keys of the first build, are dropped on load.
///
/// The file has a single writer: one store, in the main isolate of one app
/// process. Saves run in order and each writes the whole map, so two stores,
/// isolates or processes writing it would each overwrite the other's entries;
/// that costs only full downloads, never a wrong 304.
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
    var dropped = false;
    try {
      final file = File(path);
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is Map) {
          for (final MapEntry(:key, :value) in decoded.entries) {
            final validators = ResourceValidators.fromJson(value);
            if (key is String &&
                _hashedKey.hasMatch(key) &&
                validators != null) {
              entries[key] = validators;
            } else {
              dropped = true;
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
      if (dropped) {
        // Rewritten at once, so a url an old build stored leaves the disk.
        unawaited(_save());
      }
    }
    return _entries;
  }

  static final _hashedKey = RegExp(r'^[0-9a-f]{64}$');

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

  /// Marks [key] as just used, so eviction at [maxEntries] takes entries
  /// nobody asked about for longest first. What it says stays as it is.
  Future<void> touch(String key) async {
    final entries = await _load();
    final validators = entries?.remove(key);
    if (entries == null || validators == null) return;
    entries[key] = validators;
    await _save();
  }

  Future<void> remove(String key) async {
    final entries = await _load();
    if (entries?.remove(key) != null) {
      await _save();
    }
  }

  bool _saveQueued = false;

  /// Saves run one after another, each writing the whole map as it is when
  /// it starts; changes made while one waits to start share it.
  Future<void> _save() {
    final path = _loadedPath;
    if (path == null) return Future.value();
    if (_saveQueued) return _saving;
    _saveQueued = true;
    return _saving = _saving.then((_) async {
      _saveQueued = false;
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
  ResourceDownloaded(
    this.bytes, {
    this.etag,
    this.lastModified,
    this.contentType,
  });

  final Uint8List bytes;
  final String? etag;
  final String? lastModified;
  final String? contentType;

  late final String sha256 = sha256Hex(bytes);

  /// [bytes] as text, in the charset [contentType] names.
  String get text => decodeResponseText(bytes, contentType);
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

  /// A hash, so the stored file never holds a url (or a token in one).
  static String keyOf(String kind, String url) =>
      sha256Hex(utf8.encode('$kind|$url'));

  /// Sent to get a whole body when a 304 came where none could: no
  /// validators went out, or the copy they stood for changed meanwhile.
  static const _noCache = {
    HttpHeaders.cacheControlHeader: 'no-cache',
    HttpHeaders.pragmaHeader: 'no-cache',
  };

  /// Only with [revalidate] (auto update) do validators go out; a manual
  /// update always asks for the whole resource, so a server or cache that
  /// answers 304 wrongly can always be overruled by hand. Validators older
  /// than [ResourceValidators.maxAge] are dropped, so even auto update
  /// downloads each resource whole now and then.
  Future<ResourceFetch> fetch(
    String kind,
    String url, {
    required Future<bool> Function(String fingerprint) holds,
    bool revalidate = false,
  }) async {
    final key = keyOf(kind, url);
    final stored = await store.get(key);
    ResourceValidators? sent;
    if (stored != null) {
      if (!stored.canRevalidate || stored.isStale(DateTime.now())) {
        await store.remove(key);
      } else if (revalidate) {
        if (await holds(stored.fingerprint)) {
          sent = stored;
        } else {
          await store.remove(key);
        }
      }
    }
    var response = await request.getConditionalFileResponseForUrl(
      url,
      headers: sent?.headers ?? const {},
    );
    if (response.statusCode == HttpStatus.notModified) {
      if (sent != null && await holds(sent.fingerprint)) {
        await store.touch(key);
        return ResourceNotModified(sent);
      }
      // The copy changed while the request ran, or a server or cache
      // answered 304 to an unconditional request: once more, asking every
      // cache on the way for a whole body.
      await store.remove(key);
      response = await request.getConditionalFileResponseForUrl(
        url,
        headers: _noCache,
      );
      if (response.statusCode == HttpStatus.notModified) {
        throw HttpException('Unexpected 304', uri: Uri.tryParse(url));
      }
    }
    return ResourceDownloaded(
      response.data ?? Uint8List(0),
      etag: response.headers.value(HttpHeaders.etagHeader),
      lastModified: response.headers.value(HttpHeaders.lastModifiedHeader),
      contentType: response.headers.value(HttpHeaders.contentTypeHeader),
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
