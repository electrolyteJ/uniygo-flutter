import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select yes/no interaction (player: uint8 + effectDescription: uint32).
class MsgSelectYesNo {
  final int player;
  final int effectDescription;

  const MsgSelectYesNo({required this.player, required this.effectDescription});

  int get funcId => MSG_SELECT_YES_NO;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint32(effectDescription);
    return w.toBytes();
  }

  static MsgSelectYesNo decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectYesNo(
      player: r.readUint8(),
      effectDescription: r.readUint32(),
    );
  }

  @override
  String toString() =>
      'MsgSelectYesNo(player:$player effectDescription:$effectDescription)';
}
