import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/services.dart';

/// What the native installer answered: `ok`, or a code the app explains.
final class MacUpdateResult {
  final String code;
  final String? staged;
  final String detail;

  /// The launcher's version record could not be read before the update; the
  /// update cannot repair that record.
  final bool recordUnreadable;

  const MacUpdateResult(
    this.code, {
    this.staged,
    this.detail = '',
    this.recordUnreadable = false,
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
      detail: answer['detail'] as String? ?? '',
      recordUnreadable: answer['recordUnreadable'] == true,
    );
  }
}

class MacUpdater {
  const MacUpdater();

  static const _channel = MethodChannel('$packageName/mac_updater');

  /// Verifies the archive against the signed manifest again, unpacks it next
  /// to the installed app and checks the result; nothing is replaced yet.
  Future<MacUpdateResult> prepare({
    required Uint8List manifest,
    required String archive,
  }) async => _call('prepare', {'manifest': manifest, 'archive': archive});

  /// Swaps the staged app in, checks the installed result, and swaps back
  /// when that fails. The Core must already be stopped.
  Future<MacUpdateResult> install(String staged) =>
      _call('install', {'staged': staged});

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
