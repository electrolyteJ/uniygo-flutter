import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// New phase notification.
class MsgNewPhase {
  final int phase;

  const MsgNewPhase({required this.phase});

  int get funcId => MSG_NEW_PHASE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(phase);
    return w.toBytes();
  }

  static MsgNewPhase decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgNewPhase(phase: r.readUint16());
  }

  @override
  String toString() => 'MsgNewPhase(phase:$phase)';
}
