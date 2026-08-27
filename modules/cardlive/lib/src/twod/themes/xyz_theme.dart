import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// xyz 类别主题。
class XyzTheme {
  static const theme = SummonTheme(
    category: SummonCategory.xyz,
    primaryColor: Color(0xFF4A148C),   // 深紫黑
    secondaryColor: Color(0xFF8E24AA), // 亮紫
    accentColor: Color(0xFF212121),    // 黑
    lightStyle: LightStyle.blackHole,
    particleColor: Color(0xFF8E24AA),
    particleCount: 75,
    ringWidth: 3.5,
    ringColors: [Color(0xFF4A148C), Color(0xFF212121)],
    fieldPrimary: Color(0xFFFFD700),
    fieldSecondary: Color(0xFF4A4A55),
  );
}
