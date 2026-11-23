import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart' show CoreMethodException;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/mitm_core_ca.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The words for a reason `mitm.inspectCA` or `mitm.setCA` refused a CA.
String mitmImportFailureText(AppLocalizations l, String? reason) =>
    switch (reason) {
      'badP12' => l.mitmImportBadP12,
      'badPassphrase' => l.mitmImportBadPassphrase,
      'notCA' || 'notRoot' => l.mitmImportNotRoot,
      'keyMismatch' => l.mitmImportKeyMismatch,
      'expired' => l.mitmImportExpired,
      'notYetValid' => l.mitmImportNotYetValid,
      'unsupportedKey' => l.mitmImportUnsupportedKey,
      'nameConstraints' => l.mitmImportNameConstraints,
      final reason? => l.mitmImportUnusable(reason),
      null => l.mitmImportBadP12,
    };

String mitmMigrationText(AppLocalizations l, MitmMigrationOutcome outcome) =>
    switch (outcome) {
      MitmMigrationOutcome.switched => l.mitmMigrationSwitched,
      MitmMigrationOutcome.cancelled => l.mitmMigrationCancelled,
      MitmMigrationOutcome.untrusted => l.mitmMigrationUntrusted,
      MitmMigrationOutcome.failed => l.mitmMigrationFailed,
      MitmMigrationOutcome.coreIdentity => l.mitmMigrationCoreIdentity,
    };

/// Why the Core's CA does not sign, for the certificate section's footer.
String? mitmCoreCaStatusText(
  AppLocalizations l,
  MitmCoreCaTrust trust,
) => switch (trust) {
  MitmCoreCaTrust(status: MitmCoreCaStatus.untrusted) => l.mitmCoreCaUntrusted,
  MitmCoreCaTrust(failure: MitmCoreCaFailure.passphraseMissing) =>
    l.mitmCoreCaPassphraseMissing,
  MitmCoreCaTrust(failure: MitmCoreCaFailure.coreOutdated) =>
    l.mitmCoreCaCoreOutdated,
  MitmCoreCaTrust(failure: MitmCoreCaFailure.refused) => l.mitmCoreCaRefused,
  _ => null,
};

Future<void> _announce(MitmMigrationOutcome? outcome) async {
  if (outcome == null) return;
  final text = mitmMigrationText(currentAppLocalizations, outcome);
  dialogs.showBanner(
    text,
    level: outcome == MitmMigrationOutcome.switched
        ? BannerLevel.success
        : BannerLevel.warning,
  );
}

/// Installs, trusts, checks and switches to the pending CA.
Future<void> mitmInstallAndSwitch(WidgetRef ref) async {
  final l = currentAppLocalizations;
  final outcome = await globalState.loadingRun<MitmMigrationOutcome>(
    ref.read(mitmCaMigrationProvider.notifier).installAndSwitch,
    tag: LoadingTag.mitm,
    title: l.mitmInstallAndSwitch,
  );
  await _announce(outcome);
}

/// Makes a pending CA beside the one in use, then installs and switches.
Future<void> mitmMigrate(WidgetRef ref) async {
  final l = currentAppLocalizations;
  final made = await globalState.loadingRun<MitmCertificate>(
    ref.read(mitmCaMigrationProvider.notifier).generate,
    tag: LoadingTag.mitm,
    title: l.mitmMigrate,
  );
  if (made == null) return;
  await mitmInstallAndSwitch(ref);
}

/// The user's own p12 and its password. With a CA in use it waits as
/// pending; with none it is in use, still to be trusted.
Future<void> mitmImport(WidgetRef ref) async {
  final l = currentAppLocalizations;
  final file = await picker.pickerFile();
  if (file == null) return;
  final bytes = await file.readBytes();
  final passphrase = await dialogs.showPasswordInput(
    title: l.mitmImportPassword,
  );
  if (passphrase == null) return;
  String? refusal;
  final imported = await globalState.loadingRun<MitmCertificate>(
    () async {
      try {
        return await ref
            .read(mitmCaMigrationProvider.notifier)
            .import(MitmCaP12(base64.encode(bytes)), passphrase);
      } on CoreMethodException catch (error) {
        refusal = switch (error.details) {
          {'reason': final String reason} => reason,
          _ => null,
        };
        throw StateError(mitmImportFailureText(l, refusal));
      } on FormatException {
        throw StateError(l.mitmImportBadP12);
      }
    },
    tag: LoadingTag.mitm,
    title: l.mitmImportCertificate,
  );
  if (imported == null) return;
  ref.invalidate(mitmCaProvider);
  if (ref.read(patchClashConfigProvider).mitm.pendingCaCertificate != null) {
    await mitmInstallAndSwitch(ref);
  }
}

Future<void> _removeOld(WidgetRef ref, MitmCertificate old) async {
  final l = currentAppLocalizations;
  final confirm = await dialogs.showMessage(
    title: l.mitmRemoveOldCa,
    message: TextSpan(text: l.mitmRemoveOldCaTip(old.subject)),
    destructive: true,
  );
  if (confirm != true) return;
  final removed = await globalState.loadingRun<bool>(
    ref.read(mitmCaMigrationProvider.notifier).removeOld,
    tag: LoadingTag.mitm,
    title: l.mitmRemoveOldCa,
  );
  if (removed == false) {
    dialogs.showBanner(l.mitmRemoveOldCaFailed, level: BannerLevel.warning);
  }
}

final _mitmOldCaProvider = FutureProvider.autoDispose<MitmCertificate?>((ref) {
  ref.watch(
    patchClashConfigProvider.select(
      (state) => (state.mitm.coreCa, state.mitm.retiredCaCertificate),
    ),
  );
  ref.watch(mitmLegacyCaProvider);
  return ref.read(mitmCaMigrationProvider.notifier).oldCertificate();
});

/// Which certificate is in use, said on the certificate's own row.
String mitmCaInUseText(
  AppLocalizations l,
  Mitm mitm,
  MitmCertificate certificate,
) => mitm.coreCa?.fingerprint == certificate.fingerprint
    ? l.mitmCaInUseCore(certificate.subject)
    : l.mitmCaInUseLegacy(certificate.subject);

/// The rows that move to a new CA, import one, or remove the old one.
List<Widget> mitmCoreCaItems(
  BuildContext context,
  WidgetRef ref, {
  required bool keepsRoot,
}) {
  final l = context.appLocalizations;
  final mitm = ref.watch(patchClashConfigProvider.select((s) => s.mitm));
  final pending = mitm.pendingCaCertificate;
  final old = ref.watch(_mitmOldCaProvider).value;
  if (keepsRoot) return const [];
  return [
    if (pending != null) ...[
      ListItem(
        title: Text(l.mitmPendingCertificate(pending.subject)),
        subtitle: Text(l.mitmInstallAndSwitchDesc),
        onTap: () => mitmInstallAndSwitch(ref),
      ),
      ListItem(
        title: Text(l.mitmDiscardPending),
        onTap: () => unawaited(
          globalState.loadingRun<void>(
            ref.read(mitmCaMigrationProvider.notifier).discard,
            tag: LoadingTag.mitm,
            title: l.mitmDiscardPending,
          ),
        ),
      ),
    ] else
      ListItem(
        title: Text(
          mitm.coreCa == null ? l.mitmMigrate : l.regenerateCertificate,
        ),
        subtitle: mitm.coreCa == null ? Text(l.mitmMigrateDesc) : null,
        onTap: () => mitmMigrate(ref),
      ),
    ListItem(
      title: Text(l.mitmImportCertificate),
      onTap: () => mitmImport(ref),
    ),
    if (old != null)
      ListItem(
        title: Text(l.mitmRemoveOldCa),
        subtitle: Text(old.subject),
        onTap: () => _removeOld(ref, old),
      ),
  ];
}
