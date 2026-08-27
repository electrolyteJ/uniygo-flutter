import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// trap 类别主题。
class TrapTheme {
  static const theme = SummonTheme(
    category: SummonCategory.trap,
    primaryColor: Color(0xFF7B1FA2),   // 暗紫
    secondaryColor: Color(0xFF37474F), // 深灰
    accentColor: Color(0xFF4A148C),    // 更深紫
    lightStyle: LightStyle.shadow,
    particleColor: Color(0xFF9C27B0),
    particleCount: 55,
    ringWidth: 3.5,
    ringColors: [Color(0xFF7B1FA2), Color(0xFF37474F)],
  );
}
