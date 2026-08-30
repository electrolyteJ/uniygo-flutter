import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter_test/flutter_test.dart';

/// shouldHoldForDuelResult：AI 对决（本地服务端）在 MSG_WIN 后立即关连接，
/// RoomDuelEnded → RoomNotJoined 紧跟到达，此时必须停留展示结算弹窗
/// 而不是自动离房回首页；其余断开场景维持原有自动离房行为。
void main() {
  group('shouldHoldForDuelResult', () {
    test('决斗结束即断开且已有结果 → 停留展示结算', () {
      expect(
        shouldHoldForDuelResult(
          prev: const RoomDuelEnded(),
          next: const RoomNotJoined(),
          hasDuelResult: true,
        ),
        isTrue,
      );
    });

    test('换备阶段断开 → 不停留（结算可能已被「进入换备」关闭）', () {
      expect(
        shouldHoldForDuelResult(
          prev: const RoomSideDecking(),
          next: const RoomNotJoined(),
          hasDuelResult: true,
        ),
        isFalse,
      );
    });

    test('对局中断线（未出结果）→ 照常离房', () {
      expect(
        shouldHoldForDuelResult(
          prev: const RoomInDuel(isFirstTurn: true),
          next: const RoomNotJoined(),
          hasDuelResult: false,
        ),
        isFalse,
      );
    });

    test('决斗结束但无结果（未收到 MSG_WIN）→ 照常离房', () {
      expect(
        shouldHoldForDuelResult(
          prev: const RoomDuelEnded(),
          next: const RoomNotJoined(),
          hasDuelResult: false,
        ),
        isFalse,
      );
    });

    test('非 RoomNotJoined 转换 → 不停留', () {
      expect(
        shouldHoldForDuelResult(
          prev: const RoomDuelEnded(),
          next: const RoomJoined(),
          hasDuelResult: true,
        ),
        isFalse,
      );
    });
  });
}
