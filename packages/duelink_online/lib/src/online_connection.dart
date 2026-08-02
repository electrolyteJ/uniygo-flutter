import 'dart:async';
import 'dart:developer' as console;
import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 在线WebSocket连接实现。
///
/// 工作在 [YgoCtosMsg] / [YgoStocMsg] 消息对象上，
/// 线格式由 duelink 的 [encodeCtos] / [decodeStocs] 负责。
class OnlineConnection implements DuelConnection {
  WebSocketChannel? _channel;
  final _msgCtrl = StreamController<YgoStocMsg>.broadcast();
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
          final bytes = data is List<int> ? Uint8List.fromList(data) : data as Uint8List;
          for (final s in decodeStocs(bytes)) {
            _msgCtrl.add(s);
          }
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
  void send(YgoCtosMsg msg) {
    if (_state != ConnectionState.connected || _channel == null) {
      console.log(
        'Ignoring send while connection state is $_state: $msg',
      );
      return;
    }
    try {
      _channel!.sink.add(encodeCtos(msg));
    } on StateError catch (e) {
      console.log('Ignoring send on closed socket: $e');
      _state = ConnectionState.disconnected;
      _stateController.add(_state);
    }
  }

  @override
  Stream<YgoStocMsg> get messages => _msgCtrl.stream;

  @override
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Stream<ConnectionState> get state => _stateController.stream;
}
