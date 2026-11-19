import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/release_asset.dart' as package;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:path/path.dart';

const appReleaseLine = package.ReleaseLine.dev;

String appVersionLabel(String version, String build) =>
    build.isEmpty ? version : '$version+$build';

typedef VersionLabelParts = ({String version, String? build});

/// Splits a `version+build` label, as [appVersionLabel] and the release
/// identities write it, for display.
VersionLabelParts versionLabelParts(String label) {
  final plus = label.indexOf('+');
  return plus < 0
      ? (version: label, build: null)
      : (version: label.substring(0, plus), build: label.substring(plus + 1));
}

/// How a person reads a `version+build` label: `1.0.0 (2026111903)`. Only for
/// display; comparisons and stored values keep the `+` form.
String displayVersionLabel(String label) => switch (versionLabelParts(label)) {
  (version: final version, build: final build?) => '$version ($build)',
  (version: final version, build: null) => version,
};

sealed class UpdateDownload {
  const UpdateDownload(this.tag);

  final String tag;
}

final class UpdateDownloading extends UpdateDownload {
  const UpdateDownloading(super.tag, {this.received = 0, this.total = 0});

  final int received;

  /// Zero until the server reports a length.
  final int total;
}

final class UpdateReady extends UpdateDownload {
  const UpdateReady(super.tag, this.path);

  final String path;
}

typedef SelfUpdateAsset = ({
  package.ReleaseOs os,
  package.ReleaseArch arch,
  package.ReleaseForm? form,
  String extension,
});

@visibleForTesting
SelfUpdateAsset? Function() resolveSelfUpdateAsset = () => selfUpdateAssetFor(
  Abi.current(),
  windowsInstalled: system.isWindows && isInstalledWindowsBuild,
);

SelfUpdateAsset? get selfUpdateAsset => resolveSelfUpdateAsset();

/// Null where no single asset matches this build, so any release counts.
String? releasePlatformAssetSuffix(Abi abi, {required bool windowsInstalled}) =>
    switch (abi) {
      Abi.macosArm64 => 'macos-arm64.dmg',
      Abi.macosX64 => 'macos-amd64.dmg',
      _ => selfUpdateAssetSuffix(abi, windowsInstalled: windowsInstalled),
    };

String? get releaseAssetSuffix => releasePlatformAssetSuffix(
  Abi.current(),
  windowsInstalled: system.isWindows && isInstalledWindowsBuild,
);

sealed class UpdateCheck {
  const UpdateCheck();
}

final class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable(
    this.release, {
    this.manifest,
    this.discoveryIncomplete = false,
  });

  final bool discoveryIncomplete;

  final Map<String, dynamic> release;

  String get versionLabel => manifest == null
      ? (release['tag_name'] as String).replaceFirst(RegExp(r'^v'), '')
      : manifest!.fullVersion;

  /// Set on macOS, where the signed manifest is the release.
  final MacUpdateManifest? manifest;
}

final class UpdateUpToDate extends UpdateCheck {
  const UpdateUpToDate();
}

/// Also when the latest release carries no asset for this build.
final class UpdateNoRelease extends UpdateCheck {
  const UpdateNoRelease();
}

final class UpdateCheckFailed extends UpdateCheck {
  const UpdateCheckFailed(this.error);

  final Object error;
}

// The release matrix in .github/workflows/build.yaml builds each of these.
SelfUpdateAsset? selfUpdateAssetFor(Abi abi, {required bool windowsInstalled}) {
  SelfUpdateAsset apk(package.ReleaseArch arch) =>
      (os: package.ReleaseOs.android, arch: arch, form: null, extension: 'apk');
  SelfUpdateAsset setup(package.ReleaseArch arch) => (
    os: package.ReleaseOs.windows,
    arch: arch,
    form: package.ReleaseForm.setup,
    extension: 'exe',
  );
  return switch (abi) {
    Abi.androidArm64 => apk(package.ReleaseArch.arm64),
    Abi.androidArm => apk(package.ReleaseArch.armv7),
    Abi.androidX64 => apk(package.ReleaseArch.amd64),
    Abi.windowsX64 when windowsInstalled => setup(package.ReleaseArch.amd64),
    Abi.windowsArm64 when windowsInstalled => setup(package.ReleaseArch.arm64),
    _ => null,
  };
}

String updateAssetName(String tag, SelfUpdateAsset asset) {
  return package.releaseAssetName(
    line: appReleaseLine,
    version: package.releaseVersionOfTag(tag),
    os: asset.os,
    arch: asset.arch,
    form: asset.form,
    extension: asset.extension,
  );
}

String updateChecksumsName(String tag) {
  return package.releaseChecksumsName(
    appReleaseLine,
    package.releaseVersionOfTag(tag),
  );
}

Uri releaseAssetUri(String tag, String name) {
  return Uri.https(
    'github.com',
    '/$updateRepository/releases/download/$tag/$name',
  );
}

final _checksumLine = RegExp(r'^([0-9a-fA-F]{64}) [ *](?:\./)?(.+)$');

String? releaseChecksum(String sums, String name) {
  for (final line in const LineSplitter().convert(sums)) {
    final match = _checksumLine.firstMatch(line.trim());
    if (match != null && match[2] == name) {
      return match[1]!.toLowerCase();
    }
  }
  return null;
}

Future<String> fileSha256(String path) {
  return Isolate.run(() async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  });
}

// The installer that relaunched the app may still hold its file open.
Future<void> clearUpdateDownloads() async {
  try {
    await app?.clearDownloads();
    await safeDeletePath(await appPath.updateDirPath);
  } on PlatformException catch (error) {
    commonPrint.log(
      'Clearing system downloads failed: ${compactError(error)}',
      logLevel: LogLevel.warning,
    );
  } on FileSystemException catch (error) {
    commonPrint.log(
      'Clearing update downloads failed: ${compactError(error)}',
      logLevel: LogLevel.warning,
    );
  }
}

// Inno Setup writes unins000.exe beside the app; the portable zip has none.
bool get isInstalledWindowsBuild {
  return File(join(appPath.executableDirPath, 'unins000.exe')).existsSync();
}

// inno_setup.iss waits for `updatefrom` to exit, then relaunches the app.
String windowsUpdateArguments(int pid) {
  return '/SILENT /SUPPRESSMSGBOXES /NORESTART /SP- /updatefrom=$pid';
}

String? selfUpdateAssetSuffix(Abi abi, {required bool windowsInstalled}) {
  return switch (abi) {
    Abi.androidArm64 => 'android-arm64-v8a.apk',
    Abi.androidArm => 'android-armeabi-v7a.apk',
    Abi.androidX64 => 'android-x86_64.apk',
    Abi.windowsX64 when windowsInstalled => 'windows-amd64-setup.exe',
    Abi.windowsArm64 when windowsInstalled => 'windows-arm64-setup.exe',
    _ => null,
  };
}

String releaseAssetName(String tag, String suffix) {
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  return '$appName-$version-$suffix';
}

final class UpdateCheckSuperseded extends UpdateCheck {
  const UpdateCheckSuperseded();
}
