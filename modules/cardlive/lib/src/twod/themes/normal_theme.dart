import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// normal 类别主题。
class NormalTheme {
  static const theme = SummonTheme(
    category: SummonCategory.normal,
    primaryColor: Color(0xFFFFD700),   // 金色
    secondaryColor: Color(0xFFFFF8DC), // 偏白金色
    accentColor: Color(0xFFDAA520),    // 琥珀金
    lightStyle: LightStyle.column,
    particleColor: Color(0xFFFFD700),
    particleCount: 60,
    ringWidth: 3.0,
    ringColors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    fieldPrimary: Color(0xFFFFD97A),
    fieldSecondary: Color(0xFFFFF3D0),
  );
}
