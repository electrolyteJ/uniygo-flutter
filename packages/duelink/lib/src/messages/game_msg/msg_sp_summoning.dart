import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Special summoning announcement (code + location).
class MsgSpSummoning {
  final int code;
  final CardLocation location;

  const MsgSpSummoning({required this.code, required this.location});

  int get funcId => MSG_SP_SUMMONING;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(location);
    return w.toBytes();
  }

  static MsgSpSummoning decode(Uint8List data) {
    final r = BufferReader(data);
    final code = r.readUint32();
    final location = r.readCardLocation();
    return MsgSpSummoning(code: code, location: location);
  }

  @override
  String toString() => 'MsgSpSummoning(code:$code location:$location)';
}
