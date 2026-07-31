import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SIBYL_NAME (0xEB) — 神托/占卜选名交互
///
/// 回放模式获取对战双方的昵称，或用于占卜选名效果。
/// 包含 6 个定长 UTF-16 字符串块，每个 100 字节（50 个 uint16 单元）。
///
/// 有线格式 (600 字节):
/// | 偏移 | 大小  | 类型   | 说明                  |
/// |------|-------|--------|-----------------------|
/// | 0x00 | 100   | utf16  | 玩家 0 昵称           |
/// | 0x64 | 100   | utf16  | 玩家 0 昵称标签       |
/// | 0xC8 | 100   | utf16  | 玩家 0 昵称 C 版本   |
/// | 0x12C| 100   | utf16  | 玩家 1 昵称           |
/// | 0x190| 100   | utf16  | 玩家 1 昵称标签       |
/// | 0x1F4| 100   | utf16  | 玩家 1 昵称 C 版本   |
///
/// 参考 neos-ts 的 sibylName.ts 定义。
class MsgSibylName {
  final String name0;
  final String name0Tag;
  final String name0C;
  final String name1;
  final String name1Tag;
  final String name1C;

  const MsgSibylName({
    required this.name0,
    required this.name0Tag,
    required this.name0C,
    required this.name1,
    required this.name1Tag,
    required this.name1C,
  });

  int get funcId => MSG_SIBYL_NAME;

  Uint8List encode() {
    final w = BufferWriter();
    _writeFixedUtf16Block(w, name0, 100);
    _writeFixedUtf16Block(w, name0Tag, 100);
    _writeFixedUtf16Block(w, name0C, 100);
    _writeFixedUtf16Block(w, name1, 100);
    _writeFixedUtf16Block(w, name1Tag, 100);
    _writeFixedUtf16Block(w, name1C, 100);
    return w.toBytes();
  }

  static void _writeFixedUtf16Block(BufferWriter w, String str, int maxBytes) {
    final codes = str.codeUnits;
    int byteCount = 0;
    for (int i = 0; i < codes.length && byteCount < maxBytes - 2; i++) {
      w.writeUint16(codes[i]);
      byteCount += 2;
    }
    // Null terminator
    if (byteCount < maxBytes) {
      w.writeUint16(0);
      byteCount += 2;
    }
    // Pad remaining bytes
    while (byteCount < maxBytes) {
      w.writeUint16(0);
      byteCount += 2;
    }
  }

  static MsgSibylName decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgSibylName(
      name0: _readFixedUtf16(r, 100),
      name0Tag: _readFixedUtf16(r, 100),
      name0C: _readFixedUtf16(r, 100),
      name1: _readFixedUtf16(r, 100),
      name1Tag: _readFixedUtf16(r, 100),
      name1C: _readFixedUtf16(r, 100),
    );
  }

  static String _readFixedUtf16(BufferReader r, int maxBytes) {
    final codes = <int>[];
    final end = r.offset + maxBytes;
    while (r.offset < end - 1) {
      final v = r.readUint16();
      if (v == 0) break;
      codes.add(v);
    }
    // Skip remaining bytes
    r.setOffset(end);
    return String.fromCharCodes(codes);
  }

  @override
  String toString() =>
      'MsgSibylName(name0:$name0 name1:$name1)';
}
