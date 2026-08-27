import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// ritual 类别主题。
class RitualTheme {
  static const theme = SummonTheme(
    category: SummonCategory.ritual,
    primaryColor: Color(0xFF42A5F5),   // 天蓝
    secondaryColor: Color(0xFFFFFFFF), // 白
    accentColor: Color(0xFF1E88E5),    // 深蓝
    lightStyle: LightStyle.runes,
    particleColor: Color(0xFF90CAF9),
    particleCount: 65,
    ringWidth: 3.0,
    ringColors: [Color(0xFF42A5F5), Color(0xFFFFFFFF)],
    fieldPrimary: Color(0xFF3D6BFF),
    fieldSecondary: Color(0xFF9FB8FF),
  );
}
