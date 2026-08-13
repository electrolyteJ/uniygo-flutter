class DrawAnimationEvent {
  final int id;
  final int player;
  final List<int> codes;
  final int turnCount;
  final bool revealCard;

  const DrawAnimationEvent({
    required this.id,
    required this.player,
    required this.codes,
    required this.turnCount,
    this.revealCard = false,
  });

  DrawAnimationEvent copyWith({
    int? id,
    int? player,
    List<int>? codes,
    int? turnCount,
    bool? revealCard,
  }) {
    return DrawAnimationEvent(
      id: id ?? this.id,
      player: player ?? this.player,
      codes: codes ?? this.codes,
      turnCount: turnCount ?? this.turnCount,
      revealCard: revealCard ?? this.revealCard,
    );
  }
}
