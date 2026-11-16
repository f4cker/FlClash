import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yaml/yaml.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory home;
  late _MockCoreHandlerInterface core;
  late ProviderContainer container;

  setUpAll(() async {
    loadAppLocalizations(const Locale('en'));
    home = Directory.systemTemp.createTempSync('flclash-profiles-action-');
    await useAppPaths(home);
  });

  tearDownAll(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  setUp(() {
    core = _MockCoreHandlerInterface();
    when(() => core.validateConfig(any())).thenAnswer((_) async => null);
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(currentProfileIdProvider, (_, _) {});
    globalState.container = container;
  });

  void decodesTo(String link, List<Map<String, dynamic>> proxies) {
    when(
      () => core.decodeShareLinks([link]),
    ).thenAnswer((_) async => [proxies]);
  }

  Future<void> pumpHost(WidgetTester tester) async {
    const size = Size(1200, 1000);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: SizedBox()),
      ),
    );
  }

  Future<List<Map>> savedProxies(Profile profile) async {
    final config = loadYaml(await (await profile.file).readAsString()) as Map;
    return [for (final proxy in config['proxies'] as List) proxy as Map];
  }

  group('addProfileFromLink with a share link', () {
    test('saves a file profile named after the proxy it holds', () async {
      const link = 'vless://id@hk.example.com:443#HK';
      decodesTo(link, [
        {'name': 'HK', 'type': 'vless', 'server': 'hk.example.com'},
      ]);

      await container
          .read(profilesActionProvider.notifier)
          .addProfileFromLink(link);

      final profile = container.read(profilesProvider).single;
      expect(profile.type, ProfileType.file);
      expect(profile.url, isEmpty);
      expect(profile.label, 'HK');
      expect(await savedProxies(profile), [
        {'name': 'HK', 'type': 'vless', 'server': 'hk.example.com'},
      ]);
      verify(() => core.validateConfig(any())).called(1);
    });

    test('names an unnamed proxy after its server', () async {
      const link = 'ss://YWVzLTEyOC1nY206cGFzcw@ss.example.com:8388';
      decodesTo(link, [
        {'name': '', 'type': 'ss', 'server': 'ss.example.com'},
      ]);

      await container
          .read(profilesActionProvider.notifier)
          .addProfileFromLink(link, label: 'Mine');

      final profile = container.read(profilesProvider).single;
      expect(profile.label, 'Mine');
      expect((await savedProxies(profile)).single['name'], 'ss.example.com');
    });

    test('moves a proxy off a name mihomo reserves', () async {
      const link = 'trojan://pass@t.example.com:443#DIRECT';
      decodesTo(link, [
        {'name': 'DIRECT', 'type': 'trojan', 'server': 't.example.com'},
      ]);

      await container
          .read(profilesActionProvider.notifier)
          .addProfileFromLink(link);

      final profile = container.read(profilesProvider).single;
      expect((await savedProxies(profile)).single['name'], 'DIRECT-01');
    });

    testWidgets('reports a link no proxy can be read from and adds nothing', (
      tester,
    ) async {
      const link = 'vmess://not-base64';
      decodesTo(link, const []);
      await pumpHost(tester);

      await container
          .read(profilesActionProvider.notifier)
          .addProfileFromLink(link);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text(currentAppLocalizations.shareLinksInvalid), findsOne);
      expect(container.read(profilesProvider), isEmpty);
      verifyNever(() => core.validateConfig(any()));
    });
  });

  group('addProfilesFromLinks with share links', () {
    const links = [
      'vless://id@hk.example.com:443#HK',
      'trojan://pass@hk2.example.com:443#HK',
      'ss://YWVzLTEyOC1nY206cGFzcw@ss.example.com:8388',
    ];

    test('makes one profile of all their proxies', () async {
      when(() => core.decodeShareLinks(links)).thenAnswer(
        (_) async => [
          [
            {'name': 'HK', 'type': 'vless', 'server': 'hk.example.com'},
          ],
          [
            {'name': 'HK', 'type': 'trojan', 'server': 'hk2.example.com'},
          ],
          [
            {'name': '', 'type': 'ss', 'server': 'ss.example.com'},
          ],
        ],
      );

      await container
          .read(profilesActionProvider.notifier)
          .addProfilesFromLinks(links);

      final profile = container.read(profilesProvider).single;
      expect(profile.type, ProfileType.file);
      expect(
        profile.label,
        currentAppLocalizations.proxiesProfileLabel('HK', 3),
      );
      expect(
        [for (final proxy in await savedProxies(profile)) proxy['name']],
        ['HK', 'HK-01', 'ss.example.com'],
      );
      verify(() => core.decodeShareLinks(links)).called(1);
    });

    testWidgets('names the link no proxy can be read from and adds nothing', (
      tester,
    ) async {
      when(() => core.decodeShareLinks(links)).thenAnswer(
        (_) async => [
          [
            {'name': 'HK', 'type': 'vless', 'server': 'hk.example.com'},
          ],
          const [],
          [
            {'name': '', 'type': 'ss', 'server': 'ss.example.com'},
          ],
        ],
      );
      await pumpHost(tester);

      await container
          .read(profilesActionProvider.notifier)
          .addProfilesFromLinks(links);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final l10n = currentAppLocalizations;
      expect(
        find.text(
          l10n.failedItem(links.first, l10n.shareLinkUnreadable(links[1])),
        ),
        findsOne,
      );
      expect(container.read(profilesProvider), isEmpty);
      verifyNever(() => core.validateConfig(any()));
    });
  });

  group('fetchSource', () {
    late db.Database testDatabase;
    const target = Profile(
      id: 1,
      label: 'Base',
      autoUpdateDuration: Duration.zero,
    );
    const source = Profile(
      id: 2,
      label: 'Air',
      type: ProfileType.url,
      url: 'https://example.invalid/sub',
      autoUpdateDuration: Duration.zero,
    );

    setUp(() async {
      testDatabase = db.Database(NativeDatabase.memory());
      db.database = testDatabase;
      addTearDown(testDatabase.close);
      await testDatabase.profilesDao.putAll([
        target.toCompanion(),
        source.toCompanion(),
      ]);
      container.read(profilesProvider.notifier).put(target);
      container.read(profilesProvider.notifier).put(source);
      final cache = File(await appPath.getProfilePath('2'));
      await cache.parent.create(recursive: true);
      await cache.writeAsString('proxies: [old]');
    });

    Future<void> mount() async {
      await testDatabase.mountsDao.save(
        targetId: 1,
        expectedVersion: null,
        sourceIds: [2],
        pending: (version) =>
            MountOperation(kind: MountOperationKind.save, version: version),
      );
      await testDatabase.mountsDao.settle(1, 1);
    }

    void inspectsAs(MountSourceStatus status) {
      when(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
        ),
      ).thenAnswer((_) async => MountSourceInspection(status: status));
    }

    Future<Profile?> save(String body) {
      return container
          .read(profilesActionProvider.notifier)
          .fetchSource(
            2,
            (validate, publish, install) => source.saveFile(
              Uint8List.fromList(utf8.encode(body)),
              validate: validate,
              publish: publish,
              install: install,
            ),
          );
    }

    Future<String> cache() async =>
        File(await appPath.getProfilePath('2')).readAsString();

    test('setup cache hit cannot supersede an actual refresh', () async {
      final gate = Completer<void>();
      final ready = Completer<void>();
      final profiles = container.read(profilesActionProvider.notifier);
      final updating = profiles.fetchSource(
        2,
        (validate, publish, install) => source.saveFile(
          Uint8List.fromList('proxies: [new]'.codeUnits),
          validate: (path, key) async {
            ready.complete();
            await gate.future;
            return validate(path, key);
          },
          publish: publish,
          install: install,
        ),
      );
      await ready.future;
      expect(await profiles.ensureSource(source), isNull);
      gate.complete();
      expect(await updating, isNotNull);
      expect(await cache(), 'proxies: [new]');
    });

    test(
      'older completed metadata cannot overwrite a newer download',
      () async {
        final profiles = container.read(profilesActionProvider.notifier);
        final old = await save('proxies: [old-result]');
        final newest = await save('proxies: [new-result]');
        expect(profiles.commitSourceUpdate(newest!), isNotNull);
        expect(profiles.commitSourceUpdate(old!), isNull);
        expect(await cache(), 'proxies: [new-result]');
      },
    );

    test('a mounted-only candidate skips full profile validation', () async {
      await mount();
      inspectsAs(MountSourceStatus.nodes);
      await save('proxies: []\nrules: [raw-export]');
      verifyNever(() => core.validateConfig(any()));
    });

    test(
      'a mounted source selected standalone still validates full profile',
      () async {
        await mount();
        container.read(currentProfileIdProvider.notifier).value = 2;
        inspectsAs(MountSourceStatus.nodes);
        await save('proxies: []');
        verify(() => core.validateConfig(any())).called(1);
      },
    );

    test(
      'selection switch during node inspection blocks unvalidated publication',
      () async {
        await mount();
        final ready = Completer<void>();
        final gate = Completer<MountSourceInspection>();
        when(
          () => core.inspectMountSource(
            any(),
            ageSecretKey: any(named: 'ageSecretKey'),
          ),
        ).thenAnswer((_) {
          ready.complete();
          return gate.future;
        });
        final pending = save('proxies: [new]');
        await ready.future;
        container.read(currentProfileIdProvider.notifier).value = 2;
        gate.complete(
          const MountSourceInspection(status: MountSourceStatus.nodes),
        );
        expect(await pending, isNull);
        expect(await cache(), 'proxies: [old]');
      },
    );

    test(
      'mutating validation cannot replace canonical raw download bytes',
      () async {
        const raw = 'synthetic-encrypted-or-share-link-source';
        final updated = await container
            .read(profilesActionProvider.notifier)
            .fetchSource(
              2,
              (validate, publish, install) => source.saveFile(
                Uint8List.fromList(raw.codeUnits),
                validate: (path, key) async {
                  await File(path).writeAsString('proxies: []');
                  return null;
                },
                publish: publish,
                install: install,
              ),
            );
        expect(updated, isNotNull);
        expect(await cache(), raw);
      },
    );

    test('newest overlapping candidate alone publishes raw bytes', () async {
      final first = Completer<void>();
      final ready = Completer<void>();
      final profiles = container.read(profilesActionProvider.notifier);
      final old = profiles.fetchSource(
        2,
        (validate, publish, install) => source.saveFile(
          Uint8List.fromList('proxies: [stale]'.codeUnits),
          validate: (path, key) async {
            ready.complete();
            await first.future;
            return validate(path, key);
          },
          publish: publish,
          install: install,
        ),
      );
      await ready.future;
      expect(await save('proxies: [new]\nrules: [raw-export]'), isNotNull);
      first.complete();
      expect(await old, isNull);
      expect(await cache(), 'proxies: [new]\nrules: [raw-export]');
    });

    for (final edit in ['delete', 'url', 'key', 'type', 'restore', 'cancel']) {
      test('$edit supersedes a validated but unpublished candidate', () async {
        final gate = Completer<void>();
        final ready = Completer<void>();
        final profiles = container.read(profilesActionProvider.notifier);
        final updating = profiles.fetchSource(
          2,
          (validate, publish, install) => source.saveFile(
            Uint8List.fromList('proxies: [stale]'.codeUnits),
            validate: (path, key) async {
              final issue = await validate(path, key);
              ready.complete();
              await gate.future;
              return issue;
            },
            publish: publish,
            install: install,
          ),
        );
        await ready.future;
        final store = container.read(profilesProvider.notifier);
        switch (edit) {
          case 'delete':
            await store.del(2);
          case 'url':
            store.put(source.copyWith(url: 'https://example.invalid/new'));
          case 'key':
            store.put(source.copyWith(ageSecretKey: 'new-key'));
          case 'type':
            store.put(source.copyWith(type: ProfileType.file));
          case 'restore':
            store.put(source.copyWith(url: 'https://example.invalid/new'));
            store.put(source);
          case 'cancel':
            profiles.cancelSourceUpdate(2);
        }
        gate.complete();
        expect(await updating, isNull);
        expect(await cache(), 'proxies: [old]');
      });
    }

    test('a mounted source keeps its cache on content without nodes', () async {
      await mount();
      inspectsAs(MountSourceStatus.unsupported);

      await expectLater(
        save('{}'),
        throwsA(
          isA<MessageException>().having(
            (error) => error.message,
            'message',
            currentAppLocalizations.mountSourceNoNodeList,
          ),
        ),
      );

      expect(await cache(), 'proxies: [old]');
      final status = (await testDatabase.mountsDao.statuses())[2]!;
      expect(status.failure, MountSourceFailure.unsupported);
    });

    test(
      'a mounted source takes a real empty list and clears its failure',
      () async {
        await mount();
        await testDatabase.mountsDao.recordSourceResult(
          2,
          failure: MountSourceFailure.fetch,
          at: DateTime(2026),
        );
        inspectsAs(MountSourceStatus.nodes);

        expect(await save('proxies: []'), isNotNull);

        expect(await cache(), 'proxies: []');
        final status = (await testDatabase.mountsDao.statuses())[2]!;
        expect(status.failure, isNull);
        expect(status.succeededAt, isNotNull);
      },
    );

    test('a mounted source is inspected with its own age key', () async {
      await mount();
      inspectsAs(MountSourceStatus.nodes);

      await container
          .read(profilesActionProvider.notifier)
          .fetchSource(
            2,
            (validate, publish, install) => source
                .copyWith(ageSecretKey: 'own-key')
                .saveFile(
                  Uint8List.fromList(utf8.encode('proxies: []')),
                  validate: validate,
                  publish: publish,
                  install: install,
                ),
          );

      verify(
        () => core.inspectMountSource(any(), ageSecretKey: 'own-key'),
      ).called(1);
    });

    test('a failed download of a mounted source is recorded', () async {
      await mount();

      await expectLater(
        container
            .read(profilesActionProvider.notifier)
            .fetchSource(
              2,
              (_, _, _) async => throw const SocketException('down'),
            ),
        throwsA(isA<SocketException>()),
      );

      expect(await cache(), 'proxies: [old]');
      final status = (await testDatabase.mountsDao.statuses())[2]!;
      expect(status.failure, MountSourceFailure.fetch);
    });

    test('a source nobody mounts is neither inspected nor recorded', () async {
      expect(await save('{}'), isNotNull);

      expect(await cache(), '{}');
      verifyNever(
        () => core.inspectMountSource(
          any(),
          ageSecretKey: any(named: 'ageSecretKey'),
        ),
      );
      expect(await testDatabase.mountsDao.statuses(), isEmpty);
    });
  });
}
