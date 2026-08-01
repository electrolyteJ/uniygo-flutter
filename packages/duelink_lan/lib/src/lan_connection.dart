import 'dart:async';
import 'dart:io';
import 'package:duelink/duelink.dart';

/// 局域网TCP连接实现。
///
/// 工作在 [YgoCtosMsg] / [YgoStocMsg] 消息对象上，
/// 线格式由 duelink 的 [encodeCtos] / [decodeStocs] 负责。
class LanConnection implements DuelConnection {
  Socket? _socket;
  final _msgCtrl = StreamController<YgoStocMsg>.broadcast();
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
          for (final s in decodeStocs(data)) {
            _msgCtrl.add(s);
          }
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
  void send(YgoCtosMsg msg) {
    _socket?.add(encodeCtos(msg));
  }

  @override
  Stream<YgoStocMsg> get messages => _msgCtrl.stream;

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Stream<ConnectionState> get state => _stateController.stream;
}
