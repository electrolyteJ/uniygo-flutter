import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class StocHandResult {
  final int meResult;
  final int opResult;
  const StocHandResult({required this.meResult, required this.opResult});
  int get protoId => STOC_HAND_RESULT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(meResult);
    w.writeUint8(opResult);
    return w.toBytes();
  }

  static StocHandResult decode(Uint8List data) {
    final r = BufferReader(data);
    return StocHandResult(
      meResult: r.readUint8(),
      opResult: r.readUint8(),
    );
  }

  @override
  String toString() => 'StocHandResult(me:$meResult op:$opResult)';
}
