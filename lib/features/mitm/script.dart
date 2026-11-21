import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/mitm_modules.dart' show MitmModulesView;
import 'package:fl_clash/views/config/mitm_status.dart' show openMitmSettings;
import 'package:fl_clash/views/profiles/mount.dart'
    show MountBanner, MountBannerLevel;
import 'package:fl_clash/views/rules/rule_rows.dart'
    show RuleRowAction, RuleRowHover;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rewrite.dart' show mitmRewriteErrorColor, mitmRewriteErrorInk;
import 'script_actions.dart';
import 'script_dialogs.dart';

const _flashFill = Color(0x1A007AFF);
const _flashDuration = Duration(milliseconds: 1500);
const _tagFillLight = Color(0xFFF2F1F5);

/// The row on the decryption page that opens [MitmScriptView].
class MitmScriptEntryItem extends ConsumerWidget {
  const MitmScriptEntryItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final profileId = ref.watch(currentProfileIdProvider);
    final scripts = profileId == null
        ? const <MitmScript>[]
        : ref.watch(profileMitmScriptsProvider(profileId)).value ??
              const <MitmScript>[];
    return ListItem.open(
      leading: const GlyphIcon(AppGlyphs.code),
      title: Text(l.mitmScripts),
      subtitle: MitmCountLine(
        text: scripts.isEmpty
            ? l.mitmRewriteNoneAdded
            : l.mitmScriptCount(scripts.length),
        updates: scripts.where((s) => s.hasPending).length,
        errors: scripts.where((s) => s.unloadable).length,
      ),
      widget: const MitmScriptView(),
    );
  }
}

/// [text] with the amber updates and red errors counts after it.
class MitmCountLine extends StatelessWidget {
  const MitmCountLine({
    super.key,
    required this.text,
    this.updates = 0,
    this.errors = 0,
  });

  final String text;
  final int updates;
  final int errors;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (updates > 0)
            TextSpan(
              text: ' · ${l.mitmUpdateCount(updates)}',
              style: TextStyle(color: mitmAmberColor(context)),
            ),
          if (errors > 0)
            TextSpan(
              text: ' · ${l.mitmScriptInvalidCount(errors)}',
              style: TextStyle(color: mitmRewriteErrorColor(context)),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.footnote
          .of(context)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
  }
}

/// A script line with its path back at its source, as a Surge config has it.
String mitmScriptSourceLine(MitmScript script) {
  final info = parseMitmScriptInfo(script.line);
  return info?.lineWith(script.url ?? script.source) ?? script.line;
}

/// The current profile's own scripts, request then response; those from
/// modules stay in the modules page.
class MitmScriptView extends ConsumerStatefulWidget {
  const MitmScriptView({super.key, this.revealScript});

  final int? revealScript;

  static const addKey = ValueKey('mitm-script-add');

  @override
  ConsumerState<MitmScriptView> createState() => _MitmScriptViewState();
}

class _MitmScriptViewState extends ConsumerState<MitmScriptView> {
  String _query = '';
  final _pending = <int>{};
  final _flashing = <int>{};
  final _rowKeys = <int, GlobalKey>{};
  MitmShownError? _error;
  Timer? _flashTimer;
  bool _revealed = false;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _flash(Iterable<int> ids) {
    _flashTimer?.cancel();
    setState(() {
      _flashing
        ..clear()
        ..addAll(ids);
    });
    if (ids.isNotEmpty) {
      runAfterFrame(() {
        final rowContext = _rowKeys[ids.first]?.currentContext;
        if (rowContext != null && rowContext.mounted) {
          Scrollable.ensureVisible(rowContext, alignment: 0.3);
        }
      });
    }
    _flashTimer = Timer(_flashDuration, () {
      if (mounted) setState(_flashing.clear);
    });
  }

  List<MitmScript> _scripts(int profileId) =>
      ref.read(profileMitmScriptsProvider(profileId)).value ?? const [];

  Future<void> _busy(Iterable<int> ids, Future<void> Function() action) async {
    final set = ids.toSet();
    setState(() => _pending.addAll(set));
    try {
      await action();
      if (mounted && _error != null) setState(() => _error = null);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = mitmScriptFailure(context.appLocalizations, error);
        });
      }
    } finally {
      if (mounted) setState(() => _pending.removeAll(set));
    }
  }

  Future<void> _commit(
    int profileId,
    Iterable<int> ids,
    List<MitmScript> next,
  ) => _busy(ids, () => commitMitmScripts(ref.read, profileId, next));

  Future<void> _setEnabled(int profileId, Set<int> ids, bool value) =>
      _commit(profileId, ids, [
        for (final item in _scripts(profileId))
          ids.contains(item.id) ? item.copyWith(enabled: value) : item,
      ]);

  Future<void> _delete(int profileId, Set<int> ids) => _commit(profileId, ids, [
    for (final item in _scripts(profileId))
      if (!ids.contains(item.id)) item,
  ]);

  Future<void> _confirmDelete(int profileId, Set<int> ids, String what) async {
    final l = context.appLocalizations;
    final res = await dialogs.showMessage(
      context: context,
      title: l.ruleDeleteTitle,
      message: TextSpan(text: what),
      destructive: true,
      confirmText: l.delete,
    );
    if (res == true) await _delete(profileId, ids);
  }

  Future<void> _check(int profileId, Iterable<MitmScript> scripts) async {
    for (final script in scripts) {
      if (!script.isRemote || !mounted) continue;
      await _busy([
        script.id,
      ], () => checkMitmScriptUpdate(ref.read, profileId, script));
    }
  }

  Future<void> _viewUpdate(int profileId, MitmScript script) async {
    final pending = script.pendingFile;
    if (pending == null) return;
    final info = parseMitmScriptInfo(script.line);
    final String before;
    final String after;
    try {
      before = await readMitmScript(script.file);
      after = await readMitmScript(pending);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = mitmScriptFailure(context.appLocalizations, error);
        });
      }
      return;
    }
    if (!mounted) return;
    final l = context.appLocalizations;
    await showMitmUpdateDialog(
      context,
      name: info?.name ?? script.source,
      subtitle: switch (script.checkedAt) {
        final checked? => l.mitmScriptFoundUpdate(
          checked.getLastUpdateTimeDesc(context),
        ),
        null => l.mitmViewUpdate,
      },
      before: before,
      after: after,
      onAdopt: () => adoptMitmScript(ref.read, profileId, script),
    );
  }

  Future<void> _add(int profileId) async {
    final added = await showMitmScriptAddDialog(context, profileId: profileId);
    if (added == null || added.isEmpty || !mounted) return;
    dialogs.showBanner(
      context.appLocalizations.mitmScriptsAdded(added.length),
      level: BannerLevel.success,
    );
    _flash(added.map((s) => s.id));
  }

  Future<void> _edit(int profileId, MitmScript script) async {
    if (parseMitmScriptInfo(script.line) == null) return;
    await showMitmScriptEditDialog(
      context,
      script: script,
      onSave: (line) => commitMitmScripts(ref.read, profileId, [
        for (final item in _scripts(profileId))
          item.id == script.id ? item.copyWith(line: line) : item,
      ]),
      onDelete: () => commitMitmScripts(ref.read, profileId, [
        for (final item in _scripts(profileId))
          if (item.id != script.id) item,
      ]),
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) dialogs.showBanner(context.appLocalizations.copySuccess);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final profileId = ref.watch(currentProfileIdProvider);
    final profileLabel = ref.watch(
      currentProfileProvider.select((profile) => profile?.realLabel ?? ''),
    );
    final value = profileId == null
        ? null
        : ref.watch(profileMitmScriptsProvider(profileId));
    final scripts = value?.value ?? const <MitmScript>[];
    final invalid = {
      for (final script in scripts)
        if (script.unloadable) script.id,
    };
    final updates = scripts.where((s) => s.hasPending).length;
    final enabled = scripts.where((s) => s.enabled).length;
    if (!_revealed && widget.revealScript != null && scripts.isNotEmpty) {
      _revealed = true;
      runAfterFrame(() {
        if (mounted) _flash([widget.revealScript!]);
      });
    }
    return Scaffold(
      title: l.mitmScripts,
      searchState: scripts.isEmpty
          ? null
          : AppBarSearchState(
              onSearch: (query) => setState(() => _query = query),
            ),
      actions: [
        if (profileId != null && scripts.isNotEmpty)
          FilledButton(
            key: MitmScriptView.addKey,
            onPressed: () => _add(profileId),
            child: Text(l.mitmAddScript),
          ),
      ],
      menuItems: profileId == null || scripts.isEmpty
          ? const []
          : [
              PopupMenuItem(
                label: l.mitmRewriteEnableAll,
                onPressed: () => _setEnabled(profileId, {
                  for (final s in scripts) s.id,
                }, true),
              ),
              PopupMenuItem(
                label: l.mitmRewriteDisableAll,
                onPressed: () => _setEnabled(profileId, {
                  for (final s in scripts) s.id,
                }, false),
              ),
              PopupMenuItem(
                glyph: AppGlyphs.sync,
                label: l.mitmCheckAllUpdates,
                onPressed: () => _check(profileId, scripts),
              ),
              PopupMenuItem(
                glyph: AppGlyphs.copy,
                label: l.mitmScriptCopyAll,
                onPressed: () => _copy(
                  ['[Script]', ...scripts.map(mitmScriptSourceLine)].join('\n'),
                ),
              ),
              PopupMenuItem(
                glyph: AppGlyphs.delete,
                label: l.mitmScriptDeleteInvalid,
                danger: true,
                section: const PopupMenuSection(),
                onPressed: invalid.isEmpty
                    ? null
                    : () => _confirmDelete(
                        profileId,
                        invalid,
                        l.mitmScriptDeleteInvalidConfirm(invalid.length),
                      ),
              ),
            ],
      body: Builder(
        builder: (context) => _buildBody(
          context,
          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
            top: context.contentTopPadding,
            bottom: 16 + context.bottomInset,
          ),
          profileId: profileId,
          loading: value != null && value.isLoading && !value.hasValue,
          scripts: scripts,
          subtitle: MitmCountLine(
            text: l.mitmScriptSubtitle(profileLabel, scripts.length, enabled),
            updates: updates,
            errors: invalid.length,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required EdgeInsets padding,
    required Widget subtitle,
    required int? profileId,
    required bool loading,
    required List<MitmScript> scripts,
  }) {
    final l = context.appLocalizations;
    final decrypting = ref.watch(
      patchClashConfigProvider.select((state) => state.mitm.enable),
    );
    final fromModules =
        ref.watch(enabledMitmModuleRulesProvider).value?.script.length ?? 0;
    final hosts = mitmDecryptedHosts(ref);
    final banners = [
      if (_error case final error?)
        MountBanner(
          level: MountBannerLevel.error,
          lines: [error.text],
          raw: error.raw,
        ),
      if (!decrypting)
        MountBanner(
          level: MountBannerLevel.info,
          lines: [l.mitmScriptsOff],
          actionLabel: l.mitmRewriteGoTurnOn,
          onAction: () async {
            if (!await Navigator.of(context).maybePop() && context.mounted) {
              await openMitmSettings(context);
            }
          },
        ),
    ];
    final modulesRow = fromModules == 0
        ? null
        : generateSection(
            items: [
              ListItem.open(
                title: Text(
                  l.mitmScriptsFromModules(fromModules),
                  style: TextStyle(color: context.colorScheme.onSurfaceVariant),
                ),
                widget: const MitmModulesView(),
              ),
            ],
          );
    if (profileId == null || scripts.isEmpty) {
      return Column(
        children: [
          if (banners.isNotEmpty)
            Padding(
              padding: padding.copyWith(bottom: 0),
              child: Column(spacing: 8, children: banners),
            ),
          Expanded(
            child: NullStatusSwitcher(
              animate: false,
              isLoading: loading,
              isEmpty: true,
              nullStatus: NullStatus(
                label: l.mitmScriptsEmptyTitle,
                description: l.mitmScriptsEmptyBody,
                illustration: NullStatusIllustration.scripts,
                animate: false,
                descriptionMinLines: 2,
                anchorToHeading: true,
                action: profileId == null
                    ? null
                    : FilledButton(
                        onPressed: () => _add(profileId),
                        child: Text(l.mitmAddScript),
                      ),
              ),
              child: const SizedBox.shrink(),
            ),
          ),
          if (modulesRow != null)
            Padding(padding: const EdgeInsets.all(16), child: modulesRow),
        ],
      );
    }
    final query = _query.trim().toLowerCase();
    final described = [
      for (final script in scripts)
        if (parseMitmScriptInfo(script.line) case final info?)
          (script: script, info: info),
    ];
    final shown = [
      for (final item in described)
        if (query.isEmpty ||
            item.info.name.toLowerCase().contains(query) ||
            item.info.pattern.toLowerCase().contains(query) ||
            (item.script.url ?? item.script.source).toLowerCase().contains(
              query,
            ))
          item,
    ];
    final sections = <Widget>[];
    for (final kind in MitmScriptKind.values) {
      final members = [
        for (final item in shown)
          if (item.info.kind == kind) item,
      ];
      if (members.isEmpty) continue;
      sections.add(
        Column(
          children: [
            ListHeader(
              title: kind == MitmScriptKind.request
                  ? l.mitmScriptGroupRequest
                  : l.mitmScriptGroupResponse,
              trailing: Text(
                '${members.length}',
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ),
            generateGroup([
              for (final item in members)
                MitmScriptRow(
                  key: _rowKeys.putIfAbsent(item.script.id, GlobalKey.new),
                  script: item.script,
                  info: item.info,
                  pending: _pending.contains(item.script.id),
                  flashing: _flashing.contains(item.script.id),
                  notDecrypted:
                      item.info.host != null &&
                      mitmUncoveredHosts([item.info.host!], hosts).isNotEmpty,
                  onToggle: (value) =>
                      _setEnabled(profileId, {item.script.id}, value),
                  onEdit: () => _edit(profileId, item.script),
                  onDelete: () => _confirmDelete(profileId, {
                    item.script.id,
                  }, l.ruleDeleteBody(item.info.name)),
                  onCopy: () => _copy(mitmScriptSourceLine(item.script)),
                  onCheck: item.script.isRemote
                      ? () => _check(profileId, [item.script])
                      : null,
                  onViewUpdate: () => _viewUpdate(profileId, item.script),
                  onDecrypt: () => addMitmHostnames(ref, [item.info.host!]),
                ),
            ]),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: subtitle),
          if (banners.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(spacing: 8, children: banners),
            ),
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: NullStatus(
                label: UiLocalizations.of(context).noSearchResults,
                illustration: Illustration.search,
              ),
            ),
          ...sections,
          ?modulesRow,
        ],
      ),
    );
  }
}

class MitmScriptRow extends StatelessWidget {
  const MitmScriptRow({
    super.key,
    required this.script,
    required this.info,
    required this.pending,
    required this.flashing,
    required this.notDecrypted,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onCheck,
    required this.onViewUpdate,
    required this.onDecrypt,
  });

  final MitmScript script;
  final MitmScriptInfo info;
  final bool pending;
  final bool flashing;
  final bool notDecrypted;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback? onCheck;
  final VoidCallback onViewUpdate;
  final VoidCallback onDecrypt;

  String _source(BuildContext context) {
    final l = context.appLocalizations;
    final url = script.url;
    if (url == null) return l.mitmScriptLocalSource(script.source);
    final uri = Uri.tryParse(url);
    final file = uri?.pathSegments.lastOrNull ?? url;
    final where = uri == null
        ? url
        : uri.pathSegments.length > 1
        ? '${uri.host}/…/$file'
        : '${uri.host}/$file';
    final checked = script.checkedAt;
    return checked == null
        ? where
        : l.mitmScriptRemoteSource(
            where,
            checked.getLastUpdateTimeDesc(context),
          );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final error = switch (script.error) {
      final error? => mitmStoredError(l, error),
      null => null,
    };
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final amber = TextStyle(color: mitmAmberColor(context));
    final kind = info.kind == MitmScriptKind.request
        ? l.mitmScriptGroupRequest
        : l.mitmScriptGroupResponse;
    final toggleLabel = [
      info.name,
      kind,
      info.pattern,
      if (script.hasPending) l.mitmHasUpdate,
    ].join(l.localeName.startsWith('zh') ? '，' : ', ');
    final unloadable = script.unloadable;
    final Widget third;
    if (error != null) {
      // The Core's own words stay out of the line: on hover only.
      third = Tooltip(
        message: error.raw ?? error.text,
        hoverDelay: const Duration(milliseconds: 500),
        child: MitmMarkedLine(
          unloadable
              // The sentence ends the reason: its own stop goes.
              ? l.mitmScriptLoadFailed(
                  error.text.replaceFirst(RegExp(r'[.。．]$'), ''),
                )
              : mitmKeptFailureText(l, script.failure),
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(
                color: unloadable
                    ? mitmRewriteErrorColor(context)
                    : mitmAmberColor(context),
              ),
        ),
      );
    } else if (notDecrypted) {
      third = Text(
        l.mitmScriptHostNotDecrypted,
        style: AppTextStyle.footnote.of(context).merge(amber),
      );
    } else {
      third = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: _source(context)),
            if (script.hasPending)
              TextSpan(text: ' · ${l.mitmScriptHasUpdate}', style: amber),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: secondary,
      );
    }
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 3,
      children: [
        Row(
          spacing: 6,
          children: [
            Flexible(
              child: Text(
                info.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.subheadline.of(context, emphasized: true),
              ),
            ),
            if (info.requiresBody)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: ShapeDecoration(
                  color: dark
                      ? colorScheme.surfaceContainerHighest
                      : _tagFillLight,
                  shape: AppShape.full,
                ),
                child: Text(
                  l.mitmScriptNeedsBody,
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        Tooltip(
          message: info.pattern,
          hoverDelay: const Duration(milliseconds: 500),
          excludeFromSemantics: true,
          child: Text(
            info.pattern,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: secondary.toJetBrainsMono,
          ),
        ),
        third,
      ],
    );
    final Widget? action = switch (true) {
      _ when error != null && onCheck != null => MitmLinkButton(
        label: l.retry,
        onPressed: onCheck,
      ),
      _ when script.hasPending => MitmLinkButton(
        label: l.mitmViewUpdate,
        onPressed: onViewUpdate,
      ),
      _ when notDecrypted => MitmLinkButton(
        label: l.mitmAddToDecryption,
        onPressed: onDecrypt,
      ),
      _ => null,
    };
    final toggle = pending
        ? SizedBox(
            width: Switch.trackWidth,
            child: Center(
              child: ActivityIndicator(
                size: 16,
                color: colorScheme.primary,
                semanticLabel: toggleLabel,
              ),
            ),
          )
        : unloadable
        ? Opacity(
            opacity: 0.4,
            child: Switch(
              value: false,
              semanticLabel: toggleLabel,
              onChanged: null,
            ),
          )
        : Switch(
            value: script.enabled,
            semanticLabel: toggleLabel,
            onChanged: onToggle,
          );
    final menuItems = [
      PopupMenuItem(
        glyph: AppGlyphs.edit,
        label: l.ruleEditMenu,
        onPressed: onEdit,
      ),
      if (onCheck case final check?)
        PopupMenuItem(
          glyph: AppGlyphs.sync,
          label: l.mitmCheckUpdate,
          onPressed: check,
        ),
      PopupMenuItem(
        glyph: AppGlyphs.copy,
        label: l.mitmCopyLine,
        onPressed: onCopy,
      ),
      PopupMenuItem(
        glyph: AppGlyphs.delete,
        label: l.delete,
        danger: true,
        section: const PopupMenuSection(),
        onPressed: onDelete,
      ),
    ];
    final desktop = system.isDesktop;
    Widget row(bool hovered) => DecorationListItem(
      onPressed: desktop ? null : onEdit,
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          ?action,
          if (hovered && desktop) ...[
            RuleRowAction(
              glyph: AppGlyphs.edit,
              color: const Color(0xFF3F3E45),
              label: l.edit,
              onPressed: onEdit,
            ),
            RuleRowAction(
              glyph: AppGlyphs.delete,
              color: mitmRewriteErrorInk,
              label: l.delete,
              onPressed: onDelete,
            ),
          ],
          toggle,
        ],
      ),
    );
    return RuleRowHover(
      builder: (context, hovered) => ContextMenuRegion(
        menuItems: menuItems,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: desktop ? onEdit : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            foregroundDecoration: ShapeDecoration(
              color: flashing ? _flashFill : const Color(0x00007AFF),
              shape: AppShape.of(
                listItemRadiusOf(ItemPositionProvider.of(context)?.position),
              ),
            ),
            child: row(hovered),
          ),
        ),
      ),
    );
  }
}
