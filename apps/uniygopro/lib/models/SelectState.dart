class SelectState {
  final SelectType type;
  final int player;
  final List<SelectOption> options;
  final int min;
  final int max;
  final bool cancelable;
  final int? effectDescription;

  const SelectState({
    required this.type,
    required this.player,
    this.options = const [],
    this.min = 1,
    this.max = 1,
    this.cancelable = false,
    this.effectDescription,
  });
}

class SelectOption {
  final int code;
  final int controller;
  final int zone;
  final int sequence;
  final int? level;
  final int? position;
  final String? label;

  const SelectOption({
    required this.code,
    this.controller = 0,
    this.zone = 0,
    this.sequence = 0,
    this.level,
    this.position,
    this.label,
  });
}

enum SelectType {
  idleCmd,
  card,
  chain,
  option,
  position,
  effectYn,
  yesNo,
  battleCmd,
  place,
  tribute,
  sum,
  counter,
  sort,
}
