import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_ANNOUNCE_NUMBER (0x8F) — 宣言数值交互
///
/// 服务端要求玩家从给定的数值列表中宣选一个或按顺序排列。
///
/// 有线格式 (变长):
/// | 偏移 | 大小  | 类型     | 说明               |
/// |------|-------|----------|--------------------|
/// | 0x00 | 1     | uint8    | 玩家 (0 或 1)      |
/// | 0x01 | 1     | uint8    | 可选数值个数 count  |
/// | 0x02 | 4 * n | uint32[] | count 个候选数值    |
///
/// 参考 neos-ts 的 announceNumber.ts 定义。
class MsgAnnounceNumber {
  final int player;
  final int count;
  final List<int> numbers;

  const MsgAnnounceNumber({
    required this.player,
    required this.count,
    required this.numbers,
  });

  int get funcId => MSG_ANNOUNCE_NUMBER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (final n in numbers) {
      w.writeUint32(n);
    }
    return w.toBytes();
  }

  static MsgAnnounceNumber decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final numbers = <int>[];
    for (int i = 0; i < count; i++) {
      numbers.add(r.readUint32());
    }
    return MsgAnnounceNumber(player: player, count: count, numbers: numbers);
  }

  @override
  String toString() =>
      'MsgAnnounceNumber(player:$player count:$count numbers:$numbers)';
}
