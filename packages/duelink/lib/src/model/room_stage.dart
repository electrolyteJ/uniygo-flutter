import 'room_options.dart';
import 'room_player.dart';

/// 房间生命周期状态机。
///
/// 每个状态实例携带该阶段相关的字段，[players] 和 [observerCount]
/// 在整个加入房间后的所有状态间持续追踪。
///
/// ```text
/// NotJoined → Joined → InLobby → Ready <-→ Unready
/// → StartDuel(点击开始决斗) → SelectingHand → HandResult → SelectingTurn
///  → InDuel →        DuelEnded → SideDecking
///      ↑___________________↓
/// ```

sealed class RoomStage {
  /// 房间内玩家列表（含座位号和准备状态）。
  final List<RoomPlayer> players;
  /// 当前观战人数。
  final int observerCount;

  const RoomStage({this.players = const [], this.observerCount = 0});
}

// ─── 具体状态 ───────────────────────────────────────────

/// 未加入房间（初始状态）。
///
/// 触发条件：构造 / disconnect 后重置。
class RoomNotJoined extends RoomStage {
  const RoomNotJoined() : super();
  @override String toString() => 'RoomNotJoined';
}
/// 已加入房间。
class RoomJoined extends RoomStage {
  const RoomJoined() : super();
  @override String toString() => 'RoomJoined';
}

/// 在等待大厅中。
///
/// 触发条件：收到 [STOC_JOIN_GAME] + [STOC_TYPE_CHANGE]。
class RoomInLobby extends RoomStage {
  /// 自身玩家类型。
  final SelfType selfType;
  /// 是否为房主。
  final bool isHost;
  /// 房间配置参数（[STOC_JOIN_GAME] payload）。
  final RoomOptions options;

  const RoomInLobby({
    super.players = const [],
    super.observerCount = 0,
    required this.selfType,
    required this.isHost,
    required this.options,
  });

  @override String toString() => 'RoomInLobby(self:$selfType host:$isHost)';
}

class RoomReady extends RoomStage {
  const RoomReady({
    super.players = const [],
    super.observerCount = 0,
  });

  @override String toString() => 'RoomReady';
}

class RoomUnready extends RoomStage {
  const RoomUnready({
    super.players = const [],
    super.observerCount = 0,
  });

  @override String toString() => 'RoomUnready';
}
/// 决斗开始。
///
class RoomStartDuel extends RoomStage {
  const RoomStartDuel({
    super.players = const [],
    super.observerCount = 0,
  });

  @override String toString() => 'RoomStartDuel';
}
/// 猜拳阶段 — 等待玩家选择剪刀/石头/布。
///
/// 触发条件：收到 [STOC_SELECT_HAND]。
class RoomSelectingHand extends RoomStage {
  const RoomSelectingHand({
    super.players = const [],
    super.observerCount = 0,
  });

  @override String toString() => 'RoomSelectingHand';
}
/// 猜拳结果阶段
///
class RoomHandResult extends RoomStage {
  /// 我方的猜拳结果 (1=SCISSORS, 2=ROCK, 3=PAPER)。
  final int myHand;
  /// 对方的猜拳结果。
  final int opponentHand;

  const RoomHandResult({
    super.players = const [],
    super.observerCount = 0,
    required this.myHand,
    required this.opponentHand,
  });

  @override String toString() => 'RoomHandResult(me:$myHand op:$opponentHand)';
}

/// 我方猜拳胜出 选先后攻阶段(选择先后手/行动顺序)。
///
/// 触发条件：收到 [STOC_SELECT_TP]，
/// [myHand] / [opponentHand] 来自上一轮的 [STOC_HAND_RESULT]。
class RoomSelectingTurn extends RoomStage {
  const RoomSelectingTurn({
    super.players = const [],
    super.observerCount = 0,
  });

  @override String toString() => 'RoomSelectingTurn';
}

/// 决斗准备完毕（先后攻已确定，等待正式开始）。
///
/// 触发条件：收到 [MSG_START]。
class RoomInDuel extends RoomStage {
  /// 是否先攻。
  final bool isFirstTurn;

  const RoomInDuel({
    super.players = const [],
    super.observerCount = 0,
    required this.isFirstTurn,
  });

  @override String toString() => 'RoomInDuel(first:$isFirstTurn)';
}

/// 决斗结束。
///
/// 触发条件：收到 [STOC_DUEL_END]。
class RoomDuelEnded extends RoomStage {
  const RoomDuelEnded({
    super.players = const [],
    super.observerCount = 0,
  });

  @override String toString() => 'RoomDuelEnded';
}

/// 换备阶段（三局两胜模式中局间换 Side Deck）。
///
/// 触发条件：收到 [STOC_CHANGE_SIDE]。
class RoomSideDecking extends RoomStage {
  const RoomSideDecking({
    super.players = const [],
    super.observerCount = 0,
  });

  @override String toString() => 'RoomSideDecking';
}

// ─── 辅助枚举 ───────────────────────────────────────────

/// 玩家在房间中的身份。
enum SelfType {
  unknown(-1),
  player1(0),
  player2(1),
  observer(7);
  final int slot;

  const SelfType(this.slot);

  static SelfType fromValue(int value) {
    switch (value) {
      case 0:
        return SelfType.player1;
      case 1:
        return SelfType.player2;
      case 7:
        return SelfType.observer;
      default:
        return SelfType.unknown;
    }
  }
}
