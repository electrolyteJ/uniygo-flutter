import 'dart:typed_data';
import '../../constants.dart';

class StocSelectTp {
  const StocSelectTp();
  int get protoId => STOC_SELECT_TP;
  Uint8List encode() => Uint8List(0);
  static StocSelectTp decode(Uint8List data) => const StocSelectTp();
  @override
  String toString() => 'StocSelectTp';
}
