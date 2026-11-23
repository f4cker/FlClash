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
      'inUse' => l.mitmImportInUse,
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
) => switch (mitm.coreCa?.fingerprint == certificate.fingerprint) {
  true => l.mitmCaConfigured(certificate.subject),
  false when !mitm.enable => l.mitmCaAvailable(certificate.subject),
  false => l.mitmCaInUseLegacy(certificate.subject),
};

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
  final confirm = await mitmConfirmDelete(
    title: l.mitmRemoveOldCaTitle,
    text: l.mitmRemoveOldCaTip,
    confirmText: l.mitmRemoveOldCa,
    certificate: old,
  );
  if (!confirm) return;
  final removed = await globalState.loadingRun<bool>(
    () => ref.read(mitmCaMigrationProvider.notifier).removeOld(old.fingerprint),
    tag: LoadingTag.mitm,
    title: l.mitmRemoveOldCa,
  );
  if (removed == false) {
    dialogs.showBanner(l.mitmRemoveOldCaFailed, level: BannerLevel.warning);
  }
}

final mitmOldCaProvider = FutureProvider.autoDispose<List<MitmCertificate>>((
  ref,
) {
  ref.watch(
    patchClashConfigProvider.select(
      (state) => (state.mitm.coreCa, state.mitm.retiredCaCertificates),
    ),
  );
  ref.watch(mitmLegacyCaProvider);
  return ref.read(mitmCaMigrationProvider.notifier).oldCertificates();
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

/// Asks before deleting [certificate]: names it by subject and full
/// fingerprint, says the change stays on this Mac, and focuses Cancel so a
/// bare Enter never deletes.
class MitmDeleteCaDialog extends StatefulWidget {
  const MitmDeleteCaDialog({
    super.key,
    required this.title,
    required this.text,
    required this.confirmText,
    required this.certificate,
  });

  final String title;
  final String text;
  final String confirmText;
  final MitmCertificate certificate;

  @override
  State<MitmDeleteCaDialog> createState() => _MitmDeleteCaDialogState();
}

class _MitmDeleteCaDialogState extends State<MitmDeleteCaDialog> {
  final _cancel = FocusNode(canRequestFocus: false, skipTraversal: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cancel.descendants
          .where((node) => node.canRequestFocus && !node.skipTraversal)
          .firstOrNull
          ?.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return AlertDialog(
      title: widget.title,
      destructive: true,
      actions: [
        Focus(
          focusNode: _cancel,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(widget.confirmText),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MitmCertificateNote(
            text: widget.text,
            certificate: widget.certificate,
          ),
          const SizedBox(height: 8),
          Text(l.mitmCaScopeThisMac),
        ],
      ),
    );
  }
}

Future<bool> mitmConfirmDelete({
  required String title,
  required String text,
  required String confirmText,
  required MitmCertificate certificate,
}) async =>
    await dialogs.showCommonDialog<bool>(
      child: MitmDeleteCaDialog(
        title: title,
        text: text,
        confirmText: confirmText,
        certificate: certificate,
      ),
    ) ==
    true;

/// The certificate section on macOS: which CA is configured, its trust and
/// whether decryption runs with it, the staged switch to a new one, and the
/// old CA still on this Mac in a section of its own.
class MitmCoreCaSection extends ConsumerWidget {
  const MitmCoreCaSection({
    super.key,
    required this.certificate,
    required this.trustLabel,
    this.installLabel,
    this.onInstall,
    this.onRetrust,
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
  final VoidCallback? onRetrust;
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
    final old = keepsRoot
        ? const <MitmCertificate>[]
        : ref.watch(mitmOldCaProvider).value ?? const [];
    final running = ref.watch(mitmCaMigrationProvider);
    final footer = [
      mitmCoreCaStatusText(l, trust),
      this.footer,
    ].nonNulls.join('\n');
    return Column(
      children: [
        generateSection(
          title: l.certificate,
          items: [..._rows(context, ref, l, mitm, trust, keepsRoot: keepsRoot)],
          footer: footer.isEmpty ? null : footer,
        ),
        if (old.isNotEmpty)
          generateSection(
            title: l.mitmOldCaSection(old.length),
            items: [
              for (final each in old)
                MitmOldCaRow(
                  key: ValueKey(each.fingerprint),
                  certificate: each,
                  onRemove: running ? null : () => _removeOld(ref, each),
                ),
            ],
          ),
      ],
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
    final core = mitm.coreCa?.fingerprint == certificate.fingerprint;
    final untrusted = core && trust.status == MitmCoreCaStatus.untrusted;
    final run = core || !mitm.enable ? mitmRunText(l, mitm, trust) : null;
    return [
      ListItem(
        title: Text(mitmCaInUseText(l, mitm, certificate)),
        subtitle: Text(untrusted ? run! : [trustLabel, ?run].join('\n')),
        onTap: onDetails,
      ),
      if (untrusted) ...[
        ListItem(
          leading: ExcludeSemantics(
            child: GlyphIcon(
              AppGlyphs.warning,
              color: context.colorScheme.error,
            ),
          ),
          title: Text(l.mitmCoreCaUntrustedTitle),
          subtitle: Text(l.mitmCoreCaUntrusted),
        ),
        ListItem(title: Text(l.mitmRetrust), onTap: onRetrust),
      ] else if (installLabel case final label?)
        ListItem(title: Text(label), onTap: onInstall),
      ListItem(
        title: Text(l.exportCertificate),
        subtitle: Text(l.mitmExportCertificateContent),
        onTap: onExport,
      ),
      if (!keepsRoot) ..._migrationRows(context, ref, l, mitm),
      if (!keepsRoot && mitm.coreCa != null)
        ListItem(
          title: Text(
            l.mitmDeleteCurrentCa,
            style: TextStyle(color: context.colorScheme.destructive),
          ),
          onTap: onDelete,
        ),
    ];
  }

  List<Widget> _migrationRows(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    Mitm mitm,
  ) {
    final pending = mitm.pendingCaCertificate;
    final running = ref.watch(mitmCaMigrationProvider);
    if (pending == null) {
      return [
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
      ];
    }
    return [
      ListItem(
        title: Text(l.mitmPendingCertificate(pending.subject)),
        subtitle: Text(running ? l.mitmVerifying : l.mitmPendingVerification),
      ),
      MitmActionRow(
        title: l.mitmInstallAndSwitch,
        subtitle: l.mitmInstallAndSwitchDesc,
        onTap: running ? null : () => mitmInstallAndSwitch(ref),
      ),
      MitmActionRow(
        title: l.mitmDiscardPending,
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
    ];
  }
}

/// Whether decryption runs with the Core's CA; "stopped" only once it was.
String mitmRunText(AppLocalizations l, Mitm mitm, MitmCoreCaTrust trust) {
  if (!mitm.enable) return l.mitmRunOff;
  return switch (trust.status) {
    MitmCoreCaStatus.leased => l.mitmRunActive,
    MitmCoreCaStatus.untrusted => l.mitmRunStopped,
    MitmCoreCaStatus.failed => l.mitmRunNotRunning,
    _ => l.mitmRunChecking,
  };
}

/// A row that does something; with no [onTap] it is dimmed, skipped by
/// focus and announced as a disabled button.
class MitmActionRow extends StatelessWidget {
  const MitmActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final style = enabled
        ? null
        : TextStyle(color: context.colorScheme.onSurface.opacity38);
    final subtitle = this.subtitle;
    return Semantics(
      button: true,
      enabled: enabled,
      child: ExcludeFocus(
        excluding: !enabled,
        child: ListItem(
          title: Text(title, style: style),
          subtitle: subtitle == null ? null : Text(subtitle, style: style),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// The old CA by name and fingerprint; its removal sits under the name in
/// a narrow window and beside it otherwise.
class MitmOldCaRow extends StatelessWidget {
  const MitmOldCaRow({super.key, required this.certificate, this.onRemove});

  static const narrowWidth = 480.0;

  final MitmCertificate certificate;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final button = TonalButton(
      glyph: AppGlyphs.delete,
      label: l.mitmRemoveOldCa,
      onPressed: onRemove,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < narrowWidth;
        return ListItem(
          title: Text(certificate.subject),
          subtitle: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const SizedBox(height: 8), button],
                )
              : null,
          trailing: narrow ? null : button,
        );
      },
    );
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
          ExcludeSemantics(child: Text(l.mitmImportPassword)),
          const SizedBox(height: 6),
          Semantics(
            label: l.mitmImportPassword,
            child: SecretTextFormField(
              controller: _password,
              focusNode: _passwordFocus,
              decoration: InputDecoration(
                errorText: passwordError ? error : null,
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
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
  bool _risks = false;

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
          child: Text(_include ? l.mitmBackupWithKey : l.backup),
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
            const SizedBox(height: 4),
            Semantics(
              expanded: _risks,
              child: TextButton.icon(
                onPressed: () => setState(() => _risks = !_risks),
                icon: GlyphIcon(
                  _risks ? AppGlyphs.chevronUp : AppGlyphs.chevronDown,
                ),
                label: Text(l.mitmBackupRiskDetails),
              ),
            ),
            if (_risks) ...[
              Text(l.mitmBackupRiskImpact),
              const SizedBox(height: 8),
              Text(l.mitmBackupRiskRevoke),
            ],
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
