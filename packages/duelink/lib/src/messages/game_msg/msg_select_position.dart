import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select position interaction (player + code + positions).
class MsgSelectPosition {
  final int player;
  final int code;
  final int positions;

  const MsgSelectPosition({
    required this.player,
    required this.code,
    required this.positions,
  });

  int get funcId => MSG_SELECT_POSITION;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint32(code);
    w.writeUint8(positions);
    return w.toBytes();
  }

  static MsgSelectPosition decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSelectPosition(
      player: r.readUint8(),
      code: r.readUint32(),
      positions: r.readUint8(),
    );
  }

  @override
  String toString() =>
      'MsgSelectPosition(player:$player code:$code positions:$positions)';
}
