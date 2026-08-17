import 'package:duel_room2/pages/duel/duel_field_state.dart';
import 'package:duelink/duelink.dart' show PlayerInfo, RoomMode;
import 'package:flutter_test/flutter_test.dart';

/// tag 满员 4 座位：队伍 0 = A(0)/C(2)，队伍 1 = B(1)/D(3)。
const List<PlayerInfo> kTagPlayers = [
  PlayerInfo(name: 'A', pos: 0),
  PlayerInfo(name: 'B', pos: 1),
  PlayerInfo(name: 'C', pos: 2),
  PlayerInfo(name: 'D', pos: 3),
];

const List<PlayerInfo> k1v1Players = [
  PlayerInfo(name: 'Me', pos: 0),
  PlayerInfo(name: 'Opp', pos: 1),
];

void main() {
  group('teamOfSeat / seatsOfTeam', () {
    test('teamOfSeat：座位 0,2 = 队伍 0；座位 1,3 = 队伍 1', () {
      expect(teamOfSeat(0), 0);
      expect(teamOfSeat(1), 1);
      expect(teamOfSeat(2), 0);
      expect(teamOfSeat(3), 1);
    });

    test('seatsOfTeam tag：返回同队队友（座位升序）', () {
      expect(seatsOfTeam(0, kTagPlayers).map((p) => p.name), ['A', 'C']);
      expect(seatsOfTeam(1, kTagPlayers).map((p) => p.name), ['B', 'D']);
    });

    test('seatsOfTeam 1v1：每队恰一座位，退化为恒等映射', () {
      expect(seatsOfTeam(0, k1v1Players).map((p) => p.name), ['Me']);
      expect(seatsOfTeam(1, k1v1Players).map((p) => p.name), ['Opp']);
    });

    test('seatsOfTeam 忽略观战位（pos==7）', () {
      final players = const [...kTagPlayers, PlayerInfo(name: 'Spec', pos: 7)];
      expect(seatsOfTeam(1, players).map((p) => p.name), ['B', 'D']);
    });

    test('teamDisplayName：tag 用 " / " 连接队友；1v1 单名；空则 fallback', () {
      expect(teamDisplayName(0, kTagPlayers, fallback: '我方'), 'A / C');
      expect(teamDisplayName(1, kTagPlayers, fallback: '对方'), 'B / D');
      expect(teamDisplayName(0, k1v1Players, fallback: '我方'), 'Me');
      expect(teamDisplayName(1, k1v1Players, fallback: '对方'), 'Opp');
      expect(teamDisplayName(0, const [], fallback: '我方'), '我方');
    });
  });

  group('DuelFieldState.isTagMode', () {
    test('roomMode 已知时以其为准', () {
      expect(const DuelFieldState(roomMode: RoomMode.tag).isTagMode, isTrue);
      expect(
        const DuelFieldState(roomMode: RoomMode.match).isTagMode,
        isFalse,
      );
      // 即使列表里有 4 个座位，显式非 tag 模式不判 tag。
      expect(
        const DuelFieldState(
          roomMode: RoomMode.match,
          players: kTagPlayers,
        ).isTagMode,
        isFalse,
      );
    });

    test('roomMode 未同步时退回「4 决斗座位」启发式', () {
      expect(const DuelFieldState(players: kTagPlayers).isTagMode, isTrue);
      expect(const DuelFieldState(players: k1v1Players).isTagMode, isFalse);
      // 观战位不计入决斗座位数。
      expect(
        const DuelFieldState(
          players: [
            ...k1v1Players,
            PlayerInfo(name: 'S1', pos: 7),
            PlayerInfo(name: 'S2', pos: 7),
          ],
        ).isTagMode,
        isFalse,
      );
    });
  });

  group('playerNameOf', () {
    test('1v1 行为不变：座位精确匹配 + 占位兜底', () {
      const s = DuelFieldState(roomMode: RoomMode.match, players: k1v1Players);
      expect(s.playerNameOf(0), 'Me');
      expect(s.playerNameOf(1), 'Opp');
      expect(s.playerNameOf(7), '玩家7');
    });

    test('tag：按回合数推导当前行动座位（回合 1..4 → 座位 0..3）', () {
      // handleStart 置 turnCount=1，MSG_NEW_TURN（含第 1 回合）各 +1，
      // 故第 T 回合期间 turnCount == T+1。
      DuelFieldState atTurn(int turn) => DuelFieldState(
        roomMode: RoomMode.tag,
        players: kTagPlayers,
        turnCount: turn + 1,
      );
      expect(atTurn(1).playerNameOf(0), 'A'); // 座位 0
      expect(atTurn(2).playerNameOf(1), 'B'); // 座位 1
      expect(atTurn(3).playerNameOf(0), 'C'); // 座位 2
      expect(atTurn(4).playerNameOf(1), 'D'); // 座位 3
      expect(atTurn(5).playerNameOf(0), 'A'); // 轮转回座位 0
    });

    test('tag：查询非当前行动队伍时退回该队首座位', () {
      // 第 1 回合（turnCount=2）队伍 0 行动中；查询队伍 1 → 首座位 B。
      final s = DuelFieldState(
        roomMode: RoomMode.tag,
        players: kTagPlayers,
        turnCount: 2,
      );
      expect(s.playerNameOf(1), 'B');
    });

    test('tag：首个 MSG_NEW_TURN 之前无法推导，退回队伍首座位', () {
      final s = DuelFieldState(
        roomMode: RoomMode.tag,
        players: kTagPlayers,
        turnCount: 1,
      );
      expect(s.playerNameOf(0), 'A');
      expect(s.playerNameOf(1), 'B');
    });

    test('tag 判定经启发式（roomMode 未同步）同样生效', () {
      // 第 2 回合（turnCount=3）→ 座位 1。
      final s = DuelFieldState(players: kTagPlayers, turnCount: 3);
      expect(s.playerNameOf(1), 'B');
      expect(s.playerNameOf(0), 'A'); // 非行动队伍 → 首座位
    });

    test('tag：空玩家列表退回占位名', () {
      const s = DuelFieldState(roomMode: RoomMode.tag, turnCount: 2);
      expect(s.playerNameOf(0), '玩家0');
    });

    test('tag：队伍只有一个座位时直接返回该座位名', () {
      final s = DuelFieldState(
        roomMode: RoomMode.tag,
        players: const [PlayerInfo(name: 'Solo', pos: 2)],
        turnCount: 2,
      );
      expect(s.playerNameOf(0), 'Solo');
    });
  });
}
