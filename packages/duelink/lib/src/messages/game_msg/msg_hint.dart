import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_HINT (0x02) — 服务端提示消息。
///
/// 载荷为 `hintCommand + hintPlayer + hintData`，用于传递效果提示、选择文案、
/// 属性/种族/数值等上下文信息。
class MsgHint {
  final int hintCommand;
  final int hintPlayer;
  final int hintData;

  const MsgHint({
    required this.hintCommand,
    required this.hintPlayer,
    required this.hintData,
  });

  MsgHintType get hintType {
    switch (hintCommand) {
      case 1:
        return MsgHintType.event;
      case 2:
        return MsgHintType.message;
      case 3:
        return MsgHintType.selectMessage;
      case 4:
        return MsgHintType.optionSelected;
      case 5:
        return MsgHintType.effect;
      case 6:
        return MsgHintType.race;
      case 7:
        return MsgHintType.attribute;
      case 8:
        return MsgHintType.code;
      case 9:
        return MsgHintType.number;
      case 10:
        return MsgHintType.card;
      case 11:
        return MsgHintType.zone;
      default:
        return MsgHintType.unknown;
    }
  }

  int get funcId => MSG_HINT;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(hintCommand);
    w.writeUint8(hintPlayer);
    w.writeInt32(hintData);
    return w.toBytes();
  }

  static MsgHint decode(Uint8List data) {
    final r = BufferReader(data);
    return MsgHint(
      hintCommand: r.readUint8(),
      hintPlayer: r.readUint8(),
      hintData: r.readInt32(),
    );
  }

  @override
  String toString() =>
      'MsgHint(hintCommand:$hintCommand hintPlayer:$hintPlayer hintData:$hintData)';
}

enum MsgHintType {
  unknown,
  event,
  message,
  selectMessage,
  optionSelected,
  effect,
  race,
  attribute,
  code,
  number,
  card,
  zone,
}
