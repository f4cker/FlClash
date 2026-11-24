import 'package:fl_clash/common/go_net.dart';

final _separators = RegExp(r'[, ;]+');

// config.go parseHosts, on the value as splitByMultipleSeparators splits it.
bool isHostsValue(String value) => isHostsItems(_appItems(value));

List<String> _appItems(String value) {
  final parts = value.split(_separators).where((part) => part.isNotEmpty);
  return parts.length > 1 ? parts.toList() : [value];
}

List<String>? hostsItemsOf(Object? value) => switch (value) {
  final String text => [text],
  final List list => [for (final item in list) '$item'],
  _ => null,
};

bool isHostsItems(Iterable<String> items) {
  if (items.length > 1) {
    return items.every((item) => goParseAddr(item) != null);
  }
  if (items.isEmpty) return false;
  final value = items.single;
  if (value == 'lan' || goParseAddr(value) != null) return true;
  return _trimDots(value).split('.').length >= 2;
}

String? _targetOf(List<String> items) {
  if (!isHostsItems(items) || items.length > 1) return null;
  final value = items.single;
  if (value == 'lan' || goParseAddr(value) != null) return null;
  return _trimDots(value);
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
String? hostsCycleOf(Map<String, String> hosts) => hostsItemsCycleOf({
  for (final MapEntry(:key, :value) in hosts.entries) key: _appItems(value),
});

// Lowercased, as mihomo's trie lowercases every domain.
String? hostsItemsCycleOf(Map<String, List<String>> hosts) {
  final targets = {
    for (final MapEntry(:key, :value) in hosts.entries)
      key.toLowerCase(): _targetOf(value)?.toLowerCase(),
  };
  for (final domain in hosts.keys) {
    final self = domain.toLowerCase();
    final seen = <String>{};
    var next = targets[self];
    while (next != null && seen.add(next)) {
      if (next == self) return domain;
      next = targets[next];
    }
  }
  return null;
}
