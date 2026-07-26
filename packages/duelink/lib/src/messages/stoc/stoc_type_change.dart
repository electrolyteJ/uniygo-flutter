import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class StocTypeChange {
  final bool isHost;
  final int selfType; // 0=PLAYER1, 1=PLAYER2, 7=OBSERVER
  const StocTypeChange({required this.isHost, required this.selfType});
  int get protoId => STOC_TYPE_CHANGE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(((isHost ? 1 : 0) << 4) | (selfType & 0xf));
    return w.toBytes();
  }

  static StocTypeChange decode(Uint8List data) {
    final b = data[0];
    return StocTypeChange(isHost: ((b >> 4) & 0xf) != 0, selfType: b & 0xf);
  }

  @override
  String toString() => 'StocTypeChange(isHost:$isHost selfType:$selfType)';
}
