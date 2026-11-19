import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported capabilities never enter the Go setup', () {
    final content = parseMitmModule(
      r'''
[General]
dns-server = 1.1.1.1
[MITM]
hostname = example.com
skip-server-cert-verify = true
[Script]
Daily = type=cron,cronexp="0 8 * * *",script-path=job.js
[Body Rewrite]
http-response-jq ^https://example.com .ads=[]
''',
      resources: const {'job.js': 'job.js'},
    );
    final rules = flashMitmRules(content);
    expect(rules.script, isEmpty);
    expect(rules.bodyRewrite, isEmpty);
    expect(rules.skipVerifyHostname, isEmpty);
    expect(flashMitmSkipped(content), isNotEmpty);
    expect(flashMitmIssues(content)[MitmList.bodyRewrite], isNotEmpty);
  });

  test('an unsupported client restriction blocks the entire module', () {
    final content = parseMitmModule(r'''
[MITM]
hostname = example.com
client-source-address = 192.0.2.1
[URL Rewrite]
^https://example.com/ad - reject
[Rule]
DOMAIN,example.com,DIRECT
''');
    expect(flashMitmRules(content).hostname, isEmpty);
    expect(flashMitmRules(content).urlRewrite, isEmpty);
    expect(flashModuleRules(content, policies: {'DIRECT'}, exits: {}), isEmpty);
  });

  test('module providers cannot escape resource confinement', () {
    final content = parseMitmModule(
      '''
[Rule]
RULE-SET,local.list,REJECT
''',
      resources: const {'local.list': '../outside.list'},
    );
    expect(
      flashModuleProviders(content, {'local.list': '../outside.list'}),
      isEmpty,
    );
  });

  test('Surge, Loon, QX and Stash imports execute in the Go engine', () async {
    const formats = {
      'Surge': r'''
[URL Rewrite]
^https://example\.com/ad - reject
[Script]
HTTP = type=http-response,pattern=^https://example\.com/a,script-path=script.js,requires-body=true
[MITM]
hostname = example.com
''',
      'Loon': r'''
[Rewrite]
^https://example\.com/ad reject
[Script]
http-response ^https://example\.com/a script-path=script.js, requires-body=true, tag=HTTP
[MitM]
hostname = example.com
''',
      'QX': r'''
[rewrite_local]
^https://example\.com/ad url reject
^https://example\.com/a url script-response-body script.js
[mitm]
hostname = example.com
''',
      'Stash': r'''
name: Fixture
http:
  mitm:
    - example.com
  url-rewrite:
    - ^https://example\.com/ad - reject
  script:
    - match: ^https://example\.com/a
      name: HTTP
      type: response
      require-body: true
script-providers:
  HTTP:
    url: https://fixture.invalid/script.js
''',
    };
    final fixtures = <Map<String, Object?>>[];
    for (final entry in formats.entries) {
      final parsed = parseMitmModule(
        entry.value,
        resources: const {
          'script.js': 'fixture.js',
          'https://fixture.invalid/script.js': 'fixture.js',
        },
      );
      final rules = flashMitmRules(parsed);
      expect(rules.urlRewrite, hasLength(1), reason: entry.key);
      expect(rules.script, hasLength(1), reason: entry.key);
      fixtures.add({
        'name': entry.key,
        'rewrite': [
          for (final line in rules.urlRewrite)
            {'id': entry.key, 'section': 'url-rewrite', 'line': line},
        ],
        'script': rules.script,
      });
    }
    final dir = await Directory.systemTemp.createTemp('flash-module-contract-');
    addTearDown(() => dir.delete(recursive: true));
    final input = File('${dir.path}/normalized.json');
    await input.writeAsString(jsonEncode(fixtures));
    final result = await Process.run(
      'go',
      ['test', '.', '-run', '^TestFlashNormalizedModuleContract\$', '-count=1'],
      workingDirectory: 'core',
      environment: {'CGO_ENABLED': '0', 'FLASH_MODULE_CONTRACT': input.path},
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }, timeout: const Timeout(Duration(minutes: 2)));

  group('hostnames', () {
    test('a :443 is taken off, as the Core decrypts on 443 alone', () {
      expect(flashMitmHostname('a.com:443'), 'a.com');
      expect(flashMitmHostname(' *.a.com:443 '), '*.a.com');
      expect(flashMitmHostname('-a.com:443'), '-a.com');
      // Anything else is left as written, never widened.
      expect(flashMitmHostname('a.com:8443'), 'a.com:8443');
      expect(flashMitmHostname('[::1]:443'), '[::1]:443');
      expect(flashMitmHostname('::443'), '::443');
      expect(flashMitmHostname('a.com'), 'a.com');
    });

    test('lines the Core skips are named as written', () {
      final content = parseMitmModule('''
[MITM]
hostname = %INSERT% x*.a.com
hostname = %APPEND% a.com:443, b.com:8443, -c.com:80, api*.d.com, *e.com, f?.com, 1.2.3.4, [::1], *.ok.com, ok.com, -ok2.com, *
''');
      expect(flashUnusableHostnames(content), [
        'x*.a.com',
        'b.com:8443',
        '-c.com:80',
        'api*.d.com',
        '*e.com',
        'f?.com',
        '1.2.3.4',
        '[::1]',
      ]);
      expect(flashMitmRules(content).hostname, [
        'x*.a.com',
        'a.com',
        'b.com:8443',
        '-c.com:80',
        'api*.d.com',
        '*e.com',
        'f?.com',
        '1.2.3.4',
        '[::1]',
        '*.ok.com',
        'ok.com',
        '-ok2.com',
        '*',
      ]);
    });

    test('a valid :443 line gets no hint; an invalid one does', () {
      expect(
        flashUnusableHostLines(['a.com:443', '*.a.com:443', '-a.com:443']),
        isEmpty,
      );
      expect(
        flashUnusableHostLines([
          'bad_host.com:443',
          '-bad_host.com:443',
          'ex..ample.com:443',
          '1.2.3:443',
          'ok.com:443',
        ]),
        [
          'bad_host.com:443',
          '-bad_host.com:443',
          'ex..ample.com:443',
          '1.2.3:443',
        ],
      );
    });

    test('the hint agrees with the Core on the shared vectors', () {
      final vectors =
          jsonDecode(
                File(
                  'core/testdata/mitm_hostname_vectors.json',
                ).readAsStringSync(),
              )['validate']
              as List;
      for (final vector in vectors.cast<Map<String, Object?>>()) {
        final line = vector['line']! as String;
        // Taken off before the Core sees it; checked above.
        if (line.endsWith(':443')) continue;
        // Too broad and Apple are the Core's to tell.
        expect(
          flashUnusableHostLines([line]).isNotEmpty,
          {'invalid', 'address'}.contains(vector['issue']),
          reason: line,
        );
        // With a :443 the same, as the Core is sent the line without it.
        if (!line.contains(':') && line.trim().isNotEmpty) {
          expect(
            flashUnusableHostLines(['${line.trim()}:443']).isNotEmpty,
            {'invalid', 'address'}.contains(vector['issue']),
            reason: '$line:443',
          );
        }
      }
    });

    test('each skipped line has the reason the syntax shows', () {
      const cases = {
        'b.com:8443': MitmHostReason.unsupportedPort,
        '*.b.com:80': MitmHostReason.unsupportedPort,
        '-c.com:80': MitmHostReason.unsupportedPort,
        '1.2.3.4': MitmHostReason.ipAddress,
        '1.2.3.4:8443': MitmHostReason.ipAddress,
        '::1': MitmHostReason.ipAddress,
        '[2001:db8::1]': MitmHostReason.ipAddress,
        '[::1]:443': MitmHostReason.ipAddress,
        'fe80::1%en0': MitmHostReason.ipAddress,
        '[fe80::1%en0]': MitmHostReason.ipAddress,
        '[fe80::1%en0]:443': MitmHostReason.ipAddress,
        'api*.d.com': MitmHostReason.embeddedWildcard,
        'x*.a.com': MitmHostReason.embeddedWildcard,
        '*.*.example.com': MitmHostReason.embeddedWildcard,
        'api.*.example.com': MitmHostReason.embeddedWildcard,
        '*e.com': MitmHostReason.invalidFormat,
        'f?.com': MitmHostReason.invalidFormat,
        'bad_host.com': MitmHostReason.invalidFormat,
        'ex..ample.com': MitmHostReason.invalidFormat,
        '1.2.3': MitmHostReason.invalidFormat,
        '01.2.3.4': MitmHostReason.invalidFormat,
        'https://example.com': MitmHostReason.invalidFormat,
        'bücher.example': MitmHostReason.invalidFormat,
        '-*': MitmHostReason.invalidFormat,
        '*': MitmHostReason.overBroad,
        // Valid syntax: only the Core can say more.
        'a.com': null,
        '*.a.com': null,
        '-a.com': null,
        '*.com': null,
        'icloud.com': null,
      };
      for (final MapEntry(key: line, value: reason) in cases.entries) {
        expect(flashHostReason(line), reason, reason: line);
      }
    });

    test('a skipped line reads in words, never as the Core code', () {
      loadAppLocalizations(const Locale('en'));
      final l = currentAppLocalizations;
      String text(String line, String? code) =>
          mitmHostIssueText(l, line, code);
      expect(
        text('icloud.com', 'apple-service'),
        l.mitmHostIgnored(l.mitmHostReasonAppleService),
      );
      expect(
        text('*.com', 'over-broad'),
        l.mitmHostIgnored(l.mitmHostReasonOverBroad),
      );
      expect(
        text('x.com', 'invalid'),
        l.mitmHostIgnored(l.mitmHostReasonInvalidFormat),
      );
      // The app's reading is the more specific one.
      expect(
        text('b.com:8443', 'address'),
        l.mitmHostIgnored(l.mitmHostReasonUnsupportedPort),
      );
      expect(
        text('1.2.3.4', 'address'),
        l.mitmHostIgnored(l.mitmHostReasonIpAddress),
      );
      // What neither can tell is not guessed.
      expect(
        text('a.com', 'address'),
        l.mitmHostIgnored(l.mitmHostReasonUnknown),
      );
      expect(
        text('a.com', 'something-new'),
        l.mitmHostIgnored(l.mitmHostReasonUnknown),
      );
      for (final code in [
        'apple-service',
        'over-broad',
        'invalid',
        'address',
      ]) {
        expect(text('a.com', code), isNot(contains(code)));
      }
    });
  });
}
