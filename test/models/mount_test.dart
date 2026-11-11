import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Core mount report reads with its wire names', () {
    final state = MountRuntimeState.fromJson({
      'blocked': false,
      'report': {
        'revision': 'r1',
        'sources': [
          {
            'id': 2,
            'provider': 'flash-mount-2',
            'status': 'read-error',
            'tailscale-excluded': 1,
            'nodes': [
              {'name': 'HK (Air)', 'original': 'HK'},
            ],
          },
        ],
        'groups': [
          {
            'name': 'Proxy',
            'via': 'use',
            'protection': 'reject',
            'empty-fallback': 'REJECT',
          },
        ],
        'renamed': 1,
      },
      'sources': [
        {
          'id': 2,
          'provider': 'flash-mount-2',
          'present': true,
          'count': 1,
          'matches': true,
        },
      ],
      'groups': [
        {
          'name': 'Proxy',
          'present': true,
          'members': 3,
          'mounted': 1,
          'empty': false,
        },
      ],
    });

    final source = state.report!.sources.single;
    expect(source.status, MountSourceStatus.readError);
    expect(source.tailscaleExcluded, 1);
    expect(source.nodes.single.original, 'HK');
    expect(state.report!.groups.single.via, MountGroupVia.use);
    expect(state.report!.groups.single.protection, MountProtection.reject);
    expect(state.sources.single.matches, isTrue);
    expect(state.groups.single.mounted, 1);
  });

  test('a target group reads every optional flag', () {
    final group = MountGroupInfo.fromJson({
      'name': 'Auto',
      'type': 'url-test',
      'kind': 'auto',
      'collects': 'providers',
      'exclude-filter': true,
      'probe': 'unknown',
      'empty-fallback': 'DIRECT',
    });

    expect(group.kind, MountGroupKind.auto);
    expect(group.collects, MountGroupCollects.providers);
    expect(group.excludeFilter, isTrue);
    expect(group.filter, isFalse);
    expect(group.probe, MountGroupProbe.unknown);
    expect(group.emptyFallback, 'DIRECT');
  });

  test('setup params carry mounts only when there are some', () {
    const options = CoreOptions(testUrl: 'https://example.invalid');
    expect(
      const SetupParams(selectedMap: {}, options: options).toJson(),
      isNot(contains('mounts')),
    );
    final json = const SetupParams(
      selectedMap: {},
      options: options,
      mounts: MountSetup(
        target: 1,
        revision: 'r',
        sources: [MountSource(id: 2, label: 'Air', path: '/p/2.yaml')],
        groups: ['Proxy'],
      ),
    ).toJson();
    expect((json['mounts'] as MountSetup).toJson()['groups'], ['Proxy']);
  });

  test('a pending operation round-trips through JSON', () {
    const operation = MountOperation(
      kind: MountOperationKind.deleteSource,
      version: 3,
      sourceIds: [2],
    );
    expect(MountOperation.fromJson(operation.toJson()), operation);
    expect(mountProviderName(2), 'flash-mount-2');
  });

  test('a mount setup follows the relation and every source update', () {
    final updated = DateTime(2026, 1, 1);
    final profiles = [
      Profile(
        id: 2,
        label: 'Air',
        type: ProfileType.url,
        url: 'https://example.invalid/a',
        autoUpdateDuration: Duration.zero,
        lastUpdateDate: updated,
      ),
      const Profile(id: 3, label: 'Local', autoUpdateDuration: Duration.zero),
    ];
    const target = MountTargetState(
      targetId: 1,
      sourceIds: [2, 3, 9],
      groups: ['Proxy'],
      version: 4,
    );

    final setup = mountSetupOf(target, profiles, '/profiles');

    expect(setup.sources, [
      const MountSource(id: 2, label: 'Air', path: '/profiles/2.yaml'),
    ]);
    expect(setup.groups, ['Proxy']);
    expect(
      mountSetupOf(target, profiles, '/profiles').revision,
      setup.revision,
    );
    final touched = [
      profiles.first.copyWith(lastUpdateDate: DateTime(2026, 1, 2)),
      profiles.last,
    ];
    expect(
      mountSetupOf(target, touched, '/profiles').revision,
      isNot(setup.revision),
    );
    expect(
      mountSetupOf(target.copyWith(version: 5), profiles, '/profiles').revision,
      isNot(setup.revision),
    );
  });

  test('only a mount rejection names an outcome', () {
    CoreMethodException rejected(Object? details) => CoreMethodException(
      code: 'mount_rejected',
      message: 'm',
      details: details,
    );
    expect(
      mountRejectedOutcome(rejected({'outcome': 'kept'})),
      MountRejectedOutcome.kept,
    );
    expect(
      mountRejectedOutcome(rejected({'outcome': 'blocked'})),
      MountRejectedOutcome.blocked,
    );
    expect(mountRejectedOutcome(rejected({'outcome': 'other'})), isNull);
    expect(
      mountRejectedOutcome(
        const CoreMethodException(code: 'config_rejected', message: 'm'),
      ),
      isNull,
    );
    expect(mountRejectedOutcome(Exception('x')), isNull);
  });

  group('mount results', () {
    const report = MountReport(
      revision: 'r2',
      sources: [
        MountSourceReport(
          id: 2,
          provider: 'flash-mount-2',
          status: MountSourceStatus.nodes,
          nodes: [MountNode(name: 'HK (Air)', original: 'HK')],
        ),
      ],
      groups: [
        MountGroupReport(
          name: 'Proxy',
          via: MountGroupVia.use,
          protection: MountProtection.reject,
        ),
      ],
    );
    const consistent = MountRuntimeState(
      report: report,
      sources: [
        MountRuntimeSource(
          id: 2,
          provider: 'flash-mount-2',
          present: true,
          count: 1,
          matches: true,
        ),
      ],
      groups: [MountRuntimeGroup(name: 'Proxy', present: true, members: 1)],
    );

    test('only a readback of the same revision proves an apply', () {
      expect(confirmMounts(consistent, 'r2'), MountSaveOutcome.applied);
      expect(confirmMounts(consistent, 'r1'), isNull);
      expect(confirmMounts(const MountRuntimeState(), 'r2'), isNull);
      expect(
        confirmMounts(consistent.copyWith(blocked: true), 'r1'),
        MountSaveOutcome.applyFailedBlocked,
      );
      expect(
        confirmMounts(consistent.copyWith(groups: const []), 'r2'),
        MountSaveOutcome.appliedUnverified,
      );
      expect(
        confirmMounts(
          consistent.copyWith(
            sources: [consistent.sources.single.copyWith(matches: false)],
          ),
          'r2',
        ),
        MountSaveOutcome.appliedUnverified,
      );
    });

    test('a source item names what its cache holds', () {
      const profile = Profile(id: 2, autoUpdateDuration: Duration.zero);
      MountSourceState stateOf(MountSourceInspection? inspection) =>
          mountSourceItem(profile, inspection).state;
      expect(stateOf(null), MountSourceState.unreadable);
      expect(
        stateOf(const MountSourceInspection(status: MountSourceStatus.missing)),
        MountSourceState.notFetched,
      );
      expect(
        stateOf(
          const MountSourceInspection(status: MountSourceStatus.unsupported),
        ),
        MountSourceState.unsupported,
      );
      expect(
        stateOf(
          const MountSourceInspection(
            status: MountSourceStatus.nodes,
            count: 3,
          ),
        ),
        MountSourceState.nodes,
      );
      expect(
        stateOf(
          const MountSourceInspection(
            status: MountSourceStatus.nodes,
            tailscaleExcluded: 1,
          ),
        ),
        MountSourceState.tailscaleOnly,
      );
      expect(
        stateOf(
          const MountSourceInspection(
            status: MountSourceStatus.nodes,
            relayExcluded: 2,
          ),
        ),
        MountSourceState.relayOnly,
      );
      expect(
        stateOf(
          const MountSourceInspection(
            status: MountSourceStatus.nodes,
            tailscaleExcluded: 1,
            relayExcluded: 1,
          ),
        ),
        MountSourceState.isolatedOnly,
      );
      expect(
        stateOf(
          const MountSourceInspection(
            status: MountSourceStatus.nodes,
            count: 1,
            relayExcluded: 1,
          ),
        ),
        MountSourceState.nodes,
      );
      expect(
        stateOf(const MountSourceInspection(status: MountSourceStatus.nodes)),
        MountSourceState.empty,
      );
    });

    test('a source with nothing ordinary left cannot be newly mounted', () {
      expect(
        [
          for (final state in MountSourceState.values)
            if (!state.mountable) state,
        ],
        [
          MountSourceState.tailscaleOnly,
          MountSourceState.relayOnly,
          MountSourceState.isolatedOnly,
          MountSourceState.unsupported,
        ],
      );
    });

    test('the card counts only failures no later update cleared', () {
      const target = MountTargetState(
        targetId: 1,
        sourceIds: [2, 3, 4],
        groups: ['Proxy'],
        version: 1,
      );
      final summary = mountCardSummaryOf(target, {
        2: const MountSourceRecord(
          sourceId: 2,
          failure: MountSourceFailure.fetch,
        ),
        3: MountSourceRecord(sourceId: 3, succeededAt: DateTime(2026)),
        9: const MountSourceRecord(
          sourceId: 9,
          failure: MountSourceFailure.unsupported,
        ),
      });
      expect(summary, const MountCardSummary(mounted: 3, failed: 1));
      expect(mountCardSummaryOf(null, const {}), isNull);
      expect(
        mountCardSummaryOf(target.copyWith(sourceIds: const []), const {}),
        isNull,
      );
    });
  });
}
