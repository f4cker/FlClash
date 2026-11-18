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

  /// The bundle is intact and trusted, but SMAppService has no record that
  /// matches it (status notFound). Only the user's "Repair" re-registers it
  /// (the same recovery as a stale registration); never automatic.
  serviceNotFound,

  /// That repair registered the daemon again and SMAppService still reports
  /// notFound. Shown with the details; not retried by itself.
  serviceRepairFailed,
  moveRequired,

  /// Removing the old helper or registering the new one did not finish.
  updateFailed,

  /// launchd still holds the previous build's job and cannot start this
  /// helper (launch constraint not refreshed), or the daemon is still
  /// registered under its retired name: the app re-registers it.
  registrationStale,

  /// A recovery of the registration is running; nothing reconnects meanwhile.
  repairing,

  /// The recovery finished but the new helper did not answer in time.
  notReady,

  /// The new helper answered, but could not confirm that no old Core runs.
  staleCore,

  /// The daemon is enabled but does not answer, and FlashHelperLauncher
  /// reported why (read-only status file; display only, never trusted):
  /// the helper failed its signature/location/version check,
  launcherCheckFailed,

  /// is older than one that already ran (downgrade refused),
  launcherDowngrade,

  /// or could not be prepared or started (or the status is unreadable).
  launcherFailed,

  /// The launcher verified the helper but cannot read or write its root-only
  /// version record. Reinstalling does not change that record; the card's
  /// repair (one administrator prompt) rebuilds it.
  launcherRecordDamaged,

  /// The helper answered, but its reply failed the app's own verification
  /// (the failed step is in the details). Waiting or re-registering cannot
  /// change that, so nothing is retried or re-registered for it.
  untrustedReply,

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
    // A registration under the retired name (com.layoute.flash.daemon) is
    // still there: the same recovery moves it to the current name.
    'registrationStale' || 'retiredRegistration' => registrationStale,
    'repairInProgress' || 'operationInProgress' => repairing,
    'helperNotReady' => notReady,
    'staleCoreUnconfirmed' => staleCore,
    'migrationIncomplete' ||
    'migrationFailed' ||
    'registrationFailed' ||
    'authorizationDenied' => updateFailed,
    'staleHelper' => staleHelper,
    'signingRequired' => signatureFailed,
    'notFound' || 'incompatible' => reinstallRequired,
    'serviceNotFound' => serviceNotFound,
    'moveRequired' => moveRequired,
    'unsupported' => unsupported,
    'disabled' => disabled,
    'exitUnconfirmed' => exitUnconfirmed,
    'launcherCheckFailed' => launcherCheckFailed,
    'launcherDowngrade' => launcherDowngrade,
    'launcherFailed' => launcherFailed,
    'launcherRecordDamaged' => launcherRecordDamaged,
    'untrustedReply' => untrustedReply,
    // The bridge reports `unavailable` when an approved daemon does not answer
    // yet, and `timeout` when it did not answer in time: both are a wait (and
    // "taking longer" after the bounded start-up wait), never a Core claim.
    'unavailable' || 'timeout' => starting,
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

  /// Frames of the Core taken so far (the `ack` of the next receive); the
  /// daemon keeps every later one queued until a receive acknowledges it.
  int received = 0;

  /// App frames the daemon confirmed (the `seq` of the next send); a retry of
  /// one whose reply was lost is recognised and not written twice.
  int sent = 0;

  /// Recent transient relay failures (see [MacHelperClient._relayFailed]).
  final failures = ListQueue<DateTime>();

  /// When the daemon last answered a relay request with ok (or the session
  /// started).
  DateTime lastOk;

  _MacHelperRelay(this.session, this.lastOk);

  void invalidate() {
    active = false;
    frames.clear();
    queuedBytes = 0;
  }
}

final class MacHelperClient {
  static const _maxQueuedFrames = 256;
  static const _relayDelay = Duration(milliseconds: 16);

  /// Answers that say nothing about the Core: the bridge got no (verifiable)
  /// reply, or it is reconnecting. The relay is retried with the same
  /// `ack`/`seq`, so nothing is lost or duplicated; every reply used still
  /// passed the bridge's full verification.
  static const transientRelayCodes = {
    'unavailable',
    'timeout',
    'untrustedReply',
    'staleHelper',
    'backpressure',
    'operationInProgress',
    'repairInProgress',
  };
  final MacHelperNativeApi _native;
  final bool Function() _safeMode;
  final int _backpressureRetries;
  final int _maxRelayFailures;
  final Duration _relayFailureWindow;
  final Duration _relayLostAfter;
  final Duration _relayRetryDelay;
  final DateTime Function() _now;
  final _events = StreamController<MacHelperEvent>.broadcast();
  String? _session;
  String? _lastStopped;
  bool _maintenance = false;

  /// Raw code of the last native answer, shown under "View details".
  String? lastCode;

  /// Raw native text of the last answer that carried any (system errors with
  /// their domain, code and userInfo, launchd's view of the job, the helper's
  /// sweep result). Only ever shown under "View details".
  String? lastDetail;

  /// SMAppService.status the native side read right after a failed
  /// register (`serviceStatus`), from the last answer; null when it carried
  /// none.
  String? lastServiceStatus;

  /// Failed update step; kept until a later answer reports another outcome so
  /// a generic `migrationIncomplete` does not hide the step that failed.
  MacHelperFailure? failure;

  /// Outcome of the last version record repair (`ok`, `cancelled`,
  /// `denied`, `failed`, `notNeeded`), from the answer that carried it; null
  /// after any other answer.
  String? lastRecordRepair;
  _MacHelperRelay? _relay;
  bool _sending = false;

  MacHelperClient({
    MacHelperNativeApi native = const MacHelperMethodChannel(),
    bool Function()? safeMode,
    int backpressureRetries = 500,
    int maxRelayFailures = 3,
    Duration relayFailureWindow = const Duration(seconds: 10),
    Duration relayLostAfter = const Duration(seconds: 12),
    Duration relayRetryDelay = const Duration(milliseconds: 250),
    DateTime Function()? now,
  }) : assert(backpressureRetries >= 0),
       assert(maxRelayFailures >= 1),
       _native = native,
       _safeMode = safeMode ?? (() => safeModeBuild),
       _backpressureRetries = backpressureRetries,
       _maxRelayFailures = maxRelayFailures,
       _relayFailureWindow = relayFailureWindow,
       _relayLostAfter = relayLostAfter,
       _relayRetryDelay = relayRetryDelay,
       _now = now ?? DateTime.now;

  Stream<MacHelperEvent> get events => _events.stream;
  bool get hasCoreSession => _session != null;

  /// A session whose relay to the daemon is still up (not lost or stopped).
  bool get relayLive {
    final relay = _relay;
    return relay != null && _session != null && _isLive(relay);
  }

  bool get maintenanceInProgress => _maintenance;

  void _requireEffects() {
    if (_safeMode()) throw const MacHelperException('disabled');
  }

  /// The raw native text of [answer] for "View details", or null.
  static String? describeAnswer(Map<Object?, Object?> answer) {
    String? text(Object? value) =>
        value is String && value.isNotEmpty ? value : null;
    final lines = [
      ?text(answer['detail']),
      if (text(answer['domain']) case final domain?)
        'error: $domain ${answer['error'] ?? ''}'.trim(),
      if (text(answer['launchd']) case final launchd?) 'launchd: $launchd',
      if (text(answer['reason']) case final reason?) 'helper: $reason',
    ];
    return lines.isEmpty ? null : lines.join('\n');
  }

  MacHelperState _record(Map<Object?, Object?> answer) {
    final code = answer['code'];
    lastCode = code is String ? code : null;
    final serviceStatus = answer['serviceStatus'];
    lastServiceStatus = serviceStatus is String ? serviceStatus : null;
    final recordRepair = answer['recordRepair'];
    lastRecordRepair = recordRepair is String ? recordRepair : null;
    final detail = describeAnswer(answer);
    if (detail != null) lastDetail = detail;
    final state = code == 'authorizationCancelled'
        ? MacHelperState.parse(answer['status'] ?? 'migrationRequired')
        : code == 'serviceNotFound' && answer['afterRepair'] == true
        ? MacHelperState.serviceRepairFailed
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
      final sessionAtRequest = _session;
      final relayAtRequest = _relay;
      final answer = await _native.invoke(method, arguments);
      final state = _record(answer);
      // A session this app could not stop. Only the daemon can settle it: once
      // it answers that it owns no Core, the session is gone; while it still
      // owns one (or cannot tell), the ready state is not claimed. Any other
      // state describes the helper itself and is shown as is.
      if (sessionAtRequest != null &&
          _session == sessionAtRequest &&
          identical(_relay, relayAtRequest) &&
          _relay?.active != true &&
          state == MacHelperState.enabled) {
        if (!_confirmsNoCore(answer)) return MacHelperState.exitUnconfirmed;
        _forgetSession();
      }
      return state;
    } on Exception {
      lastCode = 'channelError';
      return MacHelperState.unavailable;
    }
  }

  Future<MacHelperState> status() => _call('status');

  /// The daemon's own word that no Core of it runs: no child and its exit
  /// confirmed. Absent fields (no authenticated reply) never confirm.
  static bool _confirmsNoCore(Map<Object?, Object?> answer) =>
      answer['exitConfirmed'] == true && answer['pid'] == 0;

  void _forgetSession() {
    final session = _session;
    final relay = _relay;
    _session = null;
    _lastStopped = session;
    if (relay != null) _disconnect(relay);
  }

  /// Remove the old helper (one administrator prompt) and register the daemon.
  Future<MacHelperState> migrate({required bool confirmed}) {
    if (!confirmed) throw const MacHelperException('consentRequired');
    _requireEffects();
    if (_session != null) return Future.value(MacHelperState.exitUnconfirmed);
    return _call('migrate', {'confirmed': true});
  }

  /// Rebuild the launcher's version record (one administrator prompt), then
  /// ask the helper again. The native side runs it only while the launcher
  /// reports that record unreadable.
  Future<MacHelperState> repairLauncherRecord({required bool confirmed}) {
    if (!confirmed) throw const MacHelperException('consentRequired');
    _requireEffects();
    return _call('repairRecord', {'confirmed': true});
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

  /// Re-register a stale registration (native: unregister, wait for launchd,
  /// register, ask SMAppService.status, wait for the new helper). Only inside
  /// [maintain], after the app wrote its repair record and stopped its Core.
  Future<MacHelperState> recover() {
    if (!_maintenance) throw const MacHelperException('maintenance');
    _requireEffects();
    lastDetail = null;
    return _call('recover', {'repairRecordWritten': true});
  }

  /// Asks the new helper to stop every Core it does not run itself, found by
  /// code signature, and to confirm they exited. Returns the helper's code:
  /// `noStaleCore`, `staleCoreStopped`, `staleCoreUnconfirmed`, or a reason
  /// the helper could not be asked.
  Future<String> retireStaleCores() async {
    if (!_maintenance) throw const MacHelperException('maintenance');
    _requireEffects();
    try {
      final answer = await _native.invoke('retireCores');
      final code = answer['code'];
      lastCode = code is String ? code : 'unavailable';
      final detail = describeAnswer(answer);
      if (detail != null) lastDetail = detail;
      return lastCode!;
    } on Exception {
      lastCode = 'channelError';
      return lastCode!;
    }
  }

  /// SMAppService.status only (no trust checks, no hello): cheap enough to
  /// poll while the user is in System Settings.
  Future<MacHelperState> approvalStatus() async {
    if (_safeMode()) return MacHelperState.disabled;
    try {
      final answer = await _native.invoke('approvalStatus');
      return MacHelperState.parse(answer['code']);
    } on Exception {
      return MacHelperState.unavailable;
    }
  }

  Future<void> openSettings() async {
    _requireEffects();
    final answer = await _native.invoke('openApprovalSettings');
    final code = answer['code'];
    if (code != 'settingsOpened') {
      throw MacHelperException(code is String ? code : 'unavailable');
    }
  }

  Future<T> maintain<T>(Future<T> Function() action) async {
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
    final relay = _relay = _MacHelperRelay(session, _now());
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
      // Stopped, or the daemon owns no Core at all (for example it was
      // restarted and no longer knows this session).
      final confirmed =
          result['exitConfirmed'] == true &&
          (result['code'] == 'ok' || result['pid'] == 0);
      // A status meanwhile may have heard from the daemon that no Core runs.
      if (!confirmed) return _session == null && _lastStopped == session;
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
    // A relay that ends while still wanted is a lost session: say why in the
    // system log too (the bridge's own lines only cover its side).
    // The bridge then no longer holds the session either (repair and disable
    // are not refused for it).
    if (error != null) _note('relay lost: $error', method: 'relayLost');
    _events.add(MacHelperDisconnected(error));
  }

  /// Leaves [reason] in the unified log (subsystem com.layoute.flash) through
  /// the bridge; best effort, never awaited by the relay.
  void _note(String reason, {String method = 'note'}) {
    unawaited(
      Future.sync(
        () => _native.invoke(method, {'reason': reason}),
      ).then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Whether [error] only says that this request went unanswered.
  static bool _transient(Object error) => switch (error) {
    MacHelperException(:final code) => transientRelayCodes.contains(code),
    PlatformException() || TimeoutException() => true,
    _ => false,
  };

  /// One relay request, sent at [sent], failed. A transient failure is
  /// retried (after a short, growing delay) unless [_maxRelayFailures]
  /// failures fell within [_relayFailureWindow], or no request got ok for
  /// [_relayLostAfter] (a daemon that hangs fails each request only after the
  /// bridge's timeout); then, and on any other failure, the relay is lost.
  /// Requests that were already in flight when a failure was counted share
  /// it: one dropped connection fails `send` and `receive` alike.
  /// Returns whether to retry.
  Future<bool> _relayFailed(
    _MacHelperRelay relay,
    String method,
    Object error,
    DateTime sent,
  ) async {
    if (!_isLive(relay)) return false;
    if (!_transient(error)) {
      _disconnect(relay, error);
      return false;
    }
    final now = _now();
    if (relay.failures.isEmpty || !sent.isBefore(relay.failures.last)) {
      relay.failures.addLast(now);
    }
    while (relay.failures.isNotEmpty &&
        now.difference(relay.failures.first) > _relayFailureWindow) {
      relay.failures.removeFirst();
    }
    if (relay.failures.length >= _maxRelayFailures ||
        now.difference(relay.lastOk) >= _relayLostAfter) {
      _disconnect(relay, error);
      return false;
    }
    _note(
      '$method failed ($error), retry ${relay.failures.length}/'
      '${_maxRelayFailures - 1}',
    );
    await Future<void>.delayed(_relayRetryDelay * relay.failures.length);
    return _isLive(relay);
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
    while (_isLive(relay)) {
      final sent = _now();
      try {
        final result = await _invokeWithBackpressure('receive', {
          'session': relay.session,
          'ack': relay.received,
        }, () => _isLive(relay));
        if (!_isLive(relay)) return;
        if (result['code'] != 'ok') {
          throw MacHelperException(result['code'] as String? ?? 'unavailable');
        }
        relay.lastOk = _now();
        final frames = result['frames'];
        final base = result['seq'];
        // Every queued frame from `ack` on: the batch starts at a frame not
        // yet taken was never sent (none lost), and frames already taken
        // (a resent batch whose earlier reply was lost) are skipped.
        if (frames is! List || base is! int || base > relay.received) {
          throw const MacHelperException('invalidFrame');
        }
        var index = base;
        final before = relay.received;
        for (final frame in frames) {
          if (frame is! Uint8List || frame.length > macosHelperMaxFrame) {
            throw const MacHelperException('invalidFrame');
          }
          if (index++ < relay.received) continue;
          relay.received = index;
          _events.add(MacHelperFrame(frame));
          if (!_isLive(relay)) return;
        }
        // Polls again at once only while frames keep coming.
        if (relay.received == before) {
          await Future<void>.delayed(_relayDelay);
        }
      } catch (error) {
        if (!await _relayFailed(relay, 'receive', error, sent)) return;
      }
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
        final sent = _now();
        try {
          final answer = await _invokeWithBackpressure('send', {
            'session': relay.session,
            'frame': frame,
            'seq': relay.sent,
          }, () => _isLive(relay));
          if (!_isLive(relay)) continue;
          if (answer['code'] != 'ok') {
            throw MacHelperException(
              answer['code'] as String? ?? 'unavailable',
            );
          }
          relay.lastOk = _now();
          relay.frames.removeFirst();
          relay.queuedBytes -= frame.length;
          relay.sent++;
        } catch (error) {
          await _relayFailed(relay, 'send', error, sent);
        }
      }
    } finally {
      _sending = false;
    }
  }
}

final macosHelperClient = MacHelperClient();
