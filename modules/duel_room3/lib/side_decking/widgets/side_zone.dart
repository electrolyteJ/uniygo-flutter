import 'package:flutter/material.dart';

import '../../theme/cyber_side_tokens.dart';
import 'side_top_bar.dart' show SideText;

/// 分区标题条：`MAIN DECK · 主卡组` 左对齐，右侧读数右对齐。
///
/// 设计稿里每个分区都是「标题一行 + 容器」的结构，读数用颜色表达状态
/// （主卡组满 40 张=青绿，少一张=酸绿提醒，额外卡组=青）。
class SideSectionLabel extends StatelessWidget {
  const SideSectionLabel({
    super.key,
    required this.label,
    this.trailing,
    this.trailingColor = CyberSideTokens.cyan,
  });

  final String label;
  final String? trailing;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Row(
        children: [
          SideText(
            label,
            size: CyberSideTokens.fsLabel,
            color: CyberSideTokens.textLabel,
            weight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
          const Spacer(),
          if (trailing != null)
            SideText(
              trailing!,
              size: CyberSideTokens.fsLabel,
              color: trailingColor,
              mono: true,
            ),
        ],
      ),
    );
  }
}

/// 分区容器：深底 + 细描边 + 2px 圆角。
class SideZoneBox extends StatelessWidget {
  const SideZoneBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.fill = CyberSideTokens.zoneBg,
    this.line = CyberSideTokens.zoneLine,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color fill;
  final Color line;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(CyberSideTokens.radius),
      ),
      child: child,
    );
  }
}

/// 换备页按钮（设计稿底栏的「提交卡组 / 取消编辑 / 重新提交」）。
///
/// 三种外观由 [filled] + [accent] 决定：
/// - 主按钮：实心强调色底 + 深色字（提交卡组）；
/// - 次按钮：透明底 + 描边（取消编辑）；
/// - 禁用：描边转暗、字转灰（张数不守恒时的提交按钮）。
class SideButton extends StatelessWidget {
  const SideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.accent = CyberSideTokens.cyan,
    this.width = 88,
    this.height = 26,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color accent;
  final double width;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final line = enabled ? accent : CyberSideTokens.controlLine;
    final fill = filled && enabled ? accent : Colors.transparent;
    final textColor = !enabled
        ? CyberSideTokens.textDim
        : filled
        ? CyberSideTokens.onAccent
        : CyberSideTokens.textLabel;
    final child = loading
        ? SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              valueColor: AlwaysStoppedAnimation(textColor),
            ),
          )
        : SideText(
            label,
            size: CyberSideTokens.fsButton,
            color: textColor,
            weight: filled ? FontWeight.w700 : FontWeight.w400,
          );
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(CyberSideTokens.radius),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 顶部搜索/筛选 chip（设计稿 531:2 的「怪兽 21 / 魔陷 19」）。
class SideFilterChip extends StatelessWidget {
  const SideFilterChip({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
    this.width = 52,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? CyberSideTokens.cyanChipBg : CyberSideTokens.barBg,
          border: Border.all(
            color: active
                ? CyberSideTokens.cyan
                : CyberSideTokens.controlLine,
          ),
          borderRadius: BorderRadius.circular(CyberSideTokens.radius),
        ),
        child: SideText(
          label,
          size: CyberSideTokens.fsSmall,
          color: active
              ? CyberSideTokens.cyan
              : CyberSideTokens.textSecondary,
        ),
      ),
    );
  }
}
