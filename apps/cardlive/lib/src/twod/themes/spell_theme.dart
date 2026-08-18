import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// spell 类别主题。
class SpellTheme {
  static const theme = SummonTheme(
    category: SummonCategory.spell,
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
