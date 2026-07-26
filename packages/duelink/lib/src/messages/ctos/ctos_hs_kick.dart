import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class CtosHsKick {
  final int pos;
  const CtosHsKick({required this.pos});
  int get protoId => CTOS_HS_KICK;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(pos & 0x3);
    return w.toBytes();
  }

  static CtosHsKick decode(Uint8List data) {
    return CtosHsKick(pos: data[0] & 0x3);
  }

  @override
  String toString() => 'CtosHsKick(pos:$pos)';
}
