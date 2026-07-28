import 'package:flutter/material.dart';
import 'summon_style.dart';

/// 融合召唤风格 —— 紫色螺旋漩涡 + 双卡融合
class FusionStyle {
  static const style = SummonStyle(
    type: SummonType.fusion,
    label: '融合召唤',
    primaryColor: Color(0xFF9C27B0),   // 紫色
    secondaryColor: Color(0xFFCE93D8), // 浅紫
    accentColor: Color(0xFF7B1FA2),    // 深紫
    lightStyle: LightStyle.spiral,
    particleColor: Color(0xFF9C27B0),
    particleCount: 80,
    ringWidth: 3.0,
    ringColors: [Color(0xFF9C27B0), Color(0xFFE040FB)],
  );
}
