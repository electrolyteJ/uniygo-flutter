import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CANCEL_TARGET (0x61) — 取消卡牌取对象关系。
class MsgCancelTarget {
  final CardLocation source;
  final CardLocation target;

  const MsgCancelTarget({required this.source, required this.target});

  int get funcId => MSG_CANCEL_TARGET;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeCardLocation(source);
    w.writeCardLocation(target);
    return w.toBytes();
  }

  static MsgCancelTarget decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgCancelTarget(
      source: r.readCardLocation(),
      target: r.readCardLocation(),
    );
  }

  @override
  String toString() => 'MsgCancelTarget(source:$source target:$target)';
}
