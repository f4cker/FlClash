import 'dart:async';

import 'package:fl_clash/common/proxy.dart';
import 'package:fl_clash/models/models.dart' show ProxyState;
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy.dart';

final _clashMac = MacosServiceProxy.applied(7893, const ['localhost']);

class _FakeProxy implements Proxy {
  final List<String> calls = [];
  Future<bool>? held;
  Error? failure;
  bool readable = true;
  bool restoreSucceeds = true;
  final List<SystemProxySnapshot> restored = [];

  Future<bool> _call(String name) async {
    calls.add(name);
    final error = failure;
    failure = null;
    if (error != null) {
      throw error;
    }
    final result = held ?? Future.value(true);
    held = null;
    return result;
  }

  @override
  Future<SystemProxySnapshot?> snapshotProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) async {
    calls.add('snapshot');
    if (!readable) {
      return null;
    }
    return SystemProxySnapshot(
      services: {'Wi-Fi': _clashMac},
      port: port,
      bypassDomain: bypassDomain,
    );
  }

  @override
  Future<bool> startProxy(int port, [List<String> bypassDomain = const []]) {
    return _call('start $port');
  }

  @override
  Future<bool> restoreProxy(SystemProxySnapshot snapshot) async {
    restored.add(snapshot);
    final ok = await _call('restore ${snapshot.port}');
    return ok && restoreSucceeds;
  }

  @override
  Future<bool> stopProxy() => _call('stop');
}

class _FakeStore implements SystemProxyStore {
  _FakeStore([this.snapshot]);

  SystemProxySnapshot? snapshot;
  final List<String> calls = [];

  @override
  Future<SystemProxySnapshot?> read() async {
    calls.add('read');
    return snapshot;
  }

  @override
  Future<void> write(SystemProxySnapshot snapshot) async {
    calls.add('write ${snapshot.port}');
    this.snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    calls.add('clear');
    snapshot = null;
  }
}

ProxyState _state({
  required bool isStart,
  bool systemProxy = true,
  int port = 7890,
}) {
  return ProxyState(
    isStart: isStart,
    systemProxy: systemProxy,
    bassDomain: const ['localhost'],
    port: port,
  );
}

void main() {
  test('applies changes in the order they come', () async {
    final proxy = _FakeProxy();
    final queue = SystemProxyQueue(proxy);

    unawaited(queue.apply(_state(isStart: true)));
    await queue.apply(_state(isStart: false));

    expect(proxy.calls, ['snapshot', 'start 7890', 'restore 7890']);
  });

  test('close restores last and drops the starts queued before it', () async {
    final proxy = _FakeProxy();
    final queue = SystemProxyQueue(proxy);
    final inFlight = Completer<bool>();
    proxy.held = inFlight.future;

    unawaited(queue.apply(_state(isStart: true)));
    await pumpEventQueue();
    unawaited(queue.apply(_state(isStart: true)));
    final closed = queue.close();
    await pumpEventQueue();
    expect(proxy.calls, ['snapshot', 'start 7890']);

    inFlight.complete(true);
    await closed;
    await queue.apply(_state(isStart: true));

    expect(proxy.calls, ['snapshot', 'start 7890', 'restore 7890']);
  });

  test('a failing call does not stall the queue', () async {
    final proxy = _FakeProxy();
    final queue = SystemProxyQueue(proxy);
    proxy.failure = StateError('channel gone');

    await queue.apply(_state(isStart: true));
    await queue.apply(_state(isStart: false));

    expect(proxy.calls, ['snapshot', 'start 7890', 'restore 7890']);
  });

  test('leaves a proxy it never set alone on stop and exit', () async {
    final proxy = _FakeProxy();
    final store = _FakeStore();
    final queue = SystemProxyQueue(proxy, store: store);

    await queue.apply(_state(isStart: false));
    await queue.apply(_state(isStart: true, systemProxy: false));
    await queue.close();

    expect(proxy.calls, isEmpty);
    expect(store.calls, ['read']);
  });

  test('tries a failed restore again on close', () async {
    final proxy = _FakeProxy();
    final queue = SystemProxyQueue(proxy);

    await queue.apply(_state(isStart: true));
    proxy.held = Future.value(false);
    await queue.apply(_state(isStart: false));
    await queue.close();
    await queue.close();

    expect(proxy.calls, [
      'snapshot',
      'start 7890',
      'restore 7890',
      'restore 7890',
    ]);
  });

  test('records the snapshot before it changes anything', () async {
    final proxy = _FakeProxy();
    final store = _FakeStore();
    final queue = SystemProxyQueue(proxy, store: store);
    proxy.held = Future(() {
      expect(store.snapshot?.services, {'Wi-Fi': _clashMac});
      return true;
    });

    await queue.apply(_state(isStart: true));

    expect(store.calls, ['read', 'write 7890']);
    expect(store.snapshot?.port, 7890);
  });

  test('clears the record once the restore went through', () async {
    final proxy = _FakeProxy();
    final store = _FakeStore();
    final queue = SystemProxyQueue(proxy, store: store);

    await queue.apply(_state(isStart: true));
    await queue.apply(_state(isStart: false));

    expect(store.calls, ['read', 'write 7890', 'clear']);
    expect(store.snapshot, isNull);
    expect(proxy.restored.single.services, {'Wi-Fi': _clashMac});
  });

  test('keeps the record when the restore could not finish', () async {
    final proxy = _FakeProxy()..restoreSucceeds = false;
    final store = _FakeStore();
    final queue = SystemProxyQueue(proxy, store: store);

    await queue.apply(_state(isStart: true));
    await queue.close();

    expect(store.calls, ['read', 'write 7890']);
    expect(store.snapshot, isNotNull);
  });

  test('does not touch a proxy it cannot read first', () async {
    final proxy = _FakeProxy()..readable = false;
    final store = _FakeStore();
    final queue = SystemProxyQueue(proxy, store: store);

    await queue.apply(_state(isStart: true));
    await queue.close();

    expect(proxy.calls, ['snapshot']);
    expect(store.calls, ['read']);
  });

  test('a port change keeps the first snapshot and restores once', () async {
    final proxy = _FakeProxy();
    final store = _FakeStore();
    final queue = SystemProxyQueue(proxy, store: store);

    await queue.apply(_state(isStart: true));
    await queue.apply(_state(isStart: true, port: 7900));
    await queue.close();

    expect(proxy.calls, [
      'snapshot',
      'start 7890',
      'start 7900',
      'restore 7900',
    ]);
    expect(proxy.restored.single.services, {'Wi-Fi': _clashMac});
    expect(store.calls, ['read', 'write 7890', 'write 7900', 'clear']);
  });

  test('a record left by a crash is restored at the next launch', () async {
    final proxy = _FakeProxy();
    final store = _FakeStore(
      SystemProxySnapshot(
        services: {'Wi-Fi': _clashMac},
        port: 7890,
        bypassDomain: const ['localhost'],
      ),
    );
    final queue = SystemProxyQueue(proxy, store: store);

    await queue.apply(_state(isStart: false));

    expect(proxy.calls, ['restore 7890']);
    expect(store.snapshot, isNull);
  });

  test('a failed recovery keeps the old snapshot for the next start', () async {
    final saved = SystemProxySnapshot(
      services: {'Wi-Fi': _clashMac},
      port: 7890,
      bypassDomain: const ['localhost'],
    );
    final proxy = _FakeProxy()..restoreSucceeds = false;
    final store = _FakeStore(saved);
    final queue = SystemProxyQueue(proxy, store: store);

    await queue.apply(_state(isStart: true, port: 7900));

    expect(proxy.calls, ['restore 7890', 'start 7900']);
    expect(store.snapshot?.services, saved.services);
    expect(store.snapshot?.port, 7900);
  });

  test('a platform without read-back keeps nothing on disk', () async {
    final proxy = _NonRestorableProxy();
    final store = _FakeStore();
    final queue = SystemProxyQueue(proxy, store: store);

    await queue.apply(_state(isStart: true));
    await queue.apply(_state(isStart: false));

    expect(proxy.calls, ['snapshot', 'start 7890', 'restore 7890']);
    expect(store.calls, ['read']);
  });

  group('unchangedSince', () {
    test('a run that never set the proxy left it unchanged', () async {
      final proxy = _FakeProxy();
      final queue = SystemProxyQueue(proxy, store: _FakeStore());
      final mark = queue.startCount;

      await queue.apply(_state(isStart: false));
      await queue.apply(_state(isStart: true, systemProxy: false));

      expect(await queue.unchangedSince(mark), isTrue);
      expect(proxy.calls, isEmpty);
    });

    test('a start earlier in the run counts even once restored', () async {
      final proxy = _FakeProxy();
      final queue = SystemProxyQueue(proxy, store: _FakeStore());
      final mark = queue.startCount;

      await queue.apply(_state(isStart: true));
      await queue.apply(_state(isStart: false));

      expect(proxy.calls, ['snapshot', 'start 7890', 'restore 7890']);
      expect(await queue.unchangedSince(mark), isFalse);
      expect(await queue.unchangedSince(queue.startCount), isTrue);
    });

    test('a start it could not read first still counts', () async {
      final proxy = _FakeProxy()..readable = false;
      final queue = SystemProxyQueue(proxy);
      final mark = queue.startCount;

      await queue.apply(_state(isStart: true));

      expect(await queue.unchangedSince(mark), isFalse);
    });

    test('a snapshot still held is not unchanged', () async {
      final proxy = _FakeProxy()..restoreSucceeds = false;
      final queue = SystemProxyQueue(proxy, store: _FakeStore());
      await queue.apply(_state(isStart: true));
      await queue.apply(_state(isStart: false));
      final mark = queue.startCount;

      expect(await queue.unchangedSince(mark), isFalse);
    });

    test('a record a crashed run left is not unchanged', () async {
      final store = _FakeStore(
        SystemProxySnapshot(
          services: {'Wi-Fi': _clashMac},
          port: 7890,
          bypassDomain: const ['localhost'],
        ),
      );
      final proxy = _FakeProxy();
      final queue = SystemProxyQueue(proxy, store: store);

      expect(await queue.unchangedSince(queue.startCount), isFalse);
      expect(proxy.calls, isEmpty);
      expect(store.snapshot, isNotNull);
    });

    test('waits for a pending start before it answers', () async {
      final proxy = _FakeProxy();
      final queue = SystemProxyQueue(proxy, store: _FakeStore());
      final mark = queue.startCount;
      final inFlight = Completer<bool>();
      proxy.held = inFlight.future;

      unawaited(queue.apply(_state(isStart: true)));
      final answer = queue.unchangedSince(mark);
      inFlight.complete(true);

      expect(await answer, isFalse);
    });

    test('a queue that does not settle cannot tell', () async {
      final proxy = _FakeProxy();
      final queue = SystemProxyQueue(proxy, store: _FakeStore());
      proxy.held = Completer<bool>().future;

      unawaited(queue.apply(_state(isStart: true)));

      expect(
        await queue.unchangedSince(0, wait: const Duration(milliseconds: 20)),
        isFalse,
      );
    });
  });
}

class _NonRestorableProxy extends _FakeProxy {
  @override
  Future<SystemProxySnapshot?> snapshotProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) async {
    calls.add('snapshot');
    return SystemProxySnapshot(
      services: null,
      port: port,
      bypassDomain: bypassDomain,
    );
  }
}
