import 'package:flutter/material.dart';
import 'summon_style.dart';

/// 陷阱卡发动风格 —— 紫暗阴影 + 锁链效果
class TrapStyle {
  static const style = SummonStyle(
    type: SummonType.trap,
    label: '陷阱卡发动',
    primaryColor: Color(0xFF7B1FA2),   // 暗紫
    secondaryColor: Color(0xFF37474F), // 深灰
    accentColor: Color(0xFF4A148C),    // 更深紫
    lightStyle: LightStyle.shadow,
    particleColor: Color(0xFF9C27B0),
    particleCount: 55,
    ringWidth: 3.5,
    ringColors: [Color(0xFF7B1FA2), Color(0xFF37474F)],
  );
}
