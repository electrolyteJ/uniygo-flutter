class DuelResultSummary {
  final bool didWin;
  final int winPlayer;
  final int reason;
  final String selfName;
  final String opponentName;
  final int selfLp;
  final int opponentLp;

  const DuelResultSummary({
    required this.didWin,
    required this.winPlayer,
    required this.reason,
    required this.selfName,
    required this.opponentName,
    required this.selfLp,
    required this.opponentLp,
  });
}