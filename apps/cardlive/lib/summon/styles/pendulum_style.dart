import 'package:flutter/material.dart';
import 'summon_style.dart';

/// 灵摆召唤风格 —— 双色光柱（左蓝右红）+ 钟摆弧线
class PendulumStyle {
  static const style = SummonStyle(
    type: SummonType.pendulum,
    label: '灵摆召唤',
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
