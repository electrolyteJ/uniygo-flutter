import 'dart:typed_data';
import 'package:duelink/src/protocol/buffer_io.dart';
import 'package:test/test.dart';

void main() {
  group('BufferReader', () {
    test('reads uint8', () {
      final r = BufferReader(Uint8List.fromList([0x12, 0xff]));
      expect(r.readUint8(), 0x12);
      expect(r.readUint8(), 0xff);
    });

    test('reads uint16 LE', () {
      final r = BufferReader(Uint8List.fromList([0x34, 0x12]));
      expect(r.readUint16(), 0x1234);
    });

    test('reads uint32 LE', () {
      final r = BufferReader(Uint8List.fromList([0x78, 0x56, 0x34, 0x12]));
      expect(r.readUint32(), 0x12345678);
    });

    test('reads int8 negative', () {
      final r = BufferReader(Uint8List.fromList([0xff]));
      expect(r.readInt8(), -1);
    });

    test('reads int16 negative', () {
      final r = BufferReader(Uint8List.fromList([0xff, 0xff]));
      expect(r.readInt16(), -1);
    });

    test('reads int32 negative', () {
      final r = BufferReader(Uint8List.fromList([0xff, 0xff, 0xff, 0xff]));
      expect(r.readInt32(), -1);
    });

    test('reads CardLocation', () {
      final r = BufferReader(Uint8List.fromList([0, 4, 3, 1]));
      final loc = r.readCardLocation();
      expect(loc.controller, 0);
      expect(loc.location, 4);
      expect(loc.sequence, 3);
      expect(loc.position, 1);
    });

    test('reads CardLocation with overlay', () {
      final r = BufferReader(Uint8List.fromList([1, 0x84, 2, 5]));
      final loc = r.readCardLocation();
      expect(loc.controller, 1);
      expect(loc.isOverlay, true);
      expect(loc.overlaySequence, 5);
      expect(loc.position, 0);
    });

    test('reads CardInfo (7 bytes)', () {
      final r = BufferReader(Uint8List.fromList([0xd4, 0x56, 0x03, 0x00, 0, 4, 3]));
      final info = r.readCardInfo();
      expect(info.code, 0x000356d4);
      expect(info.controller, 0);
      expect(info.location, 4);
      expect(info.sequence, 3);
    });

    test('reads fixed UTF-16 string', () {
      final bytes = <int>[];
      bytes.addAll([0x54, 0x00, 0x65, 0x00, 0x73, 0x00, 0x74, 0x00]); // T e s t
      bytes.addAll([0x00, 0x00]); // null
      bytes.addAll(List.filled(30, 0xcc)); // fill
      final r = BufferReader(Uint8List.fromList(bytes));
      expect(r.readUtf16(maxBytes: 40), 'Test');
    });

    test('hasRemaining and offset', () {
      final r = BufferReader(Uint8List.fromList([1, 2, 3, 4]));
      expect(r.hasRemaining, true);
      r.skip(4);
      expect(r.hasRemaining, false);
    });
  });

  group('BufferWriter', () {
    test('writes uint8', () {
      final w = BufferWriter();
      w.writeUint8(0x42);
      expect(w.toBytes(), Uint8List.fromList([0x42]));
    });

    test('writes uint16 LE', () {
      final w = BufferWriter();
      w.writeUint16(0x1234);
      expect(w.toBytes(), Uint8List.fromList([0x34, 0x12]));
    });

    test('writes uint32 LE', () {
      final w = BufferWriter();
      w.writeUint32(0x12345678);
      expect(w.toBytes(), Uint8List.fromList([0x78, 0x56, 0x34, 0x12]));
    });

    test('writes CardLocation', () {
      final w = BufferWriter();
      w.writeCardLocation(CardLocation(controller: 0, location: 4, sequence: 3, position: 1));
      expect(w.toBytes(), Uint8List.fromList([0, 4, 3, 1]));
    });

    test('writes CardLocation with overlay', () {
      final w = BufferWriter();
      w.writeCardLocation(CardLocation(controller: 1, location: 4, sequence: 2, isOverlay: true, overlaySequence: 5));
      expect(w.toBytes(), Uint8List.fromList([1, 0x84, 2, 5]));
    });

    test('writes fixed UTF-16', () {
      final w = BufferWriter();
      w.writeUtf16Fixed('AB');
      final bytes = w.toBytes();
      expect(bytes.length, 40);
      expect(bytes[0], 0x41);
      expect(bytes[1], 0x00);
      expect(bytes[2], 0x42);
      expect(bytes[3], 0x00);
      expect(bytes[4], 0x00); // null
      expect(bytes[5], 0x00);
    });

    test('writes variable UTF-16', () {
      final w = BufferWriter();
      w.writeUtf16Var('Hi');
      final bytes = w.toBytes();
      expect(bytes.length, 6);
      expect(bytes, Uint8List.fromList([0x48, 0x00, 0x69, 0x00, 0x00, 0x00]));
    });

    test('roundtrip CardLocation', () {
      final original = CardLocation(controller: 0, location: 8, sequence: 3, position: 1);
      final w = BufferWriter();
      w.writeCardLocation(original);
      final r = BufferReader(w.toBytes());
      final restored = r.readCardLocation();
      expect(restored, original);
    });

    test('roundtrip CardInfo', () {
      final original = CardInfo(code: 89631139, controller: 0, location: 4, sequence: 5);
      final w = BufferWriter();
      w.writeCardInfo(original);
      final r = BufferReader(w.toBytes());
      final restored = r.readCardInfo();
      expect(restored, original);
    });
  });
}
