import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class StocErrorMsg {
  final int errorType;
  final int errorCode;
  const StocErrorMsg({required this.errorType, required this.errorCode});
  int get protoId => STOC_ERROR_MSG;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(errorType);
    w.writeUint8(0); // padding byte 1
    w.writeUint8(0); // padding byte 2
    w.writeUint8(0); // padding byte 3
    w.writeInt32(errorCode);
    return w.toBytes();
  }

  static StocErrorMsg decode(Uint8List data) {
    final r = BufferReader(data);
    final errorType = r.readUint8();
    r.skip(3); // padding
    final errorCode = r.readInt32();
    return StocErrorMsg(errorType: errorType, errorCode: errorCode);
  }

  @override
  String toString() => 'StocErrorMsg(type:$errorType code:$errorCode)';
}
