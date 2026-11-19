import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/services.dart';

/// What the native installer answered: `ok`, or a code the app explains.
final class MacUpdateResult {
  final String code;
  final String? staged;
  final String? ticket;
  final String detail;

  /// The launcher's version record could not be read before the update; the
  /// update cannot repair that record.
  final bool recordUnreadable;

  /// After a failure: the installed app was confirmed untouched (the same
  /// directory with the same build is still in place).
  final bool unchanged;

  /// After `rollbackFailed`: where the previous app was kept, and whether an
  /// app with its build was found there after the move.
  final String? rescued;
  final bool rescueVerified;

  const MacUpdateResult(
    this.code, {
    this.staged,
    this.ticket,
    this.detail = '',
    this.recordUnreadable = false,
    this.unchanged = false,
    this.rescued,
    this.rescueVerified = false,
  });

  bool get ok => code == 'ok';

  /// Nothing wrong with the update, only this Mac cannot swap it in place:
  /// the verified app is shown in Finder instead.
  bool get needsManualInstall =>
      code == 'notWritable' || code == 'notInApplications';

  static MacUpdateResult fromAnswer(Object? answer) {
    if (answer is! Map) return const MacUpdateResult('failed');
    final code = answer['code'];
    return MacUpdateResult(
      code is String ? code : 'failed',
      staged: answer['staged'] as String?,
      ticket: answer['ticket'] as String?,
      detail: answer['detail'] as String? ?? '',
      recordUnreadable: answer['recordUnreadable'] == true,
      unchanged: answer['unchanged'] == true,
      rescued: answer['rescued'] as String?,
      rescueVerified: answer['rescueVerified'] == true,
    );
  }

  /// For the details view: the code and what the installer said.
  String get details => [
    code,
    if (detail.isNotEmpty) detail,
    if (rescued case final rescued?) 'previous app: $rescued',
  ].join('\n');
}

/// The ready dialog. The version record hint belongs only to a prepared,
/// installable update.
String macUpdateReadyText(
  MacUpdateResult prepared,
  String version,
  AppLocalizations l10n,
) => [
  l10n.macUpdateReadyMessage(version),
  if (prepared.ok && prepared.staged != null && prepared.recordUnreadable)
    l10n.macUpdateRecordHint,
].join('\n\n');

/// What the user reads: a state is stated as fact only when the installer
/// confirmed it (restored, unchanged, kept at a location).
String macUpdateMessage(MacUpdateResult result, AppLocalizations l10n) {
  return switch (result.code) {
    'notWritable' => l10n.macUpdateNotWritable,
    'notInApplications' => l10n.macUpdateNotInApplications,
    'notConfigured' => l10n.macUpdateNotConfigured,
    'notNewer' => l10n.macUpdateNotNewer,
    'launcherChanged' => l10n.macUpdateLauncherChanged,
    'helperOlder' => l10n.macUpdateHelperOlder,
    'rejected' => l10n.macUpdateRejected,
    'coreStopFailed' => l10n.macUpdateCoreStopFailed,
    'rolledBack' when result.unchanged => l10n.macUpdateRolledBack,
    'rollbackFailed' => switch (result) {
      MacUpdateResult(rescueVerified: true, rescued: final location?) =>
        l10n.macUpdateRollbackFailed(location),
      _ => l10n.macUpdateRollbackFailedUnverified,
    },
    _ when result.unchanged => l10n.macUpdateInstallFailedUnchanged,
    _ => l10n.macUpdateInstallFailed,
  };
}

class MacUpdater {
  const MacUpdater();

  static const _channel = MethodChannel('$packageName/mac_updater');

  /// Verifies the archive against the signed manifest again, unpacks it next
  /// to the installed app and checks the result; nothing is replaced yet.
  Future<MacUpdateResult> prepare({
    required Uint8List manifest,
    required String archive,
    required bool allowBeta,
  }) async => _call('prepare', {
    'manifest': manifest,
    'archive': archive,
    'allowBeta': allowBeta,
  });

  /// Swaps the staged app in, checks the installed result, and swaps back
  /// when that fails. The Core must already be stopped.
  Future<MacUpdateResult> install(
    String staged, {
    required String ticket,
    required bool allowBeta,
  }) => _call('install', {
    'staged': staged,
    'ticket': ticket,
    'allowBeta': allowBeta,
  });

  Future<void> invalidate() async {
    await _call('invalidate', const {});
  }

  Future<MacInstalledIdentity?> identity() async {
    try {
      final answer = await _channel.invokeMethod<Object?>('identity');
      return MacInstalledIdentity.fromAnswer(answer);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Opens the installed app once this process has exited.
  Future<MacUpdateResult> relaunchAfterExit() => _call('relaunch', const {});

  /// Unpacks the verified archive into Downloads and shows it in Finder.
  Future<MacUpdateResult> reveal({
    required String archive,
    required String version,
  }) => _call('reveal', {'archive': archive, 'version': version});

  /// Removes staged or replaced copies a previous update left behind.
  Future<void> cleanup() async {
    await _call('cleanup', const {});
  }

  Future<MacUpdateResult> _call(
    String method,
    Map<String, Object> arguments,
  ) async {
    try {
      return MacUpdateResult.fromAnswer(
        await _channel.invokeMethod<Object?>(method, arguments),
      );
    } on PlatformException catch (error) {
      return MacUpdateResult('failed', detail: compactError(error));
    } on MissingPluginException catch (error) {
      return MacUpdateResult('failed', detail: compactError(error));
    }
  }
}

final MacUpdater? macUpdater = Platform.isMacOS ? const MacUpdater() : null;
