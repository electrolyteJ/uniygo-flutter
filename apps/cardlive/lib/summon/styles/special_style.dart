import 'package:flutter/material.dart';
import 'summon_style.dart';

/// 特殊召唤风格 —— 蓝色光柱 + 环状扩散
class SpecialStyle {
  static const style = SummonStyle(
    type: SummonType.special,
    label: '特殊召唤',
    primaryColor: Color(0xFF448AFF),   // 亮蓝
    secondaryColor: Color(0xFF82B1FF), // 浅蓝
    accentColor: Color(0xFF2962FF),    // 深蓝
    lightStyle: LightStyle.radial,
    particleColor: Color(0xFF448AFF),
    particleCount: 70,
    ringWidth: 2.5,
    ringColors: [Color(0xFF448AFF), Color(0xFF2962FF)],
  );
}
