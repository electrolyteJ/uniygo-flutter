import 'dart:convert';
import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SHOW_HINT (0xA4) — 调试提示文本。
class MsgShowHint {
  final String message;

  const MsgShowHint({required this.message});

  int get funcId => MSG_SHOW_HINT;

  Uint8List encode() {
    final raw = utf8.encode(message);
    final w = BufferWriter();
    w.writeUint16(raw.length);
    w.writeBytes(Uint8List.fromList(raw));
    w.writeUint8(0);
    return w.toBytes();
  }

  static MsgShowHint decode(Uint8List data) {
    final r = BufferReader(data);
    final len = r.readUint16();
    final raw = r.readBytes(len);
    if (r.hasRemaining) {
      r.readUint8();
    }
    return MsgShowHint(message: utf8.decode(raw, allowMalformed: true));
  }

  @override
  String toString() => 'MsgShowHint(message:$message)';
}
