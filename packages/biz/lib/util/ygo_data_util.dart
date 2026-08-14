
import 'dart:typed_data';

/// 把卡组中的卡片代码编码成服务端需要的 little-endian 字节序列。
Uint8List deckToBytes(List<int> codes) {
  final bytes = Uint8List(codes.length * 4);
  final bd = ByteData.view(bytes.buffer);
  for (int i = 0; i < codes.length; i++) {
    bd.setInt32(i * 4, codes[i], Endian.little);
  }
  return bytes;
}