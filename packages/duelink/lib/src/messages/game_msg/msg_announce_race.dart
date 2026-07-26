import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Announce race interaction (player + count + min + available: uint32).
class MsgAnnounceRace {
  final int player;
  final int count;
  final int min;
  final int available;

  const MsgAnnounceRace({
    required this.player,
    required this.count,
    required this.min,
    required this.available,
  });

  int get funcId => MSG_ANNOUNCE_RACE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    w.writeUint8(min);
    w.writeUint32(available);
    return w.toBytes();
  }

  static MsgAnnounceRace decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgAnnounceRace(
      player: r.readUint8(),
      count: r.readUint8(),
      min: r.readUint8(),
      available: r.readUint32(),
    );
  }

  @override
  String toString() =>
      'MsgAnnounceRace(player:$player count:$count min:$min available:$available)';
}
