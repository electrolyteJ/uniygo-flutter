import 'dart:typed_data';
import '../../constants.dart';

class CtosHsNotReady {
  const CtosHsNotReady();
  int get protoId => CTOS_HS_NOT_READY;
  Uint8List encode() => Uint8List(0);
  static CtosHsNotReady decode(Uint8List data) => const CtosHsNotReady();
  @override
  String toString() => 'CtosHsNotReady';
}
