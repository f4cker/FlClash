import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_database_providers.dart';
import '../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

void main() {
  late Directory tempDir;
  late _MockCoreHandlerInterface core;
  late Script script;
  late ScriptEvaluator engine;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('script_outbounds_test');
    await useAppPaths(tempDir);
    script = await Script(
      id: 7,
      label: 'rename',
      lastUpdateTime: DateTime(2026),
    ).save('const main = (config) => config;');
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  setUp(() {
    engine = scriptEvaluator;
    core = _MockCoreHandlerInterface();
    when(() => core.readConfig(any())).thenAnswer(
      (_) async => <String, dynamic>{
        'proxies': [
          {'name': 'node', 'type': 'ss', 'server': 'example.com'},
        ],
        'proxy-groups': [
          {
            'name': 'Before',
            'type': 'select',
            'proxies': ['node'],
          },
        ],
      },
    );
  });

  tearDown(() => scriptEvaluator = engine);

  Future<ClashConfig?> outboundsOf(Profile profile) {
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        scriptsProvider.overrideWith(() => TestScripts([script])),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    addTearDown(container.dispose);
    final provider = scriptOutboundsProvider(profile.id);
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  test('lists the groups the script hands the core', () async {
    final inputs = <Map<String, dynamic>>[];
    scriptEvaluator = ({required String script, required String config}) async {
      final input = json.decode(config) as Map<String, dynamic>;
      inputs.add(input);
      return json.encode({
        ...input,
        'proxy-groups': [
          {
            'name': 'After',
            'type': 'url-test',
            'proxies': ['node'],
          },
        ],
      });
    };
    final profile = Profile.normal(label: 'sub').copyWith(scriptId: script.id);

    final config = await outboundsOf(profile);

    expect(inputs.single['proxy-providers'], isEmpty);
    expect(config!.proxyGroups.map((group) => group.name), ['After']);
    expect(config.proxyGroups.single.type, GroupType.URLTest);
    expect(config.proxies.map((proxy) => (proxy.name, proxy.type)), [
      ('node', 'ss'),
    ]);
  });

  test('a script that fails is an error, not the groups before it', () async {
    scriptEvaluator = ({required String script, required String config}) =>
        Future.error(StateError('main is not a function'));
    final profile = Profile.normal(label: 'sub').copyWith(scriptId: script.id);

    await expectLater(
      outboundsOf(profile),
      throwsA(
        isA<MessageException>().having(
          (error) => error.message,
          'message',
          contains('main is not a function'),
        ),
      ),
    );
  });

  test('a profile without a script runs none', () async {
    final profile = Profile.normal(label: 'sub');

    expect(await outboundsOf(profile), isNull);
    verifyNever(() => core.readConfig(any()));
  });

  test('a scripts read failing after it loaded keeps the groups, and runs '
      'nothing again', () async {
    var runs = 0;
    scriptEvaluator = ({required String script, required String config}) {
      runs++;
      return Future.value(config);
    };
    final profile = Profile.normal(label: 'sub').copyWith(scriptId: script.id);
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        scriptsProvider.overrideWith(() => TestScripts([script])),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    addTearDown(container.dispose);
    final provider = scriptOutboundsProvider(profile.id);
    final states = <AsyncValue<ClashConfig?>>[];
    container.listen(provider, (_, next) => states.add(next));
    final before = await container.read(provider.future);
    expect(before!.proxyGroups.map((group) => group.name), ['Before']);
    expect(runs, 1);
    states.clear();

    // What the database's live read reports when a later query fails.
    container.read(scriptsProvider.notifier).state = AsyncError(
      StateError('database is locked'),
      StackTrace.current,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(scriptsProvider).hasError, isTrue);
    final after = container.read(provider);
    expect(after.hasError, isFalse);
    expect(after.isLoading, isFalse);
    expect(after.value, before);
    expect(states, isEmpty);
    expect(runs, 1);
  });

  group('read live', () {
    late StreamController<List<Script>> rows;
    late List<String> ran;

    setUp(() {
      rows = StreamController<List<Script>>.broadcast();
      ran = [];
      // Hands back one group named after the script, so a run shows which.
      scriptEvaluator = ({required String script, required String config}) {
        ran.add(script);
        final input = json.decode(config) as Map<String, dynamic>;
        return Future.value(
          json.encode({
            ...input,
            'proxy-groups': [
              {
                'name': script.trim(),
                'type': 'select',
                'proxies': ['node'],
              },
            ],
          }),
        );
      };
    });

    tearDown(() => rows.close());

    ProviderContainer containerOf(Profile profile) {
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          scriptsProvider.overrideWith(() => _LiveScripts(rows)),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    List<String>? groupsOf(AsyncValue<ClashConfig?> state) =>
        state.value?.proxyGroups.map((group) => group.name).toList();

    test('a list read only after the groups are asked for runs the script '
        'once it arrives, and once only', () async {
      final profile = Profile.normal(
        label: 'sub',
      ).copyWith(scriptId: script.id);
      final container = containerOf(profile);
      final provider = scriptOutboundsProvider(profile.id);
      final states = <AsyncValue<ClashConfig?>>[];
      container.listen(provider, (_, next) => states.add(next));
      await settle();
      expect(container.read(provider).isLoading, isTrue);
      expect(ran, isEmpty);

      rows.add([script]);
      final config = await container.read(provider.future);
      await settle();

      expect(config!.proxyGroups.single.name, contains('main'));
      expect(ran, hasLength(1));
      // Never an answer of no script on the way.
      expect(states.whereType<AsyncData<ClashConfig?>>(), hasLength(1));
      expect(groupsOf(container.read(provider)), [ran.single.trim()]);
    });

    test('a first read failing is the error, and the list recovering runs '
        'the script', () async {
      final profile = Profile.normal(
        label: 'sub',
      ).copyWith(scriptId: script.id);
      final container = containerOf(profile);
      final provider = scriptOutboundsProvider(profile.id);
      container.listen(provider, (_, _) {});
      await settle();

      rows.addError(StateError('database is locked'));
      await settle();
      expect(container.read(provider).hasError, isTrue);
      expect(ran, isEmpty);

      rows.add([script]);
      await settle();
      expect(container.read(provider).hasError, isFalse);
      expect(groupsOf(container.read(provider)), [ran.single.trim()]);
    });

    test('an edit or a delete arriving as the list recovers, or just after, '
        'reaches the groups', () async {
      final first = await Script(
        id: 8,
        label: 'edited',
        lastUpdateTime: DateTime(2026),
      ).save('one');
      final profile = Profile.normal(label: 'sub').copyWith(scriptId: 8);
      final container = containerOf(profile);
      final provider = scriptOutboundsProvider(profile.id);
      container.listen(provider, (_, _) {});
      await settle();
      rows.add([first]);
      await settle();
      expect(groupsOf(container.read(provider)), ['one']);

      // Failing: the groups stay.
      rows.addError(StateError('database is locked'));
      await settle();
      expect(groupsOf(container.read(provider)), ['one']);

      // Edited while it failed: the read that recovers carries the edit.
      final second = await first.save('two');
      rows.add([second]);
      await settle();
      expect(container.read(scriptsProvider).hasError, isFalse);
      expect(groupsOf(container.read(provider)), ['two']);
      expect(ran, ['one', 'two']);

      // Recovering unchanged runs nothing; a delete right after still lands.
      rows.addError(StateError('database is locked'));
      await settle();
      rows.add([second]);
      await settle();
      expect(ran, ['one', 'two']);
      rows.add(const []);
      await settle();
      expect(container.read(provider).hasValue, isTrue);
      expect(container.read(provider).value, isNull);
      expect(ran, ['one', 'two']);
    });
  });
}

/// Scripts as the database's live read reports them, rows and errors alike.
class _LiveScripts extends Scripts {
  _LiveScripts(this.rows);

  final StreamController<List<Script>> rows;

  @override
  Stream<List<Script>> build() => rows.stream;
}
