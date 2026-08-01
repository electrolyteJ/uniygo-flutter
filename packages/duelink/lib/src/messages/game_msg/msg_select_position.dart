import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';
import '../../types.dart';

/// MSG_SELECT_POSITION (0x13) — 选择表示形式交互
///
/// 服务端要求玩家选择怪兽的表示形式（攻击/守备，表侧/里侧）。
///
/// 有线格式 (6 字节):
/// | 偏移 | 大小 | 类型   | 说明                           |
/// |------|------|--------|--------------------------------|
/// | 0x00 | 1    | uint8  | 玩家 (0 或 1)                  |
/// | 0x01 | 4    | uint32 | 卡牌 code                      |
/// | 0x05 | 1    | uint8  | 可用表示形式位掩码 positions   |
///
/// 参考 neos-ts 的 selectPosition.ts 定义。
class MsgSelectPosition {
  final int player;
  final int code;
  final int positions;

  const MsgSelectPosition({
    required this.player,
    required this.code,
    required this.positions,
  });

  int get funcId => MSG_SELECT_POSITION;

  int get rawPositions => positions;

  List<CardPosition> get availablePositions {
    final result = <CardPosition>[];
    if ((positions & 0x1) != 0) result.add(CardPosition.faceupAttack);
    if ((positions & 0x2) != 0) result.add(CardPosition.facedownAttack);
    if ((positions & 0x4) != 0) result.add(CardPosition.faceupDefense);
    if ((positions & 0x8) != 0) result.add(CardPosition.facedownDefense);
    return result;
  }

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint32(code);
    w.writeUint8(positions);
    return w.toBytes();
  }

  static MsgSelectPosition decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectPosition(
      player: r.readUint8(),
      code: r.readUint32(),
      positions: r.readUint8(),
    );
  }

  @override
  String toString() =>
      'MsgSelectPosition(player:$player code:$code positions:$positions)';
}
