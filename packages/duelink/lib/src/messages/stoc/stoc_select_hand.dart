import 'dart:typed_data';
import '../../constants.dart';

class StocSelectHand {
  const StocSelectHand();
  int get protoId => STOC_SELECT_HAND;
  Uint8List encode() => Uint8List(0);
  static StocSelectHand decode(Uint8List data) => const StocSelectHand();
  @override
  String toString() => 'StocSelectHand';
}
