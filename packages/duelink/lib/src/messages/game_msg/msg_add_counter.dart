import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Add counter notification (counterType: uint16 + shortLocation: 3 + count: uint16 = 7 bytes).
class MsgAddCounter {
  final int counterType;
  final CardShortLocation location;
  final int count;

  const MsgAddCounter({
    required this.counterType,
    required this.location,
    required this.count,
  });

  int get funcId => MSG_ADD_COUNTER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(counterType);
    w.writeCardShortLocation(location);
    w.writeUint16(count);
    return w.toBytes();
  }

  static MsgAddCounter decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgAddCounter(
      counterType: r.readUint16(),
      location: r.readCardShortLocation(),
      count: r.readUint16(),
    );
  }

  @override
  String toString() =>
      'MsgAddCounter(counterType:$counterType location:$location count:$count)';
}
