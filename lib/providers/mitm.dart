import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_body.dart';
import 'package:fl_clash/common/mitm_protobuf.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/common/mitm_network.dart';
import 'package:fl_clash/common/mitm_trust.dart';
import 'package:fl_clash/core/method.dart' show coreFailureLogLevel;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart'
    show compute, listEquals, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' show join;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rust_api/rust_api.dart' show transcodeCharset;

import 'app.dart';
import 'config.dart';
import 'core.dart';
import 'database.dart';
import 'state.dart';

part 'generated/mitm.g.dart';

const _exchangesRefreshInterval = Duration(seconds: 2);

/// On macOS the app, not the Core, holds the CA: its key stays in the login
/// keychain and the Core asks the app to sign each leaf.
@Riverpod(keepAlive: true)
MitmSigner? mitmSigner(Ref ref) => system.isMacOS ? const MitmSigner() : null;

@Riverpod(keepAlive: true)
class MitmCa extends _$MitmCa {
  @override
  Future<MitmCertificate?> build() {
    final signer = ref.read(mitmSignerProvider);
    return signer?.certificate() ??
        ref.read(coreHandlerProvider).getMitmCertificate();
  }

  /// On macOS a new or deleted root also takes the old one's keychain trust
  /// with it, which safe mode leaves as it is.
  void _checkSafeMode(MitmSigner? signer) {
    if (signer != null && ref.read(safeModeProvider)) {
      throw StateError('Safe mode keeps the MITM certificate as it is');
    }
  }

  Future<void> generate() async {
    final signer = ref.read(mitmSignerProvider);
    _checkSafeMode(signer);
    final certificate =
        await signer?.generate() ??
        await ref.read(coreHandlerProvider).generateMitmCertificate();
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(certificate);
  }

  Future<void> delete() async {
    final signer = ref.read(mitmSignerProvider);
    _checkSafeMode(signer);
    await signer?.delete();
    if (ref.mounted) {
      state = const AsyncData(null);
    }
  }
}

@Riverpod(keepAlive: true)
class MitmCoreIdentityState extends _$MitmCoreIdentityState {
  int _reportGeneration = 0;

  @override
  Future<MitmCoreIdentity> build() async {
    final connected = ref.watch(
      coreStatusProvider.select((status) => status == CoreStatus.connected),
    );
    final signer = ref.read(mitmSignerProvider);
    if (!connected || signer == null) {
      return MitmCoreIdentity.none;
    }
    final generation = _reportGeneration;
    final identity = await signer.coreIdentity();
    if (_reportGeneration != generation) return state.value ?? identity;
    if (identity != state.value) {
      _log(identity);
    }
    return identity;
  }

  void _log(MitmCoreIdentity identity) {
    commonPrint.log(
      'MITM Core identity: $identity',
      logLevel: identity.status == MitmCoreStatus.failed
          ? LogLevel.warning
          : LogLevel.info,
    );
  }

  void report(MitmCoreIdentity identity) {
    _reportGeneration++;
    if (state.value != identity) {
      _log(identity);
      state = AsyncData(identity);
    }
  }
}

@riverpod
bool mitmCoreRefused(Ref ref) {
  final enable = ref.watch(
    patchClashConfigProvider.select(
      (state) => mitmFeature && state.mitm.enable,
    ),
  );
  final connected = ref.watch(
    coreStatusProvider.select((status) => status == CoreStatus.connected),
  );
  final identity = ref.watch(mitmCoreIdentityStateProvider).value;
  return enable &&
      connected &&
      ref.watch(mitmSignerProvider) != null &&
      identity != null &&
      identity != MitmCoreIdentity.verified;
}

// Settings-only polling: failure is not treated as evidence of active decryption.
// The dashboard and tray status poll it too, but only while decryption is on.
final mitmRuntimeStatusProvider = FutureProvider.autoDispose<MitmStatus>((
  ref,
) async {
  ref.watch(coreStatusProvider);
  ref.watch(patchClashConfigProvider.select((state) => state.mitm));
  try {
    return await ref
        .read(coreHandlerProvider)
        .getMitmStatus()
        .timeout(const Duration(seconds: 3));
  } finally {
    if (ref.mounted) {
      final timer = Timer(const Duration(seconds: 2), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
  }
});

/// Whether a connection the request list saw the Core decrypt is still open:
/// the IDs of the requests marked decrypted, matched against the Core's live
/// connection list. Unknown, or no decrypted request, is false, so the status
/// claims decryption only on that evidence. Polled while it is watched.
final mitmDecryptingProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(coreStatusProvider);
  try {
    final decrypted = {
      for (final request in ref.read(requestsProvider).list)
        if (request.metadata.mitm) request.id,
    };
    if (decrypted.isEmpty) {
      return false;
    }
    return await ref
        .read(coreHandlerProvider)
        .getConnectionsWith(
          (connections) => connections.any(
            (connection) => decrypted.contains(connection.id),
          ),
        )
        .timeout(const Duration(seconds: 3));
  } finally {
    if (ref.mounted) {
      final timer = Timer(const Duration(seconds: 2), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
  }
});

/// The status the dashboard's bar, the tray's dot and its menu show while
/// decryption is on, or null while it is off. A status the Core has not answered yet is
/// unconfirmed rather than paused: only the Core knows it passes through.
/// Ready is "on"; "decrypting" needs [decrypting], a decrypted connection
/// that is still open.
///
/// A Core that does not decrypt is "not trusted" only when this device has
/// not found the CA trusted ([trusted]); with trust and listed hosts it has
/// not received the settings yet ([MitmPauseReason.notApplied]).
MitmIndicator? mitmIndicatorOf({
  required bool enabled,
  required bool coreConnected,
  required bool coreRefused,
  required MitmStatus? status,
  bool decrypting = false,
  bool trusted = false,
  bool hostsListed = false,
}) {
  if (!enabled) {
    return null;
  }
  if (!coreConnected) {
    return const MitmIndicator.paused(MitmPauseReason.coreStopped);
  }
  if (coreRefused) {
    return const MitmIndicator.paused(MitmPauseReason.coreIdentity);
  }
  if (status == null) {
    return const MitmIndicator.unconfirmed();
  }
  if (!status.enable) {
    if (!trusted) {
      return const MitmIndicator.paused(MitmPauseReason.notTrusted);
    }
    // Trusted with nothing listed: there is nothing to decrypt, and nothing
    // for the Core to be missing either.
    return hostsListed
        ? const MitmIndicator.paused(MitmPauseReason.notApplied)
        : const MitmIndicator.on();
  }
  return switch (mitmCorePauseReason(status.paused)) {
    null when decrypting => const MitmIndicator.decrypting(),
    null => const MitmIndicator.on(),
    final reason => MitmIndicator.paused(reason),
  };
}

/// Every `paused` value the Core reports (core/mitm.go `mitmStatus`, and the
/// global pause reasons of core/mitm_intercept.go `pauseMitm`), mapped once
/// for the bar, the tray and the decryption page alike; null when not paused.
MitmPauseReason? mitmCorePauseReason(String paused) => switch (paused) {
  '' => null,
  // Decrypting; connections opened before it began, or while a host's own
  // pause lasted, may have passed through. Not a pause of decryption.
  'partialConnections' => MitmPauseReason.partialConnections,
  'indicatorPending' => MitmPauseReason.indicatorPending,
  'livenessUnavailable' || 'trustUnavailable' => MitmPauseReason.liveness,
  'coreIdentity' => MitmPauseReason.coreIdentity,
  'appUnavailable' => MitmPauseReason.appUnavailable,
  'signTimeout' => MitmPauseReason.signTimeout,
  'leafUnusable' => MitmPauseReason.leafUnusable,
  // The signer's own refusals (lib/providers/mitm.dart MitmSignResult).
  'signFailed' || 'signBusy' || 'disabled' => MitmPauseReason.signRefused,
  _ => MitmPauseReason.unavailable,
};

final mitmIndicatorProvider = Provider.autoDispose<MitmIndicator?>((ref) {
  final enabled = ref.watch(
    patchClashConfigProvider.select(
      (state) => mitmFeature && state.mitm.enable,
    ),
  );
  final coreConnected = ref.watch(
    coreStatusProvider.select((status) => status == CoreStatus.connected),
  );
  if (!enabled || !coreConnected) {
    return mitmIndicatorOf(
      enabled: enabled,
      coreConnected: coreConnected,
      coreRefused: false,
      status: null,
    );
  }
  final coreRefused = ref.watch(mitmCoreRefusedProvider);
  final status = ref.watch(mitmRuntimeStatusProvider).value;
  final trusted = ref.watch(
    patchClashConfigProvider.select(
      (state) => state.mitm.trustedFingerprint != null,
    ),
  );
  final listed = ref.watch(
    patchClashConfigProvider.select(
      (state) => state.mitm.hostname.any(
        (line) => line.trim().isNotEmpty && !line.trim().startsWith('-'),
      ),
    ),
  );
  MitmIndicator? of({bool decrypting = false}) => mitmIndicatorOf(
    enabled: enabled,
    coreConnected: coreConnected,
    coreRefused: coreRefused,
    status: status,
    decrypting: decrypting,
    trusted: trusted,
    hostsListed: listed || (status?.hostnames ?? 0) > 0,
  );
  // The live connections are read only while decryption is ready.
  if (of()?.kind != MitmIndicatorKind.on) {
    return of();
  }
  return of(decrypting: ref.watch(mitmDecryptingProvider).value == true);
});

/// How many `mitm` hostnames the running profile wrote, all of them ignored.
@riverpod
Future<int> mitmIgnoredHostnames(Ref ref) async {
  ref.watch(coreStatusProvider);
  ref.watch(patchClashConfigProvider.select((state) => state.mitm));
  final status = await ref.read(coreHandlerProvider).getMitmStatus();
  return status.ignoredHostnames;
}

/// Answers the Core's `mitmSign` with a leaf for a host on the list the Core
/// decrypts (the user's hostnames, then the enabled modules', see
/// [mitmEffectiveHostnames]), or with why not; the Core passes the connection
/// through on a refusal. A module turned off, deleted or declined leaves the
/// list at once, before the Core is told.
@Riverpod(keepAlive: true)
class MitmSignAction extends _$MitmSignAction {
  @override
  void build() {}

  // Coalesce concurrent checks, but never cache their result. A timed-out
  // platform operation remains the sole in-flight check until it finishes;
  // later requests fail closed instead of starting unbounded processes.
  Future<bool>? _checkingTrust;
  String? _checkingFingerprint;
  // One app-side budget covers both stages; Core has additional headroom.
  static const _issuanceBudget = Duration(seconds: 7);

  Future<bool> _checkTrust(MitmSigner signer, String fingerprint) async {
    if (await signer.coreIdentity() != MitmCoreIdentity.verified) return false;
    if (!ref.mounted) return false;
    final store = ref.read(mitmTrustStoreProvider);
    if (store == null) return false;
    final ca = await signer.certificate();
    if (ca == null || ca.fingerprint != fingerprint) return false;
    final check = await store.check(ca, signer.checkCertificate);
    if (check.trust != MitmTrust.ready) return false;
    final current = await signer.certificate();
    return current != null && current.fingerprint == fingerprint;
  }

  Future<bool> _freshTrust(
    MitmSigner signer,
    String fingerprint,
    Duration remaining,
  ) async {
    if (remaining <= Duration.zero) return false;
    if (_checkingTrust != null && _checkingFingerprint != fingerprint) {
      return false;
    }
    _checkingFingerprint = fingerprint;
    final check = _checkingTrust ??= _checkTrust(signer, fingerprint);
    // Attach cleanup to the underlying operation, not the timeout wrapper.
    unawaited(
      check.then<void>(
        (_) {
          if (identical(_checkingTrust, check)) {
            _checkingTrust = null;
            _checkingFingerprint = null;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_checkingTrust, check)) {
            _checkingTrust = null;
            _checkingFingerprint = null;
          }
        },
      ),
    );
    try {
      return await check.timeout(remaining);
    } catch (_) {
      return false;
    }
  }

  int _signing = 0;
  static const _maxConcurrentSigns = 16;

  /// How long a signing waits for the modules' hosts before it signs for the
  /// user's alone.
  static const _modulesWait = Duration(seconds: 2);

  /// The list the Core decrypts with [mitm], the modules' part read fresh: a
  /// module just turned off is gone from it even before the Core hears. While
  /// the modules cannot be read only the user's hosts sign, never more than
  /// the Core is sent.
  Future<List<String>> _hostnames(Mitm mitm, Duration remaining) async {
    final modules = ref.listen(
      enabledMitmModuleRulesProvider.future,
      (_, _) {},
    );
    var rules = MitmModuleRules.empty;
    try {
      rules = await modules.read().timeout(
        remaining < _modulesWait ? remaining : _modulesWait,
      );
    } catch (_) {
      // Fails closed for the modules only.
    } finally {
      modules.close();
    }
    return mitmEffectiveHostnames(mitm, rules);
  }

  // Each host is logged once until its answer changes, and only by name. A
  // refusal is a warning, as the Core then lets the host through undecrypted;
  // a leaf only at the debug level the user picked.
  final _refusedLogged = <String>{};
  final _signedLogged = <String>{};
  static const _loggedHostsLimit = 512;

  void _logSigned(String host, MitmSignResult result) {
    if (result.error == 'notListed') {
      _signedLogged.remove(host);
      if (_remember(_refusedLogged, host)) {
        commonPrint.log(
          'MITM: $host is not on the decryption list, so it passes through '
          'undecrypted',
          logLevel: LogLevel.warning,
        );
      }
    } else if (result.cert != null) {
      _refusedLogged.remove(host);
      if (ref.read(patchClashConfigProvider).logLevel == LogLevel.debug &&
          _remember(_signedLogged, host)) {
        commonPrint.log('MITM: decrypting $host', logLevel: LogLevel.debug);
      }
    }
  }

  static bool _remember(Set<String> logged, String host) {
    if (logged.contains(host)) return false;
    if (logged.length >= _loggedHostsLimit) logged.clear();
    logged.add(host);
    return true;
  }

  Future<MitmSignResult> _signBounded(
    MitmSigner signer,
    MitmSignRequest request,
    List<String> hostnames,
    Duration remaining,
  ) async {
    if (remaining <= Duration.zero) {
      return const MitmSignResult(error: 'signFailed');
    }
    if (_signing >= _maxConcurrentSigns) {
      return const MitmSignResult(error: 'signBusy');
    }
    _signing++;
    final sign = signer.sign(
      host: request.host,
      spki: request.spki,
      hostnames: hostnames,
    );
    // A timeout cannot cancel the platform operation. Keep its slot until
    // it really finishes so a stuck native queue cannot grow without bound.
    unawaited(
      sign.then<void>(
        (_) {
          _signing--;
        },
        onError: (Object error, StackTrace stackTrace) {
          _signing--;
        },
      ),
    );
    try {
      return await sign.timeout(remaining);
    } catch (_) {
      return const MitmSignResult(error: 'signFailed');
    }
  }

  Future<void> answer(MitmSignRequest request) async {
    final mitm = ref.read(patchClashConfigProvider).mitm;
    final signer = ref.read(mitmSignerProvider);
    MitmSignResult result;
    if (signer == null || !mitmFeature || !mitm.enable) {
      result = const MitmSignResult(error: 'disabled');
    } else if (!request.managedRelay) {
      result = const MitmSignResult(
        error: 'coreIdentity',
        coreIdentity: 'failed:channel',
      );
      if (ref.mounted) {
        ref
            .read(mitmCoreIdentityStateProvider.notifier)
            .report(const MitmCoreIdentity.failed('channel'));
      }
    } else {
      try {
        // The Core's deadline accounts for key generation and relay delay.
        // Wall clocks are shared by the two local processes; reserve headroom
        // and use a monotonic stopwatch once the request has arrived.
        final transmitted =
            Duration(
              milliseconds:
                  request.deadlineUnixMillis -
                  DateTime.now().millisecondsSinceEpoch,
            ) -
            const Duration(seconds: 1);
        final budget = transmitted < _issuanceBudget
            ? transmitted
            : _issuanceBudget;
        final stopwatch = Stopwatch()..start();
        Duration remaining() {
          final left = budget - stopwatch.elapsed;
          return left.isNegative ? Duration.zero : left;
        }

        final fingerprint = mitm.trustedFingerprint;
        final trusted =
            fingerprint != null &&
            await _freshTrust(signer, fingerprint, remaining());
        if (!ref.mounted) return;
        final current = ref.read(patchClashConfigProvider).mitm;
        if (!trusted ||
            !current.enable ||
            current.trustedFingerprint != fingerprint) {
          result = const MitmSignResult(error: 'trustUnavailable');
        } else {
          final hostnames = await _hostnames(current, remaining());
          if (!ref.mounted) return;
          result = await _signBounded(signer, request, hostnames, remaining());
          if (!ref.mounted) return;
          final afterSign = ref.read(patchClashConfigProvider).mitm;
          final hostnamesAfter = afterSign.enable
              ? await _hostnames(afterSign, remaining())
              : const <String>[];
          if (!ref.mounted) return;
          if (!afterSign.enable ||
              afterSign.trustedFingerprint != fingerprint ||
              !listEquals(hostnamesAfter, hostnames)) {
            result = const MitmSignResult(error: 'disabled');
          }
          _logSigned(request.host, result);
        }
      } catch (error) {
        commonPrint.log(
          'Signing a MITM certificate failed: ${compactError(error)}',
          logLevel: LogLevel.warning,
        );
        result = const MitmSignResult(error: 'signFailed');
      }
      if (ref.mounted && (result.refusedCore || result.cert != null)) {
        ref
            .read(mitmCoreIdentityStateProvider.notifier)
            .report(
              result.refusedCore
                  ? MitmCoreIdentity.parse(result.coreIdentity)
                  : MitmCoreIdentity.verified,
            );
      }
    }
    if (!ref.mounted) {
      return;
    }
    try {
      await ref
          .read(coreHandlerProvider)
          .sendMitmSignResult(request.reqId, result);
    } catch (error) {
      commonPrint.log(
        'Answering a MITM signing request failed: ${compactError(error)}',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }
}

/// Counts the times a check found the CA trusted where it was not before. The
/// app layer applies the settings then, visibly, so a setup failure is shown
/// rather than left behind a silent retry.
final mitmTrustGainedProvider = NotifierProvider<MitmTrustGained, int>(
  MitmTrustGained.new,
);

class MitmTrustGained extends Notifier<int> {
  @override
  int build() => 0;

  void gained() => state++;
}

@Riverpod(keepAlive: true)
MitmTrustStore? mitmTrustStore(Ref ref) => mitmTrustStoreForPlatform();

/// Whether this device trusts the CA. A check records the CA it found
/// trusted, which is the one the Core decrypts HTTPS with.
@Riverpod(keepAlive: true)
class MitmTrustState extends _$MitmTrustState {
  @override
  Future<MitmTrustCheck> build() async {
    return _check(await ref.watch(mitmCaProvider.future));
  }

  Future<MitmTrustCheck> _check(MitmCertificate? ca) async {
    final store = ref.read(mitmTrustStoreProvider);
    final MitmTrustCheck check;
    if (ca == null) {
      check = const MitmTrustCheck(MitmTrust.notGenerated);
    } else if (store == null) {
      check = const MitmTrustCheck(MitmTrust.notInstalled);
    } else {
      final signer = ref.read(mitmSignerProvider);
      final core = ref.read(coreHandlerProvider);
      check = await store.check(
        ca,
        () =>
            signer?.checkCertificate() ??
            core.issueMitmCertificate(mitmCheckHost),
      );
    }
    if (ref.mounted) {
      _record(ca, check);
    }
    return check;
  }

  void _record(MitmCertificate? ca, MitmTrustCheck check) {
    final trusted = check.trust == MitmTrust.ready ? ca?.fingerprint : null;
    final previous = ref.read(patchClashConfigProvider).mitm.trustedFingerprint;
    if (previous == trusted) {
      return;
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            mitm: state.mitm.copyWith(trustedFingerprint: trusted),
          ),
        );
    if (previous == null && trusted != null) {
      ref.read(mitmTrustGainedProvider.notifier).gained();
    }
  }

  Future<void>? _refreshing;

  /// Calls while a check runs share it, since each check runs the platform's
  /// trust tools.
  Future<void> refresh() {
    if (state.isLoading) {
      return future.then((_) {}, onError: (_) {});
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    final next = await AsyncValue.guard(
      () async => _check(await ref.read(mitmCaProvider.future)),
    );
    if (ref.mounted) {
      state = next;
    }
  }

  Future<MitmInstallOutcome?> install() async {
    final ca = await ref.read(mitmCaProvider.future);
    final store = ref.read(mitmTrustStoreProvider);
    if (ca == null || store == null || ref.read(safeModeProvider)) {
      return null;
    }
    MitmInstallOutcome? outcome;
    try {
      outcome = await store.install(ca);
      return outcome;
    } finally {
      if (store is AndroidMitmTrustStore && ref.mounted) {
        ref.invalidate(rootAccessProvider);
      }
      if (ref.mounted &&
          (outcome == null ||
              outcome == MitmInstallOutcome.installed ||
              outcome == MitmInstallOutcome.untilReboot)) {
        await refresh();
      }
    }
  }

  Future<MitmRemoveOutcome?> remove() async {
    final ca = await ref.read(mitmCaProvider.future);
    final store = ref.read(mitmTrustStoreProvider);
    if (ca == null || store == null || ref.read(safeModeProvider)) {
      return null;
    }
    MitmRemoveOutcome outcome;
    try {
      outcome = await store.remove(ca);
    } on ProcessException catch (error) {
      commonPrint.log(
        'Removing the MITM certificate failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      outcome = MitmRemoveOutcome.failed;
    } finally {
      if (store is AndroidMitmTrustStore && ref.mounted) {
        ref.invalidate(rootAccessProvider);
      }
    }
    await refresh();
    return outcome;
  }

  /// False when the old CA is left in the trust store for the user to remove,
  /// as safe mode always leaves it.
  Future<bool> regenerate() async {
    final old = await ref.read(mitmCaProvider.future);
    final store = ref.read(mitmTrustStoreProvider);
    final trust = state.value?.trust;
    var removed = true;
    // The macOS signer removes the old root and its trust as it generates.
    if (ref.read(mitmSignerProvider) == null &&
        old != null &&
        store != null &&
        (trust == MitmTrust.ready || trust == MitmTrust.untrusted)) {
      try {
        removed =
            !ref.read(safeModeProvider) &&
            await store.remove(old) == MitmRemoveOutcome.removed;
      } catch (error) {
        commonPrint.log(
          'Removing the old MITM certificate failed: ${compactError(error)}',
          logLevel: LogLevel.warning,
        );
        removed = false;
      }
      if (store is AndroidMitmTrustStore && ref.mounted) {
        ref.invalidate(rootAccessProvider);
      }
    }
    await ref.read(mitmCaProvider.notifier).generate();
    return removed;
  }
}

/// Fetched again while shown, until the connection has closed and none of its
/// requests is pending.
@riverpod
Future<MitmExchangeList> mitmExchanges(Ref ref, String connectionId) async {
  final list = await ref
      .read(coreHandlerProvider)
      .getMitmExchanges(connectionId);
  final settled =
      list.closed && !list.exchanges.any((exchange) => exchange.pending);
  if (!settled && ref.mounted) {
    final timer = Timer(_exchangesRefreshInterval, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return list;
}

@riverpod
Future<MitmExchange?> mitmExchange(Ref ref, int id) async {
  final exchange = await ref.read(coreHandlerProvider).getMitmExchange(id);
  if (exchange != null && exchange.pending && ref.mounted) {
    final timer = Timer(_exchangesRefreshInterval, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return exchange;
}

@riverpod
Future<MitmBodyContent?> mitmBody(
  Ref ref,
  int id, {
  required bool response,
  required String contentType,
  bool original = false,
}) async {
  final body = await ref
      .read(coreHandlerProvider)
      .getMitmBody(id, response: response, original: original);
  if (body == null) {
    return null;
  }
  final content = await compute(readMitmBody, (
    body,
    contentType,
    grpcOverLimitNote: currentAppLocalizations.mitmGrpcOverLimit(
      mitmGrpcInflateLimit >> 20,
    ),
  ));
  if (content.charset.isEmpty) {
    return content;
  }
  final Uint8List? utf8Bytes;
  try {
    utf8Bytes = await mitmCharsetTranscoder(
      bytes: content.bytes,
      label: content.charset,
      lossy: content.truncated,
    );
  } catch (error) {
    commonPrint.log('Reading ${content.charset} failed: $error');
    return content;
  }
  if (utf8Bytes == null) {
    return content;
  }
  return compute(readMitmCharsetText, (content, utf8Bytes, contentType));
}

typedef MitmCharsetTranscoder =
    Future<Uint8List?> Function({
      required List<int> bytes,
      required String label,
      required bool lossy,
    });

@visibleForTesting
MitmCharsetTranscoder mitmCharsetTranscoder = transcodeCharset;

/// Whether the user was told, this run, what a copied or exported request
/// can carry.
@Riverpod(keepAlive: true)
class MitmExportWarned extends _$MitmExportWarned {
  @override
  bool build() => false;

  void accept() => state = true;
}

@riverpod
List<MitmModule> mitmModulesToAgree(Ref ref) => [
  for (final module
      in ref.watch(mitmModulesProvider).value ?? const <MitmModule>[])
    if (module.awaitsConsent) module,
];

/// Why the Core skips each of the user's hostnames, by the line.
@riverpod
Future<Map<String, String>> mitmHostnameIssues(Ref ref) async {
  final hostname = ref.watch(
    patchClashConfigProvider.select((state) => state.mitm.hostname),
  );
  if (hostname.isEmpty) {
    return const {};
  }
  final check = await _checkOf(ref, MitmRules(hostname: hostname));
  return check.issues[MitmList.hostname] ?? const {};
}

typedef _MitmLineCheck = ({
  Map<MitmList, Map<String, String>> issues,
  Map<MitmList, Map<String, MitmLineView>> views,
});

Future<_MitmLineCheck> _checkOf(Ref ref, MitmRules mitm) async {
  final issues = await ref.read(coreHandlerProvider).validateMitm(mitm);
  Map<MitmList, Map<String, T>> byLine<T>(Map<MitmList, Map<int, T>> lists) => {
    for (final MapEntry(key: list, value: lines) in lists.entries)
      list: {
        for (final MapEntry(key: index, :value) in lines.entries)
          ?mitm.linesOf(list).elementAtOrNull(index): value,
      },
  };
  return (
    issues: byLine(issues),
    views: const <MitmList, Map<String, MitmLineView>>{},
  );
}

/// A module that fails to read adds nothing, so the VPN can still start.
@riverpod
Future<List<({String name, MitmModuleContent content})>> enabledMitmModules(
  Ref ref,
) async {
  if (!(mitmFeature &&
      mitmModulesFeature &&
      ref.watch(
        patchClashConfigProvider.select((state) => state.mitm.enable),
      ))) {
    return const [];
  }
  final modules = await ref.watch(mitmModulesProvider.future);
  final contents = <({String name, MitmModuleContent content})>[];
  for (final module in modules.where((module) => module.enabled)) {
    try {
      final content = await ref.watch(
        mitmModuleContentProvider(module.id).future,
      );
      if (content != null) {
        contents.add((name: module.name, content: content));
      }
    } catch (e) {
      commonPrint.log(
        'MITM module ${module.name}: ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
    }
  }
  return contents;
}

@riverpod
Future<Map<String, List<String>>> mitmModuleExits(Ref ref) async {
  final exits = <String, List<String>>{};
  for (final module in await ref.watch(enabledMitmModulesProvider.future)) {
    for (final exit in module.content.exits) {
      exits.putIfAbsent(exit, () => []).add(module.name);
    }
  }
  return exits;
}

typedef MitmNetworkChangeState = ({
  MitmNetworkChange change,
  bool overridesYours,
  String? replacedBy,
});

/// A list goes over the user's only when it replaces it whole, a per-domain
/// entry only where the user wrote that domain. Android's VPN reads its own
/// route rows, never the TUN overrides, and only adds a module's routes.
bool mitmChangeOverridesUser(
  MitmNetworkChange change, {
  required ProfileOverrides overrides,
  required Map<String, String> hosts,
}) {
  bool dnsKey(DnsOverrideKey key) => overrides.dnsOverrideKeys.contains(key);
  return switch (change.key) {
    MitmNetworkKey.nameserver =>
      change.replaces && dnsKey(DnsOverrideKey.nameserver),
    MitmNetworkKey.defaultNameserver =>
      change.replaces && dnsKey(DnsOverrideKey.defaultNameserver),
    MitmNetworkKey.fakeIpFilter =>
      change.replaces && dnsKey(DnsOverrideKey.fakeIpFilter),
    MitmNetworkKey.nameserverPolicy =>
      dnsKey(DnsOverrideKey.nameserverPolicy) &&
          overrides.dns.nameserverPolicy.containsKey(change.entry),
    MitmNetworkKey.hosts => hosts.containsKey(change.entry),
    MitmNetworkKey.routeExcludeAddress =>
      change.replaces &&
          !system.isAndroid &&
          overrides.tunOverrideKeys.contains(
            TunOverrideKey.routeExcludeAddress,
          ),
    MitmNetworkKey.bypassDomain => change.replaces,
    MitmNetworkKey.routeAddress => false,
  };
}

@riverpod
Future<List<MitmNetworkChangeState>> mitmModuleNetworkChanges(
  Ref ref,
  int id,
) async {
  final overrides = ref.watch(
    profileOverridesProvider(ref.watch(currentProfileIdProvider)),
  );
  final hosts = ref.watch(
    patchClashConfigProvider.select((state) => state.hosts),
  );
  final changes =
      (await ref.watch(
        mitmModuleContentProvider(id).future,
      ))?.network.changes ??
      const [];
  if (changes.isEmpty) {
    return const [];
  }
  final modules = await ref.watch(mitmModulesProvider.future);
  final later = <(String, MitmNetwork)>[];
  for (final module in modules.skipWhile((module) => module.id != id).skip(1)) {
    if (!module.enabled) {
      continue;
    }
    final content = await ref.watch(
      mitmModuleContentProvider(module.id).future,
    );
    if (content != null && !content.network.isEmpty) {
      later.add((module.name, content.network));
    }
  }
  return [
    for (final change in changes)
      (
        change: change,
        overridesYours: mitmChangeOverridesUser(
          change,
          overrides: overrides,
          hosts: hosts,
        ),
        replacedBy: later
            .lastWhereOrNull((module) => change.replacedBy(module.$2))
            ?.$1,
      ),
  ];
}

typedef MitmTakeover = ({
  Map<MitmNetworkKey, String> keys,
  Map<String, String> hosts,
  Map<String, String> nameserverPolicy,
});

/// The module that last replaces each setting, for the setting's own page to
/// name; a module that only adds to a list leaves it the user's.
@riverpod
Future<MitmTakeover> mitmTakeover(Ref ref) async {
  return (
    keys: const <MitmNetworkKey, String>{},
    hosts: const <String, String>{},
    nameserverPolicy: const <String, String>{},
  );
}

@riverpod
Future<MitmNetwork> mitmModuleNetwork(Ref ref) async => const MitmNetwork();

typedef MitmModuleDetails = ({
  MitmModuleContent content,
  Map<MitmList, Map<String, String>> issues,
  Map<MitmList, Map<String, MitmLineView>> views,
});

MitmModuleContent _parseModuleSource(MitmModuleSource source) =>
    parseMitmModule(
      source.content,
      values: source.arguments,
      resources: source.resources,
    );

/// Null while the module's content is not on disk.
@riverpod
Future<MitmModuleDetails?> mitmModuleDetails(Ref ref, int id) async {
  final content = await ref.watch(mitmModuleContentProvider(id).future);
  if (content == null) {
    return null;
  }
  final check = await _checkOf(ref, flashMitmRules(content));
  final ignored = flashUnusableHostnames(content);
  final unsupported = {
    ...flashMitmIssues(content),
    // Told here as well, so it shows while the Core is not running.
    if (ignored.isNotEmpty)
      MitmList.hostname: {
        for (final line in ignored)
          line: currentAppLocalizations.mitmHostIgnored,
      },
  };
  return (
    content: content,
    issues: {
      for (final list in {...check.issues.keys, ...unsupported.keys})
        list: {...?check.issues[list], ...?unsupported[list]},
    },
    views: check.views,
  );
}

Duration? _noRetry(int retryCount, Object error) => null;

/// A file that fails to parse fails again until it changes, which rebuilds
/// this anyway.
@Riverpod(retry: _noRetry)
Future<MitmModuleContent?> mitmModuleContent(Ref ref, int id) async {
  final module = ref.watch(
    mitmModulesProvider.select(
      (state) => state.value?.firstWhereOrNull((item) => item.id == id),
    ),
  );
  if (module == null) {
    return null;
  }
  final file = File(join(await appPath.mitmModulesDirPath, module.fileName));
  if (!await file.exists()) {
    return null;
  }
  return compute(
    _parseModuleSource,
    MitmModuleSource(
      content: await file.readAsString(),
      arguments: module.arguments,
      resources: module.resources,
    ),
  );
}

/// Why the Core cannot take each of a profile's rewrite rules, by rule ID;
/// disabled rules are checked too.
@riverpod
Future<Map<int, MitmRewriteIssue>> mitmRewriteIssues(
  Ref ref,
  int profileId,
) async {
  final rewrites = await ref.watch(
    profileMitmRewritesProvider(profileId).future,
  );
  if (rewrites.isEmpty) {
    return const {};
  }
  final check = mitmRewriteCheckText(rewrites);
  final parsed = await ref
      .read(coreHandlerProvider)
      .parseMitmRewrite(check.text);
  return {for (final issue in parsed.issues) ?check.lines[issue.line]: issue};
}

/// The size up to which the Core rewrites a body, or 0 while it runs no
/// rewrite rules.
@riverpod
Future<int> mitmRewriteBodyLimit(Ref ref) async {
  ref.watch(mitmSetupProvider);
  final status = await ref.read(coreHandlerProvider).getMitmRewriteStatus();
  return status.active ? status.bodyLimit : 0;
}
