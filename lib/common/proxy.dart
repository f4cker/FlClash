import 'dart:async';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart' show ProxyState;
import 'package:rust_api/rust_api.dart' as rust_api;

final proxy = system.isDesktop && hostNetworkWritable ? Proxy() : null;

final systemProxyQueue = proxy == null
    ? null
    : SystemProxyQueue(proxy!, store: const PreferencesSystemProxyStore());

abstract interface class SystemProxyStore {
  Future<SystemProxySnapshot?> read();

  Future<void> write(SystemProxySnapshot snapshot);

  Future<void> clear();
}

final class PreferencesSystemProxyStore implements SystemProxyStore {
  const PreferencesSystemProxyStore();

  @override
  Future<SystemProxySnapshot?> read() => preferences.getSystemProxySnapshot();

  @override
  Future<void> write(SystemProxySnapshot snapshot) =>
      preferences.saveSystemProxySnapshot(snapshot);

  @override
  Future<void> clear() => preferences.clearSystemProxySnapshot();
}

/// Exit's restore goes through the same queue as every other change, so a
/// start still waiting behind a slow call cannot turn the proxy back on after
/// it.
///
/// Flash only ever undoes its own start: before pointing the system proxy at
/// itself it records what was there, and stopping puts that back only where
/// the settings are still exactly what Flash wrote. Without a start of its
/// own on record, a stop changes nothing. The record is kept in the
/// preferences until the restore succeeds, so a run that ended without one
/// is undone on the next launch.
class SystemProxyQueue {
  final Proxy _proxy;
  final SystemProxyStore? _store;
  Future<void> _tail = Future.value();
  bool _closed = false;
  bool _recovered = false;
  SystemProxySnapshot? _snapshot;
  int _starts = 0;

  /// How many times this queue has gone on to set the system proxy. A caller
  /// takes it when a run begins and hands it to [unchangedSince] later.
  int get startCount => _starts;

  SystemProxyQueue(this._proxy, {SystemProxyStore? store}) : _store = store;

  Future<void> apply(ProxyState state) {
    return _enqueue(() async {
      if (_closed) {
        return;
      }
      await _recover();
      if (state.isStart && state.systemProxy) {
        await _start(state.port, state.bassDomain);
      } else {
        await _restore();
      }
    });
  }

  Future<void> close() {
    _closed = true;
    return _enqueue(() async {
      await _recover();
      await _restore();
    });
  }

  /// True only when it is certain that nothing has set the system proxy
  /// since [startCount] was [mark]: every change queued so far has run, none
  /// of them was a start, and no snapshot of an earlier start is still held,
  /// in memory or left on disk by a run that has not been recovered yet.
  /// A queue that does not settle within [wait] cannot tell, so it is false.
  Future<bool> unchangedSince(
    int mark, {
    Duration wait = const Duration(seconds: 3),
  }) async {
    var unchanged = false;
    try {
      await _enqueue(() async {
        final leftOver = !_recovered && await _store?.read() != null;
        unchanged = !leftOver && _starts == mark && _snapshot == null;
      }).timeout(wait);
    } on TimeoutException {
      return false;
    }
    return unchanged;
  }

  Future<void> _recover() async {
    if (_recovered) {
      return;
    }
    _recovered = true;
    final saved = await _store?.read();
    if (saved == null || _snapshot != null) {
      return;
    }
    commonPrint.log('restoring the system proxy left by the last run');
    _snapshot = saved;
    await _restore();
  }

  Future<void> _start(int port, List<String> bypassDomain) async {
    _starts++;
    final snapshot = _snapshot != null
        ? _snapshot!.applying(port, bypassDomain)
        : await _proxy.snapshotProxy(port, bypassDomain);
    if (snapshot == null) {
      commonPrint.log(
        'system proxy left unchanged: its current settings could not be read',
        logLevel: LogLevel.warning,
      );
      return;
    }
    if (snapshot.restorable) {
      await _store?.write(snapshot);
    }
    _snapshot = snapshot;
    if (!await _proxy.startProxy(port, bypassDomain)) {
      _logFailure();
    }
  }

  Future<void> _restore() async {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return;
    }
    if (!await _proxy.restoreProxy(snapshot)) {
      _logFailure();
      return;
    }
    _snapshot = null;
    if (snapshot.restorable) {
      await _store?.clear();
    }
  }

  void _logFailure() {
    commonPrint.log('update system proxy failed', logLevel: LogLevel.warning);
  }

  Future<void> _enqueue(Future<void> Function() task) {
    return _tail = _tail.then((_) => task()).catchError((Object error) {
      commonPrint.log(
        'update system proxy failed: $error',
        logLevel: LogLevel.warning,
      );
    });
  }
}

String proxyEnvCommand(int port, {required bool isWindows}) {
  final url = 'http://127.0.0.1:$port';
  return isWindows ? 'set \$env:all_proxy=$url' : 'export all_proxy=$url';
}
