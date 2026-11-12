import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations zh;
  setUp(() async => zh = await AppLocalizations.load(const Locale('zh', 'CN')));

  const yaml =
      'mode: rule\n'
      'proxies:\n'
      '  - {name: HK 01, type: socks5, server: 127.0.0.1, port: 1}\n'
      'rules:\n'
      '  - DOMAIN-SUFFIX,local,DIRECT\n'
      '  - MATCH,DIRECT\n';
  const setup = TailscaleSetup(
    profileId: 7,
    configSource: TailscaleSettingSource.profile,
    managed: [TailscaleManagedSetup(id: 'a1', attached: true)],
  );
  const node = 'Tailscale (Flash)';
  const rules = [
    'DOMAIN,nas.tail1.ts.net,$node',
    'DOMAIN-SUFFIX,tail1.ts.net,$node',
    'DOMAIN-SUFFIX,ts.net,REJECT',
    'IP-CIDR,100.101.1.1/32,$node',
    'IP-CIDR,100.64.0.0/10,REJECT',
    'IP-CIDR6,fd7a:115c:a1e0::/48,REJECT',
  ];
  TailscaleRuntimeRules runtime({
    TailscaleRuntimeState state = TailscaleRuntimeState.confirmed,
    String? revision,
  }) => TailscaleRuntimeRules(
    profileId: 7,
    state: state,
    revision: revision ?? tailscaleRuntimeRevisionOf(setup),
    accounts: const [
      TailscaleRuntimeAccount(id: 'a1', node: node, rules: rules),
    ],
    proxies: const [node],
  );
  String strip(String text) =>
      text.replaceAll(RegExp(r'^ *#.*\n', multiLine: true), '');

  test('the revision is the digest the Core keeps', () {
    expect(
      tailscaleRuntimeRevisionOf(setup),
      '024e57560caeb2e40431dddf60c6336a',
    );
  });

  test('a confirmed run lists each account\'s rules and its node', () {
    final text = annotateTailscaleRuntime(yaml, runtime(), setup, zh);
    expect(
      text,
      contains(
        'proxies:\n'
        '  # Tailscale · 由 Flash 添加 · 节点 Tailscale (Flash)\n'
        '  - {name: HK 01',
      ),
    );
    expect(
      text,
      contains(
        'rules:\n'
        '  # Tailscale · 由 Flash 添加 · 6 条规则 → 节点 Tailscale (Flash)\n'
        '  #   - DOMAIN,nas.tail1.ts.net,Tailscale (Flash)\n'
        '  #   - DOMAIN-SUFFIX,tail1.ts.net,Tailscale (Flash)\n'
        '  #   - DOMAIN-SUFFIX,ts.net,REJECT\n'
        '  #   - IP-CIDR,100.101.1.1/32,Tailscale (Flash)\n'
        '  #   - IP-CIDR,100.64.0.0/10,REJECT\n'
        '  #   - IP-CIDR6,fd7a:115c:a1e0::/48,REJECT\n'
        '  - DOMAIN-SUFFIX,local,DIRECT\n',
      ),
    );
    expect(strip(text), yaml);
    final found = text.split('\n').where((line) => line.contains('ts.net'));
    expect(found, contains('  #   - DOMAIN-SUFFIX,ts.net,REJECT'));
  });

  test('English counts one rule and many', () async {
    final en = await AppLocalizations.load(const Locale('en'));
    final one = TailscaleRuntimeRules(
      profileId: 7,
      state: TailscaleRuntimeState.confirmed,
      revision: tailscaleRuntimeRevisionOf(setup),
      accounts: const [
        TailscaleRuntimeAccount(
          id: 'a1',
          node: node,
          rules: ['DOMAIN-SUFFIX,ts.net,REJECT'],
        ),
      ],
    );
    expect(
      annotateTailscaleRuntime(yaml, one, setup, en),
      contains('# Tailscale · Added by Flash · 1 rule → Node $node\n'),
    );
    expect(
      annotateTailscaleRuntime(yaml, runtime(), setup, en),
      contains('# Tailscale · Added by Flash · 6 rules → Node $node\n'),
    );
  });

  test('an unconfirmed or another revision names nothing', () {
    for (final state in [
      runtime(state: TailscaleRuntimeState.unconfirmed),
      runtime(revision: 'older'),
    ]) {
      final text = annotateTailscaleRuntime(yaml, state, setup, zh);
      expect(
        text,
        contains('rules:\n  # Tailscale · 当前运行的规则和节点待确认\n  - DOMAIN'),
      );
      expect(text, isNot(contains(node)));
      expect(text, isNot(contains('ts.net')));
      expect(text, isNot(contains('条规则')));
      expect(strip(text), yaml);
    }
  });

  test('a failed read says so, without names', () {
    final text = annotateTailscaleRuntime(
      yaml,
      const TailscaleRuntimeRules.readFailed(7),
      setup,
      zh,
    );
    expect(text, contains('rules:\n  # Tailscale · 运行信息读取失败\n'));
    expect(text, isNot(contains(node)));
    expect(strip(text), yaml);
  });

  test('no attached account adds nothing', () {
    for (final state in [
      TailscaleRuntimeState.none,
      TailscaleRuntimeState.otherProfile,
    ]) {
      final text = annotateTailscaleRuntime(
        yaml,
        TailscaleRuntimeRules(profileId: 7, state: state),
        setup,
        zh,
      );
      expect(text, yaml);
    }
  });

  test('flow sections get the notes on the next lines', () {
    const flow = 'proxies: []\nrules: [MATCH,DIRECT]\n';
    final text = annotateTailscaleRuntime(flow, runtime(), setup, zh);
    expect(text, startsWith('proxies: []\n# Tailscale · 由 Flash 添加 · 节点'));
    expect(text, contains('rules: [MATCH,DIRECT]\n# Tailscale · 由 Flash 添加'));
  });

  test('the Core reply parses', () {
    final parsed = TailscaleRuntimeRules.fromJson({
      'profile-id': 7,
      'state': 'confirmed',
      'revision': 'r',
      'accounts': [
        {
          'id': 'a1',
          'node': node,
          'rules': ['DOMAIN-SUFFIX,ts.net,REJECT'],
        },
      ],
      'proxies': [node],
    });
    expect(parsed.state, TailscaleRuntimeState.confirmed);
    expect(parsed.accounts.single.rules, ['DOMAIN-SUFFIX,ts.net,REJECT']);
    expect(
      TailscaleRuntimeRules.fromJson({'state': 'other-profile'}).state,
      TailscaleRuntimeState.otherProfile,
    );
  });
}
