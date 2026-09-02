import 'package:flutter/material.dart';

import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:duel_room1/platform/platform_adaptive.dart';

/// 停靠面板骨架：右侧停靠几何 + 面板 chrome（深色底/青色描边/圆角）
/// + 标题栏（可选图标 + 标题 + 张数）+ 右上角 44px 命中区关闭按钮。
///
/// 给「不阻塞对局」的确认/浏览类面板共用（区域浏览、确认卡列表）：
/// 不带全屏遮罩，面板外点击穿透到场地，关闭只走 × 按钮。
/// 两个面板共用同一停靠位，同屏时由页面 Stack 顺序决定谁盖谁。
class DockedPanelShell extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onClose;
  final Widget child;

  /// 标题前的可选引导图标。
  final Widget? leading;

  /// 标题栏「N 张」计数前的可选后缀 chip（如区域浏览的「⚡ N 可发动」）。
  final Widget? titleSuffix;

  const DockedPanelShell({
    super.key,
    required this.title,
    required this.count,
    required this.onClose,
    required this.child,
    this.leading,
    this.titleSuffix,
  });

  // ---- 停靠几何（页面 Stack 内右侧停靠） ----
  static const double panelWidth = 440;
  static const double panelTop = 136;
  static const double panelBottom = 126;
  static const double panelRight = 18;

  /// 面板最小宽度：再窄列数/字号就不可用。
  static const double minPanelWidth = 300.0;

  /// 面板内容区最小高度：极端矮视口下优先保证内容可读。
  static const double minContentHeight = 160.0;

  // ---- 面板与网格样式 ----
  static const double padding = 20;
  static const double gridSpacing = 12;
  static const double gridAspect = 0.72;

  static const accent = Color(0xFF00F0FF);
  static const subtitle = Color(0xFF8B9BB4);
  static const panelColor = Color(0xF2080C14);

  /// 进场动效时长：右滑入 + 淡入，挂载时播放一次。
  static const enterDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final spec = DuelRoomLayout.of(context);
    final viewport = spec.viewport;
    final legacyScale = spec.isCompact ? spec.hudScale : 1.0;
    final desiredTop = panelTop * legacyScale;
    final desiredBottom = panelBottom * legacyScale;
    final top = desiredTop
        .clamp(
          spec.safeRect.top + spec.topHudHeight + spec.panelGap,
          spec.safeRect.bottom,
        )
        .toDouble();
    final desiredBottomEdge =
        viewport.height -
        (desiredBottom >
                spec.safePadding.bottom + spec.handBarHeight + spec.panelGap
            ? desiredBottom
            : spec.safePadding.bottom + spec.handBarHeight + spec.panelGap);
    final bottomEdge = desiredBottomEdge
        .clamp(top, spec.safeRect.bottom)
        .toDouble();
    final bottom = viewport.height - bottomEdge;
    final right = spec.safePadding.right + spec.panelGap;
    final availableWidth = (spec.safeRect.width - spec.panelGap * 2)
        .clamp(0.0, double.infinity)
        .toDouble();
    final width = spec.dockedPanelWidth.clamp(0.0, availableWidth).toDouble();
    return Positioned(
      top: top,
      bottom: bottom,
      right: right,
      width: width,
      // 进场动画必须在 Positioned 之内（Positioned 要求直接挂在 Stack 下）。
      // TweenAnimationBuilder 只在挂载时播放，同实例 rebuild 不重播；
      // 需要重播时由父级换 key（如确认面板按 ConfirmPanel 实例 key）。
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: enterDuration,
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset((1 - t) * 40, 0),
            child: child,
          ),
        ),
        child: Stack(
          children: [
            Container(
              key: const ValueKey('docked-panel'),
              width: double.infinity,
              height: double.infinity,
              padding: EdgeInsets.all(spec.isCompact ? 12 : padding),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent, width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.26),
                    blurRadius: 40,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DockedPanelHeader(
                    title: title,
                    count: count,
                    leading: leading,
                    titleSuffix: titleSuffix,
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: child),
                ],
              ),
            ),
            // 关闭按钮：44px 命中区叠在面板右上角 padding 环内，
            // 20px 图标，不参与标题栏行布局。
            Positioned(
              top: 8,
              right: 8,
              child: _DockedPanelCloseButton(onClose),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标题栏：可选图标 + 标题 + 张数；右端 32px 让位给角落的关闭按钮。
class _DockedPanelHeader extends StatelessWidget {
  final String title;
  final int count;
  final Widget? leading;
  final Widget? titleSuffix;

  const _DockedPanelHeader({
    required this.title,
    required this.count,
    required this.leading,
    this.titleSuffix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: DockedPanelShell.accent,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
        if (titleSuffix != null) ...[titleSuffix!, const SizedBox(width: 8)],
        Text(
          '$count 张',
          style: const TextStyle(
            color: DockedPanelShell.subtitle,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Orbitron',
          ),
        ),
        const SizedBox(width: 32),
      ],
    );
  }
}

/// 关闭按钮：20px 图标 + 44px 命中区（opaque 吸收命中，不穿透）。
class _DockedPanelCloseButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _DockedPanelCloseButton(this.onTap);

  @override
  Widget build(BuildContext context) {
    return ClickableCursor(
      child: Tooltip(
        message: '关闭',
        child: Semantics(
          label: '关闭',
          button: true,
          enabled: onTap != null,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(Icons.close, color: DockedPanelShell.accent, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
