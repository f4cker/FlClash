import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const pageSourceDialogWidth = 480.0;

/// The rows of the dialog that confirms each setting's source before page
/// priority applies; [choices] holds the keys set to follow the profile.
class PageSourceRows extends StatefulWidget {
  const PageSourceRows({
    super.key,
    required this.changes,
    required this.choices,
  });

  final PagePriorityChanges changes;
  final Set<PageConfigKey> choices;

  @override
  State<PageSourceRows> createState() => _PageSourceRowsState();
}

class _PageSourceRowsState extends State<PageSourceRows> {
  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final titleStyle = AppTextStyle.body.of(context);
    final captionStyle = AppTextStyle.footnote.of(context).toLight;
    final lineStyle = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final hiddenRows = widget.changes.hiddenRows;
    final fillsDefaults = hiddenRows.any(
      (row) => identical(row.newValue, configKeyMissing),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text(appLocalizations.pageSourceDesc, style: captionStyle),
        for (final row in widget.changes.pageRows)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Text(pageConfigKeyLabel(row.key), style: titleStyle),
              Text(
                appLocalizations.pageSourceCompare(
                  describeConfigValue(row.key.path, row.pageValue),
                  describeConfigValue(row.key.path, row.fileValue),
                ),
                style: captionStyle,
              ),
              SourceChoice(
                follows: widget.choices.contains(row.key),
                onChanged: (follow) => setState(() {
                  follow
                      ? widget.choices.add(row.key)
                      : widget.choices.remove(row.key);
                }),
              ),
            ],
          ),
        if (hiddenRows.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(
                appLocalizations.pageSourceHiddenTitle,
                style: AppTextStyle.footnote
                    .of(context, emphasized: true)
                    .copyWith(color: colorScheme.onSurface),
              ),
              if (fillsDefaults)
                Text(appLocalizations.pageSourceHiddenNote, style: lineStyle),
              for (final row in hiddenRows)
                Text(
                  appLocalizations.pageSourceChange(
                    configPathLabel(row.path),
                    describeConfigValue(
                      row.path,
                      row.oldValue,
                      withDefault: false,
                    ),
                    describeConfigValue(
                      row.path,
                      row.newValue,
                      withDefault: false,
                    ),
                  ),
                  style: lineStyle,
                ),
            ],
          ),
      ],
    );
  }
}

/// A row's two sources; the chosen one is tinted, leaving 应用 the only fill.
class SourceChoice extends StatelessWidget {
  const SourceChoice({
    super.key,
    required this.follows,
    required this.onChanged,
  });

  final bool follows;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        shape: AppShape.full.copyWith(
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          for (final (value, label) in [
            (false, appLocalizations.keepPageSetting),
            (true, appLocalizations.followBaseProfile),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: value == follows,
                child: PressSurface(
                  fill: value == follows
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  shape: AppShape.full,
                  childFills: true,
                  onPressed: value == follows ? () {} : () => onChanged(value),
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.subheadline
                          .of(context, emphasized: value == follows)
                          .copyWith(
                            color: value == follows
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Object? pageRawValue(Object? value) => switch (value) {
  (final ExternalControllerStatus status, _) => status.value,
  final Enum item => item.name,
  _ => value,
};

/// The menu item that hands a page-controlled field back to the profile,
/// offered whenever the page controls it, whatever the two values are.
List<PopupMenuItem> followMenuItems(
  WidgetRef ref,
  PageConfigKey key, {
  bool separated = true,
}) {
  final (:pagePriority, :follows) = ref.watch(
    patchClashConfigProvider.select(
      (state) => (
        pagePriority: state.pagePriority,
        follows: state.followKeys.contains(key),
      ),
    ),
  );
  if (!pagePriority || follows) {
    return const [];
  }
  return [
    PopupMenuItem(
      label: currentAppLocalizations.followBaseProfile,
      section: separated ? const PopupMenuSection() : null,
      onPressed: () => ref
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.follow(key)),
    ),
  ];
}

/// Where a page-controlled field's value comes from, as "value · source".
class PageSourceNote extends ConsumerWidget {
  const PageSourceNote({super.key, required this.pageKey, this.describe});

  final PageConfigKey pageKey;

  final String Function(Object? value)? describe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:pagePriority, :follows, :pageValue) = ref.watch(
      patchClashConfigProvider.select(
        (state) => (
          pagePriority: state.pagePriority,
          follows: state.followKeys.contains(pageKey),
          pageValue: pageRawValue(state.pageValue(pageKey)),
        ),
      ),
    );
    if (!pagePriority) {
      return const SizedBox.shrink();
    }
    final appLocalizations = context.appLocalizations;
    String word(Object? value) =>
        describe?.call(value) ?? describeConfigValue(pageKey.path, value);
    final pending =
        ref.watch(appliedFollowKeysProvider).contains(pageKey) != follows;
    final String value;
    final String source;
    if (follows) {
      final fileValue = switch (ref.watch(profileSettingsProvider)) {
        final settings? => readConfigPath(settings, pageKey.path),
        null => configKeyMissing,
      };
      final fallback = kernelDefaults[pageKey.path];
      if (!identical(fileValue, configKeyMissing)) {
        value = word(fileValue);
        source = appLocalizations.sourceBase;
      } else if (fallback != null) {
        value = word(fallback);
        source = appLocalizations.sourceDefault;
      } else {
        value = appLocalizations.notSet;
        source = appLocalizations.sourceBase;
      }
    } else {
      value = word(pageValue);
      source = appLocalizations.sourcePage;
    }
    return Text(
      [value, source, if (pending) appLocalizations.notYetApplied].join(' · '),
      style: AppTextStyle.caption1
          .of(context)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
  }
}
