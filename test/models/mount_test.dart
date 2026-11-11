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
}
