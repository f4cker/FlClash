import 'dart:async';
import 'dart:typed_data';

import 'macos_helper_client.dart';
import 'transport.dart';

final class MacHelperTransport implements DesktopCoreTransport {
  final MacHelperClient client;
  final _events = StreamController<DesktopTransportEvent>.broadcast();
  final _frames = StreamController<Uint8List>.broadcast();
  StreamSubscription<MacHelperEvent>? _subscription;
  DesktopTransportState _state = DesktopTransportState.idle;
  TransportConnected? _connection;
  int _generation = 0;

  MacHelperTransport(this.client);

  @override
  String get address => 'xpc:com.layoute.flash.helper';
  @override
  DesktopTransportState get state => _state;
  @override
  TransportConnected? get connection => _connection;
  @override
  Stream<DesktopTransportEvent> get events => _events.stream;
  @override
  Stream<Uint8List> get frames => _frames.stream;

  @override
  Future<void> open() async {
    if (_state == DesktopTransportState.closed) {
      throw StateError('Transport closed');
    }
    if (_subscription != null) return;
    _subscription = client.events.listen((event) {
      switch (event) {
        case MacHelperConnected(:final pid):
          _state = DesktopTransportState.connected;
          final connection = TransportConnected(
            pid: pid,
            generation: ++_generation,
          );
          _connection = connection;
          _events.add(connection);
        case MacHelperDisconnected(:final error):
          if (_connection == null) return;
          _connection = null;
          _state = DesktopTransportState.ready;
          _events.add(TransportDisconnected(_generation, error: error));
        case MacHelperFrame(:final data):
          if (_connection != null) _frames.add(data);
      }
    });
    _state = DesktopTransportState.ready;
    _events.add(const TransportReady());
  }

  @override
  Future<TransportConnected> waitUntilConnected(Duration timeout) async {
    final connection = _connection;
    if (connection != null) return connection;
    return _events.stream
        .where((event) => event is TransportConnected)
        .cast<TransportConnected>()
        .first
        .timeout(timeout);
  }

  /// The lifecycle owns one transport and resets it to drop a peer whose
  /// disconnect has not arrived; the relay is per session, so only the local
  /// view of it goes. Generations keep counting across resets.
  @override
  Future<void> reset() async {
    if (_state == DesktopTransportState.closed) {
      throw StateError('Transport closed');
    }
    final connection = _connection;
    _connection = null;
    await _subscription?.cancel();
    _subscription = null;
    _state = DesktopTransportState.idle;
    if (connection != null) {
      _events.add(
        TransportDisconnected(
          connection.generation,
          error: StateError('Helper transport was reset'),
        ),
      );
    }
  }

  @override
  void send(List<int> frame) => client.send(frame);

  @override
  Future<void> close() async {
    if (_state == DesktopTransportState.closed) return;
    _state = DesktopTransportState.closed;
    await _subscription?.cancel();
    await _events.close();
    await _frames.close();
  }
}
