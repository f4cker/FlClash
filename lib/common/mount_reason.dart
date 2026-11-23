import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/l10n/l10n.dart';

final _mountSourcePattern = RegExp(
  r'mount source (\d+) is (missing|read-error|invalid|unsupported)',
);

const _mountReasonMaxLength = 160;

bool isMountSourceProblem(String reason) =>
    _mountSourcePattern.hasMatch(reason);

/// One short line naming the subscription, else the reason with URLs cut.
String mountRejectedReason(
  String reason,
  AppLocalizations appLocalizations, {
  String? Function(int id)? sourceName,
}) {
  final match = _mountSourcePattern.firstMatch(reason);
  final id = match == null ? null : int.tryParse(match[1]!);
  final name = id == null ? null : sourceName?.call(id);
  if (match != null && name != null && name.isNotEmpty) {
    final shown = redactUrls(name);
    return switch (match[2]) {
      'missing' => appLocalizations.mountSourceMissingReason(shown),
      'read-error' => appLocalizations.mountSourceReadErrorReason(shown),
      'invalid' => appLocalizations.mountSourceInvalidReason(shown),
      _ => appLocalizations.mountSourceUnsupportedReason(shown),
    };
  }
  final line = redactUrls(reason.trim()).split('\n').first.trim();
  return line.length > _mountReasonMaxLength
      ? '${line.substring(0, _mountReasonMaxLength)}…'
      : line;
}

const _mountKeptLog = 'mounted profile rejected, the running config stays:';

bool isMountKeptLog(String payload) => payload.contains(_mountKeptLog);
