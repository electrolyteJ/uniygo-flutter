import 'dart:typed_data';
import '../../constants.dart';

class CtosHsToDuelist {
  const CtosHsToDuelist();
  int get protoId => CTOS_HS_TO_DUELIST;
  Uint8List encode() => Uint8List(0);
  static CtosHsToDuelist decode(Uint8List data) => const CtosHsToDuelist();
  @override
  String toString() => 'CtosHsToDuelist';
}
