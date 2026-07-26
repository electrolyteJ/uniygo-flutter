import 'dart:typed_data';
import '../../constants.dart';

class StocWaitingSide {
  const StocWaitingSide();
  int get protoId => STOC_WAITING_SIDE;
  Uint8List encode() => Uint8List(0);
  static StocWaitingSide decode(Uint8List data) => const StocWaitingSide();
  @override
  String toString() => 'StocWaitingSide';
}
