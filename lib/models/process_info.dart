import 'dart:io';

import 'package:flutter/foundation.dart';

import 'common.dart';

/// Where a connection's process info points.
enum ProcessKind {
  app,
  process,
  unknown,

  /// Shown only on evidence that the source is not this Mac.
  otherDevice,
}

enum AppLookupStatus { app, none, unreadable, failed }

@immutable
class MacApp {
  final String bundleId;
  final String name;
  final String bundlePath;
  final Uint8List? icon;

  const MacApp({
    required this.bundleId,
    required this.name,
    required this.bundlePath,
    this.icon,
  });

  String get key =>
      bundleId.isNotEmpty ? 'app:$bundleId' : 'bundle:$bundlePath';

  @override
  bool operator ==(Object other) =>
      other is MacApp &&
      other.bundleId == bundleId &&
      other.name == name &&
      other.bundlePath == bundlePath &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(bundleId, name, bundlePath, icon);
}

@immutable
class AppLookup {
  final AppLookupStatus status;
  final MacApp? app;

  const AppLookup._(this.status, this.app);

  const AppLookup.app(MacApp this.app) : status = AppLookupStatus.app;

  static const none = AppLookup._(AppLookupStatus.none, null);
  static const unreadable = AppLookup._(AppLookupStatus.unreadable, null);
  static const failed = AppLookup._(AppLookupStatus.failed, null);

  static AppLookup fromChannel(Object? raw) {
    if (raw is! Map) {
      return failed;
    }
    switch (raw['status']) {
      case 'none':
        return none;
      case 'unreadable':
        return unreadable;
      case 'app':
        final name = raw['name'];
        final bundlePath = raw['bundlePath'];
        if (name is! String || name.isEmpty || bundlePath is! String) {
          return unreadable;
        }
        final bundleId = raw['bundleId'];
        final icon = raw['icon'];
        return AppLookup.app(
          MacApp(
            bundleId: bundleId is String ? bundleId : '',
            name: name,
            bundlePath: bundlePath,
            icon: icon is Uint8List && icon.isNotEmpty ? icon : null,
          ),
        );
    }
    return failed;
  }
}

const otherDeviceProcessKey = 'device:other';

const _lanInbounds = {'HTTP', 'HTTPS', 'Socks4', 'Socks5'};

@immutable
class ConnectionProcess {
  final ProcessKind kind;
  final String name;
  final String path;
  final MacApp? app;

  /// The Mac has not answered for [path] yet.
  final bool pending;

  final bool appUnreadable;

  const ConnectionProcess._({
    required this.kind,
    this.name = '',
    this.path = '',
    this.app,
    this.pending = false,
    this.appUnreadable = false,
  });

  static const unknown = ConnectionProcess._(kind: ProcessKind.unknown);
  static const otherDevice = ConnectionProcess._(kind: ProcessKind.otherDevice);

  /// [lookup] is the Mac's answer for the process path, null while pending;
  /// [localAddresses] are this Mac's interface addresses, null when unread.
  factory ConnectionProcess.classify(
    Metadata metadata, {
    AppLookup? lookup,
    Set<String>? localAddresses,
  }) {
    final path = metadata.processPath.trim();
    final name = metadata.process.trim().isNotEmpty
        ? metadata.process.trim()
        : _baseName(path);
    if (name.isEmpty) {
      return isFromOtherDevice(metadata, localAddresses)
          ? otherDevice
          : unknown;
    }
    if (path.isEmpty) {
      return ConnectionProcess._(kind: ProcessKind.process, name: name);
    }
    final app = lookup?.app;
    if (app != null) {
      return ConnectionProcess._(
        kind: ProcessKind.app,
        name: name,
        path: path,
        app: app,
      );
    }
    return ConnectionProcess._(
      kind: ProcessKind.process,
      name: name,
      path: path,
      pending: lookup == null,
      appUnreadable: lookup?.status == AppLookupStatus.unreadable,
    );
  }

  bool get hasProcess => kind == ProcessKind.app || kind == ProcessKind.process;

  /// What filters and groups go by: a bundle or an executable, never a name
  /// two apps may share.
  String get key => switch (kind) {
    ProcessKind.app => app!.key,
    ProcessKind.process => path.isNotEmpty ? 'exe:$path' : 'proc:$name',
    ProcessKind.unknown => '',
    ProcessKind.otherDevice => otherDeviceProcessKey,
  };

  String get label => app?.name ?? name;

  @override
  bool operator ==(Object other) =>
      other is ConnectionProcess &&
      other.kind == kind &&
      other.name == name &&
      other.path == path &&
      other.app == app &&
      other.pending == pending &&
      other.appUnreadable == appUnreadable;

  @override
  int get hashCode =>
      Object.hash(kind, name, path, app, pending, appUnreadable);
}

String _baseName(String path) {
  final index = path.lastIndexOf('/');
  return index < 0 ? path : path.substring(index + 1);
}

String normalizeAddress(String address) {
  var value = address.trim().toLowerCase();
  final zone = value.indexOf('%');
  if (zone >= 0) {
    value = value.substring(0, zone);
  }
  if (value.startsWith('::ffff:') && value.contains('.')) {
    value = value.substring(7);
  }
  return value;
}

/// Only a LAN listener that took the connection on one of this Mac's own
/// addresses from an address this Mac does not have counts as evidence.
bool isFromOtherDevice(Metadata metadata, Set<String>? localAddresses) {
  if (localAddresses == null || localAddresses.isEmpty) {
    return false;
  }
  if (!_lanInbounds.contains(metadata.type)) {
    return false;
  }
  final source = InternetAddress.tryParse(normalizeAddress(metadata.sourceIP));
  final inbound = InternetAddress.tryParse(
    normalizeAddress(metadata.inboundIP),
  );
  if (source == null || inbound == null) {
    return false;
  }
  if (source.isLoopback || inbound.isLoopback) {
    return false;
  }
  return localAddresses.contains(normalizeAddress(inbound.address)) &&
      !localAddresses.contains(normalizeAddress(source.address));
}
