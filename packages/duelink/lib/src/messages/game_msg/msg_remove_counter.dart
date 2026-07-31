import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_REMOVE_COUNTER (0x66) — 移除计数器通知
///
/// 当卡牌上的计数器被移除时，核心将此消息发送至客户端。
/// 格式与 MSG_ADD_COUNTER 相同。
///
/// 有线格式 (7 字节):
/// | 偏移 | 大小 | 类型   | 说明           |
/// |------|------|--------|----------------|
/// | 0x00 | 2    | uint16 | 计数器类型      |
/// | 0x02 | 3    | CardShortLocation | 卡片短位置 |
/// | 0x05 | 2    | uint16 | 移除的计数器数量 |
///
/// 参考 neos-ts 的 removeCounter.ts 定义。
class MsgRemoveCounter {
  final int counterType;
  final CardShortLocation location;
  final int count;

  const MsgRemoveCounter({
    required this.counterType,
    required this.location,
    required this.count,
  });

  int get funcId => MSG_REMOVE_COUNTER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(counterType);
    w.writeCardShortLocation(location);
    w.writeUint16(count);
    return w.toBytes();
  }

  static MsgRemoveCounter decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgRemoveCounter(
      counterType: r.readUint16(),
      location: r.readCardShortLocation(),
      count: r.readUint16(),
    );
  }

  @override
  String toString() =>
      'MsgRemoveCounter(counterType:$counterType location:$location count:$count)';
}
