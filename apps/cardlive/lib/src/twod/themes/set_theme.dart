import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// set 类别主题。
class SetTheme {
  static const theme = SummonTheme(
    category: SummonCategory.set,
    primaryColor: Color(0xFF8A8F9A),   // 暗灰
    secondaryColor: Color(0xFF5A5E66), // 深灰
    accentColor: Color(0xFF3C4048),    // 更暗
    lightStyle: LightStyle.shadow,
    particleColor: Color(0xFF8A8F9A),
    particleCount: 40,
    ringWidth: 2.5,
    ringColors: [Color(0xFF8A8F9A), Color(0xFF5A5E66)],
    fieldPrimary: Color(0xFF8A8F9A),
    fieldSecondary: Color(0xFF5A5E66),
    revealCard: false,
  );
}
