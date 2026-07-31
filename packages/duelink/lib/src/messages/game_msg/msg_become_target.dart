import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_BECOME_TARGET (0x53) — 成为效果对象通知
///
/// 通知客户端某张或多张卡牌成为了效果的对象/目标。
///
/// 有线格式 (变长):
/// | 偏移 | 大小 | 类型             | 说明                  |
/// |------|------|------------------|-----------------------|
/// | 0x00 | 1    | uint8            | 目标卡牌数量 count     |
/// | 0x01 | 4*n  | CardLocation[n]  | 每张目标卡牌的位置信息 |
///
/// 参考 neos-ts 的 becomeTarget.ts 定义。
class MsgBecomeTarget {
  final int count;
  final List<CardLocation> locations;

  const MsgBecomeTarget({required this.count, required this.locations});

  int get funcId => MSG_BECOME_TARGET;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(count);
    for (final loc in locations) {
      w.writeCardLocation(loc);
    }
    return w.toBytes();
  }

  static MsgBecomeTarget decode(Uint8List data) {
    final r = BufferReader(data);
    final count = r.readUint8();
    final locations = <CardLocation>[];
    for (int i = 0; i < count; i++) {
      locations.add(r.readCardLocation());
    }
    return MsgBecomeTarget(count: count, locations: locations);
  }

  @override
  String toString() => 'MsgBecomeTarget(count:$count locations:$locations)';
}
