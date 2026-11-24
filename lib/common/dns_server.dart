import 'package:fl_clash/common/go_net.dart';

/// mihomo's `unsupport scheme` and `format error`.
enum DnsServerIssue { scheme, format }

typedef _Parsed = ({String net, String addr});

const _rcodes = {
  'success',
  'format_error',
  'server_failure',
  'name_error',
  'not_implemented',
  'refused',
};

String _withScheme(String server) {
  if (server == 'system') return 'system://';
  return switch (goParseAddr(server)) {
    GoAddrFamily.v4 => 'udp://$server',
    GoAddrFamily.v6 => 'udp://[$server]',
    null when server.contains('://') => server,
    null => 'udp://$server',
  };
}

String? _withDefaultPort(String host, String port) {
  final split = goSplitHostPort(host) ?? goSplitHostPort('$host:$port');
  if (split == null) return null;
  return goJoinHostPort(split.$1, split.$2);
}

// config.go parsePureDNSServer and parseNameServer, for one server.
({_Parsed? parsed, DnsServerIssue? issue}) _parse(String input) {
  final server = _withScheme(input);
  final url = goParseUrl(server);
  if (url == null) return (parsed: null, issue: DnsServerIssue.format);
  final host = url.host;
  final _Parsed? parsed = switch (url.scheme) {
    'udp' || 'tcp' => switch (_withDefaultPort(host, '53')) {
      final addr? => (net: url.scheme, addr: addr),
      null => null,
    },
    'tls' || 'quic' => switch (_withDefaultPort(host, '853')) {
      final addr? => (net: url.scheme, addr: addr),
      null => null,
    },
    'http' || 'https' => switch (_withDefaultPort(
      host,
      url.scheme == 'http' ? '80' : '443',
    )) {
      final addr? => (net: 'https', addr: '${url.scheme}://$addr/'),
      null => null,
    },
    'system' => (net: 'system', addr: ''),
    'ts' ||
    'tailscale' ||
    'et' ||
    'easytier' => host.isEmpty ? null : (net: url.scheme, addr: host),
    'dhcp' => switch (server.length < 7 ? '' : server.substring(7)) {
      'system' => (net: 'system', addr: ''),
      final addr => (net: 'dhcp', addr: addr),
    },
    'rcode' => _rcodes.contains(host) ? (net: 'rcode', addr: host) : null,
    _ => null,
  };
  if (parsed != null) return (parsed: parsed, issue: null);
  const known = {
    'udp', 'tcp', 'tls', 'quic', 'http', 'https', 'system', 'ts', //
    'tailscale', 'et', 'easytier', 'dhcp', 'rcode',
  };
  return (
    parsed: null,
    issue: known.contains(url.scheme)
        ? DnsServerIssue.format
        : DnsServerIssue.scheme,
  );
}

/// Why mihomo would refuse [server] in any of its nameserver lists.
DnsServerIssue? dnsServerIssue(String server) => _parse(server).issue;

/// config.go's pure IP check on Default Nameserver; false for any refused.
bool isPureIpDnsServer(String server) {
  final parsed = _parse(server).parsed;
  if (parsed == null) return false;
  if (parsed.net == 'system') return true;
  final addr = parsed.addr;
  if (goSplitHostPort(addr) case (final host, _) when goParseIp(host)) {
    return true;
  }
  final url = goParseUrl(addr);
  if (url == null || goParseIp(url.host)) return true;
  return switch (goSplitHostPort(url.host)) {
    (final ip, _) => goParseIp(ip),
    null => false,
  };
}

bool isDnsHijack(String entry) {
  final scheme = entry.indexOf('://');
  final address = scheme < 0 ? entry : entry.substring(scheme + 3);
  return goParseAddrPort(address.replaceFirst('any', '0.0.0.0'));
}

enum UdpInbound { mixed, socks }

// macOS refuses a UDP bind next to a wildcard one on the same port.
UdpInbound? dnsListenTakenBy(
  String listen, {
  required int mixedPort,
  required int socksPort,
  required bool allowLan,
}) {
  final colon = listen.lastIndexOf(':');
  if (colon < 0) return null;
  final port = int.tryParse(listen.substring(colon + 1));
  final host = listen.substring(0, colon);
  final clashes =
      const {'', '0.0.0.0', '[::]'}.contains(host) ||
      (host == '127.0.0.1' && !allowLan);
  if (port == null || port == 0 || !clashes) return null;
  if (port == mixedPort) return UdpInbound.mixed;
  if (port == socksPort) return UdpInbound.socks;
  return null;
}

// config.go parseFakeIPRules, over RC.ParseRulePayload and R.ParseRule.
bool isFakeIpFilterRule(String line) {
  final item = [for (final part in line.split(',')) _trimSpaces(part)];
  final type = item.first.toUpperCase();
  var payload = '';
  var action = '';
  if (item.length > 1) {
    switch (type) {
      case 'MATCH':
        action = item[1];
      case 'NOT' || 'OR' || 'AND' || 'SUB-RULE' || 'DOMAIN-REGEX':
      case 'PROCESS-NAME-REGEX' || 'PROCESS-PATH-REGEX':
        action = item.last;
        payload = item.sublist(1, item.length - 1).join(',');
      default:
        payload = item[1];
        if (item.length > 2) action = item[2];
    }
  }
  action = action.toLowerCase();
  if (action != 'fake-ip' && action != 'real-ip') return false;
  if (type != 'MATCH' && payload.isEmpty) return false;
  return switch (type) {
    'DOMAIN' ||
    'DOMAIN-SUFFIX' ||
    'DOMAIN-KEYWORD' ||
    'DOMAIN-WILDCARD' => true,
    'GEOSITE' || 'RULE-SET' || 'MATCH' => true,
    'DOMAIN-REGEX' => _mayCompile(payload),
    _ => false,
  };
}

String _trimSpaces(String value) {
  var start = 0;
  var end = value.length;
  while (start < end && value[start] == ' ') {
    start++;
  }
  while (end > start && value[end - 1] == ' ') {
    end--;
  }
  return value.substring(start, end);
}

// mihomo compiles with regexp2, whose extra syntax all starts with `(?`.
bool _mayCompile(String pattern) {
  try {
    RegExp(pattern);
    return true;
  } on FormatException {
    return pattern.contains('(?');
  }
}

bool _isGoSpace(int c) =>
    (c >= 0x09 && c <= 0x0d) ||
    const {
      0x20,
      0x85,
      0xa0,
      0x1680,
      0x2028,
      0x2029,
      0x202f,
      0x205f,
    }.contains(c) ||
    (c >= 0x2000 && c <= 0x200a) ||
    c == 0x3000;

// component/trie ValidAndSplitDomain.
bool isTrieDomain(String domain) {
  if (domain.isEmpty || domain.endsWith('.')) return false;
  if (_isGoSpace(domain.runes.first) || _isGoSpace(domain.runes.last)) {
    return false;
  }
  final parts = domain.split('.');
  if (parts.skip(1).any((part) => part.isEmpty)) return false;
  for (final (index, part) in parts.indexed) {
    if (part.contains('+') &&
        (part != '+' || index != 0 || parts.length == 1)) {
      return false;
    }
    if (part.contains('*') && part != '*') return false;
  }
  return true;
}

// geosite: and rule-set: name data only the Core holds.
bool isDomainMatcher(String entry) {
  final lower = entry.toLowerCase();
  if (lower.startsWith('geosite:') || lower.startsWith('rule-set:')) {
    return true;
  }
  return isTrieDomain(entry);
}

bool isPolicyDomain(String key) {
  final lower = key.toLowerCase();
  if (lower.startsWith('geosite:') || lower.startsWith('rule-set:')) {
    return true;
  }
  return key.split(',').every(isDomainMatcher);
}

final _prefixBits = RegExp(r'^(0|[1-9][0-9]{0,2})$');

// netip.ParsePrefix, then component/fakeip's smallest pool.
bool isFakeIpRange(String value, {required bool v6}) {
  final slash = value.lastIndexOf('/');
  if (slash < 0) return false;
  final addr = value.substring(0, slash);
  final bits = value.substring(slash + 1);
  if (addr.contains('%') || !_prefixBits.hasMatch(bits)) return false;
  return switch (goParseAddr(addr)) {
    GoAddrFamily.v4 => !v6 && int.parse(bits) <= 29,
    GoAddrFamily.v6 => v6 && int.parse(bits) <= 125,
    null => false,
  };
}
