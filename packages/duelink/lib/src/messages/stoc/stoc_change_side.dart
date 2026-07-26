import 'dart:typed_data';
import '../../constants.dart';

class StocChangeSide {
  const StocChangeSide();
  int get protoId => STOC_CHANGE_SIDE;
  Uint8List encode() => Uint8List(0);
  static StocChangeSide decode(Uint8List data) => const StocChangeSide();
  @override
  String toString() => 'StocChangeSide';
}
