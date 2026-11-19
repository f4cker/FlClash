import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:path/path.dart';

typedef MitmReader = ProviderReader;

const _maxScriptSize = 8 << 20;

class _ScriptException implements Exception {
  const _ScriptException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// As commitMitmRewrites: the Core first, then the database.
Future<void> commitMitmScripts(
  MitmReader read,
  int profileId,
  List<MitmScript> next,
) async {
  final notifier = read(profileMitmScriptsProvider(profileId).notifier);
  final before = read(profileMitmScriptsProvider(profileId)).value;
  final setup = read(mitmSetupProvider);
  final core = read(coreHandlerProvider);
  final live =
      setup != null &&
      read(currentProfileIdProvider) == profileId &&
      read(coreStatusProvider) == CoreStatus.connected;
  if (live) {
    await core.updateMitm(
      composeMitmSetup(
        read(patchClashConfigProvider).mitm,
        rewrites: read(currentMitmRewritesProvider),
        scripts: next,
        modules:
            read(enabledMitmModuleRulesProvider).value ?? MitmModuleRules.empty,
      ),
    );
  }
  try {
    await notifier.commit(next);
  } catch (_) {
    if (live) {
      unawaited(
        core.updateMitm(read(mitmSetupProvider)).catchError((Object _) {}),
      );
    }
    rethrow;
  }
  try {
    await _forgetRemovedUrls(before, next);
  } catch (e) {
    // Left behind, they cost nothing but a slot until evicted.
    commonPrint.log(
      'forget MITM script validators: ${compactError(e)}',
      logLevel: LogLevel.warning,
    );
  }
}

/// Validators of a url that no script, of this profile or another, fetches
/// any longer go.
Future<void> _forgetRemovedUrls(
  List<MitmScript>? before,
  List<MitmScript> next,
) async {
  final kept = {for (final script in next) ?script.url};
  final removed = {
    for (final script in before ?? const <MitmScript>[])
      if (script.url case final url? when !kept.contains(url)) url,
  };
  if (removed.isEmpty) return;
  final used = {
    for (final script in await database.mitmScriptsDao.queryAll().get())
      ?script.url,
  };
  for (final url in removed.difference(used)) {
    await resourceCache.forget(ResourceKind.mitmScript, url);
  }
}

/// What a failed download or load says, already in the app's words.
String? mitmScriptErrorMessage(Object error) =>
    error is _ScriptException ? error.message : null;

Future<List<int>> downloadMitmScript(String url) async =>
    _checkedScript((await request.getFileResponseForUrl(url)).data);

List<int> _checkedScript(List<int>? bytes) {
  if (bytes == null) {
    throw _ScriptException(currentAppLocalizations.mitmScriptEmpty);
  }
  if (bytes.length > _maxScriptSize) {
    throw _ScriptException(
      currentAppLocalizations.mitmFileTooLarge(_maxScriptSize >> 20),
    );
  }
  return bytes;
}

final _heldScriptFiles = <String>[];

/// Whether [name] is a script file a check or an import wrote and has not
/// saved or given up yet; a MITM clean, which judges by saved rows, keeps it.
bool isMitmScriptFileHeld(String name) => _heldScriptFiles.contains(name);

/// Runs [body], keeping every script file it stores through `held` from a
/// MITM clean until it returns or throws: by then the rows naming them are
/// saved, or the files are left for the next clean.
Future<T> holdingMitmScriptFiles<T>(
  Future<T> Function(List<String> held) body,
) async {
  final held = <String>[];
  try {
    return await body(held);
  } finally {
    held.forEach(_heldScriptFiles.remove);
  }
}

/// With [held] (from [holdingMitmScriptFiles]) the file is kept from a MITM
/// clean before it is written.
Future<String> storeMitmScript(
  String source,
  List<int> bytes, {
  List<String>? held,
}) async {
  final name = mitmResourceName(source, bytes);
  if (held != null) {
    held.add(name);
    _heldScriptFiles.add(name);
  }
  final directory = Directory(await appPath.mitmResourcesDirPath);
  await directory.create(recursive: true);
  final file = File(join(directory.path, name));
  // Named by its content: a file already there with these bytes stays.
  if (await storedSha256(file.path) != sha256Hex(bytes)) {
    await file.writeAsBytesAtomically(bytes, keepMode: true);
  }
  return name;
}

Future<String> readMitmScript(String file) async =>
    File(join(await appPath.mitmResourcesDirPath, file)).readAsString();

/// Stores each draft's file and has the Core load it; saves nothing.
Future<List<MitmScript>> prepareMitmScripts(
  MitmReader read,
  List<MitmScriptDraft> drafts, {
  Map<String, List<int>> local = const {},
  List<String>? held,
}) async {
  final scripts = <MitmScript>[];
  for (final (index, draft) in drafts.indexed) {
    final info = draft.info;
    final List<int> bytes;
    try {
      bytes = local[info.path] ?? await downloadMitmScript(info.path);
    } on _ScriptException {
      rethrow;
    } catch (e) {
      throw _ScriptException(
        currentAppLocalizations.mitmScriptDownloadFailed(
          info.name,
          compactError(e),
        ),
      );
    }
    final file = await storeMitmScript(info.path, bytes, held: held);
    final remote = draft.isRemote;
    scripts.add(
      MitmScript(
        id: snowflake.id + index,
        line: info.lineWith(file),
        url: remote ? info.path : null,
        source: remote ? info.path : basename(info.path),
        file: file,
        checkedAt: remote ? DateTime.now() : null,
      ),
    );
  }
  final issues = await read(coreHandlerProvider).validateMitm(
    MitmRules(script: [for (final script in scripts) script.line]),
  );
  final problems = issues[MitmList.script] ?? const {};
  if (problems.isNotEmpty) {
    final (index, reason) = problems.entries
        .map((entry) => (entry.key, entry.value))
        .first;
    throw _ScriptException(
      currentAppLocalizations.mitmScriptCannotLoad(
        drafts[index].info.name,
        reason,
      ),
    );
  }
  return scripts;
}

final _scriptChecks = SingleFlight<(int, int, String?), MitmScript>();

/// New content waits in [MitmScript.pendingFile]; the old keeps running.
/// A script whose own file is gone takes the new content at once. A check of
/// a script that is already being checked from the same url joins that check.
/// Only [revalidate] (auto update) sends validators; a check the user asks
/// for downloads the script whole.
Future<MitmScript> checkMitmScriptUpdate(
  MitmReader read,
  int profileId,
  MitmScript script, {
  bool revalidate = false,
}) => _scriptChecks.run(
  (profileId, script.id, script.url),
  () => holdingMitmScriptFiles(
    (held) => _checkMitmScriptUpdate(
      read,
      profileId,
      script,
      revalidate: revalidate,
      held: held,
    ),
  ),
);

/// The stored file, the waiting one first, whose bytes have [fingerprint].
Future<String?> _scriptFileHolding(
  MitmScript script,
  String fingerprint,
) async {
  final directory = await appPath.mitmResourcesDirPath;
  for (final name in [?script.pendingFile, script.file]) {
    if (await storedSha256(join(directory, name)) == fingerprint) {
      return name;
    }
  }
  return null;
}

Future<MitmScript> _checkMitmScriptUpdate(
  MitmReader read,
  int profileId,
  MitmScript script, {
  required bool revalidate,
  required List<String> held,
}) async {
  final url = script.url;
  if (url == null) {
    return script;
  }
  final missing = !await File(
    join(await appPath.mitmResourcesDirPath, script.file),
  ).exists();
  MitmScript failed(MitmUpdateFailure failure, String error) => script.copyWith(
    checkedAt: DateTime.now(),
    error: error,
    failure: missing ? MitmUpdateFailure.load : failure,
  );
  MitmScript checked;
  try {
    // A 304 stands only for a stored file that still has the fingerprint
    // recorded with the validators; the Core still checks it below.
    final fetched = await resourceCache.fetch(
      ResourceKind.mitmScript,
      url,
      holds: (fingerprint) async =>
          await _scriptFileHolding(script, fingerprint) != null,
      revalidate: revalidate,
    );
    final String name;
    switch (fetched) {
      case ResourceNotModified(:final validators):
        name =
            await _scriptFileHolding(script, validators.fingerprint) ??
            (throw const FileSystemException('script copy changed'));
      case ResourceDownloaded(:final bytes):
        name = await storeMitmScript(url, _checkedScript(bytes), held: held);
    }
    final line =
        parseMitmScriptInfo(script.line)?.lineWith(name) ?? script.line;
    final issues = await read(
      coreHandlerProvider,
    ).validateMitm(MitmRules(script: [line]));
    final problem = issues[MitmList.script]?.values.firstOrNull;
    if (problem == null && fetched is ResourceDownloaded) {
      await resourceCache.commit(ResourceKind.mitmScript, url, fetched);
    }
    if (problem != null) {
      checked = failed(MitmUpdateFailure.invalid, problem);
    } else if (missing) {
      checked = script.copyWith(
        line: line,
        file: name,
        pendingFile: null,
        checkedAt: DateTime.now(),
        error: null,
        failure: null,
      );
    } else {
      checked = script.copyWith(
        pendingFile: name == script.file ? null : name,
        checkedAt: DateTime.now(),
        error: null,
        failure: null,
      );
    }
  } on _ScriptException catch (e) {
    checked = failed(MitmUpdateFailure.download, e.message);
  } catch (e) {
    checked = failed(MitmUpdateFailure.check, compactError(e));
  }
  final current = read(profileMitmScriptsProvider(profileId)).value ?? [];
  final next = [
    for (final item in current) item.id == script.id ? checked : item,
  ];
  if (checked.file != script.file) {
    await commitMitmScripts(read, profileId, next);
  } else {
    await read(profileMitmScriptsProvider(profileId).notifier).commit(next);
  }
  return checked;
}

Future<void> adoptMitmScript(
  MitmReader read,
  int profileId,
  MitmScript script,
) async {
  final pending = script.pendingFile;
  if (pending == null) {
    return;
  }
  final info = parseMitmScriptInfo(script.line);
  final adopted = script.copyWith(
    line: info?.lineWith(pending) ?? script.line,
    file: pending,
    pendingFile: null,
    error: null,
    failure: null,
  );
  final current = read(profileMitmScriptsProvider(profileId)).value ?? [];
  await commitMitmScripts(read, profileId, [
    for (final item in current) item.id == script.id ? adopted : item,
  ]);
}

/// Every resource a profile's script names, which module cleaning keeps.
Future<Set<String>> mitmScriptFiles() async => {
  for (final script in await database.mitmScriptsDao.queryAll().get()) ...[
    script.file,
    ?script.pendingFile,
  ],
};

/// [hosts] no line of [hostname] covers.
List<String> mitmUncoveredHosts(Iterable<String> hosts, List<String> hostname) {
  bool covered(String host) {
    for (final line in hostname) {
      final entry = line.trim().toLowerCase();
      if (entry.startsWith('-')) {
        if (entry.substring(1) == host) return false;
        continue;
      }
      if (entry == host || entry == '*') return true;
      if (entry.startsWith('*.') && host.endsWith(entry.substring(1))) {
        return true;
      }
    }
    return false;
  }

  return {
    for (final host in hosts)
      if (!covered(host.toLowerCase())) host.toLowerCase(),
  }.toList();
}

List<MitmScriptInfo> mitmModuleScripts(MitmModuleContent content) => [
  for (final line in content.script) ?parseMitmScriptInfo(line),
];
