import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select effect yes/no (12 bytes: player + code + location + effectDescription).
class MsgSelectEffectYn {
  final int player;
  final int code;
  final CardLocation location;
  final int effectDescription;

  const MsgSelectEffectYn({
    required this.player,
    required this.code,
    required this.location,
    required this.effectDescription,
  });

  int get funcId => MSG_SELECT_EFFECTYN;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint32(code);
    w.writeCardLocation(location);
    w.writeUint32(effectDescription);
    return w.toBytes();
  }

  static MsgSelectEffectYn decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectEffectYn(
      player: r.readUint8(),
      code: r.readUint32(),
      location: r.readCardLocation(),
      effectDescription: r.readUint32(),
    );
  }

  @override
  String toString() =>
      'MsgSelectEffectYn(player:$player code:$code location:$location effectDescription:$effectDescription)';
}
