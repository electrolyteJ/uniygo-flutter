import 'package:flutter/material.dart';
import 'summon_style.dart';

/// XYZ 召唤风格 —— 紫黑黑洞门 + 叠放素材飞入
class XyzStyle {
  static const style = SummonStyle(
    type: SummonType.xyz,
    label: 'XYZ召唤',
    primaryColor: Color(0xFF4A148C),   // 深紫黑
    secondaryColor: Color(0xFF8E24AA), // 亮紫
    accentColor: Color(0xFF212121),    // 黑
    lightStyle: LightStyle.blackHole,
    particleColor: Color(0xFF8E24AA),
    particleCount: 75,
    ringWidth: 3.5,
    ringColors: [Color(0xFF4A148C), Color(0xFF212121)],
  );
}
