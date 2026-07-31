import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CHAINING (0x46) — 连锁开始通知
///
/// 通知客户端一张卡牌发动效果，开始构建连锁。
///
/// 有线格式 (8 字节):
/// | 偏移 | 大小 | 类型         | 说明               |
/// |------|------|--------------|--------------------|
/// | 0x00 | 4    | uint32       | 发动效果的卡牌 code |
/// | 0x04 | 4    | CardLocation | 卡牌位置            |
///
/// 参考 neos-ts 的 chaining.ts 定义。
class MsgChaining {
  final int code;
  final CardLocation location;

  const MsgChaining({required this.code, required this.location});

  int get funcId => MSG_CHAINING;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(location);
    return w.toBytes();
  }

  static MsgChaining decode(Uint8List data) {
    final r = BufferReader(data);
    final code = r.readUint32();
    final location = r.readCardLocation();
    return MsgChaining(code: code, location: location);
  }

  @override
  String toString() => 'MsgChaining(code:$code location:$location)';
}
