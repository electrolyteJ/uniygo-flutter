import 'dart:typed_data';
import '../../constants.dart';

class StocDuelStart {
  const StocDuelStart();
  int get protoId => STOC_DUEL_START;
  Uint8List encode() => Uint8List(0);
  static StocDuelStart decode(Uint8List data) => const StocDuelStart();
  @override
  String toString() => 'StocDuelStart';
}
