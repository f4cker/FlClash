import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/process_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef AppLookupInvoker = Future<Object?> Function(String path);
typedef LocalAddressesReader = Future<Set<String>> Function();

const _channel = MethodChannel('$packageName/process_app');

Future<Object?> _invokeChannel(String path) =>
    _channel.invokeMethod<Object?>('lookup', {'path': path});

Future<Set<String>> _readLocalAddresses() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: true,
    includeLinkLocal: true,
  );
  return {
    for (final interface in interfaces)
      for (final address in interface.addresses)
        normalizeAddress(address.address),
  };
}

/// Reads which Mac app each process path belongs to, off the frame and once
/// per path, and this Mac's own addresses; a listener hears each new answer.
class ProcessApps extends ChangeNotifier {
  final AppLookupInvoker? _invoke;
  final LocalAddressesReader _readAddresses;
  final int capacity;

  ProcessApps({
    AppLookupInvoker? invoke,
    LocalAddressesReader? readLocalAddresses,
    bool? lookupApps,
    this.capacity = 512,
  }) : _invoke = (lookupApps ?? Platform.isMacOS)
           ? (invoke ?? _invokeChannel)
           : null,
       _readAddresses = readLocalAddresses ?? _readLocalAddresses;

  static const _retryAfter = Duration(minutes: 1);
  static const _addressesMaxAge = Duration(seconds: 30);

  final _lookups = <String, AppLookup>{};
  final _failedAt = <String, DateTime>{};
  final _loading = <String>{};
  final _icons = <String, MemoryImage>{};
  final _labels = <String, String>{};
  final _pool = TaskPool(4);
  Set<String>? _localAddresses;
  DateTime? _addressesReadAt;
  var _readingAddresses = false;
  var _disposed = false;

  /// The answer for [path], or null while it is being read.
  AppLookup? lookupOf(String path) {
    final invoke = _invoke;
    if (path.isEmpty || invoke == null) {
      return AppLookup.none;
    }
    final cached = _lookups.remove(path);
    if (cached != null) {
      _lookups[path] = cached;
      final failedAt = _failedAt[path];
      if (failedAt == null ||
          DateTime.now().difference(failedAt) < _retryAfter) {
        return cached;
      }
    }
    if (_loading.add(path)) {
      unawaited(_load(path, invoke));
    }
    return cached;
  }

  Future<void> _load(String path, AppLookupInvoker invoke) async {
    AppLookup lookup;
    try {
      lookup = AppLookup.fromChannel(await _pool.run(() => invoke(path)));
    } catch (_) {
      lookup = AppLookup.failed;
    }
    _loading.remove(path);
    if (_disposed) {
      return;
    }
    _put(path, lookup);
    notifyListeners();
  }

  void _put(String path, AppLookup lookup) {
    _lookups.remove(path);
    _lookups[path] = lookup;
    if (lookup.status == AppLookupStatus.failed) {
      _failedAt[path] = DateTime.now();
    } else {
      _failedAt.remove(path);
    }
    while (_lookups.length > capacity) {
      final oldest = _lookups.keys.first;
      _lookups.remove(oldest);
      _failedAt.remove(oldest);
    }
  }

  /// This Mac's interface addresses, null until first read.
  Set<String>? get localAddresses {
    final readAt = _addressesReadAt;
    if (!_readingAddresses &&
        (readAt == null ||
            DateTime.now().difference(readAt) > _addressesMaxAge)) {
      _readingAddresses = true;
      unawaited(_loadAddresses());
    }
    return _localAddresses;
  }

  Future<void> _loadAddresses() async {
    Set<String>? addresses;
    try {
      addresses = await _readAddresses();
    } catch (_) {
      addresses = null;
    }
    _readingAddresses = false;
    _addressesReadAt = DateTime.now();
    if (_disposed) {
      return;
    }
    final changed = !setEquals(addresses, _localAddresses);
    _localAddresses = addresses;
    if (changed) {
      notifyListeners();
    }
  }

  ConnectionProcess processOf(Metadata metadata) {
    final path = metadata.processPath.trim();
    final hasProcess = path.isNotEmpty || metadata.process.trim().isNotEmpty;
    final process = ConnectionProcess.classify(
      metadata,
      lookup: path.isEmpty ? null : lookupOf(path),
      localAddresses: hasProcess ? null : localAddresses,
    );
    if (process.app case final app?) {
      _remember(_labels, app.key, app.name);
    }
    return process;
  }

  /// The names a search finds [metadata]'s source by besides its own.
  List<String> searchLabelsOf(Metadata metadata) {
    final process = processOf(metadata);
    return [
      if (process.app case final app?) app.name,
      if (process.service case final match?) match.service.label,
    ];
  }

  /// What a filter on [key] reads as.
  String labelOf(String key) {
    if (key == otherDeviceProcessKey) {
      return currentAppLocalizations.otherDevice;
    }
    if (key.isEmpty) {
      return currentAppLocalizations.unknownProcess;
    }
    final label = _labels[key];
    if (label != null) {
      return label;
    }
    if (key.startsWith('svc:')) {
      final service = SystemService.fromId(key.substring(4));
      if (service != null) {
        return service.label;
      }
    }
    final value = key.substring(key.indexOf(':') + 1);
    return key.startsWith('exe:') ? value.split('/').last : value;
  }

  ImageProvider? iconOf(MacApp app) => _iconOf(app.bundlePath, app.icon);

  ImageProvider? serviceIconOf(ServiceMatch match) =>
      _iconOf(match.key, match.icon);

  ImageProvider? _iconOf(String key, Uint8List? bytes) {
    if (bytes == null) {
      return null;
    }
    final cached = _icons[key];
    if (cached != null) {
      return cached;
    }
    final icon = MemoryImage(bytes);
    _remember(_icons, key, icon);
    return icon;
  }

  void _remember<V>(Map<String, V> map, String key, V value) {
    map.remove(key);
    map[key] = value;
    while (map.length > capacity) {
      map.remove(map.keys.first);
    }
  }

  @visibleForTesting
  void seed({Map<String, AppLookup> lookups = const {}, Set<String>? local}) {
    lookups.forEach(_put);
    if (local != null) {
      _localAddresses = local;
      _addressesReadAt = DateTime(9999);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

ProcessApps processApps = ProcessApps();
