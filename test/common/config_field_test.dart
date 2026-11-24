import 'dart:convert';
import 'dart:io';

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
}
