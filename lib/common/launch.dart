import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'constant.dart';
import 'system.dart';

class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal() {
    launcher.setup(
      appName: appCompatName,
      appPath: Platform.resolvedExecutable,
    );
  }

  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  @visibleForTesting
  static LaunchAtStartup launcher = Platform.isMacOS
      ? MacOSLoginItemLauncher()
      : launchAtStartup;

  Future<bool> get isEnable async {
    return launcher.isEnabled();
  }

  Future<void> refreshStatus(void Function(bool enabled) onVerified) async {
    onVerified(await isEnable);
  }

  Future<bool> enable() async {
    return launcher.enable();
  }

  Future<bool> disable() async {
    return launcher.disable();
  }

  Future<void> updateStatus(bool isAutoLaunch) async {
    if (kDebugMode || Platform.isMacOS) {
      return;
    }
    if (await isEnable == isAutoLaunch) return;
    if (isAutoLaunch == true) {
      unawaited(enable());
    } else {
      unawaited(disable());
    }
  }
}

class MacOSLoginItemLauncher implements LaunchAtStartup {
  static const channel = MethodChannel('launch_at_startup');

  @override
  void setup({
    required String appName,
    required String appPath,
    String? packageName,
    List<String> args = const [],
  }) {}

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

  Future<bool> _setEnabled(bool enabled) async {
    await channel.invokeMethod<void>('launchAtStartupSetEnabled', {
      'setEnabledValue': enabled,
    });
    return true;
  }

  @override
  Future<bool> enable() => _setEnabled(true);

  @override
  Future<bool> disable() => _setEnabled(false);
}

final autoLaunch = system.isDesktop && !safeModeBuild ? AutoLaunch() : null;
