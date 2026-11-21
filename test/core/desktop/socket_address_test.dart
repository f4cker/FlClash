import 'dart:io';
import 'dart:math';

import 'package:fl_clash/core/desktop/socket_address.dart';
import 'package:flutter_test/flutter_test.dart';

/// A realistic per-user temp dir: `/var/folders/xx/<28>/T`, 48 bytes.
const _base = '/var/folders/7f/kd3c9_4j3vxdyhtsncqtsl2h0000gn/T';
const _nameLength = 26 + 5;

String _baseOf(int length) {
  final base = '/${'b' * (length - 1)}';
  expect(base.length, length);
  return base;
}

void main() {
  group('per-user temp dir', () {
    test('a confstr result is used as is, minus the trailing slash', () {
      expect(userTempDirFrom('$_base/'), _base);
      expect(userTempDirFrom(_base), _base);
    });

    test('a confstr failure is an error, never a fallback to /tmp', () {
      for (final raw in [null, '']) {
        expect(
          () => userTempDirFrom(raw),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('not falling back to /tmp'),
            ),
          ),
        );
      }
    });

    test('a relative confstr result is refused', () {
      expect(() => userTempDirFrom('var/folders/T/'), throwsStateError);
    });

    test('the system value is an absolute directory owned by us', () {
      final base = darwinUserTempDir();

      expect(base, startsWith('/'));
      expect(base, isNot(endsWith('/')));
      expect(FileStat.statSync(base).type, FileSystemEntityType.directory);
      expect(FileStat.statSync(base).mode & 0x3f, 0, reason: 'no group/other');
    }, skip: Platform.isMacOS ? false : 'confstr name is macOS-only');
  });

  group('unix socket address', () {
    test('release, debug and isolated copies get distinct directories', () {
      final subdirs = {
        for (final id in [
          'com.layoute.flash',
          'com.layoute.flash.debug',
          'com.layoute.flash.isolatedtest',
        ])
          unixSocketSubdir(base: _base, appId: id),
      };

      expect(subdirs, hasLength(3));
      // The release id fits whole; the longer ids get the short form.
      expect(
        unixSocketSubdir(base: _base, appId: 'com.layoute.flash'),
        'com.layoute.flash',
      );
      expect(
        unixSocketSubdir(base: _base, appId: 'com.layoute.flash.debug'),
        matches(RegExp(r'^fl-[0-9a-f]{8}$')),
      );
    });

    test('an app id cannot escape the base', () {
      final subdir = unixSocketSubdir(base: '/b', appId: '../../etc/x');
      expect(subdir, isNot(contains('/')));
      expect(subdir.startsWith('.'), isFalse);
    });

    test('ids differing only in sanitised characters get distinct dirs', () {
      final a = unixSocketSubdir(base: '/b', appId: 'com.example/app');
      final b = unixSocketSubdir(base: '/b', appId: 'com.example:app');

      expect(a, matches(RegExp(r'^fl-[0-9a-f]{8}$')));
      expect(b, matches(RegExp(r'^fl-[0-9a-f]{8}$')));
      expect(a, isNot(b));
      expect(
        unixSocketSubdir(base: '/b', appId: 'com.example_app'),
        'com.example_app',
      );
    });

    test('names carry 128 random bits and differ between listeners', () {
      final names = {for (var i = 0; i < 1000; i++) randomSocketName()};

      expect(names, hasLength(1000));
      for (final name in names) {
        expect(name, matches(RegExp(r'^[a-z2-7]{26}\.sock$')));
      }
    });

    test('the real paths fit with the full name entropy', () {
      for (final id in [
        'com.layoute.flash',
        'com.layoute.flash.debug',
        'com.layoute.flash.isolatedtest',
      ]) {
        final directory = '$_base/${unixSocketSubdir(base: _base, appId: id)}';
        final address = unixSocketAddress(directory, Random(1));

        expect(address.length, lessThanOrEqualTo(maxUnixSocketPathLength));
        expect(address.split('/').last.length, _nameLength);
      }
    });

    test('a base that fits exactly at the limit is accepted', () {
      // base + '/' + 'fl-xxxxxxxx' + '/' + name == 103
      final base = _baseOf(maxUnixSocketPathLength - 1 - 11 - 1 - _nameLength);
      final subdir = unixSocketSubdir(base: base, appId: 'x' * 60);
      final address = unixSocketAddress('$base/$subdir');

      expect(address.length, maxUnixSocketPathLength);
    });

    test('a base one byte too long fails clearly, nothing is truncated', () {
      final base = _baseOf(maxUnixSocketPathLength - 11 - 1 - _nameLength);

      expect(
        () => unixSocketSubdir(base: base, appId: 'com.layoute.flash'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('128 random bits'),
          ),
        ),
      );
    });

    test('an address over the limit is refused rather than truncated', () {
      expect(() => unixSocketAddress('/${'d' * 80}'), throwsStateError);
    });

    test('only the Rust in-use marker counts as a taken name', () {
      expect(isAddressInUse('EADDRINUSE: /x/y/z.sock already exists'), isTrue);
      expect(isAddressInUse('refusing IPC socket directory'), isFalse);
    });
  });
}
