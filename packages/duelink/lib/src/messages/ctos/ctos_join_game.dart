import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

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
