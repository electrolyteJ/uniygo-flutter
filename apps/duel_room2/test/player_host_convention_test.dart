import 'package:duelink/duelink.dart' show PlayerInfo;
import 'package:flutter_test/flutter_test.dart';

/// 复刻 [base_duel_service._onPlayerEnter] 的填充约定：
/// YGOPro 协议没有对局内的房主信号（STOC_TYPE_CHANGE.isHost 只描述自己），
/// 按惯例座位 0 == 建房者/房主，故 `host: pos == 0`。
/// 局限（已记录在 PlayerInfo.host 文档）：房主中途离开后服务器可能
/// 静默转移房主，该字段不会随之更新。
PlayerInfo enterPlayer(String name, int pos) =>
    PlayerInfo(name: name, pos: pos, host: pos == 0);

void main() {
  group('PlayerInfo.host 填充约定', () {
    test('pos==0 记为房主，其余座位否', () {
      expect(enterPlayer('Creator', 0).host, isTrue);
      expect(enterPlayer('Guest', 1).host, isFalse);
      expect(enterPlayer('Guest', 2).host, isFalse);
      expect(enterPlayer('Guest', 3).host, isFalse);
    });

    test('默认值为 false（未显式填充时不误报房主）', () {
      expect(const PlayerInfo(name: 'x', pos: 0).host, isFalse);
      expect(const PlayerInfo(name: 'x', pos: 1).host, isFalse);
    });

    test('copyWith 保留 host 标记', () {
      final host = enterPlayer('Creator', 0);
      expect(host.copyWith(ready: true).host, isTrue);
      // 换座时沿用原标记：协议无更新信号，过期风险在字段文档中声明。
      expect(host.copyWith(pos: 2).host, isTrue);
      final guest = enterPlayer('Guest', 1);
      expect(guest.copyWith(ready: true).host, isFalse);
    });
  });
}
