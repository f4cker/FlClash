import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

const _node = TailscaleNode(
  profileId: 42,
  name: 'ts',
  generation: 3,
  controlUrl: 'https://controlplane.tailscale.com',
  overridable: true,
);

const _stale = CoreMethodException(
  code: 'tailscale_stale_generation',
  message: 'reloaded',
);

Future<List<Object?>> _stored() async {
  final raw = (await SharedPreferences.getInstance()).getString(
    tailscaleNodeRecordsKey,
  );
  return raw == null ? const [] : json.decode(raw) as List<Object?>;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const TailscaleNodeRef(name: '', generation: 0));
  });

  late _MockCore core;

  setUp(() async {
    core = _MockCore();
    await mockPreferences();
  });

  ProviderContainer build({List<TailscaleNodeRecord> records = const []}) {
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        tailscaleNodeRecordsProvider.overrideWithBuild((_, _) => records),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  TailscaleAction action(ProviderContainer container) =>
      container.read(tailscaleActionProvider.notifier);

  List<TailscaleNodeRecord> records(ProviderContainer container) =>
      container.read(tailscaleNodeRecordsProvider);

  test('a logout reaches the Core only after its guard is stored', () async {
    final container = build();
    List<Object?>? storedWhenAsked;
    when(() => core.logoutTailscale(any())).thenAnswer((_) async {
      storedWhenAsked = await _stored();
      return const TailscaleLogoutResult(
        generation: 3,
        outcome: TailscaleLogoutOutcome.confirmed,
      );
    });

    final result = await action(container).logout(_node);

    expect(result.outcome, TailscaleLogoutOutcome.confirmed);
    expect(storedWhenAsked, [
      {
        'profile-id': 42,
        'name': 'ts',
        'control-url': 'https://controlplane.tailscale.com',
        'logged-out': true,
      },
    ]);
    expect(records(container).single.loggedOut, isTrue);
  });

  test('a login the Core never bound keeps the guard', () async {
    final guarded = TailscaleNodeRecord(
      profileId: 42,
      name: 'ts',
      controlUrl: _node.controlUrl,
      loggedOut: true,
    );
    final container = build(records: [guarded]);
    when(
      () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
    ).thenThrow(_stale);

    await expectLater(action(container).login(_node), throwsA(_stale));
    expect(records(container), [guarded]);

    when(
      () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
    ).thenAnswer(
      (_) async => const TailscaleLoginResult(generation: 3, pending: true),
    );
    await action(container).login(_node);

    expect(records(container), isEmpty);
    expect(await _stored(), isEmpty);
  });

  test('settings are saved first and applied by outcome', () async {
    final container = build();
    when(
      () => core.setTailscalePrefs(
        any(),
        exitNode: any(named: 'exitNode'),
        acceptRoutes: any(named: 'acceptRoutes'),
      ),
    ).thenAnswer(
      (_) async => const TailscalePrefsResult(
        generation: 3,
        outcome: TailscalePrefsOutcome.notRunning,
      ),
    );

    final saved = await action(container).setPrefs(_node, exitNode: '');
    expect(saved.outcome, TailscaleSetPrefsOutcome.saved);

    when(
      () => core.setTailscalePrefs(
        any(),
        exitNode: any(named: 'exitNode'),
        acceptRoutes: any(named: 'acceptRoutes'),
      ),
    ).thenAnswer(
      (_) async => const TailscalePrefsResult(
        generation: 3,
        outcome: TailscalePrefsOutcome.failed,
        error: TailscaleError(code: 'tailscale_exit_node_invalid'),
      ),
    );
    final failed = await action(container).setPrefs(_node, acceptRoutes: true);

    expect(failed.outcome, TailscaleSetPrefsOutcome.applyFailed);
    expect(failed.error?.code, 'tailscale_exit_node_invalid');
    expect(records(container).single.exitNode, '');
    expect(records(container).single.acceptRoutes, isTrue);
    verify(
      () => core.setTailscalePrefs(
        const TailscaleNodeRef(name: 'ts', generation: 3),
        acceptRoutes: true,
      ),
    ).called(1);
  });

  test('a node the Core cannot override keeps no saved setting', () async {
    final container = build();
    when(
      () => core.setTailscalePrefs(
        any(),
        exitNode: any(named: 'exitNode'),
        acceptRoutes: any(named: 'acceptRoutes'),
      ),
    ).thenThrow(
      const CoreMethodException(
        code: 'tailscale_not_overridable',
        message: 'provider',
      ),
    );

    final rejected = await action(
      container,
    ).setPrefs(_node.copyWith(overridable: false), exitNode: 'x');
    final raced = await action(container).setPrefs(_node, exitNode: 'x');

    expect(rejected.outcome, TailscaleSetPrefsOutcome.failed);
    expect(raced.outcome, TailscaleSetPrefsOutcome.failed);
    expect(raced.error?.code, 'tailscale_not_overridable');
    expect(records(container), isEmpty);
    verify(() => core.setTailscalePrefs(any(), exitNode: 'x')).called(1);
  });

  test('the setup payload holds the records of the current profile', () {
    const subscription = Profile(
      id: 42,
      type: ProfileType.url,
      autoUpdateDuration: defaultUpdateDuration,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([subscription])),
        currentProfileIdProvider.overrideWithBuild((_, _) => 42),
        tailscaleNodeRecordsProvider.overrideWithBuild(
          (_, _) => const [
            TailscaleNodeRecord(profileId: 42, name: 'a', loggedOut: true),
            TailscaleNodeRecord(profileId: 7, name: 'b', exitNode: ''),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(tailscaleSetupProvider),
      const TailscaleSetup(
        profileId: 42,
        configSource: TailscaleSettingSource.subscription,
        nodes: [TailscaleNodeSetup(name: 'a', loggedOut: true)],
      ),
    );
  });

  test('a state event of another instance reads the nodes again', () async {
    var reads = 0;
    when(() => core.getTailscaleNodes()).thenAnswer((_) async {
      reads++;
      return [_node];
    });
    final container = build();
    container.listen(tailscaleNodesProvider, (_, _) {});
    await container.read(tailscaleNodesProvider.future);
    final nodes = container.read(tailscaleNodesProvider.notifier);

    nodes.applyEvent(
      const TailscaleStateEvent(
        name: 'ts',
        generation: 3,
        state: TailscaleBackendState.needsLogin,
      ),
    );
    expect(
      container.read(tailscaleNodesProvider).value?.single.backendState,
      TailscaleBackendState.needsLogin,
    );
    expect(reads, 1);

    nodes.applyEvent(const TailscaleStateEvent(name: 'ts', generation: 4));
    await container.read(tailscaleNodesProvider.future);
    expect(reads, 2);
  });
}
