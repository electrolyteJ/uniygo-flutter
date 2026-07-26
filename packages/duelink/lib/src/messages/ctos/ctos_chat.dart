import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class CtosChat {
  final String message;
  const CtosChat({required this.message});
  int get protoId => CTOS_CHAT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUtf16Var(message);
    return w.toBytes();
  }

  static CtosChat decode(Uint8List data) {
    final r = BufferReader(data);
    return CtosChat(message: r.readUtf16Var());
  }

  @override
  String toString() => 'CtosChat($message)';
}
