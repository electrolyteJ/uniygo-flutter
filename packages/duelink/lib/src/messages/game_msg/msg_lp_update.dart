import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_LP_UPDATE (0x5E) — LP 变化通知
///
/// 通知客户端玩家的 LP 已更新（伤害/恢复汇总后的最终值）。
///
/// 有线格式 (5 字节):
/// | 偏移 | 大小 | 类型   | 说明          |
/// |------|------|--------|---------------|
/// | 0x00 | 1    | uint8  | 玩家 (0 或 1) |
/// | 0x01 | 4    | uint32 | 新的 LP 值    |
///
/// 参考 neos-ts 的 lpUpdate.ts 定义。
class MsgLpUpdate {
  final int player;
  final int newLp;

  const MsgLpUpdate({required this.player, required this.newLp});

  int get funcId => MSG_LP_UPDATE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint32(newLp);
    return w.toBytes();
  }

  static MsgLpUpdate decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgLpUpdate(player: r.readUint8(), newLp: r.readUint32());
  }

  @override
  String toString() => 'MsgLpUpdate(player:$player newLp:$newLp)';
}
