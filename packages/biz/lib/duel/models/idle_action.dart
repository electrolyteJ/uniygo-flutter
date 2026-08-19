import 'playmat_resolved_action.dart';

/// 主阶段可执行动作（MSG_SELECT_IDLECMD 的一项）：
/// 召唤/特召/改表示/盖放/发动，[type] 为引擎指令序号。
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

  String label(int myController) => switch (type) {
    0 => '召唤',
    1 => controller == myController ? '特殊召唤（己方）' : '特殊召唤（对方）',
    2 => '改变表示形式',
    3 || 4 => '盖放',
    5 => '发动效果',
    _ => '行动 #$sequence',
  };

  PlaymatResolvedActionKind get kind => switch (type) {
    0 => PlaymatResolvedActionKind.summon,
    1 => PlaymatResolvedActionKind.specialSummon,
    2 => PlaymatResolvedActionKind.positionChange,
    3 => PlaymatResolvedActionKind.monsterSet,
    4 => PlaymatResolvedActionKind.spellSet,
    5 => PlaymatResolvedActionKind.activate,
    _ => PlaymatResolvedActionKind.unknown,
  };
}
