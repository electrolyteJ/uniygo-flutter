import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_ADD_COUNTER (0x65) — 添加计数器通知
///
/// 当卡牌上增加计数器时，核心将此消息发送至客户端。
///
/// 有线格式 (7 字节):
/// | 偏移 | 大小 | 类型   | 说明           |
/// |------|------|--------|----------------|
/// | 0x00 | 2    | uint16 | 计数器类型      |
/// | 0x02 | 3    | CardShortLocation | 卡片短位置 |
/// | 0x05 | 2    | uint16 | 添加的计数器数量 |
///
/// 参考 neos-ts 的 addCounter.ts 定义。
class MsgAddCounter {
  final int counterType;
  final CardShortLocation location;
  final int count;

  const MsgAddCounter({
    required this.counterType,
    required this.location,
    required this.count,
  });

  int get funcId => MSG_ADD_COUNTER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(counterType);
    w.writeCardShortLocation(location);
    w.writeUint16(count);
    return w.toBytes();
  }

  static MsgAddCounter decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgAddCounter(
      counterType: r.readUint16(),
      location: r.readCardShortLocation(),
      count: r.readUint16(),
    );
  }

  @override
  String toString() =>
      'MsgAddCounter(counterType:$counterType location:$location count:$count)';
}
