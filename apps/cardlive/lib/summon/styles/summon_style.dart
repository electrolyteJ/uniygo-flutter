import 'package:flutter/material.dart';

/// 召唤类型枚举
enum SummonType {
  normal,
  special,
  fusion,
  synchro,
  xyz,
  link,
  ritual,
  pendulum,
  spell,
  trap,
}

/// 光柱样式
enum LightStyle { column, radial, spiral, blackHole, lines, runes, shadow }

/// 召唤视觉样式配置
class SummonStyle {
  final SummonType type;
  final String label;

  // 主色调
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  // 光柱样式
  final LightStyle lightStyle;

  // 粒子配置
  final Color particleColor;
  final int particleCount;

  // 光环配置
  final double ringWidth;
  final List<Color> ringColors;

  const SummonStyle({
    required this.type,
    required this.label,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.lightStyle,
    this.particleColor = Colors.amber,
    this.particleCount = 60,
    this.ringWidth = 3.0,
    this.ringColors = const [Colors.amber],
  });

  /// 根据 CardInfo 的类型位掩码推导召唤类型
  static SummonType deduceType(int cardType, int attribute) {
    if ((cardType & 0x2) != 0) return SummonType.spell; // 魔法卡
    if ((cardType & 0x4) != 0) return SummonType.trap;   // 陷阱卡
    if ((cardType & 0x4000000) != 0) return SummonType.link;
    if ((cardType & 0x800000) != 0) return SummonType.xyz;
    if ((cardType & 0x2000) != 0) return SummonType.synchro;
    if ((cardType & 0x40) != 0) return SummonType.fusion;
    if ((cardType & 0x80) != 0) return SummonType.ritual;
    if ((cardType & 0x1000000) != 0) return SummonType.pendulum;
    // 通常怪兽
    if ((cardType & 0x10) != 0 && (cardType & 0x20) == 0) {
      return SummonType.normal;
    }
    // 效果怪兽/特殊召唤
    return SummonType.special;
  }
}
