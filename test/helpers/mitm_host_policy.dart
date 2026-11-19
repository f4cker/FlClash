import 'dart:convert';
import 'dart:io';

/// macos/Runner/MitmHostPolicy.swift's MitmHostMatcher, for a test signer:
/// the same normalization, issues (invalid, address, over-broad, Apple
/// service) and first-match order. The public suffix list is the part of it
/// core/testdata/mitm_hostname_vectors.json reaches; [mitmHostVectors] holds
/// this to those vectors.
bool mitmPolicyListed(String host, List<String> lines) {
  final name = _normalize(host);
  if (!_validDNSName(name) || _isApple(name)) return false;
  for (final line in lines) {
    final entry = _parse(line);
    if (entry.issue != null) continue;
    if (entry.wildcard ? name.endsWith('.${entry.base}') : name == entry.base) {
      return !entry.exclude;
    }
  }
  return false;
}

/// The issue MitmHostPolicy.parse names for [line], or '' for none.
String mitmPolicyIssue(String line) => _parse(line).issue ?? '';

/// The vectors the Core and the Swift signer are both tested with.
({List<Map<String, Object?>> validate, List<Map<String, Object?>> match})
mitmHostVectors() {
  final json =
      jsonDecode(
            File('core/testdata/mitm_hostname_vectors.json').readAsStringSync(),
          )
          as Map<String, Object?>;
  return (
    validate: (json['validate']! as List).cast<Map<String, Object?>>(),
    match: (json['match']! as List).cast<Map<String, Object?>>(),
  );
}

const _appleDomains = [
  'apple',
  'apple.com',
  'apple.com.cn',
  'apple.co',
  'apple-cloudkit.com',
  'apple-dns.cn',
  'apple-dns.net',
  'apple-livephotoskit.com',
  'apple-mapkit.com',
  'aaplimg.com',
  'appattest.apple.com',
  'appstore.com',
  'cdn-apple.com',
  'icloud.com',
  'icloud.com.cn',
  'icloud-content.com',
  'icloud-content.com.cn',
  'itunes.com',
  'itunes.apple.com',
  'mac.com',
  'me.com',
  'mzstatic.com',
  'push.apple.com',
];

// The rules of the public suffix list the tests touch.
const _suffixes = {'com', 'cn', 'uk', 'co.uk', 'com.cn', 'io', 'github.io'};
const _wildcardSuffixes = {'ck', 'kobe.jp'};
const _exceptionSuffixes = {'www.ck', 'city.kobe.jp'};

typedef _Entry = ({bool exclude, bool wildcard, String base, String? issue});

String _normalize(String host) {
  var text = host.trim().toLowerCase();
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return text;
}

final _label = RegExp(r'^[a-z0-9-]{1,63}$');
final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

bool _validDNSName(String name) {
  if (name.isEmpty || name.length > 253) return false;
  var letters = false;
  for (final label in name.split('.')) {
    if (!_label.hasMatch(label) ||
        label.startsWith('-') ||
        label.endsWith('-')) {
      return false;
    }
    letters = label.contains(RegExp('[a-z]'));
  }
  return letters;
}

bool _isApple(String host) =>
    _appleDomains.any((domain) => host == domain || host.endsWith('.$domain'));

bool _looksLikeAddress(String text) {
  if (text.contains(':')) return true;
  return _ipv4.hasMatch(text) &&
      text.split('.').every((part) => int.parse(part) <= 255);
}

String _publicSuffix(String domain) {
  final labels = domain.split('.');
  String suffix(int count) => labels.sublist(labels.length - count).join('.');
  var length = 1;
  for (var count = 1; count <= labels.length; count++) {
    final candidate = suffix(count);
    if (_exceptionSuffixes.contains(candidate)) {
      length = count - 1;
      break;
    }
    if (_suffixes.contains(candidate) ||
        (count > 1 && _wildcardSuffixes.contains(suffix(count - 1)))) {
      length = count;
    }
  }
  return suffix(length < 1 ? 1 : length);
}

_Entry _parse(String line) {
  var text = _normalize(line);
  var exclude = false;
  _Entry fail(String issue) =>
      (exclude: exclude, wildcard: false, base: '', issue: issue);
  if (text.startsWith('-')) {
    exclude = true;
    text = _normalize(text.substring(1));
  }
  if (text == '*' || text == '*.') {
    return fail(exclude ? 'invalid' : 'over-broad');
  }
  final bare = text.replaceAll(RegExp(r'^[\[\]]+|[\[\]]+$'), '');
  if (_looksLikeAddress(bare)) return fail('address');
  final wildcard = text.startsWith('*.');
  if (wildcard) text = text.substring(2);
  if (!_validDNSName(text)) return fail('invalid');
  String? issue;
  if (!exclude) {
    if (_publicSuffix(text) == text) {
      issue = 'over-broad';
    } else if (_isApple(text)) {
      issue = 'apple-service';
    }
  }
  return (exclude: exclude, wildcard: wildcard, base: text, issue: issue);
}
