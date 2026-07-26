import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class StocHsPlayerEnter {
  final String name;
  final int pos;
  const StocHsPlayerEnter({required this.name, required this.pos});
  int get protoId => STOC_HS_PLAYER_ENTER;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUtf16Fixed(name);
    w.writeUint8(pos & 0x3);
    return w.toBytes();
  }

  static StocHsPlayerEnter decode(Uint8List data) {
    final r = BufferReader(data);
    final name = r.readUtf16(maxBytes: 40);
    final pos = r.readUint8() & 0x3;
    return StocHsPlayerEnter(name: name, pos: pos);
  }

  @override
  String toString() => 'StocHsPlayerEnter($name pos:$pos)';
}
