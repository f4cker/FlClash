import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
// ignore: depend_on_referenced_packages
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:path/path.dart' as p;

ExternalLibrary? loadMacosManagedNativeLibrary({
  bool managedHelper = const bool.fromEnvironment('MACOS_MANAGED_HELPER'),
  bool? isMacOS,
  bool releaseMode = kReleaseMode,
  String Function()? resolvedExecutable,
  String Function(String)? canonicalize,
  bool Function(String)? isFile,
  ExternalLibrary Function(String)? openLibrary,
}) {
  if (!managedHelper || !(isMacOS ?? Platform.isMacOS)) return null;
  if (!releaseMode) {
    throw StateError('Managed macOS native loading requires a release build');
  }

  final resolve = canonicalize ?? _canonicalize;
  final regularFile = isFile ?? _isFile;
  final executable = (resolvedExecutable ?? _resolvedExecutable)();
  final originalContents = _appContents(executable);
  final canonicalExecutable = resolve(executable);
  final contents = _appContents(canonicalExecutable);
  if (resolve(originalContents) != contents ||
      !regularFile(canonicalExecutable)) {
    throw StateError('Managed macOS executable is outside its app bundle');
  }

  final framework = p.posix.join(contents, 'Frameworks', 'rust_api.framework');
  if (resolve(framework) != framework) {
    throw StateError('Managed macOS framework is outside its bundled location');
  }
  final library = resolve(p.posix.join(framework, 'rust_api'));
  _requireAbsolutePath(library);
  if (!p.posix.isWithin(framework, library) ||
      p.posix.basename(library) != 'rust_api' ||
      !regularFile(library)) {
    throw StateError('Managed macOS native library is outside its framework');
  }

  // FRB's default loader honors an environment override even in packaged apps.
  return (openLibrary ?? ExternalLibrary.open)(library);
}

String _resolvedExecutable() => Platform.resolvedExecutable;

String _canonicalize(String path) => File(path).resolveSymbolicLinksSync();

bool _isFile(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) ==
    FileSystemEntityType.file;

String _appContents(String executable) {
  _requireAbsolutePath(executable);
  final macos = p.posix.dirname(executable);
  final contents = p.posix.dirname(macos);
  final app = p.posix.dirname(contents);
  if (p.posix.basename(macos) != 'MacOS' ||
      p.posix.basename(contents) != 'Contents' ||
      !p.posix.basename(app).endsWith('.app') ||
      p.posix.basename(app) == '.app') {
    throw StateError('Managed macOS executable is not in an app bundle');
  }
  return contents;
}

void _requireAbsolutePath(String path) {
  if (!p.posix.isAbsolute(path) ||
      p.posix.normalize(path) != path ||
      path.contains('\u0000')) {
    throw StateError('Managed macOS native loading requires canonical paths');
  }
}
