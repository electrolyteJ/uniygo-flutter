import 'dart:typed_data';
import '../../constants.dart';

class CtosSurrender {
  const CtosSurrender();
  int get protoId => CTOS_SURRENDER;
  Uint8List encode() => Uint8List(0);
  static CtosSurrender decode(Uint8List data) => const CtosSurrender();
  @override
  String toString() => 'CtosSurrender';
}
