import 'package:flutter/material.dart';

import 'duel_intro_timeline.dart';

/// 入场动画专用设计 token。
///
/// 数值全部取自 Ardot 设计稿「07 对决-入场动画页」(415:1) 的画板，
/// 与 [CyberPalette] 的赛博色板同源（青 #22E6FF 系），但入场演出用的
/// 是高饱和版本（#37E2FF / #FF2E88 / #D7FF3E）——设计稿在暗底上
/// 叠了辉光，纯色需要更亮才压得住。
abstract final class IntroTokens {
  // ── 底色 ──
  static const Color bg = Color(0xFF05070F);
  static const Color bgDeep = Color(0xFF04060C);

  // ── 主强调：亮青 ──
  static const Color cyan = Color(0xFF37E2FF);

  // ── 第二强调：品红（对手 / 错位层） ──
  static const Color magenta = Color(0xFFFF2E88);

  // ── 第三强调：酸绿（阶段推进 / 进度完成） ──
  static const Color acid = Color(0xFFD7FF3E);

  // ── 文字 ──
  static const Color textPrimary = Color(0xFFEAF2FF);
  static const Color textSecondary = Color(0xFF9FC3D8);
  static const Color textMuted = Color(0xFF6F93A6);
  static const Color textDim = Color(0xFF5A6A7E);
  static const Color textFaint = Color(0xFF3F6478);

  // ── 分隔线 / 槽 ──
  static const Color rule = Color(0xFF2A3D55);
  static const Color slot = Color(0xFF16263A);

  // ── 字体 ──
  /// 英文大字（LINK / DUEL FIELD / VS / DRAW）。
  /// 设计稿用的是几何无衬线（宽字重 + 大字号 + 紧字距）。
  static const String displayFamily = 'Orbitron';

  /// 中文与读数。
  static const String uiFamily = 'Noto Sans SC';

  /// 读数 / 传输日志用等宽。
  static const String monoFamily = 'JetBrains Mono';

  /// 错位大字的位移（设计稿：主层 (0,0)，青层 (-4,-3)，品红层 (+4,+3)）。
  static const Offset cyanGhostOffset = Offset(-4, -3);
  static const Offset magentaGhostOffset = Offset(4, 3);

  /// 相位切换的交叉淡入时长。
  ///
  /// 跟随 [DuelIntroTimeline.speed]（基准 220ms × 1.35 ≈ 297ms）：
  /// 放慢时淡入若还保持原速，相位切换会显得生硬。
  static final Duration phaseFade = Duration(
    milliseconds: (220 * DuelIntroTimeline.speed).round(),
  );
}
