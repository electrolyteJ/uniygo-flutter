import 'package:duelink/duelink.dart';

/// 阶段名文案（duel_room3 不做 l10n，直接用 duelink 的中文描述）。
String getDuelPhaseText(DuelPhase phase) {
  final desc = phase.desc;
  return desc.isEmpty ? phase.name.toUpperCase() : desc;
}

/// 对局内的背景音乐资源名（`assets/sounds/bgm/`）。
///
/// 两段的分工是**按叙事阶段**切的，不是按页面切的：
///
/// - [fieldAmbient]：加载页的氛围底乐。低沉持续音 + 极慢呼吸起伏，
///   循环播放，作用是「把等待填满」——预先载入 3D 场地那 2.7 秒在没有
///   声音的情况下会显得过长。
/// - [duelEnter]：从加载页切入场地页的入场曲。上升音簇 + 三次打击，
///   约 4.2 秒，**不循环**：它是一段过场，播完即止，之后交给对局音效。
///   若这里继续循环，玩家会在整个对局期间听着同一段冲击音，压迫感过载。
///
/// 替换素材时保持文件名不变即可，无需改代码。
class DuelBgm {
  const DuelBgm._();

  /// 加载页氛围曲（循环）。
  static const fieldAmbient = 'field_ambient.wav';

  /// 入场曲（单次播放）。
  static const duelEnter = 'duel_enter.wav';
}
