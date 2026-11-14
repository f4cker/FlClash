import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const pageSourceDialogWidth = 480.0;

class PageSourceRows extends StatelessWidget {
  const PageSourceRows({
    super.key,
    required this.changes,
    required this.choices,
  });

  final PagePriorityChanges changes;
  final Set<PageConfigKey> choices;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      for (final row in changes.hiddenRows)
        Text(
          context.appLocalizations.pageSourceChange(
            configPathLabel(row.path),
            describeConfigValue(row.path, row.oldValue),
            describeConfigValue(row.path, row.newValue),
          ),
        ),
    ],
  );
}

Object? pageRawValue(Object? value) => switch (value) {
  (final ExternalControllerStatus status, _) => status.value,
  final Enum item => item.name,
  _ => value,
};

List<PopupMenuItem> followMenuItems(
  WidgetRef ref,
  PageConfigKey key, {
  bool separated = true,
}) {
  return const [];
}

/// Where a page-controlled field's value comes from, as "value · source".
class PageSourceNote extends ConsumerWidget {
  const PageSourceNote({super.key, required this.pageKey, this.describe});

  final PageConfigKey pageKey;

  final String Function(Object? value)? describe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageValue = ref.watch(
      patchClashConfigProvider.select(
        (state) => pageRawValue(state.pageValue(pageKey)),
      ),
    );
    final appLocalizations = context.appLocalizations;
    final value =
        describe?.call(pageValue) ??
        describeConfigValue(pageKey.path, pageValue);
    final source = appLocalizations.sourcePage;

    return Text(
      [value, source].join(' · '),
      style: AppTextStyle.caption1
          .of(context)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
  }
}
