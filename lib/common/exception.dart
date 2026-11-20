final class MessageException implements Exception {
  final String message;

  const MessageException(this.message);

  @override
  String toString() => message;
}

enum RestoreBlockedReason {
  mountPending,
  overrideWithMountGuards,
  mergeWithMountGuards,
  mergeWithMountLinks,
}

/// Still a [StateError], so callers of the database guards keep working.
final class RestoreBlockedError extends StateError {
  final RestoreBlockedReason reason;

  RestoreBlockedError(this.reason)
    : super(switch (reason) {
        RestoreBlockedReason.mountPending =>
          'Cannot restore while a mount operation is pending',
        RestoreBlockedReason.overrideWithMountGuards =>
          'Cannot override restore while mount guards exist',
        RestoreBlockedReason.mergeWithMountGuards =>
          'Cannot merge profiles with mount guards',
        RestoreBlockedReason.mergeWithMountLinks =>
          'Cannot merge profiles with mount links',
      });
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
