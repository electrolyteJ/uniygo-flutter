/// 主阶段空闲指令（MSG_SELECT_IDLECMD）经菜单解析后的动作模型：
/// [PlaymatResolvedAction] 为展示项，[PlaymatResolvedActionKind] 为
/// 语义类别（供菜单/演出按类分色与图标）。
library;

/// 主阶段菜单的已解析动作项（标签 + 引擎应答值 + 语义类别）。
class PlaymatResolvedAction {
  final String label;
  final int response;
  final PlaymatResolvedActionKind kind;
  final int? code;
  final int? controller;
  final int? location;
  final int? sequence;

  const PlaymatResolvedAction({
    required this.label,
    required this.response,
    this.kind = PlaymatResolvedActionKind.unknown,
    this.code,
    this.controller,
    this.location,
    this.sequence,
  });
}

/// 已解析动作的语义类别（供菜单/演出按类分色与图标）。
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
