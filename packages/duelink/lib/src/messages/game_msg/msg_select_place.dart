import 'dart:typed_data';
import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_PLACE (0x12) / MSG_SELECT_DISFIELD (0x18) — 选择场地区域交互。
///
/// 两个消息的线格式一致，都是 `player + count + fieldMask`：
/// - `MSG_SELECT_PLACE` 用于从可用区域中选择放置位置
/// - `MSG_SELECT_DISFIELD` 用于选择被禁用/受限的区域位图
class MsgSelectPlace {
  final int player;
  final int count;
  final int field;

  const MsgSelectPlace({
    required this.player,
    required this.count,
    required this.field,
  });

  /// 默认函数号使用 `MSG_SELECT_PLACE`；当作 `MSG_SELECT_DISFIELD` 解码时，
  /// 外层 `StocGameMessage.func` 会保留原始命令号。
  int get funcId => MSG_SELECT_PLACE;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(player);
    w.writeUint8(count);
    w.writeUint32(field);
    return w.toBytes();
  }

  static MsgSelectPlace decode(Uint8List data) {
    final r = BufferReader(data);
    final player = r.readUint8();
    var count = r.readUint8();
    if (count == 0) count = 1;
    final field = r.readUint32();
    return MsgSelectPlace(player: player, count: count, field: field);
  }

  @override
  String toString() =>
      'MsgSelectPlace(player:$player count:$count field:$field)';
}
