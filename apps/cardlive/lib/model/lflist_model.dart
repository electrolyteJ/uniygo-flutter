class LflistCard {
  final int code;
  final int limit;
  final String reason;

  LflistCard({
    required this.code,
    required this.limit,
    this.reason = '',
  });

  factory LflistCard.fromLine(String line) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) {
      throw ArgumentError('Invalid lflist line: $line');
    }
    final parts = line.split(' ');
    final code = int.parse(parts[0]);
    final limit = parts.length > 1 ? int.parse(parts[1]) : 0;
    final reason = parts.length > 2 ? parts.sublist(2).join(' ') : '';
    return LflistCard(
      code: code,
      limit: limit,
      reason: reason,
    );
  }

  String get limitText {
    switch (limit) {
      case 0: return '禁止';
      case 1: return '限制';
      case 2: return '准限制';
      default: return '无限制';
    }
  }
}

class Lflist {
  final String name;
  final String date;
  final List<LflistCard> cards;

  Lflist({
    required this.name,
    required this.date,
    required this.cards,
  });

  int getCardLimit(int code) {
    final card = cards.firstWhere((c) => c.code == code, orElse: () => LflistCard(code: code, limit: 3));
    return card.limit;
  }

  String getCardLimitText(int code) {
    return cards.firstWhere((c) => c.code == code, orElse: () => LflistCard(code: code, limit: 3)).limitText;
  }
}