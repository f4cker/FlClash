import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart' show CoreMethodException;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/mitm_core_ca.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Words a refusal only when its reason is certain; the rest is generic.
String mitmImportFailureText(AppLocalizations l, String? reason) =>
    switch (reason) {
      'badPassphrase' => l.mitmImportBadPassphrase,
      'notCA' || 'notRoot' => l.mitmImportNotRoot,
      'expired' => l.mitmImportExpired,
      'unsupportedKey' => l.mitmImportUnsupportedKey,
      'nameConstraints' => l.mitmImportNameConstraints,
      _ => l.mitmImportFailed,
    };

String mitmMigrationText(AppLocalizations l, MitmMigrationOutcome outcome) =>
    outcome == MitmMigrationOutcome.switched
    ? l.mitmMigrationSwitched
    : l.mitmMigrationFailed;

String? mitmCoreCaStatusText(AppLocalizations l, MitmCoreCaTrust trust) =>
    switch (trust.failure) {
      MitmCoreCaFailure.passphraseMissing => l.mitmCoreCaPassphraseMissing,
      MitmCoreCaFailure.coreOutdated => l.mitmCoreCaCoreOutdated,
      MitmCoreCaFailure.refused => l.mitmCoreCaRefused,
      _ => null,
    };

String mitmCaInUseText(
  AppLocalizations l,
  Mitm mitm,
  MitmCertificate certificate,
) => mitm.coreCa?.fingerprint == certificate.fingerprint
    ? l.mitmCaInUseCore(certificate.subject)
    : l.mitmCaInUseLegacy(certificate.subject);

void _announce(MitmMigrationOutcome? outcome) {
  if (outcome == null) return;
  dialogs.showBanner(
    mitmMigrationText(currentAppLocalizations, outcome),
    level: outcome == MitmMigrationOutcome.switched
        ? BannerLevel.success
        : BannerLevel.warning,
  );
}

Future<void> mitmInstallAndSwitch(WidgetRef ref) async {
  final outcome = await globalState.loadingRun<MitmMigrationOutcome>(
    ref.read(mitmCaMigrationProvider.notifier).installAndSwitch,
    tag: LoadingTag.mitm,
    title: currentAppLocalizations.mitmInstallAndSwitch,
  );
  _announce(outcome);
}

Future<void> mitmMigrate(WidgetRef ref) async {
  final made = await globalState.loadingRun<MitmCertificate>(
    ref.read(mitmCaMigrationProvider.notifier).generate,
    tag: LoadingTag.mitm,
    title: currentAppLocalizations.mitmGenerateNewCertificate,
  );
  if (made == null) return;
  await mitmInstallAndSwitch(ref);
}

/// The Core's refusal reason, or `''` when it gave none.
Future<String?> _importWith(
  WidgetRef ref,
  List<int> bytes,
  String password,
) async {
  try {
    await ref
        .read(mitmCaMigrationProvider.notifier)
        .import(MitmCaP12(base64.encode(bytes)), password);
    return null;
  } on CoreMethodException catch (error) {
    return switch (error.details) {
      {'reason': final String reason} => reason,
      _ => '',
    };
  } on FormatException {
    return 'badP12';
  } catch (error) {
    commonPrint.log(
      'Importing a MITM CA failed: ${compactError(error)}',
      logLevel: LogLevel.warning,
    );
    return '';
  }
}

Future<void> mitmImport(WidgetRef ref) async {
  final imported = await dialogs.showCommonDialog<bool>(
    child: MitmImportDialog(
      pick: () async {
        final file = await picker.pickerFile();
        if (file == null) return null;
        return (name: file.name, bytes: await file.readBytes());
      },
      submit: (bytes, password) => _importWith(ref, bytes, password),
    ),
  );
  if (imported != true) return;
  ref.invalidate(mitmCaProvider);
  if (ref.read(patchClashConfigProvider).mitm.pendingCaCertificate != null) {
    await mitmInstallAndSwitch(ref);
  }
}

Future<void> _removeOld(WidgetRef ref, MitmCertificate old) async {
  final l = currentAppLocalizations;
  final confirm = await dialogs.showMessage(
    title: l.mitmRemoveOldCaTitle,
    body: MitmCertificateNote(text: l.mitmRemoveOldCaTip, certificate: old),
    confirmText: l.mitmRemoveOldCa,
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

final mitmOldCaProvider = FutureProvider.autoDispose<MitmCertificate?>((ref) {
  ref.watch(
    patchClashConfigProvider.select(
      (state) => (state.mitm.coreCa, state.mitm.retiredCaCertificate),
    ),
  );
  ref.watch(mitmLegacyCaProvider);
  return ref.read(mitmCaMigrationProvider.notifier).oldCertificate();
});

/// A text, then the certificate it is about by name and full fingerprint.
class MitmCertificateNote extends StatelessWidget {
  const MitmCertificateNote({
    super.key,
    required this.text,
    required this.certificate,
  });

  final String text;
  final MitmCertificate certificate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(height: 8),
        Text(certificate.subject),
        Text(
          certificate.fingerprint,
          style: AppTextStyle.custom(
            context,
            size: 12,
            leading: 18,
          ).toJetBrainsMono,
        ),
      ],
    );
  }
}

/// The certificate section on macOS: which CA is in use, its trust, and
/// the staged switch to a new one.
class MitmCoreCaSection extends ConsumerWidget {
  const MitmCoreCaSection({
    super.key,
    required this.certificate,
    required this.trustLabel,
    this.installLabel,
    this.onInstall,
    this.onDetails,
    this.onExport,
    this.onDelete,
    this.onGenerate,
    this.footer,
  });

  final MitmCertificate? certificate;
  final String trustLabel;
  final String? installLabel;
  final VoidCallback? onInstall;
  final VoidCallback? onDetails;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;
  final VoidCallback? onGenerate;
  final String? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final keepsRoot = ref.watch(safeModeProvider);
    final mitm = ref.watch(patchClashConfigProvider.select((s) => s.mitm));
    final trust = ref.watch(mitmCoreCaProvider);
    final footer = [
      mitmCoreCaStatusText(l, trust),
      this.footer,
    ].nonNulls.join('\n');
    return generateSection(
      title: l.certificate,
      items: [..._rows(context, ref, l, mitm, trust, keepsRoot: keepsRoot)],
      footer: footer.isEmpty ? null : footer,
    );
  }

  List<Widget> _rows(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    Mitm mitm,
    MitmCoreCaTrust trust, {
    required bool keepsRoot,
  }) {
    final certificate = this.certificate;
    if (certificate == null) {
      return [
        ListItem(title: Text(l.mitmGenerateNewCertificate), onTap: onGenerate),
        if (!keepsRoot)
          ListItem(
            title: Text(l.mitmImportCertificate),
            onTap: () => mitmImport(ref),
          ),
      ];
    }
    final untrusted =
        mitm.coreCa != null && trust.status == MitmCoreCaStatus.untrusted;
    return [
      ListItem(
        title: Text(mitmCaInUseText(l, mitm, certificate)),
        subtitle: Text(trustLabel),
        onTap: onDetails,
      ),
      if (untrusted)
        ListItem(
          leading: GlyphIcon(
            AppGlyphs.warning,
            color: context.colorScheme.error,
          ),
          title: Text(l.mitmCoreCaUntrustedTitle),
          subtitle: Text(l.mitmCoreCaUntrusted),
          onTap: onInstall,
        )
      else if (installLabel case final label?)
        ListItem(title: Text(label), onTap: onInstall),
      ListItem(title: Text(l.exportCertificate), onTap: onExport),
      if (!keepsRoot) ..._migrationRows(ref, l, mitm),
      if (!keepsRoot && mitm.coreCa != null)
        ListItem(title: Text(l.deleteCertificate), onTap: onDelete),
    ];
  }

  List<Widget> _migrationRows(WidgetRef ref, AppLocalizations l, Mitm mitm) {
    final pending = mitm.pendingCaCertificate;
    final running = ref.watch(mitmCaMigrationProvider);
    final old = ref.watch(mitmOldCaProvider).value;
    return [
      if (pending != null) ...[
        ListItem(
          title: Text(l.mitmPendingCertificate(pending.subject)),
          subtitle: Text(running ? l.mitmVerifying : l.mitmPendingVerification),
        ),
        ListItem(
          title: Text(l.mitmInstallAndSwitch),
          subtitle: Text(l.mitmInstallAndSwitchDesc),
          onTap: running ? null : () => mitmInstallAndSwitch(ref),
        ),
        ListItem(
          title: Text(l.mitmDiscardPending),
          onTap: running
              ? null
              : () => unawaited(
                  globalState.loadingRun<void>(
                    ref.read(mitmCaMigrationProvider.notifier).discard,
                    tag: LoadingTag.mitm,
                    title: l.mitmDiscardPending,
                  ),
                ),
        ),
      ] else ...[
        ListItem(
          title: Text(
            mitm.coreCa == null
                ? l.mitmUpdateCertificate
                : l.mitmGenerateNewCertificate,
          ),
          subtitle: mitm.coreCa == null
              ? Text(l.mitmUpdateCertificateDesc)
              : null,
          onTap: () => mitmMigrate(ref),
        ),
        ListItem(
          title: Text(l.mitmImportCertificate),
          onTap: () => mitmImport(ref),
        ),
      ],
      if (old != null)
        ListItem(
          title: Text(l.mitmOldCaKept(old.subject)),
          trailing: TonalButton(
            glyph: AppGlyphs.delete,
            label: l.mitmRemoveOldCa,
            onPressed: running ? null : () => _removeOld(ref, old),
          ),
        ),
    ];
  }
}

typedef MitmP12File = ({String name, List<int> bytes});

/// Picks a p12 and takes its password; [submit] answers null once it is
/// imported, or the Core's refusal reason.
class MitmImportDialog extends StatefulWidget {
  const MitmImportDialog({super.key, required this.pick, required this.submit});

  final Future<MitmP12File?> Function() pick;
  final Future<String?> Function(List<int> bytes, String password) submit;

  @override
  State<MitmImportDialog> createState() => _MitmImportDialogState();
}

class _MitmImportDialogState extends State<MitmImportDialog> {
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  MitmP12File? _file;
  String? _refusal;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final file = await widget.pick();
    if (file == null || !mounted) return;
    setState(() {
      _file = file;
      _refusal = null;
      _password.clear();
    });
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null || _password.text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final refusal = await widget.submit(file.bytes, _password.text);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _refusal = refusal;
    });
    if (refusal == 'badPassphrase') _passwordFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final refusal = _refusal;
    final error = refusal == null ? null : mitmImportFailureText(l, refusal);
    final passwordError = refusal == 'badPassphrase';
    final errorStyle = TextStyle(color: context.colorScheme.error);
    return AlertDialog(
      title: l.mitmImportCertificate,
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        ValueListenableBuilder(
          valueListenable: _password,
          builder: (context, value, _) => TextButton(
            onPressed: _file == null || value.text.isEmpty || _busy
                ? null
                : _submit,
            child: Text(l.mitmContinue),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _file?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TonalButton(
                label: l.mitmChooseP12,
                onPressed: _busy ? null : _choose,
              ),
            ],
          ),
          if (error != null && !passwordError) ...[
            const SizedBox(height: 8),
            Text(error, style: errorStyle),
          ],
          const SizedBox(height: 16),
          SecretTextFormField(
            controller: _password,
            focusNode: _passwordFocus,
            decoration: InputDecoration(
              hintText: l.mitmImportPassword,
              errorText: passwordError ? error : null,
            ),
            onFieldSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}

/// Asked before each backup while the Core's CA is in use: true includes
/// it, false leaves it out, null cancels.
class MitmBackupDialog extends StatefulWidget {
  const MitmBackupDialog({super.key, this.include = false});

  final bool include;

  @override
  State<MitmBackupDialog> createState() => _MitmBackupDialogState();
}

class _MitmBackupDialogState extends State<MitmBackupDialog> {
  late bool _include = widget.include;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    return AlertDialog(
      title: l.backup,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_include),
          child: Text(l.backup),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.includeMitmCa)),
              Switch(
                value: _include,
                semanticLabel: l.includeMitmCa,
                onChanged: (value) => setState(() => _include = value),
              ),
            ],
          ),
          if (_include) ...[
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: ShapeDecoration(
                color: colorScheme.warningContainer,
                shape: AppShape.all(AppCorner.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: GlyphIcon(
                        AppGlyphs.warning,
                        color: colorScheme.onWarningContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.includeMitmCaTip,
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// After a restore that brought a CA: true goes on to install and trust it.
class MitmRestoredCaDialog extends StatelessWidget {
  const MitmRestoredCaDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return AlertDialog(
      title: l.restore,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.mitmCaNotNow),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.mitmInstallAndTrust),
        ),
      ],
      child: Text(l.mitmRestoredCaTip),
    );
  }
}
