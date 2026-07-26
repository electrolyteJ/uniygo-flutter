import 'dart:typed_data';
import '../constants.dart';

/// Sequential binary reader, little-endian.
class BufferReader {
  final Uint8List _data;
  int _offset = 0;

  BufferReader(this._data);

  int get offset => _offset;
  int get remaining => _data.length - _offset;
  bool get hasRemaining => _offset < _data.length;

  void skip(int n) => _offset += n;
  void setOffset(int n) => _offset = n;

  int readUint8() => _data[_offset++];
  int readInt8() {
    final v = _data[_offset++];
    return v > 127 ? v - 256 : v;
  }

  int readUint16() {
    final v = _data[_offset] | (_data[_offset + 1] << 8);
    _offset += 2;
    return v;
  }

  int readInt16() {
    final v = readUint16();
    return v > 32767 ? v - 65536 : v;
  }

  int readUint32() {
    final v = _data[_offset] |
        (_data[_offset + 1] << 8) |
        (_data[_offset + 2] << 16) |
        (_data[_offset + 3] << 24);
    _offset += 4;
    return v;
  }

  int readInt32() {
    final v = readUint32();
    return v > 2147483647 ? v - 4294967296 : v;
  }

  Uint8List readBytes(int n) {
    final bytes = _data.sublist(_offset, _offset + n);
    _offset += n;
    return bytes;
  }

  List<int> readUint32List(int count) {
    return List.generate(count, (_) => readUint32());
  }

  /// Reads 4 bytes: controller(u8) + location(u8) + sequence(u8) + ss(u8)
  CardLocation readCardLocation() {
    final c = readUint8();
    final l = readUint8();
    final s = readUint8();
    final ss = readUint8();
    final isOverlay = (l & LOCATION_OVERLAY) != 0;
    return CardLocation(
      controller: c,
      location: l & ~LOCATION_OVERLAY,
      sequence: s,
      position: isOverlay ? 0 : ss,
      isOverlay: isOverlay,
      overlaySequence: isOverlay ? ss : 0,
    );
  }

  /// Reads 3 bytes: controller(u8) + location(u8) + sequence(u8)
  CardShortLocation readCardShortLocation() {
    return CardShortLocation(
      controller: readUint8(),
      location: readUint8(),
      sequence: readUint8(),
    );
  }

  /// Reads 7 bytes: code(u32) + controller(u8) + location(u8) + sequence(u8)
  CardInfo readCardInfo() {
    return CardInfo(
      code: readUint32(),
      controller: readUint8(),
      location: readUint8(),
      sequence: readUint8(),
    );
  }

  /// Reads UTF-16 LE null-terminated string up to [maxBytes] bytes.
  String readUtf16({int maxBytes = 40}) {
    final codes = <int>[];
    final end = (_offset + maxBytes).clamp(0, _data.length);
    while (_offset < end - 1) {
      final low = _data[_offset];
      final high = _data[_offset + 1];
      _offset += 2;
      if (low == 0 && high == 0) break;
      codes.add(low | (high << 8));
    }
    // Skip remaining bytes in fixed block
    _offset = end;
    return String.fromCharCodes(codes.where((c) => c != 0xcccc && c != 0));
  }

  /// Reads variable-length UTF-16 LE null-terminated string.
  String readUtf16Var() {
    final codes = <int>[];
    while (_offset < _data.length - 1) {
      final low = _data[_offset];
      final high = _data[_offset + 1];
      _offset += 2;
      if (low == 0 && high == 0) break;
      codes.add(low | (high << 8));
    }
    return String.fromCharCodes(codes);
  }
}

/// Sequential binary writer, little-endian.
class BufferWriter {
  final _buffer = <int>[];

  void writeUint8(int v) => _buffer.add(v & 0xff);
  void writeInt8(int v) => _buffer.add(v & 0xff);

  void writeUint16(int v) {
    _buffer.add(v & 0xff);
    _buffer.add((v >> 8) & 0xff);
  }

  void writeInt16(int v) => writeUint16(v & 0xffff);

  void writeUint32(int v) {
    _buffer.add(v & 0xff);
    _buffer.add((v >> 8) & 0xff);
    _buffer.add((v >> 16) & 0xff);
    _buffer.add((v >> 24) & 0xff);
  }

  void writeInt32(int v) => writeUint32(v & 0xffffffff);

  void writeBytes(Uint8List data) => _buffer.addAll(data);
  void writeUint32List(List<int> list) {
    for (final v in list) writeUint32(v);
  }

  void writeCardLocation(CardLocation loc) {
    final locationByte = loc.isOverlay ? (loc.location | LOCATION_OVERLAY) : loc.location;
    writeUint8(loc.controller);
    writeUint8(locationByte);
    writeUint8(loc.sequence);
    writeUint8(loc.isOverlay ? loc.overlaySequence : loc.position);
  }

  void writeCardShortLocation(CardShortLocation loc) {
    writeUint8(loc.controller);
    writeUint8(loc.location);
    writeUint8(loc.sequence);
  }

  void writeCardInfo(CardInfo info) {
    writeUint32(info.code);
    writeUint8(info.controller);
    writeUint8(info.location);
    writeUint8(info.sequence);
  }

  /// Writes fixed-length UTF-16 LE string (max 20 chars, 40 bytes).
  /// Null-terminated, remainder filled with 0xcccc.
  void writeUtf16Fixed(String str) {
    final codes = str.codeUnits;
    for (int i = 0; i < 20; i++) {
      if (i < codes.length) {
        writeUint16(codes[i]);
      } else if (i == codes.length) {
        writeUint16(0); // null terminator
      } else {
        writeUint16(0xcccc); // fill
      }
    }
  }

  /// Writes variable-length UTF-16 LE string with null terminator.
  void writeUtf16Var(String str) {
    for (final c in str.codeUnits) {
      writeUint16(c);
    }
    writeUint16(0); // null terminator
  }

  Uint8List toBytes() => Uint8List.fromList(_buffer);
}

/// 4-byte card location: controller + location + sequence + position/overlay.
class CardLocation {
  final int controller;
  final int location;
  final int sequence;
  final int position;
  final bool isOverlay;
  final int overlaySequence;

  const CardLocation({
    required this.controller,
    required this.location,
    required this.sequence,
    this.position = 0,
    this.isOverlay = false,
    this.overlaySequence = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is CardLocation &&
      other.controller == controller &&
      other.location == location &&
      other.sequence == sequence &&
      other.position == position &&
      other.isOverlay == isOverlay &&
      other.overlaySequence == overlaySequence;

  @override
  int get hashCode => Object.hash(controller, location, sequence, position, isOverlay, overlaySequence);

  @override
  String toString() => 'CardLocation(c:$controller l:$location s:$sequence p:$position)';
}

/// 3-byte short location: controller + location + sequence.
class CardShortLocation {
  final int controller;
  final int location;
  final int sequence;

  const CardShortLocation({
    required this.controller,
    required this.location,
    required this.sequence,
  });

  @override
  bool operator ==(Object other) =>
      other is CardShortLocation &&
      other.controller == controller &&
      other.location == location &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(controller, location, sequence);
}

/// 7-byte card info: code(u32) + controller(u8) + location(u8) + sequence(u8).
class CardInfo {
  final int code;
  final int controller;
  final int location;
  final int sequence;

  const CardInfo({
    required this.code,
    required this.controller,
    required this.location,
    required this.sequence,
  });

  @override
  bool operator ==(Object other) =>
      other is CardInfo &&
      other.code == code &&
      other.controller == controller &&
      other.location == location &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(code, controller, location, sequence);
}
