import 'dart:async';
import 'dart:collection';

import 'package:fl_clash/common/constant.dart';
import 'package:flutter/services.dart';

const macosManagedHelperBuild = bool.fromEnvironment('MACOS_MANAGED_HELPER');
const macosHelperMaxFrame = 64 * 1024 * 1024;

enum MacHelperState {
  off,
  installerRequired,
  updateRequired,
  enabled,
  approvalRequired,
  unavailable,
  incompatible,
  signingRequired,
  protectedInstallationRequired,
  unsupported,
  disabled,
  denied,
  repairRequired,
  exitUnconfirmed;

  static MacHelperState parse(Object? code) => values.firstWhere(
    (value) => value.name == code,
    orElse: () => unavailable,
  );
}

abstract interface class MacHelperNativeApi {
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]);
}

final class MacHelperMethodChannel implements MacHelperNativeApi {
  static const _channel = MethodChannel('com.layoute.flash/managed_helper');

  const MacHelperMethodChannel();

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    return await _channel.invokeMapMethod<Object?, Object?>(
          method,
          arguments,
        ) ??
        const {'code': 'unavailable'};
  }
}

final class MacHelperException implements Exception {
  final String code;

  const MacHelperException(this.code);

  @override
  String toString() => 'MacHelperException($code)';
}

sealed class MacHelperEvent {
  const MacHelperEvent();
}

final class MacHelperConnected extends MacHelperEvent {
  final int pid;
  const MacHelperConnected(this.pid);
}

final class MacHelperDisconnected extends MacHelperEvent {
  final Object? error;
  const MacHelperDisconnected([this.error]);
}

final class MacHelperFrame extends MacHelperEvent {
  final Uint8List data;
  const MacHelperFrame(this.data);
}

final class _MacHelperRelay {
  final String session;
  final frames = ListQueue<Uint8List>();
  int queuedBytes = 0;
  bool active = true;
  bool disconnected = false;

  _MacHelperRelay(this.session);

  void invalidate() {
    active = false;
    frames.clear();
    queuedBytes = 0;
  }
}

final class MacHelperClient {
  static const _maxQueuedFrames = 256;
  static const _relayDelay = Duration(milliseconds: 16);
  final MacHelperNativeApi _native;
  final bool Function() _safeMode;
  final int _backpressureRetries;
  final _events = StreamController<MacHelperEvent>.broadcast();
  String? _session;
  String? _lastStopped;
  bool _maintenance = false;
  _MacHelperRelay? _relay;
  bool _sending = false;

  MacHelperClient({
    MacHelperNativeApi native = const MacHelperMethodChannel(),
    bool Function()? safeMode,
    int backpressureRetries = 500,
  }) : assert(backpressureRetries >= 0),
       _native = native,
       _safeMode = safeMode ?? (() => safeModeBuild),
       _backpressureRetries = backpressureRetries;

  Stream<MacHelperEvent> get events => _events.stream;

  void _requireEffects() {
    if (_safeMode()) throw const MacHelperException('disabled');
  }

  Future<MacHelperState> status() async {
    if (_safeMode()) return MacHelperState.disabled;
    try {
      return MacHelperState.parse((await _native.invoke('status'))['code']);
    } on Exception {
      return MacHelperState.unavailable;
    }
  }

  Future<MacHelperState> installerInstructions({
    required bool confirmed,
  }) async {
    _requireEffects();
    if (!confirmed) throw const MacHelperException('consentRequired');
    return MacHelperState.parse(
      (await _native.invoke('installerInstructions', {
        'confirmed': true,
      }))['code'],
    );
  }

  Future<MacHelperState> maintain(
    Future<MacHelperState> Function() action,
  ) async {
    _requireEffects();
    if (_maintenance) throw const MacHelperException('maintenance');
    _maintenance = true;
    try {
      return await action();
    } finally {
      _maintenance = false;
    }
  }

  Future<int> start(String session) async {
    _requireEffects();
    if (_maintenance) throw const MacHelperException('maintenance');
    if (_session != null) throw const MacHelperException('exitUnconfirmed');
    final state = await status();
    if (state != MacHelperState.enabled) throw MacHelperException(state.name);
    _session = session;
    final relay = _relay = _MacHelperRelay(session);
    _lastStopped = null;
    try {
      final result = await _native.invoke('start', {'session': session});
      final pid = result['pid'];
      if (result['code'] != 'ok' ||
          result['protocol'] != 1 ||
          pid is! int ||
          pid <= 0) {
        if (result['exitConfirmed'] == true) {
          relay.invalidate();
          _session = null;
          _lastStopped = session;
        }
        throw MacHelperException(result['code'] as String? ?? 'incompatible');
      }
      _events.add(MacHelperConnected(pid));
      unawaited(_receive(relay));
      return pid;
    } catch (_) {
      await stop(session);
      rethrow;
    }
  }

  Future<bool> stop(String session) async {
    _requireEffects();
    if (_session != session) return _session == null && _lastStopped == session;
    final relay = _relay;
    relay?.invalidate();
    try {
      final result = await _invokeWithBackpressure('stop', {
        'session': session,
      }, () => identical(relay, _relay) && _session == session);
      if (result['code'] != 'ok' || result['exitConfirmed'] != true) {
        return false;
      }
      if (!identical(relay, _relay)) return true;
      _session = null;
      _lastStopped = session;
      if (relay != null) _disconnect(relay);
      return true;
    } on Exception {
      return false;
    }
  }

  bool _isLive(_MacHelperRelay relay) =>
      identical(relay, _relay) && relay.active;

  void _disconnect(_MacHelperRelay relay, [Object? error]) {
    if (!identical(relay, _relay) || relay.disconnected) return;
    relay.invalidate();
    relay.disconnected = true;
    _events.add(MacHelperDisconnected(error));
  }

  Future<Map<Object?, Object?>> _invokeWithBackpressure(
    String method,
    Map<String, Object?> arguments,
    bool Function() isCurrent,
  ) async {
    for (var retries = 0; ; retries++) {
      final result = await _native.invoke(method, arguments);
      // Only explicit predispatch refusal is safe to retry; other failures may
      // already have delivered the request. 500 delays match the bridge's 8 s.
      if (result['code'] != 'backpressure' ||
          retries >= _backpressureRetries ||
          !isCurrent()) {
        return result;
      }
      await Future<void>.delayed(_relayDelay);
      if (!isCurrent()) return result;
    }
  }

  Future<void> _receive(_MacHelperRelay relay) async {
    try {
      while (_isLive(relay)) {
        final result = await _invokeWithBackpressure('receive', {
          'session': relay.session,
        }, () => _isLive(relay));
        if (!_isLive(relay)) return;
        if (result['code'] != 'ok') {
          throw MacHelperException(result['code'] as String? ?? 'unavailable');
        }
        final frame = result['frame'];
        if (frame != null) {
          if (frame is! Uint8List || frame.length > macosHelperMaxFrame) {
            throw const MacHelperException('invalidFrame');
          }
          _events.add(MacHelperFrame(frame));
        }
        await Future<void>.delayed(_relayDelay);
      }
    } catch (error) {
      if (_isLive(relay)) _disconnect(relay, error);
    }
  }

  void send(List<int> frame) {
    _requireEffects();
    final relay = _relay;
    if (relay == null || !_isLive(relay)) {
      throw const MacHelperException('notConnected');
    }
    if (frame.length > macosHelperMaxFrame ||
        (frame is! Uint8List && frame.any((byte) => byte < 0 || byte > 255))) {
      throw const MacHelperException('invalidFrame');
    }
    if (relay.queuedBytes + frame.length > macosHelperMaxFrame ||
        relay.frames.length >= _maxQueuedFrames) {
      throw const MacHelperException('backpressure');
    }
    final copy = Uint8List.fromList(frame);
    relay.frames.addLast(copy);
    relay.queuedBytes += copy.length;
    if (!_sending) unawaited(_send());
  }

  Future<void> _send() async {
    _sending = true;
    try {
      while (true) {
        final relay = _relay;
        if (relay == null || !_isLive(relay) || relay.frames.isEmpty) return;
        final frame = relay.frames.first;
        try {
          final answer = await _invokeWithBackpressure('send', {
            'session': relay.session,
            'frame': frame,
          }, () => _isLive(relay));
          if (!_isLive(relay)) continue;
          if (answer['code'] != 'ok') {
            throw MacHelperException(
              answer['code'] as String? ?? 'unavailable',
            );
          }
          relay.frames.removeFirst();
          relay.queuedBytes -= frame.length;
        } catch (error) {
          if (_isLive(relay)) _disconnect(relay, error);
        }
      }
    } finally {
      _sending = false;
    }
  }
}

final macosHelperClient = MacHelperClient();
