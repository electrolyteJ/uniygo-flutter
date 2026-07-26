import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// LP cost payment (player: int8 + value: int32).
class MsgPayLpCost {
  final int player;
  final int value;

  const MsgPayLpCost({required this.player, required this.value});

  int get funcId => MSG_PAY_LP_COST;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt8(player);
    w.writeInt32(value);
    return w.toBytes();
  }

  static MsgPayLpCost decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgPayLpCost(player: r.readInt8(), value: r.readInt32());
  }

  @override
  String toString() => 'MsgPayLpCost(player:$player value:$value)';
}
