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

class _FakeSetupAction extends SetupAction {
  static bool result = true;
  static int applied = 0;
  static List<TailscaleManagedRecord>? seenAtApply;

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applied++;
    seenAtApply = ref.read(tailscaleManagedRecordsProvider);
    return result;
  }
}

const _account = TailscaleAccount(
  userId: 'u1',
  loginName: 'pat@example.test',
  tailnet: 'example-net.test',
  controlUrl: 'https://controlplane.tailscale.com',
);

TailscaleNode _managed(
  String id, {
  bool attached = false,
  TailscaleAccount? account = _account,
}) => TailscaleNode(
  profileId: 42,
  name: 'tailscale-$id',
  generation: 1,
  managedId: id,
  attached: attached,
  account: account,
  hasIdentity: account != null,
);

Future<List<Object?>> _stored() async {
  final raw = (await SharedPreferences.getInstance()).getString(
    tailscaleManagedRecordsKey,
  );
  return raw == null ? const [] : json.decode(raw) as List<Object?>;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const TailscaleNodeRef(name: '', generation: 0));
    registerFallbackValue(<TailscaleRouteAssignment>[]);
  });

  late _MockCore core;

  setUp(() async {
    core = _MockCore();
    await mockPreferences();
    _FakeSetupAction.result = true;
    _FakeSetupAction.applied = 0;
    _FakeSetupAction.seenAtApply = null;
  });

  ProviderContainer build({
    List<TailscaleManagedRecord> records = const [],
    int? profileId = 42,
  }) {
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(
          () => TestProfiles([
            const Profile(id: 42, autoUpdateDuration: Duration.zero),
          ]),
        ),
        currentProfileIdProvider.overrideWithBuild((_, _) => profileId),
        setupActionProvider.overrideWith(_FakeSetupAction.new),
        tailscaleManagedRecordsProvider.overrideWithBuild((_, _) => records),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  TailscaleAction action(ProviderContainer container) =>
      container.read(tailscaleActionProvider.notifier);

  List<TailscaleManagedRecord> records(ProviderContainer container) =>
      container.read(tailscaleManagedRecordsProvider)!;

  TailscaleManagedPanel panelOf(ProviderContainer container, String id) =>
      container
          .read(tailscaleManagedPanelsProvider.notifier)
          .of(tailscaleManagedNodeKey(42, id));

  group('add', () {
    test(
      'saves the draft before the apply and returns its listed node',
      () async {
        final container = build();
        when(() => core.getTailscaleNodes()).thenAnswer((_) async {
          final id = records(container).single.id;
          return [_managed(id, account: null)];
        });

        final node = await action(container).addManaged(newProfileLabel: 'x');

        expect(_FakeSetupAction.seenAtApply, hasLength(1));
        expect(node, isNotNull);
        expect(node!.managedId, records(container).single.id);
        expect(node.attached, isFalse);
        expect(panelOf(container, node.managedId).notice, isNull);
        expect((await _stored()).single, containsPair('profile-id', 42));
        verifyNever(
          () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
        );
      },
    );

    test(
      'a draft the Core never lists is a failure, an unread one unknown',
      () async {
        final container = build();
        when(() => core.getTailscaleNodes()).thenAnswer((_) async => const []);

        expect(
          await action(container).addManaged(newProfileLabel: 'x'),
          isNull,
        );
        expect(
          panelOf(container, '').notice,
          TailscaleManagedNotice.prepareFailed,
        );

        when(
          () => core.getTailscaleNodes(),
        ).thenThrow(const CoreMethodException(code: 'boom', message: 'boom'));
        expect(
          await action(container).addManaged(newProfileLabel: 'x'),
          isNull,
        );
        expect(
          panelOf(container, '').notice,
          TailscaleManagedNotice.prepareUnknown,
        );
      },
    );
  });

  group('attach', () {
    test('only a read showing the node attached confirms it', () async {
      final container = build(
        records: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
      );
      when(
        () => core.getTailscaleNodes(),
      ).thenAnswer((_) async => [_managed('m1', attached: true)]);

      final state = await action(
        container,
      ).attachManaged(_managed('m1'), [_managed('m1')]);

      expect(state, TailscaleAttachState.attached);
      expect(_FakeSetupAction.seenAtApply!.single.attached, isTrue);
      expect(panelOf(container, 'm1').attach, TailscaleAttachState.attached);
    });

    test('a read without it is a failure and takes the mark back', () async {
      final container = build(
        records: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
      );
      when(
        () => core.getTailscaleNodes(),
      ).thenAnswer((_) async => [_managed('m1')]);

      final state = await action(
        container,
      ).attachManaged(_managed('m1'), [_managed('m1')]);

      expect(state, TailscaleAttachState.failed);
      expect(records(container).single.attached, isFalse);
    });

    test('a failed apply with an unread list stays unknown', () async {
      _FakeSetupAction.result = false;
      final container = build(
        records: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
      );
      when(
        () => core.getTailscaleNodes(),
      ).thenThrow(const CoreMethodException(code: 'boom', message: 'boom'));

      final state = await action(
        container,
      ).attachManaged(_managed('m1'), [_managed('m1')]);

      expect(state, TailscaleAttachState.unknown);
      expect(
        await action(container).attachManaged(_managed('m1'), const []),
        TailscaleAttachState.unknown,
        reason: 'an unknown attach never writes again on its own',
      );
      expect(_FakeSetupAction.applied, 1);
    });

    test('the same account twice is never attached', () async {
      final container = build(
        records: const [
          TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
          TailscaleManagedRecord(id: 'm2', profileId: 42),
        ],
      );
      final nodes = [_managed('m1', attached: true), _managed('m2')];

      final state = await action(container).attachManaged(nodes[1], nodes);

      expect(state, TailscaleAttachState.duplicate);
      expect(records(container)[1].attached, isFalse);
      expect(_FakeSetupAction.applied, 0);
    });
  });

  group('sign-out and removal', () {
    test('a plain sign-out keeps the record, signed out', () async {
      final container = build(
        records: const [
          TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
        ],
      );
      when(() => core.logoutTailscale(any())).thenAnswer(
        (_) async => const TailscaleLogoutResult(
          generation: 1,
          outcome: TailscaleLogoutOutcome.confirmed,
        ),
      );

      expect(
        await action(container).signOutManaged(_managed('m1', attached: true)),
        isTrue,
      );
      expect(records(container).single.loggedOut, isTrue);
      expect(records(container).single.attached, isTrue);
      expect(panelOf(container, 'm1').notice, TailscaleManagedNotice.signedOut);
    });

    test('the guard is stored before the sign-out; the last account forgets '
        'the routes', () async {
      final container = build(
        records: const [
          TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
        ],
      );
      List<Object?>? storedWhenAsked;
      when(() => core.logoutTailscale(any())).thenAnswer((_) async {
        storedWhenAsked = await _stored();
        return const TailscaleLogoutResult(
          generation: 1,
          outcome: TailscaleLogoutOutcome.confirmed,
        );
      });
      when(() => core.forgetTailscaleRoutes(42)).thenAnswer(
        (_) async => const TailscaleForgetResult(outcome: 'confirmed'),
      );
      when(() => core.getTailscaleNodes()).thenAnswer((_) async => const []);

      final notice = await action(
        container,
      ).removeManaged(_managed('m1', attached: true));

      expect(notice, isNull);
      expect(storedWhenAsked!.single, containsPair('removing', true));
      expect(storedWhenAsked!.single, containsPair('logged-out', true));
      verify(() => core.forgetTailscaleRoutes(42)).called(1);
      expect(records(container), isEmpty);
    });

    test('another account stays, and its routes are not forgotten', () async {
      final container = build(
        records: const [
          TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
          TailscaleManagedRecord(id: 'm2', profileId: 42, attached: true),
        ],
      );
      when(() => core.logoutTailscale(any())).thenAnswer(
        (_) async => const TailscaleLogoutResult(
          generation: 1,
          outcome: TailscaleLogoutOutcome.confirmed,
        ),
      );
      when(
        () => core.getTailscaleNodes(),
      ).thenAnswer((_) async => [_managed('m2', attached: true)]);

      expect(
        await action(container).removeManaged(_managed('m1', attached: true)),
        isNull,
      );
      verifyNever(() => core.forgetTailscaleRoutes(any()));
      expect(records(container).single.id, 'm2');
      expect(records(container).single.loggedOut, isFalse);
    });

    test('an unanswered sign-out keeps the record pending; the profile '
        'cannot be deleted until a read settles it', () async {
      final container = build(
        records: const [
          TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
        ],
      );
      when(() => core.logoutTailscale(any())).thenAnswer(
        (_) async => const TailscaleLogoutResult(
          generation: 1,
          outcome: TailscaleLogoutOutcome.unknown,
        ),
      );

      final notice = await action(
        container,
      ).removeManaged(_managed('m1', attached: true));

      expect(notice, TailscaleManagedNotice.removeLogoutUnknown);
      expect(records(container).single.removing, isTrue);
      expect(action(container).hasPendingManaged(42), isTrue);
      expect(
        await action(container).removeManaged(_managed('m1', attached: true)),
        TailscaleManagedNotice.removeUnknown,
      );
      verify(() => core.logoutTailscale(any())).called(1);

      when(
        () => core.getTailscaleNodes(),
      ).thenAnswer((_) async => [_managed('m1', attached: true)]);
      when(() => core.getTailscaleStatus(any())).thenAnswer(
        (_) async => TailscaleStatus(node: _managed('m1', attached: true)),
      );
      await action(container).recheckManaged(_managed('m1', attached: true));
      expect(action(container).hasPendingManaged(42), isFalse);
    });
  });

  group('routes', () {
    const target = TailscaleRouteTarget(kind: 'ip', value: '100.64.0.9');
    const owner = TailscaleRouteOwner(kind: 'managed', id: 'm2');
    const choice = TailscaleRouteAssignment(target: target, owner: owner);

    test('a choice is updated only once a read shows it in force', () async {
      final container = build();
      when(() => core.assignTailscaleRoutes(42, any())).thenAnswer(
        (_) async => const TailscaleAssignResult(outcome: 'applied'),
      );
      when(() => core.getTailscaleRoutes(42)).thenAnswer(
        (_) async => const TailscaleRoutes(
          profileId: 42,
          targets: [
            TailscaleRouteTargetReport(
              target: target,
              state: TailscaleRouteState.assigned,
              owner: owner,
            ),
          ],
        ),
      );

      expect(
        await action(container).assignRoutes(42, [choice]),
        TailscaleAssignNotice.updated,
      );

      when(
        () => core.getTailscaleRoutes(42),
      ).thenAnswer((_) async => const TailscaleRoutes(profileId: 42));
      expect(
        await action(container).assignRoutes(42, [choice]),
        TailscaleAssignNotice.saved,
      );
    });

    test('a refusal fails, no answer is unknown', () async {
      final container = build();
      when(() => core.assignTailscaleRoutes(42, any())).thenThrow(
        const CoreMethodException(
          code: 'tailscale_assign_invalid',
          message: 'x',
        ),
      );
      expect(
        await action(container).assignRoutes(42, [choice]),
        TailscaleAssignNotice.failed,
      );

      when(
        () => core.assignTailscaleRoutes(42, any()),
      ).thenThrow(const CoreMethodException(code: 'timeout', message: 'x'));
      expect(
        await action(container).assignRoutes(42, [choice]),
        TailscaleAssignNotice.unknown,
      );
    });

    test('deleting a profile drops only its own accounts', () async {
      final container = build(
        records: const [
          TailscaleManagedRecord(id: 'm1', profileId: 42),
          TailscaleManagedRecord(id: 'm9', profileId: 7),
        ],
      );
      when(() => core.forgetTailscaleRoutes(42)).thenAnswer(
        (_) async => const TailscaleForgetResult(outcome: 'confirmed'),
      );

      await action(container).forgetProfile(42);

      verify(() => core.forgetTailscaleRoutes(42)).called(1);
      expect(records(container).single.id, 'm9');
    });
  });

  test('the setup payload holds the accounts of the current profile', () {
    final container = build(
      records: const [
        TailscaleManagedRecord(
          id: 'm1',
          profileId: 42,
          acceptRoutes: true,
          attached: true,
        ),
        TailscaleManagedRecord(id: 'm9', profileId: 7),
      ],
    );

    final setup = container.read(tailscaleSetupProvider)!;

    expect(setup.managed.map((item) => item.id), ['m1']);
    expect(setup.managed.single.attached, isTrue);
    expect(setup.managed.single.acceptRoutes, isTrue);
  });
}
