import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Damage notification (player: int8 + value: int32).
class MsgDamage {
  final int player;
  final int value;

  const MsgDamage({required this.player, required this.value});

  int get funcId => MSG_DAMAGE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeInt8(player);
    w.writeInt32(value);
    return w.toBytes();
  }

  static MsgDamage decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgDamage(player: r.readInt8(), value: r.readInt32());
  }

  @override
  String toString() => 'MsgDamage(player:$player value:$value)';
}
