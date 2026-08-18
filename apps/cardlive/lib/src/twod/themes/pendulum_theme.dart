import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// pendulum 类别主题。
class PendulumTheme {
  static const theme = SummonTheme(
    category: SummonCategory.pendulum,
    primaryColor: Color(0xFF42A5F5),   // 蓝
    secondaryColor: Color(0xFFEF5350), // 红
    accentColor: Color(0xFF7E57C2),    // 紫色调和
    lightStyle: LightStyle.column,
    particleColor: Color(0xFF7E57C2),
    particleCount: 85,
    ringWidth: 2.5,
    ringColors: [Color(0xFF42A5F5), Color(0xFFEF5350)],
  );
}
