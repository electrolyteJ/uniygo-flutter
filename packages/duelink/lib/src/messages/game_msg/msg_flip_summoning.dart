import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Flip summoning announcement (code + location).
class MsgFlipSummoning {
  final int code;
  final CardLocation location;

  const MsgFlipSummoning({required this.code, required this.location});

  int get funcId => MSG_FLIP_SUMMONING;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(location);
    return w.toBytes();
  }

  static MsgFlipSummoning decode(Uint8List data) {
    final r = BufferReader(data);
    final code = r.readUint32();
    final location = r.readCardLocation();
    return MsgFlipSummoning(code: code, location: location);
  }

  @override
  String toString() => 'MsgFlipSummoning(code:$code location:$location)';
}
