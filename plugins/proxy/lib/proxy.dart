import 'dart:io';

import 'package:flutter/foundation.dart';

import 'proxy_platform_interface.dart';
import 'src/linux_proxy.dart';
import 'src/macos_proxy.dart';
import 'src/proxy_command.dart';
import 'src/windows_proxy.dart';

export 'src/macos_proxy.dart' show MacosProxyEndpoint, MacosServiceProxy;
export 'src/proxy_command.dart' show ProxyExecutableChecker, ProxyProcessRunner;

/// What the system proxy held before Flash pointed it at itself, and what
/// Flash set. [services] is null where the platform cannot be read back, and
/// there a restore falls back to turning the proxy off.
@immutable
class SystemProxySnapshot {
  final Map<String, MacosServiceProxy>? services;
  final int port;
  final List<String> bypassDomain;

  SystemProxySnapshot({
    required Map<String, MacosServiceProxy>? services,
    required this.port,
    required List<String> bypassDomain,
  }) : services = services == null ? null : Map.unmodifiable(services),
       bypassDomain = List.unmodifiable(bypassDomain);

  bool get restorable => services != null;

  SystemProxySnapshot applying(int port, List<String> bypassDomain) {
    return SystemProxySnapshot(
      services: services,
      port: port,
      bypassDomain: bypassDomain,
    );
  }

  static SystemProxySnapshot? fromJson(Object? json) {
    if (json case {
      'services': final Map services,
      'port': final int port,
      'bypassDomain': final List bypassDomain,
    }) {
      final parsed = <String, MacosServiceProxy>{};
      for (final MapEntry(:key, :value) in services.entries) {
        final settings = MacosServiceProxy.fromJson(value);
        if (key is! String || settings == null) {
          return null;
        }
        parsed[key] = settings;
      }
      return SystemProxySnapshot(
        services: parsed,
        port: port,
        bypassDomain: bypassDomain.whereType<String>().toList(),
      );
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'services': {
      for (final MapEntry(:key, :value) in (services ?? const {}).entries)
        key: value.toJson(),
    },
    'port': port,
    'bypassDomain': bypassDomain,
  };
}

class Proxy {
  static const int _minPort = 1;
  static const int _maxPort = 65535;

  late final LinuxProxy _linuxProxy;
  late final MacosProxy _macosProxy;

  Proxy({
    ProxyProcessRunner? processRunner,
    ProxyExecutableChecker? executableChecker,
  }) {
    final commandRunner = ProxyCommandRunner(processRunner ?? Process.run);
    _linuxProxy = LinuxProxy(
      commandRunner: commandRunner,
      executableChecker: executableChecker,
    );
    _macosProxy = MacosProxy(commandRunner: commandRunner);
  }

  Future<bool> startProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) async {
    if (port < _minPort || port > _maxPort) {
      return false;
    }
    return switch (Platform.operatingSystem) {
      'macos' => await _macosProxy.start(port, bypassDomain),
      'linux' => await _linuxProxy.start(
        port,
        bypassDomain,
        desktop: Platform.environment['XDG_CURRENT_DESKTOP'],
        homeDir: Platform.environment['HOME'],
      ),
      'windows' => await ProxyPlatform.instance.startProxy(
        port,
        windowsBypassList(bypassDomain),
      ),
      String() => false,
    };
  }

  /// Reads what the system proxy holds before [startProxy] replaces it.
  /// Null when it cannot be read, and then it must not be replaced.
  Future<SystemProxySnapshot?> snapshotProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) async {
    if (Platform.operatingSystem != 'macos') {
      return SystemProxySnapshot(
        services: null,
        port: port,
        bypassDomain: bypassDomain,
      );
    }
    final services = await _macosProxy.read();
    if (services == null) {
      return null;
    }
    return SystemProxySnapshot(
      services: services,
      port: port,
      bypassDomain: bypassDomain,
    );
  }

  /// Undoes a [startProxy] recorded in [snapshot]. On macOS only services
  /// still set exactly as Flash left them are put back; others are left to
  /// whoever changed them. False when something could not be read or
  /// written, so the caller can try again.
  Future<bool> restoreProxy(SystemProxySnapshot snapshot) async {
    final services = snapshot.services;
    if (services == null) {
      return stopProxy();
    }
    if (Platform.operatingSystem != 'macos') {
      return false;
    }
    return _macosProxy.restore(
      services,
      MacosServiceProxy.applied(snapshot.port, snapshot.bypassDomain),
    );
  }

  /// macOS never turns the proxy off blindly; it goes through
  /// [restoreProxy].
  Future<bool> stopProxy() async {
    return switch (Platform.operatingSystem) {
      'macos' => false,
      'linux' => await _linuxProxy.stop(
        desktop: Platform.environment['XDG_CURRENT_DESKTOP'],
        homeDir: Platform.environment['HOME'],
      ),
      'windows' => await ProxyPlatform.instance.stopProxy(),
      String() => false,
    };
  }
}
