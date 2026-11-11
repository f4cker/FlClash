import 'dart:async';
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

  test('an exit node keeps its name for display and never sends it', () async {
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

    await action(
      container,
    ).setPrefs(_node, exitNode: '100.88.12.4', exitNodeName: 'nas-sg');
    expect(records(container).single.exitNode, '100.88.12.4');
    expect(records(container).single.exitNodeName, 'nas-sg');
    verify(
      () => core.setTailscalePrefs(
        const TailscaleNodeRef(name: 'ts', generation: 3),
        exitNode: '100.88.12.4',
      ),
    ).called(1);

    await action(container).setPrefs(_node, acceptRoutes: false);
    expect(records(container).single.exitNodeName, 'nas-sg');

    await action(
      container,
    ).setPrefs(_node, exitNode: '', exitNodeName: 'nas-sg');
    expect(records(container).single.exitNode, '');
    expect(records(container).single.exitNodeName, isNull);
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
        code: 'tailscale_override_ambiguous',
        message: 'provider',
      ),
    );

    final rejected = await action(
      container,
    ).setPrefs(_node.copyWith(overridable: false), exitNode: 'x');
    final raced = await action(container).setPrefs(_node, exitNode: 'x');

    expect(rejected.outcome, TailscaleSetPrefsOutcome.failed);
    expect(raced.outcome, TailscaleSetPrefsOutcome.failed);
    expect(raced.error?.code, 'tailscale_override_ambiguous');
    expect(records(container), isEmpty);
    verify(() => core.setTailscalePrefs(any(), exitNode: 'x')).called(1);
  });

  group('legacy migration', () {
    const migration = TailscaleLegacyMigration(
      fingerprint: 'f1',
      profileId: 42,
      name: 'ts',
      controlUrl: 'https://controlplane.tailscale.com',
    );
    const offer = TailscaleLegacyIdentity(
      loginName: 'old@example.test',
      controlUrl: 'https://controlplane.tailscale.com',
      fingerprint: 'f1',
      eligibility: TailscaleLegacyEligibility.eligible,
      offerToken: 'token-1',
    );
    final offered = _node.copyWith(legacy: offer);
    final guarded = TailscaleNodeRecord(
      profileId: 42,
      name: 'ts',
      controlUrl: _node.controlUrl,
      loggedOut: true,
    );

    TailscaleMigrateResult result(
      TailscaleMigrateOutcome outcome, {
      bool targetUntouched = false,
      bool archiveIntact = true,
      TailscaleMigrateStage? stage,
    }) => TailscaleMigrateResult(
      generation: 3,
      outcome: outcome,
      migration: migration,
      node: _node.copyWith(
        hasIdentity: outcome == TailscaleMigrateOutcome.migrated,
      ),
      targetUntouched: targetUntouched,
      archiveIntact: archiveIntact,
      stage: stage,
    );

    TailscaleLegacyState legacyOf(ProviderContainer container) =>
        container.read(tailscaleLegacyStatesProvider)[_node.key] ??
        const TailscaleLegacyState();

    Future<ProviderContainer> buildWithNodes(List<TailscaleNode> nodes) async {
      final container = build(records: [guarded]);
      when(() => core.getTailscaleNodes()).thenAnswer((_) async => nodes);
      container.listen(tailscaleNodesProvider, (_, _) {});
      await container.read(tailscaleNodesProvider.future);
      return container;
    }

    test(
      'sends the confirmed token; a copy marks and lifts the guard',
      () async {
        final container = await buildWithNodes([offered]);
        when(
          () => core.migrateTailscaleLegacy(any(), offerToken: 'token-1'),
        ).thenAnswer((_) async => result(TailscaleMigrateOutcome.migrated));

        final notice = await action(container).migrateLegacy(offered, offer);

        expect(notice, TailscaleLegacyNotice.migrated);
        expect(container.read(tailscaleLegacyMigratedProvider), migration);
        expect(
          (await SharedPreferences.getInstance()).getString(
            tailscaleLegacyMigrationKey,
          ),
          json.encode(migration),
        );
        expect(records(container), isEmpty);
        expect(
          container.read(tailscaleNodesProvider).value?.single.hasIdentity,
          isTrue,
        );
        expect(legacyOf(container).migrating, isFalse);
      },
    );

    test('an offer without a token is refused without a call', () async {
      final container = build();
      final notice = await action(
        container,
      ).migrateLegacy(_node, offer.copyWith(offerToken: null));
      expect(notice, TailscaleLegacyNotice.changed);
      verifyNever(
        () => core.migrateTailscaleLegacy(
          any(),
          offerToken: any(named: 'offerToken'),
        ),
      );
    });

    for (final (code, want) in [
      ('tailscale_legacy_changed', TailscaleLegacyNotice.changed),
      ('tailscale_stale_generation', TailscaleLegacyNotice.changed),
      ('tailscale_has_identity', TailscaleLegacyNotice.changed),
      ('tailscale_legacy_already_migrated', TailscaleLegacyNotice.changed),
      ('tailscale_legacy_unreadable', TailscaleLegacyNotice.unreadable),
      ('tailscale_legacy_unconfirmed', TailscaleLegacyNotice.unconfirmed),
      ('transport_error', TailscaleLegacyNotice.unknown),
    ]) {
      test('a refusal $code keeps no marker and the guard', () async {
        final container = build(records: [guarded]);
        when(
          () => core.migrateTailscaleLegacy(
            any(),
            offerToken: any(named: 'offerToken'),
          ),
        ).thenThrow(CoreMethodException(code: code, message: 'x'));

        final notice = await action(container).migrateLegacy(offered, offer);

        expect(notice, want);
        expect(legacyOf(container).notice, want);
        expect(container.read(tailscaleLegacyMigratedProvider), isNull);
        expect(records(container), [guarded]);
      });
    }

    test('only a failure with an intact archive is a failure', () async {
      final container = build();
      Future<TailscaleLegacyNotice> migrateWith(TailscaleMigrateResult answer) {
        when(
          () => core.migrateTailscaleLegacy(
            any(),
            offerToken: any(named: 'offerToken'),
          ),
        ).thenAnswer((_) async => answer);
        return action(container).migrateLegacy(offered, offer);
      }

      expect(
        await migrateWith(
          result(
            TailscaleMigrateOutcome.failed,
            targetUntouched: true,
            stage: TailscaleMigrateStage.claim,
          ),
        ),
        TailscaleLegacyNotice.failed,
      );
      expect(legacyOf(container).stage, TailscaleMigrateStage.claim);
      expect(legacyOf(container).archiveIntact, isTrue);
      expect(
        await migrateWith(
          result(
            TailscaleMigrateOutcome.failed,
            targetUntouched: true,
            archiveIntact: false,
            stage: TailscaleMigrateStage.copy,
          ),
        ),
        TailscaleLegacyNotice.unknown,
      );
      expect(legacyOf(container).archiveIntact, isFalse);
      expect(legacyOf(container).stage, TailscaleMigrateStage.copy);
    });

    test('no answer leaves no stage and no proof of the archive', () async {
      final container = build();
      when(
        () => core.migrateTailscaleLegacy(
          any(),
          offerToken: any(named: 'offerToken'),
        ),
      ).thenThrow(TimeoutException('migrate'));
      expect(
        await action(container).migrateLegacy(offered, offer),
        TailscaleLegacyNotice.unknown,
      );
      expect(legacyOf(container).stage, isNull);
      expect(legacyOf(container).archiveIntact, isFalse);
    });

    test('an unanswered migration stays pending through reads that do not '
        'settle it', () async {
      final container = await buildWithNodes([offered]);
      when(
        () => core.migrateTailscaleLegacy(
          any(),
          offerToken: any(named: 'offerToken'),
        ),
      ).thenThrow(TimeoutException('no answer'));
      expect(
        await action(container).migrateLegacy(offered, offer),
        TailscaleLegacyNotice.unknown,
      );

      when(() => core.getTailscaleNodes()).thenThrow(
        const CoreMethodException(code: 'tailscale_unsupported', message: 'x'),
      );
      expect(
        await action(container).recheckLegacy(_node.key),
        TailscaleLegacyNotice.unknown,
      );

      final ambiguous = _node.copyWith(
        legacy: offer.copyWith(
          eligibility: TailscaleLegacyEligibility.unconfirmed,
          offerToken: null,
        ),
      );
      when(() => core.getTailscaleNodes()).thenAnswer((_) async => [ambiguous]);
      expect(
        await action(container).recheckLegacy(_node.key),
        TailscaleLegacyNotice.unknown,
      );
      expect(legacyOf(container).notice, TailscaleLegacyNotice.unknown);
      verify(
        () => core.migrateTailscaleLegacy(
          any(),
          offerToken: any(named: 'offerToken'),
        ),
      ).called(1);
    });

    test('a read showing the target untouched and still eligible settles it '
        'as not migrated', () async {
      final container = await buildWithNodes([offered]);
      container
          .read(tailscaleLegacyStatesProvider.notifier)
          .change(
            _node.key,
            (state) => state.copyWith(notice: TailscaleLegacyNotice.unknown),
          );
      expect(
        await action(container).recheckLegacy(_node.key),
        TailscaleLegacyNotice.failed,
      );
    });

    test('a read showing the target with its own login settles it as '
        'migrated and keeps the marker', () async {
      final container = await buildWithNodes([offered]);
      container
          .read(tailscaleLegacyStatesProvider.notifier)
          .change(
            _node.key,
            (state) => state.copyWith(notice: TailscaleLegacyNotice.unknown),
          );
      when(() => core.getTailscaleNodes()).thenAnswer(
        (_) async => [
          _node.copyWith(
            hasIdentity: true,
            legacy: offer.copyWith(
              eligibility: TailscaleLegacyEligibility.hasIdentity,
              migratedTo: migration,
            ),
          ),
        ],
      );
      expect(
        await action(container).recheckLegacy(_node.key),
        TailscaleLegacyNotice.migrated,
      );
      expect(container.read(tailscaleLegacyMigratedProvider), migration);
      expect(records(container), isEmpty);
    });
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
        tailscaleLegacyMigratedProvider.overrideWithBuild(
          (_, _) => const TailscaleLegacyMigration(fingerprint: 'f1'),
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
        legacyMigration: TailscaleLegacyMigration(fingerprint: 'f1'),
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
