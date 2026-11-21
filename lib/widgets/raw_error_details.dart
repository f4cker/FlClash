import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';

/// 查看原始错误: the Core's or the system's own words for an error the app
/// has already said in the user's language, untranslated and as they came.
/// Collapsed until the user opens it, since they may name paths, rules or
/// URLs; nothing is shown for a [raw] that is null or blank.
///
/// Opened, the text is selectable, for a report the user writes. Key it by
/// the error so a new one starts collapsed.
class RawErrorDetails extends StatefulWidget {
  const RawErrorDetails({super.key, required this.raw, this.color});

  final String? raw;

  /// The ink of the toggle and the text; the ambient text color when null.
  final Color? color;

  @override
  State<RawErrorDetails> createState() => _RawErrorDetailsState();
}

class _RawErrorDetailsState extends State<RawErrorDetails> {
  bool _open = false;

  @override
  void didUpdateWidget(RawErrorDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raw != widget.raw) _open = false;
  }

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final raw = widget.raw;
    if (raw == null || raw.trim().isEmpty) return const SizedBox.shrink();
    final label = context.appLocalizations.viewOriginalError;
    final style = AppTextStyle.caption1.of(context);
    final color =
        widget.color ?? DefaultTextStyle.of(context).style.color ?? style.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: label,
          onTap: _toggle,
          excludeSemantics: true,
          child: TextButton(
            style: const ButtonStyle(
              padding: EdgeInsets.zero,
              minimumSize: Size(0, 24),
              tapTargetSize: TapTargetSize.shrinkWrap,
            ),
            onPressed: _toggle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                GlyphIcon(
                  _open ? AppGlyphs.chevronDown : AppGlyphs.chevronForward,
                  size: 12,
                  color: color,
                ),
                Flexible(
                  child: Text(
                    label,
                    style: style.copyWith(
                      color: color,
                      decoration: TextDecoration.underline,
                      decorationColor: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          SelectableText(
            raw,
            style: style.toJetBrainsMono.copyWith(color: color),
          ),
      ],
    );
  }
}
