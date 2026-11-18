import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a rewritten exchange as the Core sends it', () {
    final exchange = MitmExchange.fromJson({
      'id': 3,
      'start': '2026-11-18T01:00:00Z',
      'pending': false,
      'duration': 4,
      'method': 'GET',
      'proto': 'HTTP/1.1',
      'url': 'https://example.com/v2/x',
      'status': 200,
      'request-size': 0,
      'response-size': 20,
      'error': '',
      'rewritten': true,
      'rewrite-skipped': true,
      'ttfb': 2,
      'original-url': 'https://example.com/v1/x',
      'connection': 'c',
      'request-header': {
        'Host': ['example.com'],
      },
      'response-header': <String, Object?>{},
      'actions': [
        {
          'rule': '7',
          'kind': 'url-rewrite',
          'phase': 'request',
          'detail': 'header',
        },
        {
          'rule': '9',
          'kind': 'body-rewrite',
          'phase': 'response',
          'detail': 'body',
          'skipped': 'oversize',
        },
      ],
    });
    expect(exchange.originalUrl, 'https://example.com/v1/x');
    expect(exchange.rewritten && exchange.rewriteSkipped, isTrue);
    expect(exchange.actions.first.kind, 'url-rewrite');
    expect(exchange.actions.last.skipped, 'oversize');
    expect(exchange.actions.last.rule, '9');
  });

  test('an exchange from a Core without rewriting still reads', () {
    final summary = MitmExchangeSummary.fromJson({
      'id': 1,
      'start': '2026-11-18T01:00:00Z',
      'url': 'https://example.com/',
    });
    expect(summary.rewritten, isFalse);
    expect(summary.rewriteSkipped, isFalse);
    final exchange = MitmExchange.fromJson({
      'id': 1,
      'start': '2026-11-18T01:00:00Z',
      'actions': <Object?>[],
    });
    expect(exchange.actions, isEmpty);
  });

  test('rewrite status and paste results', () {
    final status = MitmRewriteStatus.fromJson({
      'active': true,
      'body-limit': 1048576,
      'issues': [
        {'rule': '2', 'section': 'map-local', 'message': 'bad'},
      ],
      'rules': [
        {
          'rule': '1',
          'section': 'url-rewrite',
          'hits': 3,
          'skips': 1,
          'last-skip': 'crossHost',
          'last-skip-at': '2026-11-18T01:00:00Z',
        },
      ],
    });
    expect(status.rules.single.hits, 3);
    expect(status.rules.single.lastSkipAt, isNotNull);
    expect(status.issues.single.rule, '2');
    final parse = MitmRewriteParse.fromJson({
      'rules': [
        {'section': 'url-rewrite', 'line': 'a - reject', 'number': 5},
      ],
      'issues': [
        {'line': 2, 'message': 'section [General] is not a rewrite section'},
      ],
    });
    expect(parse.rules.single.number, 5);
    expect(parse.issues.single.line, 2);
  });
}
