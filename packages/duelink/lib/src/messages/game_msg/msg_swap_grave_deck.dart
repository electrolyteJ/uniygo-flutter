import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SWAP_GRAVE_DECK (0x23) — 墓地与卡组交换通知
///
/// 通知客户端某位玩家的墓地和卡组内容进行了互换。
///
/// 有线格式 (1 字节):
/// | 偏移 | 大小 | 类型  | 说明          |
/// |------|------|-------|---------------|
/// | 0x00 | 1    | uint8 | 玩家 (0 或 1) |
///
/// 参考 neos-ts 的 penetrate.json (key 35) 定义。
class MsgSwapGraveDeck {
  final int player;

  const MsgSwapGraveDeck({required this.player});

  int get funcId => MSG_SWAP_GRAVE_DECK;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    return w.toBytes();
  }

  static MsgSwapGraveDeck decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSwapGraveDeck(player: r.readUint8());
  }

  @override
  String toString() => 'MsgSwapGraveDeck(player:$player)';
}
