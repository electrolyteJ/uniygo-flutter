class BattleAction {
  final int type;
  final int sequence;
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
}
