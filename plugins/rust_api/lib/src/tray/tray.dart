import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../rust/api/tray.dart';
import 'tray_capabilities.dart';
import 'tray_codec.dart';
import 'tray_event.dart';
import 'tray_menu.dart';
import 'tray_spec.dart';

abstract interface class TrayHost {
  Stream<TraySignal> signals();

  bool show(TrayContent content);

  bool setTitle(String title);

  void hide();

  bool openMenu();
}

final class _RustTrayHost implements TrayHost {
  const _RustTrayHost();

  @override
  Stream<TraySignal> signals() => traySignals();

  @override
  bool show(TrayContent content) => showTray(content: content);

  @override
  bool setTitle(String title) => setTrayTitle(title: title);

  @override
  void hide() => hideTray();

  @override
  bool openMenu() => openTrayMenu();
}

final class Tray {
  Tray._();

  static final Tray instance = Tray._();

  final StreamController<TrayEvent> _events =
      StreamController<TrayEvent>.broadcast();

  TrayHost _host = const _RustTrayHost();
  StreamSubscription<TraySignal>? _signals;
  Map<int, TrayMenuItem> _itemsById = const {};
  Future<void> _queue = Future<void>.value();
  String? _signature;
  int? _menuGeneration;
  int? _pendingMenuGeneration;
  int? _trackingMenuGeneration;
  EncodedTray? _pendingMenu;
  EncodedTray? _shownMenu;
  Set<int> _nativeMenuGenerations = const {};
  final Map<int, Map<int, TrayMenuItem>> _menusByGeneration = {};
  final Map<int, Map<int, TrayMenuItem>> _menuOriginsByGeneration = {};
  final Map<int, List<TrayItem>> _menuLayoutsByGeneration = {};
  int _nextMenuGeneration = 0;
  String _title = '';
  String _requestedTitle = '';
  bool _isVisible = false;

  Stream<TrayEvent> get events {
    _listen();
    return _events.stream;
  }

  TrayCapabilities get capabilities =>
      TrayCapabilities.of(defaultTargetPlatform);

  bool get isVisible => _isVisible;

  Future<void> show(TraySpec spec) {
    return _serialize(() => _show(spec));
  }

  Future<void> setTitle(String title) {
    _requestedTitle = title;
    return _serialize(() async => _setTitle(_requestedTitle));
  }

  Future<void> hide() {
    return _serialize(() async => _hide());
  }

  Future<void> openMenu() {
    return _serialize(() async => _openMenu());
  }

  @visibleForTesting
  void resetForTesting(TrayHost host) {
    _signals?.cancel();
    _signals = null;
    _host = host;
    _itemsById = const {};
    _queue = Future<void>.value();
    _signature = null;
    _menuGeneration = null;
    _pendingMenuGeneration = null;
    _trackingMenuGeneration = null;
    _pendingMenu = null;
    _shownMenu = null;
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
      _listen();
      final image = await _resolveImage(spec.icon);
      final isApplied = _host.show(
        TrayContent(
          id: _stableId,
          image: image,
          toolTip: spec.toolTip,
          title: _title,
          menu: encoded.menu,
          menuGeneration: isMacOS ? generation : 0,
        ),
      );
      if (!isApplied) {
        _signature = null;
        return;
      }
      _itemsById = encoded.itemsById;
      _signature = encoded.signature;
      _menuGeneration = generation;
      _shownMenu = encoded;
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
    void visit(List<TrayItem> retained, List<TrayItem> incoming) {
      for (final row in retained) {
        bool sameIdentity(TrayItem other) =>
            row.kind == other.kind && row.label == other.label;

        final matches = incoming.where(sameIdentity).toList();
        final unique =
            retained.where(sameIdentity).length == 1 && matches.length == 1;
        final match = unique ? matches.single : null;
        final id = row.id;
        final oldItem = previous[id] ?? origins[id];
        final newItem = match == null ? null : desired.itemsById[match.id];
        if (oldItem != null && newItem != null) {
          reconciled[id] = _retainCallback(
            newItem,
            oldItem,
            origins[id] ?? oldItem,
          );
        }
        if (row.kind == TrayItemKind.submenu) {
          visit(row.items, match?.items ?? const []);
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

  void _setTitle(String title) {
    if (!capabilities.title) {
      return;
    }
    final isUnchanged = _title == title;
    _title = title;
    if (isUnchanged || !_isVisible) {
      return;
    }
    _host.setTitle(title);
  }

  void _hide() {
    _itemsById = const {};
    _signature = null;
    _menuGeneration = null;
    _shownMenu = null;
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
    _host.hide();
  }

  void _openMenu() {
    if (!capabilities.menuControl || !_isVisible) {
      return;
    }
    _host.openMenu();
  }

  void _listen() {
    _signals ??= _host.signals().listen(_onSignal);
  }

  void _onSignal(TraySignal signal) {
    switch (signal.kind) {
      case TraySignalKind.iconActivated:
        _events.add(const TrayIconActivated());
      case TraySignalKind.menuRequested:
        _events.add(const TrayMenuRequested());
      case TraySignalKind.menuGenerations:
        if (defaultTargetPlatform != TargetPlatform.macOS) {
          return;
        }
        _nativeMenuGenerations = signal.generations.take(3).toSet();
        _trackingMenuGeneration = signal.trackingGeneration;
        // The bridge delivers this signal after the show that caused it has
        // returned, so the menu it refers to may already be the shown one.
        final (candidateGeneration, candidate) = _pendingMenu != null
            ? (_pendingMenuGeneration, _pendingMenu)
            : (_menuGeneration, _shownMenu);
        if (candidate != null &&
            _nativeMenuGenerations.contains(candidateGeneration) &&
            _trackingMenuGeneration != null &&
            _trackingMenuGeneration != candidateGeneration) {
          _reconcileTrackedCallbacks(_trackingMenuGeneration!, candidate);
        }
        _pruneMenuGenerations();
      case TraySignalKind.itemSelected:
        final items = defaultTargetPlatform == TargetPlatform.macOS
            ? _menusByGeneration[signal.menuGeneration]
            : _itemsById;
        final item = items?[signal.itemId];
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

  /// Scales probed in Flutter's `2.0x/` variant layout. macOS takes every one
  /// found as a representation of one image, Linux the largest on disk, and
  /// Windows loads the asset as-is, so it names a multi-size `.ico`.
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

  Future<TrayImage> _resolveImage(TrayIcon icon) async {
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    return TrayImage(
      path: switch (defaultTargetPlatform) {
        TargetPlatform.macOS => '',
        TargetPlatform.linux => _largestBundledVariant(icon.asset),
        _ => _bundledPath(icon.asset),
      },
      pngs: isMacOS ? await _loadVariants(icon.asset) : const [],
      template: icon.isTemplate,
      size: icon.size,
      placement: switch (icon.position) {
        TrayIconPosition.leading => TrayIconPlacement.leading,
        TrayIconPosition.trailing => TrayIconPlacement.trailing,
      },
      dot: isMacOS ? icon.dot : null,
    );
  }

  Future<List<Uint8List>> _loadVariants(String asset) async {
    final variants = <Uint8List>[];
    for (final scale in variantScales) {
      final ByteData data;
      try {
        data = await rootBundle.load(variantAsset(asset, scale));
      } on FlutterError {
        continue;
      }
      variants.add(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    return variants;
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
