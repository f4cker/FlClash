import 'package:collection/collection.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// What the device card shows for the node, design.md §4 and §9.
enum TailscalePhase {
  loadFailed,
  preparing,
  starting,
  signedOut,
  waitingBrowser,
  needsApproval,
  connected,
  needsReauth,
  stopped,
  startFailed,
  unconfirmed,
}

const tailscaleReminderWindow = Duration(days: 7);

const _signedOutStartErrors = {'tailscale_needs_login', 'tailscale_logged_out'};

/// Top-down as core-contract.md §4: the first match wins. [status] is the
/// last read of this node's instance and [readFailed] says the latest failed.
TailscalePhase deriveTailscalePhase({
  required TailscaleNode node,
  required TailscaleStatus? status,
  bool readFailed = false,
  bool loginInFlight = false,
  bool startInFlight = false,
  bool startCallFailed = false,
  bool holdsAuthUrl = false,
  bool unconfirmed = false,
  required DateTime now,
}) {
  if (status == null && readFailed) {
    return TailscalePhase.loadFailed;
  }
  if (loginInFlight) {
    return TailscalePhase.preparing;
  }
  if (unconfirmed) {
    return TailscalePhase.unconfirmed;
  }
  if (node.loggedOut) {
    return TailscalePhase.signedOut;
  }
  if (node.startError case final error?) {
    return _signedOutStartErrors.contains(error.code)
        ? TailscalePhase.signedOut
        : TailscalePhase.startFailed;
  }
  if (node.stateDirInUse) {
    return TailscalePhase.startFailed;
  }
  if (!node.started) {
    if (!node.hasIdentity) {
      return TailscalePhase.signedOut;
    }
    return startCallFailed
        ? TailscalePhase.startFailed
        : TailscalePhase.starting;
  }
  if (startInFlight) {
    return TailscalePhase.starting;
  }
  return switch (node.backendState) {
    TailscaleBackendState.starting ||
    TailscaleBackendState.noState => TailscalePhase.starting,
    TailscaleBackendState.needsLogin when holdsAuthUrl =>
      TailscalePhase.waitingBrowser,
    TailscaleBackendState.needsLogin when node.hasIdentity =>
      TailscalePhase.needsReauth,
    TailscaleBackendState.needsLogin => TailscalePhase.signedOut,
    TailscaleBackendState.needsMachineAuth => TailscalePhase.needsApproval,
    TailscaleBackendState.running when _expired(status?.self, now) =>
      TailscalePhase.needsReauth,
    TailscaleBackendState.running => TailscalePhase.connected,
    TailscaleBackendState.stopped => TailscalePhase.stopped,
    TailscaleBackendState.none ||
    TailscaleBackendState.unknown => TailscalePhase.unconfirmed,
  };
}

bool _expired(TailscalePeer? self, DateTime now) {
  if (self == null) {
    return false;
  }
  final expiry = self.keyExpiry;
  return self.expired || (expiry != null && !expiry.isAfter(now));
}

/// Set only from a reliable expiry inside the reminder window; a missing
/// time is never guessed at.
DateTime? tailscaleExpiryReminder(TailscaleStatus? status, DateTime now) {
  final expiry = status?.self?.keyExpiry;
  if (expiry == null || !expiry.isAfter(now)) {
    return null;
  }
  return expiry.difference(now) <= tailscaleReminderWindow ? expiry : null;
}

/// Phases the page re-reads every few seconds while it is in sight.
const tailscalePolledPhases = {
  TailscalePhase.starting,
  TailscalePhase.waitingBrowser,
  TailscalePhase.needsApproval,
};

const tailscaleLogoutPhases = {
  TailscalePhase.connected,
  TailscalePhase.needsApproval,
  TailscalePhase.needsReauth,
  TailscalePhase.stopped,
};

/// What the legacy block in the device card shows, legacy-login-copy.md.
enum TailscaleLegacyView {
  hidden,
  offer,
  failed,
  changed,
  migrated,
  unknown,
  hasIdentity,
  controlMismatch,
  inUse,
  migratedElsewhere,
  unreadable,
  unconfirmed,
}

/// A pending unknown outcome shows whatever the node reads now, so nothing
/// offers the migration or a login again until a read settles it.
TailscaleLegacyView tailscaleLegacyViewOf({
  required TailscaleNode node,
  required TailscaleLegacyState state,
  required TailscalePhase phase,
}) {
  final notice = state.notice;
  if (notice == TailscaleLegacyNotice.unknown) {
    return TailscaleLegacyView.unknown;
  }
  if (state.migrating) {
    return TailscaleLegacyView.offer;
  }
  if (notice == TailscaleLegacyNotice.migrated) {
    return phase == TailscalePhase.starting
        ? TailscaleLegacyView.migrated
        : TailscaleLegacyView.hidden;
  }
  final legacy = node.legacy;
  if (legacy == null || phase != TailscalePhase.signedOut) {
    return TailscaleLegacyView.hidden;
  }
  if (notice == TailscaleLegacyNotice.unreadable) {
    return TailscaleLegacyView.unreadable;
  }
  if (notice == TailscaleLegacyNotice.unconfirmed) {
    return TailscaleLegacyView.unconfirmed;
  }
  final reason = switch (legacy.eligibility) {
    TailscaleLegacyEligibility.eligible when legacy.offerToken != null =>
      switch (notice) {
        TailscaleLegacyNotice.failed => TailscaleLegacyView.failed,
        TailscaleLegacyNotice.changed => TailscaleLegacyView.changed,
        _ => TailscaleLegacyView.offer,
      },
    TailscaleLegacyEligibility.eligible ||
    TailscaleLegacyEligibility.unconfirmed => TailscaleLegacyView.unconfirmed,
    TailscaleLegacyEligibility.unreadable => TailscaleLegacyView.unreadable,
    TailscaleLegacyEligibility.hasIdentity => TailscaleLegacyView.hasIdentity,
    TailscaleLegacyEligibility.controlMismatch =>
      TailscaleLegacyView.controlMismatch,
    TailscaleLegacyEligibility.inUse => TailscaleLegacyView.inUse,
    TailscaleLegacyEligibility.migrated =>
      TailscaleLegacyView.migratedElsewhere,
    TailscaleLegacyEligibility.notIsolated ||
    TailscaleLegacyEligibility.dirInUse => TailscaleLegacyView.hidden,
  };
  const provenOnlyAfterOffer = {
    TailscaleLegacyView.hasIdentity,
    TailscaleLegacyView.controlMismatch,
    TailscaleLegacyView.inUse,
    TailscaleLegacyView.migratedElsewhere,
  };
  if (provenOnlyAfterOffer.contains(reason) && !state.offered) {
    return TailscaleLegacyView.hidden;
  }
  return reason;
}

/// Whether the device card's own login is held back by the legacy block.
bool tailscaleLegacyHoldsLogin(TailscaleLegacyView view) =>
    view == TailscaleLegacyView.unknown;

sealed class TailscaleOwner {
  const TailscaleOwner();

  /// Groups devices for the owner filter; stable IDs, never names.
  String get filterKey;
}

class TailscaleOwnerMe extends TailscaleOwner {
  const TailscaleOwnerMe(this.user);

  final TailscaleUser user;

  @override
  String get filterKey => 'me';
}

class TailscaleOwnerUser extends TailscaleOwner {
  const TailscaleOwnerUser(this.user);

  final TailscaleUser user;

  @override
  String get filterKey => 'user:${user.id}';
}

class TailscaleOwnerTags extends TailscaleOwner {
  const TailscaleOwnerTags(this.tags);

  final List<String> tags;

  @override
  String get filterKey => 'tags:${tags.join(',')}';
}

class TailscaleOwnerUnknown extends TailscaleOwner {
  const TailscaleOwnerUnknown();

  @override
  String get filterKey => 'unknown';
}

class TailscaleDevice {
  const TailscaleDevice({required this.peer, required this.owner, this.sharer});

  final TailscalePeer peer;
  final TailscaleOwner owner;

  /// Set only when the control server names who shared the device.
  final TailscaleUser? sharer;

  String? get name => tailscalePeerName(peer);

  String? get address => tailscaleAddressOf(peer);
}

String? tailscalePeerName(TailscalePeer peer) {
  if (peer.hostName.isNotEmpty) {
    return peer.hostName;
  }
  final dnsLabel = peer.dnsName.split('.').first;
  return dnsLabel.isEmpty ? null : dnsLabel;
}

/// The full MagicDNS name without its root dot, only where the tailnet has
/// MagicDNS on.
String? tailscaleMagicDnsName(TailscalePeer peer, {required bool enabled}) {
  final name = peer.dnsName.endsWith('.')
      ? peer.dnsName.substring(0, peer.dnsName.length - 1)
      : peer.dnsName;
  return enabled && name.isNotEmpty ? name : null;
}

/// Peers whose owner ID the status's user list does not hold.
int tailscaleMissingOwnerCount(TailscaleStatus status) => status.peers
    .where(
      (peer) =>
          peer.userId.isNotEmpty && !status.users.containsKey(peer.userId),
    )
    .length;

/// The IPv4 address when there is one, as the design shows it first.
String? tailscaleAddressOf(TailscalePeer? peer) {
  final addresses = peer?.addresses ?? const <String>[];
  return addresses.firstWhereOrNull((address) => !address.contains(':')) ??
      addresses.firstOrNull;
}

/// The IPv4 address only; null without one, never an IPv6 in its place.
String? tailscaleIpv4Of(TailscalePeer? peer) =>
    peer?.addresses.firstWhereOrNull((address) => !address.contains(':'));

String? tailscaleIpv6Of(TailscalePeer? peer) =>
    peer?.addresses.firstWhereOrNull((address) => address.contains(':'));

/// "我" only on a match of stable user IDs; a display name never decides it.
List<TailscaleDevice> tailscaleDevicesOf(TailscaleStatus status) {
  final me = status.loginUser;
  final devices = [
    for (final peer in status.peers)
      TailscaleDevice(
        peer: peer,
        owner: _ownerOf(peer, status, me),
        sharer: switch (peer.altSharerUserId) {
          final id? => status.users[id],
          null => null,
        },
      ),
  ];
  devices.sort((a, b) {
    if (a.peer.online != b.peer.online) {
      return a.peer.online ? -1 : 1;
    }
    final aMe = a.owner is TailscaleOwnerMe;
    if (aMe != (b.owner is TailscaleOwnerMe)) {
      return aMe ? -1 : 1;
    }
    return (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
  });
  return devices;
}

TailscaleOwner _ownerOf(
  TailscalePeer peer,
  TailscaleStatus status,
  TailscaleUser? me,
) {
  if (peer.tags.isNotEmpty) {
    return TailscaleOwnerTags(peer.tags);
  }
  if (peer.userId.isEmpty) {
    return const TailscaleOwnerUnknown();
  }
  if (me != null && me.id.isNotEmpty && me.id == peer.userId) {
    return TailscaleOwnerMe(status.users[peer.userId] ?? me);
  }
  final user = status.users[peer.userId];
  return user == null
      ? const TailscaleOwnerUnknown()
      : TailscaleOwnerUser(user);
}

class TailscaleOwnerGroup {
  const TailscaleOwnerGroup({required this.owner, required this.count});

  final TailscaleOwner owner;
  final int count;
}

/// Me first, then the others as they first appear, unknown last.
List<TailscaleOwnerGroup> tailscaleOwnerGroupsOf(
  List<TailscaleDevice> devices,
) {
  final owners = <String, TailscaleOwner>{};
  final counts = <String, int>{};
  for (final device in devices) {
    final key = device.owner.filterKey;
    owners.putIfAbsent(key, () => device.owner);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  int rank(TailscaleOwner owner) => switch (owner) {
    TailscaleOwnerMe() => 0,
    TailscaleOwnerUnknown() => 2,
    _ => 1,
  };
  final keys = owners.keys.toList()
    ..sort((a, b) => rank(owners[a]!).compareTo(rank(owners[b]!)));
  return [
    for (final key in keys)
      TailscaleOwnerGroup(owner: owners[key]!, count: counts[key]!),
  ];
}

/// The owner filter and the search apply together; [ownerKey] null is all.
List<TailscaleDevice> filterTailscaleDevices(
  List<TailscaleDevice> devices, {
  String? ownerKey,
  String query = '',
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final device in devices)
      if ((ownerKey == null || device.owner.filterKey == ownerKey) &&
          (needle.isEmpty ||
              (device.name ?? '').toLowerCase().contains(needle) ||
              device.peer.dnsName.toLowerCase().contains(needle) ||
              device.peer.addresses.any(
                (address) => address.toLowerCase().contains(needle),
              )))
        device,
  ];
}

/// The exit node as the instance runs it, else as configured.
TailscalePeer? tailscaleCurrentExitPeer(
  TailscaleNode node,
  TailscaleStatus? status,
) {
  final peers = status?.peers ?? const <TailscalePeer>[];
  if (status?.prefs case final prefs?) {
    if (prefs.exitNodeId.isNotEmpty) {
      return peers.firstWhereOrNull((peer) => peer.id == prefs.exitNodeId);
    }
    if (prefs.exitNodeIp.isNotEmpty) {
      return peers.firstWhereOrNull(
        (peer) => peer.addresses.contains(prefs.exitNodeIp),
      );
    }
    return peers.firstWhereOrNull((peer) => peer.exitNode);
  }
  final value = node.settings.exitNode.value;
  if (value.isEmpty) {
    return null;
  }
  return peers.firstWhereOrNull(
    (peer) =>
        peer.addresses.contains(value) ||
        peer.id == value ||
        peer.hostName == value,
  );
}

/// The exit node's name when no peer matches it: the raw configured value.
String? tailscaleExitValue(TailscaleNode node, TailscaleStatus? status) {
  if (status?.prefs case final prefs?) {
    final value = prefs.exitNodeIp.isNotEmpty
        ? prefs.exitNodeIp
        : prefs.exitNodeId;
    return value.isEmpty ? null : value;
  }
  final value = node.settings.exitNode.value;
  return value.isEmpty ? null : value;
}

bool tailscaleAcceptsRoutes(TailscaleNode node, TailscaleStatus? status) =>
    status?.prefs?.acceptRoutes ?? node.settings.acceptRoutes.value;

/// The host of a control server URL, as the card shows it.
String tailscaleControlHost(String controlUrl) {
  if (controlUrl.isEmpty) {
    return '';
  }
  final host = Uri.tryParse(controlUrl)?.host ?? '';
  return host.isEmpty ? controlUrl : host;
}

const _tailscaleSystemNames = {
  'linux': 'Linux',
  'android': 'Android',
  'windows': 'Windows',
  'ios': 'iOS',
  'ipados': 'iPadOS',
  'macos': 'macOS',
  'darwin': 'macOS',
  'tvos': 'tvOS',
  'freebsd': 'FreeBSD',
  'openbsd': 'OpenBSD',
  'netbsd': 'NetBSD',
  'dragonfly': 'DragonFly BSD',
  'illumos': 'illumos',
  'solaris': 'Solaris',
  'plan9': 'Plan 9',
  'js': 'JS',
};

/// A peer's OS as its vendor writes it; anything else capitalised.
String tailscaleSystemName(String os) {
  final value = os.trim();
  if (value.isEmpty) {
    return value;
  }
  return _tailscaleSystemNames[value.toLowerCase()] ??
      value[0].toUpperCase() + value.substring(1);
}
