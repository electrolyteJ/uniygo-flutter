import 'dart:typed_data';

import '../../constants.dart';
import '../../protocol/buffer_io.dart';

/// MSG_SELECT_SUM (0x17) — 选择合计数值交互。
///
/// 这里已结构化解析 must-select / selectable 两段卡牌列表，且保留 [rawData]
/// 作为协议回退数据。
///
/// [rawData] 不是冗余副本：它允许调用方在现有结构化字段之外，继续保留完整原消息，
/// 用于协议透传、录包调试、或兼容将来新增但当前尚未建模的字段。
class MsgSelectSum {
  final int overflow;
  final int player;
  final int levelSum;
  final int min;
  final int max;
  final List<MsgSelectSumInfo> mustSelectCards;
  final List<MsgSelectSumInfo> selectableCards;
  final Uint8List rawData;

  const MsgSelectSum({
    required this.overflow,
    required this.player,
    required this.levelSum,
    required this.min,
    required this.max,
    required this.mustSelectCards,
    required this.selectableCards,
    required this.rawData,
  });

  int get funcId => MSG_SELECT_SUM;

  Uint8List encode() {
    final w = BufferWriter();
    w.writeUint8(overflow);
    w.writeUint8(player);
    w.writeInt32(levelSum);
    w.writeUint8(min);
    w.writeUint8(max);
    w.writeUint8(mustSelectCards.length);
    for (final info in mustSelectCards) {
      _writeInfo(w, info);
    }
    w.writeUint8(selectableCards.length);
    for (final info in selectableCards) {
      _writeInfo(w, info);
    }
    return w.toBytes();
  }

  static void _writeInfo(BufferWriter w, MsgSelectSumInfo info) {
    w.writeInt32(info.code);
    w.writeCardShortLocation(info.location);
    if (info.level1 == info.level2) {
      w.writeInt32(info.level1);
    } else {
      w.writeInt32((info.level2 << 16) | (info.level1 & 0xffff));
    }
  }

  static MsgSelectSum decode(Uint8List data) {
    final rawData = Uint8List.fromList(data);
    final r = BufferReader(data);
    final overflow = r.readUint8();
    final player = r.readUint8();
    final levelSum = r.readInt32();
    final min = r.readUint8();
    final max = r.readUint8();

    MsgSelectSumInfo readInfo(int response) {
      final code = r.readInt32();
      final location = r.readCardShortLocation();
      final para = r.readInt32();
      var level1 = para & 0xffff;
      var level2 = para >> 16;
      if ((para & 0x80000000) != 0) {
        level1 = para & 0x7fffffff;
        level2 = level1;
      }
      if (level2 == 0) {
        level2 = level1;
      }
      return MsgSelectSumInfo(
        code: code,
        location: location,
        level1: level1,
        level2: level2,
        response: response,
      );
    }

    final mustCount = r.readUint8();
    final mustSelectCards = <MsgSelectSumInfo>[];
    for (var i = 0; i < mustCount; i++) {
      mustSelectCards.add(readInfo(i));
    }

    final selectableCount = r.readUint8();
    final selectableCards = <MsgSelectSumInfo>[];
    for (var i = 0; i < selectableCount; i++) {
      selectableCards.add(readInfo(i));
    }

    return MsgSelectSum(
      overflow: overflow,
      player: player,
      levelSum: levelSum,
      min: min,
      max: max,
      mustSelectCards: mustSelectCards,
      selectableCards: selectableCards,
      rawData: rawData,
    );
  }

  @override
  String toString() =>
      'MsgSelectSum(player:$player levelSum:$levelSum must:${mustSelectCards.length} selectable:${selectableCards.length})';
}

class MsgSelectSumInfo {
  final int code;
  final CardShortLocation location;
  final int level1;
  final int level2;
  final int response;

  const MsgSelectSumInfo({
    required this.code,
    required this.location,
    required this.level1,
    required this.level2,
    required this.response,
  });
}
