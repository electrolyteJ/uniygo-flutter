import 'dart:async';
import 'package:applog/console.dart' as console;
import 'dart:io';
import 'dart:typed_data';
import 'package:duelink/duelink.dart';

/// TCP Socket 连接实现。
///
/// 工作在 [YgoCtosMsg] / [YgoStocMsg] 消息对象上，
/// 线格式由 duelink 的 [encodeCtos] / [decodeStocs] 负责。
///
/// TCP 是字节流协议：一次 `listen` 回调可能只交付半个包（半包），
/// 也可能多个包合在一起（粘包）。`YgoProPacket.deserialize` 只处理粘包，
/// 不完整的尾部会被丢弃，因此这里必须用 [_recvBuf] 做拼包：
/// 累积字节 → 按帧长切出完整区域解码 → 剩余半包留给下次回调拼接。
class SocketConnection implements DuelConnection {
  Socket? _socket;
  final _msgCtrl = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  ConnectionState _state = ConnectionDisconnected();

  /// 接收拼包缓冲（半包留存）。
  final BytesBuilder _recvBuf = BytesBuilder(copy: false);

  @override
  Future<void> connect(Uri address) async {
    console.log('Connecting to ${address.host}:${address.port}...');
    _state = ConnectionConnecting();
    _stateController.add(_state);
    _recvBuf.clear();

    try {
      _socket = await Socket.connect(address.host, address.port);
      _state = ConnectionConnected();
      _stateController.add(_state);

      _socket!.listen(
        _onData,
        onError: (error) {
          console.log('Socket error: $error');
          _setState(ConnectionError(message: '$error'));
        },
        onDone: () {
          console.log('Socket connection closed');
          _setState(ConnectionDisconnected());
        },
      );
    } catch (e) {
      _setState(ConnectionError(message: '$e'));
      rethrow;
    }
  }

  /// 累积接收字节，切出完整帧解码，不完整尾部留存待下次拼接。
  void _onData(Uint8List data) {
    _recvBuf.add(data);
    final buf = _recvBuf.takeBytes();
    final bd = ByteData.sublistView(buf);

    // 定位完整帧区域 [0, completeEnd)
    var completeEnd = 0;
    while (buf.length - completeEnd >= 3) {
      final packetLen = bd.getUint16(completeEnd, Endian.little);
      if (packetLen < 1) break; // 数据损坏，等待更多字节也无意义
      if (buf.length - completeEnd < packetLen + 2) break; // 半包
      completeEnd += packetLen + 2;
    }

    if (completeEnd > 0) {
      for (final s in decodeStocs(Uint8List.sublistView(buf, 0, completeEnd))) {
        _msgCtrl.add(s);
      }
    }
    // 留存不完整尾部，等下次回调拼接
    if (completeEnd < buf.length) {
      _recvBuf.add(Uint8List.sublistView(buf, completeEnd));
    }
  }

  @override
  void send(YgoCtosMsg msg) {
    final socket = _socket;
    if (_state is! ConnectionConnected || socket == null) {
      console.log('Ignoring send while connection state is $_state: $msg');
      return;
    }
    try {
      socket.add(encodeCtos(msg));
    } on StateError catch (e) {
      console.log('Ignoring send on closed socket: $e');
    } on SocketException catch (e) {
      // 对端 RST（Connection reset by peer）后 socket 对象尚未标记关闭，
      // add 会同步抛 SocketException——若逃逸到心跳/应答的 Timer 回调
      // 就变成未处理异常（crash log 的 PlatformDispatcher 条目）。
      // 发送失败无需上报：对端已断开，连接状态流会走 onDone/onError 通知。
      console.log('Ignoring send on reset socket: $e');
    }
  }

  @override
  Stream<YgoStocMsg> get messages => _msgCtrl.stream;

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    _recvBuf.clear();
    try {
      await socket?.close();
    } catch (e) {
      console.log('Ignoring socket close error: $e');
    }
    _setState(ConnectionDisconnected());
  }

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  void _setState(ConnectionState next) {
    if (_state == next) return;
    _state = next;
    _stateController.add(next);
  }
}
