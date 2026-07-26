import 'dart:typed_data';
import 'package:duelink/duelink.dart';
import 'package:duelink/src/protocol/adapter.dart';
import 'package:duelink/src/protocol/packet.dart';
import 'package:duelink/src/constants.dart';
import 'package:test/test.dart';

void main() {
  group('Protocol adapter', () {
    test('adaptCtos: CTOS -> YgoProPacket roundtrip', () {
      final msg = YgoCtosMsg.handResult(CtosHandResult(hand: 2));
      final packet = adaptCtos(msg);
      expect(packet.proto, CTOS_HAND_RESULT);
      expect(packet.exData, [2]);
    });

    test('adaptStoc: YgoProPacket -> STOC roundtrip', () {
      final inner = StocTypeChange(isHost: true, selfType: 0);
      final packet = YgoProPacket.create(STOC_TYPE_CHANGE, inner.encode());
      final msg = adaptStoc(packet);
      expect(msg.protoId, STOC_TYPE_CHANGE);
      expect(msg.typeChange?.isHost, true);
      expect(msg.typeChange?.selfType, 0);
    });

    test('CTOS full roundtrip: message -> packet -> message', () {
      final original = YgoCtosMsg.handResult(CtosHandResult(hand: 3));
      final packet = adaptCtos(original);
      // Deserialize wire bytes to simulate network
      final wireBytes = packet.serialize();
      final deserialized = YgoProPacket.deserialize(wireBytes).first;
      final restored =
          YgoCtosMsg.decode(deserialized.proto, deserialized.exData);
      expect(restored.protoId, CTOS_HAND_RESULT);
      expect(restored.handResult?.hand, 3);
    });
  });
}
