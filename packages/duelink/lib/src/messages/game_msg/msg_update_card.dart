import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_UPDATE_CARD (0x07) — 单张卡牌数据更新通知
///
/// 通知客户端单张卡牌的元数据发生了更新。
/// 后跟 flag 驱动的更新动作（类似 MSG_UPDATE_DATA，但针对单张卡）。
///
/// 有线格式 (变长):
/// | 偏移 | 大小 | 类型     | 说明                           |
/// |------|------|----------|--------------------------------|
/// | 0x00 | 1    | uint8    | 玩家 (0 或 1)                  |
/// | 0x01 | 1    | uint8    | 区域 zone                      |
/// | 0x02 | 1    | uint8    | 位置 sequence                  |
/// | 0x03 | 变长 | 原始数据  | flag 驱动的更新字段数据         |
///
/// 参考 neos-ts 的 updateCard.ts 定义。
class MsgUpdateCard {
  final int player;
  final int zone;
  final int sequence;
  final Uint8List rawData;

  const MsgUpdateCard({
    required this.player,
    required this.zone,
    required this.sequence,
    required this.rawData,
  });

  int get funcId => MSG_UPDATE_CARD;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(zone);
    w.writeUint8(sequence);
    w.writeBytes(rawData);
    return w.toBytes();
  }

  static MsgUpdateCard decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgUpdateCard(
      player: r.readUint8(),
      zone: r.readUint8(),
      sequence: r.readUint8(),
      rawData: r.readBytes(data.length - 3),
    );
  }

  @override
  String toString() =>
      'MsgUpdateCard(player:$player zone:$zone sequence:$sequence rawDataLen:${rawData.length})';
}
