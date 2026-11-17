import 'package:fl_clash/common/common.dart';
import 'package:flutter/widgets.dart';

/// The name a rule target shows: the built-in ones in words.
String ruleTargetLabel(BuildContext context, String target) {
  final appLocalizations = context.appLocalizations;
  return switch (target.toUpperCase()) {
    'DIRECT' => appLocalizations.direct,
    'REJECT' || 'REJECT-DROP' => appLocalizations.ruleReject,
    _ => target,
  };
}
