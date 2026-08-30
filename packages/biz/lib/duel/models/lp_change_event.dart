/// 一次 LP 变动事件（伤害/回复/支付/直接变值）。
///
/// DuelFieldState 以 `lpChangeTick + lpChangeEvent` 形式承载（与
/// cardMoveEvent 同构：同帧多条只保留最新一条），表现层按 tick diff
/// 消费，驱动受影响玩家状态卡旁的锚定 toast。
library;

enum LpChangeKind {
  /// MSG_DAMAGE：效果/战斗伤害。
  damage,

  /// MSG_RECOVER：回复。
  recover,

  /// MSG_PAY_LP_COST：支付生命值代价。
  pay,

  /// MSG_LP_UPDATE：直接变为新值（delta 为新旧差值）。
  set,
}

class LpChangeEvent {
  /// 引擎玩家编号（0/1）。
  final int player;

  /// 带符号变动值（伤害/支付为负，回复为正；set 为新旧差值）。
  final int delta;

  final LpChangeKind kind;

  const LpChangeEvent({
    required this.player,
    required this.delta,
    required this.kind,
  });

  @override
  String toString() =>
      'LpChangeEvent(player:$player delta:$delta kind:$kind)';
}
