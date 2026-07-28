import 'package:flutter/material.dart';
import 'summon_style.dart';

/// 通常召唤风格 —— 金色光柱 + 光圈实体化
class NormalStyle {
  static const style = SummonStyle(
    type: SummonType.normal,
    label: '通常召唤',
    primaryColor: Color(0xFFFFD700),   // 金色
    secondaryColor: Color(0xFFFFF8DC), // 偏白金色
    accentColor: Color(0xFFDAA520),    // 琥珀金
    lightStyle: LightStyle.column,
    particleColor: Color(0xFFFFD700),
    particleCount: 60,
    ringWidth: 3.0,
    ringColors: [Color(0xFFFFD700), Color(0xFFFFA500)],
  );
}
