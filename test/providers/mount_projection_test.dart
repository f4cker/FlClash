import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/spill.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _RecordingCore extends CoreHandlerInterface {
  Object? arguments;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();

  @override
  Future<Object?> invokeMethod({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
    CoreResultModel? model,
  }) async {
    expect(method, CoreMethod.mountInspectTarget);
    this.arguments = arguments;
    return {'groups': [], 'relay': []};
  }
}

class _CountingSetup extends SetupAction {
  int fullBuilds = 0;

  @override
  void build() {}

  @override
  Future<BuiltProfile> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    fullBuilds++;
    return (
      yaml: 'proxies: []',
      md5: 'fixture',
      counts: configCountsOf(const {}),
      base: null,
      ruleSources: const <RuleSource>[],
    );
  }
}

void main() {
  late Directory home;
  late db.Database database;
  const normal = Profile(
    id: 1,
    type: ProfileType.url,
    label: 'Normal',
    autoUpdateDuration: Duration.zero,
  );
  const custom = Profile(
    id: 2,
    type: ProfileType.custom,
    autoUpdateDuration: Duration.zero,
    overrides: ProfileOverrides(
      proxyProviders: {'Normal': ProxyProviderOptions(filter: 'HK')},
    ),
  );
  const state = SetupState(
    profileId: 1,
    profileLastUpdateDate: null,
    profileType: ProfileType.url,
    rules: [],
    proxyGroups: [],
    addedRules: [],
    script: null,
    overrides: ProfileOverrides(),
  );

  setUp(() async {
    home = Directory.systemTemp.createTempSync('mount-projection-');
    await useAppPaths(home);
    await mockPreferences();
    database = db.Database(NativeDatabase.memory());
    db.database = database;
  });

  tearDown(() async {
    await database.close();
    await home.delete(recursive: true);
  });

  ProviderContainer containerFor(
    List<Profile> profiles, {
    bool baseline = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(profiles)),
        setupActionProvider.overrideWith(_CountingSetup.new),
        safeModeProvider.overrideWithValue(true),
        setupStateProvider.overrideWith((_, _) {
          if (!baseline) {
            throw StateError(
              'Display must not build full setup/rule/MITM inputs',
            );
          }
          return state;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'baseline full target builds once; normal projection builds zero',
    () async {
      final baseline = containerFor([normal], baseline: true);
      final oldAction =
          baseline.read(setupActionProvider.notifier) as _CountingSetup;
      await oldAction.mountTargetInput(1);
      expect(oldAction.fullBuilds, 1);

      final container = containerFor([normal]);
      final action =
          container.read(setupActionProvider.notifier) as _CountingSetup;
      for (var i = 0; i < 3; i++) {
        final input = await action.mountTargetProjectionInput(1);
        expect(input.base!.path, await appPath.getProfilePath('1'));
        expect(input.base!.overlay, '{}');
        expect(input.config, isNull);
      }
      expect(action.fullBuilds, 0);
      expect(await File(await appPath.getProfilePath('1')).exists(), isFalse);
    },
  );

  test(
    'custom projection keeps definitions and never reads rule/MITM inputs',
    () async {
      const group = ProxyGroup(
        id: 10,
        name: 'My group',
        type: GroupType.Selector,
        proxies: ['Local'],
        use: ['Normal'],
        includeAllProxies: true,
        hidden: true,
        emptyFallback: 'REJECT',
      );
      const proxy = CustomProxy(
        id: 20,
        definition: {'name': 'Local', 'type': 'direct'},
      );
      await database.profiles.put(custom.toCompanion());
      await database.proxyGroups.put(group.toCompanion(2));
      await database.customProxiesDao.order(proxy: proxy, order: 'a0');
      final container = containerFor([normal, custom]);
      final action =
          container.read(setupActionProvider.notifier) as _CountingSetup;
      final input = await action.mountTargetProjectionInput(2);
      final config = json.decode(input.config!) as Map;
      expect(input.base, isNull);
      expect(config.keys.toSet(), {
        'proxies',
        'proxy-groups',
        'proxy-providers',
      });
      expect(config['proxy-groups'], [group.definition]);
      expect(config['proxies'], [proxy.definition]);
      expect(config['proxy-providers'], {
        'Normal': {
          'type': 'file',
          'path': await appPath.getProfilePath('1'),
          'filter': 'HK',
        },
      });
      expect(action.fullBuilds, 0);
    },
  );

  test(
    'script groups are unavailable without reading or executing scripts',
    () async {
      final container = containerFor([normal.copyWith(scriptId: 99)]);
      final action =
          container.read(setupActionProvider.notifier) as _CountingSetup;
      await expectLater(
        action.mountTargetProjectionInput(1),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('unavailable for a script profile'),
          ),
        ),
      );
      expect(action.fullBuilds, 0);
    },
  );

  test(
    'display IPC is explicitly separate from authoritative inspection',
    () async {
      final core = _RecordingCore();
      await core.inspectMountTargetProjection(config: '{}', managedTarget: 1);
      expect(core.arguments, {
        'config': '{}',
        'managed-target': 1,
        'projection': true,
      });
      await core.inspectMountTarget(config: '{}', managedTarget: 1);
      expect(core.arguments, {'config': '{}', 'managed-target': 1});
    },
  );

  test(
    'a missing target is unavailable, not an empty valid projection',
    () async {
      final container = containerFor([]);
      await expectLater(
        container
            .read(setupActionProvider.notifier)
            .mountTargetProjectionInput(1),
        throwsStateError,
      );
    },
  );
}
