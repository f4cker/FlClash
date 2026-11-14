import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/composition_review.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/spill.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';
import 'package:yaml/yaml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _ReviewSetup extends SetupAction {
  final previews = <String>[];
  final pageSources = <Set<String>>[];
  final baseSources = <Set<String>>[];
  Future<bool> Function(String)? answer;
  int authorizations = 0;
  AuthorizeCode authorization = AuthorizeCode.none;
  final listenerCalls = <bool>[];
  DateTime? resumedAt;

  @override
  Future<void> setCoreRunning(bool running) async => listenerCalls.add(running);

  @override
  Future<DateTime?> serviceStartTime() async => resumedAt;

  @override
  Future<bool> reviewComposition(
    String yaml, {
    required Set<String> pagePaths,
    required Set<String> basePaths,
  }) async {
    previews.add(yaml);
    pageSources.add(Set.of(pagePaths));
    baseSources.add(Set.of(basePaths));
    return await answer?.call(yaml) ?? true;
  }

  @override
  Future<AuthorizeCode> authorizeCore() async {
    authorizations++;
    return authorization;
  }
}

class _FailRevisionStore extends InMemorySharedPreferencesStore {
  _FailRevisionStore() : super.withData({'flutter.compositionRevision': 0});
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.compositionRevision') return false;
    return super.setValue(valueType, key, value);
  }
}

class _UnavailableStore extends InMemorySharedPreferencesStore {
  _UnavailableStore() : super.empty();
  @override
  Future<Map<String, Object>> getAll() async => throw StateError('unavailable');
}

const _state = SetupState(
  profileId: null,
  profileLastUpdateDate: null,
  profileType: ProfileType.file,
  extendType: ExtendType.standard,
  rules: [],
  proxyGroups: [],
  addedRules: [],
  script: null,
  overrides: ProfileOverrides(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(
      const SetupParams(
        selectedMap: {},
        options: CoreOptions(testUrl: ''),
      ),
    );
    registerFallbackValue(const SetupBase(path: '', overlay: ''));
  });

  late Directory root;
  late File running;
  late _Core core;
  late _ReviewSetup action;
  late ProviderContainer container;
  late Profile profile;
  late List<SetupParams> pushes;
  String digest = 'saved-source-v1';
  String? rejected;
  Completer<void>? acknowledgement;

  Future<void> bind({bool custom = false}) async {
    profile = custom
        ? Profile.custom(label: 'synthetic')
        : Profile.normal(
            label: 'synthetic',
            url: 'https://invalid.test/no-refresh',
          );
    final savedSource = File(
      await appPath.getProfilePath(profile.id.toString()),
    );
    await savedSource.create(recursive: true);
    await savedSource.writeAsString('allow-lan: true\ntun: {enable: false}\n');
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        setupStateProvider.overrideWith(
          (_, id) => _state.copyWith(profileId: id, profileType: profile.type),
        ),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        setupActionProvider.overrideWith(() => action),
      ],
    );
    globalState.container = container;
    container.read(runningFindProcessModeProvider.notifier).value = 'off';
    // The real app's config/store observers keep these editable providers alive.
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(networkSettingProvider, (_, _) {});
    container.read(setupActionProvider.notifier);
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('source3066-adoption-');
    await useAppPaths(root);
    await mockPreferences({
      'config': '{}',
      'compositionRevision': 0,
      appliedConfigMd5Key: 'confirmed-old',
    });
    await AppLocalizations.load(const Locale('en'));
    globalState.packageInfo = PackageInfo(
      appName: 'Synthetic',
      packageName: 'test',
      version: '0',
      buildNumber: '0',
    );
    globalState.needInitStatus = true;
    globalState.lastConfigMd5 = 'confirmed-old';
    globalState.lastConfigCounts = (groups: 2, proxies: 3, rules: 4);
    running = File(await appPath.configFilePath);
    await running.create(recursive: true);
    await running.writeAsString('confirmed running sentinel\n');
    core = _Core();
    action = _ReviewSetup();
    pushes = [];
    digest = 'saved-source-v1';
    rejected = null;
    acknowledgement = null;
    when(() => core.getProfileBase(any())).thenAnswer(
      (_) async => ProfileBase(
        config: const {
          'allow-lan': true,
          'tun': {'enable': false},
          'dns': {'use-system-hosts': false},
        },
        digest: digest,
      ),
    );
    when(
      () => core.buildProfile(
        base: any(named: 'base'),
        config: any(named: 'config'),
        mounts: any(named: 'mounts'),
      ),
    ).thenAnswer((call) async {
      final base = call.namedArguments[#base] as SetupBase?;
      final text = base?.overlay ?? call.namedArguments[#config] as String;
      final full = Map<String, dynamic>.from(loadYaml(text) as Map);
      full['proxies'] = [
        {'name': 'cached-base-proxy', 'type': 'direct'},
      ];
      full['rules'] = ['MATCH,DIRECT'];
      final spill = File(
        join(await appPath.homeDirPath, coreSpillDirectoryName, 'review.yaml'),
      );
      await spill.create(recursive: true);
      await spill.writeAsString(await encodeYamlTask(full));
      return spill.path;
    });
    when(
      () => core.getProxies(),
    ).thenAnswer((_) async => const ProxiesData(all: [], proxies: {}));
    when(() => core.getExternalProviders()).thenAnswer((_) async => []);
    when(() => core.getTraffic(any())).thenAnswer((_) async => const Traffic());
    when(
      () => core.getTotalTraffic(any()),
    ).thenAnswer((_) async => const Traffic());
    when(() => core.resetTraffic()).thenAnswer((_) async {});
    when(
      () => core.getListeningMixedPort(),
    ).thenAnswer((_) async => container.read(effectiveMixedPortProvider));
    when(() => core.getListeningPorts()).thenAnswer((_) async => {});
    when(() => core.setupConfig(any())).thenAnswer((call) async {
      pushes.add(call.positionalArguments.single as SetupParams);
      expect(await running.readAsString(), 'confirmed running sentinel\n');
      if (acknowledgement != null) await acknowledgement!.future;
      if (rejected != null) {
        throw CoreMethodException(
          code: rejected!,
          message: 'synthetic rejection',
          details: const {'outcome': 'kept'},
        );
      }
    });
  });

  tearDown(() async {
    container.dispose();
    globalState.lastConfigMd5 = null;
    globalState.lastConfigCounts = null;
    await root.delete(recursive: true);
  });

  test(
    'existing config is pending; fresh install persists current revision',
    () async {
      await bind();
      await mockPreferences({configKey: '{}'});
      expect(await preferences.getCompositionRevision(), 0);
      await mockPreferences({});
      expect(await preferences.getCompositionRevision(), 1);
      // Reopening after first config save must not misidentify a fresh install.
      await (await SharedPreferences.getInstance()).setString(configKey, '{}');
      await preferences.rebind();
      expect(await preferences.getCompositionRevision(), 1);
    },
  );

  test(
    'Cancel blocks setup and automatic patch retries; explicit apply retries',
    () async {
      await bind();
      action.answer = (_) async => false;
      expect(await action.applyProfile(force: true), isFalse);
      expect(action.previews.single, contains('cached-base-proxy'));
      expect(action.authorizations, 0);
      expect(pushes, isEmpty);
      expect(await preferences.getCompositionRevision(), 0);
      await action.updateConfig();
      expect(action.previews, hasLength(1));
      expect(await action.applyProfile(), isFalse);
      expect(action.previews, hasLength(2));
      expect(globalState.lastConfigMd5, 'confirmed-old');
      expect(await running.readAsString(), 'confirmed running sentinel\n');
    },
  );

  test('each candidate parses its materialized YAML only once', () async {
    await bind();
    final source = await File(
      'lib/providers/actions/setup.dart',
    ).readAsString();
    final start = source.indexOf(
      'Future<_CompositionCandidate> _readCompositionCandidate()',
    );
    expect(start, isNonNegative);
    final candidate = source.substring(
      start,
      source.indexOf(
        'Future<_CompositionCandidate?> _reviewComposition()',
        start,
      ),
    );
    expect(RegExp(r'\bloadYaml\s*\(').allMatches(candidate), hasLength(1));
  });

  for (final invalid in {
    'blank': '   \n',
    'null': 'null\n',
    'scalar': 'not-a-map\n',
    'sequence': '[one, two]\n',
    'malformed': 'dns: [\n',
  }.entries) {
    test('rejects ${invalid.key} candidate without review or apply', () async {
      await bind();
      when(
        () => core.buildProfile(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).thenAnswer((_) async {
        final spill = File(
          join(
            await appPath.homeDirPath,
            coreSpillDirectoryName,
            'invalid.yaml',
          ),
        );
        await spill.create(recursive: true);
        await spill.writeAsString(invalid.value);
        return spill.path;
      });
      expect(await action.applyProfile(force: true), isFalse);
      expect(action.previews, isEmpty);
      expect(pushes, isEmpty);
      expect(await preferences.getCompositionRevision(), 0);
      expect(globalState.lastConfigMd5, 'confirmed-old');
      expect(await running.readAsString(), 'confirmed running sentinel\n');
    });
  }

  test(
    'Go profile.build merge fixture reaches review and still waits for ACK',
    () async {
      await bind();
      final materialized = await File(
        'test/fixtures/profile_build_merge_expected.yaml',
      ).readAsString();
      when(
        () => core.buildProfile(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).thenAnswer((_) async {
        final spill = File(
          join(await appPath.homeDirPath, coreSpillDirectoryName, 'merge.yaml'),
        );
        await spill.create(recursive: true);
        await spill.writeAsString(materialized);
        return spill.path;
      });
      acknowledgement = Completer<void>();
      final invoked = Completer<void>();
      when(() => core.setupConfig(any())).thenAnswer((call) async {
        pushes.add(call.positionalArguments.single as SetupParams);
        invoked.complete();
        await acknowledgement!.future;
      });
      final applying = action.applyProfile(force: true);
      await invoked.future;
      expect(action.previews, [materialized]);
      verify(
        () => core.buildProfile(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).called(3);
      expect(await preferences.getCompositionRevision(), 0);
      expect(globalState.lastConfigMd5, 'confirmed-old');
      expect(pushes, hasLength(1));
      acknowledgement!.complete();
      expect(await applying, isTrue);
      expect(await preferences.getCompositionRevision(), 1);
    },
  );

  test(
    'review marks actual saved GeoX children Page even when equal to file',
    () async {
      await bind();
      const urls = {
        GeoResource.GEOIP: 'https://invalid.test/synthetic-geoip',
        GeoResource.MMDB: 'https://invalid.test/synthetic-mmdb',
      };
      container
          .read(patchClashConfigProvider.notifier)
          .update((page) => page.copyWith(geoXUrl: urls));
      when(() => core.getProfileBase(any())).thenAnswer(
        (_) async =>
            ProfileBase(config: {'geox-url': urls.raw}, digest: digest),
      );
      action.answer = (_) async => false;
      expect(await action.applyProfile(), false);
      final values = compositionReviewValues(
        loadYaml(action.previews.single) as Map,
      );
      for (final entry in urls.raw.entries) {
        final path = 'geox-url.${entry.key}';
        expect(values[path], entry.value);
        expect(action.baseSources.single, contains(path));
        expect(action.pageSources.single, contains(path));
      }
      expect(action.pageSources.single, isNot(contains('geox-url.asn')));
      expect(action.pageSources.single, isNot(contains('geox-url.generated')));
      expect(pushes, isEmpty);
    },
  );

  test('stale Apply reprepares changed saved source and asks again', () async {
    await bind();
    action.answer = (_) async {
      if (action.previews.length == 1) {
        digest = 'saved-source-v2';
        container
            .read(patchClashConfigProvider.notifier)
            .update((page) => page.copyWith(allowLan: true));
        return true;
      }
      return false;
    };
    expect(await action.applyProfile(), isFalse);
    expect(action.previews, hasLength(2));
    expect(loadYaml(action.previews.first)['allow-lan'], false);
    expect(loadYaml(action.previews.last)['allow-lan'], true);
    expect(pushes, isEmpty);
    expect(await preferences.getCompositionRevision(), 0);
  });

  test(
    'revision advances only on full setup acknowledgement; ordinary patch does not review',
    () async {
      await bind();
      acknowledgement = Completer<void>();
      final invoked = Completer<void>();
      when(() => core.setupConfig(any())).thenAnswer((call) async {
        pushes.add(call.positionalArguments.single as SetupParams);
        invoked.complete();
        await acknowledgement!.future;
      });
      final applying = action.applyProfile(force: true);
      await invoked.future;
      expect(await preferences.getCompositionRevision(), 0);
      expect(globalState.lastConfigMd5, 'confirmed-old');
      acknowledgement!.complete();
      expect(await applying, isTrue);
      expect(await preferences.getCompositionRevision(), 1);
      expect(action.previews, hasLength(1));
      // An invalid controller still cannot bypass ordinary-path validation.
      container
          .read(patchClashConfigProvider.notifier)
          .update(
            (page) => page.copyWith(
              externalController: ExternalControllerStatus.open,
              secret: '',
            ),
          );
      await action.updateConfig();
      expect(action.previews, hasLength(1));
      expect(pushes, hasLength(1));
    },
  );

  test(
    'known rejection preserves running file, revision and confirmed metadata',
    () async {
      await bind();
      rejected = 'config_rejected';
      expect(await action.applyProfile(force: true), isFalse);
      expect(await preferences.getCompositionRevision(), 0);
      expect(globalState.lastConfigMd5, 'confirmed-old');
      expect(globalState.lastConfigCounts, (groups: 2, proxies: 3, rules: 4));
      expect(container.read(runningFindProcessModeProvider), 'off');
      expect(await running.readAsString(), 'confirmed running sentinel\n');
    },
  );

  test(
    'whole/custom uses private source and cleared overlay rules, never running file',
    () async {
      await bind(custom: true);
      when(() => core.setupConfig(any())).thenAnswer((call) async {
        final params = call.positionalArguments.single as SetupParams;
        pushes.add(params);
        expect(params.base, isNotNull);
        expect(params.base!.path, isNot(running.path));
        final source =
            loadYaml(await File(params.base!.path).readAsString()) as Map;
        final overlay = loadYaml(params.base!.overlay) as Map;
        expect(source['tun']['enable'], false);
        expect(overlay['rules'], isEmpty);
        expect(await running.readAsString(), 'confirmed running sentinel\n');
        throw const CoreMethodException(code: 'config_rejected', message: 'no');
      });
      expect(await action.applyProfile(force: true), isFalse);
      expect(await File(pushes.single.base!.path).exists(), false);
      expect(await preferences.getCompositionRevision(), 0);
      expect(await running.readAsString(), 'confirmed running sentinel\n');
    },
  );

  test(
    'pending explicit start Cancel never publishes running or starts listeners',
    () async {
      await bind();
      container.read(initProvider.notifier).value = true;
      container
          .read(networkSettingProvider.notifier)
          .update((network) => network.copyWith(autoSetSystemDns: true));
      container
          .read(patchClashConfigProvider.notifier)
          .update((page) => page.copyWith.tun(enable: true));
      container.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.authorized;
      final runningChanges = <int?>[];
      final dnsChanges = <bool>[];
      final runningSub = container.listen(
        runTimeProvider,
        (_, next) => runningChanges.add(next),
      );
      final dnsSub = container.listen(
        shouldPatchSystemDnsProvider,
        (_, next) => dnsChanges.add(next),
      );
      addTearDown(runningSub.close);
      addTearDown(dnsSub.close);
      action.answer = (_) async {
        expect(container.read(runTimeProvider), isNull);
        expect(container.read(shouldPatchSystemDnsProvider), false);
        expect(action.listenerCalls, isEmpty);
        return false;
      };
      expect(await action.setRunning(true), false);
      expect(action.listenerCalls, isEmpty);
      expect(runningChanges, isEmpty);
      expect(dnsChanges, isEmpty);
      expect(pushes, isEmpty);
    },
  );

  test(
    'Cancel on resumed service preserves its existing published runtime and listeners',
    () async {
      await bind();
      action.resumedAt = DateTime.now().subtract(const Duration(minutes: 3));
      container.read(runTimeProvider.notifier).value = 1234;
      container
          .read(networkSettingProvider.notifier)
          .update((network) => network.copyWith(autoSetSystemDns: true));
      container
          .read(patchClashConfigProvider.notifier)
          .update((page) => page.copyWith.tun(enable: true));
      container.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.authorized;
      final dnsChanges = <bool>[];
      final dnsSub = container.listen(
        shouldPatchSystemDnsProvider,
        (_, next) => dnsChanges.add(next),
        fireImmediately: true,
      );
      addTearDown(dnsSub.close);
      final changes = <int?>[];
      final sub = container.listen(
        runTimeProvider,
        (_, next) => changes.add(next),
      );
      addTearDown(sub.close);
      action.answer = (_) async {
        container.read(appVisibleProvider.notifier).value = false;
        container.read(appVisibleProvider.notifier).value = true;
        expect(container.read(runTimeProvider), 1234);
        return false;
      };
      await action.initStatus();
      expect(action.listenerCalls, isEmpty);
      expect(container.read(runTimeProvider), 1234);
      expect(changes, isEmpty);
      expect(globalState.needInitStatus, true);
      expect(container.read(shouldPatchSystemDnsProvider), true);
      expect(dnsChanges, [true]);
      expect(pushes, isEmpty);
    },
  );

  void publishResumed({required bool eligible}) {
    action.resumedAt = DateTime.now().subtract(const Duration(minutes: 3));
    container.read(runTimeProvider.notifier).value = 1234;
    container.read(listeningMixedPortProvider.notifier).value = 7890;
    container
        .read(networkSettingProvider.notifier)
        .update((network) => network.copyWith(autoSetSystemDns: true));
    container
        .read(patchClashConfigProvider.notifier)
        .update((page) => page.copyWith.tun(enable: true));
    container.read(authorizedTunEnableProvider.notifier).value = eligible
        ? TunAuthorizationState.authorized
        : TunAuthorizationState.none;
  }

  List<bool> observeDns() {
    final changes = <bool>[];
    final sub = container.listen(
      shouldPatchSystemDnsProvider,
      (_, next) => changes.add(next),
      fireImmediately: true,
    );
    addTearDown(sub.close);
    return changes;
  }

  for (final previouslyEligible in [false, true]) {
    test(
      'resumed Apply holds DNS eligibility $previouslyEligible through authorization until full ACK',
      () async {
        await bind();
        publishResumed(eligible: previouslyEligible);
        final dnsChanges = observeDns();
        final runningChanges = <int?>[];
        final sub = container.listen(
          runTimeProvider,
          (_, next) => runningChanges.add(next),
        );
        addTearDown(sub.close);
        action.answer = (_) async {
          // Also preserve an eligible old run if authorization is rechecked.
          container.read(authorizedTunEnableProvider.notifier).value =
              TunAuthorizationState.none;
          expect(
            container.read(shouldPatchSystemDnsProvider),
            previouslyEligible,
          );
          return true;
        };
        acknowledgement = Completer<void>();
        final invoked = Completer<void>();
        when(() => core.setupConfig(any())).thenAnswer((call) async {
          pushes.add(call.positionalArguments.single as SetupParams);
          invoked.complete();
          await acknowledgement!.future;
        });
        final resuming = action.initStatus();
        await invoked.future;
        expect(action.authorizations, 1);
        expect(
          container.read(authorizedTunEnableProvider),
          TunAuthorizationState.authorized,
        );
        container.read(appVisibleProvider.notifier).value = false;
        container.read(appVisibleProvider.notifier).value = true;
        expect(
          container.read(shouldPatchSystemDnsProvider),
          previouslyEligible,
        );
        expect(dnsChanges, [previouslyEligible]);
        expect(container.read(runTimeProvider), 1234);
        expect(runningChanges, isEmpty);
        expect(container.read(listeningMixedPortProvider), 7890);
        expect(action.listenerCalls, isEmpty);
        expect(globalState.lastConfigMd5, 'confirmed-old');
        expect(await running.readAsString(), 'confirmed running sentinel\n');
        expect(await preferences.getCompositionRevision(), 0);
        acknowledgement!.complete();
        await resuming;
        expect(container.read(shouldPatchSystemDnsProvider), true);
        expect(dnsChanges, previouslyEligible ? [true] : [false, true]);
        expect(await preferences.getCompositionRevision(), 1);
      },
    );

    for (final failure in [
      'authorization_refused',
      'service_refused',
      'no_response',
      'config_rejected',
    ]) {
      test(
        'resumed $failure preserves DNS eligibility $previouslyEligible and explicit stop restores',
        () async {
          await bind();
          publishResumed(eligible: previouslyEligible);
          final dnsChanges = observeDns();
          action.answer = (_) async {
            container.read(authorizedTunEnableProvider.notifier).value =
                TunAuthorizationState.none;
            return true;
          };
          if (failure == 'authorization_refused') {
            action.authorization = AuthorizeCode.error;
          } else {
            rejected = failure;
          }
          await action.initStatus();
          expect(
            container.read(shouldPatchSystemDnsProvider),
            previouslyEligible,
          );
          expect(dnsChanges, [previouslyEligible]);
          expect(container.read(runTimeProvider), 1234);
          expect(container.read(listeningMixedPortProvider), 7890);
          expect(action.listenerCalls, isEmpty);
          expect(await running.readAsString(), 'confirmed running sentinel\n');
          expect(await preferences.getCompositionRevision(), 0);
          expect(pushes, hasLength(failure == 'authorization_refused' ? 0 : 1));
          expect(await action.setRunning(false), true);
          expect(container.read(runTimeProvider), isNull);
          expect(container.read(shouldPatchSystemDnsProvider), false);
          expect(dnsChanges, previouslyEligible ? [true, false] : [false]);
          expect(action.listenerCalls, [false]);
        },
      );
    }
  }

  test(
    'Cancel resumed review then standalone Apply releases ticker only on ACK',
    () async {
      await bind();
      publishResumed(eligible: false);
      final dnsChanges = observeDns();
      action.answer = (_) async => false;
      await action.initStatus();
      expect(container.read(runTimeProvider), 1234);
      expect(dnsChanges, [false]);
      expect(action.authorizations, 0);
      action.answer = (_) async => true;
      acknowledgement = Completer<void>();
      final invoked = Completer<void>();
      when(() => core.setupConfig(any())).thenAnswer((call) async {
        pushes.add(call.positionalArguments.single as SetupParams);
        invoked.complete();
        await acknowledgement!.future;
      });
      final applying = action.applyProfile(force: true);
      await invoked.future;
      container.read(appVisibleProvider.notifier).value = false;
      container.read(appVisibleProvider.notifier).value = true;
      expect(container.read(runTimeProvider), 1234);
      expect(container.read(listeningMixedPortProvider), 7890);
      expect(dnsChanges, [false]);
      verifyNever(() => core.getTraffic(any()));
      acknowledgement!.complete();
      expect(await applying, true);
      expect(container.read(runTimeProvider), greaterThan(1234));
      expect(container.read(shouldPatchSystemDnsProvider), true);
      expect(dnsChanges, [false, true]);
      expect(action.listenerCalls, isEmpty);
      final tick = Completer<void>();
      when(() => core.getTraffic(any())).thenAnswer((_) async {
        if (!tick.isCompleted) tick.complete();
        return const Traffic();
      });
      await tick.future.timeout(const Duration(seconds: 3));
      expect(container.read(runTimeProvider), greaterThan(180000));
    },
  );

  test('explicit stop during held ACK is not gated or resurrected', () async {
    await bind();
    publishResumed(eligible: true);
    final dnsChanges = observeDns();
    acknowledgement = Completer<void>();
    final invoked = Completer<void>();
    when(() => core.setupConfig(any())).thenAnswer((_) async {
      invoked.complete();
      await acknowledgement!.future;
    });
    final resuming = action.initStatus();
    await invoked.future;
    expect(dnsChanges, [true]);
    expect(await action.setRunning(false), true);
    expect(container.read(runTimeProvider), isNull);
    expect(container.read(shouldPatchSystemDnsProvider), false);
    expect(action.listenerCalls, [false]);
    acknowledgement!.complete();
    await resuming;
    expect(container.read(runTimeProvider), isNull);
    expect(container.read(shouldPatchSystemDnsProvider), false);
    expect(dnsChanges, [true, false]);
    expect(action.listenerCalls, [false]);
  });

  test(
    'standalone ACK after cancelled new start never publishes running',
    () async {
      await bind();
      container.read(initProvider.notifier).value = true;
      action.answer = (_) async => false;
      expect(await action.setRunning(true), false);
      action.answer = (_) async => true;
      expect(await action.applyProfile(force: true), true);
      expect(container.read(runTimeProvider), isNull);
      expect(action.listenerCalls, isEmpty);
      verifyNever(() => core.getTraffic(any()));
    },
  );

  test(
    'automatic fullSetup and initStatus do not reopen a cancelled session review',
    () async {
      await bind();
      container.read(initProvider.notifier).value = true;
      action.answer = (_) async => false;
      expect(await action.applyProfile(), false);
      expect(await action.fullSetup(), false);
      await action.initStatus();
      expect(action.previews, hasLength(1));
      expect(pushes, isEmpty);
      expect(action.listenerCalls, isEmpty);
    },
  );

  for (final revision in [0, 1]) {
    test(
      'revision $revision authorization refusal preserves saved TUN and never applies false',
      () async {
        await bind();
        await mockPreferences({'compositionRevision': revision});
        container
            .read(patchClashConfigProvider.notifier)
            .update((page) => page.copyWith.tun(enable: true));
        action.authorization = AuthorizeCode.error;
        expect(await action.applyProfile(force: true), false);
        expect(action.authorizations, 1);
        expect(container.read(patchClashConfigProvider).tun.enable, true);
        if (revision == 0) {
          expect(loadYaml(action.previews.single)['tun']['enable'], true);
        }
        expect(pushes, isEmpty);
        expect(await preferences.getCompositionRevision(), revision);
      },
    );
  }

  test(
    'page-enabled TUN beats file false after mocked authorization, never false success',
    () async {
      await bind();
      container
          .read(patchClashConfigProvider.notifier)
          .update((page) => page.copyWith.tun(enable: true));
      expect(await action.applyProfile(force: true), true);
      expect(action.authorizations, 1);
      expect(loadYaml(action.previews.single)['tun']['enable'], true);
      expect(loadYaml(pushes.single.base!.overlay)['tun']['enable'], true);
      expect(container.read(patchClashConfigProvider).tun.enable, true);
      expect(await preferences.getCompositionRevision(), 1);
    },
  );

  test(
    'pending live patch uses reviewed full setup instead of a patch',
    () async {
      await bind();
      await action.updateConfig();
      expect(action.previews, hasLength(1));
      expect(pushes, hasLength(1));
      expect(await preferences.getCompositionRevision(), 1);
    },
  );

  test(
    'preparation failure never authorizes, applies or overwrites confirmed metadata',
    () async {
      await bind();
      when(
        () => core.buildProfile(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).thenThrow(StateError('synthetic build failure'));
      expect(await action.applyProfile(), false);
      expect(action.authorizations, 0);
      expect(action.previews, isEmpty);
      expect(pushes, isEmpty);
      expect(globalState.lastConfigMd5, 'confirmed-old');
      expect(await preferences.getCompositionRevision(), 0);
    },
  );

  for (final outcome in ['unknown', 'not_applied', 'default']) {
    test(
      'explicit $outcome rejection never claims the previous runtime remains confirmed',
      () async {
        await bind();
        when(() => core.setupConfig(any())).thenThrow(
          CoreMethodException(
            code: 'config_rejected',
            message: 'synthetic rejection',
            details: {'outcome': outcome},
          ),
        );
        expect(await action.applyProfile(force: true), false);
        expect(globalState.lastConfigMd5, isNull);
        expect(container.read(runningFindProcessModeProvider), isNull);
        expect(
          globalState.lastConfigCounts,
          outcome == 'default' ? (groups: 0, proxies: 0, rules: 0) : null,
        );
        expect(await preferences.getCompositionRevision(), 0);
      },
    );
  }

  test(
    'ambiguous transport retains unique candidate files and clears runtime confirmation',
    () async {
      await bind(custom: true);
      final paths = <String>[];
      when(() => core.setupConfig(any())).thenAnswer((call) async {
        paths.add((call.positionalArguments.single as SetupParams).base!.path);
        throw const CoreMethodException(
          code: 'no_response',
          message: 'synthetic timeout',
        );
      });
      expect(await action.applyProfile(force: true), false);
      expect(globalState.lastConfigMd5, isNull);
      expect(globalState.lastConfigCounts, isNull);
      expect(container.read(runningFindProcessModeProvider), isNull);
      expect(await File(paths.first).exists(), true);
      final first = await File(paths.first).readAsString();
      expect(await action.applyProfile(force: true), false);
      expect(paths.toSet(), hasLength(2));
      expect(await File(paths.first).readAsString(), first);
      expect(await File(paths.last).exists(), true);
      expect(await preferences.getCompositionRevision(), 0);
    },
  );

  test(
    'revision-record failure after acknowledgement keeps runtime success and metadata',
    () async {
      await bind();
      final failing = _FailRevisionStore();
      SharedPreferencesStorePlatform.instance = failing;
      expect(await action.applyProfile(force: true), true);
      expect(globalState.lastConfigMd5, isNot('confirmed-old'));
      expect(globalState.lastConfigMd5, isNotNull);
      expect((await failing.getAll())['flutter.compositionRevision'], 0);
      expect(action.previews, hasLength(1));
    },
  );

  test(
    'unavailable preference store is unknown, not a fresh-install bypass',
    () async {
      await bind();
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = _UnavailableStore();
      await preferences.rebind();
      expect(await preferences.getCompositionRevision(), 0);
      action.answer = (_) async => false;
      expect(await action.applyProfile(), false);
      expect(action.previews, hasLength(1));
      expect(pushes, isEmpty);
    },
  );

  test(
    'session approval only matches exact fingerprint and Cancel clears it',
    () async {
      await bind();
      final gate = CompositionReviewGate()..approve('one');
      expect(gate.approves('one'), true);
      expect(gate.approves('two'), false);
      gate.cancel();
      expect(gate.approves('one'), false);
      expect(gate.suppressed(automatic: true), true);
      expect(gate.suppressed(automatic: false), false);
    },
  );

  test(
    'review hides credential values and bulk, retaining false/zero/empty values',
    () async {
      await bind();
      expect(
        compositionReviewValues({
          'secret': 'do-not-display',
          'authentication': ['user:password'],
          'proxies': [
            {'password': 'never'},
          ],
          'hosts': {},
          'dns': {'use-hosts': false, 'ipv6-timeout': 0, 'nameserver': []},
        }),
        {
          'secret': '••••',
          'authentication': '••••',
          'hosts': {},
          'dns.use-hosts': false,
          'dns.ipv6-timeout': 0,
          'dns.nameserver': [],
        },
      );
    },
  );
}
