import 'dart:ui' show Color;

/// 赛博朋克皮肤色板（纯常量，HUD 与 3D 场景共用）。
///
/// 主色沿用 Ardot 设计稿「uniygopro · 六屏界面」的深黑蓝 + 亮青
/// (#22E6FF)，叠加品红 / 紫 / 酸绿霓虹作为第二强调。经典皮肤（关闭
/// 「赛博演出增强层」时）的回落色也集中放在这里，避免散落在各组件里。
abstract final class CyberPalette {
  /// 背景：近黑深蓝（比经典 #05070F 更冷更暗）。
  static const Color voidBlack = Color(0xFF03060E);
  static const Color deepNavy = Color(0xFF080C1C);
  static const Color panelBg = Color(0xE60B0A1C);
  static const Color panelBorder = Color(0xFF2B2A63);

  /// 主强调：亮青。
  static const Color cyan = Color(0xFF22E6FF);
  static const Color cyanDim = Color(0xFF0E6A86);
  static const Color cyanDeep = Color(0xFF0A2E3C);

  /// 第二强调：品红 / 紫 / 酸绿。
  static const Color magenta = Color(0xFFFF2D95);
  static const Color magentaDim = Color(0xFF7A1550);
  static const Color violet = Color(0xFF8B4DFF);
  static const Color acid = Color(0xFFB4FF39);

  /// 语义色（HUD 里 gold 常被当作「对方 / 连锁」的第二语义色，
  /// 赛博皮肤下用品红，变量名沿用以免破坏大量 const 引用）。
  static const Color gold = Color(0xFFFF2D95);
  static const Color danger = Color(0xFFFF3B5C);
  static const Color heal = Color(0xFFB4FF39);
  static const Color textPrimary = Color(0xFFEAF6FF);
  static const Color textSecondary = Color(0xFF7E8CA8);

  /// 3D 场景专用：光束 / 命中 / 网格。
  static const Color beam = Color(0xFF7DF9FF);
  static const Color impact = Color(0xFFFF5C9E);
  static const Color gridLine = Color(0xFF1B6C86);
  static const Color gridAccent = Color(0xFF8E2270);

  /// 经典皮肤回落色。
  static const Color classicCyan = Color(0xFF37E2FF);
  static const Color classicCyanDim = Color(0xFF1B7FA8);
  static const Color classicHeal = Color(0xFF7CFF6B);
  static const Color classicDanger = Color(0xFFFF5A5A);
  static const Color classicBeam = Color(0xFF9FE8FF);
  static const Color classicImpact = Color(0xFFFFB347);
}
