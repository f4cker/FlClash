import 'dart:async';

import 'package:fl_clash/common/constant.dart';
import 'package:flutter/services.dart';

const macosManagedHelperBuild = bool.fromEnvironment('MACOS_MANAGED_HELPER');
const macosHelperMaxFrame = 64 * 1024 * 1024;

enum MacHelperState {
  off,
  installerRequired,
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

final class MacHelperClient {
  final MacHelperNativeApi _native;
  final bool Function() _safeMode;
  final _events = StreamController<MacHelperEvent>.broadcast();
  String? _session;
  String? _lastStopped;
  bool _maintenance = false;
  int _readRevision = 0;
  int _queuedBytes = 0;
  int _pendingSends = 0;

  MacHelperClient({
    MacHelperNativeApi native = const MacHelperMethodChannel(),
    bool Function()? safeMode,
  }) : _native = native,
       _safeMode = safeMode ?? (() => safeModeBuild);

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
    _lastStopped = null;
    try {
      final result = await _native.invoke('start', {'session': session});
      final pid = result['pid'];
      if (result['code'] != 'ok' ||
          result['protocol'] != 1 ||
          pid is! int ||
          pid <= 0) {
        if (result['exitConfirmed'] == true) {
          _session = null;
          _lastStopped = session;
        }
        throw MacHelperException(result['code'] as String? ?? 'incompatible');
      }
      _events.add(MacHelperConnected(pid));
      final revision = ++_readRevision;
      unawaited(_receive(session, revision));
      return pid;
    } catch (_) {
      await stop(session);
      rethrow;
    }
  }

  Future<bool> stop(String session) async {
    _requireEffects();
    if (_session != session) return _session == null && _lastStopped == session;
    try {
      final result = await _native.invoke('stop', {'session': session});
      if (result['code'] != 'ok' || result['exitConfirmed'] != true) {
        return false;
      }
      _session = null;
      _lastStopped = session;
      _readRevision++;
      _events.add(const MacHelperDisconnected());
      return true;
    } on Exception {
      return false;
    }
  }

  Future<void> _receive(String session, int revision) async {
    try {
      while (revision == _readRevision && session == _session) {
        final result = await _native.invoke('receive', {'session': session});
        if (revision != _readRevision) return;
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
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } catch (error) {
      if (revision == _readRevision) {
        _readRevision++;
        _events.add(MacHelperDisconnected(error));
      }
    }
  }

  void send(List<int> frame) {
    _requireEffects();
    final session = _session;
    if (session == null ||
        frame.length > macosHelperMaxFrame ||
        _queuedBytes + frame.length > macosHelperMaxFrame ||
        _pendingSends >= 32) {
      throw const MacHelperException('backpressure');
    }
    _queuedBytes += frame.length;
    _pendingSends++;
    unawaited(_send(session, Uint8List.fromList(frame)));
  }

  Future<void> _send(String session, Uint8List frame) async {
    try {
      final answer = await _native.invoke('send', {
        'session': session,
        'frame': frame,
      });
      if (answer['code'] != 'ok') throw const MacHelperException('sendFailed');
    } catch (error) {
      if (_session == session) _events.add(MacHelperDisconnected(error));
    } finally {
      _queuedBytes -= frame.length;
      _pendingSends--;
    }
  }
}

final macosHelperClient = MacHelperClient();
