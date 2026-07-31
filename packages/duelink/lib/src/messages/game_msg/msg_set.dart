import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SET (0x36) — 盖卡通知
///
/// 通知客户端某张卡牌被盖放在场上。
///
/// 有线格式 (8 字节):
/// | 偏移 | 大小 | 类型         | 说明     |
/// |------|------|--------------|----------|
/// | 0x00 | 4    | uint32       | 卡牌 code |
/// | 0x04 | 4    | CardLocation | 盖放位置  |
///
/// 参考 neos-ts 的 set.ts 定义。
class MsgSet {
  final int code;
  final CardLocation location;

  const MsgSet({required this.code, required this.location});

  int get funcId => MSG_SET;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(location);
    return w.toBytes();
  }

  static MsgSet decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSet(code: r.readUint32(), location: r.readCardLocation());
  }

  @override
  String toString() => 'MsgSet(code:$code location:$location)';
}
