import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'tray_capabilities.dart';
import 'tray_codec.dart';
import 'tray_event.dart';
import 'tray_menu.dart';
import 'tray_spec.dart';

const String _methodShow = 'show';
const String _methodHide = 'hide';
const String _methodSetTitle = 'setTitle';
const String _methodOpenMenu = 'openMenu';

const String _eventIconActivated = 'onIconActivated';
const String _eventMenuRequested = 'onMenuRequested';
const String _eventMenuItemSelected = 'onMenuItemSelected';
const String _eventMenuGenerations = 'onMenuGenerations';

final class Tray {
  Tray._() {
    _channel.setMethodCallHandler(_onPlatformCall);
  }

  static final Tray instance = Tray._();

  final MethodChannel _channel = const MethodChannel('tray');

  final StreamController<TrayEvent> _events =
      StreamController<TrayEvent>.broadcast();

  Map<int, TrayMenuItem> _itemsById = const {};
  Future<void> _queue = Future<void>.value();
  String? _signature;
  int? _menuGeneration;
  int? _pendingMenuGeneration;
  int? _trackingMenuGeneration;
  EncodedTray? _pendingMenu;
  Set<int> _nativeMenuGenerations = const {};
  final Map<int, Map<int, TrayMenuItem>> _menusByGeneration = {};
  final Map<int, Map<int, TrayMenuItem>> _menuOriginsByGeneration = {};
  final Map<int, List<Object?>> _menuLayoutsByGeneration = {};
  int _nextMenuGeneration = 0;
  String _title = '';
  String _requestedTitle = '';
  bool _isVisible = false;

  Stream<TrayEvent> get events => _events.stream;

  TrayCapabilities get capabilities =>
      TrayCapabilities.of(defaultTargetPlatform);

  bool get isVisible => _isVisible;

  Future<void> show(TraySpec spec) {
    return _serialize(() => _show(spec));
  }

  Future<void> setTitle(String title) {
    _requestedTitle = title;
    return _serialize(() => _setTitle(_requestedTitle));
  }

  Future<void> hide() {
    return _serialize(_hide);
  }

  Future<void> openMenu() {
    return _serialize(_openMenu);
  }

  @visibleForTesting
  void resetForTesting() {
    _itemsById = const {};
    _queue = Future<void>.value();
    _signature = null;
    _menuGeneration = null;
    _pendingMenuGeneration = null;
    _trackingMenuGeneration = null;
    _pendingMenu = null;
    _nativeMenuGenerations = const {};
    _menusByGeneration.clear();
    _menuOriginsByGeneration.clear();
    _menuLayoutsByGeneration.clear();
    _title = '';
    _requestedTitle = '';
    _isVisible = false;
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _show(TraySpec spec) async {
    if (!capabilities.supported) {
      return;
    }
    final encoded = TrayCodec.encode(spec);
    if (_isVisible && encoded.signature == _signature) {
      _itemsById = encoded.itemsById;
      if (defaultTargetPlatform == TargetPlatform.macOS &&
          _menuGeneration != null) {
        _menusByGeneration[_menuGeneration!] = encoded.itemsById;
        _menuOriginsByGeneration[_menuGeneration!] = encoded.itemsById;
        if (_trackingMenuGeneration != null &&
            _trackingMenuGeneration != _menuGeneration) {
          _reconcileTrackedCallbacks(_trackingMenuGeneration!, encoded);
        }
      }
      return;
    }
    final generation = ++_nextMenuGeneration;
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    if (isMacOS) {
      _pendingMenuGeneration = generation;
      _pendingMenu = encoded;
      _menusByGeneration[generation] = encoded.itemsById;
      _menuOriginsByGeneration[generation] = encoded.itemsById;
      _menuLayoutsByGeneration[generation] = encoded.menu;
    }
    try {
      final isApplied = await _channel
          .invokeMethod<bool>(_methodShow, <String, Object?>{
            'id': _stableId,
            'icon': await _resolveIcon(spec.icon),
            'toolTip': encoded.toolTip,
            'title': _title,
            'menu': encoded.menu,
            if (isMacOS) 'menuGeneration': generation,
          });
      if (isApplied != true) {
        _signature = null;
        return;
      }
      _itemsById = encoded.itemsById;
      _signature = encoded.signature;
      _menuGeneration = generation;
      _isVisible = true;
    } finally {
      _pendingMenuGeneration = null;
      _pendingMenu = null;
      _pruneMenuGenerations();
    }
  }

  void _pruneMenuGenerations() {
    bool unused(int generation) =>
        generation != _menuGeneration &&
        generation != _pendingMenuGeneration &&
        !_nativeMenuGenerations.contains(generation);
    _menusByGeneration.removeWhere((generation, _) => unused(generation));
    _menuOriginsByGeneration.removeWhere((generation, _) => unused(generation));
    _menuLayoutsByGeneration.removeWhere((generation, _) => unused(generation));
  }

  void _reconcileTrackedCallbacks(int generation, EncodedTray desired) {
    final layout = _menuLayoutsByGeneration[generation];
    final previous = _menusByGeneration[generation];
    final origins = _menuOriginsByGeneration[generation];
    if (layout == null || previous == null || origins == null) {
      return;
    }
    final reconciled = <int, TrayMenuItem>{};
    void visit(List<Object?> retained, List<Object?> incoming) {
      for (final value in retained) {
        final row = value! as Map<String, Object?>;
        bool sameIdentity(Object? value) {
          final other = value! as Map<String, Object?>;
          return row['type'] == other['type'] && row['label'] == other['label'];
        }

        final matches = incoming.where(sameIdentity).toList();
        final unique =
            retained.where(sameIdentity).length == 1 && matches.length == 1;
        final match = unique ? matches.single! as Map<String, Object?> : null;
        final id = row['id']! as int;
        final oldItem = previous[id] ?? origins[id];
        final newItem = match == null ? null : desired.itemsById[match['id']];
        if (oldItem != null && newItem != null) {
          reconciled[id] = _retainCallback(
            newItem,
            oldItem,
            origins[id] ?? oldItem,
          );
        }
        if (row['type'] == 'submenu') {
          visit(
            row['items']! as List<Object?>,
            match?['items'] as List<Object?>? ?? const [],
          );
        }
      }
    }

    visit(layout, desired.menu);
    _menusByGeneration[generation] = reconciled;
  }

  TrayMenuItem _retainCallback(
    TrayMenuItem item,
    TrayMenuItem previous,
    TrayMenuItem origin,
  ) {
    return switch (item) {
      TrayMenuAction() => TrayMenuAction(
        label: item.label,
        detail: item.detail,
        icon: item.icon,
        badge: item.badge,
        accessibilityLabel: item.accessibilityLabel,
        enabled: item.enabled && (origin as TrayMenuAction).enabled,
        onSelected: (previous as TrayMenuAction).onSelected,
      ),
      TrayMenuCheckbox() => TrayMenuCheckbox(
        segmentGroup: item.segmentGroup,
        segmentError: item.segmentError,
        label: item.label,
        checked: item.checked,
        detail: item.detail,
        icon: item.icon,
        badge: item.badge,
        accessibilityLabel: item.accessibilityLabel,
        enabled:
            item.enabled &&
            ((origin as TrayMenuCheckbox).enabled ||
                (item.segmentGroup != null &&
                    item.segmentGroup == origin.segmentGroup)),
        onSelected: (previous as TrayMenuCheckbox).onSelected,
      ),
      TrayMenuSubmenu() || TrayMenuSeparator() => item,
    };
  }

  Future<void> _setTitle(String title) async {
    if (!capabilities.title) {
      return;
    }
    final isUnchanged = _title == title;
    _title = title;
    if (isUnchanged || !_isVisible) {
      return;
    }
    await _channel.invokeMethod(_methodSetTitle, <String, Object?>{
      'title': title,
    });
  }

  Future<void> _hide() async {
    _itemsById = const {};
    _signature = null;
    _menuGeneration = null;
    _trackingMenuGeneration = null;
    _nativeMenuGenerations = const {};
    _menusByGeneration.clear();
    _menuOriginsByGeneration.clear();
    _menuLayoutsByGeneration.clear();
    _title = '';
    if (!_isVisible) {
      return;
    }
    _isVisible = false;
    await _channel.invokeMethod(_methodHide);
  }

  Future<void> _openMenu() async {
    if (!capabilities.menuControl || !_isVisible) {
      return;
    }
    await _channel.invokeMethod(_methodOpenMenu);
  }

  Future<void> _onPlatformCall(MethodCall call) async {
    switch (call.method) {
      case _eventIconActivated:
        _events.add(const TrayIconActivated());
      case _eventMenuRequested:
        _events.add(const TrayMenuRequested());
      case _eventMenuGenerations:
        final arguments = call.arguments;
        if (defaultTargetPlatform != TargetPlatform.macOS) {
          return;
        }
        final references = arguments is Map
            ? arguments['generations']
            : arguments;
        if (references is! List) {
          return;
        }
        _nativeMenuGenerations = references.whereType<int>().take(3).toSet();
        final tracking = arguments is Map
            ? arguments['trackingGeneration']
            : null;
        _trackingMenuGeneration = tracking is int ? tracking : null;
        if (_pendingMenu case final pending?) {
          if (_nativeMenuGenerations.contains(_pendingMenuGeneration) &&
              _trackingMenuGeneration != null &&
              _trackingMenuGeneration != _pendingMenuGeneration) {
            _reconcileTrackedCallbacks(_trackingMenuGeneration!, pending);
          }
        }
        _pruneMenuGenerations();
      case _eventMenuItemSelected:
        final arguments = call.arguments;
        if (arguments is! Map) {
          return;
        }
        final generation = arguments['menuGeneration'];
        final items = defaultTargetPlatform == TargetPlatform.macOS
            ? (generation is int ? _menusByGeneration[generation] : null)
            : _itemsById;
        final id = arguments['id'];
        final item = id is int ? (items?[id]) : null;
        if (item == null) {
          return;
        }
        switch (item) {
          case TrayMenuAction(enabled: true, :final onSelected):
            onSelected?.call();
          case TrayMenuCheckbox(enabled: true, :final onSelected):
            onSelected?.call();
          case TrayMenuAction():
          case TrayMenuCheckbox():
          case TrayMenuSubmenu():
          case TrayMenuSeparator():
            return;
        }
        _events.add(TrayMenuItemSelected(item));
    }
  }

  /// Scales probed in Flutter's `2.0x/` variant layout; the README says how
  /// each platform consumes them.
  static const variantScales = [1.0, 2.0, 3.0, 4.0];

  @visibleForTesting
  static bool Function(String filePath) fileExists = (filePath) =>
      File(filePath).existsSync();

  @visibleForTesting
  static String variantAsset(String asset, double scale) {
    if (scale == 1.0) {
      return asset;
    }
    final directory = path.posix.dirname(asset);
    return path.posix.joinAll([
      if (directory != '.') directory,
      '${scale.toStringAsFixed(1)}x',
      path.posix.basename(asset),
    ]);
  }

  Future<Map<String, Object?>> _resolveIcon(TrayIcon icon) async {
    final resolved = <String, Object?>{
      'isTemplate': icon.isTemplate,
      'size': icon.size,
      'position': icon.position.name,
    };
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        resolved['reps'] = await _loadRepresentations(icon.asset);
      case TargetPlatform.linux:
        resolved['path'] = _largestBundledVariant(icon.asset);
      default:
        resolved['path'] = _bundledPath(icon.asset);
    }
    return resolved;
  }

  Future<List<Map<String, Object?>>> _loadRepresentations(String asset) async {
    final reps = <Map<String, Object?>>[];
    for (final scale in variantScales) {
      final ByteData data;
      try {
        data = await rootBundle.load(variantAsset(asset, scale));
      } on FlutterError {
        continue;
      }
      reps.add({
        'scale': scale,
        'bytes': base64Encode(data.buffer.asUint8List()),
      });
    }
    return reps;
  }

  String _largestBundledVariant(String asset) {
    for (final scale in variantScales.reversed) {
      final candidate = _bundledPath(variantAsset(asset, scale));
      if (fileExists(candidate)) {
        return candidate;
      }
    }
    return _bundledPath(asset);
  }

  String _bundledPath(String asset) {
    return path.joinAll([
      path.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      asset,
    ]);
  }

  String get _stableId {
    return path.basenameWithoutExtension(Platform.resolvedExecutable);
  }
}
