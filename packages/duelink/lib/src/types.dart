

/// 游戏王协议枚举和常量。
enum HandType {
  unknown(0),
  scissors(1),
  rock(2),
  paper(3);

  final int value;

  const HandType(this.value);

  static HandType fromValue(int value) {
    switch (value) {
      case 1:
        return HandType.scissors;
      case 2:
        return HandType.rock;
      case 3:
        return HandType.paper;
      default:
        return HandType.unknown;
    }
  }
}

enum CardZone {
  deck(0x01),
  hand(0x02),
  mzone(0x04),
  szone(0x08),
  grave(0x10),
  removed(0x20),
  extra(0x40),
  onfield(0x0c),
  fzone(0x100),
  pzone(0x200),
  tzone(0x300);

  final int value;

  const CardZone(this.value);

  static CardZone fromNumber(int n) {
    switch (n) {
      case 0x01:
        return CardZone.deck;
      case 0x02:
        return CardZone.hand;
      case 0x04:
        return CardZone.mzone;
      case 0x08:
        return CardZone.szone;
      case 0x10:
        return CardZone.grave;
      case 0x20:
        return CardZone.removed;
      case 0x40:
        return CardZone.extra;
      case 0x0c:
        return CardZone.onfield;
      case 0x100:
        return CardZone.fzone;
      case 0x200:
        return CardZone.pzone;
      case 0x300:
        return CardZone.tzone;
      default:
        return CardZone.deck;
    }
  }
}

