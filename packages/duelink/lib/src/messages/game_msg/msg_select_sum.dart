import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_SUM (0x17) — 选择合计数值交互
///
/// 服务端要求玩家选择多张卡牌，使其等级/数值之和满足给定条件。
/// 格式较复杂，目前保留原始字节数据。
///
/// 有线格式 (变长):
/// | 偏移 | 大小 | 类型     | 说明                           |
/// |------|------|----------|--------------------------------|
/// | 0x00 | 1    | uint8    | 玩家 (0 或 1)                  |
/// | 0x01 | 变长 | 原始数据 | 候选卡牌列表和条件信息          |
///
/// 参考 neos-ts 的 selectSum.ts 定义。
class MsgSelectSum {
  final int player;
  final Uint8List rawData;

  const MsgSelectSum({required this.player, required this.rawData});

  int get funcId => MSG_SELECT_SUM;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgSelectSum decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectSum(
      player: r.readUint8(),
      rawData: r.readBytes(data.length - 1),
    );
  }

  @override
  String toString() =>
      'MsgSelectSum(player:$player rawDataLen:${rawData.length})';
}
