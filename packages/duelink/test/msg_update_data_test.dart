/// MSG_UPDATE_DATA 里侧隐藏卡记录解析测试。
///
/// 线协议事实（ygopro single_duel.cpp RefreshMzone/RefreshSzone）：
/// 服务端向对方与观战隐藏里侧卡的方式是——保留记录长度字段、
/// 整个 payload（flag 及后续字段）memset 置零。空槽则是 len=4 无 payload。
///
/// 历史 bug：解析器把 flag==0 的记录当空记录丢弃，biz 整区重建时
/// 里侧卡被抹掉（对方场上一只里侧怪兽完全不可见；攻击它时选择
/// 目标在场上找不到卡，选择窗口退化为模态弹窗）。
library;

import 'dart:typed_data';

import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

/// 写一条快照记录：len 包含自身长度。
void _writeRecord(BytesBuilder w, Uint8List payload) {
  final lenBytes = Uint8List(4)
    ..buffer.asByteData().setInt32(0, payload.length + 4, Endian.little);
  w.add(lenBytes);
  w.add(payload);
}

Uint8List _emptyRecord() {
  final bytes = Uint8List(4)
    ..buffer.asByteData().setInt32(0, 4, Endian.little);
  return bytes;
}

/// 表侧卡记录 payload：flag=CODE|POSITION + code + c/l/s/p。
Uint8List _faceUpRecord(int code, int controller, int zone, int seq, int pos) {
  final payload = Uint8List(12);
  final d = ByteData.view(payload.buffer);
  d.setInt32(0, UPDATE_FLAG_CODE | UPDATE_FLAG_POSITION, Endian.little);
  d.setInt32(4, code, Endian.little);
  payload[8] = controller;
  payload[9] = zone;
  payload[10] = seq;
  payload[11] = pos;
  return payload;
}

/// 组一条 MSG_UPDATE_DATA 报文体（player + zone + records）。
/// records 元素：长度 4 视为空槽完整记录，其余视为 payload 加 len 前缀。
Uint8List _updateDataBytes(int player, int zone, List<Uint8List> records) {
  final w = BytesBuilder();
  w.add([player, zone]);
  for (final r in records) {
    if (r.length == 4) {
      w.add(r); // 空槽：len=4
    } else {
      _writeRecord(w, r);
    }
  }
  return w.toBytes();
}

void main() {
  group('MsgUpdateData.decode 里侧隐藏卡（全零 payload）', () {
    test('MZONE 快照：flag=0 记录按槽位序号生成占位 action', () {
      // 对方怪兽区 7 槽：slot2 为里侧怪兽（len=16 全零），其余空槽。
      final data = _updateDataBytes(1, CARD_ZONE_MZONE, [
        _emptyRecord(),
        _emptyRecord(),
        Uint8List(12), // 里侧隐藏卡：len=16，payload 全零
        _emptyRecord(),
        _emptyRecord(),
        _emptyRecord(),
        _emptyRecord(),
      ]);
      final msg = MsgUpdateData.decode(data);
      expect(msg.actions, hasLength(1));
      final hidden = msg.actions.single;
      expect(hidden.flag, 0);
      expect(hidden.code, isNull);
      expect(hidden.location, isNotNull);
      expect(hidden.location!.controller, 1);
      expect(hidden.location!.location, CARD_ZONE_MZONE);
      expect(hidden.location!.sequence, 2);
      expect(hidden.location!.position, POS_FACEDOWN_DEFENSE);
    });

    test('MZONE 快照：表侧卡与里侧卡混合，槽位序号不错位', () {
      final data = _updateDataBytes(0, CARD_ZONE_MZONE, [
        _faceUpRecord(89631139, 0, CARD_ZONE_MZONE, 0, POS_FACEUP_ATTACK),
        _emptyRecord(),
        Uint8List(12), // slot2 里侧
        _emptyRecord(),
        _emptyRecord(),
        _emptyRecord(),
        _emptyRecord(),
      ]);
      final msg = MsgUpdateData.decode(data);
      expect(msg.actions, hasLength(2));
      expect(msg.actions[0].code, 89631139);
      expect(msg.actions[0].location!.sequence, 0);
      expect(msg.actions[1].flag, 0);
      expect(msg.actions[1].location!.sequence, 2);
    });

    test('SZONE 快照：里侧魔陷同样生成占位 action', () {
      final data = _updateDataBytes(1, CARD_ZONE_SZONE, [
        _emptyRecord(),
        Uint8List(12), // slot1 里侧魔陷
        _emptyRecord(),
        _emptyRecord(),
        _emptyRecord(),
      ]);
      final msg = MsgUpdateData.decode(data);
      expect(msg.actions, hasLength(1));
      expect(msg.actions.single.location!.location, CARD_ZONE_SZONE);
      expect(msg.actions.single.location!.sequence, 1);
    });

    test('动态区域（手牌）的全零记录不生成占位（无槽位语义）', () {
      final data = _updateDataBytes(1, CARD_ZONE_HAND, [
        Uint8List(12), // 异常/隐藏记录：手牌无固定槽位，不占位
      ]);
      final msg = MsgUpdateData.decode(data);
      expect(msg.actions, isEmpty);
    });
  });
}
