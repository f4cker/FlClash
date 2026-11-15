import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/tray_menu.dart';
import 'package:fl_clash/widgets/icon.dart' show targetIconCacheRevision;
import 'package:prism_ui/prism_ui.dart' show ColorScheme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray/tray.dart';

class TrayManager extends ConsumerStatefulWidget {
  final Widget child;
  final bool? isMacOS;

  const TrayManager({super.key, this.isMacOS, required this.child});

  @override
  ConsumerState<TrayManager> createState() => _TrayManagerState();
}

class _TrayManagerState extends ConsumerState<TrayManager> {
  StreamSubscription<TrayEvent>? _subscription;
  bool _isUpdating = false;
  bool _hasPendingUpdate = false;
  ProviderSubscription<ColorScheme>? _schemeSubscription;

  bool get _isMacOS => widget.isMacOS ?? system.isMacOS;

  @override
  void initState() {
    super.initState();
    _subscription = Tray.instance.events.listen(_handleTrayEvent);
    ref.listenManual(trayStateProvider, (prev, next) {
      if (prev != next) {
        _requestUpdate();
      }
    });
    ref.listenManual(loadedLocaleProvider, (prev, next) {
      if (prev != null && prev != next) {
        _requestUpdate();
      }
    });
    if (_isMacOS) {
      ref.listenManual(groupsProvider, _onMenuDataChanged);
      ref.listenManual(profilesProvider, _onMenuDataChanged);
      ref.listenManual(
        proxiesStyleSettingProvider.select((state) => state.showHiddenGroups),
        _onMenuDataChanged,
      );
      ref.listenManual(trayGroupMenuStatesProvider, _onMenuDataChanged);
      ref.listenManual(trayModeMenuStateProvider, _onMenuDataChanged);
      ref.listenManual(trayGroupsReadFailedProvider, _onMenuDataChanged);
      ref.listenManual<int?>(currentProfileIdProvider, (prev, next) {
        _onMenuDataChanged(prev, next);
      });
      ref.listenManual(coreStatusProvider, _onMenuDataChanged);
      ref.listenManual(delayTestingGroupsProvider, _onMenuDataChanged);
      // PendingDelayTests publishes live map views. Earlier views already show
      // the new phases, so deep comparison would suppress running/finished
      // notifications. Its provider only publishes when a phase changes.
      ref.listenManual(pendingDelayTestsProvider, (_, _) => _requestUpdate());
      ref.listenManual(
        patchClashConfigProvider.select((state) => state.testUrl),
        _onMenuDataChanged,
      );
      _listenToScheme(ref.read(currentBrightnessProvider));
      ref.listenManual(currentBrightnessProvider, (prev, next) {
        if (prev == next) return;
        _listenToScheme(next);
        _requestUpdate();
      });
      targetIconCacheRevision.addListener(_requestUpdate);
      ref.listenManual(trayDelaysProvider, (prev, next) {
        if (!const DeepCollectionEquality().equals(prev, next)) {
          _requestUpdate();
        }
      });
      ref.listenManual(trayTitleStateProvider, (prev, next) {
        if (prev != next) {
          _reportFailure(
            appTray?.updateTitle(
              showTrayTitle: next.showTrayTitle,
              traffic: next.traffic,
            ),
          );
        }
      });
    }
  }

  void _onMenuDataChanged(Object? prev, Object? next) {
    if (!const DeepCollectionEquality().equals(prev, next)) _requestUpdate();
  }

  void _listenToScheme(Brightness brightness) {
    _schemeSubscription?.close();
    _schemeSubscription = ref.listenManual(
      genColorSchemeProvider(brightness),
      _onMenuDataChanged,
    );
  }

  void _requestUpdate() {
    if (!mounted) return;
    if (_isUpdating) {
      _hasPendingUpdate = true;
      return;
    }
    _isUpdating = true;
    _reportFailure(_drainUpdates());
  }

  Future<void> _drainUpdates() async {
    try {
      do {
        _hasPendingUpdate = false;
        await ref.read(systemActionProvider.notifier).updateTray();
      } while (_hasPendingUpdate && mounted);
    } finally {
      _isUpdating = false;
      if (_hasPendingUpdate && mounted) {
        _requestUpdate();
      }
    }
  }

  void _reportFailure(Future<void>? operation) {
    if (operation == null) {
      return;
    }
    unawaited(
      operation.onError<Object>((error, stackTrace) {
        commonPrint.log(
          'Tray operation failed: ${compactError(error)}',
          logLevel: LogLevel.error,
        );
      }),
    );
  }

  void _handleTrayEvent(TrayEvent event) {
    switch (event) {
      case TrayIconActivated():
        window?.show();
      case TrayMenuRequested():
        _reportFailure(Tray.instance.openMenu());
      case TrayMenuItemSelected():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _schemeSubscription?.close();
    if (_isMacOS) {
      targetIconCacheRevision.removeListener(_requestUpdate);
    }
    super.dispose();
  }
}
