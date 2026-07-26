import 'dart:async';
import 'dart:typed_data';
import 'package:duelink/duelink.dart';

class MockConnection implements DuelConnection {
  final _messageController = StreamController<Uint8List>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  ConnectionState _state = ConnectionState.disconnected;

  @override
  Future<void> connect(String address, int port) async {
    _state = ConnectionState.connected;
    _stateController.add(_state);
  }

  @override
  void send(Uint8List data) {/* capture for assertions if needed */}

  @override
  Stream<Uint8List> get messages => _messageController.stream;

  @override
  Future<void> disconnect() async {
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  /// Helper to inject a STOC packet for testing
  void injectPacket(Uint8List data) => _messageController.add(data);
}
