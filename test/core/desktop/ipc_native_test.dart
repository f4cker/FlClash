@TestOn('!windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/core/desktop/transport.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../plugins/code_forge/support.dart' show initEditorNative;

const _wait = Duration(seconds: 5);

Uint8List _frame(String payload) {
  final bytes = utf8.encode(payload);
  final header = ByteData(4)..setUint32(0, bytes.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...bytes]);
}

void main() {
  late Directory directory;
  late String address;
  late IpcCoreTransport transport;

  setUpAll(initEditorNative);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ipc');
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

  test('an address that cannot be bound fails the transport', () async {
    // Only the socket's own directory is created; a missing grandparent is not.
    final unbindable = IpcCoreTransport(
      address: '${directory.path}/missing/nested/core.sock',
    );

    await expectLater(unbindable.open(), throwsA(anything));

    expect(unbindable.state, DesktopTransportState.failed);
    expect(Directory('${directory.path}/missing').existsSync(), isFalse);
    await unbindable.close();
  });

  group('macOS private socket directory', () {
    test('an absent directory is created owner-only', () async {
      final private = IpcCoreTransport(
        address: '${directory.path}/app-501/core.sock',
      );

      await private.open();

      expect(
        FileStat.statSync('${directory.path}/app-501').mode & 0x1ff,
        0x1c0,
      );
      await private.close();
      expect(
        FileSystemEntity.typeSync('${directory.path}/app-501/core.sock'),
        FileSystemEntityType.notFound,
      );
    });

    test('a directory others can enter is refused and kept', () async {
      final shared = Directory('${directory.path}/shared')..createSync();
      await Process.run('chmod', ['755', shared.path]);
      final refused = IpcCoreTransport(address: '${shared.path}/core.sock');

      await expectLater(refused.open(), throwsA(contains('refusing')));

      expect(FileStat.statSync(shared.path).mode & 0x1ff, 0x1ed);
      await refused.close();
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
