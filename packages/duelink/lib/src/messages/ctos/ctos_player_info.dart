import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// CTOS_PLAYER_INFO (16)
///
/// 告知 ygopro 服务端当前玩家的昵称。
///
/// 协议格式:
/// - name: [unsigned short; 20] — 玩家昵称，UTF-16 LE 编码，固定 40 字节
///
/// 参考 neos-ts 的 ctosPlayerInfo.ts 定义。
class CtosPlayerInfo {
  final String name;
  const CtosPlayerInfo({required this.name});
  int get protoId => CTOS_PLAYER_INFO;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUtf16Fixed(name);
    return w.toBytes();
  }

  static CtosPlayerInfo decode(Uint8List data) {
    final r = BufferReader(data);
    return CtosPlayerInfo(name: r.readUtf16(maxBytes: 40));
  }

  @override
  String toString() => 'CtosPlayerInfo($name)';
}
