import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_CARD_HINT (0xA0) — 卡牌级提示状态更新。
///
/// `hintType` 直接对应 ygopro 的 `CHINT_*` 常量；这里保留原值，
/// 并提供 [kind] / [isDescriptionAdd] 等辅助访问。
class MsgCardHint {
  final CardLocation location;
  final int hintType;
  final int value;

  const MsgCardHint({
    required this.location,
    required this.hintType,
    required this.value,
  });

  MsgCardHintKind get kind {
    switch (hintType) {
      case 1:
        return MsgCardHintKind.turn;
      case 2:
        return MsgCardHintKind.card;
      case 3:
        return MsgCardHintKind.race;
      case 4:
        return MsgCardHintKind.attribute;
      case 5:
        return MsgCardHintKind.number;
      case 6:
        return MsgCardHintKind.descriptionAdd;
      case 7:
        return MsgCardHintKind.descriptionRemove;
      default:
        return MsgCardHintKind.unknown;
    }
  }

  bool get isDescriptionAdd => kind == MsgCardHintKind.descriptionAdd;
  bool get isDescriptionRemove => kind == MsgCardHintKind.descriptionRemove;
  bool get isTurnHint => kind == MsgCardHintKind.turn;

  int get funcId => MSG_CARD_HINT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeCardLocation(location);
    w.writeUint8(hintType);
    w.writeInt32(value);
    return w.toBytes();
  }

  static MsgCardHint decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgCardHint(
      location: r.readCardLocation(),
      hintType: r.readUint8(),
      value: r.readInt32(),
    );
  }

  @override
  String toString() =>
      'MsgCardHint(location:$location hintType:$hintType value:$value)';
}

enum MsgCardHintKind {
  unknown,
  turn,
  card,
  race,
  attribute,
  number,
  descriptionAdd,
  descriptionRemove,
}
