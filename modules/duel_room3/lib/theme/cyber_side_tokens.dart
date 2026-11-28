import 'package:flutter/material.dart';

/// 换备界面设计 token（Ardot「08 对战-换备」744179416852082 / node 531:1）。
///
/// 与 [CyberIntroTokens] 的关系：两者同源（都是赛博暗底 + 亮青强调），
/// 但载入页只用「青 / 品红 / 酸绿」三色，换备界面多出一整套**区域语义色**
/// ——主卡组青、额外卡组紫、副卡组青绿、待补空位橄榄、错误条品红底。
/// 混进 `CyberIntroTokens` 会让载入页读到一个它永远不用的色板，故单开一份。
///
/// ⚠️ 数值全部是设计稿原值，改色请回设计稿核对，不要凭观感调。
/// 尺寸一律按 844×390 设计基准书写，界面消费时乘缩放系数 k。
abstract final class CyberSideTokens {
  // ── 底板 ──
  /// 顶条 / 搜索框 / 就绪行底（比页面底亮一档）。
  static const Color barBg = Color(0xFF070D16);

  /// 分区容器底（主卡组区 / 副卡组区 / 清单区 / 交换台）。
  static const Color zoneBg = Color(0xFF05090F);

  /// 分区容器描边。
  static const Color zoneLine = Color(0xFF19293C);

  /// 分隔线 / 进度槽。
  static const Color rule = Color(0xFF16263A);

  /// 输入框 / 次级按钮描边。
  static const Color controlLine = Color(0xFF2A4763);

  // ── 强调 ──
  /// 主强调青：主卡组、我方、当前筛选。
  static const Color cyan = Color(0xFF37E2FF);

  /// 筛选选中底（青的低透明度实色，设计稿直接给了实色）。
  static const Color cyanChipBg = Color(0xFF163342);

  /// 主卡组卡面底（青的中透明度实色）。
  static const Color cardMainBg = Color(0xFF1E4A63);

  /// 副卡组卡面底（比主卡组深，暗示「在场外」）。
  static const Color cardSideBg = Color(0xFF0B2030);

  /// 额外卡组卡面底 / 描边（紫）。
  static const Color cardExtraBg = Color(0xFF43275A);
  static const Color extraViolet = Color(0xFF905FE8);

  /// 就绪 / 换入 / 通过（青绿）。
  static const Color heal = Color(0xFF5FD38A);

  /// 换出 / 错误 / 超时（品红）。
  static const Color danger = Color(0xFFFF2E88);

  /// 错误条底。
  static const Color dangerBg = Color(0xFF25070F);

  /// 倒计时 / 张数读数（酸绿）。
  static const Color acid = Color(0xFFD7FF3E);

  /// 待补空位描边（橄榄绿，弱于强调色，只在缺卡时出现）。
  static const Color pendingLine = Color(0xFF668026);

  /// 选中卡描边同 [danger]，底为紫红混合。
  static const Color cardSelectedBg = Color(0xFF5C3268);

  // ── 文字 ──
  /// 卡名 / 标题。
  static const Color textPrimary = Color(0xFFEAFCFF);

  /// 分区标题（MAIN DECK · 主卡组）。
  static const Color textLabel = Color(0xFF8A93A8);

  /// 副标 / 卡类 / 说明。
  static const Color textSecondary = Color(0xFF6F7A8C);

  /// 底注 / 时限值（最暗的可读档）。
  static const Color textDim = Color(0xFF5A6A7E);

  /// 搜索占位（几乎不可读，仅作提示）。
  static const Color textFaint = Color(0xFF3F4F65);

  /// 比分分隔符。
  static const Color textRule = Color(0xFF516F88);

  /// 确认按钮上的深字（青底反白）。
  static const Color onAccent = Color(0xFF041018);

  // ── 字号（设计稿 @844×390）──
  /// 页面标题「换备」。
  static const double fsTitle = 13;

  /// 倒计时数字。
  static const double fsTimer = 13;

  /// 按钮文案。
  static const double fsButton = 8.5;

  /// 分区标题 / 张数读数。
  static const double fsLabel = 7.5;

  /// 正文（副卡卡名、清单行）。
  static const double fsBody = 7;

  /// 次级正文（卡类、筛选 chip、换牌清单）。
  static const double fsSmall = 6.5;

  /// 角标（卡面 ×N、待补、就绪态）。
  static const double fsMicro = 6;

  // ── 版式（设计稿 844×390 基准）──
  /// 设计基准尺寸，界面按 min(w/844, h/390) 求缩放系数。
  static const Size designSize = Size(844, 390);

  /// 顶条高度。
  static const double topBarHeight = 52;

  /// 底栏分隔线到页面底的距离（按钮底边）。
  static const double bottomBarHeight = 54;

  /// 页面左右内边距。
  static const double pagePadding = 16;

  /// 卡片圆角（设计稿所有卡面与按钮都是 2，硬朗的赛博风格）。
  static const double radius = 2;

  /// 主卡组网格：13 列卡宽 30 间距 6。
  static const double gridCardSize = 30;
  static const double gridGap = 6;

  /// 额外卡组卡面 28×24。
  static const Size extraCardSize = Size(28, 24);

  // ── 字体族 ──
  /// 读数 / 比分 / 倒计时用等宽，与载入页保持一致。
  static const String monoFamily = 'JetBrains Mono';
}
