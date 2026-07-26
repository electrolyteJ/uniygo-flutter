import 'dart:typed_data';
import '../../constants.dart';

class CtosHsToObserver {
  const CtosHsToObserver();
  int get protoId => CTOS_HS_TO_OBSERVER;
  Uint8List encode() => Uint8List(0);
  static CtosHsToObserver decode(Uint8List data) => const CtosHsToObserver();
  @override
  String toString() => 'CtosHsToObserver';
}
