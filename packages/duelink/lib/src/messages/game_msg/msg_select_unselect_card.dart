import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_UNSELECT_CARD (0x1A) — 反选卡交互
///
/// 服务端要求玩家取消选择已选中的部分卡牌。
/// 格式类似 MSG_SELECT_CARD，目前保留原始字节数据。
///
/// 有线格式 (变长):
/// | 偏移 | 大小 | 类型     | 说明                           |
/// |------|------|----------|--------------------------------|
/// | 0x00 | 1    | uint8    | 玩家 (0 或 1)                  |
/// | 0x01 | 变长 | 原始数据 | 可选/已选卡牌列表信息          |
///
/// 参考 neos-ts 的 selectUnselectCard.ts 定义。
class MsgSelectUnselectCard {
  final int player;
  final Uint8List rawData;

  const MsgSelectUnselectCard({required this.player, required this.rawData});

  int get funcId => MSG_SELECT_UNSELECT_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgSelectUnselectCard decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectUnselectCard(
      player: r.readUint8(),
      rawData: r.readBytes(data.length - 1),
    );
  }

  @override
  String toString() =>
      'MsgSelectUnselectCard(player:$player rawDataLen:${rawData.length})';
}
