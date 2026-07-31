import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_FIELD_DISABLED (0x38) — 区域禁用通知
///
/// 通知客户端某些怪兽/魔陷区域被禁用（不可使用）。
/// flag 的低位代表玩家 0 的 MZONE，接着是 SZONE，然后是玩家 1 的对应区域。
///
/// 有线格式 (4 字节):
/// | 偏移 | 大小 | 类型  | 说明                         |
/// |------|------|-------|------------------------------|
/// | 0x00 | 4    | int32 | 区域禁用位掩码 flag           |
///
/// 参考 neos-ts 的 fieldDisabled.ts 定义。
class MsgFieldDisabled {
  final int flag;

  const MsgFieldDisabled({required this.flag});

  int get funcId => MSG_FIELD_DISABLED;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt32(flag);
    return w.toBytes();
  }

  static MsgFieldDisabled decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgFieldDisabled(flag: r.readInt32());
  }

  @override
  String toString() => 'MsgFieldDisabled(flag:$flag)';
}
