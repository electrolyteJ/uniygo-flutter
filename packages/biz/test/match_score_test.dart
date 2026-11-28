import 'package:biz/duel/room/duel_room_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// match 比分累计（BO3）的单元测试。
///
/// 背景：YGOPro 协议只下发单局 `MSG_WIN`（含 `winPlayer`），不汇总本场
/// 胜负。客户端自己累计，所以「同一局只记一次」的幂等性必须被测试守住
/// ——换备往返、热重载、页面重建都可能让同一份 result 被反复观察到。
void main() {
  group('比分累计', () {
    test('赢一局加我方胜场', () {
      var s = const DuelRoomState();
      s = s.copyWith(myMatchWins: s.myMatchWins + 1);
      expect(s.myMatchWins, 1);
      expect(s.opponentMatchWins, 0);
      expect(s.matchScoreLabel, '1 : 0');
    });

    test('平局不加胜场，只加平局数', () {
      var s = const DuelRoomState();
      s = s.copyWith(matchDraws: s.matchDraws + 1);
      expect(s.myMatchWins, 0);
      expect(s.opponentMatchWins, 0);
      expect(s.matchDraws, 1);
    });

    test('BO3 两胜即结束', () {
      const s = DuelRoomState(myMatchWins: 2);
      expect(s.isMatchOver, true);
      const t = DuelRoomState(myMatchWins: 1, opponentMatchWins: 1);
      expect(t.isMatchOver, false);
    });

    test('平局不计胜场，可能打超过 3 局', () {
      const s = DuelRoomState(opponentMatchWins: 2, matchDraws: 1);
      expect(s.isMatchOver, true);
      // 局号跟着实际局数走，不会出现 GAME 4 / 3。
      const t = DuelRoomState(myMatchWins: 1, opponentMatchWins: 1);
      expect(t.matchGamesPlayed, 2);
      expect(t.matchGameNumber, 3);
      expect(t.matchGameLabel, 'GAME 3 / 3');
    });
  });

  group('局号文案', () {
    test('开打前是 GAME 1 / 3', () {
      const s = DuelRoomState();
      expect(s.matchGameNumber, 1);
      expect(s.matchGameLabel, 'GAME 1 / 3');
    });

    test('已打 1 局是 GAME 2 / 3（换备发生的位置）', () {
      const s = DuelRoomState(myMatchWins: 1);
      expect(s.matchGameLabel, 'GAME 2 / 3');
    });

    test('异常局数不出现 GAME 4 / 3', () {
      const s = DuelRoomState(myMatchWins: 2, opponentMatchWins: 2);
      expect(s.matchGamesPlayed, 4);
      expect(s.matchGameLabel, 'GAME 5 / 5');
    });
  });

  group('换备起始时刻', () {
    test('默认 null，copyWith 可用 sentinel 显式清空', () {
      final t = DateTime(2026, 11, 28, 12);
      final s = DuelRoomState(sidingStartedAt: t);
      expect(s.sidingStartedAt, t);
      expect(s.copyWith(sidingStartedAt: null).sidingStartedAt, isNull);
      // 不传则保留。
      expect(s.copyWith(errorMessage: 'x').sidingStartedAt, t);
    });
  });
}