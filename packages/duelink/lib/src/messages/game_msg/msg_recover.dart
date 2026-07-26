import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// LP recover notification (player: uint8 + value: int32).
class MsgRecover {
  final int player;
  final int value;

  const MsgRecover({required this.player, required this.value});

  int get funcId => MSG_RECOVER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeInt32(value);
    return w.toBytes();
  }

  static MsgRecover decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgRecover(player: r.readUint8(), value: r.readInt32());
  }

  @override
  String toString() => 'MsgRecover(player:$player value:$value)';
}
