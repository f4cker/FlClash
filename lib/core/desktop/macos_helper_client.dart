import 'dart:async';
import 'dart:collection';

import 'package:fl_clash/common/constant.dart';
import 'package:flutter/services.dart';

const macosManagedHelperBuild = bool.fromEnvironment('MACOS_MANAGED_HELPER');
const macosHelperMaxFrame = 64 * 1024 * 1024;

/// User-facing state of the bundled SMAppService daemon.
enum MacHelperState {
  /// Registered, approved, and the running daemon answered for this build.
  enabled,

  /// The old pkg-installed helper (or its residue) must be removed first.
  migrationRequired,

  /// Registered but waiting for the user in Login Items & Extensions.
  requiresApproval,

  /// Was approved before; the user switched it off in System Settings.
  disabledByUser,

  /// Not yet registered with SMAppService.
  notRegistered,

  /// Approved; the daemon has not answered yet (launchd starts it on demand).
  starting,

  /// A daemon process from the previous app build still answers.
  staleHelper,

  /// The bundled daemon failed its pinned code-signing check.
  signatureFailed,

  /// The bundled daemon is missing/incompatible or Flash is not in /Applications.
  reinstallRequired,
  moveRequired,

  /// Removing the old helper or registering the new one did not finish.
  updateFailed,

  unsupported,
  disabled,
  exitUnconfirmed,
  unavailable;

  static MacHelperState parse(
    Object? code, [
    Object? previouslyEnabled,
  ]) => switch (code) {
    'enabled' => enabled,
    'requiresApproval' =>
      previouslyEnabled == true ? disabledByUser : requiresApproval,
    'notRegistered' => notRegistered,
    'migrationRequired' || 'authorizationCancelled' => migrationRequired,
    'migrationIncomplete' ||
    'migrationFailed' ||
    'registrationFailed' ||
    'authorizationDenied' => updateFailed,
    'staleHelper' => staleHelper,
    'signingRequired' => signatureFailed,
    'notFound' || 'incompatible' => reinstallRequired,
    'moveRequired' => moveRequired,
    'unsupported' => unsupported,
    'disabled' => disabled,
    'exitUnconfirmed' => exitUnconfirmed,
    // The bridge reports `unavailable` when an approved daemon does not answer yet.
    'unavailable' => starting,
    _ => unavailable,
  };
}

/// The step of the update that did not complete, as reported by the native side.
enum MacHelperFailedStep {
  stopOld,
  removeOld,
  registerNew,
  unknown;

  static MacHelperFailedStep parse(Object? value) =>
      values.firstWhere((step) => step.name == value, orElse: () => unknown);
}

final class MacHelperFailure {
  final MacHelperFailedStep step;

  /// Raw, copyable native error text. Never interpreted beyond the step.
  final String detail;

  const MacHelperFailure(this.step, this.detail);

  static MacHelperFailure? fromAnswer(Map<Object?, Object?> answer) {
    final code = answer['code'];
    String text(Object? value) => value is String ? value : '';
    final residue = answer['residue'];
    final residueText = residue is List && residue.isNotEmpty
        ? '\nresidue: ${residue.join(', ')}'
        : '';
    return switch (code) {
      'migrationFailed' => MacHelperFailure(
        MacHelperFailedStep.parse(answer['step']),
        '${text(answer['detail'])}$residueText'.trim(),
      ),
      'registrationFailed' => MacHelperFailure(
        MacHelperFailedStep.registerNew,
        'registrationFailed ${text(answer['domain'])} ${answer['error'] ?? ''}'
            .trim(),
      ),
      'migrationIncomplete' => MacHelperFailure(
        MacHelperFailedStep.unknown,
        'migrationIncomplete$residueText',
      ),
      'authorizationDenied' => const MacHelperFailure(
        MacHelperFailedStep.unknown,
        'authorizationDenied',
      ),
      _ => null,
    };
  }
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

  /// Raw code of the last native answer, shown under "View details".
  String? lastCode;

  /// Failed update step; kept until a later answer reports another outcome so
  /// a generic `migrationIncomplete` does not hide the step that failed.
  MacHelperFailure? failure;
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
  bool get hasCoreSession => _session != null;

  void _requireEffects() {
    if (_safeMode()) throw const MacHelperException('disabled');
  }

  MacHelperState _record(Map<Object?, Object?> answer) {
    final code = answer['code'];
    lastCode = code is String ? code : null;
    final state = code == 'authorizationCancelled'
        ? MacHelperState.parse(answer['status'] ?? 'migrationRequired')
        : MacHelperState.parse(code, answer['previouslyEnabled']);
    final next = MacHelperFailure.fromAnswer(answer);
    if (state != MacHelperState.updateFailed) {
      failure = null;
    } else if (next != null &&
        (next.step != MacHelperFailedStep.unknown || failure == null)) {
      failure = next;
    }
    return state;
  }

  Future<MacHelperState> _call(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    if (_safeMode()) return MacHelperState.disabled;
    try {
      final state = _record(await _native.invoke(method, arguments));
      if (_session != null && _relay?.active != true) {
        return MacHelperState.exitUnconfirmed;
      }
      return state;
    } on Exception {
      lastCode = 'channelError';
      return MacHelperState.unavailable;
    }
  }

  Future<MacHelperState> status() => _call('status');

  /// Remove the old helper (one administrator prompt) and register the daemon.
  Future<MacHelperState> migrate({required bool confirmed}) {
    if (!confirmed) throw const MacHelperException('consentRequired');
    _requireEffects();
    if (_session != null) return Future.value(MacHelperState.exitUnconfirmed);
    return _call('migrate', {'confirmed': true});
  }

  /// Register with SMAppService; no administrator prompt.
  Future<MacHelperState> enable() {
    _requireEffects();
    return _call('enable');
  }

  /// Retire a daemon process left over from the previous app build.
  Future<MacHelperState> repair() {
    _requireEffects();
    return _call('repair');
  }

  Future<void> openSettings() async {
    _requireEffects();
    await _native.invoke('openApprovalSettings');
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
    if (_maintenance) {
      throw const MacHelperException('maintenance');
    }
    if (_session != null) throw const MacHelperException('exitUnconfirmed');
    final state = await status();
    if (_maintenance) {
      throw const MacHelperException('maintenance');
    }
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
