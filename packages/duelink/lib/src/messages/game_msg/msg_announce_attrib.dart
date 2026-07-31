import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_ANNOUNCE_ATTRIB (0x8D) — 宣言属性交互
///
/// 服务端要求玩家从可选属性中宣言一个或多个属性。
///
/// 有线格式 (7 字节):
/// | 偏移 | 大小 | 类型   | 说明                       |
/// |------|------|--------|----------------------------|
/// | 0x00 | 1    | uint8  | 玩家 (0 或 1)              |
/// | 0x01 | 1    | uint8  | 可选属性个数                |
/// | 0x02 | 1    | uint8  | 最少需选数量 (min)          |
/// | 0x03 | 4    | uint32 | 可用属性位掩码 (available)  |
///
/// 参考 neos-ts 的 announceAttrib.ts 定义。
class MsgAnnounceAttrib {
  final int player;
  final int count;
  final int min;
  final int available;

  const MsgAnnounceAttrib({
    required this.player,
    required this.count,
    required this.min,
    required this.available,
  });

  int get funcId => MSG_ANNOUNCE_ATTRIB;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    w.writeUint8(min);
    w.writeUint32(available);
    return w.toBytes();
  }

  static MsgAnnounceAttrib decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgAnnounceAttrib(
      player: r.readUint8(),
      count: r.readUint8(),
      min: r.readUint8(),
      available: r.readUint32(),
    );
  }

  @override
  String toString() =>
      'MsgAnnounceAttrib(player:$player count:$count min:$min available:$available)';
}
