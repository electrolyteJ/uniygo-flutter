const _battlePresentationKeep = Object();

/// 攻击宣言/战斗数值呈现（波束 + 信息牌）：
/// 攻击方与防守方（直接攻击时为空）的卡槽与攻防面板数据。
class BattlePresentation {
  final String attackerZoneKey;
  final String? defenderZoneKey;
  final String attackerName;
  final String? defenderName;
  final int? attackerAttack;
  final int? attackerDefense;
  final int? attackerPosition;
  final int? defenderAttack;
  final int? defenderDefense;
  final int? defenderPosition;

  const BattlePresentation({
    required this.attackerZoneKey,
    required this.defenderZoneKey,
    required this.attackerName,
    required this.defenderName,
    this.attackerAttack,
    this.attackerDefense,
    this.attackerPosition,
    this.defenderAttack,
    this.defenderDefense,
    this.defenderPosition,
  });

  bool get isDirectAttack => defenderZoneKey == null;

  BattlePresentation copyWith({
    String? attackerZoneKey,
    Object? defenderZoneKey = _battlePresentationKeep,
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
      attackerZoneKey: attackerZoneKey ?? this.attackerZoneKey,
      defenderZoneKey: identical(defenderZoneKey, _battlePresentationKeep)
          ? this.defenderZoneKey
          : defenderZoneKey as String?,
      attackerName: attackerName ?? this.attackerName,
      defenderName: identical(defenderName, _battlePresentationKeep)
          ? this.defenderName
          : defenderName as String?,
      attackerAttack: identical(attackerAttack, _battlePresentationKeep)
          ? this.attackerAttack
          : attackerAttack as int?,
      attackerDefense: identical(attackerDefense, _battlePresentationKeep)
          ? this.attackerDefense
          : attackerDefense as int?,
      attackerPosition: identical(attackerPosition, _battlePresentationKeep)
          ? this.attackerPosition
          : attackerPosition as int?,
      defenderAttack: identical(defenderAttack, _battlePresentationKeep)
          ? this.defenderAttack
          : defenderAttack as int?,
      defenderDefense: identical(defenderDefense, _battlePresentationKeep)
          ? this.defenderDefense
          : defenderDefense as int?,
      defenderPosition: identical(defenderPosition, _battlePresentationKeep)
          ? this.defenderPosition
          : defenderPosition as int?,
    );
  }

  /// 值判等：biz 状态 copyWith 每次产出新实例，Flame 快照短路
  /// （FlameFieldSnapshot.==）依赖内容判等区分"战斗呈现是否真的变了"，
  /// 避免同内容新实例击穿短路导致全量槽位重建。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BattlePresentation &&
        other.attackerZoneKey == attackerZoneKey &&
        other.defenderZoneKey == defenderZoneKey &&
        other.attackerName == attackerName &&
        other.defenderName == defenderName &&
        other.attackerAttack == attackerAttack &&
        other.attackerDefense == attackerDefense &&
        other.attackerPosition == attackerPosition &&
        other.defenderAttack == defenderAttack &&
        other.defenderDefense == defenderDefense &&
        other.defenderPosition == defenderPosition;
  }

  @override
  int get hashCode => Object.hash(
    attackerZoneKey,
    defenderZoneKey,
    attackerName,
    defenderName,
    attackerAttack,
    attackerDefense,
    attackerPosition,
    defenderAttack,
    defenderDefense,
    defenderPosition,
  );
}
