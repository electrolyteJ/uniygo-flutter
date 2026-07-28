import 'package:flutter/material.dart';
import 'summon_style.dart';

/// 魔法卡发动风格 —— 蓝光符文圆阵扩散
class SpellStyle {
  static const style = SummonStyle(
    type: SummonType.spell,
    label: '魔法卡发动',
    primaryColor: Color(0xFF1DE9B6),   // 青
    secondaryColor: Color(0xFF64FFDA), // 亮青
    accentColor: Color(0xFF00BFA5),    // 深青
    lightStyle: LightStyle.runes,
    particleColor: Color(0xFF64FFDA),
    particleCount: 50,
    ringWidth: 3.0,
    ringColors: [Color(0xFF1DE9B6), Color(0xFF00BFA5)],
  );
}
