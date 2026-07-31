import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_PAY_LP_COST (0x64) — 支付 LP 代价通知
///
/// 通知客户端某位玩家支付了 LP 作为代价。
///
/// 有线格式 (5 字节):
/// | 偏移 | 大小 | 类型  | 说明               |
/// |------|------|-------|--------------------|
/// | 0x00 | 1    | int8  | 玩家 (0 或 1)      |
/// | 0x01 | 4    | int32 | 支付的 LP 值        |
///
/// 参考 neos-ts 的 payLpCost.ts 定义。
class MsgPayLpCost {
  final int player;
  final int value;

  const MsgPayLpCost({required this.player, required this.value});

  int get funcId => MSG_PAY_LP_COST;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt8(player);
    w.writeInt32(value);
    return w.toBytes();
  }

  static MsgPayLpCost decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgPayLpCost(player: r.readInt8(), value: r.readInt32());
  }

  @override
  String toString() => 'MsgPayLpCost(player:$player value:$value)';
}
