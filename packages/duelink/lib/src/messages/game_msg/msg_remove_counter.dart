import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Remove counter notification (same format as add_counter).
class MsgRemoveCounter {
  final int counterType;
  final CardShortLocation location;
  final int count;

  const MsgRemoveCounter({
    required this.counterType,
    required this.location,
    required this.count,
  });

  int get funcId => MSG_REMOVE_COUNTER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(counterType);
    w.writeCardShortLocation(location);
    w.writeUint16(count);
    return w.toBytes();
  }

  static MsgRemoveCounter decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgRemoveCounter(
      counterType: r.readUint16(),
      location: r.readCardShortLocation(),
      count: r.readUint16(),
    );
  }

  @override
  String toString() =>
      'MsgRemoveCounter(counterType:$counterType location:$location count:$count)';
}
