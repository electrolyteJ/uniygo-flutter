import 'package:flutter/material.dart';

import '../../category.dart';
import 'summon_theme.dart';

/// synchro 类别主题。
class SynchroTheme {
  static const theme = SummonTheme(
    category: SummonCategory.synchro,
    primaryColor: Color(0xFF00E676),   // 翠绿
    secondaryColor: Color(0xFF69F0AE), // 浅绿
    accentColor: Color(0xFF00C853),    // 深绿
    lightStyle: LightStyle.radial,
    particleColor: Color(0xFF00E676),
    particleCount: 90,
    ringWidth: 3.0,
    ringColors: [Color(0xFF00E676), Color(0xFF00C853)],
    fieldPrimary: Color(0xFFDFFFE8),
    fieldSecondary: Color(0xFF7FE8A8),
  );
}
