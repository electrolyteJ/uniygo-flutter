import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_YES_NO (0x0D) — 选择是/否交互
///
/// 服务端询问玩家一个简单的是/否问题。
///
/// 有线格式 (5 字节):
/// | 偏移 | 大小 | 类型   | 说明          |
/// |------|------|--------|---------------|
/// | 0x00 | 1    | uint8  | 玩家 (0 或 1) |
/// | 0x01 | 4    | uint32 | 效果描述 ID   |
///
/// 参考 neos-ts 的 selectYesNo.ts 定义。
class MsgSelectYesNo {
  final int player;
  final int effectDescription;

  const MsgSelectYesNo({required this.player, required this.effectDescription});

  int get funcId => MSG_SELECT_YES_NO;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint32(effectDescription);
    return w.toBytes();
  }

  static MsgSelectYesNo decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectYesNo(
      player: r.readUint8(),
      effectDescription: r.readUint32(),
    );
  }

  @override
  String toString() =>
      'MsgSelectYesNo(player:$player effectDescription:$effectDescription)';
}
