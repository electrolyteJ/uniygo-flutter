class DeckEditorRouteArgs {
  const DeckEditorRouteArgs({
    this.initialDeckName,
    this.validationContext,
    this.lockDeckSelection = false,
    this.lockDeckName = false,
  });

  final String? initialDeckName;
  final DeckValidationContext? validationContext;
  final bool lockDeckSelection;
  final bool lockDeckName;

  bool get isWaitingRoomSession => validationContext != null;
}

class DeckValidationContext {
  const DeckValidationContext({
    required this.noCheckDeck,
    required this.lfTableHash,
  });

  final bool noCheckDeck;
  final int lfTableHash;
}

class DeckEditorSaveResult {
  const DeckEditorSaveResult({required this.saved, this.validationErrors});

  final bool saved;
  final List<String>? validationErrors;

  bool get isCompliant => validationErrors?.isEmpty ?? true;
}
