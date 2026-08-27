import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// flip 类别主题。
class FlipTheme {
  static const theme = SummonTheme(
    category: SummonCategory.flip,
    primaryColor: Color(0xFF5FE3C0),   // 青绿
    secondaryColor: Color(0xFFCFFFEE), // 浅青绿
    accentColor: Color(0xFF26A69A),    // 深青绿
    lightStyle: LightStyle.radial,
    particleColor: Color(0xFF5FE3C0),
    particleCount: 60,
    ringWidth: 2.5,
    ringColors: [Color(0xFF5FE3C0), Color(0xFF26A69A)],
    fieldPrimary: Color(0xFF5FE3C0),
    fieldSecondary: Color(0xFFCFFFEE),
  );
}
