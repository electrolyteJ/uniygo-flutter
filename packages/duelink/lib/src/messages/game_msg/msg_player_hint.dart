import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_PLAYER_HINT (0xA5) — 玩家级提示状态更新。
///
/// `hintType` 对应 ygopro 的 `PHINT_*` 常量；当前常见的是描述增删。
class MsgPlayerHint {
  final int player;
  final int hintType;
  final int value;

  const MsgPlayerHint({
    required this.player,
    required this.hintType,
    required this.value,
  });

  MsgPlayerHintKind get kind {
    switch (hintType) {
      case 6:
        return MsgPlayerHintKind.descriptionAdd;
      case 7:
        return MsgPlayerHintKind.descriptionRemove;
      default:
        return MsgPlayerHintKind.unknown;
    }
  }

  bool get isDescriptionAdd => kind == MsgPlayerHintKind.descriptionAdd;
  bool get isDescriptionRemove => kind == MsgPlayerHintKind.descriptionRemove;

  int get funcId => MSG_PLAYER_HINT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(hintType);
    w.writeInt32(value);
    return w.toBytes();
  }

  static MsgPlayerHint decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgPlayerHint(
      player: r.readUint8(),
      hintType: r.readUint8(),
      value: r.readInt32(),
    );
  }

  @override
  String toString() =>
      'MsgPlayerHint(player:$player hintType:$hintType value:$value)';
}

enum MsgPlayerHintKind {
  unknown,
  descriptionAdd,
  descriptionRemove,
}
