import 'package:biz/duel/models/summon_effect_event.dart';
import 'package:flutter/material.dart';

/// 召唤特效的配色与行为配置（按召唤类型分色）。
class SummonEffectStyle {
  const SummonEffectStyle({
    required this.primary,
    required this.secondary,
    required this.revealCard,
  });

  /// 召唤阵双环 / 中线 / 光柱主色。
  final Color primary;

  /// 粒子与闪光辅色。
  final Color secondary;

  /// 是否升起卡图（盖放为 false：只播尘雾与暗环）。
  final bool revealCard;
}

/// 各召唤类型的默认样式。
const Map<SummonEffectType, SummonEffectStyle> kSummonEffectStyles = {
  // 通常召唤：金白
  SummonEffectType.normal: SummonEffectStyle(
    primary: Color(0xFFFFD97A),
    secondary: Color(0xFFFFF3D0),
    revealCard: true,
  ),
  // 特殊召唤：蓝紫
  SummonEffectType.special: SummonEffectStyle(
    primary: Color(0xFF7A9FFF),
    secondary: Color(0xFFC9D6FF),
    revealCard: true,
  ),
  // 反转召唤：青绿
  SummonEffectType.flip: SummonEffectStyle(
    primary: Color(0xFF5FE3C0),
    secondary: Color(0xFFCFFFEE),
    revealCard: true,
  ),
  // 盖放：暗灰（不升卡图）
  SummonEffectType.set: SummonEffectStyle(
    primary: Color(0xFF8A8F9A),
    secondary: Color(0xFF5A5E66),
    revealCard: false,
  ),
  // 仪式召唤：深蓝
  SummonEffectType.ritual: SummonEffectStyle(
    primary: Color(0xFF3D6BFF),
    secondary: Color(0xFF9FB8FF),
    revealCard: true,
  ),
  // 融合召唤：紫
  SummonEffectType.fusion: SummonEffectStyle(
    primary: Color(0xFFB45FFF),
    secondary: Color(0xFFE3C6FF),
    revealCard: true,
  ),
  // 同调召唤：白绿
  SummonEffectType.synchro: SummonEffectStyle(
    primary: Color(0xFFDFFFE8),
    secondary: Color(0xFF7FE8A8),
    revealCard: true,
  ),
  // 超量召唤：黑金
  SummonEffectType.xyz: SummonEffectStyle(
    primary: Color(0xFFFFD700),
    secondary: Color(0xFF4A4A55),
    revealCard: true,
  ),
  // 连接召唤：青蓝
  SummonEffectType.link: SummonEffectStyle(
    primary: Color(0xFF35D8FF),
    secondary: Color(0xFFBDF3FF),
    revealCard: true,
  ),
};
