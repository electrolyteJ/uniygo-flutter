import 'dart:typed_data';
import '../../constants.dart';

/// Empty payload — server tells client to wait.
class MsgWait {
  const MsgWait();

  int get funcId => MSG_WAITING;

  Uint8List encode() => Uint8List(0);

  static MsgWait decode(Uint8List data) => const MsgWait();

  @override
  String toString() => 'MsgWait()';
}
