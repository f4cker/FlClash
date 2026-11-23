import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/core/method.dart' show CoreMethodException;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config.dart';
import 'core.dart';
import 'mitm.dart';

/// Why the Core's CA is not leased, when it is not for a plain lapse.
enum MitmCoreCaFailure {
  coreIdentity,

  passphraseMissing,

  /// The Core answers the check leaf without the id a lease needs.
  coreOutdated,

  refused,
}

enum MitmCoreCaStatus { off, checking, leased, lapsed, untrusted, failed }

@immutable
class MitmCoreCaTrust {
  const MitmCoreCaTrust(this.status, {this.leased, this.failure});

  static const off = MitmCoreCaTrust(MitmCoreCaStatus.off);

  final MitmCoreCaStatus status;

  /// Only a CA leased since it was last untrusted makes the Core the signer.
  final String? leased;

  final MitmCoreCaFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is MitmCoreCaTrust &&
      other.status == status &&
      other.leased == leased &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(status, leased, failure);
}

bool _sameFingerprint(String? a, String? b) =>
    a != null && b != null && a.toUpperCase() == b.toUpperCase();

String? _refusal(Object error) => switch (error) {
  CoreMethodException(details: {'reason': final String reason}) => reason,
  _ => null,
};

final mitmPassphraseStoreProvider = Provider<MitmPassphraseStore?>(
  (ref) => ref.watch(mitmSignerProvider),
);

/// The legacy keychain CA; [mitmCaProvider] names the one in use.
final mitmLegacyCaProvider = FutureProvider<MitmCertificate?>((ref) async {
  ref.watch(patchClashConfigProvider.select((state) => state.mitm.coreCa));
  return ref.watch(mitmSignerProvider)?.certificate();
});

final mitmCoreCaProvider = NotifierProvider<MitmCoreCaLease, MitmCoreCaTrust>(
  MitmCoreCaLease.new,
);

/// Keeps the Core's CA leased while decryption is on: load, check leaf,
/// `verify-cert`, lease, about every [renewEvery] from each check's start.
/// A check that errors sends nothing, so the lease lapses on its own.
class MitmCoreCaLease extends Notifier<MitmCoreCaTrust> {
  @visibleForTesting
  static Duration renewEvery = const Duration(seconds: 5);

  static const _checkBudget = Duration(seconds: 4);
  static const _stopBudget = Duration(seconds: 2);

  Timer? _timer;
  Future<MitmTrust?>? _running;
  int _suspended = 0;
  int _connection = 0;
  ({int connection, String fingerprint})? _loaded;
  bool _holding = false;

  /// Set once the CA was found untrusted: trust found again later resumes
  /// nothing until [retrust], a new CA or decryption turned on again.
  bool _awaitingRetrust = false;

  MitmSigner? _signer;

  @override
  MitmCoreCaTrust build() {
    _signer = ref.read(mitmSignerProvider);
    ref.listen(coreStatusProvider, (previous, next) {
      // A new Core process, or the relay adopting one, starts without a CA.
      if (next == CoreStatus.connected && previous != CoreStatus.connected) {
        _connection++;
        _loaded = null;
        _kick();
      } else if (next != CoreStatus.connected) {
        _loaded = null;
      }
    });
    ref.listen(
      patchClashConfigProvider.select(
        (state) => (
          enable: mitmFeature && state.mitm.enable,
          ca: state.mitm.coreCa?.fingerprint,
        ),
      ),
      (previous, next) {
        if (previous?.ca != null && (!next.enable || next.ca != previous?.ca)) {
          unawaited(stopSigning());
        }
        if (next.ca != previous?.ca ||
            (next.enable && previous?.enable != true)) {
          _awaitingRetrust = false;
        }
        _kick();
      },
      fireImmediately: true,
    );
    ref.listen(mitmCoreIdentityStateProvider, (previous, next) {
      if (next.value == MitmCoreIdentity.verified &&
          previous?.value != MitmCoreIdentity.verified) {
        _kick();
      }
    });
    ref.onDispose(() {
      _timer?.cancel();
      _hold(false);
    });
    return MitmCoreCaTrust.off;
  }

  Mitm get _mitm => ref.read(patchClashConfigProvider).mitm;

  bool get _enabled => mitmFeature && _mitm.enable;

  void _kick() {
    _timer?.cancel();
    _timer = Timer(Duration.zero, _tick);
  }

  Future<void> _tick() async {
    _timer = null;
    if (!ref.mounted) return;
    if (!_enabled || _mitm.coreCa == null) {
      _hold(false);
      if (state.status != MitmCoreCaStatus.off) {
        state = MitmCoreCaTrust.off;
      }
      return;
    }
    final started = Stopwatch()..start();
    await checkNow();
    if (!ref.mounted || _timer != null) return;
    final wait = renewEvery - started.elapsed;
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _tick);
  }

  /// Shared by callers while it runs; null when it could not tell.
  Future<MitmTrust?> checkNow() {
    if (_suspended > 0) return Future.value();
    return _running ??= _check().whenComplete(() => _running = null);
  }

  /// Runs [body] with the Core's one CA slot to itself.
  Future<T> exclusive<T>(Future<T> Function() body) async {
    _suspended++;
    try {
      await _running;
      return await body();
    } finally {
      if (--_suspended == 0 && ref.mounted) _kick();
    }
  }

  /// The user asked to trust the CA again: check now, and lease if trusted.
  Future<MitmTrust?> retrust() {
    _awaitingRetrust = false;
    _kick();
    return checkNow();
  }

  Future<MitmTrust?> _check() async {
    if (_awaitingRetrust) return null;
    final mitm = _mitm;
    final ca = mitm.coreCa;
    final p12 = mitm.caP12;
    final signer = ref.read(mitmSignerProvider);
    final store = ref.read(mitmTrustStoreProvider);
    if (ca == null || p12 == null || signer == null || store == null) {
      return null;
    }
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      _lapsed();
      return null;
    }
    if (state.leased == null) {
      state = MitmCoreCaTrust(MitmCoreCaStatus.checking, leased: state.leased);
    }
    final enabled = _enabled;
    try {
      if (await signer.coreIdentity() != MitmCoreIdentity.verified) {
        _failed(MitmCoreCaFailure.coreIdentity);
        return null;
      }
      final leaf = await _load(ca, p12).timeout(_checkBudget);
      if (leaf == null || !ref.mounted) return null;
      final verdict = await store
          .check(ca, () async => leaf.pem)
          .timeout(_checkBudget);
      if (!ref.mounted) return null;
      if (verdict.trust != MitmTrust.ready) {
        await _untrusted(ca);
        return verdict.trust;
      }
      if (!enabled) {
        // Checked for the page while decryption is off: nothing to lease.
        await stopSigning();
        _record(ca.fingerprint);
        return MitmTrust.ready;
      }
      final lease = await ref
          .read(coreHandlerProvider)
          .leaseMitmTrust(ca.fingerprint, leaf.check!);
      if (!ref.mounted) return null;
      if (!lease.leasedFor(ca.fingerprint) ||
          !_sameFingerprint(_mitm.coreCa?.fingerprint, ca.fingerprint)) {
        _lapsed();
        return null;
      }
      _record(ca.fingerprint);
      state = MitmCoreCaTrust(MitmCoreCaStatus.leased, leased: ca.fingerprint);
      _hold(true);
      return MitmTrust.ready;
    } catch (error) {
      if (!ref.mounted) return null;
      switch (_refusal(error)) {
        // Cleared or reloaded since: load it again on the next round.
        case 'notLoaded' || 'unknownCheck' || 'fingerprintMismatch':
          _loaded = null;
          _lapsed();
        case final String _ when error is CoreMethodException:
          _loaded = null;
          _failed(MitmCoreCaFailure.refused);
        default:
          commonPrint.log(
            'MITM trust check failed: ${compactError(error)}',
            logLevel: LogLevel.warning,
          );
          _lapsed();
      }
      return null;
    }
  }

  Future<MitmCheckLeaf?> _load(MitmCertificate ca, MitmCaP12 p12) async {
    final core = ref.read(coreHandlerProvider);
    final key = (connection: _connection, fingerprint: ca.fingerprint);
    if (_loaded != key) {
      final passphrase = await ref
          .read(mitmPassphraseStoreProvider)
          ?.readPassphrase(ca.fingerprint);
      if (passphrase == null) {
        _failed(MitmCoreCaFailure.passphraseMissing);
        return null;
      }
      final loaded = await core.setMitmCa(
        MitmCaSecret(
          p12: p12,
          passphrase: passphrase,
          fingerprint: ca.fingerprint,
        ),
      );
      if (!loaded.loaded ||
          !_sameFingerprint(loaded.fingerprint, ca.fingerprint)) {
        return null;
      }
      _loaded = key;
    }
    final leaf = await core.issueMitmCheck();
    if (leaf.check == null) {
      _failed(MitmCoreCaFailure.coreOutdated);
      return null;
    }
    return leaf;
  }

  void _record(String fingerprint) {
    final previous = _mitm.trustedFingerprint;
    if (previous == fingerprint) return;
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            mitm: state.mitm.copyWith(trustedFingerprint: fingerprint),
          ),
        );
    if (previous == null) {
      ref.read(mitmTrustGainedProvider.notifier).gained();
    }
  }

  void _lapsed() {
    if (state.leased != null) {
      state = MitmCoreCaTrust(MitmCoreCaStatus.lapsed, leased: state.leased);
    }
  }

  void _failed(MitmCoreCaFailure failure) {
    state = MitmCoreCaTrust(
      MitmCoreCaStatus.failed,
      leased: state.leased,
      failure: failure,
    );
  }

  Future<void> _untrusted(MitmCertificate ca) async {
    final wasLeased = state.leased != null;
    _awaitingRetrust = true;
    state = const MitmCoreCaTrust(MitmCoreCaStatus.untrusted);
    _hold(false);
    await stopSigning();
    if (!ref.mounted) return;
    if (_sameFingerprint(_mitm.trustedFingerprint, ca.fingerprint)) {
      ref
          .read(patchClashConfigProvider.notifier)
          .update(
            (state) => state.copyWith(
              mitm: state.mitm.copyWith(trustedFingerprint: null),
            ),
          );
    }
    if (wasLeased) {
      commonPrint.log(
        'The MITM CA is no longer trusted; decryption is off',
        logLevel: LogLevel.warning,
      );
    }
  }

  /// Bounded, so a dead Core never holds up quit, turn-off or removal.
  Future<void> stopSigning() async {
    _loaded = null;
    if (ref.read(coreStatusProvider) != CoreStatus.connected) return;
    try {
      await ref
          .read(coreHandlerProvider)
          .stopMitmSigning(timeout: _stopBudget)
          .timeout(_stopBudget);
    } catch (error) {
      commonPrint.log(
        'mitm.stopSigning failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
  }

  /// The migration leased [fingerprint] under this connection: no reload.
  void adopt(String fingerprint) {
    _loaded = (connection: _connection, fingerprint: fingerprint);
    state = MitmCoreCaTrust(MitmCoreCaStatus.leased, leased: fingerprint);
    _hold(true);
    _kick();
  }

  void reload() {
    _loaded = null;
    _kick();
  }

  int get connection => _connection;

  void _hold(bool on) {
    if (_holding == on) return;
    _holding = on;
    unawaited(
      _signer?.holdActivity(on).catchError((Object _) {}) ??
          Future<void>.value(),
    );
  }
}

enum MitmMigrationOutcome {
  switched,
  cancelled,
  untrusted,
  failed,
  coreIdentity,
}

final mitmCaMigrationProvider = NotifierProvider<MitmCaMigration, bool>(
  MitmCaMigration.new,
);

/// Staged: a pending CA is made or imported while the one in use stays; it
/// is installed and trusted, checked and leased in the Core, and only then
/// takes over in one settings write. Cancelling, an untrusted or failed
/// check leave the CA in use as it was. The state is whether a step runs.
class MitmCaMigration extends Notifier<bool> {
  @override
  bool build() => false;

  Mitm get _mitm => ref.read(patchClashConfigProvider).mitm;

  void _update(Mitm Function(Mitm) update) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mitm: update(state.mitm)));
  }

  Future<T> _step<T>(Future<T> Function() run) async {
    state = true;
    try {
      return await run();
    } finally {
      if (ref.mounted) state = false;
    }
  }

  /// With no CA at all the new one is in use at once, still to be trusted.
  Future<MitmCertificate> generate() => _step(() async {
    final generated = await ref.read(coreHandlerProvider).generateMitmCa();
    return _keep(generated.p12, generated.passphrase, generated.certificate);
  });

  /// A refusal is a [CoreMethodException] carrying its reason.
  Future<MitmCertificate> import(MitmCaP12 p12, String passphrase) =>
      _step(() async {
        final certificate = await ref
            .read(coreHandlerProvider)
            .inspectMitmCa(p12, passphrase);
        return _keep(p12, passphrase, certificate);
      });

  Future<MitmCertificate> _keep(
    MitmCaP12 p12,
    String passphrase,
    MitmCertificate certificate,
  ) async {
    // Its passphrase in the keychain is the one the stored p12 opens with.
    if (_sameFingerprint(certificate.fingerprint, _mitm.coreCa?.fingerprint)) {
      throw const CoreMethodException(
        code: 'mitm_ca',
        message: 'This CA is already in use',
        details: {'reason': 'inUse'},
      );
    }
    await ref
        .read(mitmPassphraseStoreProvider)
        ?.writePassphrase(certificate.fingerprint, passphrase);
    final legacy = await ref.read(mitmLegacyCaProvider.future);
    final mitm = _mitm;
    final previous = mitm.pendingCaCertificate;
    if (mitm.coreCa == null && legacy == null) {
      _update(
        (mitm) => mitm.copyWith(
          caP12: p12,
          caCertificate: certificate,
          trustedFingerprint: null,
        ),
      );
    } else {
      _update(
        (mitm) =>
            mitm.copyWith(pendingCaP12: p12, pendingCaCertificate: certificate),
      );
    }
    if (previous != null &&
        !_sameFingerprint(previous.fingerprint, certificate.fingerprint)) {
      await _forgetPassphrase(previous.fingerprint);
    }
    return certificate;
  }

  Future<void> _forgetPassphrase(String fingerprint) async {
    try {
      await ref
          .read(mitmPassphraseStoreProvider)
          ?.deletePassphrase(fingerprint);
    } catch (error) {
      commonPrint.log(
        'Deleting a MITM CA passphrase failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
  }

  Future<MitmMigrationOutcome> installAndSwitch() => _step(() async {
    final pending = _mitm.pendingCaCertificate;
    final store = ref.read(mitmTrustStoreProvider);
    if (pending == null || store == null) return MitmMigrationOutcome.failed;
    try {
      await store.install(pending);
    } on ProcessException catch (error) {
      commonPrint.log(
        'Installing the new MITM CA did not finish: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return MitmMigrationOutcome.cancelled;
    }
    return _verify();
  });

  Future<MitmMigrationOutcome> verify() => _step(_verify);

  Future<MitmMigrationOutcome> _verify() =>
      ref.read(mitmCoreCaProvider.notifier).exclusive(_verifyPending);

  Future<MitmMigrationOutcome> _verifyPending() async {
    final mitm = _mitm;
    final pending = mitm.pendingCaCertificate;
    final p12 = mitm.pendingCaP12;
    final signer = ref.read(mitmSignerProvider);
    final store = ref.read(mitmTrustStoreProvider);
    if (pending == null || p12 == null || signer == null || store == null) {
      return MitmMigrationOutcome.failed;
    }
    if (await signer.coreIdentity() != MitmCoreIdentity.verified) {
      return MitmMigrationOutcome.coreIdentity;
    }
    final core = ref.read(coreHandlerProvider);
    final lease = ref.read(mitmCoreCaProvider.notifier);
    final connection = lease.connection;
    final replaced = mitm.coreCa != null;
    try {
      final passphrase = await ref
          .read(mitmPassphraseStoreProvider)
          ?.readPassphrase(pending.fingerprint);
      if (passphrase == null) return MitmMigrationOutcome.failed;
      await core.setMitmCa(
        MitmCaSecret(
          p12: p12,
          passphrase: passphrase,
          fingerprint: pending.fingerprint,
        ),
      );
      final leaf = await core.issueMitmCheck();
      final check = leaf.check;
      if (check == null) return MitmMigrationOutcome.failed;
      final verdict = await store.check(pending, () async => leaf.pem);
      if (verdict.trust != MitmTrust.ready) {
        return MitmMigrationOutcome.untrusted;
      }
      final leased = await core.leaseMitmTrust(pending.fingerprint, check);
      if (!leased.leasedFor(pending.fingerprint) ||
          lease.connection != connection ||
          !ref.mounted ||
          !_sameFingerprint(
            _mitm.pendingCaCertificate?.fingerprint,
            pending.fingerprint,
          )) {
        return MitmMigrationOutcome.failed;
      }
      final current = _mitm.coreCa;
      final retired =
          _sameFingerprint(current?.fingerprint, pending.fingerprint)
          ? null
          : current;
      _update(
        (mitm) => mitm.copyWith(
          caP12: p12,
          caCertificate: pending,
          pendingCaP12: null,
          pendingCaCertificate: null,
          trustedFingerprint: pending.fingerprint,
          retiredCaCertificate: retired ?? mitm.retiredCaCertificate,
        ),
      );
      lease.adopt(pending.fingerprint);
      if (retired != null) await _forgetPassphrase(retired.fingerprint);
      return MitmMigrationOutcome.switched;
    } catch (error) {
      commonPrint.log(
        'Checking the new MITM CA failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return MitmMigrationOutcome.failed;
    } finally {
      // The Core has one CA slot: give it back to the one in use.
      if (ref.mounted &&
          !_sameFingerprint(_mitm.coreCa?.fingerprint, pending.fingerprint)) {
        if (replaced) {
          lease.reload();
        } else {
          await lease.stopSigning();
        }
      }
    }
  }

  Future<void> discard() => _step(() async {
    final pending = _mitm.pendingCaCertificate;
    _update(
      (mitm) => mitm.copyWith(pendingCaP12: null, pendingCaCertificate: null),
    );
    if (pending != null &&
        !_sameFingerprint(pending.fingerprint, _mitm.coreCa?.fingerprint)) {
      await _forgetPassphrase(pending.fingerprint);
    }
  });

  /// The legacy keychain CA, or a Core CA replaced since.
  Future<MitmCertificate?> oldCertificate() async {
    final mitm = _mitm;
    if (mitm.coreCa == null) return null;
    final legacy = await ref.read(mitmLegacyCaProvider.future);
    if (legacy != null &&
        !_sameFingerprint(legacy.fingerprint, mitm.coreCa?.fingerprint)) {
      return legacy;
    }
    final retired = mitm.retiredCaCertificate;
    if (_sameFingerprint(retired?.fingerprint, mitm.coreCa?.fingerprint)) {
      return null;
    }
    return retired;
  }

  Future<bool> removeOld() => _step(() async {
    final old = await oldCertificate();
    if (old == null) return false;
    final legacy = await ref.read(mitmLegacyCaProvider.future);
    if (legacy != null &&
        _sameFingerprint(legacy.fingerprint, old.fingerprint)) {
      final removed =
          await ref.read(mitmSignerProvider)?.deleteLegacy(old.fingerprint) ??
          false;
      ref.invalidate(mitmLegacyCaProvider);
      return removed;
    }
    try {
      await ref.read(mitmTrustStoreProvider)?.remove(old);
    } on ProcessException catch (error) {
      commonPrint.log(
        'Removing the old MITM CA failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return false;
    }
    _update((mitm) => mitm.copyWith(retiredCaCertificate: null));
    return true;
  });
}
