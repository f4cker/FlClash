import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_body.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_signer.dart';
import 'package:fl_clash/common/mitm_trust.dart';
import 'package:fl_clash/core/method.dart' show coreFailureLogLevel;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' show join;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rust_api/rust_api.dart' show transcodeCharset;

import 'app.dart';
import 'config.dart';
import 'core.dart';
import 'database.dart';

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
  @override
  Future<MitmCoreIdentity> build() async {
    final connected = ref.watch(
      coreStatusProvider.select((status) => status == CoreStatus.connected),
    );
    final signer = ref.read(mitmSignerProvider);
    if (!connected || signer == null) {
      return MitmCoreIdentity.none;
    }
    final identity = await signer.coreIdentity();
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

/// How many `mitm` hostnames the running profile wrote, all of them ignored.
@riverpod
Future<int> mitmIgnoredHostnames(Ref ref) async {
  ref.watch(coreStatusProvider);
  ref.watch(patchClashConfigProvider.select((state) => state.mitm));
  final status = await ref.read(coreHandlerProvider).getMitmStatus();
  return status.ignoredHostnames;
}

/// Answers the Core's `mitmSign` with a leaf for a host on the user's own
/// list, or with why not; the Core passes the connection through on a refusal.
@Riverpod(keepAlive: true)
class MitmSignAction extends _$MitmSignAction {
  @override
  void build() {}

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
        result = await signer.sign(
          host: request.host,
          spki: request.spki,
          hostnames: mitm.hostname,
        );
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
    if (ref.read(patchClashConfigProvider).mitm.trustedFingerprint == trusted) {
      return;
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            mitm: state.mitm.copyWith(trustedFingerprint: trusted),
          ),
        );
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
    final MitmInstallOutcome outcome;
    try {
      outcome = await store.install(ca);
    } finally {
      if (store is AndroidMitmTrustStore && ref.mounted) {
        ref.invalidate(rootAccessProvider);
      }
    }
    if (outcome == MitmInstallOutcome.installed ||
        outcome == MitmInstallOutcome.untilReboot) {
      await refresh();
    }
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
        removed = !ref.read(safeModeProvider) && await store.remove(old);
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
}) async {
  final body = await ref
      .read(coreHandlerProvider)
      .getMitmBody(id, response: response);
  if (body == null) {
    return null;
  }
  final content = await compute(readMitmBody, (body, contentType));
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

/// Why the Core skips each of the user's hostnames, by the line.
@riverpod
Future<Map<String, String>> mitmHostnameIssues(Ref ref) async {
  final hostname = ref.watch(
    patchClashConfigProvider.select((state) => state.mitm.hostname),
  );
  final issues = await _issuesOf(ref, MitmRules(hostname: hostname));
  return issues[MitmList.hostname] ?? const {};
}

Future<Map<MitmList, Map<String, String>>> _issuesOf(
  Ref ref,
  MitmRules mitm,
) async {
  final issues = await ref.read(coreHandlerProvider).validateMitm(mitm);
  return {
    for (final MapEntry(key: list, value: lines) in issues.entries)
      list: {
        for (final MapEntry(key: index, value: issue) in lines.entries)
          mitm.linesOf(list)[index]: issue,
      },
  };
}

typedef MitmModuleDetails = ({
  MitmModuleContent content,
  Map<MitmList, Map<String, String>> issues,
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
  final content = await compute(
    _parseModuleSource,
    MitmModuleSource(
      content: await file.readAsString(),
      arguments: module.arguments,
      resources: module.resources,
    ),
  );
  return (content: content, issues: await _issuesOf(ref, content.mitm));
}
