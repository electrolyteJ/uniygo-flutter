import 'package:flutter/material.dart';

/// 赛博载入风格设计 token（与 [CyberPalette] / [HudTheme] 同级）。
///
/// 数值全部取自 Ardot 设计稿「07 对战-载入」(415:1) 与「05 对战-等候」
/// 的画板，与 [CyberPalette] 的赛博色板同源（青 #22E6FF 系），但载入页
/// 用的是高饱和版本（#37E2FF / #FF2E88 / #D7FF3E）——设计稿在暗底上
/// 叠了辉光，纯色需要更亮才压得住。
///
/// ⚠️ 本文件**只做常量**，不 import 任何业务模块。
/// 时间相关的派生值（如相位淡入时长）在
/// `loading/models/duel_intro_timeline.dart`，别搬回来——
/// 那会让 theme 反过来依赖 loading。
abstract final class CyberIntroTokens {
  // ── 底色 ──
  static const Color bg = Color(0xFF05070F);

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
}
