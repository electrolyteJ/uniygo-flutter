import 'dart:typed_data';
import '../../constants.dart';

/// MSG_WAITING (0x03) — 等待对手操作通知
///
/// 服务端通知客户端等待对手操作。
/// 此消息没有附加负载数据。
///
/// 有线格式 (0 字节): 空负载，仅通过消息号传递事件。
///
/// 参考 neos-ts 的 wait.ts 定义。
class MsgWait {
  const MsgWait();

  int get funcId => MSG_WAITING;

  Uint8List encode() => Uint8List(0);

  static MsgWait decode(Uint8List data) => const MsgWait();

  @override
  String toString() => 'MsgWait()';
}
