import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_ROCK_PAPER_SCISSORS (0x84) — 猜拳请求
///
/// 服务端要求玩家进行猜拳（石头剪刀布）。
///
/// 有线格式 (1 字节):
/// | 偏移 | 大小 | 类型  | 说明          |
/// |------|------|-------|---------------|
/// | 0x00 | 1    | uint8 | 玩家 (0 或 1) |
///
/// 参考 neos-ts 的 rockPaperScissors.ts 定义。
class MsgRockPaperScissors {
  final int player;

  const MsgRockPaperScissors({required this.player});

  int get funcId => MSG_ROCK_PAPER_SCISSORS;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    return w.toBytes();
  }

  static MsgRockPaperScissors decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgRockPaperScissors(player: r.readUint8());
  }

  @override
  String toString() => 'MsgRockPaperScissors(player:$player)';
}
