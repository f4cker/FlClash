import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/features/mitm/script_actions.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/mitm/script_dialogs.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart' show RuleEditFrame;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _shownHosts = 12;
const _shownRules = 5;

/// How long the sheet waits on the Core's word on its rewrite lines.
const mitmModuleRewriteCheckTimeout = Duration(seconds: 10);

/// The issue kinds the Core gives a pattern its compiler rejects.
const _regexIssueKinds = {'urlRegex', 'headerRegex', 'bodyRegex', 'emptyRegex'};

/// Whether a rewrite line will load, as far as the sheet can say.
enum MitmRuleCheck { invalidRegex, unverified }

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

/// A rewrite line the Core rejects or could not check: the group and place
/// in the main line, the line itself and the Core's reason only when the
/// user opens the details.
class _MitmRuleHint extends StatelessWidget {
  const _MitmRuleHint({
    super.key,
    required this.label,
    required this.check,
    required this.detail,
  });

  final String label;
  final MitmRuleCheck check;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final color = mitmAmberColor(context);
    final style = AppTextStyle.footnote.of(context).copyWith(color: color);
    final text = switch (check) {
      MitmRuleCheck.invalidRegex => l.mitmRuleRegexInvalid,
      MitmRuleCheck.unverified => l.mitmRuleUnverified,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        // One node for a screen reader: which rule, then what is wrong.
        Semantics(
          container: true,
          label: '$label, $text',
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: GlyphIcon(AppGlyphs.warning, size: 13, color: color),
                  ),
                ),
                TextSpan(
                  text: label,
                  style: AppTextStyle.footnote
                      .of(context, emphasized: true)
                      .copyWith(color: color),
                ),
                const TextSpan(text: '  '),
                TextSpan(text: text),
              ],
            ),
            style: style,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 17),
          child: RawErrorDetails(
            raw: detail,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
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
  bool _allRuleHints = false;
  bool? _busy;
  MitmShownError? _error;

  /// The Core's word on the rewrite lines once it answers, or why it did
  /// not; neither while it is asked.
  Map<MitmList, Map<int, MitmRewriteIssue>>? _rewriteIssues;
  Object? _rewriteCheckError;

  List<(MitmList, List<String>)> get _rewriteLists => [
    (MitmList.urlRewrite, widget.content.urlRewrite),
    (MitmList.headerRewrite, widget.content.headerRewrite),
    (MitmList.bodyRewrite, widget.content.bodyRewrite),
    (MitmList.mapLocal, widget.content.mapLocal),
  ];

  @override
  void initState() {
    super.initState();
    _checkRewrites();
  }

  /// Each line as the module wrote it, so the Core's indexes are the
  /// sheet's; only a word on it, nothing about import changes.
  Future<void> _checkRewrites() async {
    final content = widget.content;
    final rules = MitmRules(
      urlRewrite: content.urlRewrite,
      headerRewrite: content.headerRewrite,
      bodyRewrite: content.bodyRewrite,
      mapLocal: content.mapLocal,
    );
    if (_rewriteLists.every((entry) => entry.$2.isEmpty)) return;
    try {
      final issues = await ref
          .read(mitmRewriteValidatorProvider)(rules)
          .timeout(mitmModuleRewriteCheckTimeout);
      if (mounted) setState(() => _rewriteIssues = issues);
    } catch (error) {
      if (mounted) setState(() => _rewriteCheckError = error);
    }
  }

  /// Every rewrite line the Core rejects as a pattern, or that it could not
  /// check, in the order the sheet lists them.
  List<Widget> _ruleHints(AppLocalizations l) {
    final issues = _rewriteIssues;
    final failed = _rewriteCheckError;
    if (issues == null && failed == null) return const [];
    final numbers = <MitmRewriteGroup, int>{};
    final hints = <Widget>[];
    for (final (list, lines) in _rewriteLists) {
      for (final (index, line) in lines.indexed) {
        final group = mitmRewriteGroupOf(list, line);
        final number = numbers[group] = (numbers[group] ?? 0) + 1;
        if (_isComment(line)) continue;
        final listIssues = issues?[list];
        final issue = listIssues?[index];
        final MitmRuleCheck check;
        final String detail;
        if (failed != null || listIssues == null) {
          check = MitmRuleCheck.unverified;
          detail = failed == null ? line : '$line\n$failed';
        } else if (issue != null && _regexIssueKinds.contains(issue.kind)) {
          check = MitmRuleCheck.invalidRegex;
          detail = '$line\n${issue.message}';
        } else {
          continue;
        }
        hints.add(
          _MitmRuleHint(
            key: ValueKey((list, index)),
            label: '${group.label(l)} #$number',
            check: check,
            detail: detail,
          ),
        );
      }
    }
    return hints;
  }

  static bool _isComment(String line) {
    final trimmed = line.trim();
    return trimmed.isEmpty ||
        trimmed.startsWith('#') ||
        trimmed.startsWith(';') ||
        trimmed.startsWith('//');
  }

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
        _error = mitmScriptFailure(context.appLocalizations, error);
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
    final ruleHints = _ruleHints(l);
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
            for (final hint
                in _allRuleHints ? ruleHints : ruleHints.take(_shownRules))
              hint,
            if (!_allRuleHints && ruleHints.length > _shownRules)
              _more(l.showMore, () => setState(() => _allRuleHints = true)),
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
    return RuleEditFrame(
      title: l.mitmModuleConfirmTitle,
      subtitle: '${widget.name} · ${widget.source}',
      width: 560,
      error: _error?.text,
      errorRaw: _error?.raw,
      busy: busy,
      primaryLabel: l.mitmImportAndEnable,
      onPrimary: () => _import(true),
      leading: TextButton(
        onPressed: busy ? () {} : () => _import(false),
        child: Text(l.mitmImportOnly),
      ),
      // No scroll view of its own: the frame scrolls the body under its
      // pinned actions, and one nested in it could hide its own end.
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: sections,
        ),
      ],
    );
  }
}
