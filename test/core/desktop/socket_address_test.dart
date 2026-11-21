import 'dart:math';

import 'package:fl_clash/core/desktop/socket_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('unix socket address', () {
    test('release, debug and isolated copies get distinct directories', () {
      final dirs = {
        for (final id in [
          'com.layoute.flash',
          'com.layoute.flash.debug',
          'com.layoute.flash.isolatedtest',
        ])
          unixSocketDirectory(appId: id, uid: 501),
      };

      expect(dirs, {
        '/tmp/com.layoute.flash-501',
        '/tmp/com.layoute.flash.debug-501',
        '/tmp/com.layoute.flash.isolatedtest-501',
      });
      expect(
        unixSocketDirectory(appId: 'com.layoute.flash', uid: 502),
        isNot(unixSocketDirectory(appId: 'com.layoute.flash', uid: 501)),
      );
    });

    test('an app id cannot escape /tmp', () {
      expect(
        unixSocketDirectory(appId: '../../etc/x', uid: 501),
        '/tmp/app.._.._etc_x-501',
      );
      expect(unixSocketDirectory(appId: '', uid: 501), '/tmp/app-501');
    });

    test('names carry 128 random bits and differ between listeners', () {
      final names = {for (var i = 0; i < 1000; i++) randomSocketName()};

      expect(names, hasLength(1000));
      for (final name in names) {
        expect(name, matches(RegExp(r'^[0-9a-f]{32}\.sock$')));
      }
    });

    test('the longest address stays under the sun_path limit', () {
      final directory = unixSocketDirectory(appId: 'x' * 200, uid: 4294967295);
      final address = unixSocketAddress(directory, Random(1));

      expect(address.length, lessThanOrEqualTo(maxUnixSocketPathLength));
      expect(address, startsWith('$directory/'));
    });

    test('an over-long directory is refused rather than truncated', () {
      expect(() => unixSocketAddress('/${'d' * 80}'), throwsStateError);
    });

    test('only the Rust in-use marker counts as a taken name', () {
      expect(
        isAddressInUse('EADDRINUSE: /tmp/a/b.sock already exists'),
        isTrue,
      );
      expect(isAddressInUse('refusing IPC socket directory'), isFalse);
    });
  });
}
