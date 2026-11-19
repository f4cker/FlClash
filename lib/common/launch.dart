import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rust_api/rust_api.dart' as rust_api;

import 'constant.dart';
import 'system.dart';

abstract interface class AutostartEntry {
  Future<bool> isEnabled();

  Future<bool> setEnabled(bool enabled);
}

class _SystemAutostartEntry implements AutostartEntry {
  const _SystemAutostartEntry();

  @override
  Future<bool> isEnabled() => rust_api.isAutostartEnabled(
    id: appName,
    executable: Platform.resolvedExecutable,
  );

  @override
  Future<bool> setEnabled(bool enabled) => rust_api.setAutostart(
    id: appName,
    displayName: appName,
    executable: Platform.resolvedExecutable,
    enabled: enabled,
  );
}

/// Flash registers its macOS login item through the Runner's
/// `launch_at_startup` channel (`MainFlutterWindow.swift`), which drives
/// `SMAppService.mainApp` and reports why a change was not applied
/// (`login_item_*` codes) instead of collapsing it into a Boolean.
class MacOSLoginItemEntry implements AutostartEntry {
  const MacOSLoginItemEntry();

  static const channel = MethodChannel('launch_at_startup');

  @override
  Future<bool> isEnabled() async {
    final enabled = await channel.invokeMethod<bool>(
      'launchAtStartupIsEnabled',
    );
    if (enabled == null) {
      throw PlatformException(code: 'login_item_missing_status');
    }
    return enabled;
  }

  @override
  Future<bool> setEnabled(bool enabled) async {
    await channel.invokeMethod<void>('launchAtStartupSetEnabled', {
      'setEnabledValue': enabled,
    });
    return true;
  }
}

class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal();

  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  @visibleForTesting
  static const AutostartEntry systemEntry = _SystemAutostartEntry();

  @visibleForTesting
  static AutostartEntry entry = Platform.isMacOS
      ? const MacOSLoginItemEntry()
      : systemEntry;

  Future<bool> get isEnable => entry.isEnabled();

  Future<void> refreshStatus(void Function(bool enabled) onVerified) async {
    onVerified(await isEnable);
  }

  Future<bool> enable() => entry.setEnabled(true);

  Future<bool> disable() => entry.setEnabled(false);

  Future<void> _update = Future.value();

  /// The bridge runs each call on its own worker, so an update waits for the
  /// write of the one before it rather than reading the entry around it.
  /// On macOS the login item is the user's choice in the toggle and in System
  /// Settings, so a boot never writes it.
  Future<void> updateStatus(bool isAutoLaunch) {
    if (kDebugMode || Platform.isMacOS) {
      return Future.value();
    }
    final update = _update.then((_) => _apply(isAutoLaunch));
    _update = update.then<void>((_) {}, onError: (Object _) {});
    return update;
  }

  Future<void> _apply(bool isAutoLaunch) async {
    if (await isEnable == isAutoLaunch) return;
    await entry.setEnabled(isAutoLaunch);
  }
}

final autoLaunch = system.isDesktop && !safeModeBuild ? AutoLaunch() : null;
