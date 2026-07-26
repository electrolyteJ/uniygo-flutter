import 'dart:async';
import 'dart:developer' as console;
import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 在线WebSocket连接实现
class OnlineConnection implements DuelConnection {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Uint8List>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  ConnectionState _state = ConnectionState.disconnected;

  @override
  Future<void> connect(String address, int port) async {
    _state = ConnectionState.connecting;
    _stateController.add(_state);
    try {
      console.log('Connecting to wss://$address:$port');
      _channel = WebSocketChannel.connect(Uri.parse('wss://$address:$port'));
      await _channel!.ready;
      _state = ConnectionState.connected;
      _stateController.add(_state);
      _channel!.stream.listen(
        (data) {
          _messageController.add(data is List<int> ? Uint8List.fromList(data) : data as Uint8List);
        },
        onError: (e) {
          console.log('WebSocket error: $e');
          _state = ConnectionState.error;
          _stateController.add(_state);
        },
        onDone: () {
          console.log('WebSocket connection closed');
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
  void send(Uint8List data) => _channel?.sink.add(data);

  @override
  Stream<Uint8List> get messages => _messageController.stream;

  @override
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Stream<ConnectionState> get state => _stateController.stream;
}
