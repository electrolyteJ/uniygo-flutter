import 'dart:typed_data';
import '../../constants.dart';

class StocDuelEnd {
  const StocDuelEnd();
  int get protoId => STOC_DUEL_END;
  Uint8List encode() => Uint8List(0);
  static StocDuelEnd decode(Uint8List data) => const StocDuelEnd();
  @override
  String toString() => 'StocDuelEnd';
}
