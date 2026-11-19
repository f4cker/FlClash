import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/features/mitm/script_actions.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/mitm/script_dialogs.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart' show RuleEditFrame;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _shownHosts = 12;
const _shownRules = 5;
const _footerRule = Color(0xFFE3E1E6);

String mitmSkipReasonText(AppLocalizations l, MitmModuleSkip skip) =>
    switch (skip.reason) {
      MitmModuleSkipReason.section => l.mitmSkipSection(skip.section),
      MitmModuleSkipReason.setting => l.mitmSkipSetting,
      MitmModuleSkipReason.scriptType => l.mitmSkipScriptType,
      MitmModuleSkipReason.event => l.mitmSkipEvent,
      MitmModuleSkipReason.disabled => l.mitmSkipDisabled,
      MitmModuleSkipReason.rule => l.mitmSkipRule,
      MitmModuleSkipReason.httpRulePolicy => l.mitmSkipHttpRulePolicy,
      MitmModuleSkipReason.finalRule => l.mitmSkipFinalRule,
      MitmModuleSkipReason.deviceRule => l.mitmSkipDeviceRule,
      MitmModuleSkipReason.requirement => l.mitmSkipRequirement,
      MitmModuleSkipReason.managedCa => l.mitmSkipManagedCa,
      MitmModuleSkipReason.proxies => l.mitmSkipProxies,
      MitmModuleSkipReason.appOnly => l.mitmSkipAppOnly,
      MitmModuleSkipReason.reflect => l.mitmSkipReflect,
      MitmModuleSkipReason.conditional => l.mitmSkipConditional,
      MitmModuleSkipReason.skipVerifyAll => l.mitmSkipSkipVerifyAll,
      MitmModuleSkipReason.relativeData => l.mitmSkipRelativeData,
      MitmModuleSkipReason.notDownloaded => l.mitmSkipNotDownloaded,
      MitmModuleSkipReason.unreadable => l.mitmSkipUnreadable,
    };

/// Null before a profile has been applied.
Set<String>? mitmCurrentPolicies(WidgetRef ref) {
  final settings = ref.watch(profileSettingsProvider);
  final groups = ref.watch(groupsProvider);
  if (settings == null && groups.isEmpty) return null;
  return {
    ...mitmConfigPolicies(settings ?? const {}),
    for (final group in groups) group.name,
  };
}

class _MitmRoutingRuleLine extends StatelessWidget {
  const _MitmRoutingRuleLine({required this.rule, this.policies});

  final String rule;
  final Set<String>? policies;

  @override
  Widget build(BuildContext context) {
    final policies = this.policies;
    final missing = policies != null && !mitmRuleUsable(rule, policies);
    final color = missing
        ? mitmAmberColor(context)
        : context.colorScheme.onSurfaceVariant;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: rule),
          if (missing)
            TextSpan(
              text:
                  '  ${context.appLocalizations.mitmRulePolicyMissing(mitmRulePolicy(rule))}',
              style: AppTextStyle.caption1.of(context).copyWith(color: color),
            ),
        ],
      ),
      style: AppTextStyle.custom(
        context,
        size: 12,
        leading: 18,
      ).toJetBrainsMono.copyWith(color: color),
    );
  }
}

/// Shows what a module brings before anything is saved; [onImport] saves
/// it, on or off and with its routing rules on or off, and the dialog closes
/// with that choice once it is done.
Future<bool?> showMitmModuleConfirmDialog(
  BuildContext context, {
  required MitmModuleContent content,
  required String name,
  required String source,
  required Future<void> Function(bool enable, bool rules) onImport,
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
  final Future<void> Function(bool enable, bool rules) onImport;

  @override
  ConsumerState<_ModuleConfirmDialog> createState() =>
      __ModuleConfirmDialogState();
}

class __ModuleConfirmDialogState extends ConsumerState<_ModuleConfirmDialog> {
  bool _allHosts = false;
  bool _rewriteLines = false;
  bool _skipped = false;
  bool _rules = true;
  bool _allRules = false;
  bool? _busy;
  String? _error;

  Future<void> _import(bool enable) async {
    setState(() {
      _busy = enable;
      _error = null;
    });
    try {
      await widget.onImport(enable, _rules);
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
    child: MitmLinkButton(label: label, onPressed: onPressed),
  );

  /// [line] with Show More after it, 8 apart, until [shown].
  Widget _withMore(Widget line, bool shown, VoidCallback onPressed) => shown
      ? line
      : Row(
          spacing: 8,
          children: [
            Flexible(child: line),
            MitmLinkButton(
              label: context.appLocalizations.showMore,
              onPressed: onPressed,
            ),
          ],
        );

  bool _overflows = false;

  bool _onMetrics(ScrollMetricsNotification notification) {
    final overflows = notification.metrics.maxScrollExtent > 0;
    if (overflows != _overflows) setState(() => _overflows = overflows);
    return false;
  }

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
    // The Core's word on each line as well, once it answers.
    final hostIssues = ref
        .watch(mitmModuleHostIssuesProvider(hosts.join('\n')))
        .value;
    final ignoredHosts = flashUnusableHostnames(content);
    final skippedHosts = [
      for (final host in hosts)
        if (hostIssues?.containsKey(host) == true &&
            !ignoredHosts.contains(host))
          host,
    ];
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
          if (ignoredHosts.isNotEmpty)
            Text(
              l.mitmModuleHostsIgnored(ignoredHosts.join(', ')),
              style: secondary.copyWith(color: mitmAmberColor(context)),
            ),
          if (skippedHosts.isNotEmpty)
            Text(
              l.mitmModuleHostsSkipped(skippedHosts.join(', ')),
              style: secondary.copyWith(color: mitmAmberColor(context)),
            ),
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
            for (final (index, MapEntry(key: group, value: lines))
                in rewrites.entries.indexed)
              index == rewrites.length - 1
                  ? _withMore(
                      Text(
                        '${group.label(l)} ${lines.length}',
                        style: secondary,
                      ),
                      _rewriteLines,
                      () => setState(() => _rewriteLines = true),
                    )
                  : Text('${group.label(l)} ${lines.length}', style: secondary),
            if (_rewriteLines)
              for (final lines in rewrites.values)
                for (final line in lines)
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono,
                  ),
          ],
        ),
      if (content.rules.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Row(
              children: [
                Expanded(
                  child: _title(
                    context,
                    l.mitmModuleRoutingRules,
                    content.rules.length,
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: FittedBox(
                    child: Switch(
                      value: _rules,
                      semanticLabel: l.mitmModuleRoutingRules,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _rules = value),
                    ),
                  ),
                ),
              ],
            ),
            Text(l.mitmModuleRulesDesc, style: secondary),
            for (final rule
                in _allRules ? content.rules : content.rules.take(_shownRules))
              _MitmRoutingRuleLine(
                rule: rule,
                policies: mitmCurrentPolicies(ref),
              ),
            if (!_allRules && content.rules.length > _shownRules)
              _more(l.showMore, () => setState(() => _allRules = true)),
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
      if (flashMitmSkipped(content).isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            _title(
              context,
              l.mitmModuleUnsupported,
              flashMitmSkipped(content).length,
            ),
            _withMore(
              Text(
                l.mitmModuleUnsupportedCount(flashMitmSkipped(content).length),
                style: secondary,
              ),
              _skipped,
              () => setState(() => _skipped = true),
            ),
            if (_skipped)
              for (final skip in flashMitmSkipped(content))
                Text(
                  '${skip.line}\n  ${mitmSkipReasonText(l, skip)}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: mono,
                ),
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
        onPressed: busy ? () {} : () => _import(false),
        child: Text(l.mitmImportOnly),
      ),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (height * 0.8 - 160).clamp(200, 2000),
          ),
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetrics,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: sections,
              ),
            ),
          ),
        ),
        if (_overflows)
          Container(
            height: 1,
            color: context.colorScheme.brightness == Brightness.dark
                ? colorScheme.outlineVariant
                : _footerRule,
          ),
      ],
    );
  }
}
