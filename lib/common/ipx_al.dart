import 'dart:convert';

import 'package:flutter/foundation.dart';

/// ipx.al: a free, keyless and unofficial IP report service.
///
/// `GET /api/me` answers at once with what the edge sees of the caller;
/// `GET /api/report/{ip}` takes a few seconds the first time and is cached
/// at the edge for about six hours. The terms ask for reasonable use, so the
/// report is only fetched when asked for and kept for the session.
const ipxAlHost = 'ipx.al';

const ipxAlMeUrl = 'https://$ipxAlHost/api/me';

String ipxAlReportUrl(String ip) =>
    'https://$ipxAlHost/api/report/${Uri.encodeComponent(ip)}';

/// The human-readable report of the same address.
String ipxAlPageUrl(String ip) =>
    'https://$ipxAlHost/${Uri.encodeComponent(ip)}';

/// `type.verdict`, see https://ipx.al/api.
enum IpxIpType {
  residential,
  mobile,
  education,
  business,
  hosting,
  pseudo,
  unknown,
}

/// `native.verdict`: whether the registry country matches where the
/// location databases see the address used.
enum IpxNativity { native, broadcast, unknown }

/// The letter grades of https://ipx.al/about.
enum IpxGrade {
  aPlus('A+'),
  a('A'),
  b('B'),
  c('C'),
  d('D');

  const IpxGrade(this.letter);

  final String letter;

  static IpxGrade of(int score) => switch (score) {
    >= 85 => IpxGrade.aPlus,
    >= 70 => IpxGrade.a,
    >= 50 => IpxGrade.b,
    >= 30 => IpxGrade.c,
    _ => IpxGrade.d,
  };
}

/// What `/api/me` sees of the caller: enough to fill the location and the
/// network while the report is still being put together.
@immutable
class IpxBrief {
  const IpxBrief({
    required this.ip,
    this.countryCode,
    this.city,
    this.asn,
    this.organization,
  });

  factory IpxBrief.parse(String body) {
    final json = _decode(body);
    return IpxBrief(
      ip: _requireIp(json),
      countryCode: _text(json['country']),
      city: _text(json['city']),
      asn: _asn(json['asn']),
      organization: _text(json['org']),
    );
  }

  final String ip;
  final String? countryCode;
  final String? city;
  final int? asn;
  final String? organization;

  @override
  bool operator ==(Object other) =>
      other is IpxBrief &&
      other.ip == ip &&
      other.countryCode == countryCode &&
      other.city == city &&
      other.asn == asn &&
      other.organization == organization;

  @override
  int get hashCode => Object.hash(ip, countryCode, city, asn, organization);
}

/// One line of `health.items`: what took points off, or a check that passed.
@immutable
class IpxDeduction {
  const IpxDeduction({
    required this.label,
    required this.points,
    this.source,
    this.note,
    this.tag,
  });

  final String label;

  /// Zero or negative; null when the report left it out.
  final int? points;
  final String? source;
  final String? note;
  final String? tag;

  @override
  bool operator ==(Object other) =>
      other is IpxDeduction &&
      other.label == label &&
      other.points == points &&
      other.source == source &&
      other.note == note &&
      other.tag == tag;

  @override
  int get hashCode => Object.hash(label, points, source, note, tag);
}

@immutable
class IpxReport {
  const IpxReport({
    required this.ip,
    this.score,
    this.ceiling,
    this.type = IpxIpType.unknown,
    this.nativity = IpxNativity.unknown,
    this.registeredCountry,
    this.usedCountry,
    this.countryCode,
    this.city,
    this.asn,
    this.organization,
    this.deductions = const [],
  });

  /// Throws a [FormatException] for anything without an address and a health
  /// section. Whatever
  /// else is missing stays null or unknown: a third party's estimate is
  /// never filled in.
  factory IpxReport.parse(String body) {
    final json = _decode(body);
    final health = switch (json['health']) {
      final Map<String, dynamic> health => health,
      _ => throw const FormatException('ipx.al report without a health check'),
    };
    final score = health['score'];
    final native = _object(json['native']);
    final type = _object(json['type']);
    final location = _object(json['location']);
    return IpxReport(
      ip: _requireIp(json),
      score: score is num ? score.round().clamp(0, 100) : null,
      ceiling: switch (health['ceiling']) {
        final num ceiling => ceiling.round(),
        _ => null,
      },
      type: _type(type['verdict'] ?? health['ipType']),
      nativity: switch (native['verdict']) {
        'native' => IpxNativity.native,
        'broadcast' => IpxNativity.broadcast,
        _ => IpxNativity.unknown,
      },
      registeredCountry: _text(native['regCountry']),
      usedCountry: _text(native['useCountry']),
      countryCode: _text(location['country']),
      city: _text(location['city']),
      asn: _asn(json['asn']),
      organization: _text(json['org']),
      deductions: [
        for (final item in _list(health['items']))
          if (item case {'label': final String label} when label.isNotEmpty)
            IpxDeduction(
              label: label,
              points: switch (item['pts']) {
                final num points => points.round(),
                _ => null,
              },
              source: _text(item['src']),
              note: _text(item['note']),
              tag: _text(item['tag']),
            ),
      ],
    );
  }

  final String ip;

  /// 0–100, or null when ipx.al gave none.
  final int? score;

  /// What the type allows at most before any deduction.
  final int? ceiling;
  final IpxIpType type;
  final IpxNativity nativity;
  final String? registeredCountry;
  final String? usedCountry;
  final String? countryCode;
  final String? city;
  final int? asn;
  final String? organization;
  final List<IpxDeduction> deductions;

  /// Only ever read off a score ipx.al gave.
  IpxGrade? get grade => switch (score) {
    final score? => IpxGrade.of(score),
    null => null,
  };

  /// The ones that took points off first, the most first; checks that took
  /// none, or did not say, last.
  List<IpxDeduction> get sortedDeductions {
    int key(IpxDeduction deduction) => switch (deduction.points) {
      final points? when points < 0 => points,
      0 => 1,
      _ => 2,
    };
    // List.sort is not stable; ties keep ipx.al's order.
    final order = [for (var i = 0; i < deductions.length; i++) i]
      ..sort((a, b) {
        final byPoints = key(deductions[a]).compareTo(key(deductions[b]));
        return byPoints != 0 ? byPoints : a.compareTo(b);
      });
    return [for (final i in order) deductions[i]];
  }

  @override
  bool operator ==(Object other) =>
      other is IpxReport &&
      other.ip == ip &&
      other.score == score &&
      other.ceiling == ceiling &&
      other.type == type &&
      other.nativity == nativity &&
      other.registeredCountry == registeredCountry &&
      other.usedCountry == usedCountry &&
      other.countryCode == countryCode &&
      other.city == city &&
      other.asn == asn &&
      other.organization == organization &&
      listEquals(other.deductions, deductions);

  @override
  int get hashCode => Object.hash(
    ip,
    score,
    ceiling,
    type,
    nativity,
    registeredCountry,
    usedCountry,
    countryCode,
    city,
    asn,
    organization,
    Object.hashAll(deductions),
  );
}

IpxIpType _type(Object? verdict) => switch (verdict) {
  'isp' => IpxIpType.residential,
  'mobile' => IpxIpType.mobile,
  'edu' => IpxIpType.education,
  'business' => IpxIpType.business,
  'hosting' => IpxIpType.hosting,
  'pseudo' => IpxIpType.pseudo,
  _ => IpxIpType.unknown,
};

Map<String, dynamic> _decode(String body) {
  final Object? json = jsonDecode(body);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('ipx.al answered without an object');
  }
  if (json['error'] != null) {
    throw const FormatException('ipx.al answered with an error');
  }
  return json;
}

String _requireIp(Map<String, dynamic> json) {
  final ip = _text(json['ip']);
  if (ip == null) {
    throw const FormatException('ipx.al answered without an address');
  }
  return ip;
}

Map<String, dynamic> _object(Object? value) {
  return value is Map<String, dynamic> ? value : const {};
}

List<Map<String, dynamic>> _list(Object? value) {
  return value is List ? value.whereType<Map<String, dynamic>>().toList() : [];
}

String? _text(Object? value) {
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

int? _asn(Object? value) {
  final asn = switch (value) {
    final int number => number,
    final String text => int.tryParse(
      RegExp(r'\d+').firstMatch(text)?[0] ?? '',
    ),
    _ => null,
  };
  return asn == 0 ? null : asn;
}
