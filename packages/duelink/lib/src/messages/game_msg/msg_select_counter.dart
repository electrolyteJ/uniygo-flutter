import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_COUNTER (0x16) — 选择计数器交互
///
/// 服务端要求玩家从多张卡片上移除指定数量的计数器。
///
/// 有线格式 (变长):
/// | 偏移 | 大小     | 类型                      | 说明                    |
/// |------|----------|---------------------------|-------------------------|
/// | 0x00 | 1        | uint8                     | 玩家 (0 或 1)           |
/// | 0x01 | 2        | uint16                    | 计数器类型 counterType   |
/// | 0x03 | 2        | uint16                    | 最少需选数量 min         |
/// | 0x05 | 1        | uint8                     | 可选卡片数量 count       |
/// | 0x06 | 9 * n    | code(u32) + shortLocation(3) + counterCount(u16) | 每张卡: 卡牌 code + 短位置 + 该卡上的计数器数量 |
///
/// 参考 neos-ts 的 selectCounter.ts 定义。
class MsgSelectCounter {
  final int player;
  final int counterType;
  final int min;
  final int count;
  final List<int> codes;
  final List<CardShortLocation> locations;
  final List<int> counterCounts;

  const MsgSelectCounter({
    required this.player,
    required this.counterType,
    required this.min,
    required this.count,
    required this.codes,
    required this.locations,
    required this.counterCounts,
  });

  int get funcId => MSG_SELECT_COUNTER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint16(counterType);
    w.writeUint16(min);
    w.writeUint8(count);
    for (int i = 0; i < count; i++) {
      w.writeUint32(codes[i]);
      w.writeCardShortLocation(locations[i]);
      w.writeUint16(counterCounts[i]);
    }
    return w.toBytes();
  }

  static MsgSelectCounter decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final counterType = r.readUint16();
    final min = r.readUint16();
    final count = r.readUint8();
    final codes = <int>[];
    final locations = <CardShortLocation>[];
    final counterCounts = <int>[];
    for (int i = 0; i < count; i++) {
      codes.add(r.readUint32());
      locations.add(r.readCardShortLocation());
      counterCounts.add(r.readUint16());
    }
    return MsgSelectCounter(
      player: player,
      counterType: counterType,
      min: min,
      count: count,
      codes: codes,
      locations: locations,
      counterCounts: counterCounts,
    );
  }

  @override
  String toString() =>
      'MsgSelectCounter(player:$player counterType:$counterType min:$min count:$count)';
}
