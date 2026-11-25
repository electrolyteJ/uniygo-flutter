/// 开屏 / 登录 / 主页三屏共用的设计令牌。
///
/// 数值取自 Ardot 设计稿「uniygopro · 六屏界面（844×390）」
/// （文件 744179416852082，页面 01 开屏 / 02 登录 / 03 主页大厅）：
/// 背景 #05070F、面板 #080F19、描边 #1A2C3E ~ #1E3247、
/// 主强调色 #37E2FF、金色 #FFD75A，字体 Noto Serif SC / Noto Sans SC / Inter。
///
/// 字体未随包分发：以系统同名字体 + 中文常见衬线/黑体回退链近似。
library;

import 'package:flutter/material.dart';

/// 三屏共用的颜色。命名按「用途」而非「色相」，方便后续整体换肤。
abstract final class DuelColors {
  /// 页面基色（与设计稿一致的最深背景）。
  static const base = Color(0xFF05070F);

  /// 背景渐变的高光端。
  static const baseTop = Color(0xFF0D1725);

  /// 背景渐变的中段。
  static const baseMid = Color(0xFF070C15);

  /// 弹层/登录卡片底色。
  static const panel = Color(0xFF080F19);

  /// 输入框底色。
  static const field = Color(0xFF071019);

  /// 次级面板（公告列表、匹配条）。
  static const surface = Color(0xFF0B1420);

  /// 抬升面板（公告大图、卡面）。
  static const surfaceRaised = Color(0xFF0E2233);

  /// 选中态面板（模式卡）。
  static const surfaceSelected = Color(0xFF0B2030);

  /// 卡组主卡的蓝底。
  static const cardDeep = Color(0xFF123048);

  /// 底纹网格线。
  static const grid = Color(0xFF0C1622);

  /// 同心圆环线。
  static const ring = Color(0xFF1D3247);

  /// 背景水平分隔线。
  static const rule = Color(0xFF1B2A3C);

  /// 常规描边（输入框、按钮、面板）。
  static const border = Color(0xFF1A2C3E);

  /// 面板描边（略亮）。
  static const borderSoft = Color(0xFF1E3247);

  /// 弹层描边。
  static const borderPanel = Color(0xFF2A4763);

  /// 细分割线（列表项、统计分隔）。
  static const divider = Color(0xFF16263A);

  /// 主强调色（青色）。
  static const accent = Color(0xFF37E2FF);

  /// 次级青色（背景斜线/弧线）。
  static const accentDim = Color(0xFF2C8BA6);

  /// 金色（等级、DP、提示词）。
  static const gold = Color(0xFFFFD75A);

  /// 主文本。
  static const textPrimary = Color(0xFFEAF2FF);

  /// 副标题文本。
  static const textSecondary = Color(0xFFC0C7D4);

  /// 正文本（输入值、游客按钮）。
  static const textBody = Color(0xFFC8D2E0);

  /// 弱文本（段位、列表、公告副题）。
  static const textMuted = Color(0xFF8A93A8);

  /// 更弱文本（标签、页脚）。
  static const textDim = Color(0xFF7A8496);

  /// 最弱文本（脚注、版本）。
  static const textFaint = Color(0xFF6F7A8C);

  /// 几乎消隐的文本（延迟、副行）。
  static const textGhost = Color(0xFF5A6A7E);

  /// 强调色底上的文字。
  static const inkOnAccent = Color(0xFF041018);

  /// 顶部渐隐遮罩用的纯黑。
  static const black = Color(0xFF000000);
}

/// 字体族与回退链。
///
/// 设计稿使用 Noto Serif SC / Noto Sans SC / Inter。仓库未内置这些字体，
/// 因此优先系统内同名/近似字体，最后落到通用族，避免方框字。
abstract final class DuelFonts {
  static const serif = 'Noto Serif SC';
  static const sans = 'Noto Sans SC';
  static const latin = 'Inter';

  static const serifFallback = <String>[
    'Noto Serif SC',
    'Noto Serif CJK SC',
    'Source Han Serif SC',
    'Songti SC',
    'STSong',
    'SimSun',
    'Georgia',
    'serif',
  ];

  static const sansFallback = <String>[
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'Heiti SC',
    'sans-serif',
  ];

  static const latinFallback = <String>[
    'Inter',
    'SF Pro Text',
    'Helvetica Neue',
    'Roboto',
    'Segoe UI',
    'Arial',
    'sans-serif',
  ];
}

/// 常用文字样式。字号全部来自设计稿（逻辑像素）。
abstract final class DuelType {
  static TextStyle _base(
    String family,
    List<String> fallback,
    double size, {
    Color color = DuelColors.textPrimary,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// 衬线（品牌字标、标题、头像字）。
  static TextStyle serif(
    double size, {
    Color color = DuelColors.textPrimary,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) => _base(
    DuelFonts.serif,
    DuelFonts.serifFallback,
    size,
    color: color,
    weight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// 黑体（中文正文、按钮）。
  static TextStyle sans(
    double size, {
    Color color = DuelColors.textPrimary,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) => _base(
    DuelFonts.sans,
    DuelFonts.sansFallback,
    size,
    color: color,
    weight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// 拉丁字体（数值、版本号、英文标签）。
  static TextStyle latin(
    double size, {
    Color color = DuelColors.textPrimary,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) => _base(
    DuelFonts.latin,
    DuelFonts.latinFallback,
    size,
    color: color,
    weight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );
}
