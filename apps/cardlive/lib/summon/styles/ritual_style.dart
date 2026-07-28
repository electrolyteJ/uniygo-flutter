import 'package:flutter/material.dart';
import 'summon_style.dart';

/// 仪式召唤风格 —— 蓝白圣光 + 祭坛符文阵
class RitualStyle {
  static const style = SummonStyle(
    type: SummonType.ritual,
    label: '仪式召唤',
    primaryColor: Color(0xFF42A5F5),   // 天蓝
    secondaryColor: Color(0xFFFFFFFF), // 白
    accentColor: Color(0xFF1E88E5),    // 深蓝
    lightStyle: LightStyle.runes,
    particleColor: Color(0xFF90CAF9),
    particleCount: 65,
    ringWidth: 3.0,
    ringColors: [Color(0xFF42A5F5), Color(0xFFFFFFFF)],
  );
}
