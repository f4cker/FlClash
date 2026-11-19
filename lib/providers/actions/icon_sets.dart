part of '../action.dart';

@Riverpod(keepAlive: true)
class IconSetsAction extends _$IconSetsAction {
  final _syncs = SingleFlight<(int, String), IconSet>();

  @override
  void build() {}

  Future<IconSet> importUrl(String url, {String name = ''}) async {
    final existing = (await database.iconSetsDao.query().get())
        .where((item) => item.url == url)
        .firstOrNull;
    if (existing != null) {
      return sync(name.isEmpty ? existing : existing.copyWith(name: name));
    }
    // A new set has nothing stored to revalidate, so this always downloads.
    final download =
        await resourceCache.fetch(
              ResourceKind.iconSet,
              url,
              holds: (_) async => false,
            )
            as ResourceDownloaded;
    final content = _parse(utf8.decode(download.bytes, allowMalformed: true));
    final added = _put(
      IconSet(
        id: snowflake.id,
        name: _nameOf(name, content.name, url.urlFileName.fileStem),
        url: url,
        icons: content.icons,
        lastUpdateTime: DateTime.now(),
      ),
    );
    await resourceCache.commit(
      ResourceKind.iconSet,
      url,
      download,
      fingerprint: _fingerprintOf(content.icons),
    );
    return added;
  }

  IconSet importContent(String fileName, String content) {
    final parsed = _parse(content);
    return _put(
      IconSet(
        id: snowflake.id,
        name: _nameOf('', parsed.name, fileName.fileStem),
        icons: parsed.icons,
        lastUpdateTime: DateTime.now(),
      ),
    );
  }

  /// A sync of a set that is already syncing from the same url joins it,
  /// whichever of the page, an update button or auto update asked.
  Future<IconSet> sync(IconSet iconSet) =>
      _syncs.run((iconSet.id, iconSet.url), () => _sync(iconSet));

  Future<IconSet> _sync(IconSet iconSet) async {
    final before = await _stored(iconSet.id);
    final url = iconSet.url;
    // Validators go out only while the stored icons are what they described.
    final fetched = await resourceCache.fetch(
      ResourceKind.iconSet,
      url,
      holds: (fingerprint) async {
        final stored = await _stored(iconSet.id);
        return stored != null &&
            stored.url == url &&
            _fingerprintOf(stored.icons) == fingerprint;
      },
    );
    final content = switch (fetched) {
      ResourceDownloaded(:final bytes) => _parse(
        utf8.decode(bytes, allowMalformed: true),
      ),
      ResourceNotModified() => null,
    };
    final latest = before == null ? null : await _stored(iconSet.id);
    if (before != null && (latest == null || latest.url != before.url)) {
      return latest ?? iconSet;
    }
    final base = switch ((before, latest)) {
      (final before?, final latest?) => latest.copyWith(
        name: iconSet.name == before.name ? latest.name : iconSet.name,
        url: iconSet.url,
      ),
      _ => iconSet,
    };
    final icons = content?.icons ?? base.icons;
    final saved = _put(
      base.copyWith(icons: icons, lastUpdateTime: DateTime.now()),
    );
    if (fetched is ResourceDownloaded) {
      await resourceCache.commit(
        ResourceKind.iconSet,
        url,
        fetched,
        fingerprint: _fingerprintOf(icons),
      );
    }
    return saved;
  }

  static String _fingerprintOf(List<IconSetIcon> icons) => sha256Hex(
    utf8.encode(
      json.encode([
        for (final icon in icons) [icon.name, icon.url],
      ]),
    ),
  );

  Future<IconSet?> _stored(int id) async {
    final rows =
        ref.read(iconSetsProvider).value ??
        await database.iconSetsDao.query().get();
    return rows.where((item) => item.id == id).firstOrNull;
  }

  IconSet _put(IconSet iconSet) {
    ref.read(iconSetsProvider.notifier).put(iconSet);
    return iconSet;
  }

  String _nameOf(String name, String parsedName, String fallback) {
    for (final candidate in [name, parsedName, fallback]) {
      if (candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return currentAppLocalizations.iconSets;
  }

  ({String name, List<IconSetIcon> icons}) _parse(String content) {
    try {
      return parseIconSet(content);
    } on FormatException {
      throw MessageException(currentAppLocalizations.invalidIconSet);
    }
  }
}
