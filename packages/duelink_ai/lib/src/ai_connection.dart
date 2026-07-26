import 'dart:async';
import 'dart:typed_data';
import 'package:duelink/duelink.dart';

/// AI本地连接实现（模拟服务器）
class AiConnection implements DuelConnection {
  final _messageController = StreamController<Uint8List>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  ConnectionState _state = ConnectionState.disconnected;

  @override
  Future<void> connect(String address, int port) async {
    _state = ConnectionState.connecting;
    _stateController.add(_state);

    // 模拟连接成功
    _state = ConnectionState.connected;
    _stateController.add(_state);
  }

  @override
  void send(Uint8List data) {
    // 处理AI逻辑，生成响应
    // 需要与ocgcore集成
  }

  @override
  Stream<Uint8List> get messages => _messageController.stream;

  @override
  Future<void> disconnect() async {
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  /// 注入AI响应数据（用于测试）
  void injectResponse(Uint8List data) => _messageController.add(data);
}
