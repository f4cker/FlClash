import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/tailscale/device_list.dart';
import 'package:flutter/widgets.dart';

import 'tailscale_fixtures.dart';

const devicesAlice = TailscaleUser(
  id: '501',
  loginName: 'alice@example.com',
  displayName: 'Alice',
);

const devicesBob = TailscaleUser(
  id: '502',
  loginName: 'bob@example.com',
  displayName: 'Bob',
);

/// Made-up peers on example.ts.net: online and offline, one without a
/// MagicDNS name and one whose owner the status leaves out.
List<TailscalePeer> devicesPeers() => const [
  TailscalePeer(
    id: 'p1',
    hostName: 'studio-mac',
    dnsName: 'studio-mac.example.ts.net.',
    os: 'macOS',
    userId: '501',
    addresses: ['100.94.68.92', 'fd7a:115c:a1e0::1'],
    online: true,
  ),
  TailscalePeer(
    id: 'p2',
    hostName: 'nas-sg',
    dnsName: 'nas-sg.example.ts.net.',
    os: 'linux',
    userId: '502',
    addresses: ['100.88.12.4'],
    online: true,
    exitNodeOption: true,
  ),
  TailscalePeer(
    id: 'p3',
    hostName: 'office-hk',
    dnsName: 'office-hk.example.ts.net.',
    os: 'windows',
    userId: '777',
    addresses: ['100.72.40.9'],
  ),
  TailscalePeer(
    id: 'p4',
    hostName: 'old-phone',
    os: 'iOS',
    userId: '502',
    addresses: ['100.70.1.4'],
  ),
];

TailscaleStatus devicesStatus({
  bool magicDns = true,
  String network = 'alice@example.com',
  List<TailscalePeer>? peers,
}) => TailscaleStatus(
  node: tsConnectedNode,
  loginUser: devicesAlice,
  tailnet: TailscaleTailnet(
    name: network,
    magicDnsSuffix: 'example.ts.net',
    magicDnsEnabled: magicDns,
  ),
  users: {devicesAlice.id: devicesAlice, devicesBob.id: devicesBob},
  peers: peers ?? devicesPeers(),
);

class DevicesHarness extends StatefulWidget {
  const DevicesHarness({
    super.key,
    required this.status,
    this.copied,
    this.width = 920,
  });

  final TailscaleStatus status;
  final List<String>? copied;
  final double width;

  @override
  State<DevicesHarness> createState() => _DevicesHarnessState();
}

class _DevicesHarnessState extends State<DevicesHarness> {
  final _search = TextEditingController();
  String _query = '';
  String? _owner;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DashboardColors.of(context).page,
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: widget.width,
            child: TailscaleDeviceSection(
              status: widget.status,
              readFailed: false,
              reading: false,
              ownerKey: _owner,
              query: _query,
              searchController: _search,
              onOwnerChanged: (key) => setState(() => _owner = key),
              onQueryChanged: (query) => setState(() => _query = query),
              onRefresh: () {},
              onCopy: (text) => widget.copied?.add('address:$text'),
              onCopyName: (text) => widget.copied?.add('name:$text'),
            ),
          ),
        ),
      ),
    );
  }
}
