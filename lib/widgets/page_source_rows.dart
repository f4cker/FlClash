import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The dialog's width, so its description fits on one line.
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

/// A row's two sources side by side; the chosen one is tinted, not filled,
/// so the dialog's only filled button stays its default action.
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

/// Where a page-controlled field's value comes from, with the action that
/// hands it back to the profile.
class PageSourceNote extends ConsumerWidget {
  const PageSourceNote({super.key, required this.pageKey, this.pageValue});

  final PageConfigKey pageKey;

  final String? pageValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:pagePriority, :follows) = ref.watch(
      patchClashConfigProvider.select(
        (state) => (
          pagePriority: state.pagePriority,
          follows: state.followKeys.contains(pageKey),
        ),
      ),
    );
    if (!pagePriority) {
      return const SizedBox.shrink();
    }
    final appLocalizations = context.appLocalizations;
    final pending =
        ref.watch(appliedFollowKeysProvider).contains(pageKey) != follows;
    final String text;
    if (follows) {
      final fileValue = switch (ref.watch(profileSettingsProvider)) {
        final settings? => readConfigPath(settings, pageKey.path),
        null => configKeyMissing,
      };
      final fromFile = !identical(fileValue, configKeyMissing);
      final fallback = kernelDefaults[pageKey.path];
      final value = fromFile
          ? describeConfigValue(pageKey.path, fileValue)
          : fallback == null
          ? appLocalizations.notSet
          : describeConfigValue(pageKey.path, fallback);
      text =
          '$value · ${fromFile ? appLocalizations.sourceBase : appLocalizations.sourceDefault}';
    } else {
      text = [?pageValue, appLocalizations.sourcePage].join(' · ');
    }
    final style = AppTextStyle.footnote.of(context).toLight;
    return Row(
      spacing: 8,
      children: [
        Flexible(
          child: Text(
            pending ? '$text · ${appLocalizations.notYetApplied}' : text,
            style: style,
          ),
        ),
        if (!follows)
          TextButton(
            onPressed: () => ref
                .read(patchClashConfigProvider.notifier)
                .update((state) => state.follow(pageKey)),
            child: Text(appLocalizations.followBaseProfile),
          ),
      ],
    );
  }
}
