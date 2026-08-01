import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_TOSS_COIN (0x82) / MSG_TOSS_DICE (0x83) — 掷硬币或掷骰子结果。
class MsgToss {
  final int player;
  final int count;
  final List<int> results;

  const MsgToss({
    required this.player,
    required this.count,
    required this.results,
  });

  int get funcId => MSG_TOSS_COIN; // Both coin/dice share format

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    for (final r in results) {
      w.writeUint8(r);
    }
    return w.toBytes();
  }

  static MsgToss decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final count = r.readUint8();
    final results = <int>[];
    for (int i = 0; i < count; i++) {
      results.add(r.readUint8());
    }
    return MsgToss(player: player, count: count, results: results);
  }

  @override
  String toString() =>
      'MsgToss(player:$player count:$count results:$results)';
}
