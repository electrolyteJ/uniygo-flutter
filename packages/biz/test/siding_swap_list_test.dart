/// 换备派生状态测试：换牌清单、提交标记、对手就绪。
///
/// 这几个 getter 是换备界面（08z）唯一的「算出来」的数据——卡面网格、
/// 副卡组列表、就绪行都只是把 [DuelRoomState.sidingDeck] 画出来，唯独
/// 「换入 / 换出」和「张数守恒」需要按基准做差集。差集算错会让玩家看到
/// 一份和实际提交不符的清单，所以单独覆盖。
library;

import 'package:biz/duel/room/duel_room_state.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/ygo_data.dart';

/// 造一张主卡组普通怪兽（type 位 0x11 = 怪兽 | 通常）。
CardInfo _main(int code, [String? name]) =>
    CardInfo(code: code, type: 0x11, name: name ?? '主$code');

/// 造一张额外卡组怪兽（0x41 = 怪兽 | 融合）。
CardInfo _extra(int code, [String? name]) =>
    CardInfo(code: code, type: 0x41, name: name ?? '额$code');

void main() {
  /// 基准：主 3 / 额 1 / 副 2。
  ResolvedDeck baseline() => (
    main: [_main(101), _main(102), _main(103)],
    extra: [_extra(201)],
    side: [_main(301), _main(302)],
  );

  DuelRoomState stateWith({
    required ResolvedDeck current,
    ResolvedDeck? base,
    bool submitted = false,
    List<PlayerInfo> players = const [],
    PlayerType selfType = PlayerType.player1,
  }) => DuelRoomState(
    stage: const RoomSideDecking(),
    selfType: selfType,
    players: players,
    sidingDeck: current,
    sidingBaseline: base ?? baseline(),
    sidingSubmitted: submitted,
  );

  group('sidingSwapList', () {
    test('未做任何调整时清单为空', () {
      final s = stateWith(current: baseline());
      expect(s.sidingSwapList.inCards, isEmpty);
      expect(s.sidingSwapList.outCards, isEmpty);
      expect(s.hasSidingChanges, isFalse);
    });

    test('主 101 换出、副 301 换入', () {
      // 101 从主卡组移到副卡组，301 从副卡组移到主卡组。
      final current = (
        main: [_main(301), _main(102), _main(103)],
        extra: [_extra(201)],
        side: [_main(101), _main(302)],
      );
      final s = stateWith(current: current);
      expect(s.sidingSwapList.inCards, [(code: 301, count: 1)]);
      expect(s.sidingSwapList.outCards, [(code: 101, count: 1)]);
      expect(s.hasSidingChanges, isTrue);
    });

    test('同一张卡换两张时聚合为一行 ×2', () {
      final base = (
        main: [_main(101), _main(102), _main(103), _main(104)],
        extra: [_extra(201)],
        side: [_main(301), _main(301), _main(302)],
      );
      final current = (
        main: [_main(301), _main(301), _main(103), _main(104)],
        extra: [_extra(201)],
        side: [_main(101), _main(102), _main(302)],
      );
      final s = stateWith(current: current, base: base);
      expect(s.sidingSwapList.inCards, [(code: 301, count: 2)]);
      expect(s.sidingSwapList.outCards, [(code: 101, count: 1), (code: 102, count: 1)]);
    });

    test('额外卡组换出走额外卡组路径', () {
      // 额 201 出、副 302 进额外。
      final current = (
        main: [_main(101), _main(102), _main(103)],
        extra: [_extra(302)],
        side: [_main(301), _extra(201)],
      );
      final s = stateWith(current: current);
      expect(s.sidingSwapList.inCards, [(code: 302, count: 1)]);
      expect(s.sidingSwapList.outCards, [(code: 201, count: 1)]);
    });

    test('换入按副卡组顺序输出', () {
      // 基准副卡 [301, 302]；当前副卡 [302, 301]（顺序对调但张数不变），
      // 主卡组里 101/103 换成了 301/302。换入项 301/302 在副卡组里
      // 的阅读顺序是 [302, 301]，清单也应如此。
      final current = (
        main: [_main(302), _main(102), _main(301)],
        extra: [_extra(201)],
        side: [_main(101), _main(103)],
      );
      final s = stateWith(current: current);
      expect(
        s.sidingSwapList.inCards.map((e) => e.code).toList(),
        [302, 301],
        reason: '换入顺序应跟随当前副卡组的阅读顺序',
      );
    });

    test('基准或草稿缺失时不崩溃且返回空清单', () {
      final s = DuelRoomState(
        stage: const RoomSideDecking(),
        sidingDeck: baseline(),
      );
      expect(s.sidingSwapList.inCards, isEmpty);
      expect(s.sidingSwapList.outCards, isEmpty);
      expect(s.hasSidingChanges, isFalse);
    });
  });

  group('isSidingCountsValid', () {
    test('数量与基准一致时为 true', () {
      expect(stateWith(current: baseline()).isSidingCountsValid, isTrue);
    });

    test('主卡组少一张时为 false', () {
      final current = (
        main: [_main(101), _main(102)],
        extra: [_extra(201)],
        side: [_main(301), _main(302), _main(103)],
      );
      expect(stateWith(current: current).isSidingCountsValid, isFalse);
    });
  });

  group('对手就绪', () {
    test('对手座位 ready 时为 true', () {
      final s = stateWith(
        current: baseline(),
        players: const [
          PlayerInfo(name: 'me', pos: 0, ready: true),
          PlayerInfo(name: 'op', pos: 1, ready: true),
        ],
      );
      expect(s.isOpponentReady, isTrue);
    });

    test('对手座位未 ready 时为 false', () {
      final s = stateWith(
        current: baseline(),
        players: const [
          PlayerInfo(name: 'me', pos: 0, ready: true),
          PlayerInfo(name: 'op', pos: 1),
        ],
      );
      expect(s.isOpponentReady, isFalse);
    });

    test('我是 1 号位时对手是 0 号位（不能按 pos 顺序猜）', () {
      final s = stateWith(
        current: baseline(),
        selfType: PlayerType.player2,
        players: const [
          PlayerInfo(name: 'op', pos: 0, ready: true),
          PlayerInfo(name: 'me', pos: 1, ready: false),
        ],
      );
      expect(s.isOpponentReady, isTrue);
    });

    test('观战者（座位非 0-3）恒为 false', () {
      final s = stateWith(
        current: baseline(),
        selfType: PlayerType.unknown,
        players: const [PlayerInfo(name: 'op', pos: 1, ready: true)],
      );
      expect(s.isOpponentReady, isFalse);
    });
  });

  group('sidingSubmitted 默认值与 copyWith', () {
    test('默认未提交', () {
      expect(stateWith(current: baseline()).sidingSubmitted, isFalse);
      expect(stateWith(current: baseline()).isSidingSubmitted, isFalse);
    });

    test('copyWith 可以显式置回 false（不是 only-if-non-null）', () {
      final s = stateWith(current: baseline(), submitted: true);
      expect(s.sidingSubmitted, isTrue);
      expect(s.copyWith(sidingSubmitted: false).sidingSubmitted, isFalse);
    });
  });
}
