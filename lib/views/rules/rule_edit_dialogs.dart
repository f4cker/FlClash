import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/added_rule_edit.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'add_rule_dialog.dart' show ruleTargetLabel;

/// How a rule or rule set dialog closed after it saved: what it wrote,
/// and whether that waits on the Core to start.
typedef RuleEditOutcome = ({
  String text,
  String name,
  int? ruleId,
  bool pending,
  bool isSet,
  bool edited,
  bool deleted,
});

/// Writes a rule: [previous] is the rule it replaces, if any; [last] puts a
/// new one after the other added rules.
typedef RuleSaver =
    Future<RuleEditSave> Function(Rule rule, {Rule? previous, bool last});

typedef RuleSetSaver =
    Future<RuleEditSave> Function(
      AddedRuleSet set, {
      required String target,
      RuleSetCheck? check,
    });

typedef RuleEditSave = ({String? error, bool pending, int? ruleId});

const _errorInk = Color(0xFFB3261E);
const _errorFill = Color(0xFFFDECEC);
const _okInk = Color(0xFF16632C);
const _warnInk = Color(0xFF8A5300);
const _fieldGap = 14.0;
const _stackedActionHeight = 44.0;
const _labelGap = 6.0;
const _validateDelay = Duration(milliseconds: 300);
const _checkDelay = Duration(milliseconds: 500);

/// The rule types the add dialog names in words; the rest show their type.
String ruleTypeLabel(BuildContext context, RuleAction type) {
  final appLocalizations = context.appLocalizations;
  return switch (type) {
    RuleAction.DOMAIN_SUFFIX => appLocalizations.ruleTypeDomainSuffix,
    RuleAction.DOMAIN => appLocalizations.ruleTypeDomain,
    RuleAction.DOMAIN_KEYWORD => appLocalizations.ruleTypeKeyword,
    RuleAction.IP_CIDR => appLocalizations.ruleTypeIpCidr,
    RuleAction.IP_CIDR6 => appLocalizations.ruleTypeIpCidr6,
    RuleAction.DST_PORT => appLocalizations.ruleTypeDstPort,
    RuleAction.PROCESS_NAME => appLocalizations.ruleTypeProcessName,
    RuleAction.SRC_IP_CIDR => appLocalizations.ruleTypeSrcIpCidr,
    _ => type.value,
  };
}

String _valueLabel(BuildContext context, RuleAction type) {
  if (type == RuleAction.DOMAIN_KEYWORD) {
    return context.appLocalizations.ruleValueKeyword;
  }
  if (addedRuleMainTypes.contains(type) ||
      const [
        RuleAction.IP_CIDR6,
        RuleAction.DST_PORT,
        RuleAction.PROCESS_NAME,
        RuleAction.SRC_IP_CIDR,
        RuleAction.GEOIP,
        RuleAction.GEOSITE,
      ].contains(type)) {
    return ruleTypeLabel(context, type);
  }
  return context.appLocalizations.value;
}

String? _helpOf(BuildContext context, RuleAction type) {
  final appLocalizations = context.appLocalizations;
  return switch (type) {
    RuleAction.DOMAIN_SUFFIX => appLocalizations.ruleHelpDomainSuffix,
    RuleAction.DOMAIN => appLocalizations.ruleHelpDomain,
    RuleAction.DOMAIN_KEYWORD => appLocalizations.ruleHelpKeyword,
    RuleAction.IP_CIDR => appLocalizations.ruleHelpIpCidr,
    RuleAction.IP_CIDR6 => appLocalizations.ruleHelpIpCidr6,
    RuleAction.SRC_IP_CIDR => appLocalizations.ruleHelpSrcIpCidr,
    RuleAction.DST_PORT => appLocalizations.ruleHelpPort,
    RuleAction.PROCESS_NAME => appLocalizations.ruleHelpProcess,
    _ => null,
  };
}

String _valueErrorText(BuildContext context, AddedRuleValueError error) {
  final appLocalizations = context.appLocalizations;
  return switch (error) {
    AddedRuleValueError.empty => appLocalizations.ruleValueEmpty,
    AddedRuleValueError.comma => appLocalizations.ruleValueComma,
    AddedRuleValueError.domain => appLocalizations.ruleValueDomain,
    AddedRuleValueError.cidr => appLocalizations.ruleValueCidr,
    AddedRuleValueError.network => appLocalizations.ruleValueNetwork,
    AddedRuleValueError.numberRange => appLocalizations.ruleValueNumberRange,
    AddedRuleValueError.dscpRange => appLocalizations.ruleValueDscp,
  };
}

/// The country codes a GEOIP rule offers, and the lists a GEOSITE rule
/// offers: the ones the bundled databases carry that rules use most.
const geoIpCodes = [
  'CN', 'LAN', 'PRIVATE', 'HK', 'TW', 'MO', 'JP', 'KR', 'SG', 'US', //
  'GB', 'DE', 'FR', 'NL', 'CA', 'AU', 'RU', 'IN', 'TELEGRAM',
];

const geoSiteCodes = [
  'cn',
  'geolocation-cn',
  'geolocation-!cn',
  'private',
  'apple',
  'apple-cn',
  'google',
  'google-cn',
  'microsoft',
  'github',
  'openai',
  'anthropic',
  'telegram',
  'twitter',
  'facebook',
  'youtube',
  'netflix',
  'spotify',
  'steam',
  'category-ads-all',
  'category-games',
  'tld-cn',
  'tld-!cn',
];

Widget _label(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: _labelGap),
    child: Text(
      text,
      style: AppTextStyle.caption1
          .of(context)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    ),
  );
}

Widget _note(BuildContext context, String text, {Color? color, Widget? lead}) {
  final style = AppTextStyle.caption1
      .of(context)
      .copyWith(color: color ?? context.colorScheme.onSurfaceVariant);
  final body = Text(text, style: style);
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: lead == null
        ? body
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: lead),
              Expanded(child: body),
            ],
          ),
  );
}

/// A single-line field of the dialogs, 36 high, outlined red on [error].
class RuleEditField extends StatelessWidget {
  final TextEditingController controller;
  final bool error;
  final bool monospace;
  final bool autofocus;
  final bool enabled;
  final String? hint;
  final String semanticLabel;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final Widget? trailing;

  const RuleEditField({
    super.key,
    required this.controller,
    required this.semanticLabel,
    this.error = false,
    this.monospace = false,
    this.autofocus = false,
    this.enabled = true,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    var style = AppTextStyle.subheadline.of(context);
    if (monospace) style = style.toJetBrainsMono;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: error ? _errorInk : colorScheme.outlineVariant,
            width: error ? 1.5 : 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: semanticLabel,
              textField: true,
              child: TextField(
                controller: controller,
                autofocus: autofocus,
                enabled: enabled,
                autocorrect: false,
                enableSuggestions: false,
                style: style,
                decoration: InputDecoration.collapsed(
                  hintText: hint ?? '',
                  filled: false,
                ),
                onChanged: onChanged,
                onSubmitted: (_) => onSubmitted?.call(),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A field that picks one of [items] from a menu.
class RuleEditDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T item) labelOf;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final String placeholder;

  /// The items after which the menu draws a line, such as the built-in
  /// outbounds after the groups.
  final bool Function(T item)? startsSection;

  const RuleEditDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onSelected,
    this.enabled = true,
    this.placeholder = '',
    this.startsSection,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final value = this.value;
    return PopupAnchor(
      placement: PopupPlacement.belowAnchorStart,
      targetBuilder: (open) => Semantics(
        button: true,
        label: value == null ? placeholder : labelOf(value),
        child: GestureDetector(
          onTap: enabled && items.isNotEmpty ? open : null,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                      value == null ? placeholder : labelOf(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.subheadline
                          .of(context)
                          .copyWith(
                            color: value == null
                                ? colorScheme.onSurfaceVariant
                                : null,
                          ),
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
      ),
      popupBuilder: (_) => PopupMenu(
        items: [
          for (final item in items)
            PopupMenuItem(
              label: labelOf(item),
              checked: item == value,
              section: startsSection?.call(item) == true
                  ? const PopupMenuSection()
                  : null,
              onPressed: () => onSelected(item),
            ),
        ],
      ),
    );
  }
}

/// The block that shows the rule a dialog writes.
class RuleEditPreview extends StatelessWidget {
  final String text;
  final bool placeholder;

  const RuleEditPreview({
    super.key,
    required this.text,
    this.placeholder = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
            context.appLocalizations.addRulePreview,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          EmojiText(
            text,
            style: AppTextStyle.footnote
                .of(context)
                .toJetBrainsMono
                .copyWith(
                  color: placeholder
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                      : colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

/// The frame both dialogs share: title and subtitle, the fields, a red bar
/// for a failed save, and the buttons, Delete apart on the left. While
/// [busy] nothing in it takes input.
class RuleEditFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final double width;
  final List<Widget> children;
  final String? error;

  /// The untranslated text behind [error], behind 查看原始错误 in its bar.
  final String? errorRaw;
  final bool busy;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onDelete;
  final bool deleting;

  /// In the footer's start, where [onDelete] would go.
  ///
  /// Mounted twice, once in the one-row footer and once in the stacked one
  /// (only one is shown), so it must keep no state of its own and carry no
  /// GlobalKey: a button whose state lives in the dialog.
  final Widget? leading;

  /// Stacked actions top to bottom by slot id; null keeps primary first.
  final List<Symbol>? stackedOrder;
  final double? minBodyHeight;

  const RuleEditFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.width,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.error,
    this.errorRaw,
    this.busy = false,
    this.onDelete,
    this.deleting = false,
    this.leading,
    this.stackedOrder,
    this.minBodyHeight,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final screen = MediaQuery.sizeOf(context).width;
    final effective = math.max(280.0, math.min(width, screen - 32));
    final errorInk = colorScheme.brightness == Brightness.light
        ? _errorInk
        : const Color(0xFFF2B8B5);
    void cancel() {
      if (!busy) Navigator.of(context).pop();
    }

    Widget spinner(Color color) => ActivityIndicator(size: 14, color: color);
    final wide = Row(
      spacing: 8,
      children: [
        if (onDelete != null)
          AdaptiveActionSlot(
            id: #delete,
            child: TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(
                  busy ? _errorInk.withValues(alpha: 0.4) : _errorInk,
                ),
              ),
              onPressed: busy ? null : onDelete,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  if (deleting) spinner(_errorInk),
                  Text(appLocalizations.delete),
                ],
              ),
            ),
          ),
        if (leading case final leading?)
          Flexible(
            child: AdaptiveActionSlot(id: #leading, child: leading),
          ),
        const Spacer(),
        AdaptiveActionSlot(
          id: #cancel,
          child: TextButton(
            onPressed: busy ? null : cancel,
            child: Text(appLocalizations.cancel),
          ),
        ),
        AdaptiveActionSlot(
          id: #primary,
          child: FilledButton(
            onPressed: busy ? () {} : onPrimary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (busy && !deleting) spinner(colorScheme.onPrimary),
                Text(primaryLabel),
              ],
            ),
          ),
        ),
      ],
    );
    // Too narrow for one row: every action on its own full-width line, the
    // default one first, each label wrapping as it needs.
    const stackedStyle = ButtonStyle(
      minimumSize: Size(0, _stackedActionHeight),
    );
    Widget stackedLabel(String text) => Text(text, textAlign: TextAlign.center);
    final stackedActions = [
      AdaptiveActionSlot(
        id: #primary,
        child: FilledButton(
          style: stackedStyle,
          onPressed: busy ? () {} : onPrimary,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (busy && !deleting) spinner(colorScheme.onPrimary),
              Flexible(child: stackedLabel(primaryLabel)),
            ],
          ),
        ),
      ),
      if (leading case final leading?)
        AdaptiveActionSlot(
          id: #leading,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _stackedActionHeight),
            child: leading,
          ),
        ),
      if (onDelete != null)
        AdaptiveActionSlot(
          id: #delete,
          child: TextButton(
            style: ButtonStyle(
              minimumSize: const Size(0, _stackedActionHeight),
              foregroundColor: WidgetStatePropertyAll(
                busy ? _errorInk.withValues(alpha: 0.4) : _errorInk,
              ),
            ),
            onPressed: busy ? null : onDelete,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (deleting) spinner(_errorInk),
                Flexible(child: stackedLabel(appLocalizations.delete)),
              ],
            ),
          ),
        ),
      AdaptiveActionSlot(
        id: #cancel,
        child: TextButton(
          style: stackedStyle,
          onPressed: busy ? null : cancel,
          child: stackedLabel(appLocalizations.cancel),
        ),
      ),
    ];
    final order = stackedOrder;
    final stacked = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: order == null
          ? stackedActions
          : [
              for (final id in order)
                ...stackedActions.where((slot) => slot.id == id),
            ],
    );
    final footer = AdaptiveActions(wide: wide, stacked: stacked);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): cancel},
      child: AlertDialog(
        title: title,
        width: effective,
        hasFields: true,
        child: PinnedFooter(
          minBodyHeight: minBodyHeight,
          footer: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: footer,
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              AbsorbPointer(
                absorbing: busy,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, child) in children.indexed) ...[
                      if (index > 0) const SizedBox(height: _fieldGap),
                      child,
                    ],
                  ],
                ),
              ),
              if (error case final error?) ...[
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: ShapeDecoration(
                      color: colorScheme.brightness == Brightness.light
                          ? _errorFill
                          : _errorInk.withValues(alpha: 0.28),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          error,
                          style: AppTextStyle.footnote
                              .of(context)
                              .copyWith(color: errorInk),
                        ),
                        if (errorRaw case final raw?)
                          RawErrorDetails(
                            key: ValueKey(raw),
                            raw: raw,
                            color: errorInk,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks before a rule or rule set goes; true to delete.
Future<bool> confirmRuleDelete(
  BuildContext context, {
  required String text,
  String? setName,
}) async {
  final appLocalizations = context.appLocalizations;
  final res = await dialogs.showMessage(
    context: context,
    title: setName == null
        ? appLocalizations.ruleDeleteTitle
        : appLocalizations.ruleSetDeleteTitle(setName),
    message: TextSpan(text: appLocalizations.ruleDeleteBody(text)),
    destructive: true,
    confirmText: appLocalizations.delete,
  );
  return res == true;
}

// The rule dialog

/// Adds an added rule, or edits [rule]. It closes only once [onSave] says
/// the Core runs the profile with it, or that it waits on the Core to
/// start; a failure stays in the dialog with what was typed.
class RuleEditDialog extends StatefulWidget {
  final String profileLabel;
  final bool coreRunning;
  final List<String> targets;

  /// The added rules already there, in order, for duplicates.
  final List<Rule> existing;

  /// The rule edited, and its place in the list.
  final Rule? rule;
  final int? number;

  /// What a new rule starts with, such as a looked-up host.
  final RuleAction? initialType;
  final String? initialValue;
  final String? initialTarget;

  /// The processes requests came from lately, to pick one.
  final List<String> processNames;

  final RuleSaver onSave;
  final Future<RuleEditSave> Function()? onDelete;

  const RuleEditDialog({
    super.key,
    required this.profileLabel,
    required this.coreRunning,
    required this.targets,
    required this.existing,
    required this.onSave,
    this.rule,
    this.number,
    this.initialType,
    this.initialValue,
    this.initialTarget,
    this.processNames = const [],
    this.onDelete,
  });

  @override
  State<RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<RuleEditDialog> {
  late RuleAction _type;
  late final TextEditingController _value;
  late String? _target;
  bool _last = false;
  bool _busy = false;
  bool _deleting = false;
  String? _error;
  bool _showValueError = false;
  Timer? _validateTimer;

  bool get _editing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _type = rule?.ruleAction ?? widget.initialType ?? RuleAction.DOMAIN_SUFFIX;
    _value = TextEditingController(
      text: rule?.content ?? widget.initialValue ?? '',
    );
    final wanted = rule?.ruleTarget ?? widget.initialTarget;
    _target = wanted != null && widget.targets.contains(wanted)
        ? wanted
        : widget.targets.firstOrNull;
    _showValueError = _value.text.isNotEmpty;
  }

  @override
  void dispose() {
    _validateTimer?.cancel();
    _value.dispose();
    super.dispose();
  }

  String get _normalized => normalizeAddedRuleValue(_type, _value.text);

  AddedRuleValueError? get _valueError =>
      addedRuleValueError(_type, _normalized);

  /// The added rule matching the same thing, not the one edited.
  (int, Rule)? get _duplicate {
    if (_valueError != null) return null;
    final probe = Rule(ruleAction: _type, content: _normalized);
    for (final (index, rule) in widget.existing.indexed) {
      if (rule.id == widget.rule?.id) continue;
      if (sameAddedRule(rule, probe)) return (index, rule);
    }
    return null;
  }

  Rule _build() {
    final rule = widget.rule;
    final base = rule ?? Rule(ruleAction: _type);
    return base.copyWith(
      ruleAction: _type,
      content: _normalized,
      ruleTarget: _target,
      ruleProvider: null,
      subRule: null,
      noResolve: rule != null && rule.ruleAction == _type && rule.noResolve,
      src: rule != null && rule.ruleAction == _type && rule.src,
    );
  }

  bool get _changed {
    final rule = widget.rule;
    if (rule == null) return true;
    return rule.ruleAction != _type ||
        (rule.content ?? '') != _normalized ||
        rule.ruleTarget != _target;
  }

  bool get _canSave =>
      !_busy && _target != null && _valueError == null && _changed;

  void _onValueChanged(String text) {
    // A pasted link gives its host for a domain rule.
    if (text.contains('://') &&
        const [
          RuleAction.DOMAIN_SUFFIX,
          RuleAction.DOMAIN,
          RuleAction.DOMAIN_KEYWORD,
        ].contains(_type)) {
      final host = normalizeAddedRuleValue(_type, text);
      if (host != text.trim()) {
        _value.value = TextEditingValue(
          text: host,
          selection: TextSelection.collapsed(offset: host.length),
        );
      }
    }
    _validateTimer?.cancel();
    setState(() => _showValueError = false);
    _validateTimer = Timer(_validateDelay, () {
      if (mounted) setState(() => _showValueError = _value.text.isNotEmpty);
    });
  }

  void _setType(RuleAction type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      if (type == RuleAction.GEOIP || type == RuleAction.GEOSITE) {
        final codes = type == RuleAction.GEOIP ? geoIpCodes : geoSiteCodes;
        if (!codes.contains(_value.text)) _value.text = '';
      }
      _showValueError = _value.text.isNotEmpty;
    });
  }

  Future<void> _save() async {
    if (!_canSave) {
      setState(() => _showValueError = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final duplicate = _editing ? null : _duplicate;
    final rule = _build();
    final RuleEditSave result;
    if (duplicate != null) {
      result = await widget.onSave(
        duplicate.$2.copyWith(ruleTarget: _target),
        previous: duplicate.$2,
      );
    } else {
      result = await widget.onSave(rule, previous: widget.rule, last: _last);
    }
    if (!mounted) return;
    if (result.error case final error?) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop<RuleEditOutcome>((
      text: rule.rawValue,
      name: '',
      ruleId: result.ruleId,
      pending: result.pending,
      isSet: false,
      edited: _editing || duplicate != null,
      deleted: false,
    ));
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    final rule = widget.rule;
    if (onDelete == null || rule == null) return;
    if (!await confirmRuleDelete(context, text: rule.rawValue)) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _deleting = true;
      _error = null;
    });
    final result = await onDelete();
    if (!mounted) return;
    if (result.error case final error?) {
      setState(() {
        _busy = false;
        _deleting = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop<RuleEditOutcome>((
      text: rule.rawValue,
      name: '',
      ruleId: null,
      pending: result.pending,
      isSet: false,
      edited: false,
      deleted: true,
    ));
  }

  Widget _buildType(BuildContext context, bool narrow) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final all = [...addedRuleMainTypes, ...addedRuleMoreTypes];
    if (narrow) {
      return RuleEditDropdown<RuleAction>(
        value: _type,
        items: all,
        labelOf: (type) => ruleTypeLabel(context, type),
        onSelected: _setType,
      );
    }
    final inMore = !addedRuleMainTypes.contains(_type);
    final more = PopupAnchor(
      placement: PopupPlacement.belowAnchorEnd,
      targetBuilder: (open) => Semantics(
        button: true,
        selected: inMore,
        label: inMore
            ? ruleTypeLabel(context, _type)
            : appLocalizations.ruleTypeMore,
        child: GestureDetector(
          onTap: open,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: ShapeDecoration(
                color: inMore
                    ? colorScheme.primary
                    : context.raisedSurfaceLevel.colorOf(colorScheme),
                shape: AppShape.full,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Text(
                    inMore
                        ? ruleTypeLabel(context, _type)
                        : appLocalizations.ruleTypeMore,
                    style: AppTextStyle.footnote
                        .of(context, emphasized: true)
                        .copyWith(
                          color: inMore
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                  ),
                  GlyphIcon(
                    AppGlyphs.chevronDown,
                    size: 12,
                    color: inMore
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      popupBuilder: (_) => PopupMenu(
        maxVisibleItems: 10,
        items: [
          for (final type in addedRuleMoreTypes)
            PopupMenuItem(
              label: ruleTypeLabel(context, type),
              checked: type == _type,
              onPressed: () => _setType(type),
            ),
        ],
      ),
    );
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: SegmentedControl<RuleAction?>(
            segments: [
              for (final type in addedRuleMainTypes)
                (type, ruleTypeLabel(context, type)),
            ],
            value: inMore ? null : _type,
            onChanged: (type) {
              if (type != null) _setType(type);
            },
          ),
        ),
        more,
      ],
    );
  }

  Widget _buildValue(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final label = _valueLabel(context, _type);
    final error = _valueError;
    final shownError =
        _showValueError && error != null && error != AddedRuleValueError.empty
        ? error
        : null;
    final duplicate = _editing ? null : _duplicate;
    final Widget input;
    if (_type == RuleAction.GEOIP || _type == RuleAction.GEOSITE) {
      final codes = _type == RuleAction.GEOIP ? geoIpCodes : geoSiteCodes;
      input = RuleEditDropdown<String>(
        value: codes.contains(_value.text) ? _value.text : null,
        items: codes,
        labelOf: (code) => code,
        placeholder: appLocalizations.ruleValuePickCode,
        onSelected: (code) => setState(() => _value.text = code),
      );
    } else {
      final processes = _type == RuleAction.PROCESS_NAME
          ? widget.processNames
          : const <String>[];
      input = RuleEditField(
        controller: _value,
        semanticLabel: label,
        monospace: true,
        autofocus: true,
        error: shownError != null,
        onChanged: _onValueChanged,
        onSubmitted: _save,
        trailing: _type != RuleAction.PROCESS_NAME
            ? null
            : PopupAnchor(
                placement: PopupPlacement.belowAnchorEnd,
                targetBuilder: (open) => Tooltip(
                  message: appLocalizations.ruleValuePickProcess,
                  child: Semantics(
                    button: true,
                    label: appLocalizations.ruleValuePickProcess,
                    child: GestureDetector(
                      onTap: open,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: GlyphIcon(
                            AppGlyphs.chevronDown,
                            size: 14,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                popupBuilder: (_) => PopupMenu(
                  maxVisibleItems: 10,
                  items: processes.isEmpty
                      ? [
                          PopupMenuItem(
                            label: appLocalizations.ruleValueNoProcesses,
                          ),
                        ]
                      : [
                          for (final name in processes)
                            PopupMenuItem(
                              label: name,
                              onPressed: () => setState(() {
                                _value.text = name;
                                _showValueError = true;
                              }),
                            ),
                        ],
                ),
              ),
      );
    }
    final help = _helpOf(context, _type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, label),
        input,
        Semantics(
          liveRegion: true,
          child: shownError != null
              ? _note(
                  context,
                  _valueErrorText(context, shownError),
                  color: _errorInk,
                )
              : duplicate != null
              ? _note(
                  context,
                  appLocalizations.ruleDuplicate(
                    duplicate.$1 + 1,
                    ruleTargetLabel(context, duplicate.$2.ruleTarget ?? ''),
                  ),
                  color: _warnInk,
                )
              : help == null
              ? const SizedBox.shrink()
              : _note(context, help),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final rule = widget.rule;
    final number = widget.number;
    final subtitle = _editing && number != null
        ? appLocalizations.ruleEditPosition(number)
        : widget.coreRunning
        ? appLocalizations.addRuleSubtitle(widget.profileLabel)
        : appLocalizations.ruleEditCoreStopped;
    final duplicate = _editing ? null : _duplicate;
    final target = _target ?? '';
    final value = _normalized;
    final preview = value.isEmpty
        ? addedRuleLine(_type, '…', target)
        : _build().rawValue;
    final primary = _busy && !_deleting
        ? (_editing
              ? appLocalizations.ruleEditSaving
              : appLocalizations.addRuleAdding)
        : duplicate != null
        ? appLocalizations.ruleUpdateGroup
        : _editing
        ? appLocalizations.save
        : appLocalizations.add;
    return LayoutBuilder(
      builder: (context, _) {
        final narrow = MediaQuery.sizeOf(context).width - 32 < 440;
        return RuleEditFrame(
          title: rule == null
              ? appLocalizations.ruleEditAddTitle
              : appLocalizations.ruleEditTitle,
          subtitle: subtitle,
          width: 460,
          busy: _busy,
          deleting: _deleting,
          error: _error,
          primaryLabel: primary,
          onPrimary: _canSave ? _save : null,
          onDelete: _editing && widget.onDelete != null ? _delete : null,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label(context, appLocalizations.ruleTypeLabel),
                _buildType(context, narrow),
              ],
            ),
            _buildValue(context),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label(context, appLocalizations.addRuleTarget),
                RuleEditDropdown<String>(
                  value: _target,
                  items: widget.targets,
                  labelOf: (target) => ruleTargetLabel(context, target),
                  startsSection: (target) => target == 'DIRECT',
                  onSelected: (target) => setState(() => _target = target),
                ),
              ],
            ),
            if (!_editing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label(context, appLocalizations.rulePositionLabel),
                  narrow
                      ? RuleEditDropdown<bool>(
                          value: _last,
                          items: const [false, true],
                          labelOf: (last) => last
                              ? appLocalizations.rulePositionLast
                              : appLocalizations.rulePositionFirst,
                          onSelected: (last) => setState(() => _last = last),
                        )
                      : SegmentedControl<bool>(
                          segments: [
                            (false, appLocalizations.rulePositionFirst),
                            (true, appLocalizations.rulePositionLast),
                          ],
                          value: _last,
                          onChanged: (last) => setState(() => _last = last),
                        ),
                ],
              ),
            RuleEditPreview(text: preview, placeholder: value.isEmpty),
          ],
        );
      },
    );
  }
}

// The rule set dialog

String ruleSetBehaviorLabel(
  BuildContext context,
  RuleProviderBehavior behavior,
) {
  final appLocalizations = context.appLocalizations;
  return switch (behavior) {
    RuleProviderBehavior.domain => appLocalizations.ruleSetBehaviorDomain,
    RuleProviderBehavior.ipcidr => appLocalizations.ruleSetBehaviorIpcidr,
    RuleProviderBehavior.classical => appLocalizations.ruleSetBehaviorClassical,
  };
}

String ruleSetFormatLabel(BuildContext context, RuleProviderFormat format) {
  return switch (format) {
    RuleProviderFormat.yaml => 'YAML',
    RuleProviderFormat.text => context.appLocalizations.ruleSetFormatText,
    RuleProviderFormat.mrs => 'MRS',
  };
}

String ruleSetIntervalLabel(BuildContext context, int interval) {
  final appLocalizations = context.appLocalizations;
  return switch (interval) {
    21600 => appLocalizations.ruleSetEvery6Hours,
    86400 => appLocalizations.ruleSetDaily,
    604800 => appLocalizations.ruleSetWeekly,
    0 => appLocalizations.ruleSetNeverUpdate,
    _ => appLocalizations.ruleSetEverySeconds(interval),
  };
}

String ruleSetCheckFailureText(BuildContext context, RuleSetCheck check) {
  final appLocalizations = context.appLocalizations;
  return switch (check.failure) {
    RuleSetCheckFailure.notFound => appLocalizations.ruleSetCheckNotFound,
    RuleSetCheckFailure.timeout => appLocalizations.ruleSetCheckTimeout,
    RuleSetCheckFailure.network => appLocalizations.ruleSetCheckNetwork(
      check.detail,
    ),
    RuleSetCheckFailure.notRuleSet => appLocalizations.ruleSetCheckNotRuleSet,
    RuleSetCheckFailure.unknown || null => appLocalizations.ruleSetCheckUnknown,
  };
}

/// Adds an added rule set from a link, or edits [set]. The link is
/// downloaded and read as it is typed; the set saves only once that check
/// passes, and closes once the Core loaded it.
class RuleSetEditDialog extends StatefulWidget {
  final String profileLabel;
  final bool coreRunning;
  final List<String> targets;

  /// Names another set already takes: the profile's own, the other added.
  final Set<String> takenNames;

  final AddedRuleSet? set;
  final String? setTarget;
  final int? number;
  final String? initialTarget;

  final Future<RuleSetCheck> Function(String url) onCheck;
  final RuleSetSaver onSave;
  final Future<RuleEditSave> Function()? onDelete;
  final Future<String?> Function()? onRefresh;

  const RuleSetEditDialog({
    super.key,
    required this.profileLabel,
    required this.coreRunning,
    required this.targets,
    required this.takenNames,
    required this.onCheck,
    required this.onSave,
    this.set,
    this.setTarget,
    this.number,
    this.initialTarget,
    this.onDelete,
    this.onRefresh,
  });

  @override
  State<RuleSetEditDialog> createState() => _RuleSetEditDialogState();
}

class _RuleSetEditDialogState extends State<RuleSetEditDialog> {
  late final TextEditingController _url;
  late final TextEditingController _name;
  late RuleProviderBehavior _behavior;
  late RuleProviderFormat _format;
  late int _interval;
  late String? _target;
  bool _nameEdited = false;
  RuleSetCheck? _check;
  bool _checking = false;
  int _checkSerial = 0;
  Timer? _checkTimer;
  bool _busy = false;
  bool _deleting = false;
  bool _refreshing = false;
  String? _refreshNote;
  String? _error;

  bool get _editing => widget.set != null;

  @override
  void initState() {
    super.initState();
    final set = widget.set;
    _url = TextEditingController(text: set?.url ?? '');
    _name = TextEditingController(text: set?.name ?? '');
    _nameEdited = set != null;
    _behavior = set?.behavior ?? RuleProviderBehavior.domain;
    _format = set?.format ?? RuleProviderFormat.yaml;
    _interval = set?.interval ?? defaultAddedRuleSetInterval;
    final wanted = widget.setTarget ?? widget.initialTarget;
    _target = wanted != null && widget.targets.contains(wanted)
        ? wanted
        : widget.targets.firstOrNull;
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _urlText => _url.text.trim();

  bool get _urlUnchanged => _editing && _urlText == widget.set!.url;

  bool get _urlValid => isRuleSetUrl(_urlText);

  void _onUrlChanged(String text) {
    _checkTimer?.cancel();
    _checkSerial++;
    setState(() {
      _check = null;
      _checking = false;
      if (!_nameEdited) _name.text = ruleSetNameOf(text);
    });
    if (_urlUnchanged || !_urlValid) return;
    _checkTimer = Timer(_checkDelay, _runCheck);
  }

  Future<void> _runCheck() async {
    final serial = ++_checkSerial;
    final url = _urlText;
    setState(() => _checking = true);
    final check = await widget.onCheck(url);
    if (!mounted || serial != _checkSerial) return;
    setState(() {
      _checking = false;
      _check = check;
      if (check.ok) {
        if (check.behavior case final behavior?) _behavior = behavior;
        if (check.format case final format?) _format = format;
      }
    });
  }

  AddedRuleSet _build() {
    final set = widget.set;
    return AddedRuleSet(
      id: set?.id ?? snowflake.id,
      profileId: set?.profileId ?? 0,
      name: _name.text.trim(),
      url: _urlText,
      behavior: _behavior,
      format: _format,
      interval: _interval,
    );
  }

  String? get _nameError {
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    if (!isRuleSetName(name)) {
      return context.appLocalizations.ruleSetNameInvalid;
    }
    if (widget.takenNames.contains(name)) {
      return context.appLocalizations.ruleSetNameTaken;
    }
    return null;
  }

  bool get _checked => _urlUnchanged || (_check?.ok ?? false);

  bool get _changed {
    final set = widget.set;
    if (set == null) return true;
    final built = _build();
    return built.name != set.name ||
        built.url != set.url ||
        built.behavior != set.behavior ||
        built.format != set.format ||
        built.interval != set.interval ||
        _target != widget.setTarget;
  }

  bool get _canSave =>
      !_busy &&
      _urlValid &&
      _checked &&
      !_checking &&
      _name.text.trim().isNotEmpty &&
      _nameError == null &&
      ruleSetFormatFits(_behavior, _format) &&
      _target != null &&
      _changed;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final set = _build();
    final result = await widget.onSave(
      set,
      target: _target!,
      check: _urlUnchanged ? null : _check,
    );
    if (!mounted) return;
    if (result.error case final error?) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop<RuleEditOutcome>((
      text: 'RULE-SET,${set.name},$_target',
      name: set.name,
      ruleId: result.ruleId,
      pending: result.pending,
      isSet: true,
      edited: _editing,
      deleted: false,
    ));
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    final set = widget.set;
    if (onDelete == null || set == null) return;
    final text = 'RULE-SET,${set.name},${widget.setTarget ?? ''}';
    if (!await confirmRuleDelete(context, text: text, setName: set.name)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _deleting = true;
      _error = null;
    });
    final result = await onDelete();
    if (!mounted) return;
    if (result.error case final error?) {
      setState(() {
        _busy = false;
        _deleting = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop<RuleEditOutcome>((
      text: text,
      name: set.name,
      ruleId: null,
      pending: result.pending,
      isSet: true,
      edited: false,
      deleted: true,
    ));
  }

  Future<void> _refresh() async {
    final onRefresh = widget.onRefresh;
    if (onRefresh == null || _refreshing) return;
    setState(() {
      _refreshing = true;
      _refreshNote = null;
    });
    final error = await onRefresh();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _refreshNote = error ?? context.appLocalizations.ruleSetRefreshed;
    });
  }

  Widget _buildUrlStatus(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final check = _check;
    Widget status;
    if (_urlText.isNotEmpty && !_urlValid) {
      status = _note(
        context,
        appLocalizations.ruleSetUrlInvalid,
        color: _errorInk,
      );
    } else if (_checking) {
      status = _note(
        context,
        appLocalizations.ruleSetChecking,
        lead: const ActivityIndicator(size: 12),
      );
    } else if (check != null && !check.ok) {
      status = _note(
        context,
        ruleSetCheckFailureText(context, check),
        color: _errorInk,
      );
    } else if (check != null) {
      final kind = check.behavior == null
          ? null
          : ruleSetBehaviorLabel(context, check.behavior!);
      final format = ruleSetFormatLabel(
        context,
        check.format ?? RuleProviderFormat.yaml,
      );
      status = _note(
        context,
        kind != null && check.count != null
            ? appLocalizations.ruleSetCheckOk(
                kind,
                format,
                groupedCountOf(check.count!),
              )
            : appLocalizations.ruleSetCheckOkUncounted(format),
        color: _okInk,
        lead: const GlyphIcon(AppGlyphs.checkCircle, size: 12, color: _okInk),
      );
    } else if (_urlText.isEmpty) {
      status = _note(context, appLocalizations.ruleSetUrlHelp);
    } else {
      status = const SizedBox.shrink();
    }
    if (_editing && widget.onRefresh != null) {
      status = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _refreshNote == null
                ? status
                : _note(context, _refreshNote!),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: GestureDetector(
              onTap: _refreshing ? null : _refresh,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Semantics(
                  button: true,
                  child: Text(
                    appLocalizations.ruleSetUpdateNow,
                    style: AppTextStyle.caption1
                        .of(context, emphasized: true)
                        .copyWith(
                          color: _refreshing
                              ? context.colorScheme.onSurfaceVariant
                              : context.colorScheme.primary,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(liveRegion: true, child: status);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final number = widget.number;
    final subtitle = _editing && number != null
        ? appLocalizations.ruleSetEditPosition(number)
        : widget.coreRunning
        ? appLocalizations.addRuleSubtitle(widget.profileLabel)
        : appLocalizations.ruleEditCoreStopped;
    final urlError =
        (_urlText.isNotEmpty && !_urlValid) || (_check != null && !_check!.ok);
    final nameError = _nameError;
    final check = _check;
    final detected = check != null && check.ok ? check.behavior : null;
    final mismatch = detected != null && detected != _behavior;
    final formatError = !ruleSetFormatFits(_behavior, _format);
    final name = _name.text.trim();
    final target = _target ?? '';
    final primary = _busy && !_deleting
        ? (_editing
              ? appLocalizations.ruleEditSaving
              : appLocalizations.addRuleAdding)
        : _editing
        ? appLocalizations.save
        : appLocalizations.add;
    final narrow = MediaQuery.sizeOf(context).width - 32 < 440;
    final interval = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, appLocalizations.ruleSetIntervalLabel),
        RuleEditDropdown<int>(
          value: _interval,
          items: [
            ...addedRuleSetIntervals,
            if (!addedRuleSetIntervals.contains(_interval)) _interval,
          ],
          labelOf: (value) => ruleSetIntervalLabel(context, value),
          onSelected: (value) => setState(() => _interval = value),
        ),
      ],
    );
    final group = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, appLocalizations.addRuleTarget),
        RuleEditDropdown<String>(
          value: _target,
          items: widget.targets,
          labelOf: (target) => ruleTargetLabel(context, target),
          startsSection: (target) => target == 'DIRECT',
          onSelected: (target) => setState(() => _target = target),
        ),
      ],
    );
    return RuleEditFrame(
      title: _editing
          ? appLocalizations.ruleSetEditTitle
          : appLocalizations.ruleSetAddTitle,
      subtitle: subtitle,
      width: 480,
      busy: _busy,
      deleting: _deleting,
      error: _error,
      primaryLabel: primary,
      onPrimary: _canSave ? _save : null,
      onDelete: _editing && widget.onDelete != null ? _delete : null,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(context, appLocalizations.ruleSetUrlLabel),
            RuleEditField(
              controller: _url,
              semanticLabel: appLocalizations.ruleSetUrlLabel,
              hint: 'https://',
              monospace: true,
              autofocus: !_editing,
              error: urlError,
              onChanged: _onUrlChanged,
              onSubmitted: _save,
            ),
            _buildUrlStatus(context),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(context, appLocalizations.ruleSetNameLabel),
            RuleEditField(
              controller: _name,
              semanticLabel: appLocalizations.ruleSetNameLabel,
              monospace: true,
              error: nameError != null,
              onChanged: (_) => setState(() => _nameEdited = true),
              onSubmitted: _save,
            ),
            if (nameError != null)
              Semantics(
                liveRegion: true,
                child: _note(context, nameError, color: _errorInk),
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(context, appLocalizations.ruleSetBehaviorLabel),
            narrow
                ? RuleEditDropdown<RuleProviderBehavior>(
                    value: _behavior,
                    items: RuleProviderBehavior.values,
                    labelOf: (value) => ruleSetBehaviorLabel(context, value),
                    onSelected: (value) => setState(() => _behavior = value),
                  )
                : SegmentedControl<RuleProviderBehavior>(
                    segments: [
                      for (final value in RuleProviderBehavior.values)
                        (value, ruleSetBehaviorLabel(context, value)),
                    ],
                    value: _behavior,
                    onChanged: (value) => setState(() => _behavior = value),
                  ),
            if (formatError)
              _note(
                context,
                appLocalizations.ruleSetMrsNeedsKind,
                color: _errorInk,
              )
            else if (mismatch)
              _note(
                context,
                appLocalizations.ruleSetBehaviorMismatch,
                color: _warnInk,
              )
            else if (detected != null)
              _note(context, appLocalizations.ruleSetBehaviorDetected),
          ],
        ),
        if (narrow) ...[
          interval,
          group,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(child: interval),
              Expanded(child: group),
            ],
          ),
        RuleEditPreview(
          text: 'RULE-SET,${name.isEmpty ? '…' : name},$target',
          placeholder: name.isEmpty,
        ),
      ],
    );
  }
}

/// A count with its thousands grouped.
String groupedCountOf(int count) {
  final digits = '$count';
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// [wide] while it fits on one line, else [stacked]. Only the one shown
/// paints, takes taps and focus, and is read out.
class AdaptiveActions extends StatefulWidget {
  const AdaptiveActions({super.key, required this.wide, required this.stacked});

  final Widget wide;
  final Widget stacked;

  @override
  State<AdaptiveActions> createState() => _AdaptiveActionsState();
}

/// One action in [AdaptiveActions]' layouts; the same [id] marks the same
/// action in both, so focus follows it from one layout to the other.
class AdaptiveActionSlot extends StatelessWidget {
  const AdaptiveActionSlot({super.key, required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _AdaptiveActionsState extends State<AdaptiveActions> {
  bool _stacked = false;
  final _wideKey = GlobalKey();
  final _stackedKey = GlobalKey();

  void _onLayout(bool stacked) {
    if (stacked == _stacked) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || stacked == _stacked) return;
      final from = _focusedSlot(_stacked ? _stackedKey : _wideKey);
      setState(() => _stacked = stacked);
      if (from == null) return;
      // The focused action is hidden now: its counterpart takes the focus.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusDropped()) return;
        _nodeOf(_stacked ? _stackedKey : _wideKey, from)?.requestFocus();
      });
      SchedulerBinding.instance.scheduleFrame();
    });
  }

  /// Whether the focus fell back from the hidden action: on nothing, still
  /// on the hidden layout, or on a scope around the footer; not on a shown
  /// action, nor anywhere else the user has moved it since.
  bool _focusDropped() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return true;
    final hidden = (_stacked ? _wideKey : _stackedKey).currentContext;
    var inHidden = false;
    focused.visitAncestorElements((element) {
      if (element == hidden) {
        inHidden = true;
        return false;
      }
      return true;
    });
    if (inHidden) return true;
    var around = false;
    context.visitAncestorElements((element) {
      if (element == focused) {
        around = true;
        return false;
      }
      return true;
    });
    return around;
  }

  /// The id of the slot under [layout] holding the primary focus.
  Object? _focusedSlot(GlobalKey layout) {
    final root = layout.currentContext;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (root == null || focused == null) return null;
    Object? id;
    var inside = false;
    focused.visitAncestorElements((element) {
      if (id == null && element.widget is AdaptiveActionSlot) {
        id = (element.widget as AdaptiveActionSlot).id;
      }
      if (element == root) {
        inside = true;
        return false;
      }
      return true;
    });
    return inside ? id : null;
  }

  /// The first focus node inside the slot [id] under [layout].
  FocusNode? _nodeOf(GlobalKey layout, Object id) {
    final root = layout.currentContext as Element?;
    if (root == null) return null;
    FocusNode? node;
    void search(Element element, bool inSlot) {
      if (node != null) return;
      final widget = element.widget;
      final slot = inSlot || (widget is AdaptiveActionSlot && widget.id == id);
      if (slot && widget is Focus && widget.focusNode != null) {
        node = widget.focusNode;
        return;
      }
      if (slot && widget is Focus) {
        element.visitChildElements((child) {
          node ??= Focus.maybeOf(child, scopeOk: true, createDependency: false);
        });
        if (node != null) return;
      }
      element.visitChildElements((child) => search(child, slot));
    }

    search(root, false);
    return node;
  }

  @override
  Widget build(BuildContext context) {
    Widget hidden(Widget child, bool hide) => ExcludeFocus(
      excluding: hide,
      child: ExcludeSemantics(excluding: hide, child: child),
    );
    return _ActionsSwitch(
      onLayout: _onLayout,
      children: [
        hidden(KeyedSubtree(key: _wideKey, child: widget.wide), _stacked),
        hidden(
          KeyedSubtree(key: _stackedKey, child: widget.stacked),
          !_stacked,
        ),
      ],
    );
  }
}

class _ActionsSwitch extends MultiChildRenderObjectWidget {
  const _ActionsSwitch({required this.onLayout, required super.children});

  final ValueChanged<bool> onLayout;

  @override
  MultiChildRenderObjectElement createElement() => _ActionsSwitchElement(this);

  @override
  _RenderActionsSwitch createRenderObject(BuildContext context) =>
      _RenderActionsSwitch(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderActionsSwitch renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

/// Tells the framework (and so tests' finders) that only the shown actions
/// are on stage.
class _ActionsSwitchElement extends MultiChildRenderObjectElement {
  _ActionsSwitchElement(super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final stacked = (renderObject as _RenderActionsSwitch)._stacked;
    final shown = children.toList();
    if (shown.length != 2) return super.debugVisitOnstageChildren(visitor);
    visitor(stacked ? shown.last : shown.first);
  }
}

class _ActionsSwitchData extends ContainerBoxParentData<RenderBox> {}

class _RenderActionsSwitch extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ActionsSwitchData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ActionsSwitchData> {
  _RenderActionsSwitch(this.onLayout);

  ValueChanged<bool> onLayout;
  bool _stacked = false;

  RenderBox get _wide => firstChild!;
  RenderBox get _stack => lastChild!;
  RenderBox get _shown => _stacked ? _stack : _wide;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ActionsSwitchData) {
      child.parentData = _ActionsSwitchData();
    }
  }

  bool _stacks(double width) =>
      width.isFinite && _wide.getMaxIntrinsicWidth(double.infinity) > width;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _stack.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _wide.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _stacks(width)
      ? _stack.getMinIntrinsicHeight(width)
      : _wide.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _stacks(width)
      ? _stack.getMaxIntrinsicHeight(width)
      : _wide.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      (_stacks(constraints.maxWidth) ? _stack : _wide).getDryLayout(
        constraints,
      );

  @override
  void performLayout() {
    _stacked = _stacks(constraints.maxWidth);
    final hidden = _stacked ? _wide : _stack;
    // Laid out to keep its state, never shown.
    hidden.layout(constraints.loosen());
    _shown.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(_shown.size);
    onLayout(_stacked);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(_shown, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _shown.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_shown);
  }
}

/// Keeps [footer] in view under [body] when the dialog runs out of height:
/// once the dialog's own scroll view would scroll, [body] alone scrolls in
/// the height left.
class PinnedFooter extends StatefulWidget {
  const PinnedFooter({
    super.key,
    required this.body,
    required this.footer,
    this.minBodyHeight,
  });

  final Widget body;
  final Widget footer;

  /// When set, [body] keeps this much and a taller [footer] scrolls itself.
  final double? minBodyHeight;

  @override
  State<PinnedFooter> createState() => _PinnedFooterState();
}

class _PinnedFooterState extends State<PinnedFooter> {
  double? _height;
  Size? _screen;
  TextScaler? _scaler;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screen = MediaQuery.sizeOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    // Measured again for another window or text size.
    if (screen != _screen || scaler != _scaler) {
      _screen = screen;
      _scaler = scaler;
      _height = null;
    }
  }

  void _measure() {
    if (!mounted) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || !position.hasContentDimensions) return;
    if (position.maxScrollExtent > 0) {
      final height = position.viewportDimension;
      if (height != _height) setState(() => _height = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
    final height = _height;
    if (height == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [widget.body, widget.footer],
      );
    }
    final minBody = widget.minBodyHeight;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(child: SingleChildScrollView(child: widget.body)),
          if (minBody == null)
            widget.footer
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(0, height - minBody),
              ),
              child: SingleChildScrollView(child: widget.footer),
            ),
        ],
      ),
    );
  }
}
