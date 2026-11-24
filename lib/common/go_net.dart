// Go's address and URL parsing, as far as mihomo's config checks lean on it,
// so the app refuses what the Core would and nothing it would take.
// core/testdata/config_field_vectors.json holds both sides to the same cases.

enum GoAddrFamily { v4, v6 }

const _hex = '0123456789abcdefABCDEF';

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isLetter(int c) => (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7a;

bool _isHexAt(String s, int i) => i < s.length && _hex.contains(s[i]);

bool _parseIpv4(String s) {
  final fields = s.split('.');
  if (fields.length != 4) return false;
  for (final field in fields) {
    if (field.isEmpty || field.length > 3) return false;
    if (!field.codeUnits.every(_isDigit)) return false;
    if (field.length > 1 && field[0] == '0') return false;
    if (int.parse(field) > 255) return false;
  }
  return true;
}

bool _parseIpv6(String input) {
  var s = input;
  var i = 0;
  var ellipsis = -1;
  if (s.startsWith('::')) {
    ellipsis = 0;
    s = s.substring(2);
    if (s.isEmpty) return true;
  }
  while (i < 16) {
    var off = 0;
    while (off < s.length && _isHexAt(s, off)) {
      off++;
      if (off > 4) return false;
    }
    if (off == 0) return false;
    if (off < s.length && s[off] == '.') {
      if (ellipsis < 0 && i != 12) return false;
      if (i + 4 > 16) return false;
      if (!_parseIpv4(s)) return false;
      s = '';
      i += 4;
      break;
    }
    i += 2;
    s = s.substring(off);
    if (s.isEmpty) break;
    if (s[0] != ':' || s.length == 1) return false;
    s = s.substring(1);
    if (s[0] == ':') {
      if (ellipsis >= 0) return false;
      ellipsis = i;
      s = s.substring(1);
      if (s.isEmpty) break;
    }
  }
  if (s.isNotEmpty) return false;
  return i < 16 ? ellipsis >= 0 : ellipsis < 0;
}

/// netip.ParseAddr: the family of [s], or null when Go refuses it.
GoAddrFamily? goParseAddr(String s) {
  for (final c in s.codeUnits) {
    switch (c) {
      case 0x2e:
        return _parseIpv4(s) ? GoAddrFamily.v4 : null;
      case 0x3a:
        final zone = s.indexOf('%');
        if (zone == s.length - 1) return null;
        return _parseIpv6(zone < 0 ? s : s.substring(0, zone))
            ? GoAddrFamily.v6
            : null;
      case 0x25:
        return null;
    }
  }
  return null;
}

/// net.ParseIP, which takes no zone.
bool goParseIp(String s) => !s.contains('%') && goParseAddr(s) != null;

/// netip.ParseAddrPort.
bool goParseAddrPort(String s) {
  final i = s.lastIndexOf(':');
  if (i < 0) return false;
  var ip = s.substring(0, i);
  final port = s.substring(i + 1);
  if (ip.isEmpty || port.isEmpty) return false;
  var bracketed = false;
  if (ip.startsWith('[')) {
    if (ip.length < 2 || !ip.endsWith(']')) return false;
    ip = ip.substring(1, ip.length - 1);
    bracketed = true;
  }
  if (!port.codeUnits.every(_isDigit) || int.parse(port) > 65535) {
    return false;
  }
  return switch (goParseAddr(ip)) {
    null => false,
    GoAddrFamily.v4 => !bracketed,
    GoAddrFamily.v6 => bracketed,
  };
}

/// net.SplitHostPort: the host and port, or null on its errors.
(String, String)? goSplitHostPort(String hostport) {
  final i = hostport.lastIndexOf(':');
  if (i < 0) return null;
  String host;
  var j = 0;
  var k = 0;
  if (hostport.startsWith('[')) {
    final end = hostport.indexOf(']');
    if (end < 0) return null;
    if (end + 1 == hostport.length) return null;
    if (end + 1 != i) return null;
    host = hostport.substring(1, end);
    j = 1;
    k = end + 1;
  } else {
    host = hostport.substring(0, i);
    if (host.contains(':')) return null;
  }
  if (hostport.substring(j).contains('[')) return null;
  if (hostport.substring(k).contains(']')) return null;
  return (host, hostport.substring(i + 1));
}

String goJoinHostPort(String host, String port) =>
    host.contains(':') ? '[$host]:$port' : '$host:$port';

/// What of a URL mihomo reads: its lowercased scheme and its unescaped host.
typedef GoUrl = ({String scheme, String host});

bool _validEscapes(String s) {
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '%' && !(_isHexAt(s, i + 1) && _isHexAt(s, i + 2))) {
      return false;
    }
  }
  return true;
}

const _hostPunctuation = '!\$&\'()*+,;=:[]<>"-_.~';

bool _hostByte(int c) =>
    _isLetter(c) ||
    _isDigit(c) ||
    _hostPunctuation.contains(String.fromCharCode(c));

String? _unescapeHost(String s, {bool zone = false}) {
  final out = <int>[];
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c == 0x25) {
      if (!(_isHexAt(s, i + 1) && _isHexAt(s, i + 2))) return null;
      final escape = s.substring(i, i + 3);
      final value = int.parse(s.substring(i + 1, i + 3), radix: 16);
      if (escape != '%25') {
        if (!zone && value < 0x80) return null;
        if (zone && value != 0x20 && !(value < 0x80 && _hostByte(value))) {
          return null;
        }
      }
      out.add(value);
      i += 2;
      continue;
    }
    if (c < 0x80 && !_hostByte(c)) return null;
    out.add(c);
  }
  return String.fromCharCodes(out);
}

bool _validOptionalPort(String port) =>
    port.isEmpty ||
    (port.startsWith(':') && port.substring(1).codeUnits.every(_isDigit));

String? _parseHost(String scheme, String host) {
  final open = host.lastIndexOf('[');
  if (open > 0) return null;
  if (open == 0) {
    final close = host.lastIndexOf(']');
    if (close < 0) return null;
    final port = host.substring(close + 1);
    if (!_validOptionalPort(port)) return null;
    final name = host.substring(1, close);
    final zone = name.indexOf('%25');
    final String? unescaped;
    if (zone >= 0) {
      final a = _unescapeHost(name.substring(0, zone));
      final b = _unescapeHost(name.substring(zone), zone: true);
      unescaped = a == null || b == null ? null : '$a$b';
    } else {
      unescaped = _unescapeHost(name);
    }
    if (unescaped == null) return null;
    if (goParseAddr(unescaped) != GoAddrFamily.v6) return null;
    return '[$unescaped]$port';
  }
  final first = host.indexOf(':');
  if (first >= 0) {
    // Go holds only http and https to one colon in a host.
    final at = scheme == 'http' || scheme == 'https'
        ? first
        : host.lastIndexOf(':');
    if (!_validOptionalPort(host.substring(at))) return null;
  }
  return _unescapeHost(host);
}

const _userinfoPunctuation = '-._:~!\$&\'()*+,;=%@';

/// url.Parse, or null where it errs.
GoUrl? goParseUrl(String raw) {
  final hash = raw.indexOf('#');
  final rest0 = hash < 0 ? raw : raw.substring(0, hash);
  if (hash >= 0 && !_validEscapes(raw.substring(hash + 1))) return null;
  if (rest0.codeUnits.any((c) => c < 0x20 || c == 0x7f)) return null;
  var scheme = '';
  var rest = rest0;
  for (var i = 0; i < rest0.length; i++) {
    final c = rest0.codeUnitAt(i);
    if (_isLetter(c)) continue;
    if (_isDigit(c) || c == 0x2b || c == 0x2d || c == 0x2e) {
      if (i == 0) break;
      continue;
    }
    if (c == 0x3a) {
      if (i == 0) return null;
      scheme = rest0.substring(0, i).toLowerCase();
      rest = rest0.substring(i + 1);
    }
    break;
  }
  if (rest.endsWith('?') && '?'.allMatches(rest).length == 1) {
    rest = rest.substring(0, rest.length - 1);
  } else if (rest.indexOf('?') case final q when q >= 0) {
    rest = rest.substring(0, q);
  }
  if (!rest.startsWith('/')) {
    if (scheme.isNotEmpty) return (scheme: scheme, host: '');
    final slash = rest.indexOf('/');
    final segment = slash < 0 ? rest : rest.substring(0, slash);
    if (segment.contains(':')) return null;
    return _validEscapes(rest) ? (scheme: scheme, host: '') : null;
  }
  var host = '';
  if ((scheme.isNotEmpty || !rest.startsWith('///')) && rest.startsWith('//')) {
    final authorityAndPath = rest.substring(2);
    final slash = authorityAndPath.indexOf('/');
    final authority = slash < 0
        ? authorityAndPath
        : authorityAndPath.substring(0, slash);
    rest = slash < 0 ? '' : authorityAndPath.substring(slash);
    final at = authority.lastIndexOf('@');
    final parsed = _parseHost(
      scheme,
      at < 0 ? authority : authority.substring(at + 1),
    );
    if (parsed == null) return null;
    if (at >= 0) {
      final userinfo = authority.substring(0, at);
      final valid = userinfo.codeUnits.every(
        (c) =>
            _isLetter(c) ||
            _isDigit(c) ||
            _userinfoPunctuation.contains(String.fromCharCode(c)),
      );
      if (!valid || !_validEscapes(userinfo)) return null;
    }
    host = parsed;
  }
  return _validEscapes(rest) ? (scheme: scheme, host: host) : null;
}
