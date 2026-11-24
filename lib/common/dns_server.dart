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
