import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Normal summoning announcement (code + location).
class MsgSummoning {
  final int code;
  final CardLocation location;

  const MsgSummoning({required this.code, required this.location});

  int get funcId => MSG_SUMMONING;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(location);
    return w.toBytes();
  }

  static MsgSummoning decode(Uint8List data) {
    final r = BufferReader(data);
    final code = r.readUint32();
    final location = r.readCardLocation();
    return MsgSummoning(code: code, location: location);
  }

  @override
  String toString() => 'MsgSummoning(code:$code location:$location)';
}
