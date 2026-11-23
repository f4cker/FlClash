import 'package:dio/dio.dart';
import 'package:fl_clash/common/print.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compactError compacts DioException to type and status code', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 403,
      ),
    );
    expect(compactError(error), 'DioException(badResponse, HTTP 403)');
  });

  test('compactError omits the status code when the response is missing', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.connectionError,
    );
    expect(compactError(error), 'DioException(connectionError)');
  });

  test('compactError keeps other exception messages', () {
    expect(compactError(StateError('boom')), contains('boom'));
  });

  test('redactUrls keeps only scheme and host of every URL', () {
    expect(
      redactUrls(
        'Get "https://user:pw@sub.example.com/api/v1?token=abc123": EOF '
        'and http://1.2.3.4:8080/x/y',
      ),
      'Get "https://sub.example.com/…": EOF and http://1.2.3.4:8080/…',
    );
    expect(redactUrls('no link here'), 'no link here');
  });

  test('redactUrls drops a token that sits right after the host', () {
    expect(
      redactUrls('https://sub.example.com?token=abc'),
      'https://sub.example.com/…',
    );
  });

  test('redactUrls keeps only the scheme of a share link', () {
    expect(
      redactUrls(
        'vmess://eyJhZGQiOiIxLjIuMy40In0= and ss://YWVzOnB3QGhvc3Q6MQ',
      ),
      'vmess://… and ss://…',
    );
  });

  test('redactUrls drops a login with an @ or / in its password', () {
    expect(redactUrls('https://u:p@ss@host.com/x'), 'https://host.com/…');
    expect(redactUrls('https://u:pa/ss@host.com/x'), 'https://…');
  });

  test('redactUrls cuts an age secret key in any case', () {
    const key =
        'AGE-SECRET-KEY-1QYQSZQGPQYQSZQGPQYQSZQGPQYQSZQGPQYQSZQGPQYQSZQGPQYQS7RMN0J';
    expect(
      redactUrls('setup {age-secret-key: $key, path: /p}'),
      'setup {age-secret-key: AGE-SECRET-KEY-…, path: /p}',
    );
    expect(
      redactUrls('key=${key.toLowerCase()} via https://h.example/x?t=1'),
      'key=AGE-SECRET-KEY-… via https://h.example/…',
    );
    expect(
      redactUrls('pq: AGE-SECRET-KEY-PQ-1QYQSZQGPQYQSZQGPQYQSZQGPQ.'),
      'pq: AGE-SECRET-KEY-….',
    );
  });

  test('redactUrls leaves file paths in stack traces alone', () {
    const frame = '#0 main (file:///Users/a/app/lib/main.dart:10:3)';
    expect(redactUrls(frame), frame);
  });

  test('redactUrls catches a URL glued to a word', () {
    expect(redactUrls('foo_https://h.com/p?t=1'), 'foo_https://h.com/…');
  });

  test('redactUrls drops a digit password that looks like a port', () {
    expect(redactUrls('https://user:1234/x@host.com/p'), 'https://…');
  });

  test('redactUrls cuts a web link with an empty host', () {
    expect(redactUrls('https:///x?token=abc'), 'https://…');
  });

  test('redactUrls never takes a token after a path @ for the host', () {
    expect(redactUrls('https://sub.example/s/@a1B2c3TOKEN'), 'https://…');
    expect(redactUrls('https://h/api?u=x@SECRET123'), 'https://…');
  });
}
