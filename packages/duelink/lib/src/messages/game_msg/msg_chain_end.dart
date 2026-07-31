import 'dart:typed_data';
import '../../constants.dart';

/// MSG_CHAIN_END (0x4A) — 连锁结束通知
///
/// 通知客户端当前连锁处理已全部完成。
/// 此消息没有附加负载数据。
///
/// 有线格式 (0 字节): 空负载，仅通过消息号传递事件。
///
/// 参考 neos-ts 的 chainEnd.ts 定义。
class MsgChainEnd {
  const MsgChainEnd();

  int get funcId => MSG_CHAIN_END;

  Uint8List encode() => Uint8List(0);

  static MsgChainEnd decode(Uint8List data) => const MsgChainEnd();

  @override
  String toString() => 'MsgChainEnd()';
}
