import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'rules_logic.dart';

/// The name a rule target shows: the built-in ones in words.
String ruleTargetLabel(BuildContext context, String target) {
  final appLocalizations = context.appLocalizations;
  return switch (target.toUpperCase()) {
    'DIRECT' => appLocalizations.direct,
    'REJECT' || 'REJECT-DROP' => appLocalizations.ruleReject,
    _ => target,
  };
}

/// Asks where an added rule for [host] reaches and which group it goes
/// through, then writes it with [onAdd]; it closes, with the rule's text,
/// only once [onAdd] says the rule was written and the config reloaded.
/// [onAdd] answers null when it did, or why it did not.
class AddRuleDialog extends StatefulWidget {
  final String host;
  final String profileLabel;
  final List<String> targets;
  final String? initialTarget;
  final Future<String?> Function(String ruleText) onAdd;

  const AddRuleDialog({
    super.key,
    required this.host,
    required this.profileLabel,
    required this.targets,
    this.initialTarget,
    required this.onAdd,
  });

  @override
  State<AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends State<AddRuleDialog> {
  late final _choices = addedRuleChoices(widget.host);
  int _choice = 0;
  late String _target =
      widget.initialTarget != null &&
          widget.targets.contains(widget.initialTarget)
      ? widget.initialTarget!
      : widget.targets.first;
  bool _busy = false;
  String? _error;

  String get _ruleText => addedRuleText(_choices[_choice], _target);

  Future<void> _add() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final text = _ruleText;
    final error = await widget.onAdd(text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(text);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: AppTextStyle.footnote
          .of(context, emphasized: true)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildChoice(BuildContext context, int index) {
    final colorScheme = context.colorScheme;
    final choice = _choices[index];
    final selected = index == _choice;
    final label = choice.exact
        ? context.appLocalizations.addRuleExact(choice.value)
        : context.appLocalizations.addRuleSuffix(choice.value);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : () => setState(() => _choice = index),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              spacing: 10,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.outline,
                      width: selected ? 5 : 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyle.subheadline.of(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTarget(BuildContext context) {
    final colorScheme = context.colorScheme;
    return PopupAnchor(
      placement: PopupPlacement.overAnchorStart,
      targetBuilder: (open) => GestureDetector(
        onTap: _busy ? null : open,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: ShapeDecoration(
              color: context.raisedSurfaceLevel.colorOf(colorScheme),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: EmojiText(
                    ruleTargetLabel(context, _target),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.subheadline.of(context),
                  ),
                ),
                GlyphIcon(
                  AppGlyphs.chevronDown,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
      popupBuilder: (_) => PopupMenu(
        maxVisibleItems: 10,
        items: [
          for (final target in widget.targets)
            PopupMenuItem(
              label: ruleTargetLabel(context, target),
              checked: target == _target,
              onPressed: () => setState(() => _target = target),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    return AlertDialog(
      title: appLocalizations.addRuleTitle,
      width: 440,
      hasFields: true,
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _busy ? null : _add,
          child: _busy
              ? ActivityIndicator(size: 16, color: colorScheme.onPrimary)
              : Text(appLocalizations.add),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            appLocalizations.addRuleSubtitle(widget.profileLabel),
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _label(context, appLocalizations.addRuleScope),
          const SizedBox(height: 4),
          for (var index = 0; index < _choices.length; index++)
            _buildChoice(context, index),
          const SizedBox(height: 12),
          _label(context, appLocalizations.addRuleTarget),
          const SizedBox(height: 6),
          _buildTarget(context),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: ShapeDecoration(
              color: colorScheme.brightness == Brightness.light
                  ? const Color(0xFFF6F5F8)
                  : colorScheme.surfaceContainerHighest,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  appLocalizations.addRulePreview,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
                EmojiText(
                  _ruleText,
                  style: AppTextStyle.footnote
                      .of(context)
                      .toJetBrainsMono
                      .copyWith(color: colorScheme.onSurface),
                ),
              ],
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
