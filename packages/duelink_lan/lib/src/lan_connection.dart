import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:duelink/duelink.dart';

/// 局域网TCP连接实现
class LanConnection implements DuelConnection {
  Socket? _socket;
  final _messageController = StreamController<Uint8List>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  ConnectionState _state = ConnectionState.disconnected;

  @override
  Future<void> connect(String address, int port) async {
    _state = ConnectionState.connecting;
    _stateController.add(_state);

    try {
      _socket = await Socket.connect(address, port);
      _state = ConnectionState.connected;
      _stateController.add(_state);

      _socket!.listen(
        (data) {
          _messageController.add(data);
        },
        onError: (error) {
          _state = ConnectionState.error;
          _stateController.add(_state);
        },
        onDone: () {
          _state = ConnectionState.disconnected;
          _stateController.add(_state);
        },
      );
    } catch (e) {
      _state = ConnectionState.error;
      _stateController.add(_state);
      rethrow;
    }
  }

  @override
  void send(Uint8List data) {
    _socket?.add(data);
  }

  @override
  Stream<Uint8List> get messages => _messageController.stream;

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Stream<ConnectionState> get state => _stateController.stream;
}
