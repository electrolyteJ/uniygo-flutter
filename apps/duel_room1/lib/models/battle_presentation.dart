
const _battlePresentationKeep = Object();

class BattlePresentation {
  final String attackerSlotId;
  final String? defenderSlotId;
  final String attackerName;
  final String? defenderName;
  final int? attackerAttack;
  final int? attackerDefense;
  final int? attackerPosition;
  final int? defenderAttack;
  final int? defenderDefense;
  final int? defenderPosition;

  const BattlePresentation({
    required this.attackerSlotId,
    required this.defenderSlotId,
    required this.attackerName,
    required this.defenderName,
    this.attackerAttack,
    this.attackerDefense,
    this.attackerPosition,
    this.defenderAttack,
    this.defenderDefense,
    this.defenderPosition,
  });

  bool get isDirectAttack => defenderSlotId == null;

  BattlePresentation copyWith({
    String? attackerSlotId,
    Object? defenderSlotId = _battlePresentationKeep,
    String? attackerName,
    Object? defenderName = _battlePresentationKeep,
    Object? attackerAttack = _battlePresentationKeep,
    Object? attackerDefense = _battlePresentationKeep,
    Object? attackerPosition = _battlePresentationKeep,
    Object? defenderAttack = _battlePresentationKeep,
    Object? defenderDefense = _battlePresentationKeep,
    Object? defenderPosition = _battlePresentationKeep,
  }) {
    return BattlePresentation(
      attackerSlotId: attackerSlotId ?? this.attackerSlotId,
      defenderSlotId: defenderSlotId == _battlePresentationKeep
          ? this.defenderSlotId
          : defenderSlotId as String?,
      attackerName: attackerName ?? this.attackerName,
      defenderName: defenderName == _battlePresentationKeep
          ? this.defenderName
          : defenderName as String?,
      attackerAttack: attackerAttack == _battlePresentationKeep
          ? this.attackerAttack
          : attackerAttack as int?,
      attackerDefense: attackerDefense == _battlePresentationKeep
          ? this.attackerDefense
          : attackerDefense as int?,
      attackerPosition: attackerPosition == _battlePresentationKeep
          ? this.attackerPosition
          : attackerPosition as int?,
      defenderAttack: defenderAttack == _battlePresentationKeep
          ? this.defenderAttack
          : defenderAttack as int?,
      defenderDefense: defenderDefense == _battlePresentationKeep
          ? this.defenderDefense
          : defenderDefense as int?,
      defenderPosition: defenderPosition == _battlePresentationKeep
          ? this.defenderPosition
          : defenderPosition as int?,
    );
  }
}