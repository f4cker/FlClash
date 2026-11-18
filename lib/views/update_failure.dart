import 'package:fl_clash/common/common.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// An update failure: the plain message, with codes and paths folded under a
/// Details toggle.
class UpdateFailureBody extends StatefulWidget {
  final String message;
  final String details;

  const UpdateFailureBody({
    super.key,
    required this.message,
    required this.details,
  });

  @override
  State<UpdateFailureBody> createState() => _UpdateFailureBodyState();
}

class _UpdateFailureBodyState extends State<UpdateFailureBody> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(widget.message),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _open = !_open),
          child: Text(context.appLocalizations.macUpdateDetails),
        ),
        if (_open)
          SelectableText(
            widget.details,
            style: AppTextStyle.caption1.of(context),
          ),
      ],
    );
  }
}
