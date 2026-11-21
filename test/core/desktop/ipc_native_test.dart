@TestOn('!windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/core/desktop/socket_address.dart';
import 'package:fl_clash/core/desktop/transport.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../plugins/code_forge/support.dart' show initEditorNative;

const _wait = Duration(seconds: 5);

Uint8List _frame(String payload) {
  final bytes = utf8.encode(payload);
  final header = ByteData(4)..setUint32(0, bytes.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...bytes]);
}

/// Socket directories must sit directly in the per-user temp dir on macOS.
final Directory _base = Platform.isMacOS
    ? Directory(darwinUserTempDir())
    : Directory.systemTemp;

void main() {
  late Directory directory;
  late String address;
  late IpcCoreTransport transport;

  setUpAll(initEditorNative);

  setUp(() async {
    directory = await _base.createTemp('ipc');
    address = '${directory.path}/core.sock';
    transport = IpcCoreTransport(address: address);
  });

  tearDown(() async {
    await transport.close();
    await directory.delete(recursive: true);
  });

  Future<Socket> connect() {
    return Socket.connect(
      InternetAddress(address, type: InternetAddressType.unix),
      0,
    );
  }

  test('a socket peer exchanges frames with the transport', () async {
    await transport.open();
    expect(
      FileSystemEntity.typeSync(address),
      FileSystemEntityType.unixDomainSock,
    );

    final connected = transport.waitUntilConnected(_wait);
    final peer = await connect();
    final received = StreamIterator(peer);
    expect((await connected).generation, 1);

    final incoming = transport.frames.first.timeout(_wait);
    peer.add(_frame('ping'));
    expect(utf8.decode(await incoming), 'ping');

    transport.send(utf8.encode('pong'));
    expect(await received.moveNext().timeout(_wait), isTrue);
    expect(received.current, _frame('pong'));

    final disconnected = transport.events
        .where((event) => event is TransportDisconnected)
        .cast<TransportDisconnected>()
        .first
        .timeout(_wait);
    await received.cancel();
    peer.destroy();
    expect((await disconnected).generation, 1);
    expect(transport.state, DesktopTransportState.ready);

    await transport.close();
    expect(FileSystemEntity.typeSync(address), FileSystemEntityType.notFound);
  });

  test('sending without a peer is refused', () async {
    await transport.open();

    expect(
      () => transport.send(utf8.encode('early')),
      throwsA(contains('not connected')),
    );
  });

  test(
    'an address that cannot be bound fails the transport',
    () async {
      // Only the socket's own directory is created; a missing grandparent is not.
      // macOS refuses this address earlier; see the private directory group.
      final unbindable = IpcCoreTransport(
        address: '${directory.path}/missing/nested/core.sock',
      );

      await expectLater(unbindable.open(), throwsA(anything));

      expect(unbindable.state, DesktopTransportState.failed);
      expect(Directory('${directory.path}/missing').existsSync(), isFalse);
      await unbindable.close();
    },
    skip: Platform.isMacOS
        ? 'macOS: covered by the nested-address test'
        : false,
  );

  group('macOS private socket directory', () {
    test('an absent directory is created owner-only', () async {
      final absent = '${directory.path}-absent';
      final private = IpcCoreTransport(address: '$absent/core.sock');

      await private.open();

      expect(FileStat.statSync(absent).mode & 0x1ff, 0x1c0);
      await private.close();
      expect(
        FileSystemEntity.typeSync('$absent/core.sock'),
        FileSystemEntityType.notFound,
      );
      Directory(absent).deleteSync();
    });

    test('a nested address is refused before anything is created', () async {
      // The placement check runs before any mkdir, so even the socket's
      // own directory is not made. A missing grandparent inside a valid
      // base is covered in Rust with an injected base.
      final nested = IpcCoreTransport(
        address: '${directory.path}/missing/nested/core.sock',
      );

      await expectLater(
        nested.open(),
        throwsA(contains('not directly inside the per-user temp dir')),
      );

      expect(nested.state, DesktopTransportState.failed);
      expect(directory.listSync(), isEmpty);
      await nested.close();
    });

    test('a socket directory in public /tmp is refused', () async {
      final public = '/tmp/ipc-public-$pid';
      final refused = IpcCoreTransport(address: '$public/core.sock');

      await expectLater(
        refused.open(),
        throwsA(contains('not directly inside the per-user temp dir')),
      );

      expect(Directory(public).existsSync(), isFalse);
      await refused.close();
    });

    test('a directory others can enter is refused and kept', () async {
      final shared = _base.createTempSync('ipcshared');
      await Process.run('chmod', ['755', shared.path]);
      final refused = IpcCoreTransport(address: '${shared.path}/core.sock');

      await expectLater(refused.open(), throwsA(contains('refusing')));

      expect(FileStat.statSync(shared.path).mode & 0x1ff, 0x1ed);
      await refused.close();
      shared.deleteSync();
    });

    test(
      'an existing file at the name is kept and reported as taken',
      () async {
        final taken = File('${directory.path}/taken.sock')
          ..writeAsStringSync('keep');
        final transport = IpcCoreTransport(address: taken.path);

        await expectLater(transport.open(), throwsA(startsWith('EADDRINUSE')));

        expect(taken.readAsStringSync(), 'keep');
        await transport.close();
      },
    );
  }, skip: Platform.isMacOS ? false : 'the private directory is macOS-only');
}
