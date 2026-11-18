import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:yaml/yaml.dart' show loadYaml;

/// The rule types the add dialog offers as segments, in order.
const addedRuleMainTypes = [
  RuleAction.DOMAIN_SUFFIX,
  RuleAction.DOMAIN,
  RuleAction.DOMAIN_KEYWORD,
  RuleAction.IP_CIDR,
];

/// The rest of the types an added rule may take, under 「更多」: every type
/// one line names in full, without the logic rules that nest others.
final addedRuleMoreTypes = [
  RuleAction.IP_CIDR6,
  RuleAction.DST_PORT,
  RuleAction.PROCESS_NAME,
  RuleAction.GEOIP,
  RuleAction.GEOSITE,
  RuleAction.SRC_IP_CIDR,
  for (final action in RuleAction.addedRuleActions)
    if (!action.nestsRules &&
        !addedRuleMainTypes.contains(action) &&
        !const [
          RuleAction.IP_CIDR6,
          RuleAction.DST_PORT,
          RuleAction.PROCESS_NAME,
          RuleAction.GEOIP,
          RuleAction.GEOSITE,
          RuleAction.SRC_IP_CIDR,
        ].contains(action))
      action,
];

/// Why a value cannot make a rule.
enum AddedRuleValueError {
  empty,
  comma,
  domain,
  cidr,
  network,
  numberRange,
  dscpRange,
}

final _domainLike = RegExp(
  r'^(?:\*\.|\+\.|\.)?(?:[a-z0-9_*](?:[a-z0-9_*-]{0,61}[a-z0-9_*])?\.)*[a-z0-9_*-]{1,63}$',
);

bool _isDomainType(RuleAction type) =>
    const [RuleAction.DOMAIN, RuleAction.DOMAIN_SUFFIX].contains(type);

bool _isCidrType(RuleAction type) => const [
  RuleAction.IP_CIDR,
  RuleAction.IP_CIDR6,
  RuleAction.SRC_IP_CIDR,
].contains(type);

/// The value as the rule writes it: a pasted link gives its host for a
/// domain rule, and a single address its own range for an IP range rule.
String normalizeAddedRuleValue(RuleAction type, String input) {
  var value = input.trim();
  if (value.isEmpty) return value;
  if (_isDomainType(type) || type == RuleAction.DOMAIN_KEYWORD) {
    if (value.contains('://') || value.contains('/')) {
      final uri = Uri.tryParse(value.contains('://') ? value : 'http://$value');
      final host = uri?.host ?? '';
      if (host.isNotEmpty) value = host;
    }
    if (_isDomainType(type)) {
      value = value.toLowerCase();
      if (value.endsWith('.')) value = value.substring(0, value.length - 1);
    }
    return value;
  }
  if (_isCidrType(type)) {
    if (value.startsWith('[') && value.endsWith(']')) {
      value = value.substring(1, value.length - 1);
    }
    if (!value.contains('/')) {
      final address = InternetAddress.tryParse(value);
      if (address != null) {
        final bits = address.type == InternetAddressType.IPv6 ? 128 : 32;
        return '$value/$bits';
      }
    }
  }
  return value;
}

bool _validCidr(String value) {
  final slash = value.indexOf('/');
  if (slash <= 0) return false;
  final address = InternetAddress.tryParse(value.substring(0, slash));
  final bits = int.tryParse(value.substring(slash + 1));
  if (address == null || bits == null || bits < 0) return false;
  return bits <= (address.type == InternetAddressType.IPv6 ? 128 : 32);
}

/// Why [value], already normalized, cannot make a [type] rule; null when it
/// can.
AddedRuleValueError? addedRuleValueError(RuleAction type, String value) {
  if (value.isEmpty) return AddedRuleValueError.empty;
  if (value.contains(',') && !type.hasCommaPayload) {
    return AddedRuleValueError.comma;
  }
  if (_isDomainType(type) && !_domainLike.hasMatch(value)) {
    return AddedRuleValueError.domain;
  }
  if (_isCidrType(type) && !_validCidr(value)) {
    return AddedRuleValueError.cidr;
  }
  final error = Rule(ruleAction: type, content: value).payloadError;
  return switch (error) {
    null => null,
    RulePayloadError.network => AddedRuleValueError.network,
    RulePayloadError.numberRange => AddedRuleValueError.numberRange,
    RulePayloadError.dscpRange => AddedRuleValueError.dscpRange,
  };
}

/// The value the add dialog starts with for a looked-up [host]: the host
/// without www. as a domain suffix, or the address as its own range.
({RuleAction type, String value}) addedRulePrefill(String host) {
  if (InternetAddress.tryParse(host) != null) {
    return (
      type: RuleAction.IP_CIDR,
      value: normalizeAddedRuleValue(RuleAction.IP_CIDR, host),
    );
  }
  final value = host.startsWith('www.') ? host.substring(4) : host;
  return (type: RuleAction.DOMAIN_SUFFIX, value: value);
}

/// The text of an added rule; an empty [value] leaves its place empty.
String addedRuleLine(RuleAction type, String value, String target) {
  return [type.value, value, target].join(',');
}

/// Whether two rules match the same thing, whatever their groups.
bool sameAddedRule(Rule a, Rule b) {
  return a.ruleAction == b.ruleAction &&
      (a.realContent ?? '').toLowerCase() ==
          (b.realContent ?? '').toLowerCase();
}

/// The name a rule set takes from its link: the file name without its
/// extension.
String ruleSetNameOf(String url) {
  final uri = Uri.tryParse(url.trim());
  final segments = uri?.pathSegments.where((item) => item.isNotEmpty) ?? [];
  if (segments.isEmpty) return uri?.host ?? '';
  final file = Uri.decodeComponent(segments.last);
  final dot = file.indexOf('.');
  return dot > 0 ? file.substring(0, dot) : file;
}

/// Whether [url] is a web address an added rule set may download from.
bool isRuleSetUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

/// A rule set's name cannot carry what splits a rule line.
bool isRuleSetName(String name) {
  final value = name.trim();
  return value.isNotEmpty && !value.contains(',') && value == name;
}

/// Whether [format] can carry [behavior]: mrs holds domains or IP ranges
/// only.
bool ruleSetFormatFits(
  RuleProviderBehavior behavior,
  RuleProviderFormat format,
) {
  return format != RuleProviderFormat.mrs ||
      behavior != RuleProviderBehavior.classical;
}

/// Why a downloaded rule set cannot be added.
enum RuleSetCheckFailure { notFound, timeout, network, notRuleSet, unknown }

/// What the check of a rule set's link found. [count] is null when only the
/// Core could count it and it was not running.
class RuleSetCheck {
  final RuleProviderBehavior? behavior;
  final RuleProviderFormat? format;
  final int? count;
  final RuleSetCheckFailure? failure;

  /// The status code or message behind a failure, when there is one.
  final String detail;

  /// What was downloaded, to start the set's file with.
  final Uint8List? content;

  const RuleSetCheck({this.behavior, this.format, this.count, this.content})
    : failure = null,
      detail = '';

  const RuleSetCheck.failed(
    RuleSetCheckFailure this.failure, {
    this.detail = '',
  }) : behavior = null,
       format = null,
       count = null,
       content = null;

  bool get ok => failure == null;
}

const _zstdMagic = [0x28, 0xB5, 0x2F, 0xFD];

bool isZstd(List<int> bytes) =>
    bytes.length >= 4 &&
    bytes[0] == _zstdMagic[0] &&
    bytes[1] == _zstdMagic[1] &&
    bytes[2] == _zstdMagic[2] &&
    bytes[3] == _zstdMagic[3];

final _cidr = RegExp(r'^[0-9a-fA-F:.]+/\d{1,3}$');

bool _isAddressEntry(String entry) {
  if (_cidr.hasMatch(entry)) return _validCidr(entry);
  return InternetAddress.tryParse(entry) != null;
}

/// Reads what a downloaded rule set holds as the Core would load it: a
/// payload in YAML, or one entry a line; entries with a type are classical
/// rules, bare ones domains or IP ranges. An mrs file is the Core's to
/// read, so its kind is left null here.
RuleSetCheck classifyRuleSet(Uint8List bytes) {
  if (isZstd(bytes)) {
    return RuleSetCheck(format: RuleProviderFormat.mrs, content: bytes);
  }
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    return const RuleSetCheck.failed(RuleSetCheckFailure.unknown);
  }
  final trimmed = text.trimLeft();
  if (trimmed.isEmpty) {
    return const RuleSetCheck.failed(RuleSetCheckFailure.notRuleSet);
  }
  if (trimmed.startsWith('<')) {
    return const RuleSetCheck.failed(RuleSetCheckFailure.notRuleSet);
  }
  var format = RuleProviderFormat.text;
  List<String>? entries;
  try {
    final yaml = loadYaml(text);
    if (yaml is Map && (yaml['payload'] is List || yaml['rules'] is List)) {
      format = RuleProviderFormat.yaml;
      entries = [
        for (final key in ['payload', 'rules'])
          if (yaml[key] is List)
            for (final entry in yaml[key] as List)
              if ('$entry'.trim().isNotEmpty) '$entry'.trim(),
      ];
    } else if (yaml is Map) {
      // A config or anything else keyed is not a rule set.
      return const RuleSetCheck.failed(RuleSetCheckFailure.notRuleSet);
    }
  } catch (_) {
    // Not YAML: read as one entry a line.
  }
  entries ??= [
    for (final raw in const LineSplitter().convert(text))
      if (raw.trim() case final line
          when line.isNotEmpty &&
              !line.startsWith('#') &&
              !line.startsWith('//'))
        line,
  ];
  if (entries.isEmpty) {
    return const RuleSetCheck.failed(RuleSetCheckFailure.notRuleSet);
  }
  final RuleProviderBehavior behavior;
  if (entries.any((entry) => entry.contains(','))) {
    final known = {for (final action in RuleAction.values) action.value};
    final typed = entries.every(
      (entry) => known.contains(entry.split(',').first.trim().toUpperCase()),
    );
    if (!typed) {
      return const RuleSetCheck.failed(RuleSetCheckFailure.unknown);
    }
    behavior = RuleProviderBehavior.classical;
  } else {
    final addresses = entries.where(_isAddressEntry).length;
    if (addresses == entries.length) {
      behavior = RuleProviderBehavior.ipcidr;
    } else if (addresses == 0) {
      // Core accepts single-label and leading-dot patterns. A lone bare
      // token is also indistinguishable from a 200 error body, so require
      // explicit YAML structure or at least one unambiguous domain pattern.
      bool domainEntry(String value) {
        if (value.startsWith('+.')) {
          value = value.substring(2);
        } else if (value.startsWith('.')) {
          value = value.substring(1);
        }
        if (value.isEmpty || value.length > 253) return false;
        final label = RegExp(
          r'^[A-Za-z0-9_](?:[A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?$',
        );
        return value
            .split('.')
            .every((part) => part == '*' || label.hasMatch(part));
      }

      final hasDomainContext =
          format == RuleProviderFormat.yaml ||
          entries.any((entry) => entry.contains('.'));
      if (!hasDomainContext || entries.any((entry) => !domainEntry(entry))) {
        return const RuleSetCheck.failed(RuleSetCheckFailure.notRuleSet);
      }
      behavior = RuleProviderBehavior.domain;
    } else {
      return const RuleSetCheck.failed(RuleSetCheckFailure.unknown);
    }
  }
  return RuleSetCheck(
    behavior: behavior,
    format: format,
    count: entries.length,
    content: bytes,
  );
}
