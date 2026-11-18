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
}

/// What a failed download or load says, already in the app's words.
String? mitmScriptErrorMessage(Object error) =>
    error is _ScriptException ? error.message : null;

Future<List<int>> downloadMitmScript(String url) async {
  final bytes = (await request.getFileResponseForUrl(url)).data;
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

Future<String> storeMitmScript(String source, List<int> bytes) async {
  final name = mitmResourceName(source, bytes);
  final directory = Directory(await appPath.mitmResourcesDirPath);
  await directory.create(recursive: true);
  final file = File(join(directory.path, name));
  if (!await file.exists()) {
    await file.safeWriteAsBytes(bytes);
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
    final file = await storeMitmScript(info.path, bytes);
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

/// New content waits in [MitmScript.pendingFile]; the old keeps running.
/// A script whose own file is gone takes the new content at once.
Future<MitmScript> checkMitmScriptUpdate(
  MitmReader read,
  int profileId,
  MitmScript script,
) async {
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
    final bytes = await downloadMitmScript(url);
    final name = await storeMitmScript(url, bytes);
    final line =
        parseMitmScriptInfo(script.line)?.lineWith(name) ?? script.line;
    final issues = await read(
      coreHandlerProvider,
    ).validateMitm(MitmRules(script: [line]));
    final problem = issues[MitmList.script]?.values.firstOrNull;
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
