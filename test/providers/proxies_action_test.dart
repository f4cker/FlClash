import 'dart:async';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/tray_menu.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_profiles.dart';

class MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

const _testUrl = 'http://delay.test';

Group _group(String name, List<Proxy> all) =>
    Group(type: GroupType.Selector, name: name, all: all);

const _proxy = Proxy(name: 'HK-01', type: 'ss');

Profile _selectedProfile(String proxyName) => Profile(
  id: 1,
  autoUpdateDuration: Duration.zero,
  selectedMap: {'Proxy': proxyName},
);

final _delayKey = delayTestKey(_testUrl, 'HK-01');

TestDelayParams _delayTest(String testUrl, [String? proxyName]) {
  var matcher = isA<TestDelayParams>().having(
    (params) => params.testUrl,
    'testUrl',
    testUrl,
  );
  if (proxyName != null) {
    matcher = matcher.having(
      (params) => params.proxyName,
      'proxyName',
      proxyName,
    );
  }
  return any(that: matcher);
}

ProviderContainer _delayContainer(ProviderContainer Function() build) {
  final container = build();
  container.read(patchClashConfigProvider.notifier).value =
      const PatchClashConfig(testUrl: _testUrl);
  return container;
}

ExternalProvider _provider(String name, {int count = 1}) => ExternalProvider(
  name: name,
  type: 'Proxy',
  count: count,
  vehicleType: 'HTTP',
  updateAt: DateTime.utc(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCoreHandlerInterface core;

  setUpAll(() async {
    registerFallbackValue(
      const ChangeProxyParams(groupName: 'G', proxyName: 'P'),
    );
    registerFallbackValue(
      const TestDelayParams(proxyName: 'P', testUrl: 'U', timeout: 0),
    );
    core = MockCoreHandlerInterface();
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() => reset(core));

  ProviderContainer buildContainer({Profile? profile}) {
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(() => TestProfiles([?profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile?.id),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ProxiesAction actionOf(ProviderContainer container) =>
      container.read(proxiesActionProvider.notifier);

  ProviderContainer runningContainer() {
    final container = buildContainer();
    container.read(initProvider.notifier).value = true;
    container.read(runTimeProvider.notifier).value = 1;
    return container;
  }

  group('updateGroups', () {
    const exit = 'Tailscale 出口 (Flash)';
    const member = 'exit-a1 · a1@example.test';
    const remaining = 'exit-b2 · b2@example.test';
    final saved = <String, String>{
      'Policy': exit,
      'Empty': exit,
      exit: member,
      tailscaleExitSelectionKey: 'a1',
      'UserGroup': 'Tailscale 出口',
      'UserNode': 'Tailscale exit',
    };

    ProxiesData exitData({bool active = false}) => ProxiesData(
      tailscaleRevision: 1,
      all: ['GLOBAL', 'Policy', 'Empty', 'Tailscale 出口', if (active) exit],
      proxies: {
        'GLOBAL': {
          'name': 'GLOBAL',
          'type': 'Selector',
          'now': 'DIRECT',
          'all': ['DIRECT', 'Tailscale 出口', 'Tailscale exit'],
        },
        'Policy': {
          'name': 'Policy',
          'type': 'Selector',
          'now': active ? exit : 'DIRECT',
          'all': ['DIRECT', if (active) exit],
        },
        'Empty': {
          'name': 'Empty',
          'type': 'Selector',
          'now': active ? exit : 'COMPATIBLE',
          'all': ['COMPATIBLE', if (active) exit],
        },
        'Tailscale 出口': {
          'name': 'Tailscale 出口',
          'type': 'Selector',
          'now': 'DIRECT',
          'all': ['DIRECT'],
        },
        'Tailscale exit': {'name': 'Tailscale exit', 'type': 'socks5'},
        'DIRECT': {'name': 'DIRECT', 'type': 'Direct'},
        'COMPATIBLE': {'name': 'COMPATIBLE', 'type': 'Direct'},
        if (active) ...{
          exit: {
            'name': exit,
            'type': 'Selector',
            'now': remaining,
            'all': [remaining],
          },
          remaining: {'name': remaining, 'type': 'Tailscale'},
        },
      },
    );

    Profile exitProfile() =>
        Profile(id: 1, autoUpdateDuration: Duration.zero, selectedMap: saved);

    for (final state in [
      TailscaleRuntimeState.confirmed,
      TailscaleRuntimeState.none,
    ]) {
      test(
        'closed exit selections are repaired after $state and stay repaired on reload',
        () async {
          final container = buildContainer(profile: exitProfile());
          when(core.getProxies).thenAnswer((_) async => exitData());
          when(() => core.getTailscaleExit(1)).thenAnswer(
            (_) async =>
                TailscaleExitReport(revision: 1, profileId: 1, state: state),
          );

          await actionOf(container).updateGroups();
          expect(container.read(profilesProvider).getProfile(1)!.selectedMap, {
            'Policy': 'DIRECT',
            'UserGroup': 'Tailscale 出口',
            'UserNode': 'Tailscale exit',
          });
          await actionOf(container).updateGroups();
          expect(
            container
                .read(profilesProvider)
                .getProfile(1)!
                .selectedMap['Policy'],
            'DIRECT',
          );
          expect(
            container.read(profilesProvider).getProfile(1)!.selectedMap,
            isNot(contains(tailscaleExitSelectionKey)),
          );
        },
      );
    }

    test(
      'same-profile runtime replacement between reads cannot erase a new valid choice',
      () async {
        final container = buildContainer(profile: exitProfile());
        when(
          core.getProxies,
        ).thenAnswer((_) async => exitData().copyWith(tailscaleRevision: 7));
        when(() => core.getTailscaleExit(1)).thenAnswer(
          (_) async => const TailscaleExitReport(
            revision: 8,
            profileId: 1,
            state: TailscaleRuntimeState.none,
          ),
        );

        await actionOf(container).updateGroups();
        expect(
          container.read(profilesProvider).getProfile(1)!.selectedMap,
          saved,
        );
      },
    );

    test(
      'fallback persistence follows Core order, not name-sorted presentation',
      () async {
        final container = buildContainer(profile: exitProfile());
        container
            .read(proxiesStyleSettingProvider.notifier)
            .update((state) => state.copyWith(sortType: ProxiesSortType.name));
        final data = exitData();
        final proxies = {
          ...data.proxies,
          'Policy': {
            'name': 'Policy',
            'type': 'Selector',
            'now': 'Z-proxy',
            'all': ['Z-proxy', 'DIRECT'],
          },
          'Z-proxy': {'name': 'Z-proxy', 'type': 'socks5'},
        };
        when(
          core.getProxies,
        ).thenAnswer((_) async => data.copyWith(proxies: proxies));
        when(() => core.getTailscaleExit(1)).thenAnswer(
          (_) async => const TailscaleExitReport(
            revision: 1,
            profileId: 1,
            state: TailscaleRuntimeState.none,
          ),
        );

        await actionOf(container).updateGroups();
        expect(
          container.read(groupsProvider).getGroup('Policy')!.all.first.name,
          'DIRECT',
        );
        expect(
          container.read(profilesProvider).getProfile(1)!.selectedMap['Policy'],
          'Z-proxy',
        );
      },
    );

    test(
      'one account removed preserves shared parents and follows the remaining member',
      () async {
        final container = buildContainer(profile: exitProfile());
        when(core.getProxies).thenAnswer((_) async => exitData(active: true));
        when(() => core.getTailscaleExit(1)).thenAnswer(
          (_) async => const TailscaleExitReport(
            revision: 1,
            profileId: 1,
            state: TailscaleRuntimeState.confirmed,
            group: exit,
            selected: 'b2',
            accounts: [
              TailscaleExitAccount(
                id: 'b2',
                member: remaining,
                exitNode: '100.64.0.7',
                state: TailscaleExitState.unavailable,
              ),
            ],
          ),
        );

        await actionOf(container).updateGroups();
        final selected = container
            .read(profilesProvider)
            .getProfile(1)!
            .selectedMap;
        expect(selected['Policy'], exit);
        expect(selected['Empty'], exit);
        expect(selected[exit], remaining);
        expect(selected[tailscaleExitSelectionKey], 'b2');
      },
    );

    test('unconfirmed closure never repairs saved selections', () async {
      final container = buildContainer(profile: exitProfile());
      when(core.getProxies).thenAnswer((_) async => exitData());
      when(
        () => core.getTailscaleExit(1),
      ).thenAnswer((_) async => const TailscaleExitReport.readFailed(1));

      await actionOf(container).updateGroups();
      expect(
        container.read(profilesProvider).getProfile(1)!.selectedMap,
        saved,
      );
    });

    test(
      'a late read after a profile switch cannot repair either profile',
      () async {
        final container = buildContainer(profile: exitProfile());
        final other = exitProfile().copyWith(id: 2);
        container.read(profilesProvider.notifier).put(other);
        final reading = Completer<void>();
        final report = Completer<TailscaleExitReport>();
        when(core.getProxies).thenAnswer((_) async => exitData());
        when(() => core.getTailscaleExit(1)).thenAnswer((_) {
          reading.complete();
          return report.future;
        });

        final update = actionOf(container).updateGroups();
        await reading.future;
        container.read(currentProfileIdProvider.notifier).value = 2;
        report.complete(
          const TailscaleExitReport(
            revision: 1,
            profileId: 1,
            state: TailscaleRuntimeState.none,
          ),
        );
        await update;
        expect(
          container.read(profilesProvider).getProfile(1)!.selectedMap,
          saved,
        );
        expect(
          container.read(profilesProvider).getProfile(2)!.selectedMap,
          saved,
        );
      },
    );

    test('a selection changed during readback is not overwritten', () async {
      final container = buildContainer(profile: exitProfile());
      final reading = Completer<void>();
      final report = Completer<TailscaleExitReport>();
      when(core.getProxies).thenAnswer((_) async => exitData());
      when(() => core.getTailscaleExit(1)).thenAnswer((_) {
        reading.complete();
        return report.future;
      });

      final update = actionOf(container).updateGroups();
      await reading.future;
      container
          .read(profilesProvider.notifier)
          .put(
            exitProfile().copyWith(
              selectedMap: {...saved, 'Policy': 'ManualNew'},
            ),
          );
      report.complete(
        const TailscaleExitReport(
          revision: 1,
          profileId: 1,
          state: TailscaleRuntimeState.none,
        ),
      );
      await update;
      expect(
        container.read(profilesProvider).getProfile(1)!.selectedMap['Policy'],
        'ManualNew',
      );
    });

    test('publishes the groups derived from core proxy data', () async {
      when(core.getProxies).thenAnswer(
        (_) async => ProxiesData(
          all: const ['Proxy', 'Direct'],
          proxies: Map<String, dynamic>.from({
            'Proxy': Map<String, dynamic>.from({
              'name': 'Proxy',
              'type': 'Selector',
              'now': 'HK-01',
              'all': ['HK-01'],
            }),
            'Direct': Map<String, dynamic>.from({
              'name': 'Direct',
              'type': 'Direct',
            }),
            'HK-01': Map<String, dynamic>.from({'name': 'HK-01', 'type': 'ss'}),
          }),
        ),
      );
      final container = buildContainer();

      await actionOf(container).updateGroups();

      final groups = container.read(groupsProvider);
      expect(groups.map((group) => group.name), ['Proxy']);
      expect(groups.single.all.map((proxy) => proxy.name), ['HK-01']);
    });

    test(
      'publishes the groups once a retry succeeds after core throws',
      () async {
        var attempt = 0;
        when(core.getProxies).thenAnswer((_) async {
          attempt++;
          if (attempt == 1) {
            throw StateError('core down');
          }
          return ProxiesData(
            all: const ['Proxy', 'Direct'],
            proxies: Map<String, dynamic>.from({
              'Proxy': Map<String, dynamic>.from({
                'name': 'Proxy',
                'type': 'Selector',
                'now': 'HK-01',
                'all': ['HK-01'],
              }),
              'Direct': Map<String, dynamic>.from({
                'name': 'Direct',
                'type': 'Direct',
              }),
              'HK-01': Map<String, dynamic>.from({
                'name': 'HK-01',
                'type': 'ss',
              }),
            }),
          );
        });
        final container = buildContainer();

        await actionOf(container).updateGroups();

        final groups = container.read(groupsProvider);
        expect(groups.map((group) => group.name), ['Proxy']);
        verify(core.getProxies).called(2);
      },
    );

    test(
      'clears the groups once retry is exhausted after core throws',
      () async {
        when(core.getProxies).thenThrow(StateError('core down'));
        final container = buildContainer();
        container.read(groupsProvider.notifier).value = [
          _group('Stale', const []),
        ];

        await actionOf(container).updateGroups();

        expect(container.read(groupsProvider), isEmpty);
        verify(core.getProxies).called(3);
      },
    );

    test('a core status change alone does not clear the groups', () {
      final container = buildContainer();
      actionOf(container);
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      container.read(groupsProvider.notifier).value = [
        _group('Stale', const []),
      ];

      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;

      expect(container.read(groupsProvider).map((group) => group.name), [
        'Stale',
      ]);
    });
  });

  group('changeProxy', () {
    setUp(() {
      when(
        () => core.changeProxy(any()),
      ).thenAnswer((_) async => const ChangeProxyResult(changed: true));
      when(core.closeConnections).thenAnswer((_) async => true);
      when(core.resetConnections).thenAnswer((_) async => true);
    });

    test('closes connections when enabled', () async {
      final container = runningContainer();
      container.read(appSettingProvider.notifier).value = const AppSettingProps(
        closeConnections: true,
      );

      await actionOf(
        container,
      ).changeProxy(groupName: 'Proxy', proxyName: 'HK-01');

      verify(
        () => core.changeProxy(
          const ChangeProxyParams(groupName: 'Proxy', proxyName: 'HK-01'),
        ),
      ).called(1);
      verify(core.closeConnections).called(1);
      verifyNever(core.resetConnections);
    });

    test('resets connections instead when the setting is off', () async {
      final container = buildContainer();
      container.read(appSettingProvider.notifier).value = const AppSettingProps(
        closeConnections: false,
      );

      await actionOf(
        container,
      ).changeProxy(groupName: 'Proxy', proxyName: 'HK-01');

      verify(core.resetConnections).called(1);
      verifyNever(core.closeConnections);
    });

    test('a failing connection reset does not fail the switch', () async {
      when(core.closeConnections).thenThrow(
        const CoreMethodException(
          code: 'transport_disconnected',
          message: 'Core RPC client is closed',
        ),
      );
      final container = buildContainer(profile: _selectedProfile('HK-00'));
      container.read(appSettingProvider.notifier).value = const AppSettingProps(
        closeConnections: true,
      );

      await actionOf(
        container,
      ).changeProxy(groupName: 'Proxy', proxyName: 'HK-01');

      verify(core.closeConnections).called(1);
      expect(container.read(currentProfileProvider)?.selectedMap, {
        'Proxy': 'HK-01',
      });
    });

    test('skips the connection reset when the switch itself fails', () async {
      when(() => core.changeProxy(any())).thenThrow(StateError('core down'));
      final container = runningContainer();

      await actionOf(
        container,
      ).changeProxy(groupName: 'Proxy', proxyName: 'HK-01');

      verifyNever(core.closeConnections);
      verifyNever(core.resetConnections);
    });

    test(
      'skips the connection reset when the Core reports no change',
      () async {
        when(
          () => core.changeProxy(any()),
        ).thenAnswer((_) async => const ChangeProxyResult(changed: false));
        final container = runningContainer();

        await actionOf(
          container,
        ).changeProxy(groupName: 'Proxy', proxyName: 'HK-01');

        verifyNever(core.closeConnections);
        verifyNever(core.resetConnections);
      },
    );

    test('rolls the selection back when the Core answers a message', () async {
      when(() => core.changeProxy(any())).thenAnswer(
        (_) async => const ChangeProxyResult(message: 'proxy not exist'),
      );
      final container = buildContainer(profile: _selectedProfile('HK-00'));

      await actionOf(
        container,
      ).changeProxy(groupName: 'Proxy', proxyName: 'HK-01');

      verifyNever(core.closeConnections);
      expect(container.read(currentProfileProvider)?.selectedMap, {
        'Proxy': 'HK-00',
      });
    });

    test('commits the selection the Core accepted', () async {
      final container = buildContainer(profile: _selectedProfile('HK-00'));

      await actionOf(
        container,
      ).changeProxy(groupName: 'Proxy', proxyName: 'HK-01');

      expect(container.read(currentProfileProvider)?.selectedMap, {
        'Proxy': 'HK-01',
      });
    });

    test('rolls the selection back when the switch fails', () async {
      when(() => core.changeProxy(any())).thenThrow(StateError('core down'));
      final container = buildContainer(profile: _selectedProfile('HK-00'));

      await actionOf(
        container,
      ).changeProxy(groupName: 'Proxy', proxyName: 'HK-01');

      expect(container.read(currentProfileProvider)?.selectedMap, {
        'Proxy': 'HK-00',
      });
    });

    test(
      'rolls back to the last selection the Core applied, not the last tap',
      () async {
        when(() => core.changeProxy(any())).thenThrow(StateError('core down'));
        final container = buildContainer(profile: _selectedProfile('HK-00'));
        final action = actionOf(container);

        action.changeProxyDebounce('Proxy', 'HK-01');
        action.changeProxyDebounce('Proxy', 'HK-02');
        expect(container.read(currentProfileProvider)?.selectedMap, {
          'Proxy': 'HK-02',
        });

        await action.changeProxy(groupName: 'Proxy', proxyName: 'HK-02');

        expect(container.read(currentProfileProvider)?.selectedMap, {
          'Proxy': 'HK-00',
        });
        debouncer.cancel((FunctionTag.changeProxy, 'Proxy'));
      },
    );
  });

  group('changeProxyForTray', () {
    const old = 'HK-00';
    const target = 'HK-01';
    const members = [Proxy(name: old, type: 'ss'), _proxy];

    ProxiesData data({
      String now = target,
      List<String> all = const [old, target],
      GroupType type = GroupType.Selector,
    }) => ProxiesData(
      all: const ['Proxy'],
      proxies: {
        'Proxy': {'name': 'Proxy', 'type': type.name, 'now': now, 'all': all},
        for (final name in all) name: {'name': name, 'type': 'ss'},
      },
    );

    ProviderContainer trayContainer() {
      final container = buildContainer(profile: _selectedProfile(old));
      container.read(runTimeProvider.notifier).value = 1;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      container.read(groupsProvider.notifier).value = [
        _group('Proxy', members).copyWith(now: old),
      ];
      return container;
    }

    TrayGroupMenuState? menuState(ProviderContainer container) =>
        container.read(trayGroupMenuStatesProvider)['Proxy'];

    Future<void> switchProxy(ProviderContainer container) => actionOf(
      container,
    ).changeProxyForTray(groupName: 'Proxy', proxyName: target);

    setUp(() {
      when(
        () => core.changeProxy(any()),
      ).thenAnswer((_) async => const ChangeProxyResult(changed: true));
      when(core.closeConnections).thenAnswer((_) async {});
      when(core.resetConnections).thenAnswer((_) async {});
      when(core.getProxies).thenAnswer((_) async => data());
    });

    for (final type in [GroupType.URLTest, GroupType.Fallback]) {
      test('confirms active member selection in a $type group', () async {
        final container = trayContainer();
        container.read(groupsProvider.notifier).value = [
          _group('Proxy', members).copyWith(type: type, now: old),
        ];
        when(core.getProxies).thenAnswer((_) async => data(type: type));
        await switchProxy(container);
        verify(() => core.changeProxy(any())).called(1);
        expect(container.read(rawGroupsProvider).single.now, target);
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          target,
        );
        expect(menuState(container), isNull);
      });
    }

    for (final type in [GroupType.LoadBalance, GroupType.Relay]) {
      test('rejects direct member selection in a $type group', () async {
        final container = trayContainer();
        container.read(groupsProvider.notifier).value = [
          _group('Proxy', members).copyWith(type: type, now: old),
        ];
        await switchProxy(container);
        container.read(runTimeProvider.notifier).value = null;
        await switchProxy(container);
        verifyNever(() => core.changeProxy(any()));
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          old,
        );
        expect(menuState(container), isNull);
      });
    }

    for (final type in [
      GroupType.Selector,
      GroupType.URLTest,
      GroupType.Fallback,
    ]) {
      for (final status in [CoreStatus.connected, CoreStatus.disconnected]) {
        test(
          'saves a stopped $type choice with Core $status without claiming confirmation',
          () async {
            final container = trayContainer();
            container.read(runTimeProvider.notifier).value = null;
            container.read(coreStatusProvider.notifier).value = status;
            container.read(groupsProvider.notifier).value = [
              _group('Proxy', members).copyWith(type: type, now: target),
            ];
            await switchProxy(container);
            expect(
              container.read(currentProfileProvider)?.selectedMap['Proxy'],
              target,
            );
            expect(container.read(rawGroupsProvider).single.now, target);
            expect(menuState(container), isNull);
            verifyNever(() => core.changeProxy(any()));
            verifyNever(core.getProxies);
            verifyNever(core.closeConnections);
            verifyNever(core.resetConnections);
          },
        );
      }
    }

    test(
      'a running but disconnected Core does not turn an active switch into a saved choice',
      () async {
        final container = trayContainer();
        container.read(coreStatusProvider.notifier).value =
            CoreStatus.disconnected;
        await switchProxy(container);
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          old,
        );
        expect(menuState(container), isNull);
        verifyNever(() => core.changeProxy(any()));
      },
    );

    test(
      'stopping clears an uncertain active lock before saving a stopped choice',
      () async {
        when(() => core.changeProxy(any())).thenThrow(
          const CoreMethodException(code: 'no_response', message: 'no answer'),
        );
        final container = trayContainer();
        await switchProxy(container);
        expect(
          menuState(container)?.switchFailure,
          TraySwitchFailure.unconfirmed,
        );
        container.read(runTimeProvider.notifier).value = null;
        await switchProxy(container);
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          target,
        );
        expect(container.read(rawGroupsProvider).single.now, old);
        expect(menuState(container), isNull);
        verify(() => core.changeProxy(any())).called(1);
        verifyNever(core.getProxies);
      },
    );

    test(
      'a stopped configured choice does not overwrite the old raw Core choice',
      () async {
        final container = trayContainer();
        container.read(runTimeProvider.notifier).value = null;
        await switchProxy(container);
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          target,
        );
        expect(container.read(rawGroupsProvider).single.now, old);
        expect(menuState(container), isNull);
        verifyNever(() => core.changeProxy(any()));
      },
    );

    test(
      'a stopped choice validates the current profile, group, and member',
      () async {
        final container = trayContainer();
        container.read(runTimeProvider.notifier).value = null;
        await actionOf(
          container,
        ).changeProxyForTray(groupName: 'Missing', proxyName: target);
        await actionOf(
          container,
        ).changeProxyForTray(groupName: 'Proxy', proxyName: 'Missing');
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          old,
        );
        container.read(currentProfileIdProvider.notifier).value = 2;
        await switchProxy(container);
        expect(
          container.read(profilesProvider).getProfile(1)?.selectedMap['Proxy'],
          old,
        );
        expect(menuState(container), isNull);
        verifyNever(() => core.changeProxy(any()));
      },
    );

    test(
      'a click after starting uses the live running state, not a stopped menu snapshot',
      () async {
        final selected = Completer<ChangeProxyResult>();
        when(() => core.changeProxy(any())).thenAnswer((_) => selected.future);
        final container = trayContainer();
        container.read(runTimeProvider.notifier).value = null;
        container.read(runTimeProvider.notifier).value = 2;
        final operation = switchProxy(container);
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          old,
        );
        expect(menuState(container)?.confirmedName, old);
        expect(menuState(container)?.pendingName, target);
        verify(() => core.changeProxy(any())).called(1);
        selected.complete(const ChangeProxyResult(changed: false));
        await operation;
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          target,
        );
      },
    );

    for (final changed in [true, false]) {
      test(
        'keeps the old check until raw Core confirmation, changed=$changed',
        () async {
          final selected = Completer<ChangeProxyResult>();
          final reading = Completer<void>();
          final snapshot = Completer<ProxiesData>();
          when(
            () => core.changeProxy(any()),
          ).thenAnswer((_) => selected.future);
          when(core.getProxies).thenAnswer((_) {
            reading.complete();
            return snapshot.future;
          });
          final container = trayContainer();
          final observed = <TrayGroupMenuState?>[];
          container.listen(trayGroupMenuStatesProvider, (_, next) {
            observed.add(next['Proxy']);
          });

          final operation = switchProxy(container);
          expect(menuState(container)?.confirmedName, old);
          expect(menuState(container)?.pendingName, target);
          expect(
            container.read(currentProfileProvider)?.selectedMap['Proxy'],
            old,
          );
          selected.complete(ChangeProxyResult(changed: changed));
          await reading.future;
          expect(menuState(container)?.confirmedName, old);
          expect(menuState(container)?.pendingName, target);
          snapshot.complete(data());
          await operation;

          expect(container.read(rawGroupsProvider).single.now, target);
          expect(
            container.read(currentProfileProvider)?.selectedMap['Proxy'],
            target,
          );
          expect(menuState(container), isNull);
          expect(observed.first?.confirmedName, old);
          expect(observed.last, isNull);
          if (changed) {
            verify(core.closeConnections).called(1);
          } else {
            verifyNever(core.closeConnections);
            verifyNever(core.resetConnections);
          }
        },
      );
    }

    for (final failure in [
      const ChangeProxyResult(message: 'proxy not exist'),
      const CoreMethodException(code: 'invalid_argument', message: 'removed'),
    ]) {
      test(
        'explicit failure is observable and preserves the old selection: $failure',
        () async {
          if (failure is ChangeProxyResult) {
            when(
              () => core.changeProxy(any()),
            ).thenAnswer((_) async => failure);
          } else {
            when(() => core.changeProxy(any())).thenThrow(failure);
          }
          final container = trayContainer();

          await switchProxy(container);

          expect(menuState(container)?.confirmedName, old);
          expect(menuState(container)?.pendingName, isNull);
          expect(menuState(container)?.switchFailure, TraySwitchFailure.failed);
          expect(
            container.read(currentProfileProvider)?.selectedMap['Proxy'],
            old,
          );
          verifyNever(core.getProxies);
          verifyNever(core.closeConnections);
          verifyNever(core.resetConnections);
        },
      );
    }

    for (final origin in ['main window', 'external Core']) {
      test(
        'a failed notice follows a later confirmed $origin selection',
        () async {
          when(() => core.changeProxy(any())).thenAnswer(
            (_) async => const ChangeProxyResult(message: 'selection rejected'),
          );
          final container = trayContainer();
          await switchProxy(container);
          expect(menuState(container)?.confirmedName, old);
          expect(menuState(container)?.switchFailure, TraySwitchFailure.failed);

          if (origin == 'main window') {
            when(
              () => core.changeProxy(any()),
            ).thenAnswer((_) async => const ChangeProxyResult(changed: true));
            await actionOf(
              container,
            ).changeProxy(groupName: 'Proxy', proxyName: target);
          }
          await actionOf(container).updateGroups();

          expect(container.read(rawGroupsProvider).single.now, target);
          expect(menuState(container)?.confirmedName, target);
          expect(menuState(container)?.pendingName, isNull);
          expect(menuState(container)?.switchFailure, TraySwitchFailure.failed);
          await switchProxy(container);
          verify(
            () => core.changeProxy(any()),
          ).called(origin == 'main window' ? 2 : 1);
        },
      );
    }

    test('a removed group drops its failed notice before recreation', () async {
      when(() => core.changeProxy(any())).thenAnswer(
        (_) async => const ChangeProxyResult(message: 'selection rejected'),
      );
      final container = trayContainer();
      await switchProxy(container);
      expect(menuState(container)?.switchFailure, TraySwitchFailure.failed);
      final other = data().copyWith(
        all: const ['Other'],
        proxies: {
          'Other': {
            'name': 'Other',
            'type': 'Selector',
            'now': old,
            'all': [old],
          },
          old: {'name': old, 'type': 'ss'},
        },
      );
      when(core.getProxies).thenAnswer((_) async => other);
      await actionOf(container).updateGroups();
      expect(menuState(container), isNull);

      when(core.getProxies).thenAnswer((_) async => data());
      await actionOf(container).updateGroups();
      expect(container.read(rawGroupsProvider).single.now, target);
      expect(menuState(container), isNull);
    });

    for (final error in [
      const CoreMethodException(code: 'no_response', message: 'no answer'),
      TimeoutException('no answer'),
    ]) {
      test(
        'an unanswered request stays uncertain and locked until refresh: $error',
        () async {
          when(() => core.changeProxy(any())).thenThrow(error);
          final container = trayContainer();
          await switchProxy(container);

          expect(
            menuState(container)?.switchFailure,
            TraySwitchFailure.unconfirmed,
          );
          expect(menuState(container)?.confirmedName, old);
          expect(menuState(container)?.pendingName, target);
          expect(
            container.read(currentProfileProvider)?.selectedMap['Proxy'],
            old,
          );
          await switchProxy(container);
          verify(() => core.changeProxy(any())).called(1);
          expect(container.read(trayGroupsReadFailedProvider), isFalse);

          await actionOf(container).updateGroups();
          expect(menuState(container), isNull);
          expect(
            container.read(currentProfileProvider)?.selectedMap['Proxy'],
            target,
          );
        },
      );
    }

    test('accepted RPC with a mismatching now is not confirmation', () async {
      when(core.getProxies).thenAnswer((_) async => data(now: old));
      final container = trayContainer();
      await switchProxy(container);

      expect(
        menuState(container)?.switchFailure,
        TraySwitchFailure.unconfirmed,
      );
      expect(menuState(container)?.confirmedName, old);
      expect(container.read(currentProfileProvider)?.selectedMap['Proxy'], old);
      await actionOf(container).updateGroups();
      expect(menuState(container), isNull);
      expect(container.read(currentProfileProvider)?.selectedMap['Proxy'], old);
    });

    test(
      'confirmation read errors retain the old check and recover on refresh',
      () async {
        when(core.getProxies).thenThrow(
          const CoreMethodException(
            code: 'no_response',
            message: 'read timed out',
          ),
        );
        final container = trayContainer();
        await switchProxy(container);

        expect(
          menuState(container)?.switchFailure,
          TraySwitchFailure.unconfirmed,
        );
        expect(menuState(container)?.confirmedName, old);
        expect(menuState(container)?.pendingName, target);
        expect(container.read(trayGroupsReadFailedProvider), isTrue);
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          old,
        );
        when(core.getProxies).thenAnswer((_) async => data());
        await actionOf(container).updateGroups();
        expect(container.read(trayGroupsReadFailedProvider), isFalse);
        expect(menuState(container), isNull);
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          target,
        );
      },
    );

    test(
      'rejects duplicate taps and another member of the same pending group',
      () async {
        final selected = Completer<ChangeProxyResult>();
        when(() => core.changeProxy(any())).thenAnswer((_) => selected.future);
        final container = trayContainer();
        final operation = switchProxy(container);
        await switchProxy(container);
        await actionOf(
          container,
        ).changeProxyForTray(groupName: 'Proxy', proxyName: old);
        expect(menuState(container)?.pendingName, target);
        verify(() => core.changeProxy(any())).called(1);
        selected.complete(const ChangeProxyResult(changed: false));
        await operation;
      },
    );

    test(
      'ignores already selected, missing groups, and missing members',
      () async {
        final container = trayContainer();
        await actionOf(
          container,
        ).changeProxyForTray(groupName: 'Proxy', proxyName: old);
        await actionOf(
          container,
        ).changeProxyForTray(groupName: 'Missing', proxyName: target);
        await actionOf(
          container,
        ).changeProxyForTray(groupName: 'Proxy', proxyName: 'Removed');
        expect(menuState(container), isNull);
        verifyNever(() => core.changeProxy(any()));
      },
    );

    for (final confirmed in [target, old]) {
      test(
        'a newer $confirmed snapshot resolves a superseded switch confirmation without another read',
        () async {
          final firstSnapshot = Completer<ProxiesData>();
          final reading = Completer<void>();
          var reads = 0;
          when(
            () => core.changeProxy(any()),
          ).thenAnswer((_) async => const ChangeProxyResult(changed: false));
          when(core.getProxies).thenAnswer((_) {
            reads++;
            if (reads == 1) {
              reading.complete();
              return firstSnapshot.future;
            }
            return Future.value(data(now: confirmed));
          });
          final container = trayContainer();
          final operation = switchProxy(container);
          await reading.future;

          await actionOf(container).updateGroups();
          expect(container.read(rawGroupsProvider).single.now, confirmed);
          expect(menuState(container)?.pendingName, target);
          expect(
            container.read(currentProfileProvider)?.selectedMap['Proxy'],
            old,
          );

          firstSnapshot.complete(data(now: confirmed == target ? old : target));
          await operation;

          expect(menuState(container), isNull);
          expect(container.read(rawGroupsProvider).single.now, confirmed);
          expect(
            container.read(currentProfileProvider)?.selectedMap['Proxy'],
            confirmed,
          );
          expect(container.read(trayGroupsReadFailedProvider), isFalse);
          verify(core.getProxies).called(2);
        },
      );
    }

    test('runtime ticks do not invalidate a pending tray switch', () async {
      final selected = Completer<ChangeProxyResult>();
      when(() => core.changeProxy(any())).thenAnswer((_) => selected.future);
      final container = trayContainer();
      final operation = switchProxy(container);
      container.read(runTimeProvider.notifier).value = 2;
      expect(menuState(container)?.pendingName, target);
      selected.complete(const ChangeProxyResult(changed: false));
      await operation;
      expect(menuState(container), isNull);
      expect(
        container.read(currentProfileProvider)?.selectedMap['Proxy'],
        target,
      );
    });

    for (final lifecycle in ['profile', 'core', 'running state']) {
      for (final phase in ['RPC', 'confirmation']) {
        test(
          'ignores $phase completion after a $lifecycle generation change',
          () async {
            final selected = Completer<ChangeProxyResult>();
            final snapshot = Completer<ProxiesData>();
            final reading = Completer<void>();
            when(
              () => core.changeProxy(any()),
            ).thenAnswer((_) => selected.future);
            when(core.getProxies).thenAnswer((_) {
              reading.complete();
              return snapshot.future;
            });
            final container = trayContainer();
            final operation = switchProxy(container);
            if (phase == 'confirmation') {
              selected.complete(const ChangeProxyResult(changed: false));
              await reading.future;
            }
            if (lifecycle == 'profile') {
              container
                  .read(profilesProvider.notifier)
                  .put(_selectedProfile('Other').copyWith(id: 2));
              container.read(currentProfileIdProvider.notifier).value = 2;
              expect(container.read(currentProfileProvider)?.id, 2);
            } else if (lifecycle == 'core') {
              container.read(coreStatusProvider.notifier).value =
                  CoreStatus.disconnected;
              container.read(coreStatusProvider.notifier).value =
                  CoreStatus.connected;
            } else {
              container.read(runTimeProvider.notifier).value = null;
              container.read(runTimeProvider.notifier).value = 2;
            }
            container.read(groupsProvider.notifier).value = [
              _group('New generation', const []),
            ];
            if (phase == 'RPC') {
              selected.complete(const ChangeProxyResult(changed: true));
            } else {
              snapshot.complete(data());
            }
            await operation;

            expect(container.read(trayGroupMenuStatesProvider), isEmpty);
            expect(
              container.read(groupsProvider).single.name,
              'New generation',
            );
            expect(
              container
                  .read(profilesProvider)
                  .getProfile(1)
                  ?.selectedMap['Proxy'],
              old,
            );
            if (lifecycle == 'profile') {
              expect(
                container.read(currentProfileProvider)?.selectedMap['Proxy'],
                'Other',
              );
            }
            expect(container.read(trayGroupsReadFailedProvider), isFalse);
          },
        );
      }
    }

    test('a profile round trip cannot revive an old switch', () async {
      final selected = Completer<ChangeProxyResult>();
      when(() => core.changeProxy(any())).thenAnswer((_) => selected.future);
      final container = trayContainer();
      final operation = switchProxy(container);
      container.read(currentProfileIdProvider.notifier).value = 2;
      container.read(currentProfileIdProvider.notifier).value = 1;
      selected.complete(const ChangeProxyResult(changed: true));
      await operation;
      expect(menuState(container), isNull);
      expect(container.read(currentProfileProvider)?.selectedMap['Proxy'], old);
      verifyNever(core.getProxies);
      verifyNever(core.closeConnections);
    });

    test(
      'uses reset policy and treats reset failure separately from confirmation',
      () async {
        final container = trayContainer();
        container.read(appSettingProvider.notifier).value =
            const AppSettingProps(closeConnections: false);
        when(core.resetConnections).thenThrow(StateError('reset failed'));
        await switchProxy(container);
        verify(core.resetConnections).called(1);
        verifyNever(core.closeConnections);
        expect(menuState(container), isNull);
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          target,
        );
      },
    );

    test('a removed group cannot be revived by its in-flight RPC', () async {
      final selected = Completer<ChangeProxyResult>();
      when(() => core.changeProxy(any())).thenAnswer((_) => selected.future);
      final container = trayContainer();
      final operation = switchProxy(container);
      container.read(groupsProvider.notifier).value = [];
      container.read(groupsProvider.notifier).value = [
        _group('Proxy', members).copyWith(now: old),
      ];
      selected.complete(const ChangeProxyResult(changed: true));
      await operation;
      expect(menuState(container), isNull);
      expect(container.read(currentProfileProvider)?.selectedMap['Proxy'], old);
      verifyNever(core.getProxies);
      verifyNever(core.closeConnections);
    });

    test('ignores completion after container disposal', () async {
      final selected = Completer<ChangeProxyResult>();
      when(() => core.changeProxy(any())).thenAnswer((_) => selected.future);
      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          profilesProvider.overrideWith(
            () => TestProfiles([_selectedProfile(old)]),
          ),
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        ],
      );
      container.read(runTimeProvider.notifier).value = 1;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      container.read(groupsProvider.notifier).value = [
        _group('Proxy', members).copyWith(now: old),
      ];
      final operation = switchProxy(container);
      container.dispose();
      selected.complete(const ChangeProxyResult(changed: true));
      await expectLater(operation, completes);
      verifyNever(core.getProxies);
      verifyNever(core.closeConnections);
    });

    for (final removed in ['group', 'member']) {
      test('does not persist a removed $removed from confirmation', () async {
        final container = trayContainer();
        when(core.getProxies).thenAnswer(
          (_) async => removed == 'group'
              ? ProxiesData(
                  all: const ['Other'],
                  proxies: {
                    'Other': {
                      'name': 'Other',
                      'type': 'Selector',
                      'all': [old],
                      'now': old,
                    },
                    old: {'name': old, 'type': 'ss'},
                  },
                )
              : data(now: old, all: const [old]),
        );
        await switchProxy(container);
        expect(menuState(container), isNull);
        expect(
          container.read(currentProfileProvider)?.selectedMap['Proxy'],
          old,
        );
      });
    }

    test(
      'successful empty data is not invented into a group read error',
      () async {
        when(
          core.getProxies,
        ).thenAnswer((_) async => const ProxiesData(all: [], proxies: {}));
        final container = trayContainer();
        await actionOf(container).updateGroups();
        expect(container.read(trayGroupsReadFailedProvider), isFalse);
        expect(container.read(groupsProvider), isEmpty);
      },
    );

    test(
      'profile lifecycle resets tray failures without clearing app groups',
      () async {
        final container = trayContainer();
        when(core.getProxies).thenThrow(StateError('read failed'));
        await actionOf(container).updateGroups();
        expect(container.read(trayGroupsReadFailedProvider), isTrue);
        container
            .read(trayGroupMenuStatesProvider.notifier)
            .set(
              'Proxy',
              const TrayGroupMenuState(
                confirmedName: old,
                switchFailure: TraySwitchFailure.failed,
              ),
            );
        container.read(groupsProvider.notifier).value = [
          _group('Unchanged', const []),
        ];
        container.read(currentProfileIdProvider.notifier).value = 2;
        expect(container.read(trayGroupsReadFailedProvider), isFalse);
        expect(container.read(trayGroupMenuStatesProvider), isEmpty);
        expect(container.read(groupsProvider).single.name, 'Unchanged');
      },
    );

    test(
      'a superseded failed group read cannot mark a newer snapshot failed',
      () async {
        final first = Completer<ProxiesData>();
        var count = 0;
        when(core.getProxies).thenAnswer((_) {
          count++;
          return count == 1 ? first.future : Future.value(data());
        });
        final container = trayContainer();
        final stale = actionOf(container).updateGroups();
        await actionOf(container).updateGroups();
        when(core.getProxies).thenThrow(StateError('old read failed'));
        first.completeError(StateError('old read failed'));
        await stale;
        expect(container.read(trayGroupsReadFailedProvider), isFalse);
        expect(container.read(groupsProvider).single.now, target);
      },
    );
  });

  group('proxyDelayTest', () {
    test('marks the node pending while it runs, then records it', () async {
      late ProviderContainer container;
      final observed = <bool>[];
      when(() => core.testDelay(_delayTest(_testUrl, 'HK-01'))).thenAnswer((
        _,
      ) async {
        observed.add(
          container.read(pendingDelayTestsProvider).containsKey(_delayKey),
        );
        return const Delay(name: 'HK-01', url: _testUrl, value: 128);
      });
      container = _delayContainer(buildContainer);

      await actionOf(container).proxyDelayTest(_proxy);

      expect(observed, [true]);
      expect(container.read(delayDataSourceProvider)[_testUrl]?['HK-01'], 128);
      expect(container.read(pendingDelayTestsProvider), isEmpty);
    });

    test('keeps the last measurement when the Core does not answer', () async {
      when(
        () => core.testDelay(_delayTest(_testUrl, 'HK-01')),
      ).thenThrow(TimeoutException('no answer'));
      final container = _delayContainer(buildContainer);
      container
          .read(delayDataSourceProvider.notifier)
          .setDelay(const Delay(name: 'HK-01', url: _testUrl, value: 42));

      await actionOf(container).proxyDelayTest(_proxy);

      expect(container.read(delayDataSourceProvider)[_testUrl]?['HK-01'], 42);
      expect(container.read(pendingDelayTestsProvider), isEmpty);
    });

    test('falls back to untested when a throwing call had no value', () async {
      when(
        () => core.testDelay(_delayTest(_testUrl, 'HK-01')),
      ).thenThrow(StateError('channel is gone'));
      final container = _delayContainer(buildContainer);

      await actionOf(container).proxyDelayTest(_proxy);

      expect(container.read(delayDataSourceProvider)[_testUrl]?['HK-01'], null);
      expect(container.read(pendingDelayTestsProvider), isEmpty);
    });

    test('does nothing when the resolved proxy name is empty', () async {
      final container = buildContainer();

      await actionOf(container).proxyDelayTest(const Proxy(name: '', type: ''));

      expect(container.read(delayDataSourceProvider), isEmpty);
      expect(container.read(pendingDelayTestsProvider), isEmpty);
      verifyNever(() => core.testDelay(any()));
    });
  });

  group('delayTest', () {
    test('measures every proxy and bumps the sort counter', () async {
      when(() => core.testDelay(_delayTest(_testUrl))).thenAnswer(
        (invocation) async => Delay(
          name:
              (invocation.positionalArguments[0] as TestDelayParams).proxyName,
          url: _testUrl,
          value: 10,
        ),
      );
      final container = _delayContainer(buildContainer);
      final before = container.read(sortNumProvider);

      await actionOf(
        container,
      ).delayTest(const [_proxy, Proxy(name: 'HK-02', type: 'ss')]);

      final delays = container.read(delayDataSourceProvider)[_testUrl];
      expect(delays?['HK-01'], 10);
      expect(delays?['HK-02'], 10);
      expect(container.read(sortNumProvider), before + 1);
      expect(container.read(pendingDelayTestsProvider), isEmpty);
    });

    test('lands a run of quick results in batches, not one per node', () async {
      when(() => core.testDelay(_delayTest(_testUrl))).thenAnswer(
        (invocation) async => Delay(
          name:
              (invocation.positionalArguments[0] as TestDelayParams).proxyName,
          url: _testUrl,
          value: 10,
        ),
      );
      final container = _delayContainer(buildContainer);
      var delayChanges = 0;
      var pendingChanges = 0;
      container.listen(delayDataSourceProvider, (_, _) => delayChanges++);
      container.listen(pendingDelayTestsProvider, (_, _) => pendingChanges++);
      final proxies = List.generate(
        1000,
        (index) => Proxy(name: 'HK-$index', type: 'ss'),
      );

      await actionOf(container).delayTest(proxies);

      expect(
        container.read(delayDataSourceProvider)[_testUrl],
        hasLength(1000),
      );
      expect(container.read(pendingDelayTestsProvider), isEmpty);
      expect(delayChanges, 1);
      expect(pendingChanges, lessThanOrEqualTo(2));
    });

    test(
      'marks only nodes the pool runs as running, the rest queued',
      () async {
        final answers = <String, Completer<Delay>>{};
        when(() => core.testDelay(_delayTest(_testUrl))).thenAnswer(
          (invocation) => answers
              .putIfAbsent(
                (invocation.positionalArguments[0] as TestDelayParams)
                    .proxyName,
                Completer<Delay>.new,
              )
              .future,
        );
        final container = _delayContainer(buildContainer);
        final proxies = List.generate(
          maxConcurrentDelayTests + 1,
          (index) => Proxy(name: 'HK-$index', type: 'ss'),
        );
        DelayTestPhase? phaseOf(int index) => container.read(
          pendingDelayTestsProvider,
        )[delayTestKey(_testUrl, 'HK-$index')];

        final run = actionOf(container).delayTest(proxies);

        expect(phaseOf(0), DelayTestPhase.running);
        expect(phaseOf(maxConcurrentDelayTests - 1), DelayTestPhase.running);
        expect(phaseOf(maxConcurrentDelayTests), DelayTestPhase.queued);

        answers['HK-0']!.completeError(TimeoutException('no answer'));
        await Future<void>.delayed(renderThrottleDuration * 2);

        expect(phaseOf(0), isNull);
        expect(phaseOf(maxConcurrentDelayTests), DelayTestPhase.running);

        for (final answer in answers.values) {
          if (!answer.isCompleted) {
            answer.completeError(TimeoutException('no answer'));
          }
        }
        await run;

        expect(container.read(pendingDelayTestsProvider), isEmpty);
      },
    );

    test('probes a node that appears twice only once', () async {
      when(() => core.testDelay(_delayTest(_testUrl, 'HK-01'))).thenAnswer(
        (_) async => const Delay(name: 'HK-01', url: _testUrl, value: 10),
      );
      final container = _delayContainer(buildContainer);

      await actionOf(container).delayTest(const [_proxy, _proxy]);

      verify(() => core.testDelay(_delayTest(_testUrl, 'HK-01'))).called(1);
    });

    test('passes the delay test timeout setting to the core', () async {
      when(() => core.testDelay(_delayTest(_testUrl, 'HK-01'))).thenAnswer(
        (_) async => const Delay(name: 'HK-01', url: _testUrl, value: 10),
      );
      final container = _delayContainer(buildContainer);
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(delayTestTimeout: 2000));

      await actionOf(container).delayTest(const [_proxy]);

      verify(
        () => core.testDelay(
          const TestDelayParams(
            proxyName: 'HK-01',
            testUrl: _testUrl,
            timeout: 2000,
          ),
        ),
      ).called(1);
    });

    test('testing groups probes a shared node once per test URL', () async {
      const otherUrl = 'http://other.test';
      when(() => core.testDelay(any())).thenAnswer(
        (invocation) async => Delay(
          url: (invocation.positionalArguments[0] as TestDelayParams).testUrl,
          name:
              (invocation.positionalArguments[0] as TestDelayParams).proxyName,
          value: 10,
        ),
      );
      final container = _delayContainer(buildContainer);
      final before = container.read(sortNumProvider);

      await actionOf(container).delayTestGroups([
        _group('A', const [_proxy]),
        _group('B', const [_proxy, Proxy(name: 'HK-02', type: 'ss')]),
        const Group(
          type: GroupType.URLTest,
          name: 'C',
          testUrl: otherUrl,
          all: [_proxy],
        ),
      ]);

      verify(() => core.testDelay(_delayTest(_testUrl, 'HK-01'))).called(1);
      verify(() => core.testDelay(_delayTest(_testUrl, 'HK-02'))).called(1);
      verify(() => core.testDelay(_delayTest(otherUrl, 'HK-01'))).called(1);
      expect(container.read(sortNumProvider), before + 1);
    });

    test(
      'testing a page group probes the nodes the timeout filter hides',
      () async {
        when(() => core.testDelay(_delayTest(_testUrl))).thenAnswer(
          (invocation) async => Delay(
            name: (invocation.positionalArguments[0] as TestDelayParams)
                .proxyName,
            url: _testUrl,
            value: 10,
          ),
        );
        final container = _delayContainer(buildContainer);
        container
            .read(groupsProvider.notifier)
            .update(
              (_) => [
                _group('Proxy', const [
                  _proxy,
                  Proxy(name: 'HK-02', type: 'ss'),
                  Proxy(name: 'JP-01', type: 'ss'),
                ]),
              ],
            );
        container
            .read(delayDataSourceProvider.notifier)
            .setDelay(const Delay(url: _testUrl, name: 'HK-02', value: -1));
        container
            .read(proxiesStyleSettingProvider.notifier)
            .update((state) => state.copyWith(hideTimeoutProxies: true));
        container.read(queryProvider(QueryTag.proxies).notifier).value = 'HK';

        await actionOf(container).delayTestPageGroup('Proxy');

        verify(() => core.testDelay(_delayTest(_testUrl, 'HK-01'))).called(1);
        verify(() => core.testDelay(_delayTest(_testUrl, 'HK-02'))).called(1);
        verifyNever(() => core.testDelay(_delayTest(_testUrl, 'JP-01')));
      },
    );

    test(
      'a group tested away from the proxies page ignores its search',
      () async {
        when(() => core.testDelay(_delayTest(_testUrl))).thenAnswer(
          (invocation) async => Delay(
            name: (invocation.positionalArguments[0] as TestDelayParams)
                .proxyName,
            url: _testUrl,
            value: 10,
          ),
        );
        final container = _delayContainer(buildContainer);
        container
            .read(groupsProvider.notifier)
            .update(
              (_) => [
                _group('Proxy', const [
                  _proxy,
                  Proxy(name: 'JP-01', type: 'ss'),
                ]),
              ],
            );
        container.listen(queryProvider(QueryTag.proxies), (_, _) {});
        container.read(queryProvider(QueryTag.proxies).notifier).value = 'HK';

        await actionOf(
          container,
        ).delayTestPageGroup('Proxy', matchSearch: false);

        verify(() => core.testDelay(_delayTest(_testUrl, 'HK-01'))).called(1);
        verify(() => core.testDelay(_delayTest(_testUrl, 'JP-01'))).called(1);
      },
    );

    test('a page group holds its testing mark until the run settles', () async {
      final release = Completer<Delay>();
      when(
        () => core.testDelay(_delayTest(_testUrl, 'HK-01')),
      ).thenAnswer((_) => release.future);
      final container = _delayContainer(buildContainer);
      container
          .read(groupsProvider.notifier)
          .update(
            (_) => [
              _group('Proxy', const [_proxy]),
            ],
          );

      final run = actionOf(container).delayTestPageGroup('Proxy');
      await actionOf(container).delayTestPageGroup('Proxy');

      expect(container.read(delayTestingGroupsProvider), {'Proxy'});
      release.completeError(
        const CoreMethodException(code: 'internal_error', message: 'boom'),
      );
      await run;

      verify(() => core.testDelay(_delayTest(_testUrl, 'HK-01'))).called(1);
      expect(container.read(delayTestingGroupsProvider), isEmpty);
    });

    test('stops the run once the transport is gone', () async {
      var calls = 0;
      when(() => core.testDelay(_delayTest(_testUrl))).thenAnswer((_) async {
        calls++;
        throw const CoreMethodException(
          code: 'transport_disconnected',
          message: 'the Core is gone',
        );
      });
      final container = _delayContainer(buildContainer);
      final proxies = List.generate(
        maxConcurrentDelayTests * 3,
        (index) => Proxy(name: 'HK-$index', type: 'ss'),
      );

      await actionOf(container).delayTest(proxies);

      expect(calls, lessThanOrEqualTo(maxConcurrentDelayTests));
      expect(calls, lessThan(proxies.length));
      expect(container.read(delayDataSourceProvider), isEmpty);
      expect(container.read(pendingDelayTestsProvider), isEmpty);
    });

    test('a proxy that answers nothing leaves the rest of the run', () async {
      var calls = 0;
      when(() => core.testDelay(_delayTest(_testUrl))).thenAnswer((
        invocation,
      ) async {
        calls++;
        final name =
            (invocation.positionalArguments[0] as TestDelayParams).proxyName;
        if (name == 'HK-1') {
          throw TimeoutException('no answer');
        }
        return Delay(name: name, url: _testUrl, value: 10);
      });
      final container = _delayContainer(buildContainer);
      final proxies = List.generate(
        8,
        (index) => Proxy(name: 'HK-$index', type: 'ss'),
      );

      await actionOf(container).delayTest(proxies);

      expect(calls, proxies.length);
      final delays = container.read(delayDataSourceProvider)[_testUrl];
      expect(delays?.length, proxies.length - 1);
      expect(delays?['HK-1'], isNull);
      expect(container.read(pendingDelayTestsProvider), isEmpty);
    });

    test('a proxy that fails leaves the rest of the run', () async {
      var calls = 0;
      when(() => core.testDelay(_delayTest(_testUrl))).thenAnswer((
        invocation,
      ) async {
        calls++;
        final name =
            (invocation.positionalArguments[0] as TestDelayParams).proxyName;
        if (name == 'HK-1') {
          throw const CoreMethodException(
            code: 'internal_error',
            message: 'internal panic',
          );
        }
        return Delay(name: name, url: _testUrl, value: 10);
      });
      final container = _delayContainer(buildContainer);
      final proxies = List.generate(
        8,
        (index) => Proxy(name: 'HK-$index', type: 'ss'),
      );

      await actionOf(container).delayTest(proxies);

      expect(calls, proxies.length);
      final delays = container.read(delayDataSourceProvider)[_testUrl];
      expect(delays?.length, proxies.length - 1);
      expect(delays?['HK-1'], isNull);
      expect(container.read(pendingDelayTestsProvider), isEmpty);
    });

    test('drops every spinner when the Core goes away mid-run', () async {
      final release = Completer<Delay>();
      when(
        () => core.testDelay(_delayTest(_testUrl)),
      ).thenAnswer((_) => release.future);
      final container = _delayContainer(buildContainer);
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;

      final run = actionOf(
        container,
      ).delayTest(const [_proxy, Proxy(name: 'HK-02', type: 'ss')]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(pendingDelayTestsProvider), isNotEmpty);

      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      expect(container.read(pendingDelayTestsProvider), isEmpty);

      release.complete(const Delay(name: 'HK-01', url: _testUrl, value: 10));
      await run;

      expect(container.read(delayDataSourceProvider), isEmpty);
      expect(container.read(pendingDelayTestsProvider), isEmpty);
    });
  });

  group('updateProvider', () {
    test(
      'stores the refreshed provider and clears the updating flag',
      () async {
        final refreshed = _provider('geo', count: 5);
        final release = Completer<void>();
        when(
          () => core.updateExternalProvider('geo'),
        ).thenAnswer((_) => release.future);
        when(
          () => core.getExternalProvider('geo'),
        ).thenAnswer((_) async => refreshed);
        final container = buildContainer();
        container.read(providersProvider.notifier).value = [_provider('geo')];

        final update = actionOf(
          container,
        ).updateProvider(_provider('geo'), showLoading: true);

        expect(container.read(isUpdatingProvider('provider_geo')), isTrue);

        release.complete();
        await update;

        expect(container.read(providersProvider), [refreshed]);
        expect(container.read(isUpdatingProvider('provider_geo')), isFalse);
      },
    );

    testWidgets('the stale sweep does not interrupt the provider update', (
      tester,
    ) async {
      final refreshed = _provider('geo', count: 8);
      final release = Completer<void>();
      when(
        () => core.updateExternalProvider('geo'),
      ).thenAnswer((_) => release.future);
      when(
        () => core.getExternalProvider('geo'),
      ).thenAnswer((_) async => refreshed);
      final container = buildContainer();
      container.read(updatingActionProvider.notifier);
      container.read(providersProvider.notifier).value = [_provider('geo')];

      final update = actionOf(
        container,
      ).updateProvider(_provider('geo'), showLoading: true);

      await tester.pump(updatingStaleTimeout + updatingSweepInterval);

      expect(container.read(isUpdatingProvider('provider_geo')), isFalse);

      release.complete();

      await update;
      expect(container.read(providersProvider), [refreshed]);

      await tester.pump(Duration.zero);
    });

    testWidgets('a core disconnect clears the provider updating state', (
      tester,
    ) async {
      final release = Completer<void>();
      when(
        () => core.updateExternalProvider('geo'),
      ).thenAnswer((_) => release.future);
      when(
        () => core.getExternalProvider('geo'),
      ).thenAnswer((_) async => _provider('geo'));
      final container = buildContainer();
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;

      final update = actionOf(
        container,
      ).updateProvider(_provider('geo'), showLoading: true);

      expect(container.read(isUpdatingProvider('provider_geo')), isTrue);

      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      await tester.pump();

      expect(container.read(isUpdatingProvider('provider_geo')), isFalse);

      release.complete();
      await update;
      await tester.pump(Duration.zero);
    });

    test('surfaces the core error without storing a provider', () async {
      when(() => core.updateExternalProvider('geo')).thenThrow(
        const CoreMethodException(code: 'core_error', message: 'update failed'),
      );
      final container = buildContainer();

      await expectLater(
        actionOf(container).updateProvider(_provider('geo'), showLoading: true),
        throwsA(isA<CoreMethodException>()),
      );

      expect(container.read(providersProvider), isEmpty);
      expect(container.read(isUpdatingProvider('provider_geo')), isFalse);
      verifyNever(() => core.getExternalProvider(any()));
    });

    test('clears the updating flag when core throws', () async {
      when(
        () => core.updateExternalProvider('geo'),
      ).thenThrow(StateError('boom'));
      final container = buildContainer();

      await expectLater(
        actionOf(container).updateProvider(_provider('geo'), showLoading: true),
        throwsStateError,
      );

      expect(container.read(isUpdatingProvider('provider_geo')), isFalse);
    });
  });

  group('sideLoadExternalProvider', () {
    test('stores the provider after a successful side load', () async {
      final refreshed = _provider('rules', count: 3);
      final release = Completer<void>();
      when(
        () => core.sideLoadExternalProvider(
          providerName: 'rules',
          data: 'payload',
        ),
      ).thenAnswer((_) => release.future);
      when(
        () => core.getExternalProvider('rules'),
      ).thenAnswer((_) async => refreshed);
      final container = buildContainer();
      container.read(providersProvider.notifier).value = [_provider('rules')];

      final sideLoad = actionOf(container).sideLoadExternalProvider(
        _provider('rules'),
        'payload',
        showLoading: true,
      );

      expect(container.read(isUpdatingProvider('provider_rules')), isTrue);

      release.complete();
      await sideLoad;

      expect(container.read(providersProvider), [refreshed]);
      expect(container.read(isUpdatingProvider('provider_rules')), isFalse);
    });

    test('surfaces the core error and skips the refresh', () async {
      when(
        () => core.sideLoadExternalProvider(providerName: 'rules', data: 'bad'),
      ).thenThrow(
        const CoreMethodException(
          code: 'core_error',
          message: 'invalid payload',
        ),
      );
      final container = buildContainer();

      await expectLater(
        actionOf(container).sideLoadExternalProvider(_provider('rules'), 'bad'),
        throwsA(isA<CoreMethodException>()),
      );
      verifyNever(() => core.getExternalProvider(any()));
    });
  });

  group('addToLocalProxies', () {
    const hongKong = CustomProxy(
      id: 5,
      definition: {'name': 'HK', 'type': 'ss', 'server': 'hk.example.com'},
    );

    late db.Database testDatabase;

    setUp(() async {
      testDatabase = db.Database(NativeDatabase.memory());
      db.database = testDatabase;
      await testDatabase.customProxies.put(hongKong.toCompanion('a0'));
    });

    tearDown(() => testDatabase.close());

    test(
      'adds the running proxy after the app proxies, without its dialer',
      () async {
        when(() => core.getProxyDefinition('SG')).thenAnswer(
          (_) async => {
            'name': 'SG',
            'type': 'ss',
            'server': 'sg.example.com',
            'dialer-proxy': 'Relay',
          },
        );

        await actionOf(buildContainer()).addToLocalProxies('SG');

        final proxies = await testDatabase.customProxiesDao.query().get();
        expect([for (final proxy in proxies) proxy.name], ['HK', 'SG']);
        expect(proxies.last.definition, {
          'name': 'SG',
          'type': 'ss',
          'server': 'sg.example.com',
        });
      },
    );

    test('adds nothing for a proxy an app proxy already holds', () async {
      when(
        () => core.getProxyDefinition('Hong Kong'),
      ).thenAnswer((_) async => {...hongKong.definition, 'name': 'Hong Kong'});

      await actionOf(buildContainer()).addToLocalProxies('Hong Kong');

      expect(await testDatabase.customProxiesDao.query().get(), [
        hongKong.copyWith(order: 'a0'),
      ]);
    });

    test('names a proxy the running config does not define', () async {
      when(() => core.getProxyDefinition('Gone')).thenAnswer((_) async => null);

      await expectLater(
        actionOf(buildContainer()).addToLocalProxies('Gone'),
        throwsA(
          isA<MessageException>().having(
            (error) => error.message,
            'message',
            currentAppLocalizations.customIssueMissingProxies('Gone'),
          ),
        ),
      );
    });
  });

  group('current profile mutations', () {
    test('updateCurrentGroupName writes the new group onto the profile', () {
      final profile = Profile.normal(label: 'p');
      final container = buildContainer(profile: profile);

      actionOf(container).updateCurrentGroupName('Proxy');

      expect(container.read(profilesProvider).single.currentGroupName, 'Proxy');
    });

    test('updateCurrentGroupName is a no-op for the same group', () {
      final profile = Profile.normal(
        label: 'p',
      ).copyWith(currentGroupName: 'Proxy');
      final container = buildContainer(profile: profile);

      actionOf(container).updateCurrentGroupName('Proxy');

      expect(container.read(profilesProvider).single, same(profile));
    });

    test('updateCurrentUnfoldSet is a no-op without a current profile', () {
      final container = buildContainer();

      expect(
        () => actionOf(container).updateCurrentUnfoldSet({'Proxy'}),
        returnsNormally,
      );
      expect(container.read(profilesProvider), isEmpty);
    });

    test('updateCurrentUnfoldSet stores the set on the current profile', () {
      final profile = Profile.normal(label: 'p');
      final container = buildContainer(profile: profile);

      actionOf(container).updateCurrentUnfoldSet({'Proxy', 'Auto'});

      expect(container.read(profilesProvider).single.unfoldSet, {
        'Proxy',
        'Auto',
      });
    });
  });
}
