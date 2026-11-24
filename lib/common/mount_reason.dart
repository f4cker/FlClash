import 'package:fl_clash/common/config_rejection.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/common/string.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';

final _mountSourcePattern = RegExp(
  r'mount source (\d+) is (missing|read-error|invalid|unsupported)',
);

const _mountReasonMaxLength = 160;

String mountSourceReason(
  MountSourceStatus status,
  String name,
  AppLocalizations appLocalizations,
) {
  final shown = redactUrls(name);
  return switch (status) {
    MountSourceStatus.missing => appLocalizations.mountSourceMissingReason(
      shown,
    ),
    MountSourceStatus.readError => appLocalizations.mountSourceReadErrorReason(
      shown,
    ),
    MountSourceStatus.invalid => appLocalizations.mountSourceInvalidReason(
      shown,
    ),
    _ => appLocalizations.mountSourceUnsupportedReason(shown),
  };
}

/// Without the name, for a line that already shows it.
String mountSourceShortReason(
  MountSourceStatus status,
  AppLocalizations appLocalizations,
) => switch (status) {
  MountSourceStatus.missing => appLocalizations.mountSkipShortMissing,
  MountSourceStatus.readError => appLocalizations.mountSkipShortReadError,
  MountSourceStatus.invalid => appLocalizations.mountSkipShortInvalid,
  _ => appLocalizations.mountSkipShortUnsupported,
};

List<String> mountSkipReasons(
  List<MountSkip> skips,
  String? Function(int id) sourceName,
  AppLocalizations appLocalizations,
) => [
  for (final skip in skips)
    mountSourceReason(
      skip.status,
      sourceName(skip.sourceId).takeFirstValid(['#${skip.sourceId}']),
      appLocalizations,
    ),
];

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
    final status = switch (match[2]) {
      'missing' => MountSourceStatus.missing,
      'read-error' => MountSourceStatus.readError,
      'invalid' => MountSourceStatus.invalid,
      _ => MountSourceStatus.unsupported,
    };
    return mountSourceReason(status, name, appLocalizations);
  }
  if (configRejectionMessage(reason, appLocalizations) case final message?) {
    return message;
  }
  final line = redactUrls(reason.trim()).split('\n').first.trim();
  return line.length > _mountReasonMaxLength
      ? '${line.substring(0, _mountReasonMaxLength)}…'
      : line;
}

const _mountKeptLog = 'mounted profile rejected, the running config stays:';

bool isMountKeptLog(String payload) => payload.contains(_mountKeptLog);
