import 'package:flutter/material.dart';

abstract final class DuelTheme {
  static const void_ = Color(0xFF05060F);
  static const void2 = Color(0xFF0B0E22);
  static const gold = Color(0xFFE8B84B);
  static const goldHi = Color(0xFFFFE9A8);
  static const goldDim = Color(0xFF8A6A2A);
  static const cyan = Color(0xFF3FE0FF);
  static const crimson = Color(0xFFFF3D6E);
  static const spell = Color(0xFF2EE8A0);
  static const trap = Color(0xFFE84BD8);
  static const text = Color(0xFFCFD6F2);
  static const textDim = Color(0xFF7D87B8);
  static const textFaint = Color(0xFF5F6A9C);

  static const cardRatio = 1.457;

  static TextStyle tech(double size, {Color color = text, FontWeight w = FontWeight.w700, double ls = 0}) =>
      TextStyle(
        fontSize: size,
        color: color,
        fontWeight: w,
        letterSpacing: ls == 0 ? size * 0.08 : ls,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle body(double size, {Color color = text, FontWeight w = FontWeight.w600, double ls = 0}) =>
      TextStyle(fontSize: size, color: color, fontWeight: w, letterSpacing: ls);
}
