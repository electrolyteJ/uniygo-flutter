import 'dart:typed_data';
import '../../constants.dart';

/// MSG_SWAP (0x37) — 场上卡牌交换位置通知
///
/// 通知客户端场上的两张卡牌交换了位置。
/// 此消息没有附加负载数据（位置变化由后续 MSG_MOVE 消息体现）。
///
/// 有线格式 (0 字节): 空负载，仅通过消息号传递事件。
///
/// 参考 neos-ts 的 penetrate.json (key 55) 定义。
class MsgSwap {
  const MsgSwap();

  int get funcId => MSG_SWAP;

  Uint8List encode() => Uint8List(0);

  static MsgSwap decode(Uint8List data) => const MsgSwap();

  @override
  String toString() => 'MsgSwap()';
}
