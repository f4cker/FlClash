final class MessageException implements Exception {
  final String message;

  const MessageException(this.message);

  @override
  String toString() => message;
}

enum RestoreBlockedReason {
  /// A mount operation's outcome is unknown; nothing may replace its record.
  mountPending,

  /// The mounts changed after the user confirmed what the restore does to
  /// them; the confirmed list no longer holds.
  mountStateChanged,
}

/// Still a [StateError], so callers of the database guards keep working.
final class RestoreBlockedError extends StateError {
  final RestoreBlockedReason reason;

  /// The profile ids the guard found in conflict, in id order.
  final List<int> profileIds;

  RestoreBlockedError(this.reason, [this.profileIds = const []])
    : super(switch (reason) {
        RestoreBlockedReason.mountPending =>
          'Cannot restore while a mount operation is pending',
        RestoreBlockedReason.mountStateChanged =>
          'Mounts changed after the restore was confirmed',
      });
}

/// [profileIds] are the conflicting profiles that exist locally, the ones
/// the dialog can point to.
final class RestoreBlockedException extends MessageException {
  final RestoreBlockedReason reason;
  final List<int> profileIds;

  /// The label of each of [profileIds], in the same order.
  final List<String> profileNames;

  const RestoreBlockedException(
    super.message, {
    required this.reason,
    this.profileIds = const [],
    this.profileNames = const [],
  });
}

/// A restore whose rows committed but whose later [steps] did not all run.
/// Its message never says the data is unchanged.
final class RestorePartialException extends MessageException {
  final List<Object> steps;

  const RestorePartialException(super.message, {this.steps = const []});
}

final class AgeSecretKeyRequiredException implements Exception {
  const AgeSecretKeyRequiredException();
}

/// [reason] is DownloadManager's COLUMN_REASON, null without a download.
final class SystemDownloadException implements Exception {
  final int? reason;

  const SystemDownloadException(this.reason);

  @override
  String toString() => 'SystemDownloadException: $reason';
}

final class ReleaseNotVerifiedException implements Exception {
  final String name;

  const ReleaseNotVerifiedException(this.name);

  @override
  String toString() => 'ReleaseNotVerifiedException: $name';
}
