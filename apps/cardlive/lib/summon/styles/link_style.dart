import 'package:flutter/material.dart';
import 'summon_style.dart';

/// 链接召唤风格 —— 电蓝数据网格 + 电路线框
class LinkStyle {
  static const style = SummonStyle(
    type: SummonType.link,
    label: '链接召唤',
    primaryColor: Color(0xFF00B0FF),   // 电蓝
    secondaryColor: Color(0xFF40C4FF), // 亮蓝
    accentColor: Color(0xFF0091EA),    // 深蓝
    lightStyle: LightStyle.lines,
    particleColor: Color(0xFF00B0FF),
    particleCount: 100,
    ringWidth: 2.0,
    ringColors: [Color(0xFF00B0FF), Color(0xFF18FFFF)],
  );
}
