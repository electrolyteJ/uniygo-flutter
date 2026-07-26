import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select tribute interaction (fully decoded).
/// Format: player + cancelable + min + max + count + [code(u32) + shortLocation(3) + level(u8); count]
class MsgSelectTribute {
  final int player;
  final int cancelable;
  final int min;
  final int max;
  final int count;
  final List<int> codes;
  final List<CardShortLocation> locations;
  final List<int> levels;

  const MsgSelectTribute({
    required this.player,
    required this.cancelable,
    required this.min,
    required this.max,
    required this.count,
    required this.codes,
    required this.locations,
    required this.levels,
  });

  int get funcId => MSG_SELECT_TRIBUTE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(cancelable);
    w.writeUint8(min);
    w.writeUint8(max);
    w.writeUint8(count);
    for (int i = 0; i < count; i++) {
      w.writeUint32(codes[i]);
      w.writeCardShortLocation(locations[i]);
      w.writeUint8(levels[i]);
    }
    return w.toBytes();
  }

  static MsgSelectTribute decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final cancelable = r.readUint8();
    final min = r.readUint8();
    final max = r.readUint8();
    final count = r.readUint8();
    final codes = <int>[];
    final locations = <CardShortLocation>[];
    final levels = <int>[];
    for (int i = 0; i < count; i++) {
      codes.add(r.readUint32());
      locations.add(r.readCardShortLocation());
      levels.add(r.readUint8());
    }
    return MsgSelectTribute(
      player: player,
      cancelable: cancelable,
      min: min,
      max: max,
      count: count,
      codes: codes,
      locations: locations,
      levels: levels,
    );
  }

  @override
  String toString() =>
      'MsgSelectTribute(player:$player cancelable:$cancelable min:$min max:$max count:$count)';
}
