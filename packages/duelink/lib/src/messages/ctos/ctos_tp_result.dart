import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class CtosTpResult {
  final bool first; // true=first, false=second
  const CtosTpResult({required this.first});
  int get protoId => CTOS_TP_RESULT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(first ? 1 : 0);
    return w.toBytes();
  }

  static CtosTpResult decode(Uint8List data) {
    final r = BufferReader(data);
    return CtosTpResult(first: r.readUint8() == 1);
  }

  @override
  String toString() => 'CtosTpResult(first: $first)';
}
