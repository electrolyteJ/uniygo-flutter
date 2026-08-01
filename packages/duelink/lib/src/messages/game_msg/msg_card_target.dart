import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CARD_TARGET (0x60) — 建立卡牌取对象关系。
class MsgCardTarget {
  final CardLocation source;
  final CardLocation target;

  const MsgCardTarget({required this.source, required this.target});

  int get funcId => MSG_CARD_TARGET;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeCardLocation(source);
    w.writeCardLocation(target);
    return w.toBytes();
  }

  static MsgCardTarget decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgCardTarget(
      source: r.readCardLocation(),
      target: r.readCardLocation(),
    );
  }

  @override
  String toString() => 'MsgCardTarget(source:$source target:$target)';
}
