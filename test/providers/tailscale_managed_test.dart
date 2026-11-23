import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/database/database.dart' as db;
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
    bool announceMountSkips = false,
    bool Function()? owns,
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applied++;
    seenAtApply = ref.read(tailscaleManagedRecordsProvider);
    return result;
  }
}

/// Refuses any write that drops a record.
class _FailingDrop extends TailscaleManagedRecords {
  _FailingDrop(this.initial);

  final List<TailscaleManagedRecord> initial;

  @override
  List<TailscaleManagedRecord>? build() => initial;

  @override
  Future<bool> modify(
    List<TailscaleManagedRecord>? Function(List<TailscaleManagedRecord> records)
    update,
  ) async {
    final next = update(state!);
    if (next == null || next.length < state!.length) {
      return false;
    }
    return super.modify((_) => next);
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
    final testDatabase = db.Database(NativeDatabase.memory());
    db.database = testDatabase;
    addTearDown(testDatabase.close);
    _FakeSetupAction.result = true;
    _FakeSetupAction.applied = 0;
    _FakeSetupAction.seenAtApply = null;
    when(() => core.getTailscaleManagedState(any())).thenAnswer(
      (invocation) async => TailscaleManagedState(
        profileId: invocation.positionalArguments.single as int,
        routes: 'absent',
        protection: 'none',
      ),
    );
  });

  ProviderContainer build({
    List<TailscaleManagedRecord>? records = const [],
    int? profileId = 42,
    bool failDrop = false,
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
        if (failDrop)
          tailscaleManagedRecordsProvider.overrideWith(
            () => _FailingDrop(records!),
          )
        else
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
      expect(
        action(container).hasPendingManaged(42),
        isTrue,
        reason: 'a node that still holds its sign-in proves no logout',
      );
      expect(records(container).single.removing, isTrue);

      final signedOut = _managed('m1', attached: true, account: null);
      when(() => core.getTailscaleNodes()).thenAnswer((_) async => [signedOut]);
      when(
        () => core.getTailscaleStatus(any()),
      ).thenAnswer((_) async => TailscaleStatus(node: signedOut));
      await action(container).recheckManaged(signedOut);
      expect(action(container).hasPendingManaged(42), isFalse);
    });

    test('the last account: the record goes first, then its routes; a '
        'failed forget reports the removal incomplete', () async {
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
      List<Object?>? storedWhenForgot;
      when(() => core.forgetTailscaleRoutes(42)).thenAnswer((_) async {
        storedWhenForgot = await _stored();
        return const TailscaleForgetResult(outcome: 'failed');
      });
      when(() => core.getTailscaleNodes()).thenAnswer((_) async => const []);

      final notice = await action(
        container,
      ).removeManaged(_managed('m1', attached: true));

      expect(storedWhenForgot, isEmpty);
      expect(notice, TailscaleManagedNotice.removeIncomplete);
      expect(records(container), isEmpty);
    });

    test('a record that cannot be dropped keeps the routes', () async {
      final container = build(
        records: const [
          TailscaleManagedRecord(id: 'm1', profileId: 42, attached: true),
        ],
        failDrop: true,
      );
      when(() => core.logoutTailscale(any())).thenAnswer(
        (_) async => const TailscaleLogoutResult(
          generation: 1,
          outcome: TailscaleLogoutOutcome.confirmed,
        ),
      );

      final notice = await action(
        container,
      ).removeManaged(_managed('m1', attached: true));

      expect(notice, TailscaleManagedNotice.removeIncomplete);
      verifyNever(() => core.forgetTailscaleRoutes(any()));
      expect(records(container).single.removing, isTrue);
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

      final outcome = await action(container).unlinkProfile(
        42,
        () => container.read(profilesProvider.notifier).del(42),
      );

      expect(outcome, TailscaleUnlinkOutcome.done);
      verify(() => core.forgetTailscaleRoutes(42)).called(1);
      expect(records(container).single.id, 'm9');
      expect(container.read(profilesProvider), isEmpty);
    });
  });

  group('unreadable records', () {
    test('send the unknown marker and block deleting the profile', () async {
      final container = build(records: null);

      final setup = container.read(tailscaleSetupProvider)!;
      expect(setup.managedUnknown, isTrue);
      expect(setup.managed, isEmpty);
      expect(setup.toJson(), containsPair('managed-unknown', true));
      expect(action(container).hasPendingManaged(42), isTrue);
      expect(
        await action(container).unlinkProfile(42, () async => fail('deleted')),
        TailscaleUnlinkOutcome.pending,
      );
      verifyNever(() => core.forgetTailscaleRoutes(any()));
    });

    test('readable ones do not', () {
      final container = build();
      expect(container.read(tailscaleSetupProvider)!.managedUnknown, isFalse);
    });
  });

  group('names', () {
    test('each draft keeps a name of its own, sent with the setup', () async {
      final container = build(
        records: const [
          TailscaleManagedRecord(id: 'm1', profileId: 42, name: 'Tailscale'),
          TailscaleManagedRecord(id: 'm9', profileId: 7, name: 'Tailscale 2'),
        ],
      );
      when(() => core.getTailscaleNodes()).thenAnswer((_) async => const []);

      await action(container).addManaged(newProfileLabel: 'x');

      final added = records(container).last;
      expect(added.name, 'Tailscale 2');
      expect(
        container.read(tailscaleSetupProvider)!.managed.map((m) => m.name),
        ['Tailscale', 'Tailscale 2'],
      );
    });
  });

  group('drafts', () {
    test('opening the panel only reads an unattached draft', () async {
      final container = build(
        records: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
      );
      when(
        () => core.getTailscaleStatus(any()),
      ).thenAnswer((_) async => TailscaleStatus(node: _managed('m1')));

      await action(container).prewarm(_managed('m1'));

      verifyNever(() => core.startTailscale(any()));
      verify(() => core.getTailscaleStatus(any())).called(1);
    });

    test('only a sign-in tap marks a draft to attach, and an attach clears '
        'the mark', () async {
      final container = build(
        records: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
      );
      expect(panelOf(container, 'm1').signInTapped, isFalse);
      when(
        () => core.loginTailscale(any(), reauth: any(named: 'reauth')),
      ).thenAnswer(
        (_) async => const TailscaleLoginResult(
          generation: 1,
          state: TailscaleBackendState.running,
        ),
      );
      when(
        () => core.getTailscaleNodes(),
      ).thenAnswer((_) async => [_managed('m1')]);
      when(
        () => core.getTailscaleStatus(any()),
      ).thenAnswer((_) async => TailscaleStatus(node: _managed('m1')));

      await action(container).loginFromPanel(_managed('m1'));
      expect(panelOf(container, 'm1').signInTapped, isTrue);

      await action(container).attachManaged(_managed('m1'), [_managed('m1')]);
      expect(panelOf(container, 'm1').signInTapped, isFalse);
    });
  });

  group('duplicates', () {
    test('a signed-out entry still counts by the identity it attached '
        'with', () async {
      final container = build(
        records: const [
          TailscaleManagedRecord(
            id: 'm1',
            profileId: 42,
            attached: true,
            loggedOut: true,
            account: _account,
          ),
          TailscaleManagedRecord(id: 'm2', profileId: 42),
        ],
      );
      final nodes = [
        _managed('m1', attached: true, account: null),
        _managed('m2'),
      ];

      expect(
        await action(container).attachManaged(nodes[1], nodes),
        TailscaleAttachState.duplicate,
      );
      expect(_FakeSetupAction.applied, 0);
    });

    test('a renamed network is the same one; another domain is not', () {
      const before = TailscaleAccount(
        userId: 'u1',
        tailnet: 'Old name',
        tailnetId: 'example.ts.net',
      );
      expect(before.sameAs(before.copyWith(tailnet: 'New name')), isTrue);
      expect(
        before.sameAs(before.copyWith(tailnetId: 'other.ts.net')),
        isFalse,
      );
    });

    test('an attach stores the identity it attached with', () async {
      final container = build(
        records: const [TailscaleManagedRecord(id: 'm1', profileId: 42)],
      );
      when(
        () => core.getTailscaleNodes(),
      ).thenAnswer((_) async => [_managed('m1', attached: true)]);

      await action(container).attachManaged(_managed('m1'), [_managed('m1')]);

      expect(records(container).single.account, _account);
      expect(
        (await _stored()).single,
        containsPair('account', containsPair('user-id', 'u1')),
      );
    });
  });

  group('deleting a profile', () {
    const record = TailscaleManagedRecord(
      id: 'm1',
      profileId: 42,
      attached: true,
    );

    test('waits for an unknown attach, sign-out or login', () {
      final container = build(records: const [record]);
      final key = tailscaleManagedNodeKey(42, 'm1');
      expect(action(container).hasPendingManaged(42), isFalse);

      container
          .read(tailscaleManagedPanelsProvider.notifier)
          .change(
            key,
            (state) => state.copyWith(attach: TailscaleAttachState.unknown),
          );
      expect(action(container).hasPendingManaged(42), isTrue);
      container
          .read(tailscaleManagedPanelsProvider.notifier)
          .change(key, (_) => const TailscaleManagedPanel());

      final panels = container.read(tailscalePanelNodesProvider.notifier);
      panels.change(key, (state) => state.copyWith(unconfirmed: true));
      expect(
        action(container).hasPendingManaged(42),
        isTrue,
        reason: 'an unknown plain sign-out',
      );
      panels.change(
        key,
        (state) => state.copyWith(unconfirmed: false, loggingIn: true),
      );
      expect(
        action(container).hasPendingManaged(42),
        isTrue,
        reason: 'a pending login',
      );
      expect(action(container).hasPendingManaged(7), isFalse);
    });

    test('waits for an add in progress', () async {
      final container = build();
      when(() => core.getTailscaleNodes()).thenAnswer((_) async {
        expect(action(container).hasPendingManaged(42), isTrue);
        return const [];
      });

      await action(container).addManaged(newProfileLabel: 'x');

      verify(() => core.getTailscaleNodes()).called(1);
    });

    Future<void> keep() async => fail('the profile must stay');

    void forgetAnswers(String outcome) {
      when(
        () => core.forgetTailscaleRoutes(42),
      ).thenAnswer((_) async => TailscaleForgetResult(outcome: outcome));
    }

    const kept = TailscaleManagedState(
      profileId: 42,
      routes: 'kept',
      digest: 'd1',
      running: true,
      protection: 'active',
    );
    const forgotten = TailscaleManagedState(
      profileId: 42,
      routes: 'absent',
      running: true,
      forgotten: true,
      protection: 'active',
    );
    const partial = {
      'pins moved': TailscaleManagedState(
        profileId: 42,
        routes: 'kept',
        digest: 'd2',
        running: true,
        protection: 'active',
      ),
      'file gone, memory kept': TailscaleManagedState(
        profileId: 42,
        routes: 'absent',
        running: true,
        protection: 'active',
      ),
      'file kept, memory forgotten': TailscaleManagedState(
        profileId: 42,
        routes: 'kept',
        digest: 'd1',
        running: true,
        forgotten: true,
        protection: 'active',
      ),
      'a write on its way': TailscaleManagedState(
        profileId: 42,
        routes: 'absent',
        running: true,
        forgotten: true,
        pending: true,
        protection: 'active',
      ),
      'REJECT rules off': TailscaleManagedState(
        profileId: 42,
        routes: 'absent',
        running: true,
        forgotten: true,
        protection: 'off',
      ),
      'unreadable': TailscaleManagedState(
        profileId: 42,
        routes: 'unreadable',
        running: true,
        protection: 'active',
      ),
      'another profile': TailscaleManagedState(
        profileId: 43,
        routes: 'absent',
        protection: 'none',
      ),
    };

    void stateAnswers(List<Object> answers) {
      when(() => core.getTailscaleManagedState(42)).thenAnswer((_) async {
        final next = answers.length > 1 ? answers.removeAt(0) : answers.first;
        if (next is TailscaleManagedState) {
          return next;
        }
        throw next as Exception;
      });
    }

    const timeout = CoreMethodException(code: 'timeout', message: 'x');

    Future<TailscaleUnlinkOutcome> recheck(
      ProviderContainer container, [
      TailscaleUnlinkOutcome open = TailscaleUnlinkOutcome.unconfirmed,
    ]) => action(container).recheckUnlink(42, open: open);

    Future<ProviderContainer> unanswered() async {
      final container = build(records: const [record]);
      stateAnswers([kept]);
      when(() => core.forgetTailscaleRoutes(42)).thenThrow(timeout);
      expect(
        await container.read(profilesActionProvider.notifier).deleteProfile(42),
        TailscaleUnlinkOutcome.unconfirmed,
      );
      return container;
    }

    test('a failed read before the unlink changes nothing', () async {
      final container = build(records: const [record]);
      stateAnswers([timeout]);

      expect(
        await action(container).unlinkProfile(42, keep),
        TailscaleUnlinkOutcome.failed,
      );
      expect(records(container), const [record]);
      verifyNever(() => core.forgetTailscaleRoutes(any()));
    });

    test('a refused forget is retryable once a read shows the state it '
        'started from', () async {
      final container = build(records: const [record]);
      stateAnswers([kept]);
      forgetAnswers('failed');

      expect(
        await container.read(profilesActionProvider.notifier).deleteProfile(42),
        TailscaleUnlinkOutcome.failed,
      );

      expect(records(container), const [record]);
      expect((await _stored()).single, containsPair('unlinking', false));
      expect(action(container).hasPendingManaged(42), isFalse);
      expect(container.read(profilesProvider).single.id, 42);
    });

    test(
      'a refused forget that left a partial state stays unconfirmed',
      () async {
        final container = build(records: const [record]);
        stateAnswers([kept, partial['pins moved']!]);
        forgetAnswers('failed');

        expect(
          await action(container).unlinkProfile(42, keep),
          TailscaleUnlinkOutcome.unconfirmed,
        );
        expect(records(container).single.unlinking, isTrue);
        expect(action(container).hasPendingManaged(42), isTrue);
      },
    );

    test('the mark records the profile, the operation and its start', () async {
      final container = await unanswered();

      final mark = records(container).single.unlink!;
      expect(mark.profileId, 42);
      expect(mark.operation, isNotEmpty);
      expect(mark.before, 'kept:d1');
      expect(
        (await _stored()).single,
        containsPair('unlink', containsPair('operation', mark.operation)),
      );
      expect(
        await action(container).unlinkProfile(42, keep),
        TailscaleUnlinkOutcome.pending,
      );
      verify(() => core.forgetTailscaleRoutes(42)).called(1);
    });

    for (final MapEntry(:key, :value) in partial.entries) {
      test('a kept profile with $key stays unconfirmed', () async {
        final container = await unanswered();
        stateAnswers([value]);

        expect(await recheck(container), TailscaleUnlinkOutcome.unconfirmed);
        expect(records(container).single.unlinking, isTrue);
        expect(action(container).hasPendingManaged(42), isTrue);
      });
    }

    test('a failed read keeps the lock', () async {
      final container = await unanswered();
      stateAnswers([timeout]);

      expect(await recheck(container), TailscaleUnlinkOutcome.unconfirmed);
      expect(await recheck(container), TailscaleUnlinkOutcome.unconfirmed);
      expect(action(container).hasPendingManaged(42), isTrue);
      verify(() => core.getTailscaleManagedState(42)).called(3);
    });

    test('a kept profile wholly before the unlink may be retried', () async {
      final container = await unanswered();
      container
          .read(profilesProvider.notifier)
          .put(
            const Profile(id: 43, label: '', autoUpdateDuration: Duration.zero),
          );

      expect(await recheck(container), TailscaleUnlinkOutcome.failed);
      expect(records(container).single.unlinking, isFalse);
      expect(records(container).single.unlink, isNull);
      expect(action(container).hasPendingManaged(42), isFalse);
      verifyNever(() => core.forgetTailscaleRoutes(43));
    });

    test('a kept profile wholly after the unlink may be retried, which '
        'deletes it', () async {
      final container = await unanswered();
      stateAnswers([forgotten]);

      expect(await recheck(container), TailscaleUnlinkOutcome.failed);
      expect(records(container).single.unlinking, isFalse);
      expect(container.read(profilesProvider).single.id, 42);

      forgetAnswers('confirmed');
      expect(
        await action(container).unlinkProfile(
          42,
          () => container.read(profilesProvider.notifier).del(42),
        ),
        TailscaleUnlinkOutcome.done,
      );
      expect(records(container), isEmpty);
      expect(container.read(profilesProvider), isEmpty);
    });

    test(
      'marks of another operation are proven only by a finished forget',
      () async {
        final container = await unanswered();
        final stray = records(container).single.copyWith(
          id: 'm2',
          unlink: const TailscaleUnlinkMark(
            operation: 'other',
            profileId: 42,
            before: 'kept:d1',
          ),
        );
        await container
            .read(tailscaleManagedRecordsProvider.notifier)
            .modify((records) => [...records, stray]);

        expect(await recheck(container), TailscaleUnlinkOutcome.unconfirmed);
        expect(action(container).hasPendingManaged(42), isTrue);

        stateAnswers([forgotten]);
        expect(await recheck(container), TailscaleUnlinkOutcome.failed);
      },
    );

    test(
      'a deleted profile keeps its records until the forget is proven',
      () async {
        final container = build(records: const [record]);
        stateAnswers([kept]);
        forgetAnswers('confirmed');

        expect(
          await action(
            container,
          ).unlinkProfile(42, () async => throw StateError('disk')),
          TailscaleUnlinkOutcome.deleteUnconfirmed,
        );
        expect(records(container).single.unlinking, isTrue);

        await container.read(profilesProvider.notifier).del(42);
        for (final state in [timeout, kept, ...partial.values]) {
          stateAnswers([state]);
          expect(
            await recheck(container, TailscaleUnlinkOutcome.deleteUnconfirmed),
            TailscaleUnlinkOutcome.deleteUnconfirmed,
            reason: '$state',
          );
          expect(records(container).single.unlinking, isTrue);
          expect(action(container).hasPendingManaged(42), isTrue);
        }

        stateAnswers([forgotten]);
        expect(
          await recheck(container, TailscaleUnlinkOutcome.deleteUnconfirmed),
          TailscaleUnlinkOutcome.done,
        );
        expect(records(container), isEmpty);
      },
    );

    test('a deleted profile the Core no longer runs drops its records once '
        'its routing is gone', () async {
      final container = await unanswered();
      await container.read(profilesProvider.notifier).del(42);
      stateAnswers([
        const TailscaleManagedState(
          profileId: 42,
          routes: 'absent',
          protection: 'none',
        ),
      ]);

      expect(await recheck(container), TailscaleUnlinkOutcome.done);
      expect(records(container), isEmpty);
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
    expect(setup.managedUnknown, isFalse);
  });
}
