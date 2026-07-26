import 'dart:typed_data';

/// Wire-level packet format matching ygopro server protocol:
/// [packetLen: uint16 LE] [proto: uint8] [exData: ...]
///
/// packetLen = 1 + exData.length (includes the proto byte).
/// Total frame size = packetLen + 2 = exData.length + 3 bytes.
class YgoProPacket {
  /// Length written to the wire (= 1 + exData.length, includes proto byte)
  final int packetLen;
  final int proto;
  final Uint8List exData;

  const YgoProPacket({
    required this.packetLen,
    required this.proto,
    required this.exData,
  });

  /// Serialize to wire format bytes.
  Uint8List serialize() {
    final result = Uint8List(packetLen + 2);
    final bd = ByteData.view(result.buffer);
    bd.setUint16(0, packetLen, Endian.little);
    bd.setUint8(2, proto);
    result.setAll(3, exData);
    return result;
  }

  /// Deserialize from a buffer, handling sticky packets (multiple packets
  /// concatenated in one buffer).
  static List<YgoProPacket> deserialize(Uint8List data) {
    if (data.length < 3) return [];

    final packets = <YgoProPacket>[];
    int offset = 0;

    while (offset < data.length) {
      if (data.length - offset < 3) break;

      final bd = ByteData.view(data.buffer, data.offsetInBytes + offset);
      final packetLen = bd.getUint16(0, Endian.little);

      // packetLen includes proto byte, so frame = packetLen + 2 bytes total
      if (packetLen + 2 > data.length - offset) break;
      // Need at least 1 byte of exData (after proto byte)
      if (packetLen < 1) break;

      final proto = bd.getUint8(2);
      final exDataLen = packetLen - 1; // subtract the proto byte
      final exData = Uint8List.view(
          data.buffer, data.offsetInBytes + offset + 3, exDataLen);

      packets.add(YgoProPacket(packetLen: packetLen, proto: proto, exData: exData));
      offset += packetLen + 2;
    }

    return packets;
  }

  /// Create a packet from proto ID and payload bytes.
  factory YgoProPacket.create(int proto, Uint8List exData) {
    return YgoProPacket(packetLen: exData.length + 1, proto: proto, exData: exData);
  }

  @override
  String toString() => 'YgoProPacket(proto: $proto, len: $packetLen)';
}
