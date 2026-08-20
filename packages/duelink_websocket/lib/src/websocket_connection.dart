import 'dart:async';
import 'dart:developer' as console;
import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket 连接实现。
///
/// 工作在 [YgoCtosMsg] / [YgoStocMsg] 消息对象上，
/// 线格式由 duelink 的 [encodeCtos] / [decodeStocs] 负责。
class WebSocketConnection implements DuelConnection {
  WebSocketChannel? _channel;
  final _msgCtrl = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  ConnectionState _state = ConnectionState.disconnected;

  @override
  Future<void> connect(Uri address) async {
    _state = ConnectionState.connecting;
    _stateController.add(_state);
    try {
      console.log('Connecting to wss://${address.host}:${address.port}');;
      _channel = WebSocketChannel.connect(address);
      await _channel!.ready;
      _state = ConnectionState.connected;
      _stateController.add(_state);
      _channel!.stream.listen(
        (data) {
          final bytes = data is List<int> ? Uint8List.fromList(data) : data as Uint8List;
          // 单批解码失败不应吞掉整批消息：逐包解码并记录失败，
          // 避免一条坏消息导致后续消息（如第二局 MSG_START）被静默丢弃。
          try {
            for (final s in decodeStocs(bytes)) {
              _msgCtrl.add(s);
            }
          } catch (e) {
            console.log('decodeStocs failed (${bytes.length} bytes): $e');
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
