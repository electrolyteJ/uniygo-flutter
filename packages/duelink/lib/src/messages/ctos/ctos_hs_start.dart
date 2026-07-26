import 'dart:typed_data';
import '../../constants.dart';

class CtosHsStart {
  const CtosHsStart();
  int get protoId => CTOS_HS_START;
  Uint8List encode() => Uint8List(0);
  static CtosHsStart decode(Uint8List data) => const CtosHsStart();
  @override
  String toString() => 'CtosHsStart';
}
