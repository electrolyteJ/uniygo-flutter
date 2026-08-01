import 'dart:convert';
import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_AI_NAME (0xA3) — 调试 AI 名称。
class MsgAiName {
  final String name;

  const MsgAiName({required this.name});

  int get funcId => MSG_AI_NAME;

  Uint8List encode() {
    final raw = utf8.encode(name);
    final w = BufferWriter();
    w.writeUint16(raw.length);
    w.writeBytes(Uint8List.fromList(raw));
    w.writeUint8(0);
    return w.toBytes();
  }

  static MsgAiName decode(Uint8List data) {
    final r = BufferReader(data);
    final len = r.readUint16();
    final raw = r.readBytes(len);
    if (r.hasRemaining) {
      r.readUint8();
    }
    return MsgAiName(name: utf8.decode(raw, allowMalformed: true));
  }

  @override
  String toString() => 'MsgAiName(name:$name)';
}
