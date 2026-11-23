import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Core mount report reads with its wire names', () {
    final state = MountRuntimeState.fromJson({
      'blocked': false,
      'refused': ['lan', 'sub'],
      'report': {
        'revision': 'r1',
        'sources': [
          {
            'id': 2,
            'provider': 'flash-mount-2',
            'status': 'read-error',
            'tailscale-excluded': 1,
            'unsupported-excluded': 2,
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
    expect(source.unsupportedExcluded, 2);
    expect(state.refused, ['lan', 'sub']);
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
    expect(group.reason, isNull);
  });

  test('a group left out for Tailscale reads why', () {
    for (final (wire, reason) in [
      ('holds', MountGroupReason.holds),
      ('provider-unknown', MountGroupReason.providerUnknown),
      ('rule', MountGroupReason.rule),
      ('rule-unknown', MountGroupReason.ruleUnknown),
      ('member', MountGroupReason.member),
      ('carrier', MountGroupReason.carrier),
      ('global', MountGroupReason.global),
      ('dns', MountGroupReason.dns),
      ('dialer', MountGroupReason.dialer),
      ('later', null),
    ]) {
      final group = MountGroupInfo.fromJson({
        'name': 'Lan',
        'type': 'select',
        'kind': 'excluded',
        'excluded': 'tailscale',
        'reason': wire,
      });
      expect(group.excluded, MountGroupExclusion.tailscale);
      expect(group.reason, reason, reason: wire);
    }
  });

  test('excluded groups map to three isolations, each group once', () {
    MountGroupInfo isolated(String name, MountGroupReason? reason) =>
        MountGroupInfo(
          name: name,
          type: 'select',
          kind: MountGroupKind.excluded,
          excluded: MountGroupExclusion.tailscale,
          reason: reason,
        );
    for (final reason in MountGroupReason.values) {
      expect(reason.isolation, switch (reason) {
        MountGroupReason.dialer => MountGroupIsolation.dialer,
        MountGroupReason.providerUnknown ||
        MountGroupReason.ruleUnknown => MountGroupIsolation.unknown,
        _ => MountGroupIsolation.traffic,
      }, reason: reason.name);
    }
    final target = MountTarget(
      groups: [
        isolated('Lan', MountGroupReason.holds),
        isolated('Dns', MountGroupReason.dns),
        isolated('Hop', MountGroupReason.dialer),
        isolated('Set', MountGroupReason.ruleUnknown),
        isolated('Later', null),
        isolated('Lan', MountGroupReason.rule),
        const MountGroupInfo(
          name: 'Hidden',
          type: 'select',
          kind: MountGroupKind.excluded,
          excluded: MountGroupExclusion.builtin,
        ),
        const MountGroupInfo(
          name: 'Auto',
          type: 'select',
          kind: MountGroupKind.auto,
        ),
      ],
    );
    final groups = mountIsolatedGroups(target);
    expect(groups.map((group) => group.name), [
      'Lan',
      'Dns',
      'Hop',
      'Set',
      'Later',
    ]);
    expect(mountIsolationCounts(groups), {
      MountGroupIsolation.traffic: 2,
      MountGroupIsolation.dialer: 1,
      MountGroupIsolation.unknown: 2,
    });
    expect(mountIsolatedGroups(null), isEmpty);
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
      ),
    ).toJson();
    expect((json['mounts'] as MountSetup).toJson(), isNot(contains('groups')));
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
      version: 4,
    );

    final setup = mountSetupOf(target, profiles, '/profiles');

    expect(setup.sources, [
      const MountSource(id: 2, label: 'Air', path: '/profiles/2.yaml'),
    ]);
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

    test('a skipped source is reported, not required to have loaded', () {
      const skipped = MountSourceReport(
        id: 5,
        provider: 'flash-mount-5',
        status: MountSourceStatus.missing,
      );
      final withSkip = consistent.copyWith(
        report: report.copyWith(sources: [...report.sources, skipped]),
      );
      expect(confirmMounts(withSkip, 'r2'), MountSaveOutcome.applied);
      expect(mountSkipsOf(withSkip.report!), [
        (sourceId: 5, status: MountSourceStatus.missing),
      ]);
      expect(mountSkipsOf(report), isEmpty);
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
            unsupportedExcluded: 2,
          ),
        ),
        MountSourceState.isolatedOnly,
      );
      expect(
        stateOf(
          const MountSourceInspection(
            status: MountSourceStatus.nodes,
            relayExcluded: 1,
            unsupportedExcluded: 1,
          ),
        ),
        MountSourceState.isolatedOnly,
      );
      expect(
        mountSourceItem(
          profile,
          const MountSourceInspection(
            status: MountSourceStatus.nodes,
            count: 1,
            unsupportedExcluded: 2,
          ),
        ).unsupportedExcluded,
        2,
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
          MountSourceState.pending,
          MountSourceState.tailscaleOnly,
          MountSourceState.relayOnly,
          MountSourceState.isolatedOnly,
          MountSourceState.notFetched,
          MountSourceState.unsupported,
          MountSourceState.unreadable,
        ],
      );
      expect(
        [
          for (final state in MountSourceState.values)
            if (state.fetched) state,
        ],
        [MountSourceState.nodes, MountSourceState.empty],
      );
    });

    test('the card counts only failures no later update cleared', () {
      const target = MountTargetState(
        targetId: 1,
        sourceIds: [2, 3, 4],
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

  group('the viewer notes', () {
    late AppLocalizations l10n;
    setUpAll(() async => l10n = loadAppLocalizations(const Locale('zh', 'CN')));

    const yaml = '''
proxy-providers:
  flash-mount-2:
    path: /p/2.yaml
    type: file
  flash-mount-3:
    path: /p/3.yaml
    type: file
proxy-groups:
  - {name: "Proxy", type: select, use: [flash-mount-2, flash-mount-3]}
''';
    const mounts = MountSetup(
      target: 1,
      revision: 'r2',
      sources: [
        MountSource(id: 2, label: '机场B', path: '/p/2.yaml'),
        MountSource(id: 3, label: '机场C', path: '/p/3.yaml'),
      ],
    );
    MountRuntimeState runtime({
      String revision = 'r2',
      bool blocked = false,
      bool matches = true,
    }) => MountRuntimeState(
      blocked: blocked,
      report: MountReport(
        target: 1,
        revision: revision,
        sources: const [
          MountSourceReport(
            id: 2,
            provider: 'flash-mount-2',
            status: MountSourceStatus.nodes,
            nodes: [MountNode(name: 'B-美国-01', original: 'B-美国-01')],
          ),
          MountSourceReport(
            id: 3,
            provider: 'flash-mount-3',
            status: MountSourceStatus.nodes,
            nodes: [
              MountNode(name: 'A-香港-01 (机场C)', original: 'A-香港-01'),
              MountNode(name: 'C-韩国-01', original: 'C-韩国-01'),
            ],
          ),
        ],
      ),
      sources: [
        const MountRuntimeSource(
          id: 2,
          provider: 'flash-mount-2',
          present: true,
          count: 1,
          matches: true,
        ),
        MountRuntimeSource(
          id: 3,
          provider: 'flash-mount-3',
          present: true,
          count: 2,
          matches: matches,
        ),
      ],
    );

    test('name the nodes the running revision loaded, after rename', () {
      final text = annotateMountProviders(yaml, mounts, runtime(), l10n);
      expect(
        text,
        contains(
          '  # 挂载：机场C · 2 个节点\n'
          '  #   - A-香港-01 (机场C)\n'
          '  #   - C-韩国-01\n'
          '  flash-mount-3:\n',
        ),
      );
      expect(text, contains('  # 挂载：机场B · 1 个节点\n  #   - B-美国-01\n'));
      expect(text.replaceAll(RegExp(r'^ *#.*\n', multiLine: true), ''), yaml);
    });

    test('a revision read but not applied names no nodes', () {
      final text = annotateMountProviders(
        yaml,
        mounts,
        runtime(revision: 'r1'),
        l10n,
      );
      expect(text, contains('  # 挂载：机场B · 节点列表待确认\n  flash-mount-2:\n'));
      expect(text, contains('  # 挂载：机场C · 节点列表待确认\n  flash-mount-3:\n'));
      expect(text, isNot(contains('B-美国-01')));
      expect(text, isNot(contains('C-韩国-01')));
    });

    test('a blocked run, an unread state, or a provider the Core does not '
        'hold as reported names no nodes', () {
      for (final state in [runtime(blocked: true), null]) {
        expect(
          annotateMountProviders(yaml, mounts, state, l10n),
          isNot(contains('B-美国-01')),
        );
      }
      final partial = annotateMountProviders(
        yaml,
        mounts,
        runtime(matches: false),
        l10n,
      );
      expect(partial, contains('#   - B-美国-01'));
      expect(partial, contains('# 挂载：机场C · 节点列表待确认'));
      expect(partial, isNot(contains('C-韩国-01')));
    });

    test('a flow mapping gets its notes at the head of the section', () {
      const flow =
          'proxy-providers: {flash-mount-2: {path: /p/2.yaml}, '
          'flash-mount-3: {path: /p/3.yaml}}\nrules: [MATCH,DIRECT]\n';
      final text = annotateMountProviders(flow, mounts, runtime(), l10n);
      expect(
        text,
        startsWith(
          '# 挂载：机场B · 1 个节点\n#   - B-美国-01\n'
          '# 挂载：机场C · 2 个节点\n',
        ),
      );
      expect(text, endsWith(flow));
    });

    test('only providers under proxy-providers get notes', () {
      const other =
          'proxy-providers:\n  flash-mount-2:\n    path: /p/2.yaml\n'
          'rule-providers:\n  flash-mount-3:\n    path: /r.yaml\n';
      final text = annotateMountProviders(other, mounts, runtime(), l10n);
      expect(text, contains('  #   - B-美国-01\n  flash-mount-2:\n'));
      expect(
        text,
        startsWith('# 挂载：机场C · 2 个节点\n'),
        reason: 'a source with no block entry is noted at the section head',
      );
      expect(text, contains('rule-providers:\n  flash-mount-3:\n'));
    });
  });
}
