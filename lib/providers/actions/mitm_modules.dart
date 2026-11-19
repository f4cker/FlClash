part of '../action.dart';

MitmModuleContent _parseMitmModule((String, Map<String, String>) source) =>
    parseMitmModule(source.$1, values: source.$2);

bool _bringsNewScripts(
  ({
    String before,
    Map<String, String> resourcesBefore,
    String after,
    Map<String, String> resourcesAfter,
    Map<String, String> values,
  })
  source,
) {
  return mitmScriptScope(
        source.after,
        values: source.values,
        resources: source.resourcesAfter,
      )
      .difference(
        mitmScriptScope(
          source.before,
          values: source.values,
          resources: source.resourcesBefore,
        ),
      )
      .isNotEmpty;
}

@Riverpod(keepAlive: true)
class MitmModulesAction extends _$MitmModulesAction {
  var _autoUpdating = false;

  /// One update per module and url at a time; a second request joins the
  /// first. A module whose url changed meanwhile updates from the new one.
  final _updates = SingleFlight<(int, String?), MitmModule>();

  /// One download per resource url at a time, shared by every module naming
  /// it. A manual update never joins an auto update's conditional request.
  final _resourceDownloads = SingleFlight<(String, bool), String?>();

  /// Files written before a row or a line names them, which [clean] keeps.
  final _held = <String>[];

  /// Deletions run one at a time: two at once can both find a file still there
  /// and the later delete fails.
  Future<void> _deleting = Future.value();

  @override
  void build() {}

  Future<String> download(String url) async =>
      (await request.getTextResponseForUrl(url)).data ?? '';

  /// [text], when given, is what the import confirm showed.
  Future<MitmModule> addFromUrl(
    String url, {
    bool? enable,
    bool rulesEnabled = true,
    String? text,
  }) async {
    // A new module has nothing stored to revalidate: this always downloads.
    final fetched = text == null
        ? await resourceCache.fetch(
                ResourceKind.mitmModule,
                url,
                holds: (_) async => false,
              )
              as ResourceDownloaded
        : null;
    text ??= fetched!.text;
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    final name = segments.where((segment) => segment.isNotEmpty).lastOrNull;
    final saved = await _save(
      MitmModule(
        id: snowflake.id,
        name: basenameWithoutExtension(name ?? url),
        url: url,
        rulesEnabled: rulesEnabled,
        lastUpdateTime: DateTime.now(),
      ),
      text,
      added: true,
      enable: enable,
    );
    if (fetched != null) {
      await resourceCache.commit(
        ResourceKind.mitmModule,
        url,
        fetched,
        fingerprint: sha256Hex(utf8.encode(text)),
      );
    }
    return saved;
  }

  Future<MitmModule> addFromFile(
    String text,
    String fileName, {
    bool? enable,
    bool rulesEnabled = true,
  }) {
    return _save(
      MitmModule(
        id: snowflake.id,
        name: basenameWithoutExtension(fileName),
        rulesEnabled: rulesEnabled,
        lastUpdateTime: DateTime.now(),
      ),
      text,
      added: true,
      enable: enable,
    );
  }

  Future<MitmModule> create(String text) {
    return _save(
      MitmModule(
        id: snowflake.id,
        name: currentAppLocalizations.mitmModule,
        lastUpdateTime: DateTime.now(),
      ),
      text,
      added: true,
      first: true,
      edited: true,
    );
  }

  Future<MitmModule> edit(MitmModule module, String text) {
    return _save(module, text, edited: true);
  }

  /// An update of a module that is already updating joins that update.
  ///
  /// Only [revalidate] (auto update) asks the server whether what is stored
  /// is still current; an update the user asks for downloads everything
  /// whole. Unchanged content still rewrites and reloads nothing.
  Future<MitmModule> updateModule(
    MitmModule module, {
    bool revalidate = false,
  }) => _updates.run((
    module.id,
    module.url,
  ), () => _updateModule(module, revalidate: revalidate));

  Future<MitmModule> _updateModule(
    MitmModule module, {
    required bool revalidate,
  }) async {
    final updatingKeys = ref.read(updatingKeysProvider.notifier);
    final operation = updatingKeys.start(module.updatingKey);
    try {
      final url = module.url;
      if (url == null) {
        return await _save(
          module,
          await File(await _pathOf(module)).readAsString(),
        );
      }
      final missing = await _readText(module) == null;
      Future<void> fail(MitmUpdateFailure failure, Object e) => _mark(
        module,
        (current) => current.copyWith(
          error: e is MessageException ? e.message : compactError(e),
          failure: missing ? MitmUpdateFailure.load : failure,
        ),
      );
      final ResourceFetch fetched;
      final String text;
      try {
        fetched = await resourceCache.fetch(
          ResourceKind.mitmModule,
          url,
          holds: (fingerprint) async =>
              await _textHolds(module, fingerprint) != null,
          revalidate: revalidate,
        );
        text = switch (fetched) {
          ResourceDownloaded(:final text) => text,
          ResourceNotModified(:final validators) =>
            await _textHolds(module, validators.fingerprint) ??
                (throw const FileSystemException('module copy changed')),
        };
      } catch (e) {
        await fail(MitmUpdateFailure.check, e);
        rethrow;
      }
      try {
        final offered = await _offer(module, text, revalidate: revalidate);
        if (fetched is ResourceDownloaded) {
          await resourceCache.commit(
            ResourceKind.mitmModule,
            url,
            fetched,
            fingerprint: sha256Hex(utf8.encode(text)),
          );
        }
        return offered;
      } catch (e) {
        await fail(
          e is MessageException
              ? MitmUpdateFailure.invalid
              : MitmUpdateFailure.download,
          e,
        );
        rethrow;
      }
    } finally {
      updatingKeys.stop(module.updatingKey, operation);
    }
  }

  /// The text of the module's running or waiting copy whose bytes have
  /// [fingerprint], the two places a downloaded text is kept.
  Future<String?> _textHolds(MitmModule module, String fingerprint) async {
    final directory = await appPath.mitmModulesDirPath;
    for (final name in [module.fileName, module.pendingFileName]) {
      final path = join(directory, name);
      if (await storedSha256(path) == fingerprint) {
        try {
          return await File(path).readAsString();
        } on FileSystemException {
          return null;
        }
      }
    }
    return null;
  }

  /// Differing content waits in the pending file; what runs stays.
  Future<MitmModule> _offer(
    MitmModule module,
    String text, {
    bool revalidate = false,
  }) async {
    final current = await _readText(module);
    if (current == null) {
      return _mark(
        await _save(module, text, revalidate: revalidate),
        (item) => item.copyWith(error: null, failure: null),
      );
    }
    final pending = File(
      join(await appPath.mitmModulesDirPath, module.pendingFileName),
    );
    if (current == text) {
      // Its files still refresh; one whose script changed turns it off.
      final saved = await _refresh(module, text, revalidate: revalidate);
      await pending.safeDelete();
      return _mark(
        saved,
        (item) => item.copyWith(pendingTime: null, error: null, failure: null),
      );
    }
    if (await pendingText(module) == text) {
      // What waits is still the latest: only the check time moves.
      return _mark(
        module,
        (item) => item.copyWith(
          lastUpdateTime: DateTime.now(),
          error: null,
          failure: null,
        ),
      );
    }
    final content = await compute(_parseMitmModule, (text, module.arguments));
    if (content.isEmpty) {
      throw MessageException(currentAppLocalizations.mitmModuleInvalid);
    }
    _held.add(module.pendingFileName);
    try {
      await pending.writeAsStringAtomically(text);
      return await _mark(
        module,
        (item) => item.copyWith(
          lastUpdateTime: DateTime.now(),
          pendingTime: DateTime.now(),
          error: null,
          failure: null,
        ),
      );
    } finally {
      _held.remove(module.pendingFileName);
      if (ref.mounted) unawaited(_cleanAfterSave());
    }
  }

  /// [text] is what runs already. When no file it names changed either,
  /// nothing is written and nothing reloads: only the check time moves.
  /// Anything else, a changed file or a row that no longer says what [text]
  /// does, goes through [_save] and every check it makes.
  Future<MitmModule> _refresh(
    MitmModule module,
    String text, {
    required bool revalidate,
  }) async {
    final content = await compute(_parseMitmModule, (text, module.arguments));
    if (content.isEmpty) {
      return _save(module, text, revalidate: revalidate);
    }
    final held = [module.fileName];
    _held.addAll(held);
    try {
      final resources = await _download(
        content.resourceUrls,
        previous: module.resources,
        held: held,
        revalidate: revalidate,
      );
      final written = await _writeInline(content.inlineResources, held);
      final current = await _current(module.id);
      if (current == null || !ref.mounted) {
        return module;
      }
      final same =
          mapEquals(current.resources, {
            ...mitmAttachments(current),
            ...resources,
            ...written,
          }) &&
          (content.name ?? current.name) == current.name &&
          (content.description ?? '') == current.description &&
          content.system == current.system &&
          content.declaredScripts == current.scripts &&
          content.asksConsent == current.asksConsent;
      if (!same) {
        return await _save(module, text, fetched: (resources, written));
      }
      final checked = current.copyWith(lastUpdateTime: DateTime.now());
      putModule(checked);
      return checked;
    } finally {
      held.forEach(_held.remove);
      if (ref.mounted) {
        unawaited(_cleanAfterSave());
      }
    }
  }

  Future<MitmModule> _mark(
    MitmModule module,
    MitmModule Function(MitmModule current) change,
  ) async {
    final current = await _current(module.id);
    if (current == null || !ref.mounted) {
      return module;
    }
    final next = change(current);
    putModule(next);
    return next;
  }

  Future<String?> pendingText(MitmModule module) async {
    final file = File(
      join(await appPath.mitmModulesDirPath, module.pendingFileName),
    );
    return await file.exists() ? file.readAsString() : null;
  }

  Future<MitmModule> adopt(MitmModule module) async {
    final text = await pendingText(module);
    if (text == null) {
      return _mark(module, (item) => item.copyWith(pendingTime: null));
    }
    final saved = await _save(module, text, adopting: true);
    await File(
      join(await appPath.mitmModulesDirPath, module.pendingFileName),
    ).safeDelete();
    return _mark(
      saved,
      (item) => item.copyWith(pendingTime: null, error: null, failure: null),
    );
  }

  void putModule(MitmModule module, {bool first = false}) {
    ref.read(mitmModulesProvider.notifier).put(module, first: first);
  }

  Future<void> recordConsent(
    int id, {
    required bool asksConsent,
    bool? agreed,
  }) async {
    final current = await _current(id);
    if (!ref.mounted || current == null) {
      return;
    }
    putModule(
      current.copyWith(
        asksConsent: asksConsent,
        enabled: agreed ?? true,
        accepted: agreed ?? current.accepted,
      ),
    );
  }

  /// Turning a module off counts as declining it until it is turned on.
  Future<void> turnOff(int id) async {
    final current = await _current(id);
    if (ref.mounted && current != null) {
      putModule(
        current.copyWith(enabled: false, accepted: current.accepted ?? false),
      );
    }
  }

  /// A restored row may have been judged against another device's files.
  Future<void> recheckConsent() async {
    for (final module in await database.mitmModulesDao.query().get()) {
      bool asksConsent;
      try {
        asksConsent = (await _read(module, module.arguments)).asksConsent;
      } catch (_) {
        asksConsent = true;
      }
      if (!ref.mounted) {
        return;
      }
      if (asksConsent != module.asksConsent) {
        final current = await _current(module.id);
        if (ref.mounted && current != null) {
          putModule(current.copyWith(asksConsent: asksConsent));
        }
      }
    }
  }

  /// Null once the module is gone; a module file that cannot be read throws.
  Future<MitmModule?> setArguments(
    MitmModule module,
    Map<String, String> arguments,
  ) async {
    final content = await _read(module, arguments);
    final current = await _current(module.id);
    if (!ref.mounted || current == null) {
      return current;
    }
    final changed = _withContent(
      current.copyWith(arguments: arguments),
      content,
    );
    putModule(changed);
    final held = <String>[];
    try {
      final missing = content.resourceUrls.difference({
        ...changed.resources.keys,
      });
      final fetched = missing.isEmpty || !ref.mounted
          ? const <String, String>{}
          : await _download(missing, previous: const {}, held: held);
      final written = await _writeInline({
        for (final MapEntry(:key, :value) in content.inlineResources.entries)
          if (!changed.resources.containsKey(key)) key: value,
      }, held);
      if (fetched.isEmpty && written.isEmpty) {
        return changed;
      }
      final latest = await _current(module.id);
      if (!ref.mounted || latest == null) {
        return latest;
      }
      final withResources = latest.copyWith(
        resources: {...latest.resources, ...fetched, ...written},
      );
      putModule(withResources);
      return withResources;
    } finally {
      held.forEach(_held.remove);
    }
  }

  Future<void> attach(
    MitmModule module,
    String fileName,
    List<int> bytes,
  ) async {
    if (bytes.length > maxMitmResourceSize) {
      throw MessageException(
        currentAppLocalizations.mitmFileTooLarge(maxMitmResourceSize >> 20),
      );
    }
    final name = await _storeResource(fileName, bytes);
    try {
      final current = await _current(module.id);
      if (current != null && ref.mounted) {
        putModule(
          current.copyWith(resources: {...current.resources, fileName: name}),
        );
      }
    } finally {
      _held.remove(name);
    }
  }

  Future<void> detach(MitmModule module, String fileName) async {
    final current = await _current(module.id);
    if (current == null || !ref.mounted) {
      return;
    }
    putModule(
      current.copyWith(
        resources: {
          for (final MapEntry(:key, :value) in current.resources.entries)
            if (key != fileName) key: value,
        },
      ),
    );
    await clean();
  }

  Future<void> deleteModule(MitmModule module) async {
    ref.read(mitmModulesProvider.notifier).del(module.id);
    try {
      await _forgetValidators(module);
    } catch (e) {
      // Left behind, they cost nothing but a slot until evicted.
      commonPrint.log(
        'forget validators of ${module.name}: ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
    }
    final path = await _pathOf(module);
    await _oneDeletionAtATime(() async {
      await File(path).safeDelete();
      await _sweep();
    });
  }

  /// What was kept to revalidate the module and its resources goes with it,
  /// unless another module fetches the same url.
  Future<void> _forgetValidators(MitmModule module) async {
    final others = [
      for (final item in await database.mitmModulesDao.query().get())
        if (item.id != module.id) item,
    ];
    final url = module.url;
    if (url != null && !others.any((item) => item.url == url)) {
      await resourceCache.forget(ResourceKind.mitmModule, url);
    }
    for (final resource in module.resources.keys) {
      if (!others.any((item) => item.resources.containsKey(resource))) {
        await resourceCache.forget(ResourceKind.mitmResource, resource);
      }
    }
  }

  Future<void> _oneDeletionAtATime(Future<void> Function() delete) =>
      _deleting = _deleting.then((_) {}, onError: (_) {}).then((_) => delete());

  Future<String> _pathOf(MitmModule module) async {
    return join(await appPath.mitmModulesDirPath, module.fileName);
  }

  Future<MitmModuleContent> _read(
    MitmModule module,
    Map<String, String> arguments,
  ) async {
    final text = await File(await _pathOf(module)).readAsString();
    return compute(_parseMitmModule, (text, arguments));
  }

  Future<MitmModule?> _current(int id) async => (await ref.read(
    mitmModulesProvider.future,
  )).where((item) => item.id == id).firstOrNull;

  Future<MitmModule> _save(
    MitmModule module,
    String text, {
    bool added = false,
    bool first = false,
    bool edited = false,
    bool adopting = false,
    bool? enable,
    (Map<String, String>, Map<String, String>)? fetched,
    bool revalidate = false,
  }) async {
    final content = await compute(_parseMitmModule, (text, module.arguments));
    if (content.isEmpty && !edited) {
      throw MessageException(currentAppLocalizations.mitmModuleInvalid);
    }
    final held = [module.fileName];
    _held.addAll(held);
    try {
      final previous = added || edited ? null : await _readText(module);
      // What [fetched] names stays held by the caller that fetched it.
      final (resources, written) =
          fetched ??
          (
            await _download(
              content.resourceUrls,
              previous: module.resources,
              held: held,
              revalidate: revalidate,
            ),
            await _writeInline(content.inlineResources, held),
          );
      await File(await _pathOf(module)).writeAsStringAtomically(text);
      if (!ref.mounted) {
        return module;
      }
      var current = added ? module : await _current(module.id);
      if (current == null || !ref.mounted) {
        return module;
      }
      final merged = {...mitmAttachments(current), ...resources, ...written};
      final bringsNew =
          !adopting &&
          previous != null &&
          current.enabled &&
          await compute(_bringsNewScripts, (
            before: previous,
            resourcesBefore: current.resources,
            after: text,
            resourcesAfter: merged,
            values: current.arguments,
          ));
      if (!ref.mounted) {
        return module;
      }
      current = added ? module : await _current(module.id);
      if (current == null || !ref.mounted) return module;
      final saved = current.copyWith(
        name: content.name ?? current.name,
        description: content.description ?? '',
        system: content.system,
        enabled: added
            ? (enable ?? (content.declaredScripts == 0 && !content.asksConsent))
            : current.enabled &&
                  !bringsNew &&
                  (adopting || content.declaredScripts <= current.scripts),
        scripts: content.declaredScripts,
        asksConsent: content.asksConsent,
        accepted: content.asksConsent && !current.asksConsent
            ? null
            : current.accepted,
        resources: {...mitmAttachments(current), ...resources, ...written},
        lastUpdateTime: DateTime.now(),
      );
      putModule(saved, first: first);
      return saved;
    } finally {
      held.forEach(_held.remove);
      if (ref.mounted) {
        unawaited(_cleanAfterSave());
      }
    }
  }

  MitmModule _withContent(MitmModule current, MitmModuleContent content) {
    final next = current.copyWith(
      scripts: content.declaredScripts,
      asksConsent: content.asksConsent,
    );
    if (!current.enabled ||
        !next.asksBeforeTurningOn ||
        (current.accepted == true &&
            current.asksConsent == next.asksConsent &&
            current.scripts == next.scripts)) {
      return next;
    }
    return next.copyWith(enabled: false, accepted: null);
  }

  Future<void> _cleanAfterSave() async {
    try {
      await clean();
    } catch (e) {
      if (ref.mounted) {
        commonPrint.log(
          'MITM module clean: ${compactError(e)}',
          logLevel: LogLevel.warning,
        );
      }
    }
  }

  Future<String?> _readText(MitmModule module) async {
    try {
      return await File(await _pathOf(module)).readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// A resource that fails to download keeps the copy an earlier update left.
  /// One the server reports unchanged, or that downloads to the same bytes,
  /// keeps its file as it is.
  Future<Map<String, String>> _download(
    Set<String> urls, {
    required Map<String, String> previous,
    required List<String> held,
    bool revalidate = false,
  }) async {
    final directory = await appPath.mitmResourcesDirPath;
    final names = await Future.wait([
      for (final url in urls)
        () async {
          try {
            final name = await _resourceDownloads.run((
              url,
              revalidate,
            ), () => _fetchResource(url, directory, revalidate: revalidate));
            if (name == null) {
              throw const FileSystemException('too large');
            }
            _held.add(name);
            held.add(name);
            return name;
          } catch (e) {
            commonPrint.log(
              'MITM resource $url: ${compactError(e)}',
              logLevel: LogLevel.warning,
            );
            final name = previous[url];
            if (name == null) {
              return null;
            }
            held.add(name);
            _held.add(name);
            return await File(join(directory, name)).exists() ? name : null;
          }
        }(),
    ]);
    return {for (final (index, url) in urls.indexed) url: ?names[index]};
  }

  /// The stored name of [url]'s current bytes, null when they are too large.
  ///
  /// Files are named by their content, so whether the copy validators stand
  /// for is still there does not depend on which module asked: any module
  /// joining this download gets the same answer.
  Future<String?> _fetchResource(
    String url,
    String directory, {
    required bool revalidate,
  }) async {
    final fetched = await resourceCache.fetch(
      ResourceKind.mitmResource,
      url,
      holds: (fingerprint) async =>
          await storedSha256(
            join(directory, mitmResourceNameOf(url, fingerprint)),
          ) ==
          fingerprint,
      revalidate: revalidate,
    );
    switch (fetched) {
      case ResourceNotModified(:final validators):
        // Already stored; each caller holds it as soon as this returns.
        return mitmResourceNameOf(url, validators.fingerprint);
      case ResourceDownloaded(:final bytes):
        if (bytes.length > maxMitmResourceSize) {
          return null;
        }
        // Held until every caller of this download holds it itself.
        final name = await _storeResource(url, bytes);
        try {
          await resourceCache.commit(ResourceKind.mitmResource, url, fetched);
        } finally {
          _held.remove(name);
        }
        return name;
    }
  }

  Future<Map<String, String>> _writeInline(
    Map<String, String> sources,
    List<String> held,
  ) async {
    final written = <String, String>{};
    for (final MapEntry(:key, :value) in sources.entries) {
      final name = await _storeResource(key, utf8.encode(value));
      held.add(name);
      written[key] = name;
    }
    return written;
  }

  Future<String> _storeResource(String source, List<int> bytes) async {
    final name = mitmResourceName(source, bytes);
    _held.add(name);
    final file = File(join(await appPath.mitmResourcesDirPath, name));
    // Named by its content: a file already there with these bytes stays.
    if (await storedSha256(file.path) != sha256Hex(bytes)) {
      await file.writeAsBytesAtomically(bytes, keepMode: true);
    }
    return name;
  }

  /// Removes every file no module names, judged file by file so that what a
  /// save writes or names while it runs stays.
  Future<void> clean() => _oneDeletionAtATime(_sweep);

  Future<void> _sweep() async {
    final stored = await database.mitmModulesDao.query().get();
    final scriptFiles = await mitmScriptFiles();
    Future<void> sweep(
      String path,
      Iterable<String> Function(MitmModule module) namesOf,
    ) async {
      final directory = Directory(path);
      if (!await directory.exists()) {
        return;
      }
      await for (final entity in directory.list()) {
        if (entity is! File || !ref.mounted) {
          continue;
        }
        // An atomic write goes through `<name>.<pid>.<random>.tmp`.
        final name = basename(entity.path).replaceFirst(atomicTempSuffix, '');
        final modules = [...stored, ...?ref.read(mitmModulesProvider).value];
        if (!_held.contains(name) &&
            !isMitmScriptFileHeld(name) &&
            !scriptFiles.contains(name) &&
            !modules.any((module) => namesOf(module).contains(name))) {
          await entity.safeDelete();
        }
      }
    }

    await sweep(
      await appPath.mitmModulesDirPath,
      (module) => [module.fileName, module.pendingFileName],
    );
    await sweep(
      await appPath.mitmResourcesDirPath,
      (module) => module.resources.values,
    );
  }

  /// Remote modules follow the resources' two settings. What a restore leaves
  /// out, the content of remote modules and every downloaded resource, comes
  /// back even with auto update off.
  Future<void> autoUpdate() async {
    final setting = ref.read(patchClashConfigProvider);
    if (!mitmFeature ||
        !mitmModulesFeature ||
        _autoUpdating ||
        !ref.mounted ||
        !setting.mitm.enable) {
      return;
    }
    _autoUpdating = true;
    try {
      final interval = Duration(hours: setting.geoUpdateInterval);
      final resourcesDir = await appPath.mitmResourcesDirPath;
      for (final module in await database.mitmModulesDao.query().get()) {
        final missing =
            !await File(await _pathOf(module)).exists() ||
            !(await Future.wait([
              for (final name in module.resources.values)
                File(join(resourcesDir, name)).exists(),
            ])).every((exists) => exists);
        final due =
            setting.geoAutoUpdate &&
            module.isRemote &&
            module.lastUpdateTime.add(interval).isBeforeNow;
        if (!due && !missing) {
          continue;
        }
        if (!ref.mounted) {
          return;
        }
        if (!module.isRemote && !await File(await _pathOf(module)).exists()) {
          continue;
        }
        try {
          await updateModule(module, revalidate: true);
        } catch (e) {
          commonPrint.log(
            'auto update ${module.name}: ${compactError(e)}',
            logLevel: LogLevel.warning,
          );
        }
      }
      if (setting.geoAutoUpdate) {
        // The cleans the module updates started finish first; a clean that
        // starts later still keeps what a check holds.
        await _deleting.then((_) {}, onError: (_) {});
        await _checkScripts(interval);
      }
    } finally {
      _autoUpdating = false;
    }
  }

  Future<void> _checkScripts(Duration interval) async {
    for (final script in await database.mitmScriptsDao.queryAll().get()) {
      final checked = script.checkedAt;
      final profileId = script.profileId;
      if (!script.isRemote ||
          profileId == null ||
          !ref.mounted ||
          (checked != null && !checked.add(interval).isBeforeNow)) {
        continue;
      }
      await ref.read(profileMitmScriptsProvider(profileId).future);
      if (!ref.mounted) {
        return;
      }
      await checkMitmScriptUpdate(
        ref.read,
        profileId,
        script,
        revalidate: true,
      );
    }
  }
}
