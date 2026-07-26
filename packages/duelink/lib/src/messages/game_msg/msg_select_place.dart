import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select place interaction (similar to select card but with field: uint32).
class MsgSelectPlace {
  final int player;
  final int count;
  final int field;

  const MsgSelectPlace({
    required this.player,
    required this.count,
    required this.field,
  });

  int get funcId => MSG_SELECT_PLACE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    w.writeUint32(field);
    return w.toBytes();
  }

  static MsgSelectPlace decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    var count = r.readUint8();
    if (count == 0) count = 1;
    final field = r.readUint32();
    return MsgSelectPlace(player: player, count: count, field: field);
  }

  @override
  String toString() =>
      'MsgSelectPlace(player:$player count:$count field:$field)';
}
