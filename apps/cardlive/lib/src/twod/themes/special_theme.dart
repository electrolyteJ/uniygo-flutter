import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// special 类别主题。
class SpecialTheme {
  static const theme = SummonTheme(
    category: SummonCategory.special,
    primaryColor: Color(0xFF448AFF),   // 亮蓝
    secondaryColor: Color(0xFF82B1FF), // 浅蓝
    accentColor: Color(0xFF2962FF),    // 深蓝
    lightStyle: LightStyle.radial,
    particleColor: Color(0xFF448AFF),
    particleCount: 70,
    ringWidth: 2.5,
    ringColors: [Color(0xFF448AFF), Color(0xFF2962FF)],
    fieldPrimary: Color(0xFF7A9FFF),
    fieldSecondary: Color(0xFFC9D6FF),
  );
}
