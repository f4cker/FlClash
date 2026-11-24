import 'package:fl_clash/common/go_net.dart';

final _separators = RegExp(r'[, ;]+');

// config.go parseHosts, on the value as splitByMultipleSeparators splits it.
bool isHostsValue(String value) {
  final parts = value.split(_separators).where((part) => part.isNotEmpty);
  if (parts.length > 1) {
    return parts.every((part) => goParseAddr(part) != null);
  }
  if (value == 'lan' || goParseAddr(value) != null) return true;
  return _trimDots(value).split('.').length >= 2;
}

String _trimDots(String value) {
  var start = 0;
  var end = value.length;
  while (start < end && value[start] == '.') {
    start++;
  }
  while (end > start && value[end - 1] == '.') {
    end--;
  }
  return value.substring(start, end);
}

/// A domain whose mapping leads back to itself, which mihomo refuses.
String? hostsCycleOf(Map<String, String> hosts) {
  String? target(String domain) {
    final value = hosts[domain];
    if (value == null || !isHostsValue(value)) return null;
    final parts = value.split(_separators).where((part) => part.isNotEmpty);
    if (parts.length > 1 || value == 'lan' || goParseAddr(value) != null) {
      return null;
    }
    return _trimDots(value);
  }

  for (final domain in hosts.keys) {
    final seen = <String>{};
    var next = target(domain);
    while (next != null && seen.add(next)) {
      if (next == domain) return domain;
      next = target(next);
    }
  }
  return null;
}
