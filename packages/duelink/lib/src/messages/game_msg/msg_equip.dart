import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_EQUIP (0x5D) — 建立装备关系通知。
class MsgEquip {
  final CardLocation source;
  final CardLocation target;

  const MsgEquip({required this.source, required this.target});

  int get funcId => MSG_EQUIP;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeCardLocation(source);
    w.writeCardLocation(target);
    return w.toBytes();
  }

  static MsgEquip decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgEquip(source: r.readCardLocation(), target: r.readCardLocation());
  }

  @override
  String toString() => 'MsgEquip(source:$source target:$target)';
}
