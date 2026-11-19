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
    late final Future<V> future;
    future = () async {
      try {
        return await task();
      } finally {
        if (identical(_running[key], future)) {
          unawaited(_running.remove(key));
        }
      }
    }();
    _running[key] = future;
    return future;
  }
}
