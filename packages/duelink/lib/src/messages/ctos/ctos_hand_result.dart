import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class CtosHandResult {
  final int hand; // 1=SCISSORS, 2=ROCK, 3=PAPER
  const CtosHandResult({required this.hand});
  int get protoId => CTOS_HAND_RESULT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(hand);
    return w.toBytes();
  }

  static CtosHandResult decode(Uint8List data) {
    final r = BufferReader(data);
    return CtosHandResult(hand: r.readUint8());
  }

  @override
  String toString() => 'CtosHandResult($hand)';
}
