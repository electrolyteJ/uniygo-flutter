import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// LP update notification (player: uint8 + newLp: uint32).
class MsgLpUpdate {
  final int player;
  final int newLp;

  const MsgLpUpdate({required this.player, required this.newLp});

  int get funcId => MSG_LP_UPDATE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint32(newLp);
    return w.toBytes();
  }

  static MsgLpUpdate decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgLpUpdate(player: r.readUint8(), newLp: r.readUint32());
  }

  @override
  String toString() => 'MsgLpUpdate(player:$player newLp:$newLp)';
}
