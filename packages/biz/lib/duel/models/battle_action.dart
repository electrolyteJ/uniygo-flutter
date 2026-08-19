import 'playmat_resolved_action.dart';

/// 战斗阶段可执行动作（MSG_SELECT_BATTLE_CMD 的一项）：
/// 发动效果或（直接）攻击，[type] 为引擎指令序号。
class BattleAction {
  final int type;
  final int sequence;
  final int code;
  final int attackerController;
  final int attackerLocation;
  final int attackerSequence;
  final int attackerPosition;
  final bool directAttack;
  final int targetController;
  final int targetLocation;
  final int targetSequence;
  final int targetPosition;

  const BattleAction({
    required this.type,
    required this.sequence,
    this.code = 0,
    required this.attackerController,
    required this.attackerLocation,
    required this.attackerSequence,
    required this.attackerPosition,
    required this.directAttack,
    this.targetController = 0,
    this.targetLocation = 0,
    this.targetSequence = 0,
    this.targetPosition = 0,
  });

  String get label => switch (type) {
    0 => '发动效果',
    1 => directAttack ? '直接攻击' : '攻击',
    _ => '行动 #$sequence',
  };

  PlaymatResolvedActionKind get kind => switch (type) {
    0 => PlaymatResolvedActionKind.activate,
    1 =>
      directAttack
          ? PlaymatResolvedActionKind.directAttack
          : PlaymatResolvedActionKind.attack,
    _ => PlaymatResolvedActionKind.unknown,
  };
}
