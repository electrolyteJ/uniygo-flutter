import 'dart:typed_data';

/// 网络数据包结构定义。
///
/// 遵循 ygopro 服务端协议：
///
/// ```
/// Wire format:
/// ┌───────────────┬───────────┬──────────────┐
/// │ packetLen     │ proto     │ exData       │
/// │ uint16 LE     │ uint8     │ bytes...     │
/// │ (2 bytes)     │ (1 byte)  │ (N bytes)    │
/// └───────────────┴───────────┴──────────────┘
/// ```
///
/// - packetLen: 包长度 = 1 (proto) + exData.length（包含 proto 字节）
/// - proto: 协议标识号（见 constants.dart 中的 CTOS_*/STOC_* 常量）
/// - exData: 协议负载数据
/// - 总帧大小 = packetLen + 2 = exData.length + 3
///
/// 支持粘包反序列化（由于 ygopro 服务端实现问题，可能出现多个包合并在一起的情况）。
///
/// 参考 neos-ts 的 packet.ts 定义。
class YgoProPacket {
  /// 网络字节长度 = 1 + exData.length（包含 proto 字节）
  final int packetLen;
  /// 协议标识号（见 constants.dart 中的 CTOS_*/STOC_* 常量）
  final int proto;
  /// 协议负载数据
  final Uint8List exData;

  const YgoProPacket({
    required this.packetLen,
    required this.proto,
    required this.exData,
  });

  /// 序列化为网络传输格式的字节数组。
  Uint8List serialize() {
    final result = Uint8List(packetLen + 2);
    final bd = ByteData.view(result.buffer);
    bd.setUint16(0, packetLen, Endian.little);
    bd.setUint8(2, proto);
    result.setAll(3, exData);
    return result;
  }

  /// 从网络缓冲区反序列化，自动处理粘包（多个包合并在一起的情况）。
  ///
  /// 返回解析出的包列表。如果缓冲区数据不完整，剩余数据会被丢弃。
  static List<YgoProPacket> deserialize(Uint8List data) {
    if (data.length < 3) return [];

    final packets = <YgoProPacket>[];
    int offset = 0;

    while (offset < data.length) {
      if (data.length - offset < 3) break;

      final bd = ByteData.view(data.buffer, data.offsetInBytes + offset);
      final packetLen = bd.getUint16(0, Endian.little);

      // packetLen 包含 proto 字节，帧 = packetLen + 2 字节
      if (packetLen + 2 > data.length - offset) break;
      // 需要至少 1 字节 exData（proto 之后的负载）
      if (packetLen < 1) break;

      final proto = bd.getUint8(2);
      final exDataLen = packetLen - 1; // 减去 proto 字节
      final exData = Uint8List.view(
          data.buffer, data.offsetInBytes + offset + 3, exDataLen);

      packets.add(YgoProPacket(packetLen: packetLen, proto: proto, exData: exData));
      offset += packetLen + 2;
    }

    return packets;
  }

  /// 由协议标识号和负载字节创建数据包。
  factory YgoProPacket.create(int proto, Uint8List exData) {
    return YgoProPacket(packetLen: exData.length + 1, proto: proto, exData: exData);
  }

  @override
  String toString() => 'YgoProPacket(proto: $proto, len: $packetLen)';
}
