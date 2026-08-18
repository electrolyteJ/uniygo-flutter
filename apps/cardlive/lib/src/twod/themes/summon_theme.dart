import 'package:flutter/material.dart';

import '../../category.dart';

/// 光柱样式
enum LightStyle { column, radial, spiral, blackHole, lines, runes, shadow }

/// 召唤视觉主题 —— 每个类别一套统一视觉身份。
///
/// 双色板：
/// - 鉴赏色板（primary/secondary/accent + 光柱/粒子/光环参数）：
///   全屏鉴赏与卡组编辑器动效使用；
/// - 场地色板（fieldPrimary/fieldSecondary）：决斗场地内小特效使用，
///   未提供时回落鉴赏色板。
class SummonTheme {
  final SummonCategory category;

  // ── 鉴赏色板 ──
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  /// 光柱样式
  final LightStyle lightStyle;

  // ── 粒子配置 ──
  final Color particleColor;
  final int particleCount;

  // ── 光环配置 ──
  final double ringWidth;
  final List<Color> ringColors;

  // ── 场地色板（决斗内小特效）──
  final Color? _fieldPrimary;
  final Color? _fieldSecondary;

  /// 是否升起卡图（盖放为 false：只播尘雾与暗环）。
  final bool revealCard;

  const SummonTheme({
    required this.category,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.lightStyle,
    this.particleColor = Colors.amber,
    this.particleCount = 60,
    this.ringWidth = 3.0,
    this.ringColors = const [Colors.amber],
    Color? fieldPrimary,
    Color? fieldSecondary,
    this.revealCard = true,
  }) : _fieldPrimary = fieldPrimary,
       _fieldSecondary = fieldSecondary;

  /// 场地特效主色（召唤阵双环 / 中线 / 光柱），默认取鉴赏主色。
  Color get fieldPrimary => _fieldPrimary ?? primaryColor;

  /// 场地特效辅色（粒子与闪光），默认取鉴赏辅色。
  Color get fieldSecondary => _fieldSecondary ?? secondaryColor;

  /// 中文标签（来自类别）。
  String get label => category.label;
}
