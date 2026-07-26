import 'dart:typed_data';
import '../../constants.dart';

class CtosHsReady {
  const CtosHsReady();
  int get protoId => CTOS_HS_READY;
  Uint8List encode() => Uint8List(0);
  static CtosHsReady decode(Uint8List data) => const CtosHsReady();
  @override
  String toString() => 'CtosHsReady';
}
