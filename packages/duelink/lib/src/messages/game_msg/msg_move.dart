import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Card movement notification. 19 bytes total.
class MsgMove {
  final int code;
  final CardLocation from;
  final CardLocation to;
  final int reason;

  const MsgMove({
    required this.code,
    required this.from,
    required this.to,
    required this.reason,
  });

  int get funcId => MSG_MOVE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(from);
    w.writeCardLocation(to);
    w.writeUint32(reason);
    return w.toBytes();
  }

  static MsgMove decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgMove(
      code: r.readUint32(),
      from: r.readCardLocation(),
      to: r.readCardLocation(),
      reason: r.readUint32(),
    );
  }

  @override
  String toString() => 'MsgMove(code:$code from:$from to:$to reason:$reason)';
}
