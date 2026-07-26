import 'dart:typed_data';
import 'package:duelink/src/protocol/packet.dart';
import 'package:test/test.dart';

void main() {
  group('YgoProPacket', () {
    test('serializes correctly', () {
      final pkt = YgoProPacket(packetLen: 5, proto: 18, exData: Uint8List.fromList([1, 2, 3, 4]));
      final wire = pkt.serialize();
      expect(wire.length, 7);
      expect(wire[0], 5); // packetLen low byte
      expect(wire[1], 0); // packetLen high byte
      expect(wire[2], 18); // proto
      expect(wire.sublist(3), Uint8List.fromList([1, 2, 3, 4]));
    });

    test('roundtrip: serialize then deserialize', () {
      final original = YgoProPacket(packetLen: 5, proto: 18, exData: Uint8List.fromList([1, 2, 3, 4]));
      final wire = original.serialize();
      final packets = YgoProPacket.deserialize(wire);
      expect(packets.length, 1);
      expect(packets[0].proto, 18);
      expect(packets[0].exData, Uint8List.fromList([1, 2, 3, 4]));
    });

    test('deserializes single packet', () {
      // packetLen=3 → exDataLen=2 (3-1), frame=5 bytes
      final wire = Uint8List.fromList([3, 0, 1, 0xa, 0xb]);
      final packets = YgoProPacket.deserialize(wire);
      expect(packets.length, 1);
      expect(packets[0].packetLen, 3);
      expect(packets[0].proto, 1);
      expect(packets[0].exData, Uint8List.fromList([0xa, 0xb]));
    });

    test('deserializes sticky packets (multiple in one buffer)', () {
      // first: packetLen=3 (exData 2 bytes), proto=1, exData=[0xa,0xb], frame=5
      // second: packetLen=2 (exData 1 byte), proto=2, exData=[0xc], frame=4
      final wire = Uint8List.fromList([
        3, 0, 1, 0xa, 0xb, // first packet
        2, 0, 2, 0xc,      // second packet
      ]);
      final packets = YgoProPacket.deserialize(wire);
      expect(packets.length, 2);
      expect(packets[0].packetLen, 3);
      expect(packets[0].proto, 1);
      expect(packets[0].exData, Uint8List.fromList([0xa, 0xb]));
      expect(packets[1].packetLen, 2);
      expect(packets[1].proto, 2);
      expect(packets[1].exData, Uint8List.fromList([0xc]));
    });

    test('deserializes empty buffer', () {
      expect(YgoProPacket.deserialize(Uint8List(0)), isEmpty);
    });

    test('deserializes buffer too short for header', () {
      expect(YgoProPacket.deserialize(Uint8List.fromList([1])), isEmpty);
    });

    test('deserializes buffer with incomplete packet', () {
      // packetLen=10, need 10+2=12 bytes, only 4 present → empty
      final wire = Uint8List.fromList([10, 0, 1, 0xa]);
      final packets = YgoProPacket.deserialize(wire);
      expect(packets, isEmpty);
    });

    test('YgoProPacket.create shorthand', () {
      final pkt = YgoProPacket.create(18, Uint8List.fromList([1, 2, 3]));
      expect(pkt.packetLen, 4);
      expect(pkt.proto, 18);
      expect(pkt.exData, Uint8List.fromList([1, 2, 3]));
    });
  });
}
