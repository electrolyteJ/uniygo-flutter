import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_FLIP_SUMMONING (0x40) — 反转召唤宣言
///
/// 通知客户端某张怪兽即将进行反转召唤。
///
/// 有线格式 (8 字节):
/// | 偏移 | 大小 | 类型         | 说明           |
/// |------|------|--------------|----------------|
/// | 0x00 | 4    | uint32       | 卡牌 code      |
/// | 0x04 | 4    | CardLocation | 卡牌位置       |
///
/// 参考 neos-ts 的 flipSummoning.ts 定义。
class MsgFlipSummoning {
  final int code;
  final CardLocation location;

  const MsgFlipSummoning({required this.code, required this.location});

  int get funcId => MSG_FLIP_SUMMONING;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(location);
    return w.toBytes();
  }

  static MsgFlipSummoning decode(Uint8List data) {
    final r = BufferReader(data);
    final code = r.readUint32();
    final location = r.readCardLocation();
    return MsgFlipSummoning(code: code, location: location);
  }

  @override
  String toString() => 'MsgFlipSummoning(code:$code location:$location)';
}
