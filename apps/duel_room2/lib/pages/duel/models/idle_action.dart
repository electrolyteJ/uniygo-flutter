enum PlaymatResolvedActionKind {
  summon,
  specialSummon,
  positionChange,
  monsterSet,
  spellSet,
  activate,
  attack,
  directAttack,
  toBattlePhase,
  toMainPhase2,
  toEndPhase,
  unknown,
}

class IdleAction {
  final int type;
  final int sequence;
  final int code;
  final int controller;
  final int location;
  final int locationSequence;
  final int position;

  const IdleAction({
    required this.type,
    required this.sequence,
    required this.code,
    required this.controller,
    required this.location,
    this.locationSequence = 0,
    required this.position,
  });

  String label(int myController) {
    switch (type) {
      case 0:
        return '召唤';
      case 1:
        return controller == myController ? '特殊召唤（己方）' : '特殊召唤（对方）';
      case 2:
        return '改变表示形式';
      case 3:
      case 4:
        return '盖放';
      case 5:
        return '发动效果';
      default:
        return '行动 #$sequence';
    }
  }

  PlaymatResolvedActionKind get kind {
    switch (type) {
      case 0:
        return PlaymatResolvedActionKind.summon;
      case 1:
        return PlaymatResolvedActionKind.specialSummon;
      case 2:
        return PlaymatResolvedActionKind.positionChange;
      case 3:
        return PlaymatResolvedActionKind.monsterSet;
      case 4:
        return PlaymatResolvedActionKind.spellSet;
      case 5:
        return PlaymatResolvedActionKind.activate;
      default:
        return PlaymatResolvedActionKind.unknown;
    }
  }
}
