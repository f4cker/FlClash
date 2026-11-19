part of '../action.dart';

@Riverpod(keepAlive: true)
class ScriptsAction extends _$ScriptsAction {
  final _updates = SingleFlight<(int, String?), void>();

  @override
  void build() {}

  void putScript(Script script) {
    ref.read(scriptsProvider.notifier).put(script);
    _applyIfInUse(script.id);
  }

  void deleteScript(int scriptId) {
    final inUse = ref.read(currentProfileProvider)?.scriptId == scriptId;
    final url = ref.read(scriptsProvider).value?.get(scriptId)?.url;
    if (url != null) {
      unawaited(resourceCache.forget(ResourceKind.script, url));
    }
    ref.read(scriptsProvider.notifier).del(scriptId);
    ref
        .read(profilesProvider.notifier)
        .updateWhere(
          (profile) => profile.scriptId == scriptId,
          (profile) => profile.copyWith(scriptId: null),
        );
    if (inUse) {
      ref
          .read(setupActionProvider.notifier)
          .applyProfileDebounce(silence: true);
    }
  }

  /// An update of a script that is already updating from the same url joins
  /// that update. Only [revalidate] (auto update) sends validators; an update
  /// the user asks for downloads the script whole.
  Future<void> updateScript(Script script, {bool revalidate = false}) =>
      _updates.run((
        script.id,
        script.url,
      ), () => _updateScript(script, revalidate: revalidate));

  /// Unchanged content, by a 304 or by its hash, only moves the check time:
  /// the file stays as it is and nothing reapplies.
  Future<void> _updateScript(Script script, {required bool revalidate}) async {
    final updatingKeys = ref.read(updatingKeysProvider.notifier);
    final operation = updatingKeys.start(script.updatingKey);
    try {
      final url = script.url!;
      final path = await script.path;
      final fetched = await resourceCache.fetch(
        ResourceKind.script,
        url,
        holds: (fingerprint) async => await storedSha256(path) == fingerprint,
        revalidate: revalidate,
      );
      switch (fetched) {
        case ResourceNotModified():
          _checked(script);
        case ResourceDownloaded(:final text):
          final fingerprint = sha256Hex(utf8.encode(text));
          if (await storedSha256(path) == fingerprint) {
            _checked(script);
          } else {
            putScript(await script.save(text));
          }
          await resourceCache.commit(
            ResourceKind.script,
            url,
            fetched,
            fingerprint: fingerprint,
          );
      }
    } finally {
      updatingKeys.stop(script.updatingKey, operation);
    }
  }

  void _checked(Script script) {
    final current = ref.read(scriptsProvider).value?.get(script.id) ?? script;
    ref
        .read(scriptsProvider.notifier)
        .put(current.copyWith(lastUpdateTime: DateTime.now()));
  }

  void _applyIfInUse(int scriptId) {
    if (ref.read(currentProfileProvider)?.scriptId != scriptId) {
      return;
    }
    ref.read(setupActionProvider.notifier).applyProfileDebounce(silence: true);
  }
}
