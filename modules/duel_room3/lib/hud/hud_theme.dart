import 'package:flutter/material.dart';

/// MDPro3 风格 HUD 主题：深空蓝黑底 + 青/金霓虹点缀。
abstract final class HudTheme {
  static const Color bgDeep = Color(0xFF05070F);
  static const Color panelBg = Color(0xE60A1220);
  static const Color panelBorder = Color(0xFF1E3A55);
  static const Color cyan = Color(0xFF37E2FF);
  static const Color cyanDim = Color(0xFF1B7FA8);
  static const Color gold = Color(0xFFFFD75A);
  static const Color danger = Color(0xFFFF5A5A);
  static const Color heal = Color(0xFF7CFF6B);
  static const Color textPrimary = Color(0xFFEAF2FF);
  static const Color textSecondary = Color(0xFF8A93A8);

  static BoxDecoration panel({double radius = 10}) => BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: panelBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x59000000), blurRadius: 12),
        ],
      );

  static BoxDecoration glowPanel({Color glow = cyan, double radius = 10}) =>
      BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glow.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: glow.withValues(alpha: 0.25), blurRadius: 16),
        ],
      );

  static const TextStyle title = TextStyle(
    color: textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(color: textPrimary, fontSize: 13);

  static const TextStyle caption =
      TextStyle(color: textSecondary, fontSize: 11);
}
