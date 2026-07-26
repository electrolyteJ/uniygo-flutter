import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Select counter interaction (complex format).
/// player + counterType(uint16) + min(uint16) + count + items: [code(u32) + shortLocation(3) + counterCount(u16); count]
class MsgSelectCounter {
  final int player;
  final int counterType;
  final int min;
  final int count;
  final List<int> codes;
  final List<CardShortLocation> locations;
  final List<int> counterCounts;

  const MsgSelectCounter({
    required this.player,
    required this.counterType,
    required this.min,
    required this.count,
    required this.codes,
    required this.locations,
    required this.counterCounts,
  });

  int get funcId => MSG_SELECT_COUNTER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint16(counterType);
    w.writeUint16(min);
    w.writeUint8(count);
    for (int i = 0; i < count; i++) {
      w.writeUint32(codes[i]);
      w.writeCardShortLocation(locations[i]);
      w.writeUint16(counterCounts[i]);
    }
    return w.toBytes();
  }

  static MsgSelectCounter decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    final counterType = r.readUint16();
    final min = r.readUint16();
    final count = r.readUint8();
    final codes = <int>[];
    final locations = <CardShortLocation>[];
    final counterCounts = <int>[];
    for (int i = 0; i < count; i++) {
      codes.add(r.readUint32());
      locations.add(r.readCardShortLocation());
      counterCounts.add(r.readUint16());
    }
    return MsgSelectCounter(
      player: player,
      counterType: counterType,
      min: min,
      count: count,
      codes: codes,
      locations: locations,
      counterCounts: counterCounts,
    );
  }

  @override
  String toString() =>
      'MsgSelectCounter(player:$player counterType:$counterType min:$min count:$count)';
}
