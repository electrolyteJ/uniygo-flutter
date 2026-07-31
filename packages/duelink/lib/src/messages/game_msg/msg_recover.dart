import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_RECOVER (0x5C) — LP 恢复通知
///
/// 通知客户端某位玩家的 LP 被恢复。
///
/// 有线格式 (5 字节):
/// | 偏移 | 大小 | 类型  | 说明               |
/// |------|------|-------|--------------------|
/// | 0x00 | 1    | uint8 | 玩家 (0 或 1)      |
/// | 0x01 | 4    | int32 | 恢复的 LP 值        |
///
/// 参考 neos-ts 的 recover.ts 定义。
class MsgRecover {
  final int player;
  final int value;

  const MsgRecover({required this.player, required this.value});

  int get funcId => MSG_RECOVER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeInt32(value);
    return w.toBytes();
  }

  static MsgRecover decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgRecover(player: r.readUint8(), value: r.readInt32());
  }

  @override
  String toString() => 'MsgRecover(player:$player value:$value)';
}
