import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/views/profiles/mount.dart' show MountTag;
import 'package:flutter/widgets.dart';

const _tagGap = 6.0;

/// A config-hidden group's name and 隐藏 tag; only the name truncates.
class HiddenGroupName extends StatelessWidget {
  const HiddenGroupName({super.key, required this.name, required this.child});

  final String name;
  final Widget child;

  static double tagWidthOf(BuildContext context) =>
      _tagGap +
      MountTag.widthOf(context, context.appLocalizations.hiddenGroupTag);

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Semantics(
      label: appLocalizations.hiddenGroupSemantics(name),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: child),
            const SizedBox(width: _tagGap),
            MountTag(label: appLocalizations.hiddenGroupTag),
          ],
        ),
      ),
    );
  }
}
