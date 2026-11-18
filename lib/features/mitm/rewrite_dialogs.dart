import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/core/method.dart' show CoreMethodException;
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart' show RuleEditFrame;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rewrite.dart' show mitmRewriteErrorColor, mitmRewriteListSeparator;

/// What a failed save or check says: the app's own words for a failure it
/// knows, never an exception's or the Core's English, which goes to logs.
String mitmRewriteFailureText(AppLocalizations l, Object error) {
  final text = userFacingErrorMessage(error, l);
  final raw = error is CoreMethodException ? error.message : error.toString();
  return text == raw ? l.mitmRewriteFailureGeneric : text;
}

const _dialogWidth = 520.0;
const _validateDelay = Duration(milliseconds: 300);
const _okInk = Color(0xFF16632C);
const _okInkDark = Color(0xFF7DD99A);
const _errorLineFill = Color(0xFFFDECEA);
const _maxListedErrors = 5;
const _editorFontSize = 12.0;
const _editorLineHeight = 18.0;
const _editorPadding = 8.0;
const _gutterWidth = 30.0;

Color _okColor(BuildContext context) =>
    context.colorScheme.brightness == Brightness.dark ? _okInkDark : _okInk;

Color _errorLineColor(BuildContext context) =>
    context.colorScheme.brightness == Brightness.dark
    ? const Color(0x47B3261E)
    : _errorLineFill;

Color _editorFill(BuildContext context) {
  final colorScheme = context.colorScheme;
  return colorScheme.brightness == Brightness.light
      ? const Color(0xFFF9F9FB)
      : colorScheme.surfaceContainerHighest;
}

bool _isSectionLine(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('[') && trimmed.endsWith(']') ||
      trimmed.startsWith('#') ||
      trimmed.startsWith('//') ||
      trimmed.startsWith(';');
}

/// Greys section titles and comments, the lines that are not rules.
class _RewriteTextController extends TextEditingController {
  _RewriteTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final muted = TextStyle(color: context.colorScheme.onSurfaceVariant);
    final lines = text.split('\n');
    return TextSpan(
      style: style,
      children: [
        for (final (index, line) in lines.indexed)
          TextSpan(
            text: index < lines.length - 1 ? '$line\n' : line,
            style: _isSectionLine(line) ? muted : null,
          ),
      ],
    );
  }
}

/// A monospaced text area with line numbers whose lines in [errorLines]
/// are tinted; 7 to 16 lines tall, scrolling past that.
class MitmLineEditor extends StatelessWidget {
  final TextEditingController controller;
  final Set<int> errorLines;
  final bool autofocus;
  final String semanticLabel;
  final ValueChanged<String>? onChanged;

  const MitmLineEditor({
    super.key,
    required this.controller,
    required this.semanticLabel,
    this.errorLines = const {},
    this.autofocus = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    // Every line, gutter and field alike, is one fixed height so the
    // numbers and the error bands stay level with the text.
    final style = AppTextStyle.custom(
      context,
      size: _editorFontSize,
      leading: _editorLineHeight,
    ).toJetBrainsMono;
    final strut = StrutStyle.fromTextStyle(style, forceStrutHeight: true);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final lines = value.text.split('\n');
        final shown = lines.length.clamp(7, 16);
        final painter = TextPainter(
          text: TextSpan(
            text: lines.reduce((a, b) => a.length >= b.length ? a : b),
            style: style,
          ),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final longest = painter.width;
        painter.dispose();
        return Container(
          height: shown * _editorLineHeight + _editorPadding * 2,
          decoration: ShapeDecoration(
            color: _editorFill(context),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: _editorPadding),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      for (var i = 1; i <= lines.length; i++)
                        Container(
                          height: _editorLineHeight,
                          color: errorLines.contains(i)
                              ? _errorLineColor(context)
                              : null,
                        ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        width: _gutterWidth,
                        child: Column(
                          children: [
                            for (var i = 1; i <= lines.length; i++)
                              SizedBox(
                                height: _editorLineHeight,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      '$i',
                                      style: style.copyWith(
                                        color: errorLines.contains(i)
                                            ? mitmRewriteErrorColor(context)
                                            : colorScheme.onSurfaceVariant
                                                  .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: math.max(
                                  constraints.maxWidth,
                                  longest + 24,
                                ),
                                child: Semantics(
                                  label: semanticLabel,
                                  textField: true,
                                  child: TextField(
                                    controller: controller,
                                    autofocus: autofocus,
                                    autocorrect: false,
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    style: style,
                                    strutStyle: strut,
                                    decoration: _bareField,
                                    onChanged: onChanged,
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// [text] led by [glyph] in its color, as a status line under an editor.
Widget _markedLine(Glyph glyph, String text, TextStyle style) => Text.rich(
  TextSpan(
    children: [
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: GlyphIcon(glyph, size: 12, color: style.color),
        ),
      ),
      TextSpan(text: text),
    ],
  ),
  style: style,
);

/// A field in a frame of its own: the frame shows focus, so the field
/// draws no ring inside it (a collapsed one still takes the theme's).
const _bareField = InputDecoration(
  isCollapsed: true,
  filled: false,
  contentPadding: EdgeInsets.zero,
  border: NoInputBorder(),
  enabledBorder: NoInputBorder(),
  focusedBorder: NoInputBorder(),
  errorBorder: NoInputBorder(),
  disabledBorder: NoInputBorder(),
  focusedErrorBorder: NoInputBorder(),
);

typedef MitmRewriteImporter =
    Future<void> Function(List<MitmRewrite> added, bool atStart);

/// Asks for pasted rules and hands the importable ones to [onImport]; it
/// closes, with them, only once [onImport] is done.
Future<List<MitmRewrite>?> showMitmRewritePasteDialog(
  BuildContext context, {
  required List<MitmRewrite> existing,
  required MitmRewriteImporter onImport,
  String? initialText,
}) {
  return dialogs.showCommonDialog<List<MitmRewrite>>(
    context: context,
    dismissible: false,
    child: _RewritePasteDialog(
      existing: existing,
      onImport: onImport,
      initialText: initialText,
    ),
  );
}

class _RewritePasteDialog extends ConsumerStatefulWidget {
  final List<MitmRewrite> existing;
  final MitmRewriteImporter onImport;

  /// Set, the clipboard is left alone.
  final String? initialText;

  const _RewritePasteDialog({
    required this.existing,
    required this.onImport,
    this.initialText,
  });

  @override
  ConsumerState<_RewritePasteDialog> createState() =>
      _RewritePasteDialogState();
}

class _RewritePasteDialogState extends ConsumerState<_RewritePasteDialog> {
  late final _controller = _RewriteTextController(
    text: widget.initialText ?? '',
  );
  Timer? _timer;
  MitmRewriteParse? _parse;
  String _parsed = '';
  bool _atStart = false;
  bool _busy = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialText == null) {
      unawaited(_prefill());
    } else {
      unawaited(_check());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !mounted || _controller.text.isNotEmpty) return;
    final MitmRewriteParse parse;
    try {
      parse = await ref.read(coreHandlerProvider).parseMitmRewrite(text);
    } catch (_) {
      return;
    }
    if (!mounted || _controller.text.isNotEmpty || parse.rules.isEmpty) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    setState(() {
      _parse = parse;
      _parsed = text;
    });
  }

  void _onChanged(String _) {
    _timer?.cancel();
    _timer = Timer(_validateDelay, () => unawaited(_check()));
  }

  Future<void> _check() async {
    final text = _controller.text;
    final generation = ++_generation;
    if (text.trim().isEmpty) {
      setState(() {
        _parse = null;
        _parsed = text;
      });
      return;
    }
    try {
      final parse = await ref.read(coreHandlerProvider).parseMitmRewrite(text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _parse = parse;
        _parsed = text;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = context.appLocalizations.mitmRewriteNotApplied(
          mitmRewriteFailureText(context.appLocalizations, error),
        );
      });
    }
  }

  /// The rules to import and the line numbers of those already there.
  ({List<MitmRewriteLine> rules, List<int> duplicates}) _sorted() {
    final parse = _parse;
    if (parse == null) return (rules: const [], duplicates: const []);
    final seen = {
      for (final rewrite in widget.existing)
        (rewrite.section.key, rewrite.line.trim()),
    };
    final rules = <MitmRewriteLine>[];
    final duplicates = <int>[];
    for (final rule in parse.rules) {
      if (!seen.add((rule.section, rule.line.trim()))) {
        duplicates.add(rule.number);
        continue;
      }
      rules.add(rule);
    }
    return (rules: rules, duplicates: duplicates);
  }

  Future<void> _import(List<MitmRewriteLine> rules) async {
    final added = [
      for (final rule in rules)
        if (mitmListOfKey(rule.section) case final section?)
          MitmRewrite(id: snowflake.id, section: section, line: rule.line),
    ];
    if (added.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onImport(added, _atStart);
      if (mounted) Navigator.of(context).pop(added);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.appLocalizations.mitmRewriteNotApplied(
          mitmRewriteFailureText(context.appLocalizations, error),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final current = _parsed == _controller.text ? _parse : null;
    final sorted = _sorted();
    final issues = current?.issues ?? const <MitmRewriteIssue>[];
    final caption = AppTextStyle.footnote.of(context);
    final counts = <MitmRewriteGroup, int>{};
    for (final rule in sorted.rules) {
      final section = mitmListOfKey(rule.section);
      if (section == null) continue;
      final group = mitmRewriteGroupOf(section, rule.line);
      counts[group] = (counts[group] ?? 0) + 1;
    }
    final summary = [
      for (final group in MitmRewriteGroup.values)
        if (counts[group] case final count?)
          '${group.label(appLocalizations)} $count',
    ].join(mitmRewriteListSeparator(appLocalizations));
    final count = sorted.rules.length;
    final status = <Widget>[
      if (current != null && count > 0)
        _markedLine(
          AppGlyphs.check,
          appLocalizations.mitmRewriteImportReady(count, summary),
          caption.copyWith(color: _okColor(context)),
        ),
      for (final issue in issues.take(_maxListedErrors))
        Tooltip(
          message: issue.message,
          child: _markedLine(
            AppGlyphs.close,
            appLocalizations.mitmRewriteImportLineError(
              issue.line,
              mitmRewriteIssueText(appLocalizations, issue),
            ),
            caption.copyWith(color: mitmRewriteErrorColor(context)),
          ),
        ),
      if (issues.length > _maxListedErrors)
        Text(
          appLocalizations.mitmRewriteImportMoreErrors(
            issues.length - _maxListedErrors,
          ),
          style: caption.copyWith(color: mitmRewriteErrorColor(context)),
        ),
      for (final line in sorted.duplicates)
        Text(
          appLocalizations.mitmRewriteImportDuplicate(line),
          style: caption.copyWith(color: colorScheme.onSurfaceVariant),
        ),
    ];
    return RuleEditFrame(
      title: appLocalizations.mitmRewriteImportTitle,
      subtitle: appLocalizations.mitmRewriteImportDesc,
      width: _dialogWidth,
      error: _error,
      busy: _busy,
      primaryLabel: _busy
          ? appLocalizations.mitmRewriteImporting
          : appLocalizations.mitmRewriteImportButton(count),
      onPrimary: count == 0 || current == null
          ? null
          : () => _import(sorted.rules),
      children: [
        MitmLineEditor(
          controller: _controller,
          autofocus: true,
          semanticLabel: appLocalizations.mitmRewriteImportTitle,
          errorLines: {for (final issue in issues) issue.line},
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Text(
              appLocalizations.mitmRewritePlace,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
            SegmentedControl<bool>(
              segments: [
                (false, appLocalizations.mitmRewritePlaceEnd),
                (true, appLocalizations.mitmRewritePlaceStart),
              ],
              value: _atStart,
              onChanged: (value) => setState(() => _atStart = value),
            ),
          ],
        ),
      ],
    );
  }
}

/// Edits [rewrite]'s line; true once saved, false once deleted. It closes
/// only once [onSave] or [onDelete] is done.
Future<bool?> showMitmRewriteEditDialog(
  BuildContext context, {
  required MitmRewrite rewrite,
  required String subtitle,
  required Future<void> Function(String line) onSave,
  required Future<void> Function() onDelete,
}) {
  return dialogs.showCommonDialog<bool>(
    context: context,
    dismissible: false,
    child: _RewriteEditDialog(
      rewrite: rewrite,
      subtitle: subtitle,
      onSave: onSave,
      onDelete: onDelete,
    ),
  );
}

class _RewriteEditDialog extends ConsumerStatefulWidget {
  final MitmRewrite rewrite;
  final String subtitle;
  final Future<void> Function(String line) onSave;
  final Future<void> Function() onDelete;

  const _RewriteEditDialog({
    required this.rewrite,
    required this.subtitle,
    required this.onSave,
    required this.onDelete,
  });

  @override
  ConsumerState<_RewriteEditDialog> createState() => _RewriteEditDialogState();
}

const _emptyRule = MitmRewriteIssue(kind: 'emptyRule', message: 'empty rule');

class _RewriteEditDialogState extends ConsumerState<_RewriteEditDialog> {
  late final _controller = TextEditingController(text: widget.rewrite.line);
  Timer? _timer;
  MitmRewriteIssue? _issue;
  String? _checked;
  bool _details = false;
  bool _busy = false;
  bool _deleting = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _timer?.cancel();
    setState(() {});
    _timer = Timer(_validateDelay, () => unawaited(_check()));
  }

  Future<void> _check() async {
    final line = _controller.text.trim();
    final generation = ++_generation;
    if (line.isEmpty) {
      setState(() {
        _issue = _emptyRule;
        _checked = '';
      });
      return;
    }
    try {
      final parse = await ref
          .read(coreHandlerProvider)
          .parseMitmRewrite(
            '${mitmRewriteSectionTitle(widget.rewrite.section)}\n$line',
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        // A line the Core reads as neither a rule nor an issue is a comment:
        // saved alone, it is an empty rule.
        _issue = parse.rules.isNotEmpty
            ? null
            : parse.issues.firstOrNull ?? _emptyRule;
        _checked = line;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = context.appLocalizations.mitmRewriteNotApplied(
          mitmRewriteFailureText(context.appLocalizations, error),
        );
      });
    }
  }

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
        _error = context.appLocalizations.mitmRewriteNotApplied(
          mitmRewriteFailureText(context.appLocalizations, error),
        );
      });
    }
  }

  Future<void> _delete() async {
    final appLocalizations = context.appLocalizations;
    final res = await dialogs.showMessage(
      context: context,
      title: appLocalizations.ruleDeleteTitle,
      message: TextSpan(
        text: appLocalizations.ruleDeleteBody(widget.rewrite.line),
      ),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res == true && mounted) await _run(widget.onDelete, false);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final line = _controller.text.trim();
    final checked = _checked == line;
    final issue = checked ? _issue : null;
    final valid = checked && issue == null;
    final description = valid
        ? describeMitmRewrite(appLocalizations, widget.rewrite.section, line)
        : null;
    final error = issue != null;
    final rows = description == null
        ? null
        : [
            (
              appLocalizations.mitmRewritePreviewType,
              '${description.group.label(appLocalizations)} · ${description.action}',
            ),
            (appLocalizations.mitmRewritePreviewMatch, description.match),
            (appLocalizations.mitmRewritePreviewAction, description.detail),
          ];
    final label = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    return RuleEditFrame(
      title: appLocalizations.mitmRewriteEditTitle,
      subtitle: widget.subtitle,
      width: _dialogWidth,
      error: _error,
      busy: _busy,
      deleting: _deleting,
      primaryLabel: appLocalizations.save,
      onPrimary: valid && line != widget.rewrite.line
          ? () => _run(() => widget.onSave(line), true)
          : null,
      onDelete: _delete,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: ShapeDecoration(
                color: context.raisedSurfaceLevel.colorOf(colorScheme),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: error
                        ? mitmRewriteErrorColor(context)
                        : colorScheme.outlineVariant,
                    width: error ? 1.5 : 1,
                  ),
                ),
              ),
              child: Semantics(
                label: appLocalizations.mitmRewriteEditTitle,
                textField: true,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  autocorrect: false,
                  minLines: 2,
                  maxLines: 6,
                  style: AppTextStyle.footnote.of(context).toJetBrainsMono,
                  decoration: _bareField,
                  onChanged: _onChanged,
                ),
              ),
            ),
            if (issue != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  appLocalizations.mitmRewriteInvalid(
                    mitmRewriteIssueText(appLocalizations, issue),
                  ),
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: mitmRewriteErrorColor(context)),
                ),
              ),
            // The Core's own words, for a report: behind a tap, not in the
            // red line.
            if (issue != null && issue.kind != 'emptyRule')
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _details
                    ? SelectableText(
                        issue.message,
                        style: label.toJetBrainsMono,
                      )
                    : TextButton(
                        onPressed: () => setState(() => _details = true),
                        child: Text(
                          appLocalizations.mitmRewriteErrorDetails,
                          style: label.copyWith(color: colorScheme.primary),
                        ),
                      ),
              ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: ShapeDecoration(
            color: colorScheme.brightness == Brightness.light
                ? const Color(0xFFF6F5F8)
                : colorScheme.surfaceContainerHighest,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: rows == null
              ? Text(
                  checked || line.isEmpty
                      ? appLocalizations.mitmRewriteUnparsable
                      : '…',
                  style: label,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    for (final (title, value) in rows)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 72, child: Text(title, style: label)),
                          Expanded(
                            child: Text(
                              value,
                              style: AppTextStyle.footnote.of(context),
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
