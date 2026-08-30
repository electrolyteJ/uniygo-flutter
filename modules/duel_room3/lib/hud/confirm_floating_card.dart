import 'package:biz/widgets/card_image.dart';
import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// 卡组顶部 / 额外卡组顶部确认展示的浮动卡片。
///
/// 时序唯一来源是 CardConfirmNotifier.showFloatPreview：notifier 按
/// 「每卡一档（≤5 张 750ms/张，>5 张 200ms/张）+ 500ms 收尾」推进下标，
/// 到期后清空 floatPreviewCodes。本组件只渲染 currentIndex 指向的那张卡，
/// 不持有任何逐张计时 / 自动关闭逻辑（否则会与 notifier 的计时打架）。
///
/// 组件自身仅保留淡入 / 缩放装饰动效（约 300ms），在 currentIndex 变化时
/// 重播；点击卡片仍可提前关闭（onDismiss）。
class ConfirmFloatingCard extends StatefulWidget {
  const ConfirmFloatingCard({
    super.key,
    required this.codes,
    required this.currentIndex,
    required this.title,
    required this.cardNameBuilder,
    this.onDismiss,
  });

  final List<int> codes;
  final int currentIndex;
  final String title;
  final String Function(int code) cardNameBuilder;
  final VoidCallback? onDismiss;

  @override
  State<ConfirmFloatingCard> createState() => _ConfirmFloatingCardState();
}

class _ConfirmFloatingCardState extends State<ConfirmFloatingCard>
    with SingleTickerProviderStateMixin {
  static const _cosmeticDuration = Duration(milliseconds: 300);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _cosmeticDuration, vsync: this);
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.3)),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ConfirmFloatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // 切换到下一张卡：重播装饰动效（与自动关闭时序无关）。
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.codes.isEmpty) return const SizedBox.shrink();
    // 防御性 clamp：下标由页面侧保证不越界（越界时不挂载本组件）。
    final index = widget.currentIndex.clamp(0, widget.codes.length - 1);
    final code = widget.codes[index];
    final name = widget.cardNameBuilder(code);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _opacityAnim.value,
        child: Transform.scale(scale: _scaleAnim.value, child: child),
      ),
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: HudTheme.glowPanel(radius: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HudTheme.caption.copyWith(color: HudTheme.cyan),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CardImage(
                  code: code,
                  width: 130,
                  height: 186,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: HudTheme.caption.copyWith(
                  color: HudTheme.textPrimary,
                  height: 1.25,
                ),
              ),
              if (widget.codes.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${index + 1} / ${widget.codes.length}',
                    style: HudTheme.caption.copyWith(fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
