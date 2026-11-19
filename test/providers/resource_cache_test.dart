import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/mitm/script_actions.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

class _RecordingSetupAction extends SetupAction {
  var applies = 0;

  @override
  void applyProfileDebounce({bool silence = false, bool force = false}) {
    applies++;
  }
}

enum _Mode { ok, error, drop, partial }

class _Served {
  _Served(this.body);

  String body;
  bool validators = true;
  _Mode mode = _Mode.ok;
}

/// A loopback server that counts every request, the conditional ones and
/// the 304s it answers, per path. Validators are an ETag of the body and a
/// fixed Last-Modified.
void main() {
  late HttpServer server;
  final served = <String, _Served>{};
  final hits = <String, int>{};
  final conditional = <String, int>{};
  final notModified = <String, int>{};
  Completer<void>? held;
  late Directory home;
  late db.Database testDatabase;
  late ProviderContainer container;
  late _RecordingSetupAction setup;
  late _MockCore core;
  late int validations;

  void count(Map<String, int> counts, String path) =>
      counts.update(path, (value) => value + 1, ifAbsent: () => 1);

  setUpAll(() async {
    loadAppLocalizations(const Locale('en'));
    registerFallbackValue(const MitmRules());
    globalState.packageInfo = PackageInfo(
      appName: 'FlClash',
      packageName: 'com.follow.clash',
      version: '1.0.0',
      buildNumber: '1',
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      count(hits, path);
      final ifNoneMatch = request.headers.value('if-none-match');
      if (ifNoneMatch != null ||
          request.headers.value('if-modified-since') != null) {
        count(conditional, path);
      }
      await held?.future;
      final response = request.response;
      final item = served[path];
      if (item == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      switch (item.mode) {
        case _Mode.error:
          response.statusCode = HttpStatus.serviceUnavailable;
          await response.close();
          return;
        case _Mode.drop:
          (await response.detachSocket(writeHeaders: false)).destroy();
          return;
        case _Mode.partial:
          final socket = await response.detachSocket(writeHeaders: false);
          final body = utf8.encode(item.body);
          socket.add(
            utf8.encode(
              'HTTP/1.1 200 OK\r\n'
              'Content-Length: ${body.length + 100}\r\n'
              'ETag: "partial"\r\n\r\n',
            ),
          );
          socket.add(body);
          await socket.flush();
          socket.destroy();
          return;
        case _Mode.ok:
      }
      final etag = '"${sha256Hex(utf8.encode(item.body)).substring(0, 16)}"';
      if (item.validators) {
        if (ifNoneMatch == etag) {
          count(notModified, path);
          response.statusCode = HttpStatus.notModified;
          await response.close();
          return;
        }
        response.headers.set('etag', etag);
        response.headers.set(
          'last-modified',
          HttpDate.format(DateTime.utc(2026)),
        );
      }
      response.add(utf8.encode(item.body));
      await response.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  setUp(() async {
    mitmFeature = true;
    mitmModulesFeature = true;
    addTearDown(() {
      mitmFeature = false;
      mitmModulesFeature = false;
    });
    served.clear();
    hits.clear();
    conditional.clear();
    notModified.clear();
    held = null;
    validations = 0;
    final bindingOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = bindingOverrides);
    home = await Directory.systemTemp.createTemp('resource_cache');
    await useAppPaths(home);
    testDatabase = db.Database(NativeDatabase.memory());
    db.database = testDatabase;
    setup = _RecordingSetupAction();
    core = _MockCore();
    when(() => core.validateMitm(any())).thenAnswer((_) async {
      validations++;
      return {MitmList.script: <int, String>{}};
    });
    const profile = Profile(
      id: 1,
      label: 'Uses the script',
      scriptId: 5,
      autoUpdateDuration: Duration.zero,
    );
    await testDatabase.profiles.put(profile.toCompanion());
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        setupActionProvider.overrideWith(() => setup),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    globalState.container = container;
    container.listen(mitmModulesProvider, (_, _) {});
    container.listen(iconSetsProvider, (_, _) {});
    container.listen(scriptsProvider, (_, _) {});
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(currentProfileProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = 1;
  });

  tearDown(() async {
    // Sweeps a save leaves running end before the directory goes.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    container.dispose();
    await testDatabase.close();
    await home.delete(recursive: true);
  });

  String urlOf(String path) => 'http://127.0.0.1:${server.port}$path';

  void serve(Map<String, String> bodies) {
    for (final MapEntry(:key, :value) in bodies.entries) {
      served[key] = _Served(value);
    }
  }

  void resetCounts() {
    hits.clear();
    conditional.clear();
    notModified.clear();
  }

  final old = DateTime(2000);

  /// Backdates [path] so that any rewrite shows as a new modification time.
  void backdate(String path) => File(path).setLastModifiedSync(old);

  bool untouched(String path) => File(path).lastModifiedSync() == old;

  Future<List<String>> tempFiles() async => [
    await for (final entity in home.list(recursive: true))
      if (entity.path.endsWith('.tmp')) entity.path,
  ];

  MitmModulesAction mitm() =>
      container.read(mitmModulesActionProvider.notifier);

  Future<MitmModule> storedModule([int? id]) async {
    await pumpEventQueue();
    final modules = await testDatabase.mitmModulesDao.query().get();
    return id == null
        ? modules.single
        : modules.firstWhere((module) => module.id == id);
  }

  String module(String name, {String prefix = ''}) =>
      '''
#!name=$name
[MITM]
hostname = %APPEND% example.com
[Map Local]
^https://example\\.com/a data="${urlOf('$prefix/a.json')}"
^https://example\\.com/b data="${urlOf('$prefix/b.json')}"
^https://example\\.com/c data="${urlOf('$prefix/c.json')}"
''';

  Future<List<String>> modulePaths(MitmModule module) async => [
    join(await appPath.mitmModulesDirPath, module.fileName),
    for (final name in module.resources.values)
      join(await appPath.mitmResourcesDirPath, name),
  ];

  /// A module with three resources, added and with every file backdated.
  Future<MitmModule> addModule({String prefix = ''}) async {
    serve({
      '$prefix/m.sgmodule': module('M$prefix', prefix: prefix),
      '$prefix/a.json': '{"a":1}',
      '$prefix/b.json': '[]',
      '$prefix/c.json': '1',
    });
    await mitm().addFromUrl(urlOf('$prefix/m.sgmodule'));
    final added = (await testDatabase.mitmModulesDao.query().get()).firstWhere(
      (item) => item.url == urlOf('$prefix/m.sgmodule'),
    );
    await resourceCache.store.saved;
    for (final path in await modulePaths(added)) {
      backdate(path);
    }
    // The database keeps whole seconds; an old check time shows the next.
    final checked = added.copyWith(lastUpdateTime: old);
    mitm().putModule(checked);
    await pumpEventQueue();
    return checked;
  }

  group('a MITM module', () {
    test('unchanged: one conditional request per file, each a 304, and '
        'nothing is rewritten or reloaded', () async {
      final added = await addModule();
      resetCounts();
      final before = await storedModule();

      final updated = await mitm().updateModule(before);

      expect(hits, {
        '/m.sgmodule': 1,
        '/a.json': 1,
        '/b.json': 1,
        '/c.json': 1,
      });
      expect(conditional, hits);
      expect(notModified, hits);
      for (final path in await modulePaths(added)) {
        expect(untouched(path), isTrue, reason: path);
      }
      final after = await storedModule();
      expect(after.lastUpdateTime.isAfter(before.lastUpdateTime), isTrue);
      // Only the check time moved, so the setup sent to the Core is the same.
      expect(after.copyWith(lastUpdateTime: before.lastUpdateTime), before);
      expect(updated.hasPending, isFalse);
      expect(await mitm().pendingText(after), isNull);
    });

    test('changed text waits as before; a changed resource is fetched whole '
        'and stored under its new name', () async {
      final added = await addModule();
      resetCounts();
      served['/m.sgmodule']!.body = '${module('M')}# changed\n';

      final pending = await mitm().updateModule(await storedModule());

      expect(hits, {'/m.sgmodule': 1});
      expect(notModified, isEmpty);
      expect(pending.hasPending, isTrue);
      expect(untouched((await modulePaths(added)).first), isTrue);

      resetCounts();
      served['/m.sgmodule']!.body = module('M');
      served['/b.json']!.body = '[2]';

      final updated = await mitm().updateModule(await storedModule());

      expect(hits, {
        '/m.sgmodule': 1,
        '/a.json': 1,
        '/b.json': 1,
        '/c.json': 1,
      });
      expect(conditional, hits);
      expect(notModified, {'/a.json': 1, '/c.json': 1});
      expect(updated.hasPending, isFalse);
      final b = updated.resources[urlOf('/b.json')]!;
      expect(b, isNot(added.resources[urlOf('/b.json')]));
      expect(
        await File(join(await appPath.mitmResourcesDirPath, b)).readAsString(),
        '[2]',
      );
    });

    test('a pending text the server still serves only moves the check '
        'time', () async {
      await addModule();
      served['/m.sgmodule']!.body = '${module('M')}# changed\n';
      final pending = await mitm().updateModule(await storedModule());
      final pendingPath = join(
        await appPath.mitmModulesDirPath,
        pending.pendingFileName,
      );
      backdate(pendingPath);
      final waiting = await storedModule();
      resetCounts();

      final again = await mitm().updateModule(waiting);

      expect(hits, {'/m.sgmodule': 1});
      expect(notModified, {'/m.sgmodule': 1});
      expect(untouched(pendingPath), isTrue);
      expect(again.hasPending, isTrue);
      expect((await storedModule()).pendingTime, waiting.pendingTime);
    });

    test('a server without validators: same bytes skip the rewrite', () async {
      serve({
        '/m.sgmodule': module('M'),
        '/a.json': '{"a":1}',
        '/b.json': '[]',
        '/c.json': '1',
      });
      for (final item in served.values) {
        item.validators = false;
      }
      await mitm().addFromUrl(urlOf('/m.sgmodule'));
      final added = await storedModule();
      for (final path in await modulePaths(added)) {
        backdate(path);
      }
      resetCounts();

      await mitm().updateModule(added);

      expect(hits, {
        '/m.sgmodule': 1,
        '/a.json': 1,
        '/b.json': 1,
        '/c.json': 1,
      });
      expect(conditional, isEmpty);
      for (final path in await modulePaths(added)) {
        expect(untouched(path), isTrue, reason: path);
      }
      final after = await storedModule();
      expect(after.copyWith(lastUpdateTime: added.lastUpdateTime), added);
    });

    test('a resource file that is gone is fetched whole', () async {
      final added = await addModule();
      final a = join(
        await appPath.mitmResourcesDirPath,
        added.resources[urlOf('/a.json')]!,
      );
      await File(a).delete();
      resetCounts();

      await mitm().updateModule(added);

      expect(conditional, {'/m.sgmodule': 1, '/b.json': 1, '/c.json': 1});
      expect(hits['/a.json'], 1);
      expect(await File(a).readAsString(), '{"a":1}');
    });

    test(
      'a corrupt resource file drops its validators and is restored',
      () async {
        final added = await addModule();
        final [_, a, ...] = await modulePaths(added);
        await File(a).writeAsString('tampered');
        resetCounts();

        await mitm().updateModule(added);

        expect(conditional, {'/m.sgmodule': 1, '/b.json': 1, '/c.json': 1});
        expect(hits['/a.json'], 1);
        expect(await File(a).readAsString(), '{"a":1}');
      },
    );

    test('a module file changed on disk drops its validators', () async {
      final added = await addModule();
      final [modulePath, ...] = await modulePaths(added);
      await File(modulePath).writeAsString('${module('M')}# tampered\n');
      resetCounts();

      await mitm().updateModule(added);

      expect(hits, {'/m.sgmodule': 1});
      expect(conditional, isEmpty);
      // The served text differs from what is on disk, so it waits as any
      // other new text would; nothing unchecked was taken as current.
      expect((await storedModule()).hasPending, isTrue);
    });

    for (final mode in _Mode.values.where((mode) => mode != _Mode.ok)) {
      test('a ${mode.name} keeps the old files, leaves no temp file, and the '
          'next attempt works', () async {
        final added = await addModule();
        final paths = await modulePaths(added);
        final contents = [
          for (final path in paths) File(path).readAsStringSync(),
        ];
        for (final item in served.values) {
          item.mode = mode;
        }
        served['/b.json']!.body = '[2]';

        await expectLater(mitm().updateModule(added), throwsA(anything));

        for (final (index, path) in paths.indexed) {
          expect(File(path).readAsStringSync(), contents[index]);
        }
        expect(await tempFiles(), isEmpty);
        final failed = await storedModule();
        expect(failed.failure, isNotNull);

        for (final item in served.values) {
          item.mode = _Mode.ok;
        }
        resetCounts();
        final next = await mitm().updateModule(failed);

        expect(hits, {
          '/m.sgmodule': 1,
          '/a.json': 1,
          '/b.json': 1,
          '/c.json': 1,
        });
        expect(notModified, {'/m.sgmodule': 1, '/a.json': 1, '/c.json': 1});
        expect(next.failure, isNull);
        expect(
          next.resources[urlOf('/b.json')],
          isNot(added.resources[urlOf('/b.json')]),
        );
        expect(await tempFiles(), isEmpty);
      });

      test('a resource that fails by ${mode.name} keeps its last copy and '
          'leaves no temp file', () async {
        final added = await addModule();
        served['/b.json']!
          ..mode = mode
          ..body = '[2]';
        final b = (await modulePaths(added))[2];

        final updated = await mitm().updateModule(added);

        expect(updated.failure, isNull);
        expect(updated.resources, added.resources);
        expect(File(b).readAsStringSync(), '[]');
        expect(untouched(b), isTrue);
        expect(await tempFiles(), isEmpty);
      });
    }

    test('two updates at once download each file once and both get the '
        'result', () async {
      final added = await addModule();
      served['/m.sgmodule']!.body = '${module('M')}# changed\n';
      resetCounts();
      held = Completer();

      final first = mitm().updateModule(added);
      final second = mitm().updateModule(added);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      held!.complete();
      final results = await Future.wait([first, second]);

      expect(hits, {'/m.sgmodule': 1});
      expect(results.first, results.last);
      expect(results.first.hasPending, isTrue);
      expect(await tempFiles(), isEmpty);
    });

    test('updates of two modules at once each go ahead', () async {
      final one = await addModule(prefix: '/one');
      final two = await addModule(prefix: '/two');
      served['/one/b.json']!.body = '[1]';
      served['/two/b.json']!.body = '[2]';
      resetCounts();
      held = Completer();

      final first = mitm().updateModule(one);
      final second = mitm().updateModule(two);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      held!.complete();
      final [a, b] = await Future.wait([first, second]);

      expect(hits.values, everyElement(1));
      expect(hits, hasLength(8));
      expect(
        a.resources[urlOf('/one/b.json')],
        isNot(one.resources[urlOf('/one/b.json')]),
      );
      expect(
        b.resources[urlOf('/two/b.json')],
        isNot(two.resources[urlOf('/two/b.json')]),
      );
      expect(a.failure, isNull);
      expect(b.failure, isNull);
    });
  });

  group('an icon set', () {
    IconSetsAction icons() => container.read(iconSetsActionProvider.notifier);

    String iconSet(List<String> names) => json.encode({
      'name': 'Q',
      'icons': [
        for (final name in names)
          {'name': '$name.png', 'url': 'https://example.com/$name.png'},
      ],
    });

    Future<IconSet> added() async {
      serve({
        '/icons.json': iconSet(['a']),
      });
      final imported = await icons().importUrl(urlOf('/icons.json'));
      await resourceCache.store.saved;
      container
          .read(iconSetsProvider.notifier)
          .put(imported.copyWith(lastUpdateTime: old));
      await pumpEventQueue();
      return (await testDatabase.iconSetsDao.query().get()).single;
    }

    test('unchanged answers 304 and keeps its icons', () async {
      final saved = await added();
      resetCounts();

      final synced = await icons().sync(saved);

      expect(notModified, {'/icons.json': 1});
      expect(synced.icons, saved.icons);
      expect(synced.lastUpdateTime!.isAfter(saved.lastUpdateTime!), isTrue);
    });

    test('a new url is fetched whole', () async {
      final saved = await added();
      serve({
        '/moved.json': iconSet(['a', 'b']),
      });
      resetCounts();

      final synced = await icons().sync(
        saved.copyWith(url: urlOf('/moved.json')),
      );

      expect(hits, {'/moved.json': 1});
      expect(conditional, isEmpty);
      expect(synced.icons, hasLength(2));
    });

    test('icons edited since the last download drop the validators', () async {
      final saved = await added();
      container
          .read(iconSetsProvider.notifier)
          .put(saved.copyWith(icons: const []));
      await pumpEventQueue();
      resetCounts();

      final synced = await icons().sync(saved);

      expect(conditional, isEmpty);
      expect(synced.icons, hasLength(1));
    });

    test('auto update and the page Sync at once download once', () async {
      final saved = await added();
      container
          .read(iconSetsProvider.notifier)
          .put(saved.copyWith(lastUpdateTime: DateTime(2020)));
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(geoAutoUpdate: true));
      await pumpEventQueue();
      served['/icons.json']!.body = iconSet(['a', 'b']);
      resetCounts();
      held = Completer();

      final auto = container
          .read(resourcesActionProvider.notifier)
          .autoUpdate();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final sync = icons().sync(saved);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      held!.complete();
      await Future.wait([auto, sync]);

      expect(hits, {'/icons.json': 1});
      expect((await sync).icons, hasLength(2));
    });

    test('two sets at once each go ahead', () async {
      serve({
        '/one.json': iconSet(['a']),
        '/two.json': iconSet(['a', 'b']),
      });
      held = Completer();
      final one = icons().importUrl(urlOf('/one.json'));
      final two = icons().importUrl(urlOf('/two.json'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      held!.complete();
      final [a, b] = await Future.wait([one, two]);

      expect(hits, {'/one.json': 1, '/two.json': 1});
      expect(a.icons, hasLength(1));
      expect(b.icons, hasLength(2));
    });
  });

  group('a script', () {
    ScriptsAction scripts() => container.read(scriptsActionProvider.notifier);

    Future<(Script, String)> added() async {
      serve({'/s.js': 'const main = (c) => c;'});
      final script = await Script(
        id: 5,
        label: 'S',
        url: urlOf('/s.js'),
        lastUpdateTime: DateTime(2020),
      ).save('');
      scripts().putScript(script);
      await scripts().updateScript(script);
      await resourceCache.store.saved;
      await pumpEventQueue();
      final path = await script.path;
      backdate(path);
      container
          .read(scriptsProvider.notifier)
          .put(script.copyWith(lastUpdateTime: old));
      await pumpEventQueue();
      setup.applies = 0;
      resetCounts();
      return ((await testDatabase.scriptsDao.query().get()).single, path);
    }

    test('unchanged: one 304, no rewrite and no reapply', () async {
      final (script, path) = await added();

      await scripts().updateScript(script);
      await pumpEventQueue();

      expect(notModified, {'/s.js': 1});
      expect(untouched(path), isTrue);
      expect(setup.applies, 0);
      final saved = (await testDatabase.scriptsDao.query().get()).single;
      expect(saved.lastUpdateTime.isAfter(script.lastUpdateTime), isTrue);
    });

    test('changed content is written and reapplied', () async {
      final (script, path) = await added();
      served['/s.js']!.body = 'const main = (c) => ({...c});';

      await scripts().updateScript(script);
      await pumpEventQueue();

      expect(conditional, {'/s.js': 1});
      expect(notModified, isEmpty);
      expect(await File(path).readAsString(), served['/s.js']!.body);
      expect(setup.applies, 1);
    });

    test('a server without validators: same bytes are not rewritten', () async {
      final (script, path) = await added();
      served['/s.js']!.validators = false;
      await scripts().updateScript(script);
      backdate(path);
      setup.applies = 0;
      resetCounts();

      await scripts().updateScript(script);
      await pumpEventQueue();

      expect(hits, {'/s.js': 1});
      expect(conditional, isEmpty);
      expect(untouched(path), isTrue);
      expect(setup.applies, 0);
    });

    test('a file edited by hand drops the validators', () async {
      final (script, path) = await added();
      await File(path).writeAsString('// mine');
      resetCounts();

      await scripts().updateScript(script);

      expect(conditional, isEmpty);
      expect(await File(path).readAsString(), served['/s.js']!.body);
    });

    test('an unreadable validator file starts over without them', () async {
      final (script, _) = await added();
      final store = ResourceValidatorStore();
      final storePath = join(home.path, ResourceValidatorStore.fileName);
      await File(storePath).writeAsString('{not json');
      final cache = ResourceCache(store);

      final fetched = await cache.fetch(
        ResourceKind.script,
        script.url!,
        holds: (_) async => true,
      );

      expect(fetched, isA<ResourceDownloaded>());
      expect(conditional, isEmpty);
      await cache.commit(
        ResourceKind.script,
        script.url!,
        fetched as ResourceDownloaded,
      );
      await store.saved;
      expect(
        json.decode(await File(storePath).readAsString()),
        contains(ResourceCache.keyOf(ResourceKind.script, script.url!)),
      );
    });

    for (final mode in _Mode.values.where((mode) => mode != _Mode.ok)) {
      test('a ${mode.name} keeps the file, leaves no temp file, and the next '
          'attempt works', () async {
        final (script, path) = await added();
        final served0 = served['/s.js']!
          ..mode = mode
          ..body = 'const main = (c) => null;';

        await expectLater(scripts().updateScript(script), throwsA(anything));

        expect(await File(path).readAsString(), 'const main = (c) => c;');
        expect(untouched(path), isTrue);
        expect(await tempFiles(), isEmpty);
        expect(setup.applies, 0);

        served0.mode = _Mode.ok;
        resetCounts();
        await scripts().updateScript(script);

        expect(hits, {'/s.js': 1});
        expect(notModified, isEmpty);
        expect(await File(path).readAsString(), served0.body);
      });
    }

    test('two updates at once download once', () async {
      final (script, _) = await added();
      served['/s.js']!.body = 'const main = (c) => ({...c});';
      held = Completer();

      final first = scripts().updateScript(script);
      final second = scripts().updateScript(script);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      held!.complete();
      await Future.wait([first, second]);
      await pumpEventQueue();

      expect(hits, {'/s.js': 1});
      expect(setup.applies, 1);
    });
  });

  group('a remote MITM script', () {
    Future<MitmScript> stored() async {
      serve({'/s.js': 'one'});
      final url = urlOf('/s.js');
      final file = await storeMitmScript(url, 'one'.codeUnits);
      final script = MitmScript(
        id: 3,
        line: 'S = type=http-request,pattern=^https://a,script-path=$file',
        url: url,
        source: url,
        file: file,
      );
      container.listen(profileMitmScriptsProvider(1), (_, _) {});
      await container.read(profileMitmScriptsProvider(1).notifier).commit([
        script,
      ]);
      return (await container.read(
        profileMitmScriptsProvider(1).future,
      )).single;
    }

    test('unchanged: a 304 after the first check, and the Core still checks '
        'the stored file', () async {
      final script = await stored();
      final first = await checkMitmScriptUpdate(container.read, 1, script);
      await resourceCache.store.saved;
      resetCounts();
      validations = 0;

      final second = await checkMitmScriptUpdate(container.read, 1, first);

      expect(notModified, {'/s.js': 1});
      expect(validations, 1);
      expect(second.file, script.file);
      expect(second.hasPending, isFalse);
      expect(second.failure, isNull);
    });

    test('content that waits stays waiting on a 304', () async {
      final script = await stored();
      served['/s.js']!.body = 'two';
      final pending = await checkMitmScriptUpdate(container.read, 1, script);
      await resourceCache.store.saved;
      resetCounts();

      final again = await checkMitmScriptUpdate(container.read, 1, pending);

      expect(notModified, {'/s.js': 1});
      expect(again.pendingFile, pending.pendingFile);
    });

    test('two checks at once download once', () async {
      final script = await stored();
      held = Completer();

      final first = checkMitmScriptUpdate(container.read, 1, script);
      final second = checkMitmScriptUpdate(container.read, 1, script);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      held!.complete();
      final results = await Future.wait([first, second]);

      expect(hits, {'/s.js': 1});
      expect(results.first, results.last);
    });
  });

  group('SingleFlight', () {
    test('joins a running key, shares its error, then runs anew', () async {
      final flight = SingleFlight<String, int>();
      var runs = 0;
      final gate = Completer<void>();
      Future<int> task() async {
        runs++;
        await gate.future;
        throw StateError('boom');
      }

      final a = flight.run('k', task);
      final b = flight.run('k', task);
      final c = flight.run('other', () async => 7);
      expect(flight.isRunning('k'), isTrue);
      gate.complete();

      await expectLater(a, throwsStateError);
      await expectLater(b, throwsStateError);
      expect(await c, 7);
      expect(runs, 1);
      expect(flight.isRunning('k'), isFalse);
      expect(await flight.run('k', () async => 1), 1);
    });
  });
}
