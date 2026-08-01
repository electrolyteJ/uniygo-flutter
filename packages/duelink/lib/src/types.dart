/// 游戏王协议枚举和常量定义。
///
/// 这些枚举用于把 ygopro 协议里的原始数字字段转换成更易读的语义值。
/// 对上层消费方来说，通常优先使用各消息/结构体上暴露的 enum getter；
/// 只有在需要保留原始协议值、做位运算、或兼容尚未建模的新取值时，
/// 才直接读取对应的 raw/number 字段。
///
/// 参考 neos-ts 的 ocgcore.ts IDL 定义。

/// 猜拳类型枚举。
///
/// 用于 CtoS/StoC 猜拳交互协议。消费方一般应优先使用该枚举，
/// 而不是在业务层直接判断 `1/2/3` 这类魔法数字。
enum HandType {
  unknown(0),
  scissors(1),
  rock(2),
  paper(3);

  final int value;

  const HandType(this.value);

  /// 将协议中的原始数字值映射到语义化枚举。
  ///
  /// 未识别的值会回退为 [HandType.unknown]，这样上层仍可安全显示或记录。
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

/// 卡牌区域枚举，与 ygopro 核心的 CardZone 值一一对应。
///
/// 大多数场景应优先消费 `zone` / `zoneEnum` / `zoneValue` 这类 getter，
/// 因为它们更适合 UI 与业务逻辑判断；如果调用方需要保留原始字节语义、
/// 做位掩码计算、或处理暂未覆盖的新区域值，再读取 `rawZone` / `zoneCode`。
///
/// 部分值支持位组合（如 onfield = mzone | szone）。
enum CardZone {
  deck(0x01),
  hand(0x02),
  mzone(0x04),
  szone(0x08),
  grave(0x10),
  removed(0x20),
  extra(0x40),
  /// 场上（MZONE | SZONE）
  onfield(0x0c),
  fzone(0x100),
  pzone(0x200),
  tzone(0x300);

  final int value;

  const CardZone(this.value);

  /// 将 ygopro 协议中的数字区域值转换为 [CardZone] 枚举。
  ///
  /// 该方法面向已知协议值；如果上层必须区分未知值，请同时保留原始数字字段。
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

/// 卡牌表示形式枚举，与 ygopro 的 position 位值一致。
///
/// 建议优先使用消息/结构体上的 `positionEnum` / `cardPosition`，
/// 只有在需要原始位值或兼容未知取值时再读取 `rawPosition` / `positionCode`。
enum CardPosition {
  unknown(0),
  faceupAttack(0x1),
  facedownAttack(0x2),
  attack(0x3),
  faceupDefense(0x4),
  faceup(0x5),
  facedownDefense(0x8),
  facedown(0xA),
  defense(0xC);

  final int value;

  const CardPosition(this.value);

  /// 将协议中的原始 position 位值转换为 [CardPosition] 枚举。
  ///
  /// 未识别的值会回退为 [CardPosition.unknown]，避免上层直接依赖数字常量。
  static CardPosition fromNumber(int n) {
    switch (n) {
      case 0x1:
        return CardPosition.faceupAttack;
      case 0x2:
        return CardPosition.facedownAttack;
      case 0x3:
        return CardPosition.attack;
      case 0x4:
        return CardPosition.faceupDefense;
      case 0x5:
        return CardPosition.faceup;
      case 0x8:
        return CardPosition.facedownDefense;
      case 0xA:
        return CardPosition.facedown;
      case 0xC:
        return CardPosition.defense;
      default:
        return CardPosition.unknown;
    }
  }
}
