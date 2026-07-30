import 'package:flutter/material.dart';

abstract final class MdTheme {
  static const bg = Color(0xFF0A0E1A);
  static const bgDeep = Color(0xFF060810);
  static const panel = Color(0xFF101828);
  static const panelHi = Color(0xFF1A2440);
  static const gold = Color(0xFFD4A843);
  static const goldHi = Color(0xFFFFE4A0);
  static const goldDim = Color(0xFF8A6B2A);
  static const blue = Color(0xFF2A6AE8);
  static const blueHi = Color(0xFF5A9AFF);
  static const cyan = Color(0xFF38D8F0);
  static const crimson = Color(0xFFE83A5A);
  static const spell = Color(0xFF28C878);
  static const trap = Color(0xFFC840D8);
  static const text = Color(0xFFD8E0F0);
  static const textDim = Color(0xFF8090B0);
  static const textFaint = Color(0xFF506080);
  static const border = Color(0xFF2A3A5A);

  static const cardRatio = 1.457;

  static TextStyle title(double size, {Color color = text, FontWeight w = FontWeight.w700, double ls = 0}) =>
      TextStyle(fontSize: size, color: color, fontWeight: w, letterSpacing: ls == 0 ? size * 0.06 : ls);

  static TextStyle body(double size, {Color color = text, FontWeight w = FontWeight.w500, double ls = 0}) =>
      TextStyle(fontSize: size, color: color, fontWeight: w, letterSpacing: ls);

  static TextStyle num(double size, {Color color = goldHi, FontWeight w = FontWeight.w800}) =>
      TextStyle(
        fontSize: size,
        color: color,
        fontWeight: w,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static BoxDecoration panelBox({double radius = 6}) => BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      );

  static BoxDecoration goldFrame({double radius = 4}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: gold.withValues(alpha: .6)),
        boxShadow: [BoxShadow(color: gold.withValues(alpha: .15), blurRadius: 8)],
      );
}
