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
}
