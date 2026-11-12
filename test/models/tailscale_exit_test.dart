import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Core's reply for a profile shaped like a regional subscription; every
/// name is made up.
const exitReply = {
  'profile-id': 7,
  'state': 'confirmed',
  'group': 'Tailscale 出口',
  'selected': 'a1',
  'parents': [
    {
      'name': '国际媒体',
      'now': 'Tailscale 出口',
      'members': ['香港策略', '美国策略', 'DIRECT', 'Tailscale 出口'],
      'replacement': '香港策略',
    },
    {
      'name': '仅日本',
      'now': 'Tailscale 出口',
      'members': ['COMPATIBLE', 'Tailscale 出口'],
    },
    {
      'name': '全球手动',
      'now': 'HK 01',
      'members': ['HK 01', 'Tailscale 出口'],
      'replacement': 'HK 01',
    },
  ],
  'accounts': [
    {
      'id': 'a1',
      'member': 'nas-sg · pat@example.test',
      'exit-node': '100.88.12.4',
      'state': 'unavailable',
      'reason': 'offline',
    },
  ],
};

void main() {
  late AppLocalizations zh;
  setUp(() async => zh = await AppLocalizations.load(const Locale('zh', 'CN')));

  final report = TailscaleExitReport.fromJson(exitReply);

  test('the Core reply parses', () {
    expect(report.offered, isTrue);
    expect(report.parents.map((parent) => parent.name), [
      '国际媒体',
      '仅日本',
      '全球手动',
    ]);
    expect(report.parents[1].replacement, isNull);
    final account = report.accountOf('a1')!;
    expect(account.state, TailscaleExitState.unavailable);
    expect(account.reason, TailscaleExitReason.offline);
    expect(report.memberNamed('nas-sg · pat@example.test')?.id, 'a1');
  });

  test('only groups using the exit group are affected by turning it off', () {
    expect(report.affectedWithout('a1').map((parent) => parent.name), [
      '国际媒体',
      '仅日本',
    ]);
  });

  test('another account keeping an exit node leaves every group alone', () {
    final shared = TailscaleExitReport.fromJson({
      ...exitReply,
      'accounts': [
        ...exitReply['accounts']! as List,
        {
          'id': 'b2',
          'member': 'office-hk · pat@work.test',
          'exit-node': '100.72.40.9',
          'state': 'applied',
        },
      ],
    });
    expect(shared.affectedWithout('a1'), isEmpty);
    expect(shared.affectedWithout('c3'), isEmpty);
  });

  test('an unconfirmed read affects nothing it cannot name', () {
    final unconfirmed = TailscaleExitReport.fromJson({
      ...exitReply,
      'state': 'unconfirmed',
    });
    expect(unconfirmed.offered, isFalse);
    expect(unconfirmed.affectedWithout('a1'), isEmpty);
  });

  test('a proxy card knows the exit group and its nodes', () {
    expect(report.cardOf('nas-sg · pat@example.test'), (
      node: true,
      unavailable: true,
    ));
    expect(report.cardOf('Tailscale 出口'), (node: false, unavailable: true));
    expect(report.cardOf('HK 01'), isNull);
    expect(const TailscaleExitReport.readFailed(7).cardOf('x'), isNull);
  });

  test('the node is named by device then account', () {
    const record = TailscaleManagedRecord(
      id: 'a1',
      profileId: 7,
      attached: true,
      exitNode: '100.88.12.4',
      exitNodeName: 'nas-sg',
      account: TailscaleAccount(
        loginName: 'pat@example.test',
        displayName: 'Pat',
      ),
    );
    expect(record.setup.exitLabel, 'nas-sg · pat@example.test');
    expect(
      record.copyWith(exitNodeName: null, account: null).setup.exitLabel,
      '100.88.12.4 · a1',
    );
    expect(record.copyWith(exitNode: '').setup.exitLabel, isNull);
    expect(record.setup.toJson()['exit-label'], 'nas-sg · pat@example.test');
  });

  group('runtime viewer', () {
    const yaml =
        'proxies:\n'
        '  - {name: HK 01, type: socks5, server: 127.0.0.1, port: 1}\n'
        'proxy-groups:\n'
        '  - {name: 国际媒体, type: select, proxies: [HK 01]}\n'
        'rules:\n'
        '  - MATCH,国际媒体\n';

    test('a confirmed group names its node and the manual groups', () {
      expect(
        annotateTailscaleExit(yaml, report, zh),
        contains(
          'proxy-groups:\n'
          '  # Tailscale 出口 · 由 Flash 添加 · nas-sg · pat@example.test · '
          '手动策略组：国际媒体、仅日本、全球手动\n'
          '  - {name: 国际媒体',
        ),
      );
    });

    test('an unconfirmed group names nothing', () {
      final text = annotateTailscaleExit(
        yaml,
        TailscaleExitReport.fromJson({...exitReply, 'state': 'unconfirmed'}),
        zh,
      );
      expect(text, contains('  # Tailscale 出口 · 当前运行的出口和分组待确认\n'));
      expect(text, isNot(contains('nas-sg')));
    });

    test('no group or another profile adds nothing', () {
      for (final state in ['none', 'other-profile']) {
        final none = TailscaleExitReport.fromJson({
          'profile-id': 7,
          'state': state,
        });
        expect(annotateTailscaleExit(yaml, none, zh), yaml);
      }
      final empty = TailscaleExitReport.fromJson({
        'profile-id': 7,
        'state': 'confirmed',
      });
      expect(annotateTailscaleExit(yaml, empty, zh), yaml);
    });

    test('a failed read says so once', () {
      const failed = TailscaleExitReport.readFailed(7);
      final once = annotateTailscaleExit(yaml, failed, zh);
      expect(once, contains('# Tailscale · 运行信息读取失败'));
      expect(annotateTailscaleExit(once, failed, zh), once);
    });
  });
}
