import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/features/mitm/rewrite.dart' show mitmRewriteErrorColor;
import 'package:fl_clash/features/mitm/script.dart';
import 'package:fl_clash/features/mitm/script_dialogs.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/mitm_modules.dart' show MitmModuleView;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mitm_rewrite_hits.dart'
    show MitmRewriteHitsSection, mitmRewriteTookText;

const mitmScriptKind = 'script';
const _shownLogLines = 6;
const _logFillLight = Color(0xFFF6F5F8);

bool mitmScriptFailed(MitmAction hit) => hit.skipped.isNotEmpty;

/// The result line of one script run, in the app's words.
String mitmScriptResultText(AppLocalizations l, MitmAction hit) =>
    switch (hit.skipped) {
      '' => l.mitmScriptDone(mitmRewriteTookText(hit) ?? ''),
      'scriptTimeout' => l.mitmScriptTimedOut,
      'scriptError' => l.mitmScriptFailed(hit.error),
      'scriptNoDone' => l.mitmScriptFailed(l.mitmScriptNoDone),
      'scriptMemory' => l.mitmScriptNotRun(l.mitmScriptMemory),
      'scriptBusy' => l.mitmScriptNotRun(l.mitmScriptBusy),
      final other => l.mitmScriptNotRun(mitmRewriteSkipText(l, other)),
    };

/// The scripts that ran on one request, in the order they ran.
class MitmScriptHitsSection extends ConsumerWidget {
  const MitmScriptHitsSection({super.key, required this.exchange});

  final MitmExchange exchange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final hits = [
      for (final hit in exchange.actions)
        if (hit.kind == mitmScriptKind) hit,
    ];
    final failed = hits.where(mitmScriptFailed).length;
    final settled = !exchange.pending;
    final warn = failed > 0 && settled;
    final color = warn ? mitmAmberColor(context) : mitmScriptColor(context);
    final header = ListItem(
      leading: GlyphIcon(
        warn ? AppGlyphs.warning : AppGlyphs.code,
        size: 18,
        color: color,
      ),
      title: Text(
        warn ? l.mitmScriptsPassed(failed) : l.mitmScriptsRan(hits.length),
        style: AppTextStyle.body
            .of(context, emphasized: true)
            .copyWith(color: warn ? color : null),
      ),
    );
    return generateSection(
      title: l.mitmScripts,
      items: [
        header,
        for (final hit in hits) _MitmScriptHitRow(hit: hit),
      ],
    );
  }
}

class _MitmScriptHitRow extends ConsumerStatefulWidget {
  const _MitmScriptHitRow({required this.hit});

  final MitmAction hit;

  @override
  ConsumerState<_MitmScriptHitRow> createState() => _MitmScriptHitRowState();
}

class _MitmScriptHitRowState extends ConsumerState<_MitmScriptHitRow> {
  bool _allLogs = false;
  bool _requests = false;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final hit = widget.hit;
    final footnote = AppTextStyle.footnote.of(context);
    final secondary = footnote.copyWith(color: colorScheme.onSurfaceVariant);
    final rule = hit.rule;
    final profileId = ref.watch(currentProfileIdProvider);
    final own = rule.startsWith('s') && profileId != null
        ? (ref.watch(profileMitmScriptsProvider(profileId)).value ?? const [])
              .firstWhereOrNull((script) => 's${script.id}' == rule)
        : null;
    final moduleId = rule.startsWith('m')
        ? int.tryParse(rule.substring(1).split('.').first)
        : null;
    final module = moduleId == null
        ? null
        : ref
              .watch(mitmModulesProvider)
              .value
              ?.firstWhereOrNull((item) => item.id == moduleId);
    final failed = mitmScriptFailed(hit);
    final logs = hit.logs;
    final shownLogs = _allLogs ? logs : logs.take(_shownLogLines).toList();
    final mono = AppTextStyle.custom(
      context,
      size: 11.5,
      leading: 16,
    ).toJetBrainsMono;
    VoidCallback? reveal;
    String? revealLabel;
    if (own != null) {
      revealLabel = l.mitmViewInScripts;
      reveal = () =>
          BaseNavigator.push(context, MitmScriptView(revealScript: own.id));
    } else if (module != null) {
      revealLabel = l.mitmViewInModule;
      reveal = () => BaseNavigator.push(context, MitmModuleView(id: module.id));
    }
    return ListItem(
      alignment: ListRowAlignment.top,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MitmRewriteHitsSection.typeWidth,
            child: Text(
              hit.phase == 'response'
                  ? l.mitmScriptGroupResponse
                  : l.mitmScriptGroupRequest,
              style: secondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: hit.detail,
                        style: AppTextStyle.footnote.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                      if (module != null)
                        TextSpan(
                          text: '  ${l.mitmFromModule(module.name)}',
                          style: AppTextStyle.caption2
                              .of(context)
                              .copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mitmScriptResultText(l, hit),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: failed
                            ? footnote.copyWith(color: mitmAmberColor(context))
                            : secondary,
                      ),
                    ),
                    if (reveal != null)
                      MitmLinkButton(label: revealLabel!, onPressed: reveal),
                  ],
                ),
                if (logs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                    decoration: ShapeDecoration(
                      color: colorScheme.brightness == Brightness.light
                          ? _logFillLight
                          : colorScheme.surfaceContainerHighest,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText.rich(
                                TextSpan(
                                  children: [
                                    for (final (index, log)
                                        in shownLogs.indexed)
                                      TextSpan(
                                        text:
                                            '${index > 0 ? '\n' : ''}${log.text}',
                                        style: TextStyle(
                                          color: switch (log.level) {
                                            'error' => mitmRewriteErrorColor(
                                              context,
                                            ),
                                            'warn' => mitmAmberColor(context),
                                            _ => null,
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                                style: mono,
                              ),
                              if (!_allLogs && logs.length > _shownLogLines)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: MitmLinkButton(
                                    label: l.mitmScriptLogExpand(logs.length),
                                    onPressed: () =>
                                        setState(() => _allLogs = true),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l.copy,
                          onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text: logs.map((log) => log.text).join('\n'),
                            ),
                          ),
                          icon: const GlyphIcon(AppGlyphs.copy, size: 14),
                        ),
                      ],
                    ),
                  ),
                ],
                if (hit.requests.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MitmLinkButton(
                      label: l.mitmScriptRequestsSent(hit.requests.length),
                      glyph: _requests
                          ? AppGlyphs.chevronDown
                          : AppGlyphs.chevronForward,
                      color: colorScheme.onSurfaceVariant,
                      onPressed: () => setState(() => _requests = !_requests),
                    ),
                  ),
                ],
                if (_requests)
                  for (final request in hit.requests)
                    Text(
                      [
                        request.method,
                        request.url,
                        if (request.status > 0) '${request.status}',
                        if (request.error.isNotEmpty) request.error,
                      ].join(' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: mono.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
