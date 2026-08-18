import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// link 类别主题。
class LinkTheme {
  static const theme = SummonTheme(
    category: SummonCategory.link,
    primaryColor: Color(0xFF00B0FF),   // 电蓝
    secondaryColor: Color(0xFF40C4FF), // 亮蓝
    accentColor: Color(0xFF0091EA),    // 深蓝
    lightStyle: LightStyle.lines,
    particleColor: Color(0xFF00B0FF),
    particleCount: 100,
    ringWidth: 2.0,
    ringColors: [Color(0xFF00B0FF), Color(0xFF18FFFF)],
    fieldPrimary: Color(0xFF35D8FF),
    fieldSecondary: Color(0xFFBDF3FF),
  );
}
