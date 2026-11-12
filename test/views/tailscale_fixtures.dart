import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// Made-up identities only; nothing here is a real account or address.
final tsNow = DateTime.utc(2026, 11, 11, 4);

const tsProfile = Profile(
  id: 42,
  label: 'Home',
  autoUpdateDuration: Duration.zero,
);

const tsControl = 'https://controlplane.tailscale.com';

const tsSignedOutNode = TailscaleNode(
  profileId: 42,
  name: 'ts-home',
  generation: 3,
  controlUrl: tsControl,
  hostname: 'flclash-mac',
  stateDirMode: TailscaleStateDirMode.derived,
  overridable: true,
  settings: TailscaleSettings(
    acceptRoutes: TailscaleAcceptRoutesSetting(
      value: true,
      source: TailscaleSettingSource.subscription,
    ),
  ),
);

final tsConnectedNode = tsSignedOutNode.copyWith(
  started: true,
  hasIdentity: true,
  backendState: TailscaleBackendState.running,
);

const tsMe = TailscaleUser(
  id: '1001',
  loginName: 'pat@example.test',
  displayName: 'Pat Example',
);

const tsSam = TailscaleUser(
  id: '1002',
  loginName: 'sam@example.test',
  displayName: 'Sam',
);

const tsAlex = TailscaleUser(
  id: '1003',
  loginName: 'alex@example.test',
  displayName: 'Alex',
);

TailscalePeer _peer(
  String id,
  String host,
  String ip,
  String os,
  String userId, {
  bool online = true,
  bool exit = false,
  String? sharer,
  List<String> tags = const [],
}) => TailscalePeer(
  id: id,
  hostName: host,
  dnsName: '$host.example-net.test.',
  os: os,
  userId: userId,
  addresses: [ip, 'fd7a:115c:a1e0::${id.hashCode.toRadixString(16)}'],
  online: online,
  exitNodeOption: exit,
  altSharerUserId: sharer,
  tags: tags,
);

List<TailscalePeer> tsPeers({bool many = false}) => [
  _peer('n1', 'studio-mac', '100.94.68.92', 'macOS', '1002'),
  _peer('n2', 'nas-sg', '100.88.12.4', 'linux', '1002', exit: true),
  _peer('n3', 'laptop-pat', '100.101.4.22', 'macOS', '1001'),
  _peer(
    'n4',
    'office-hk',
    '100.72.40.9',
    'linux',
    '1003',
    exit: true,
    online: false,
    sharer: '1003',
  ),
  if (many) ...[
    _peer('n5', 'phone-pat', '100.90.7.31', 'iOS', '1001'),
    _peer('n6', 'build-box', '100.70.1.2', 'linux', '', tags: ['tag:ci']),
    _peer('n7', 'printer', '100.70.1.3', '', ''),
    _peer('n8', 'tv-room', '100.70.1.4', 'android', '1002', online: false),
  ],
];

TailscaleStatus tsConnectedStatus({
  TailscaleNode? node,
  DateTime? keyExpiry,
  bool manyPeers = false,
}) => TailscaleStatus(
  node: node ?? tsConnectedNode,
  haveNodeKey: true,
  self: TailscalePeer(
    id: 'self',
    hostName: 'flclash-mac',
    addresses: const ['100.101.7.58', 'fd7a:115c:a1e0::6b01:73a'],
    userId: tsMe.id,
    online: true,
    keyExpiry: keyExpiry,
  ),
  loginUser: tsMe,
  tailnet: const TailscaleTailnet(name: 'example-net.test'),
  users: {tsMe.id: tsMe, tsSam.id: tsSam, tsAlex.id: tsAlex},
  peers: tsPeers(many: manyPeers),
  prefs: const TailscalePrefs(acceptRoutes: true),
);

TailscaleNode tsLegacyNode({
  bool authKey = false,
  TailscaleLegacyEligibility eligibility = TailscaleLegacyEligibility.eligible,
  String? token = 'offer-1',
}) => tsSignedOutNode.copyWith(
  authKey: authKey,
  warnings: const [tailscaleLegacySharedStateWarning],
  legacy: TailscaleLegacyIdentity(
    loginName: 'legacy@example.test',
    displayName: 'Legacy User',
    controlUrl: tsControl,
    fingerprint: 'fp-1',
    eligibility: eligibility,
    offerToken: token,
  ),
);

TailscaleMigrateResult tsMigrateResult(
  TailscaleMigrateOutcome outcome, {
  bool targetUntouched = false,
  bool archiveIntact = true,
  TailscaleMigrateStage? stage,
  String? error,
  TailscaleNode? node,
}) => TailscaleMigrateResult(
  generation: 3,
  outcome: outcome,
  migration: const TailscaleLegacyMigration(
    fingerprint: 'fp-1',
    profileId: 42,
    name: 'ts-home',
    controlUrl: tsControl,
  ),
  node: node ?? tsLegacyNode(),
  targetUntouched: targetUntouched,
  archiveIntact: archiveIntact,
  stage: stage,
  error: error == null
      ? null
      : TailscaleError(code: 'tailscale_migrate_failed', message: error),
);

const tsWorkAccount = TailscaleAccount(
  userId: '2001',
  loginName: 'pat@work.test',
  displayName: 'Pat Work',
  tailnet: 'work-net.test',
  controlUrl: tsControl,
);

const tsHomeAccount = TailscaleAccount(
  userId: '1001',
  loginName: 'pat@example.test',
  displayName: 'Pat Example',
  tailnet: 'example-net.test',
  controlUrl: tsControl,
);

/// A panel-added account, signed in and attached unless told otherwise.
TailscaleNode tsManagedNode(
  String id, {
  TailscaleAccount? account = tsHomeAccount,
  bool attached = true,
  bool loggedOut = false,
}) => TailscaleNode(
  profileId: 42,
  name: 'tailscale-$id',
  generation: 1,
  controlUrl: tsControl,
  hostname: 'flclash-mac',
  stateDirMode: TailscaleStateDirMode.managed,
  overridable: true,
  managedId: id,
  attached: attached,
  loggedOut: loggedOut,
  account: account,
  started: account != null && !loggedOut,
  hasIdentity: account != null && !loggedOut,
  backendState: account != null && !loggedOut
      ? TailscaleBackendState.running
      : TailscaleBackendState.needsLogin,
);

const tsConflictTarget = TailscaleRouteTarget(
  kind: tailscaleTargetIp,
  value: '100.94.68.92',
);

/// Two accounts both list studio-mac's address; nothing chosen yet.
TailscaleRoutes tsConflictRoutes() => const TailscaleRoutes(
  profileId: 42,
  active: true,
  complete: true,
  revision: 3,
  accounts: [
    TailscaleRouteAccountReport(
      id: 'm1',
      fresh: true,
      available: true,
      domain: 'example-net.test.ts.net',
      addresses: 9,
    ),
    TailscaleRouteAccountReport(
      id: 'm2',
      fresh: true,
      available: true,
      domain: 'work-net.test.ts.net',
      addresses: 4,
    ),
  ],
  targets: [
    TailscaleRouteTargetReport(
      target: tsConflictTarget,
      state: TailscaleRouteState.conflict,
      candidates: [
        TailscaleRouteCandidate(
          owner: TailscaleRouteOwner(kind: tailscaleOwnerManaged, id: 'm1'),
          device: 'studio-mac',
          label: 'pat@example.test',
          tailnet: 'example-net.test',
        ),
        TailscaleRouteCandidate(
          owner: TailscaleRouteOwner(kind: tailscaleOwnerManaged, id: 'm2'),
          device: 'build-mac',
          label: 'pat@work.test',
          tailnet: 'work-net.test',
        ),
      ],
    ),
  ],
);

/// m1 uses nas-sg as its exit node.
TailscaleStatus tsExitStatus(
  TailscaleNode node, {
  bool online = true,
  bool exitNodeOption = true,
}) {
  final status = tsConnectedStatus(node: node);
  return status.copyWith(
    prefs: const TailscalePrefs(exitNodeIp: '100.88.12.4'),
    peers: [
      for (final peer in status.peers)
        peer.hostName == 'nas-sg'
            ? peer.copyWith(online: online, exitNodeOption: exitNodeOption)
            : peer,
    ],
  );
}

const tsExitMember = 'nas-sg';

/// The running exit group: 国际媒体 falls back to 香港策略, 仅日本 to nothing
/// the Core can name.
TailscaleExitReport tsExitReport({
  TailscaleExitState state = TailscaleExitState.applied,
  TailscaleExitReason? reason,
  List<TailscaleExitParent>? parents,
}) => TailscaleExitReport(
  profileId: 42,
  state: TailscaleRuntimeState.confirmed,
  group: 'Tailscale 出口',
  selected: 'm1',
  parents:
      parents ??
      const [
        TailscaleExitParent(
          name: '国际媒体',
          now: 'Tailscale 出口',
          members: ['香港策略', '美国策略', 'DIRECT', 'Tailscale 出口'],
          replacement: '香港策略',
        ),
        TailscaleExitParent(
          name: '仅日本',
          now: 'Tailscale 出口',
          members: ['COMPATIBLE', 'Tailscale 出口'],
        ),
        TailscaleExitParent(
          name: '全球手动',
          now: 'HK 01',
          members: ['HK 01', 'US 01', 'Tailscale 出口'],
          replacement: 'HK 01',
        ),
      ],
  accounts: [
    TailscaleExitAccount(
      id: 'm1',
      member: tsExitMember,
      exitNode: '100.88.12.4',
      state: state,
      reason: reason,
    ),
  ],
);

/// The proxies page as the Core lists it with the exit group added last.
List<Group> tsExitGroups() {
  const exit = Proxy(name: 'Tailscale 出口', type: 'Selector');
  return [
    const Group(
      name: '国际媒体',
      type: GroupType.Selector,
      hidden: false,
      now: '香港策略',
      all: [
        Proxy(name: '香港策略', type: 'URLTest'),
        Proxy(name: '美国策略', type: 'Fallback'),
        Proxy(name: 'DIRECT', type: 'Direct'),
        exit,
      ],
    ),
    const Group(
      name: '香港策略',
      type: GroupType.URLTest,
      hidden: false,
      now: 'HK 01',
      all: [Proxy(name: 'HK 01', type: 'Socks5')],
    ),
    const Group(
      name: '美国策略',
      type: GroupType.Fallback,
      hidden: false,
      now: 'US 01',
      all: [Proxy(name: 'US 01', type: 'Socks5')],
    ),
    const Group(
      name: 'Tailscale 出口',
      type: GroupType.Selector,
      hidden: false,
      now: tsExitMember,
      all: [Proxy(name: tsExitMember, type: 'Tailscale')],
    ),
  ];
}
