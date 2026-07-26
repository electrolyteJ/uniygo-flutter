import 'dart:typed_data';
import '../../constants.dart';

class CtosTimeConfirm {
  const CtosTimeConfirm();
  int get protoId => CTOS_TIME_CONFIRM;
  Uint8List encode() => Uint8List(0);
  static CtosTimeConfirm decode(Uint8List data) => const CtosTimeConfirm();
  @override
  String toString() => 'CtosTimeConfirm';
}
