import 'package:flutter/material.dart';
import 'summon_style.dart';

/// 同调召唤风格 —— 翠绿光环 + 粒子流穿越
class SynchroStyle {
  static const style = SummonStyle(
    type: SummonType.synchro,
    label: '同调召唤',
    primaryColor: Color(0xFF00E676),   // 翠绿
    secondaryColor: Color(0xFF69F0AE), // 浅绿
    accentColor: Color(0xFF00C853),    // 深绿
    lightStyle: LightStyle.radial,
    particleColor: Color(0xFF00E676),
    particleCount: 90,
    ringWidth: 3.0,
    ringColors: [Color(0xFF00E676), Color(0xFF00C853)],
  );
}
