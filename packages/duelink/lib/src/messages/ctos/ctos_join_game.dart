import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// CTOS_JOIN_GAME (18)
///
/// 加入房间。
///
/// 协议格式:
/// - version:   unsigned short — 版本号
/// - _align:    unsigned short — 对齐填充（始终为 0）
/// - gameId:    unsigned int — 永远是 0（保留字段）
/// - passWd:    [unsigned short; 20] — 房间密码，UTF-16 LE 编码
///
/// 参考 neos-ts 的 ctosJoinGame.ts 定义。
class CtosJoinGame {
  final int version;
  final int gameId;
  final String passwd;

  const CtosJoinGame({
    required this.version,
    required this.gameId,
    required this.passwd,
  });

  int get protoId => CTOS_JOIN_GAME;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint16(version);
    w.writeUint16(0); // align
    w.writeUint32(gameId);
    w.writeUtf16Fixed(passwd);
    return w.toBytes();
  }

  static CtosJoinGame decode(Uint8List data) {
    final r = BufferReader(data);
    final version = r.readUint16();
    r.skip(2); // align
    final gameId = r.readUint32();
    final passwd = r.readUtf16(maxBytes: 40);
    return CtosJoinGame(version: version, gameId: gameId, passwd: passwd);
  }

  @override
  String toString() => 'CtosJoinGame(v:$version)';
}
