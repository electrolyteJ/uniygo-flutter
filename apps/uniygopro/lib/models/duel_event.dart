sealed class DuelEvent {
  const DuelEvent();
}

sealed class DuelFlowEvent extends DuelEvent {
  const DuelFlowEvent();
}

sealed class DuelBoardEvent extends DuelEvent {
  const DuelBoardEvent();
}

sealed class DuelSelectionEvent extends DuelEvent {
  const DuelSelectionEvent();
}

class DuelIgnoredEvent extends DuelEvent {
  final String reason;

  const DuelIgnoredEvent(this.reason);
}

class DuelFlowMessageEvent extends DuelFlowEvent {
  final int func;
  final Object innerMsg;

  const DuelFlowMessageEvent({required this.func, required this.innerMsg});
}

class DuelBoardMessageEvent extends DuelBoardEvent {
  final int func;
  final Object innerMsg;

  const DuelBoardMessageEvent({required this.func, required this.innerMsg});
}

class DuelSelectionMessageEvent extends DuelSelectionEvent {
  final int func;
  final Object innerMsg;

  const DuelSelectionMessageEvent({required this.func, required this.innerMsg});
}
