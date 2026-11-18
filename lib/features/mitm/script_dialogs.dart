import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart' show RuleEditFrame;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rewrite.dart' show mitmRewriteErrorColor;
import 'rewrite_dialogs.dart' show MitmLineEditor, mitmRewriteFailureText;
import 'script_actions.dart';

const mitmScriptInk = Color(0xFF0A7C86);
const _scriptInkDark = Color(0xFF4FC3CF);
const mitmAmberInk = Color(0xFFB25E00);
const _amberInkDark = Color(0xFFFFB74D);
const _amberFill = Color(0xFFFFF4E5);
const _addedInk = Color(0xFF16632C);
const _addedFill = Color(0xFFE8F5EC);
const _removedFill = Color(0xFFFDECEA);
const _excludedFill = Color(0xFFF2F1F5);
const _excludedInk = Color(0xFF8E8C94);
const _dialogWidth = 560.0;
const _diffWidth = 640.0;
const _validateDelay = Duration(milliseconds: 300);

String mitmScriptFailureText(AppLocalizations l, Object error) =>
    mitmScriptErrorMessage(error) ?? mitmRewriteFailureText(l, error);

/// A failed update that left the current version running.
String mitmKeptFailureText(AppLocalizations l, MitmUpdateFailure? failure) =>
    switch (failure) {
      MitmUpdateFailure.download => l.mitmUpdateDownloadFailedKept,
      MitmUpdateFailure.invalid => l.mitmUpdateInvalidKept,
      _ => l.mitmUpdateCheckFailedKept,
    };

bool _dark(BuildContext context) =>
    context.colorScheme.brightness == Brightness.dark;

Color mitmScriptColor(BuildContext context) =>
    _dark(context) ? _scriptInkDark : mitmScriptInk;

Color mitmAmberColor(BuildContext context) =>
    _dark(context) ? _amberInkDark : mitmAmberInk;

Color _addedColor(BuildContext context) =>
    _dark(context) ? const Color(0x3316632C) : _addedFill;

Color _removedColor(BuildContext context) =>
    _dark(context) ? const Color(0x47B3261E) : _removedFill;

String mitmScriptKindLabel(AppLocalizations l, MitmScriptKind kind) =>
    switch (kind) {
      MitmScriptKind.request => l.mitmScriptKindRequest,
      MitmScriptKind.response => l.mitmScriptKindResponse,
    };

String mitmScriptPasteErrorText(AppLocalizations l, MitmScriptPasteError e) =>
    switch (e) {
      MitmScriptPasteError.unsupportedType => l.mitmScriptUnsupportedType,
      MitmScriptPasteError.unreadable => l.mitmScriptUnreadable,
      MitmScriptPasteError.noPattern => l.mitmScriptNoPattern,
      MitmScriptPasteError.noPath => l.mitmScriptNoPath,
    };

/// The amber block that says what scripts may do, as the engine allows it.
class MitmScriptCapabilities extends StatelessWidget {
  const MitmScriptCapabilities({super.key, this.body});

  final String? body;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final amber = mitmAmberColor(context);
    final text = AppTextStyle.footnote.of(context);
    Widget line(Glyph glyph, String label) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: GlyphIcon(glyph, size: 16, color: amber),
        ),
        Expanded(child: Text(label, style: text)),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: _dark(context) ? const Color(0x33B25E00) : _amberFill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              GlyphIcon(AppGlyphs.shieldAlert, size: 18, color: amber),
              Expanded(
                child: Text(
                  body ?? l.mitmScriptConfirmBody,
                  style: AppTextStyle.footnote.of(context, emphasized: true),
                ),
              ),
            ],
          ),
          line(AppGlyphs.eye, l.mitmCapabilityRead),
          line(AppGlyphs.send, l.mitmCapabilitySend),
          line(AppGlyphs.key, l.mitmCapabilityStore),
          Text(
            l.mitmCapabilityLimits,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A text link whose words line up with the column it sits in.
class MitmLinkButton extends StatelessWidget {
  const MitmLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.glyph,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  /// A chevron after [label], for a link that opens in place.
  final Glyph? glyph;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: const ButtonStyle(
        padding: EdgeInsets.zero,
        minimumSize: Size(0, 24),
        tapTargetSize: TapTargetSize.shrinkWrap,
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label),
            if (glyph case final glyph?)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 2),
                  child: GlyphIcon(
                    glyph,
                    size: 12,
                    color: color ?? context.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        maxLines: 1,
        style: AppTextStyle.footnote
            .of(context, emphasized: true)
            .copyWith(color: color ?? context.colorScheme.primary),
      ),
    );
  }
}

/// A line of [style]'s colour led by [glyph]: a row's reason, or a check.
class MitmMarkedLine extends StatelessWidget {
  const MitmMarkedLine(
    this.text, {
    super.key,
    required this.style,
    this.glyph = AppGlyphs.warning,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle style;
  final Glyph glyph;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: GlyphIcon(glyph, size: 13, color: style.color),
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// A host pill: new ones outlined in blue, listed ones grey, excluded ones
/// struck through.
class MitmHostPill extends StatelessWidget {
  const MitmHostPill({
    super.key,
    required this.host,
    this.listed = false,
    this.change,
  });

  final String host;
  final bool listed;

  /// True for added, false for removed, in an update.
  final bool? change;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final excluded = host.startsWith('-');
    final (fill, border, ink) = switch (change) {
      true => (_addedColor(context), null, _dark(context) ? null : _addedInk),
      false => (_removedColor(context), null, mitmRewriteErrorColor(context)),
      null when excluded => (
        _dark(context) ? colorScheme.surfaceContainerHighest : _excludedFill,
        null,
        _dark(context) ? colorScheme.onSurfaceVariant : _excludedInk,
      ),
      null when listed => (
        colorScheme.surfaceContainerHighest,
        null,
        colorScheme.onSurfaceVariant,
      ),
      null => (null, colorScheme.primary, colorScheme.onSurface),
    };
    final style = AppTextStyle.caption1
        .of(context)
        .toJetBrainsMono
        .copyWith(
          color: ink,
          decoration: excluded ? TextDecoration.lineThrough : null,
        );
    final prefix = switch (change) {
      true => '+ ',
      false => '− ',
      null => '',
    };
    return Semantics(
      label: '$host, ${listed ? l.mitmAlreadyListed : l.mitmNewHost}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: ShapeDecoration(
          color: fill,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(999),
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$prefix${excluded ? host.substring(1) : host}'),
              if (listed && change == null)
                TextSpan(
                  text: ' · ${l.mitmAlreadyListed}',
                  style: AppTextStyle.caption2.of(context),
                ),
            ],
          ),
          style: style,
        ),
      ),
    );
  }
}

/// The decrypted hostnames, the user's and the enabled modules'.
List<String> mitmDecryptedHosts(WidgetRef ref) => [
  ...ref.watch(patchClashConfigProvider.select((s) => s.mitm.hostname)),
  ...?ref.watch(enabledMitmModuleRulesProvider).value?.hostname,
];

/// Appends [hosts] to the user's hostname list; the Core takes it with the
/// next setup.
void addMitmHostnames(WidgetRef ref, Iterable<String> hosts) {
  final added = hosts.toList();
  if (added.isEmpty) return;
  ref
      .read(patchClashConfigProvider.notifier)
      .update(
        (state) => state.copyWith(
          mitm: state.mitm.copyWith(
            hostname: [
              ...state.mitm.hostname,
              for (final host in added)
                if (!state.mitm.hostname.contains(host)) host,
            ],
          ),
        ),
      );
}

/// Adds scripts in two steps, pasted lines then a confirm; returns those
/// stored, once the Core runs them.
Future<List<MitmScript>?> showMitmScriptAddDialog(
  BuildContext context, {
  required int profileId,
  String? initialText,
}) {
  return dialogs.showCommonDialog<List<MitmScript>>(
    context: context,
    dismissible: false,
    child: _ScriptAddDialog(profileId: profileId, initialText: initialText),
  );
}

class _ScriptAddDialog extends ConsumerStatefulWidget {
  const _ScriptAddDialog({required this.profileId, this.initialText});

  final int profileId;
  final String? initialText;

  @override
  ConsumerState<_ScriptAddDialog> createState() => _ScriptAddDialogState();
}

class _ScriptAddDialogState extends ConsumerState<_ScriptAddDialog> {
  late final _controller = TextEditingController(
    text: widget.initialText ?? '',
  );
  final _pattern = TextEditingController();
  Timer? _timer;
  MitmScriptPaste _paste = const MitmScriptPaste([], {});
  MitmScriptKind _kind = MitmScriptKind.response;
  bool _requiresBody = true;
  bool _confirming = false;
  bool _alsoDecrypt = true;
  bool _busy = false;
  String? _error;

  /// A local file's name and bytes, set by From File….
  ({String name, List<int> bytes})? _file;

  @override
  void initState() {
    super.initState();
    if (widget.initialText == null) {
      unawaited(_prefill());
    } else {
      _check();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _pattern.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    if (_controller.text.isNotEmpty) return;
    if (parseMitmScriptPaste(text).drafts.isEmpty) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    _check();
  }

  void _onChanged(String _) {
    _timer?.cancel();
    _timer = Timer(_validateDelay, _check);
  }

  void _check() {
    final paste = parseMitmScriptPaste(_controller.text);
    if (!mounted) return;
    setState(() {
      _file = null;
      _paste = paste;
      if (paste.isBareUrl) {
        _pattern.text = paste.drafts.single.info.pattern;
        _kind = MitmScriptKind.response;
        _requiresBody = true;
      }
    });
  }

  Future<void> _pickFile() async {
    final file = await globalState.safeRun(picker.pickerFile);
    if (file == null || !mounted) return;
    final bytes = await file.readBytes();
    if (!mounted) return;
    final draft = mitmBareScriptDraft(file.name);
    setState(() {
      _controller.clear();
      _file = (name: file.name, bytes: bytes);
      _paste = MitmScriptPaste([draft], const {});
      _pattern.text = draft.info.pattern;
    });
  }

  bool get _bare => _file != null || _paste.isBareUrl;

  List<MitmScriptDraft> get _drafts {
    if (!_bare) return _paste.drafts;
    final path = _file?.name ?? _paste.drafts.single.info.path;
    return [
      mitmBareScriptDraft(
        path,
        kind: _kind,
        pattern: _pattern.text.trim(),
        requiresBody: _requiresBody,
      ),
    ];
  }

  bool get _patternValid {
    if (!_bare) return true;
    final pattern = _pattern.text.trim();
    if (pattern.isEmpty) return false;
    try {
      RegExp(pattern);
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<void> _add(
    List<MitmScriptDraft> drafts,
    List<String> uncovered,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = _file;
      final scripts = await prepareMitmScripts(
        ref.read,
        drafts,
        local: {if (file != null) file.name: file.bytes},
      );
      final current =
          ref.read(profileMitmScriptsProvider(widget.profileId)).value ??
          const <MitmScript>[];
      if (_alsoDecrypt) addMitmHostnames(ref, uncovered);
      await commitMitmScripts(ref.read, widget.profileId, [
        ...current,
        ...scripts,
      ]);
      if (mounted) Navigator.of(context).pop(scripts);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = mitmScriptFailureText(context.appLocalizations, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _confirming ? _buildConfirm(context) : _buildPaste(context);
  }

  Widget _buildPaste(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final caption = AppTextStyle.footnote.of(context);
    final drafts = _drafts;
    final requests = drafts
        .where((d) => d.info.kind == MitmScriptKind.request)
        .length;
    final status = <Widget>[
      if (drafts.isNotEmpty && _patternValid)
        MitmMarkedLine(
          l.mitmScriptPasteOk(
            drafts.length,
            requests,
            drafts.length - requests,
          ),
          glyph: AppGlyphs.check,
          style: caption.copyWith(
            color: _dark(context) ? const Color(0xFF7DD99A) : _addedInk,
          ),
        ),
      for (final MapEntry(key: line, value: error) in _paste.errors.entries)
        MitmMarkedLine(
          l.mitmScriptPasteLineError(line, mitmScriptPasteErrorText(l, error)),
          glyph: AppGlyphs.close,
          style: caption.copyWith(color: mitmRewriteErrorColor(context)),
        ),
    ];
    final label = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    return RuleEditFrame(
      title: l.mitmAddScript,
      subtitle: l.mitmAddScriptHint,
      width: _dialogWidth,
      primaryLabel: l.mitmContinue,
      onPrimary: drafts.isEmpty || !_patternValid
          ? null
          : () => setState(() => _confirming = true),
      leading: TextButton(onPressed: _pickFile, child: Text(l.mitmAddFromFile)),
      children: [
        if (_file case final file?)
          Text(
            l.mitmScriptLocalSource(file.name),
            style: AppTextStyle.footnote.of(context).toJetBrainsMono,
          )
        else
          MitmLineEditor(
            controller: _controller,
            autofocus: true,
            semanticLabel: l.mitmAddScript,
            errorLines: _paste.errors.keys.toSet(),
            onChanged: _onChanged,
          ),
        if (status.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: status,
            ),
          ),
        if (_bare) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(l.mitmScriptType, style: label),
              SegmentedControl<MitmScriptKind>(
                segments: [
                  for (final kind in MitmScriptKind.values)
                    (kind, mitmScriptKindLabel(l, kind)),
                ],
                value: _kind,
                onChanged: (kind) => setState(() {
                  _kind = kind;
                  _requiresBody = kind == MitmScriptKind.response;
                }),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(l.mitmScriptPattern, style: label),
              TextField(
                controller: _pattern,
                autocorrect: false,
                style: AppTextStyle.footnote.of(context).toJetBrainsMono,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text(l.mitmScriptNeedsBody)),
              Switch(
                value: _requiresBody,
                semanticLabel: l.mitmScriptNeedsBody,
                onChanged: (value) => setState(() => _requiresBody = value),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildConfirm(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final drafts = _drafts;
    final listed = mitmDecryptedHosts(ref);
    final uncovered = mitmUncoveredHosts([
      for (final draft in drafts) ?draft.info.host,
    ], listed);
    final secondary = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    return RuleEditFrame(
      title: l.mitmScriptConfirmTitle,
      subtitle: l.mitmScriptCount(drafts.length),
      width: _dialogWidth,
      error: _error,
      busy: _busy,
      primaryLabel: _busy ? l.mitmScriptDownloading : l.mitmAddAndEnable,
      onPrimary: () => _add(drafts, uncovered),
      leading: TextButton(
        onPressed: _busy ? null : () => setState(() => _confirming = false),
        child: Text(l.back),
      ),
      children: [
        _Bounded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              for (final draft in drafts)
                MitmScriptSummary(
                  info: draft.info,
                  source: draft.isRemote
                      ? Uri.tryParse(draft.info.path)?.host
                      : null,
                  notDecrypted:
                      draft.info.host != null &&
                      uncovered.contains(draft.info.host!.toLowerCase()),
                ),
              const MitmScriptCapabilities(),
              if (uncovered.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        SizedBox.square(
                          dimension: 24,
                          child: OverflowBox(
                            maxWidth: 48,
                            maxHeight: 48,
                            child: Checkbox(
                              value: _alsoDecrypt,
                              onChanged: (value) =>
                                  setState(() => _alsoDecrypt = value ?? false),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            uncovered.length == 1
                                ? l.mitmAlsoDecryptHost(uncovered.single)
                                : l.mitmAlsoDecryptHosts,
                            style: AppTextStyle.footnote.of(context),
                          ),
                        ),
                      ],
                    ),
                    if (uncovered.length > 1)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            for (final host in uncovered)
                              Text(host, style: secondary.toJetBrainsMono),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Keeps a long confirm inside 60% of the window, scrolling past that.
class _Bounded extends StatelessWidget {
  const _Bounded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.max(200, height * 0.6)),
      child: SingleChildScrollView(child: child),
    );
  }
}

/// One script in a confirm: name, type, pattern and where it comes from.
class MitmScriptSummary extends StatelessWidget {
  const MitmScriptSummary({
    super.key,
    required this.info,
    this.source,
    this.notDecrypted = false,
  });

  final MitmScriptInfo info;
  final String? source;
  final bool notDecrypted;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final secondary = AppTextStyle.caption1
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    final host = info.host;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Row(
          spacing: 6,
          children: [
            GlyphIcon(
              AppGlyphs.code,
              size: 14,
              color: mitmScriptColor(context),
            ),
            Flexible(
              child: Text(
                info.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.footnote.of(context, emphasized: true),
              ),
            ),
            Text(
              [mitmScriptKindLabel(l, info.kind), ?source].join(' · '),
              style: secondary,
            ),
          ],
        ),
        Text(
          info.pattern,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: secondary.toJetBrainsMono,
        ),
        if (notDecrypted && host != null)
          Text(
            l.mitmHostNotDecrypted(host),
            style: secondary.copyWith(color: mitmAmberColor(context)),
          ),
      ],
    );
  }
}

/// Changes one script's settings; its code is not edited here. True once
/// saved, false once deleted.
Future<bool?> showMitmScriptEditDialog(
  BuildContext context, {
  required MitmScript script,
  required Future<void> Function(String line) onSave,
  required Future<void> Function() onDelete,
}) {
  return dialogs.showCommonDialog<bool>(
    context: context,
    dismissible: false,
    child: _ScriptEditDialog(
      script: script,
      onSave: onSave,
      onDelete: onDelete,
    ),
  );
}

class _ScriptEditDialog extends StatefulWidget {
  const _ScriptEditDialog({
    required this.script,
    required this.onSave,
    required this.onDelete,
  });

  final MitmScript script;
  final Future<void> Function(String line) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_ScriptEditDialog> createState() => _ScriptEditDialogState();
}

class _ScriptEditDialogState extends State<_ScriptEditDialog> {
  late final MitmScriptInfo _info = parseMitmScriptInfo(widget.script.line)!;
  late final _name = TextEditingController(text: _info.name);
  late final _pattern = TextEditingController(text: _info.pattern);
  late MitmScriptKind _kind = _info.kind;
  late bool _requiresBody = _info.requiresBody;
  late int _timeout = _info.timeout;
  bool _busy = false;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _pattern.dispose();
    super.dispose();
  }

  bool get _patternValid {
    final pattern = _pattern.text.trim();
    if (pattern.isEmpty) return false;
    try {
      RegExp(pattern);
      return true;
    } on FormatException {
      return false;
    }
  }

  String get _line => MitmScriptInfo(
    name: _name.text.trim().isEmpty ? _info.name : _name.text.trim(),
    kind: _kind,
    pattern: _pattern.text.trim(),
    path: _info.path,
    params: {
      ..._info.params,
      'requires-body': _requiresBody ? '1' : '0',
      'timeout': '$_timeout',
    },
  ).lineWith(widget.script.file);

  Future<void> _run(Future<void> Function() action, bool result) async {
    setState(() {
      _busy = true;
      _deleting = !result;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _deleting = false;
        _error = mitmScriptFailureText(context.appLocalizations, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final label = AppTextStyle.caption1
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    Widget field(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(title, style: label),
        child,
      ],
    );
    final script = widget.script;
    return RuleEditFrame(
      title: l.edit,
      subtitle: '${mitmScriptKindLabel(l, _info.kind)} · ${_info.name}',
      width: _dialogWidth,
      error: _error,
      busy: _busy,
      deleting: _deleting,
      primaryLabel: l.save,
      onPrimary: _patternValid && _line != script.line
          ? () => _run(() => widget.onSave(_line), true)
          : null,
      onDelete: () => _run(widget.onDelete, false),
      children: [
        field(
          l.name,
          TextField(controller: _name, onChanged: (_) => setState(() {})),
        ),
        field(
          l.mitmScriptType,
          SegmentedControl<MitmScriptKind>(
            segments: [
              for (final kind in MitmScriptKind.values)
                (kind, mitmScriptKindLabel(l, kind)),
            ],
            value: _kind,
            onChanged: (kind) => setState(() => _kind = kind),
          ),
        ),
        field(
          l.mitmScriptPattern,
          TextField(
            controller: _pattern,
            autocorrect: false,
            style: AppTextStyle.footnote.of(context).toJetBrainsMono,
            onChanged: (_) => setState(() {}),
          ),
        ),
        Row(
          children: [
            Expanded(child: Text(l.mitmScriptNeedsBody)),
            Switch(
              value: _requiresBody,
              semanticLabel: l.mitmScriptNeedsBody,
              onChanged: (value) => setState(() => _requiresBody = value),
            ),
          ],
        ),
        field(
          l.mitmScriptTimeout,
          SegmentedControl<int>(
            segments: [
              for (final s in const [1, 3, 5, 10]) (s, '$s s'),
            ],
            value: const [1, 3, 5, 10].contains(_timeout) ? _timeout : 10,
            onChanged: (value) => setState(() => _timeout = value),
          ),
        ),
        Text(
          script.url ?? l.mitmScriptLocalSource(script.source),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: label.toJetBrainsMono,
        ),
      ],
    );
  }
}

/// A unified diff: added lines green, removed red, long unchanged runs
/// folded.
class MitmDiffView extends StatelessWidget {
  const MitmDiffView({super.key, required this.lines});

  final List<MitmDiffLine> lines;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final style = AppTextStyle.custom(
      context,
      size: 12,
      leading: 18,
    ).toJetBrainsMono;
    final counts = mitmDiffCounts(lines);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: l.mitmDiffAdded(counts.added),
                style: TextStyle(
                  color: _dark(context) ? const Color(0xFF7DD99A) : _addedInk,
                ),
              ),
              const TextSpan(text: '  '),
              TextSpan(
                text: l.mitmDiffRemoved(counts.removed),
                style: TextStyle(color: mitmRewriteErrorColor(context)),
              ),
            ],
          ),
          style: AppTextStyle.caption1.of(context).toJetBrainsMono,
        ),
        Container(
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in lines.take(2000))
                Container(
                  color: switch (line.kind) {
                    MitmDiffKind.added => _addedColor(context),
                    MitmDiffKind.removed => _removedColor(context),
                    _ => null,
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    switch (line.kind) {
                      MitmDiffKind.added => '+ ${line.text}',
                      MitmDiffKind.removed => '− ${line.text}',
                      MitmDiffKind.same => '  ${line.text}',
                      MitmDiffKind.folded => l.mitmDiffFolded(line.count),
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: line.kind == MitmDiffKind.folded
                        ? style.copyWith(color: colorScheme.onSurfaceVariant)
                        : style,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What a module update changes, part by part, before the line diff.
class MitmModuleChangeSummary extends StatelessWidget {
  const MitmModuleChangeSummary({super.key, required this.change});

  final MitmModuleChange change;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final label = AppTextStyle.footnote.of(context, emphasized: true);
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    String counts(int added, int removed) => added == 0 && removed == 0
        ? l.mitmNoChange
        : [if (added > 0) '+$added', if (removed > 0) '−$removed'].join(' ');
    final rewrites = change.rewritesAfter - change.rewritesBefore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${l.mitmChangeHosts}  ', style: label),
              TextSpan(
                text: counts(
                  change.addedHosts.length,
                  change.removedHosts.length,
                ),
              ),
            ],
          ),
          style: secondary,
        ),
        if (change.addedHosts.isNotEmpty || change.removedHosts.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final host in change.addedHosts)
                MitmHostPill(host: host, change: true),
              for (final host in change.removedHosts)
                MitmHostPill(host: host, change: false),
            ],
          ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${l.mitmChangeScripts}  ', style: label),
              TextSpan(
                text: counts(
                  change.addedScripts.length,
                  change.removedScripts.length,
                ),
              ),
            ],
          ),
          style: secondary,
        ),
        for (final script in change.addedScripts)
          Text('+ $script', style: secondary.toJetBrainsMono),
        for (final script in change.removedScripts)
          Text('− $script', style: secondary.toJetBrainsMono),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${l.mitmChangeRewrites}  ', style: label),
              TextSpan(
                text: rewrites == 0
                    ? l.mitmNoChange
                    : rewrites > 0
                    ? '+$rewrites'
                    : '−${-rewrites}',
              ),
            ],
          ),
          style: secondary,
        ),
        if (change.bringsAccess) const MitmScriptCapabilities(),
      ],
    );
  }
}

/// Shows an update next to what runs; [onAdopt] runs the new one, and the
/// dialog closes, true, once it is done. Not now leaves it waiting.
Future<bool?> showMitmUpdateDialog(
  BuildContext context, {
  required String name,
  required String subtitle,
  required String before,
  required String after,
  required Future<void> Function() onAdopt,
  Widget? summary,
}) {
  return dialogs.showCommonDialog<bool>(
    context: context,
    dismissible: false,
    child: _UpdateDialog(
      name: name,
      subtitle: subtitle,
      before: before,
      after: after,
      onAdopt: onAdopt,
      summary: summary,
    ),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.name,
    required this.subtitle,
    required this.before,
    required this.after,
    required this.onAdopt,
    this.summary,
  });

  final String name;
  final String subtitle;
  final String before;
  final String after;
  final Future<void> Function() onAdopt;
  final Widget? summary;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  late final _diff = mitmLineDiff(widget.before, widget.after);
  bool _busy = false;
  String? _error;

  Future<void> _adopt() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAdopt();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = mitmScriptFailureText(context.appLocalizations, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final summary = widget.summary;
    return RuleEditFrame(
      title: l.mitmUpdateTitle(widget.name),
      subtitle: widget.subtitle,
      width: _diffWidth,
      error: _error,
      busy: _busy,
      primaryLabel: l.mitmAdoptUpdate,
      onPrimary: _adopt,
      leading: TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: Text(l.mitmNotNow),
      ),
      children: [
        _Bounded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(
                l.mitmPendingKept,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
              ?summary,
              MitmDiffView(lines: _diff),
            ],
          ),
        ),
      ],
    );
  }
}
