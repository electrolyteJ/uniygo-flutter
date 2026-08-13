import 'idle_action.dart';

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

  String get label {
    switch (type) {
      case 0:
        return '发动效果';
      case 1:
        return directAttack ? '直接攻击' : '攻击';
      default:
        return '行动 #$sequence';
    }
  }

  PlaymatResolvedActionKind get kind {
    switch (type) {
      case 0:
        return PlaymatResolvedActionKind.activate;
      case 1:
        return directAttack
            ? PlaymatResolvedActionKind.directAttack
            : PlaymatResolvedActionKind.attack;
      default:
        return PlaymatResolvedActionKind.unknown;
    }
  }
}
