import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));
  String? names(int id) => {7: 'LiteCN 机场', 8: ''}[id];

  test('a named source reads as its subscription in each status', () {
    expect(
      mountRejectedReason('mount source 7 is missing', zh, sourceName: names),
      '订阅「LiteCN 机场」的本地副本缺失。',
    );
    expect(
      mountRejectedReason(
        'parse: mount source 7 is read-error',
        zh,
        sourceName: names,
      ),
      zh.mountSourceReadErrorReason('LiteCN 机场'),
    );
    expect(
      mountRejectedReason('mount source 7 is invalid', en, sourceName: names),
      en.mountSourceInvalidReason('LiteCN 机场'),
    );
    expect(
      mountRejectedReason(
        'mount source 7 is unsupported',
        en,
        sourceName: names,
      ),
      en.mountSourceUnsupportedReason('LiteCN 机场'),
    );
  });

  test('an unknown or unnamed source keeps the Core reason', () {
    expect(
      mountRejectedReason('mount source 9 is missing', zh, sourceName: names),
      'mount source 9 is missing',
    );
    expect(
      mountRejectedReason('mount source 8 is missing', zh, sourceName: names),
      'mount source 8 is missing',
    );
    expect(
      mountRejectedReason('mount source 7 is missing', zh),
      'mount source 7 is missing',
    );
  });

  test('the reason shown never carries a URL path, token or login', () {
    final shown = mountRejectedReason(
      'provider flash-mount-7: https://user:pw@sub.example.com/link?token=abc '
      'and vmess://eyJzZWNyZXQi',
      zh,
    );
    expect(shown, contains('https://sub.example.com/…'));
    expect(shown, contains('vmess://…'));
    expect(shown, isNot(contains('token=abc')));
    expect(shown, isNot(contains('pw@')));
    expect(shown, isNot(contains('eyJzZWNyZXQi')));
    expect(
      mountRejectedReason(
        'mount source 7 is missing',
        zh,
        sourceName: (_) => 'https://sub.example.com/link?token=abc',
      ),
      zh.mountSourceMissingReason('https://sub.example.com/…'),
    );
  });

  test('the reason shown is one short line', () {
    final shown = mountRejectedReason('${'x' * 400}\nsecond line', en);
    expect(shown, '${'x' * 160}…');
    expect(mountRejectedReason('  first\nsecond  ', en), 'first');
  });

  test(
    'respect rules without a Proxy Server Nameserver says how to fix it',
    () {
      for (final l in [zh, en]) {
        expect(
          mountRejectedReason(
            'if “respect-rules” is turned on, “proxy-server-nameserver” cannot '
            'be empty',
            l,
            sourceName: names,
          ),
          l.dnsRespectRulesUnmetError,
        );
      }
    },
  );

  test('only the kept refusal is left to the setup that asked for it', () {
    expect(
      isMountKeptLog(
        'mounted profile rejected, the running config stays: mount source 7 '
        'is missing',
      ),
      isTrue,
    );
    expect(
      isMountKeptLog(
        'mounted profile rejected, every connection is rejected: x',
      ),
      isFalse,
    );
  });
}
