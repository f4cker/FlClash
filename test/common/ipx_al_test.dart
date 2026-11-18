import 'dart:io';

import 'package:fl_clash/common/ipx_al.dart';
import 'package:flutter_test/flutter_test.dart';

// Saved from https://ipx.al on 2026-11-18. me.json had the address of the
// machine that saved it, replaced with a documentation address.
String fixture(String name) =>
    File('test/fixtures/ipx_al/$name').readAsStringSync();

void main() {
  group('IpxReport.parse', () {
    test('reads a clean data-center address', () {
      final report = IpxReport.parse(fixture('report_8.8.8.8.json'));

      expect(report.ip, '8.8.8.8');
      expect(report.score, 55);
      expect(report.grade, IpxGrade.b);
      expect(report.ceiling, 55);
      expect(report.type, IpxIpType.hosting);
      expect(report.nativity, IpxNativity.native);
      expect(report.registeredCountry, 'US');
      expect(report.usedCountry, 'US');
      expect(report.countryCode, 'US');
      expect(report.city, 'Mountain View');
      expect(report.asn, 15169);
      expect(report.organization, 'GOOGLE - Google LLC');
      expect(report.deductions, hasLength(5));
      expect(report.deductions.every((d) => d.points == 0), isTrue);
      expect(report.deductions.last.label, '未发现 Tor 出口');
      expect(report.deductions.last.note, 'pass');
    });

    test('reads the deductions of a Tor exit', () {
      final report = IpxReport.parse(fixture('report_185.220.101.1.json'));

      expect(report.score, 0);
      expect(report.grade, IpxGrade.d);
      expect(report.countryCode, 'DE');
      expect(
        report.deductions.map((d) => (d.label, d.points, d.source)),
        containsAllInOrder([
          ('Tor 出口', -40, 'IPQuery'),
          ('DNSBL 命中 4/13', -15, 'DNSBL'),
        ]),
      );
      expect(report.deductions.first.note, isNull);
      expect(report.deductions.last.tag, '1 条不计');
    });

    test('takes a broadcast verdict and unknown values', () {
      final report = IpxReport.parse(
        '{"ip":"192.0.2.1","health":{"score":71.6,"items":[{"pts":-5},'
        '{"label":"x","pts":"?"}]},"native":{"verdict":"broadcast"},'
        '"type":{"verdict":"satellite"},"asn":"AS64500"}',
      );

      expect(report.score, 72);
      expect(report.grade, IpxGrade.a);
      expect(report.nativity, IpxNativity.broadcast);
      expect(report.type, IpxIpType.unknown);
      expect(report.asn, 64500);
      expect(report.deductions.single.label, 'x');
      expect(report.deductions.single.points, isNull);
    });

    test('leaves out what ipx.al left out', () {
      final report = IpxReport.parse(
        '{"ip":"192.0.2.1","health":{"items":[{"label":"x","pts":-5}]}}',
      );

      expect(report.score, isNull);
      expect(report.grade, isNull);
      expect(report.ceiling, isNull);
      expect(report.type, IpxIpType.unknown);
      expect(report.nativity, IpxNativity.unknown);
      expect(report.deductions.single.points, -5);
    });

    test('sorts the deductions most points first, none last', () {
      final report = IpxReport.parse(fixture('report_185.220.101.1.json'));

      expect(report.sortedDeductions.map((d) => d.points), [
        -40,
        -15,
        -5,
        -3,
        0,
      ]);
      final mixed = IpxReport.parse(
        '{"ip":"192.0.2.1","health":{"items":[{"label":"a"},'
        '{"label":"b","pts":0},{"label":"c","pts":-1},{"label":"d","pts":0}]}}',
      );
      expect(mixed.sortedDeductions.map((d) => d.label), ['c', 'b', 'd', 'a']);
    });

    test('refuses what is no report', () {
      for (final body in [
        '',
        '<!doctype html>',
        '[]',
        '{"error":{"message":"rate limited"}}',
        '{"health":{"score":50}}',
        '{"ip":"192.0.2.1"}',
      ]) {
        expect(
          () => IpxReport.parse(body),
          throwsFormatException,
          reason: body,
        );
      }
    });
  });

  test('IpxBrief.parse reads /api/me', () {
    final brief = IpxBrief.parse(fixture('me.json'));

    expect(brief.ip, '198.51.100.20');
    expect(brief.countryCode, 'US');
    expect(brief.city, 'Irvine');
    expect(brief.asn, 3356);
    expect(brief.organization, 'Level 3 Parent, LLC');
  });

  test('grades follow ipx.al/about', () {
    expect(
      [
        100,
        85,
        84,
        70,
        69,
        50,
        49,
        30,
        29,
        0,
      ].map((s) => IpxGrade.of(s).letter),
      ['A+', 'A+', 'A', 'A', 'B', 'B', 'C', 'C', 'D', 'D'],
    );
  });

  test('urls name the exit address', () {
    expect(ipxAlReportUrl('8.8.8.8'), 'https://ipx.al/api/report/8.8.8.8');
    expect(
      ipxAlReportUrl('2001:db8::1'),
      'https://ipx.al/api/report/2001%3Adb8%3A%3A1',
    );
    expect(ipxAlPageUrl('8.8.8.8'), 'https://ipx.al/8.8.8.8');
  });
}
