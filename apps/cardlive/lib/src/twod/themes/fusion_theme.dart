import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// fusion 类别主题。
class FusionTheme {
  static const theme = SummonTheme(
    category: SummonCategory.fusion,
    primaryColor: Color(0xFF9C27B0),   // 紫色
    secondaryColor: Color(0xFFCE93D8), // 浅紫
    accentColor: Color(0xFF7B1FA2),    // 深紫
    lightStyle: LightStyle.spiral,
    particleColor: Color(0xFF9C27B0),
    particleCount: 80,
    ringWidth: 3.0,
    ringColors: [Color(0xFF9C27B0), Color(0xFFE040FB)],
    fieldPrimary: Color(0xFFB45FFF),
    fieldSecondary: Color(0xFFE3C6FF),
  );
}
