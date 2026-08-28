/// 卡片移动事件（MSG_MOVE 的表现层信号）。
///
/// 与 SummonEffectEvent / DrawAnimationEvent 同构：applyMove 时生成，
/// id 单调递增（cardMoveTick），表现层按 id diff 驱动飞牌动画。
///
/// 隐私纪律：任何涉及对方手牌（from 或 to 是对方 HAND）的移动，
/// [code] 恒为 0（渲染卡背），与 isOpponentDeckToHand 的 0 占位一致。
library;

class CardMoveEvent {
  const CardMoveEvent({
    required this.id,
    required this.code,
    required this.fromController,
    required this.fromLocation,
    required this.fromSequence,
    required this.toController,
    required this.toLocation,
    required this.toSequence,
  });

  /// 单调递增事件序号（与 state.cardMoveTick 同步）。
  final int id;

  /// 卡码；涉及对方手牌或不可知时为 0（表现层渲染卡背）。
  final int code;

  final int fromController;
  final int fromLocation;
  final int fromSequence;
  final int toController;
  final int toLocation;
  final int toSequence;
}
