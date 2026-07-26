import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class StocHsPlayerChange {
  final int pos;
  final int state; // MOVE=0, READY=1, NO_READY=2, LEAVE=3, TO_OBSERVER=4
  const StocHsPlayerChange({required this.pos, required this.state});
  int get protoId => STOC_HS_PLAYER_CHANGE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(((pos & 0xf) << 4) | (state & 0xf));
    return w.toBytes();
  }

  static StocHsPlayerChange decode(Uint8List data) {
    final b = data[0];
    return StocHsPlayerChange(pos: (b >> 4) & 0xf, state: b & 0xf);
  }

  @override
  String toString() => 'StocHsPlayerChange(pos:$pos state:$state)';
}
