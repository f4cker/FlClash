import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/features/mitm/rewrite.dart' show mitmRewriteErrorColor;
import 'package:fl_clash/features/mitm/script.dart' show MitmCountLine;
import 'package:fl_clash/features/mitm/script_dialogs.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' show join;

import 'mitm_module_confirm.dart';

MitmModule? _moduleOf(WidgetRef ref, int id) => ref.watch(
  mitmModulesProvider.select(
    (state) => state.value?.firstWhereOrNull((item) => item.id == id),
  ),
);

Future<void> _setEnabled(WidgetRef ref, MitmModule module, bool enabled) async {
  if (enabled) {
    await answerMitmModule(ref, module);
  } else {
    await ref.read(mitmModulesActionProvider.notifier).turnOff(module.id);
  }
}

/// Runs a cron, event or generic script line now; any other line, any while
/// decryption is off, and a task still running have none.
PopupMenuItem? mitmRunScriptItem(WidgetRef ref, String line) {
  final name = mitmTaskName(line);
  if (!mitmHttpScriptLines([line]).contains(line) ||
      name == null ||
      !ref.read(patchClashConfigProvider).mitm.enable ||
      ref.read(updatingKeysProvider).contains(_runKey(name))) {
    return null;
  }
  return PopupMenuItem(
    glyph: AppGlyphs.playPause(0),
    label: currentAppLocalizations.mitmRunScript,
    onPressed: () => _runScript(ref, name),
  );
}

String _runKey(String name) => 'mitm_script_$name';

class MitmTaskRunning extends ConsumerWidget {
  const MitmTaskRunning({super.key, required this.line, required this.builder});

  final String line;
  final Widget Function(bool running) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = mitmTaskName(line);
    return builder(
      name != null && ref.watch(isUpdatingProvider(_runKey(name))),
    );
  }
}

Future<void> _runScript(WidgetRef ref, String name) async {
  final updatingKeys = ref.read(updatingKeysProvider.notifier);
  final key = _runKey(name);
  final operation = updatingKeys.start(key, scope: UpdatingScope.core);
  final MitmScriptOutput? output;
  try {
    output = await globalState.safeRun(
      () => ref.read(coreHandlerProvider).runMitmScript(name),
      title: name,
      silence: false,
    );
  } finally {
    updatingKeys.stop(key, operation);
  }
  if (output == null) {
    return;
  }
  await dialogs.showAlert(
    title: name,
    message: TextSpan(text: _runOutput(output)),
  );
}

String _runOutput(MitmScriptOutput output) {
  final parts = [
    if (output.error.isNotEmpty) output.error,
    ?_resultText(output.result),
    ...output.logs,
  ];
  return parts.isEmpty
      ? currentAppLocalizations.mitmScriptNoOutput
      : parts.join('\n');
}

/// A panel script's title and content, or the value as the script gave it.
String? _resultText(String result) {
  if (result.isEmpty) {
    return null;
  }
  final Object? value;
  try {
    value = jsonDecode(result);
  } on FormatException {
    return result;
  }
  return switch (value) {
    null || '' => null,
    final String text => text,
    {'title': final Object title} => [
      title,
      if ((value as Map)['content'] case final Object content) content,
    ].join('\n'),
    final Map map when map.isEmpty => null,
    _ => result,
  };
}

Future<void> _updateModule(
  BuildContext context,
  WidgetRef ref,
  MitmModule module,
) async {
  final updated = await globalState.safeRun<MitmModule>(
    () => ref.read(mitmModulesActionProvider.notifier).updateModule(module),
    title: module.name,
    silence: false,
  );
  if (updated != null && updated.hasPending && context.mounted) {
    await _viewModuleUpdate(context, ref, updated);
  }
}

Future<void> _viewModuleUpdate(
  BuildContext context,
  WidgetRef ref,
  MitmModule module,
) async {
  final action = ref.read(mitmModulesActionProvider.notifier);
  final after = await action.pendingText(module);
  final path = join(await appPath.mitmModulesDirPath, module.fileName);
  final file = File(path);
  final before = await file.exists() ? await file.readAsString() : '';
  if (after == null || !context.mounted) return;
  final change = mitmModuleChange(
    previewMitmModule(before, values: module.arguments),
    previewMitmModule(after, values: module.arguments),
  );
  await showMitmUpdateDialog(
    context,
    name: module.name,
    subtitle: switch (module.pendingTime) {
      final found? => context.appLocalizations.mitmScriptFoundUpdate(
        found.getLastUpdateTimeDesc(context),
      ),
      null => context.appLocalizations.mitmViewUpdate,
    },
    before: before,
    after: after,
    summary: MitmModuleChangeSummary(change: change),
    onAdopt: () => action.adopt(module),
  );
}

/// Downloads or reads a module, shows what it brings, and saves it only
/// once the user confirms.
Future<void> _confirmImport(
  BuildContext context,
  String text, {
  required String name,
  required String source,
  required Future<void> Function(bool enable, bool rules) onImport,
}) async {
  final l = context.appLocalizations;
  final content = previewMitmModule(text);
  if (content.isEmpty) {
    dialogs.showBanner(l.mitmModuleInvalid, level: BannerLevel.error);
    return;
  }
  final res = await showMitmModuleConfirmDialog(
    context,
    content: content,
    name: content.name ?? name,
    source: source,
    onImport: onImport,
  );
  if (res != null) {
    dialogs.showBanner(l.mitmModuleImported, level: BannerLevel.success);
  }
}

class MitmModulesItem extends ConsumerWidget {
  const MitmModulesItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final modules =
        ref.watch(mitmModulesProvider).value ?? const <MitmModule>[];
    return ListItem.open(
      leading: const GlyphIcon(AppGlyphs.puzzle),
      title: Text(appLocalizations.mitmModules),
      subtitle: MitmCountLine(
        text: modules.isEmpty
            ? appLocalizations.mitmRewriteNoneAdded
            : appLocalizations.mitmModuleCount(
                modules.length,
                modules.where((m) => m.enabled).length,
              ),
        updates: modules.where((m) => m.hasPending).length,
        errors: modules.where((m) => m.unloadable).length,
      ),
      widget: const MitmModulesView(),
    );
  }
}

class MitmModulesView extends ConsumerWidget {
  const MitmModulesView({super.key});

  Future<void> _importFromUrl(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final input = await dialogs.showUrlInput(
      title: appLocalizations.importUrl,
      accepts: (value) => mitmModuleUrls(value).isNotEmpty,
    );
    if (input == null) {
      return;
    }
    final modules = ref.read(mitmModulesProvider).value ?? const [];
    final urls = mitmModuleUrls(
      input,
    ).where((url) => !modules.any((module) => module.url == url)).toSet();
    if (urls.isEmpty) {
      dialogs.showBanner(
        appLocalizations.existsTip(appLocalizations.mitmModule),
      );
      return;
    }
    final action = ref.read(mitmModulesActionProvider.notifier);
    for (final url in urls) {
      final text = await globalState.loadingRun(
        () => action.download(url),
        title: appLocalizations.importUrl,
        tag: LoadingTag.mitm,
      );
      if (text == null || !context.mounted) return;
      final uri = Uri.tryParse(url);
      await _confirmImport(
        context,
        text,
        name: uri?.pathSegments.lastOrNull ?? url,
        source: uri?.host ?? url,
        onImport: (enable, rules) => action.addFromUrl(
          url,
          enable: enable,
          rulesEnabled: rules,
          text: text,
        ),
      );
    }
  }

  Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final file = await globalState.safeRun(picker.pickerFile);
    if (file == null) {
      return;
    }
    final text = await globalState.safeRun(
      () async => utf8.decode(await file.readBytes()),
      title: appLocalizations.importFile,
    );
    if (text == null || !context.mounted) return;
    await _confirmImport(
      context,
      text,
      name: file.name,
      source: file.name,
      onImport: (enable, rules) => ref
          .read(mitmModulesActionProvider.notifier)
          .addFromFile(text, file.name, enable: enable, rulesEnabled: rules),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final state = ref.watch(mitmModulesProvider);
    final modules = state.value ?? const <MitmModule>[];
    return Scaffold(
      title: appLocalizations.mitmModules,
      canSort: modules.length > 1,
      isLoading: ref.watch(loadingProvider(LoadingTag.mitm)),
      actions: [
        PopupAnchor(
          targetBuilder: (open) => FilledButton(
            onPressed: open,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(appLocalizations.mitmImportModule),
                const GlyphIcon(AppGlyphs.chevronDown, size: 14, fill: 1),
              ],
            ),
          ),
          popupBuilder: (_) => PopupMenu(
            items: [
              PopupMenuItem(
                glyph: AppGlyphs.cloudDownload,
                label: appLocalizations.importUrl,
                onPressed: () => _importFromUrl(context, ref),
              ),
              PopupMenuItem(
                glyph: AppGlyphs.compose,
                label: appLocalizations.mitmNewModule,
                onPressed: () => openMitmModuleEditor(context, ref),
              ),
              PopupMenuItem(
                glyph: AppGlyphs.importFile,
                label: appLocalizations.importFile,
                onPressed: () => _importFromFile(context, ref),
              ),
            ],
          ),
        ),
      ],
      body: NullStatusSwitcher(
        animate: false,
        isLoading: state.isLoading && !state.hasValue,
        isEmpty: modules.isEmpty,
        nullStatus: NullStatus(
          illustration: NullStatusIllustration.modules,
          animate: false,
          descriptionMinLines: 2,
          anchorToHeading: true,
          label: appLocalizations.mitmModulesEmptyTitle,
          description: appLocalizations.mitmModulesEmptyBody,
          action: FilledButton(
            onPressed: () => _importFromUrl(context, ref),
            child: Text(appLocalizations.mitmImportModule),
          ),
        ),
        child: PrismReorderableListView(
          padding: context.listInsets
              .page(top: 16, bottom: 16)
              .copyWith(
                top: context.contentTopPadding,
                bottom: 16 + context.bottomInset,
              ),
          itemCount: modules.length,
          itemBuilder: (_, index) => _MitmModuleRow(
            key: ValueKey(modules[index].id),
            module: modules[index],
            index: index,
            total: modules.length,
          ),
          proxyDecorator: (_, index, animation) => commonProxyDecorator(
            _MitmModuleRow(
              module: modules[index],
              index: index,
              total: modules.length,
            ),
            index,
            animation,
          ),
          onReorderItem: ref.read(mitmModulesProvider.notifier).order,
        ),
      ),
    );
  }
}

class _MitmModuleRow extends ConsumerWidget {
  const _MitmModuleRow({
    super.key,
    required this.module,
    required this.index,
    required this.total,
  });

  final MitmModule module;
  final int index;
  final int total;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final res = await dialogs.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.mitmModule),
      ),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res != true) {
      return;
    }
    await ref.read(mitmModulesActionProvider.notifier).deleteModule(module);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isUpdating = ref.watch(isUpdatingProvider(module.updatingKey));
    return SortableItem(
      index: index,
      child: ContextMenuRegion(
        menuItems: isUpdating
            ? null
            : [
                if (module.isRemote)
                  PopupMenuItem(
                    glyph: AppGlyphs.sync,
                    label: appLocalizations.update,
                    onPressed: () => _updateModule(context, ref, module),
                  )
                else
                  PopupMenuItem(
                    glyph: AppGlyphs.edit,
                    label: appLocalizations.edit,
                    onPressed: () =>
                        openMitmModuleEditor(context, ref, module: module),
                  ),
                PopupMenuItem(
                  danger: true,
                  glyph: AppGlyphs.delete,
                  label: appLocalizations.delete,
                  onPressed: () => _delete(context, ref),
                ),
              ],
        child: ItemPositionProvider(
          position: ItemPosition.get(index, total),
          child: DecorationListItem(
            contentPadding: EdgeInsetsDirectional.only(
              start: context.listInsets.leading,
              end: isUpdating
                  ? context.listInsets.trailing
                  : context.listInsets.trailing - Switch.edgeInset,
            ),
            title: Text(
              module.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.subheadline.of(context, emphasized: true),
            ),
            subtitle: _MitmModuleSummary(module: module),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                if (!isUpdating && module.hasPending)
                  MitmLinkButton(
                    label: appLocalizations.mitmViewUpdate,
                    onPressed: () => _viewModuleUpdate(context, ref, module),
                  )
                else if (!isUpdating && module.error != null && module.isRemote)
                  MitmLinkButton(
                    label: appLocalizations.retry,
                    onPressed: () => _updateModule(context, ref, module),
                  ),
                if (isUpdating)
                  const ActivityIndicator(size: 24)
                else if (module.unloadable)
                  const Opacity(
                    opacity: 0.4,
                    child: Switch(value: false, onChanged: null),
                  )
                else
                  Switch(
                    value: module.enabled,
                    onChanged: (value) => _setEnabled(ref, module, value),
                  ),
              ],
            ),
            onPressed: () =>
                BaseNavigator.push(context, MitmModuleView(id: module.id)),
          ),
        ),
      ),
    );
  }
}

class MitmModuleView extends ConsumerWidget {
  const MitmModuleView({super.key, required this.id});

  final int id;

  /// A module written for Apple systems still applies, so this only warns.
  String? _systemTip(AppLocalizations appLocalizations, String? target) {
    final current = switch (true) {
      _ when system.isMacOS => 'mac',
      _ when system.isAndroid => 'android',
      _ when system.isWindows => 'windows',
      _ => 'linux',
    };
    if (target == null || target.toLowerCase().contains(current)) {
      return null;
    }
    return appLocalizations.mitmModuleSystemTip(target);
  }

  Widget _linesItem(
    String title,
    List<String> lines, {
    Map<String, String> issues = const {},
    String? issuesHeader,
    List<PopupMenuItem> Function(String line)? menuItemsOf,
  }) {
    return Builder(
      builder: (context) {
        final appLocalizations = context.appLocalizations;
        final invalid = lines.where(issues.containsKey).length;
        return ListItem.open(
          title: Text(title),
          subtitle: Text(
            invalid == 0
                ? appLocalizations.itemsCount(lines.length)
                : appLocalizations.invalidOfCount(invalid, lines.length),
          ),
          widget: _MitmModuleLinesView(
            title: title,
            header: invalid == 0 ? null : issuesHeader,
            lines: [for (final line in lines) (line, issues[line])],
            menuItemsOf: menuItemsOf,
          ),
        );
      },
    );
  }

  List<Widget> _sourceItems(
    BuildContext context,
    WidgetRef ref,
    MitmModule module,
  ) {
    final appLocalizations = context.appLocalizations;
    final url = module.url;
    return [
      ListItem(
        title: Text(appLocalizations.source),
        subtitle: Text(url ?? appLocalizations.local),
      ),
      ListItem(
        title: Text(appLocalizations.lastUpdated),
        trailing: LastUpdateTimeText(
          lastUpdateDate: module.lastUpdateTime,
          style: context.listCaptionStyle,
        ),
      ),
      if (url == null)
        ListItem(
          title: Text(appLocalizations.edit),
          onTap: () => openMitmModuleEditor(context, ref, module: module),
        ),
      if (url != null)
        Consumer(
          builder: (_, ref, _) {
            final isUpdating = ref.watch(
              isUpdatingProvider(module.updatingKey),
            );
            return ListItem(
              title: Text(
                isUpdating
                    ? appLocalizations.mitmChecking
                    : appLocalizations.update,
                style: TextStyle(color: context.colorScheme.primary),
              ),
              trailing: isUpdating ? const ActivityIndicator(size: 16) : null,
              onTap: isUpdating
                  ? null
                  : () => _updateModule(context, ref, module),
            );
          },
        ),
    ];
  }

  Future<void> _attach(WidgetRef ref, MitmModule module) async {
    final file = await globalState.safeRun(picker.pickerFile);
    if (file == null) {
      return;
    }
    await globalState.loadingRun(
      () async => ref
          .read(mitmModulesActionProvider.notifier)
          .attach(module, file.name, await file.readBytes()),
      title: currentAppLocalizations.mitmAddLocalFile,
      tag: LoadingTag.mitm,
    );
  }

  Future<void> _detach(WidgetRef ref, MitmModule module, String name) async {
    final appLocalizations = currentAppLocalizations;
    final res = await dialogs.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.deleteTip(name)),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res == true) {
      await ref.read(mitmModulesActionProvider.notifier).detach(module, name);
    }
  }

  List<Widget> _attachmentItems(
    BuildContext context,
    WidgetRef ref,
    MitmModule module,
  ) {
    final appLocalizations = context.appLocalizations;
    return [
      for (final name in mitmAttachments(module).keys)
        ContextMenuRegion(
          menuItems: [
            PopupMenuItem(
              danger: true,
              glyph: AppGlyphs.delete,
              label: appLocalizations.delete,
              onPressed: () => _detach(ref, module, name),
            ),
          ],
          child: ListItem(title: Text(name)),
        ),
      ListItem(
        title: Text(appLocalizations.mitmAddLocalFile),
        onTap: () => _attach(ref, module),
      ),
    ];
  }

  Widget _argumentItem(
    WidgetRef ref,
    MitmModule module,
    MitmModuleArgument argument,
  ) {
    final value = module.arguments[argument.name] ?? argument.defaultValue;
    Future<void> save(String next) async {
      final turnedOff = await ref
          .read(mitmModulesActionProvider.notifier)
          .setArguments(module, {...module.arguments, argument.name: next});
      await offerMitmModule(ref, turnedOff);
    }

    return switch (argument.type) {
      MitmModuleArgumentType.toggle => ListItem.toggle(
        title: Text(argument.title),
        value: value == 'true',
        onChanged: (next) => save(next.toString()),
      ),
      MitmModuleArgumentType.select => ListItem.options(
        title: Text(argument.title),
        options: argument.options.contains(value)
            ? argument.options
            : [value, ...argument.options],
        value: value,
        textBuilder: (option) => option,
        onChanged: save,
      ),
      MitmModuleArgumentType.input => ListItem.input(
        title: Text(argument.title),
        subtitle: value.isEmpty ? null : Text(value),
        dialogTitle: argument.title,
        value: value,
        onChanged: (next) {
          if (next != null) {
            save(next);
          }
        },
      ),
    };
  }

  String? _aboutFooter(AppLocalizations appLocalizations, MitmModule module) {
    final paragraphs = [
      if (module.description.isNotEmpty) module.description,
      ?_systemTip(appLocalizations, module.system),
    ];
    return paragraphs.isEmpty ? null : paragraphs.join('\n\n');
  }

  String? _argumentsFooter(MitmModuleContent content) {
    final lines = [
      ?content.argumentsDescription,
      for (final argument in content.arguments)
        if (argument.description case final description?)
          '${argument.title}: $description',
    ];
    return lines.isEmpty ? null : lines.join('\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final module = _moduleOf(ref, id);
    final details = ref.watch(mitmModuleDetailsProvider(id));
    final content = details.value?.content;
    final issues = details.value?.issues ?? const {};
    return Scaffold(
      title: module?.name ?? appLocalizations.mitmModule,
      body: NullStatusSwitcher(
        isLoading: module == null || details.isLoading && !details.hasValue,
        child: module == null
            ? const SizedBox()
            : ListView(
                padding: context.listInsets.page().copyWith(
                  top: context.sectionsTopPadding,
                  bottom: 16 + context.bottomInset,
                ),
                children: [
                  generateSection(
                    items: [
                      ListItem.toggle(
                        title: Text(appLocalizations.enabled),
                        value: module.enabled,
                        onChanged: (value) => _setEnabled(ref, module, value),
                      ),
                    ],
                    footer: _aboutFooter(appLocalizations, module),
                  ),
                  generateSection(
                    title: appLocalizations.source,
                    items: _sourceItems(context, ref, module),
                  ),
                  if (!module.isRemote)
                    generateSection(
                      title: appLocalizations.mitmAttachments,
                      items: _attachmentItems(context, ref, module),
                      footer: appLocalizations.mitmAttachmentsDesc,
                      last: content == null,
                    ),
                  if (content != null && content.arguments.isNotEmpty)
                    generateSection(
                      title: appLocalizations.arguments,
                      items: [
                        for (final argument in content.arguments)
                          _argumentItem(ref, module, argument),
                      ],
                      footer: _argumentsFooter(content),
                    ),
                  if (content != null)
                    generateSection(
                      title: appLocalizations.rules,
                      items: [
                        for (final list in MitmList.values)
                          if (content.mitm.linesOf(list) case final lines
                              when lines.isNotEmpty)
                            _linesItem(
                              list.label,
                              lines,
                              issues: issues[list] ?? const {},
                              // Said once; each line keeps its own reason.
                              issuesHeader: list == MitmList.hostname
                                  ? appLocalizations.mitmHostFormatHint
                                  : null,
                              menuItemsOf:
                                  list == MitmList.script && module.enabled
                                  ? (line) => [?mitmRunScriptItem(ref, line)]
                                  : null,
                            ),
                        if (flashMitmSkipped(content).isNotEmpty)
                          ListItem.open(
                            title: Text(appLocalizations.mitmIgnoredLines),
                            subtitle: Text(
                              appLocalizations.itemsCount(
                                flashMitmSkipped(content).length,
                              ),
                            ),
                            widget: _MitmModuleLinesView(
                              title: appLocalizations.mitmIgnoredLines,
                              notes: true,
                              lines: [
                                for (final skip in flashMitmSkipped(content))
                                  (
                                    skip.line,
                                    mitmSkipReasonText(appLocalizations, skip),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  if (content != null && content.rules.isNotEmpty)
                    _MitmRoutingSection(module: module, rules: content.rules),
                ],
              ),
      ),
    );
  }
}

/// A module's routing rules and the switch that puts them ahead of the
/// profile's own. The switch spins until the profile runs with the change,
/// and stays as it was if that fails.
class _MitmRoutingSection extends ConsumerStatefulWidget {
  const _MitmRoutingSection({required this.module, required this.rules});

  final MitmModule module;
  final List<String> rules;

  @override
  ConsumerState<_MitmRoutingSection> createState() =>
      _MitmRoutingSectionState();
}

class _MitmRoutingSectionState extends ConsumerState<_MitmRoutingSection> {
  bool _busy = false;

  Future<void> _set(bool value) async {
    final module = widget.module;
    // The page may close while the profile applies.
    final container = ProviderScope.containerOf(context, listen: false);
    final action = container.read(mitmModulesActionProvider.notifier);
    final setup = container.read(setupActionProvider.notifier);
    setState(() => _busy = true);
    action.putModule(module.copyWith(rulesEnabled: value));
    final applies =
        module.enabled && container.read(patchClashConfigProvider).mitm.enable;
    final applied = !applies || await setup.applyProfile(silence: true);
    if (!applied) {
      final current =
          container
              .read(mitmModulesProvider)
              .value
              ?.firstWhereOrNull((item) => item.id == module.id) ??
          module;
      action.putModule(current.copyWith(rulesEnabled: !value));
      final restored = await setup.applyProfile(silence: true);
      final l = currentAppLocalizations;
      dialogs.showBanner(
        restored
            ? l.mitmRoutingRulesNotApplied
            : l.mitmRoutingRulesRevertFailed,
        level: BannerLevel.error,
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final policies = mitmCurrentPolicies(ref);
    final rules = widget.rules;
    final count = l.mitmModuleRuleCount(rules.length);
    return generateSection(
      title: l.mitmRoutingRules,
      items: [
        ListItem(
          title: Text(l.enabled),
          trailing: _busy
              ? const ActivityIndicator(size: 24)
              : Switch(value: widget.module.rulesEnabled, onChanged: _set),
        ),
        ListItem.open(
          title: Text(count),
          widget: _MitmModuleLinesView(
            title: l.mitmRoutingRules,
            notes: true,
            noteColor: mitmAmberColor(context),
            lines: [
              for (final rule in rules)
                (
                  rule,
                  policies == null || mitmRuleUsable(rule, policies)
                      ? null
                      : l.mitmRulePolicyMissing(mitmRulePolicy(rule)),
                ),
            ],
          ),
        ),
      ],
      footer: l.mitmModuleRulesDesc,
    );
  }
}

class _MitmModuleLinesView extends StatelessWidget {
  const _MitmModuleLinesView({
    required this.title,
    required this.lines,
    this.header,
    this.notes = false,
    this.noteColor,
    this.menuItemsOf,
  });

  final String title;

  /// Each line with why the Core skips it, or with [notes] why the module's
  /// reader left it out.
  final List<(String, String?)> lines;

  /// Above the lines, for what they have in common.
  final String? header;
  final bool notes;
  final Color? noteColor;
  final List<PopupMenuItem> Function(String line)? menuItemsOf;

  @override
  Widget build(BuildContext context) {
    final noteStyle = notes
        ? context.listCaptionStyle.copyWith(color: noteColor)
        : TextStyle(color: context.colorScheme.error);
    return Scaffold(
      title: title,
      body: PrismListView(
        padding: context.listInsets.page().copyWith(
          top: context.contentTopPadding,
          bottom: 16 + context.bottomInset,
        ),
        itemCount: lines.length + (header == null ? 0 : 1),
        itemBuilder: (_, at) {
          if (header case final header? when at == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(header, style: context.listCaptionStyle),
            );
          }
          final index = header == null ? at : at - 1;
          final (line, issue) = lines[index];
          return ItemPositionProvider(
            position: ItemPosition.get(index, lines.length),
            child: MitmTaskRunning(
              line: line,
              builder: (running) => ContextMenuRegion(
                menuItems: menuItemsOf?.call(line),
                child: DecorationListItem(
                  title: Text(line),
                  subtitle: issue == null
                      ? null
                      : Text(issue, style: noteStyle),
                  trailing: running ? const ActivityIndicator(size: 24) : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What a module brings, where it is from, and whether an update waits or
/// failed.
class _MitmModuleSummary extends ConsumerWidget {
  const _MitmModuleSummary({required this.module});

  final MitmModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final content = ref
        .watch(mitmModuleDetailsProvider(module.id))
        .value
        ?.content;
    final style = context.listCaptionStyle;
    final hosts = content == null
        ? 0
        : [
            ...content.insertedHostname,
            ...content.hostname,
          ].where((host) => !host.startsWith('-')).length;
    final rewrites = content == null
        ? 0
        : content.urlRewrite.length +
              content.headerRewrite.length +
              content.bodyRewrite.length +
              content.mapLocal.length;
    final scripts = content?.script.length ?? 0;
    final rules = content?.rules.length ?? 0;
    final skipped = content?.skipped.length ?? 0;
    final parts = [
      if (hosts > 0) TextSpan(text: l.mitmModuleHostCount(hosts)),
      if (rewrites > 0) TextSpan(text: l.mitmModuleRewriteCount(rewrites)),
      if (rules > 0) TextSpan(text: l.mitmModuleRuleCount(rules)),
      if (scripts > 0)
        TextSpan(
          text: l.mitmScriptCount(scripts),
          style: TextStyle(color: mitmScriptColor(context)),
        ),
    ];
    final error = module.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        if (parts.isNotEmpty || skipped > 0)
          Text.rich(
            TextSpan(
              children: [
                for (final (index, part) in parts.indexed) ...[
                  if (index > 0) const TextSpan(text: ' · '),
                  part,
                ],
                if (skipped > 0)
                  TextSpan(
                    text:
                        '${parts.isEmpty ? '' : ' · '}${l.mitmModuleUnsupportedLines(skipped)}',
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        if (error != null)
          Tooltip(
            message: error,
            hoverDelay: const Duration(milliseconds: 500),
            child: MitmMarkedLine(
              module.unloadable
                  ? l.mitmModuleLoadFailed(error)
                  : mitmKeptFailureText(l, module.failure),
              style: style.copyWith(
                color: module.unloadable
                    ? mitmRewriteErrorColor(context)
                    : mitmAmberColor(context),
              ),
            ),
          )
        else
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: module.isRemote
                      ? l.mitmModuleRemoteSource(
                          module.lastUpdateTime.getLastUpdateTimeDesc(context),
                        )
                      : l.mitmModuleLocalSource,
                ),
                if (module.hasPending)
                  TextSpan(
                    text: ' · ${l.mitmHasUpdate}',
                    style: TextStyle(color: mitmAmberColor(context)),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
      ],
    );
  }
}
