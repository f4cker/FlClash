import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/features/mitm/script_actions.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/mitm/script_dialogs.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart' show RuleEditFrame;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _shownHosts = 12;

String mitmSkipReasonText(AppLocalizations l, MitmModuleSkip skip) =>
    switch (skip.reason) {
      MitmModuleSkipReason.section => l.mitmSkipSection(skip.section),
      MitmModuleSkipReason.setting => l.mitmSkipSetting,
      MitmModuleSkipReason.scriptType => l.mitmSkipScriptType,
      MitmModuleSkipReason.event => l.mitmSkipEvent,
      MitmModuleSkipReason.disabled => l.mitmSkipDisabled,
      MitmModuleSkipReason.rule => l.mitmSkipRule,
      MitmModuleSkipReason.policy => l.mitmSkipPolicy,
      MitmModuleSkipReason.jq => l.mitmSkipJq,
      MitmModuleSkipReason.jsonBody => l.mitmSkipJsonBody,
      MitmModuleSkipReason.rawHeader => l.mitmSkipRawHeader,
      MitmModuleSkipReason.conditional => l.mitmSkipConditional,
      MitmModuleSkipReason.relativeData => l.mitmSkipRelativeData,
      MitmModuleSkipReason.notDownloaded => l.mitmSkipNotDownloaded,
      MitmModuleSkipReason.unreadable => l.mitmSkipUnreadable,
    };

/// Shows what a module brings before anything is saved; [onImport] saves
/// it, on or off, and the dialog closes with that choice once it is done.
Future<bool?> showMitmModuleConfirmDialog(
  BuildContext context, {
  required MitmModuleContent content,
  required String name,
  required String source,
  required Future<void> Function(bool enable) onImport,
}) {
  return dialogs.showCommonDialog<bool>(
    context: context,
    dismissible: false,
    child: _ModuleConfirmDialog(
      content: content,
      name: name,
      source: source,
      onImport: onImport,
    ),
  );
}

class _ModuleConfirmDialog extends ConsumerStatefulWidget {
  const _ModuleConfirmDialog({
    required this.content,
    required this.name,
    required this.source,
    required this.onImport,
  });

  final MitmModuleContent content;
  final String name;
  final String source;
  final Future<void> Function(bool enable) onImport;

  @override
  ConsumerState<_ModuleConfirmDialog> createState() =>
      __ModuleConfirmDialogState();
}

class __ModuleConfirmDialogState extends ConsumerState<_ModuleConfirmDialog> {
  bool _allHosts = false;
  bool _rewriteLines = false;
  bool _skipped = false;
  bool? _busy;
  String? _error;

  Future<void> _import(bool enable) async {
    setState(() {
      _busy = enable;
      _error = null;
    });
    try {
      await widget.onImport(enable);
      if (mounted) Navigator.of(context).pop(enable);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = mitmScriptFailureText(context.appLocalizations, error);
      });
    }
  }

  Widget _title(BuildContext context, String text, int count) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: text),
        TextSpan(
          text: '  $count',
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      ],
    ),
    style: AppTextStyle.footnote.of(context, emphasized: true),
  );

  Widget _more(String label, VoidCallback onPressed) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton(onPressed: onPressed, child: Text(label)),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final content = widget.content;
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final mono = secondary.toJetBrainsMono;
    final listed = mitmDecryptedHosts(ref);
    final hosts = [...content.insertedHostname, ...content.hostname];
    final excluded = hosts.where((host) => host.startsWith('-')).length;
    final uncovered = mitmUncoveredHosts([
      for (final host in hosts)
        if (!host.startsWith('-')) host,
    ], listed).toSet();
    final shownHosts = _allHosts ? hosts : hosts.take(_shownHosts).toList();
    final rewrites = <MitmRewriteGroup, List<String>>{};
    for (final (list, lines) in [
      (MitmList.urlRewrite, content.urlRewrite),
      (MitmList.headerRewrite, content.headerRewrite),
      (MitmList.bodyRewrite, content.bodyRewrite),
      (MitmList.mapLocal, content.mapLocal),
    ]) {
      for (final line in lines) {
        rewrites
            .putIfAbsent(mitmRewriteGroupOf(list, line), () => [])
            .add(line);
      }
    }
    final rewriteCount = rewrites.values.fold(0, (a, b) => a + b.length);
    final scripts = mitmModuleScripts(content);
    final description = content.description ?? '';
    final busy = _busy != null;
    final sections = <Widget>[
      if (description.isNotEmpty)
        Text(
          description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: secondary,
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          _title(context, l.mitmChangeHosts, hosts.length - excluded),
          Text(
            hosts.isEmpty ? l.mitmModuleNoHosts : l.mitmModuleHostsHint,
            style: secondary,
          ),
          if (hosts.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final host in shownHosts)
                  MitmHostPill(
                    host: host,
                    listed:
                        !host.startsWith('-') &&
                        !uncovered.contains(host.toLowerCase()),
                  ),
              ],
            ),
          if (excluded > 0)
            Text(l.mitmExcludedCount(excluded), style: secondary),
          if (!_allHosts && hosts.length > _shownHosts)
            _more(
              l.mitmMoreHosts(hosts.length - _shownHosts),
              () => setState(() => _allHosts = true),
            ),
        ],
      ),
      if (rewriteCount > 0)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            _title(context, l.mitmModuleRewrites, rewriteCount),
            for (final MapEntry(key: group, value: lines) in rewrites.entries)
              Text('${group.label(l)} ${lines.length}', style: secondary),
            if (_rewriteLines)
              for (final lines in rewrites.values)
                for (final line in lines)
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono,
                  )
            else
              _more(l.more, () => setState(() => _rewriteLines = true)),
          ],
        ),
      if (scripts.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            _title(context, l.mitmChangeScripts, scripts.length),
            for (final info in scripts)
              MitmScriptSummary(
                info: info,
                source: Uri.tryParse(info.path)?.host,
              ),
            MitmScriptCapabilities(body: l.mitmScriptConfirmBody),
          ],
        ),
      if (content.rules.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            _title(context, l.mitmModuleRoutingRules, content.rules.length),
            Text(
              l.mitmModuleRoutingRulesNote(content.rules.length),
              style: secondary,
            ),
          ],
        ),
      if (content.skipped.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            _title(context, l.mitmModuleUnsupported, content.skipped.length),
            Text(
              l.mitmModuleUnsupportedCount(content.skipped.length),
              style: secondary,
            ),
            if (_skipped)
              for (final skip in content.skipped)
                Text(
                  '${skip.line}\n  ${mitmSkipReasonText(l, skip)}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: mono,
                )
            else
              _more(l.more, () => setState(() => _skipped = true)),
          ],
        ),
    ];
    final height = MediaQuery.sizeOf(context).height;
    return RuleEditFrame(
      title: l.mitmModuleConfirmTitle,
      subtitle: '${widget.name} · ${widget.source}',
      width: 560,
      error: _error,
      busy: busy,
      primaryLabel: l.mitmImportAndEnable,
      onPrimary: () => _import(true),
      leading: TextButton(
        onPressed: busy ? null : () => _import(false),
        child: Text(l.mitmImportOnly),
      ),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (height * 0.8 - 160).clamp(200, 2000),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: sections,
            ),
          ),
        ),
      ],
    );
  }
}
