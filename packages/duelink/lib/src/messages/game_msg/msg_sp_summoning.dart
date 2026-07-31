import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SP_SUMMONING (0x3E) — 特殊召唤宣言
///
/// 通知客户端某张怪兽即将被特殊召唤。
///
/// 有线格式 (8 字节):
/// | 偏移 | 大小 | 类型         | 说明           |
/// |------|------|--------------|----------------|
/// | 0x00 | 4    | uint32       | 卡牌 code      |
/// | 0x04 | 4    | CardLocation | 卡牌位置       |
///
/// 参考 neos-ts 的 penetrate.json (key 62) 定义。
class MsgSpSummoning {
  final int code;
  final CardLocation location;

  const MsgSpSummoning({required this.code, required this.location});

  int get funcId => MSG_SP_SUMMONING;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(location);
    return w.toBytes();
  }

  static MsgSpSummoning decode(Uint8List data) {
    final r = BufferReader(data);
    final code = r.readUint32();
    final location = r.readCardLocation();
    return MsgSpSummoning(code: code, location: location);
  }

  @override
  String toString() => 'MsgSpSummoning(code:$code location:$location)';
}
