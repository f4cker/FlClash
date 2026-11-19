import 'dart:async';

/// At most one run per key: a call made while one runs joins it and gets the
/// same result, or the same error, instead of starting another.
class SingleFlight<K, V> {
  final _running = <K, Future<V>>{};

  bool isRunning(K key) => _running.containsKey(key);

  Future<V> run(K key, Future<V> Function() task) {
    final running = _running[key];
    if (running != null) {
      return running;
    }
    // A task that throws before its first await fails this future like any
    // other error, and the key is freed once it settles either way.
    final future = Future<V>.sync(task);
    _running[key] = future;
    unawaited(
      future
          .whenComplete(() {
            if (identical(_running[key], future)) {
              _running.remove(key);
            }
          })
          .then<void>((_) {}, onError: (_) {}),
    );
    return future;
  }
}
