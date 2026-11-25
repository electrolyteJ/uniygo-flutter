import 'package:flutter/material.dart';

import '../theme/cyber_palette.dart';

/// HUD 主题：赛博朋克皮肤（深黑蓝底 + 亮青主强调 + 品红/酸绿霓虹）。
///
/// 全部保持 `static const`：19 个 HUD 文件里有大量 `const Icon(...,
/// color: HudTheme.cyan)` 之类的编译期引用，把常量改成 getter 会引发
/// 连锁编译错误。因此换肤只改常量值，运行时差异交给 CyberSkin 控制
/// 的「演出增强层」（后处理叠层 / 3D 特效强度）。
abstract final class HudTheme {
  static const Color bgDeep = CyberPalette.voidBlack;
  static const Color panelBg = CyberPalette.panelBg;
  static const Color panelBorder = CyberPalette.panelBorder;
  static const Color cyan = CyberPalette.cyan;
  static const Color cyanDim = CyberPalette.cyanDim;
  static const Color gold = CyberPalette.gold;
  static const Color danger = CyberPalette.danger;
  static const Color heal = CyberPalette.heal;
  static const Color textPrimary = CyberPalette.textPrimary;
  static const Color textSecondary = CyberPalette.textSecondary;

  /// 切角感面板：细线框 + 青色微光外发光 + 深色投影。
  static BoxDecoration panel({double radius = 10}) => BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: panelBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x2600D9FF), blurRadius: 10, spreadRadius: 0.5),
          BoxShadow(color: Color(0x99000000), blurRadius: 14),
        ],
      );

  static BoxDecoration glowPanel({Color glow = cyan, double radius = 10}) =>
      BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glow.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: glow.withValues(alpha: 0.25), blurRadius: 16),
          const BoxShadow(color: Color(0x66000000), blurRadius: 10),
        ],
      );

  static const TextStyle title = TextStyle(
    color: textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );

  static const TextStyle body = TextStyle(
    color: textPrimary,
    fontSize: 13,
    letterSpacing: 0.3,
  );

  static const TextStyle caption = TextStyle(
    color: textSecondary,
    fontSize: 11,
    letterSpacing: 0.6,
  );
}
