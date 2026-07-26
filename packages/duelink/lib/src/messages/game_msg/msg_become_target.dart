import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// A card (or cards) became a target.
class MsgBecomeTarget {
  final int count;
  final List<CardLocation> locations;

  const MsgBecomeTarget({required this.count, required this.locations});

  int get funcId => MSG_BECOME_TARGET;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(count);
    for (final loc in locations) {
      w.writeCardLocation(loc);
    }
    return w.toBytes();
  }

  static MsgBecomeTarget decode(Uint8List data) {
    final r = BufferReader(data);
    final count = r.readUint8();
    final locations = <CardLocation>[];
    for (int i = 0; i < count; i++) {
      locations.add(r.readCardLocation());
    }
    return MsgBecomeTarget(count: count, locations: locations);
  }

  @override
  String toString() => 'MsgBecomeTarget(count:$count locations:$locations)';
}
