import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/native_load_verification.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = 'synthetic_token_1234';
const _args = [nativeLoadVerificationFlag, '--challenge=$_token'];

class _Harness {
  bool isMacOS = true;
  bool releaseMode = true;
  bool managedHelper = true;
  final events = <String>[];
  final lines = <String>[];
  final statuses = <int>[];
  Future<bool> Function(String)? handshake;
  List<Future<bool> Function()>? probes;
  Future<void> Function()? flush;
  Duration timeout = const Duration(seconds: 1);

  Future<void> run([List<String> args = _args]) => runNativeLoadVerification(
    args,
    runtime: NativeLoadVerificationRuntime(
      isMacOS: isMacOS,
      releaseMode: releaseMode,
      managedHelper: managedHelper,
      handshake: (token) async {
        events.add('handshake:$token');
        return await handshake?.call(token) ?? true;
      },
      probes:
          probes ??
          [
            for (final id in nativeLoadVerificationProbeIds)
              () async {
                events.add(id);
                return true;
              },
          ],
      writeLine: (line) {
        events.add('write');
        lines.add(line);
      },
      flush: () async {
        events.add('flush');
        await flush?.call();
      },
      terminate: (status) {
        events.add('exit');
        statuses.add(status);
      },
      timeout: timeout,
    ),
  );

  Map<String, dynamic> get result {
    expect(lines, hasLength(1));
    expect(lines.single, startsWith(nativeLoadVerificationPrefix));
    return jsonDecode(
          lines.single.substring(nativeLoadVerificationPrefix.length),
        )
        as Map<String, dynamic>;
  }
}

void main() {
  group('reserved diagnostic arguments', () {
    test('ordinary invocations remain ordinary', () {
      expect(isNativeLoadVerificationRequested([]), isFalse);
      expect(isNativeLoadVerificationRequested(['clash://example']), isFalse);
      expect(nativeLoadVerificationChallenge(_args), _token);
      for (final length in [16, 64]) {
        final token = List.filled(length, 'a').join();
        expect(
          nativeLoadVerificationChallenge([
            nativeLoadVerificationFlag,
            '--challenge=$token',
          ]),
          token,
        );
      }
    });

    final invalid = <List<String>>[
      [nativeLoadVerificationFlag],
      [nativeLoadVerificationFlag, nativeLoadVerificationFlag],
      [..._args, nativeLoadVerificationFlag],
      [..._args, '--challenge=$_token'],
      [..._args, '--output=/private/synthetic'],
      [..._args, 'clash://example'],
      ['--flash-verify-native-load', '--challenge=$_token'],
      ['--flash-verfy-native-loads', '--challenge=$_token'],
      ['--flahs-verify-native-loads', '--challenge=$_token'],
      ['-flash-verify-native-loads', '--challenge=$_token'],
      ['--FLASH-VERIFY-NATIVE-LOADS', '--challenge=$_token'],
      ['--flash-verify-native-loads=true', '--challenge=$_token'],
      ['--challenge=$_token', nativeLoadVerificationFlag],
      ['--challenge=$_token'],
      [nativeLoadVerificationFlag, '--challenge=short'],
      [nativeLoadVerificationFlag, '--challenge=${'a' * 65}'],
      [nativeLoadVerificationFlag, '--challenge=/private/synthetic/path'],
      [nativeLoadVerificationFlag, '--challenge=synthetic_token_1234\n'],
      [nativeLoadVerificationFlag, '--challenge=synthetic_✓_123456'],
    ];
    for (var i = 0; i < invalid.length; i++) {
      test(
        'malformed invocation $i is claimed and rejected without probes',
        () async {
          final args = invalid[i];
          expect(isNativeLoadVerificationRequested(args), isTrue);
          expect(nativeLoadVerificationChallenge(args), isNull);
          final host = _Harness();
          await host.run(args);
          expect(host.result['code'], 'invalid_arguments');
          expect(host.result['challenge'], isNull);
          expect(host.result['probes'].values, everyElement(isFalse));
          expect(host.events, ['write', 'flush', 'exit']);
          expect(host.statuses, [70]);
          expect(host.lines.single, isNot(contains('/private/')));
        },
      );
    }
  });

  test(
    'success requires native handshake and all four positive results',
    () async {
      final host = _Harness();
      await host.run();
      expect(host.result, {
        'schema': 1,
        'challenge': _token,
        'ok': true,
        'code': 'ok',
        'probes': {for (final id in nativeLoadVerificationProbeIds) id: true},
      });
      expect(host.events, [
        'handshake:$_token',
        ...nativeLoadVerificationProbeIds,
        'write',
        'flush',
        'exit',
      ]);
      expect(host.statuses, [0]);
    },
  );

  for (final gate in ['macos', 'release', 'managed']) {
    test('$gate precondition fails before handshake or probes', () async {
      final host = _Harness();
      switch (gate) {
        case 'macos':
          host.isMacOS = false;
        case 'release':
          host.releaseMode = false;
        case 'managed':
          host.managedHelper = false;
      }
      await host.run();
      expect(host.result['code'], 'unsupported_build');
      expect(host.events, ['write', 'flush', 'exit']);
      expect(host.statuses, [70]);
    });
  }

  test('negative handshake cannot reach probes', () async {
    final host = _Harness()..handshake = (_) async => false;
    await host.run();
    expect(host.result['code'], 'native_handshake_failed');
    expect(host.result['probes'].values, everyElement(isFalse));
    expect(host.events, ['handshake:$_token', 'write', 'flush', 'exit']);
    expect(host.statuses, [70]);
  });

  for (var failure = 0; failure < 4; failure++) {
    test(
      'probe $failure failure is nonzero and cannot claim all pass',
      () async {
        var calls = 0;
        final host = _Harness()
          ..probes = [
            for (var i = 0; i < 4; i++)
              () async {
                calls++;
                return i != failure;
              },
          ];
        await host.run();
        expect(host.result['code'], 'probe_failed');
        expect(host.result['ok'], isFalse);
        expect(host.result['probes'], {
          for (var i = 0; i < 4; i++)
            nativeLoadVerificationProbeIds[i]: i < failure,
        });
        expect(calls, failure + 1);
        expect(host.statuses, [70]);
      },
    );
  }

  test('exceptions are redacted and exit without normal cleanup', () async {
    final host = _Harness()
      ..handshake = (_) => throw StateError('/private/synthetic-secret');
    await host.run();
    expect(host.result['code'], 'probe_failed');
    expect(host.lines.single, isNot(contains('synthetic-secret')));
    expect(host.statuses, [70]);
  });

  test(
    'unhandled asynchronous probe errors produce one fixed failure',
    () async {
      final host = _Harness()
        ..probes = [
          () {
            Future<void>.microtask(() => throw StateError('synthetic-secret'));
            return Completer<bool>().future;
          },
          for (var i = 0; i < 3; i++) () async => true,
        ];
      await host.run();
      expect(host.result['code'], 'probe_failed');
      expect(host.lines.single, isNot(contains('synthetic-secret')));
      expect(host.statuses, [70]);
    },
  );

  test(
    'timeout exits and a late result cannot continue probes or emit twice',
    () async {
      final pending = Completer<bool>();
      var calls = 0;
      final host = _Harness()
        ..timeout = Duration.zero
        ..probes = [
          () => pending.future,
          for (var i = 0; i < 3; i++)
            () async {
              calls++;
              return true;
            },
        ];
      await host.run();
      expect(host.result['code'], 'timeout');
      pending.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
      expect(host.lines, hasLength(1));
      expect(host.result['probes'].values, everyElement(isFalse));
      expect(host.statuses, [70]);
    },
  );

  test('flush failure still terminates nonzero', () async {
    final host = _Harness()..flush = () => throw StateError('synthetic-secret');
    await host.run();
    expect(host.lines, hasLength(1));
    expect(host.statuses, [70]);
    expect(host.events.last, 'exit');
  });

  group('same-binary source contract (no application or native execution)', () {
    String read(String path) => File(path).readAsStringSync();

    test('Dart dispatch precedes the unchanged normal startup zone', () {
      final source = read('lib/main.dart');
      final dispatch = source.indexOf(
        'if (isNativeLoadVerificationRequested(args))',
      );
      final zone = source.indexOf('  runZonedGuarded(');
      expect(dispatch, greaterThan(source.indexOf('void main(')));
      expect(dispatch, lessThan(zone));
      expect(source.substring(dispatch, zone), contains('return;'));
      expect(source.indexOf('system.init()'), greaterThan(zone));
      expect(source.indexOf('bootstrap.init(version)'), greaterThan(zone));
    });

    test('isolated probe module has only the allowed imports and effects', () {
      final source = read('lib/common/native_load_verification.dart');
      final imports = RegExp(
        r"^import '([^']+)'.*;",
        multiLine: true,
      ).allMatches(source).map((match) => match[1]).toSet();
      expect(imports, {
        'dart:async',
        'dart:convert',
        'dart:io',
        'dart:ui',
        'package:flutter/foundation.dart',
        'package:flutter/services.dart',
        'package:flutter/widgets.dart',
        'package:objective_c/objective_c.dart',
        'package:rust_api/rust_api.dart',
        'package:sqlite3/sqlite3.dart',
        'macos_managed_native_library.dart',
      });
      for (final forbidden in [
        'runApp(',
        'system.',
        'bootstrap.',
        'appPath',
        'preferences',
        'IpcServer',
        'Hotkey',
        'Process.',
        'HttpClient',
        'File(',
        'Directory(',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
      for (final required in [
        'WidgetsFlutterBinding.ensureInitialized()',
        'ui.PictureRecorder()',
        'drawColor(',
        'picture.toImage(1, 1)',
        'ui.ImageByteFormat.rawRgba',
        'bytes.getUint8(0) == 0x12',
        'image.dispose()',
        'picture.dispose()',
        'RustLib.init(externalLibrary: loadMacosManagedNativeLibrary())',
        'transcodeCharset(',
        "label: 'utf-8'",
        'RustLib.dispose()',
        'NSString(text)',
        'value.toDartString() == text',
        'value.ref.release()',
        'sqlite3.openInMemory()',
        'PRAGMA temp_store = MEMORY',
        'CREATE TABLE proof',
        'INSERT INTO proof',
        'SELECT value FROM proof',
        'db.close()',
        'stdout.writeln',
        'stdout.flush',
        'terminate: exit',
      ]) {
        expect(source, contains(required), reason: required);
      }
    });

    test('native gate precedes controller and all production registrations', () {
      final source = read('macos/Runner/MainFlutterWindow.swift');
      final awake = source.substring(
        source.indexOf('override func awakeFromNib()'),
      );
      expect(
        awake.indexOf('if NativeLoadVerification.requested'),
        lessThan(
          awake.indexOf('let flutterViewController = FlutterViewController()'),
        ),
      );
      expect(
        awake.substring(0, awake.indexOf('let flutterViewController')),
        contains('return'),
      );
      final diagnostic = source.substring(
        source.indexOf('private func startNativeLoadVerification()'),
        source.indexOf('override public func order('),
      );
      expect(
        diagnostic,
        contains(
          'project.dartEntrypointArguments = NativeLoadVerification.arguments',
        ),
      );
      expect(diagnostic, contains('FlutterViewController(project: project)'));
      expect(diagnostic, contains('token == challenge'));
      expect(diagnostic, contains('asyncAfter(deadline: .now() + 20)'));
      expect(
        diagnostic,
        contains('NativeLoadVerification.fail("invalid_arguments")'),
      );
      for (final forbidden in [
        'RegisterGeneratedPlugins',
        'ManagedHelperChannel',
        'ProcessAppChannel',
        'LaunchAtLogin',
        'launch_at_startup',
        'super.awakeFromNib',
        'setFrame',
        'makeKey',
        'orderFront',
      ]) {
        expect(diagnostic, isNot(contains(forbidden)), reason: forbidden);
      }
      final order = source.substring(
        source.indexOf('override public func order('),
      );
      expect(
        order.indexOf('if NativeLoadVerification.requested { return }'),
        lessThan(order.indexOf('super.order')),
      );
      expect(source, contains(r'"^[A-Za-z0-9_-]{16,64}$"'));
      expect(source, contains('arguments.count == 2, arguments[0] == flag'));
      expect(source, contains('Darwin._exit(70)'));
      expect(source, contains('FLASH_NATIVE_LOADS '));
      for (final id in nativeLoadVerificationProbeIds) {
        expect(source, contains('"$id": false'));
      }
    });

    test(
      'hidden diagnostic explicitly starts the engine after handshake setup',
      () {
        final source = read('macos/Runner/MainFlutterWindow.swift');
        final diagnostic = source.substring(
          source.indexOf('private func startNativeLoadVerification()'),
          source.indexOf('override public func order('),
        );
        final run = diagnostic.indexOf(
          'guard controller.engine.run(withEntrypoint: nil) else {',
        );
        expect(
          run,
          greaterThan(diagnostic.indexOf('channel.setMethodCallHandler')),
        );
        expect(run, greaterThan(diagnostic.indexOf('result(true)')));
        expect(
          run,
          greaterThan(diagnostic.indexOf('verificationChannel = channel')),
        );
        expect(
          run,
          greaterThan(diagnostic.indexOf('contentViewController = controller')),
        );
        expect(
          diagnostic.substring(run),
          contains('NativeLoadVerification.fail("engine_start_failed")'),
        );
        for (final forbidden in [
          'viewWillAppear',
          'viewDidAppear',
          'makeKey',
          'orderFront',
          'isRunning',
        ]) {
          expect(diagnostic, isNot(contains(forbidden)), reason: forbidden);
        }
      },
    );

    test('AppDelegate diagnostic lifecycle cannot enter WindowPlugin', () {
      final source = read('macos/Runner/AppDelegate.swift');
      final terminate = source.substring(
        source.indexOf('override func applicationShouldTerminate('),
      );
      expect(
        terminate.indexOf(
          'if NativeLoadVerification.requested { NativeLoadVerification.fail("interrupted") }',
        ),
        lessThan(terminate.indexOf('WindowPlugin.instance')),
      );
      final reopen = source.substring(
        source.indexOf('override func applicationShouldHandleReopen('),
      );
      expect(
        reopen.indexOf('if NativeLoadVerification.requested { return false }'),
        lessThan(reopen.indexOf('WindowPlugin.instance')),
      );
      expect(source, contains('return !NativeLoadVerification.requested'));
    });
  });
}
