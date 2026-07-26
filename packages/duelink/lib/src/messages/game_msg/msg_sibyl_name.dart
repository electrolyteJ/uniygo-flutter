import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// Sibyl name interaction.
/// 6 fixed-length UTF-16 strings, each 100 bytes (50 uint16 units).
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
