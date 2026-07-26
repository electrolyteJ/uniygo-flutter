import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// A card is being chained (activated).
class MsgChaining {
  final int code;
  final CardLocation location;

  const MsgChaining({required this.code, required this.location});

  int get funcId => MSG_CHAINING;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint32(code);
    w.writeCardLocation(location);
    return w.toBytes();
  }

  static MsgChaining decode(Uint8List data) {
    final r = BufferReader(data);
    final code = r.readUint32();
    final location = r.readCardLocation();
    return MsgChaining(code: code, location: location);
  }

  @override
  String toString() => 'MsgChaining(code:$code location:$location)';
}
