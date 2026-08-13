/// [DuelFieldTracker] 测试：LP / 回合 / 阶段 / revealed 簿记。
library;

import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferWriter;
import 'package:duelink_ai/duelink_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocgcore/ocgcore.dart';

void main() {
  group('DuelFieldTracker LP', () {
    test('damage / recover / pay / lpupdate', () {
      final t = DuelFieldTracker(startLp: 8000);

      var w = BufferWriter()
        ..writeUint8(0)
        ..writeUint32(1500);
      t.observe(MSG_DAMAGE, w.toBytes());
      expect(t.lp, [6500, 8000]);

      w = BufferWriter()
        ..writeUint8(1)
        ..writeUint32(500);
      t.observe(MSG_RECOVER, w.toBytes());
      expect(t.lp, [6500, 8500]);

      w = BufferWriter()
        ..writeUint8(0)
        ..writeUint32(1000);
      t.observe(MSG_PAY_LPCOST, w.toBytes());
      expect(t.lp, [5500, 8500]);

      w = BufferWriter()
        ..writeUint8(1)
        ..writeUint32(4000);
      t.observe(MSG_LPUPDATE, w.toBytes());
      expect(t.lp, [5500, 4000]);
    });

    test('reset 恢复初始状态', () {
      final t = DuelFieldTracker(startLp: 8000);
      var w = BufferWriter()
        ..writeUint8(0)
        ..writeUint32(3000);
      t.observe(MSG_DAMAGE, w.toBytes());
      t.observe(MSG_NEW_TURN, Uint8List.fromList([1]));
      t.reset(4000);
      expect(t.lp, [4000, 4000]);
      expect(t.turn, 0);
      expect(t.turnPlayer, 0);
      expect(t.rawPhase, PHASE_DRAW);
      expect(t.revealed, isEmpty);
    });
  });

  group('DuelFieldTracker turn/phase', () {
    test('new_turn 累计、new_phase 覆写', () {
      final t = DuelFieldTracker();
      t.observe(MSG_NEW_TURN, Uint8List.fromList([0]));
      t.observe(MSG_NEW_PHASE, Uint8List.fromList([PHASE_MAIN1 & 0xff, 0]));
      expect(t.turn, 1);
      expect(t.turnPlayer, 0);
      expect(t.rawPhase, PHASE_MAIN1);

      t.observe(MSG_NEW_TURN, Uint8List.fromList([1]));
      t.observe(
          MSG_NEW_PHASE,
          Uint8List.fromList(
              [PHASE_DAMAGE_CAL & 0xff, (PHASE_DAMAGE_CAL >> 8) & 0xff]));
      expect(t.turn, 2);
      expect(t.turnPlayer, 1);
      expect(t.rawPhase, PHASE_DAMAGE_CAL);
    });
  });

  group('DuelFieldTracker revealed', () {
    test('CONFIRM_CARDS：本 fork 线格式（player + skipPanel + count）', () {
      final t = DuelFieldTracker();
      final w = BufferWriter();
      w.writeUint8(0); // player
      w.writeUint8(0); // skipPanel
      w.writeUint8(2); // count
      // 对方手牌第 5 张公开给 player 0（c != player → 无 o 前缀）
      w.writeUint32(111);
      w.writeUint8(1);
      w.writeUint8(LOCATION_HAND);
      w.writeUint8(4);
      // 自己场上第 3 格（c == player → o 前缀）
      w.writeUint32(222);
      w.writeUint8(0);
      w.writeUint8(LOCATION_MZONE);
      w.writeUint8(2);

      t.observe(MSG_CONFIRM_CARDS, w.toBytes());
      expect(t.revealed, {'h5', 'om3'});
    });

    test('lsToSpec：overlay 后缀单字符 + 对方前缀', () {
      expect(
        DuelFieldTracker.lsToSpec(LOCATION_MZONE, 2, 0, opponent: false),
        'm3',
      );
      expect(
        DuelFieldTracker.lsToSpec(LOCATION_HAND, 0, 0, opponent: true),
        'oh1',
      );
      expect(
        DuelFieldTracker.lsToSpec(
            LOCATION_MZONE | LOCATION_OVERLAY, 1, 2,
            opponent: true),
        'om2c',
      );
      expect(
        DuelFieldTracker.lsToSpec(LOCATION_EXTRA, 7, 0, opponent: false),
        'x8',
      );
    });
  });
}
