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
  static HandType of(int value) {
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
