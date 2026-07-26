import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

class CtosPlayerInfo {
  final String name;
  const CtosPlayerInfo({required this.name});
  int get protoId => CTOS_PLAYER_INFO;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUtf16Fixed(name);
    return w.toBytes();
  }

  static CtosPlayerInfo decode(Uint8List data) {
    final r = BufferReader(data);
    return CtosPlayerInfo(name: r.readUtf16(maxBytes: 40));
  }

  @override
  String toString() => 'CtosPlayerInfo($name)';
}
