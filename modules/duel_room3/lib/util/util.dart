int rpsOutcome(int mine, int other) {
  if (mine == other) return 0;
  final win =
      (mine == 1 && other == 3) ||
      (mine == 2 && other == 1) ||
      (mine == 3 && other == 2);
  return win ? 1 : -1;
}
