import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Card set notification (code + location).
class MsgSet {
  final int code;
  final CardLocation location;

  const MsgSet({required this.code, required this.location});

  int get funcId => MSG_SET;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(location);
    return w.toBytes();
  }

  static MsgSet decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSet(code: r.readUint32(), location: r.readCardLocation());
  }

  @override
  String toString() => 'MsgSet(code:$code location:$location)';
}
