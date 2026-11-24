import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/dns_server.dart';
import 'package:fl_clash/common/hosts_value.dart';
import 'package:fl_clash/l10n/l10n_en.dart';
import 'package:fl_clash/widgets/config_item.dart';
import 'package:flutter_test/flutter_test.dart';

// core/config_field_test.go holds mihomo to the same file.
final _vectors =
    (jsonDecode(
              File(
                'core/testdata/config_field_vectors.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>)
        .map(
          (kind, list) => MapEntry(
            kind,
            (list! as List).cast<Map<String, Object?>>().map(
              (vector) => (
                value: vector['value']! as String,
                ok: vector['ok']! as bool,
              ),
            ),
          ),
        );

void main() {
  final l = AppLocalizationsEn();

  final validators = <String, bool Function(String value)>{
    'nameserver': (value) => validateDnsServer(value, l) == null,
    'default-nameserver': (value) =>
        validateDefaultNameserver(value, l) == null,
    'dns-hijack': (value) => validateDnsHijack(value, l) == null,
    'hosts': isHostsValue,
  };

  for (final MapEntry(key: kind, value: check) in validators.entries) {
    test('$kind takes what mihomo takes and nothing else', () {
      final vectors = _vectors[kind];
      expect(vectors, isNotEmpty);
      for (final vector in vectors!) {
        expect(check(vector.value), vector.ok, reason: vector.value);
      }
    });
  }

  test('each refusal says why', () {
    expect(validateDnsServer('doh://dns.google', l), l.dnsServerSchemeTip);
    expect(validateDnsServer('1.1.1.1:53:53', l), l.dnsServerFormatTip);
    expect(
      validateDefaultNameserver('https://doh.pub/dns-query', l),
      l.defaultNameserverPureIpTip,
    );
    expect(validateDefaultNameserver('tls://223.5.5.5', l), isNull);
  });

  group('a DNS listen address an app port already holds', () {
    UdpInbound? takenBy(String listen, {bool allowLan = false}) =>
        dnsListenTakenBy(
          listen,
          mixedPort: 7890,
          socksPort: 7891,
          allowLan: allowLan,
        );

    test('a wildcard one takes it from either', () {
      expect(takenBy('0.0.0.0:7890'), UdpInbound.mixed);
      expect(takenBy(':7891', allowLan: true), UdpInbound.socks);
      expect(takenBy('[::]:7890'), UdpInbound.mixed);
    });

    test('the loopback one only while the ports are on loopback too', () {
      expect(takenBy('127.0.0.1:7890'), UdpInbound.mixed);
      expect(takenBy('127.0.0.1:7890', allowLan: true), isNull);
      expect(takenBy('[::1]:7890'), isNull);
    });

    test('another port, or a disabled SOCKS port, is free', () {
      expect(takenBy('0.0.0.0:1053'), isNull);
      expect(
        dnsListenTakenBy(
          '0.0.0.0:0',
          mixedPort: 7890,
          socksPort: 0,
          allowLan: false,
        ),
        isNull,
      );
    });
  });

  test('a hosts domain that leads back to itself is a cycle', () {
    expect(hostsCycleOf({'a.com': 'b.com', 'b.com': 'a.com.'}), 'a.com');
    expect(
      hostsCycleOf({'a.com': 'b.com', 'b.com': 'c.com', 'c.com': 'a.com'}),
      'a.com',
    );
    expect(hostsCycleOf({'a.com': 'b.com', 'b.com': '1.1.1.1'}), isNull);
    expect(hostsCycleOf({'a.com': 'b.com', 'c.com': 'b.com'}), isNull);
  });
}
