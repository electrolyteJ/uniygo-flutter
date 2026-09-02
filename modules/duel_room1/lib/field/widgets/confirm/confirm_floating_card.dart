import 'package:flutter/material.dart';

import 'package:biz/widgets/card_image.dart';
import 'package:duel_room1/layout/duel_room_layout.dart';

/// 卡组顶部 / 额外卡组顶部 确认展示的浮动卡片。
///
/// 参考经典 ygopro C++ 客户端：卡片偏移 + 旋转展示后自动复位。
/// Flutter 中以浮动卡片 + 缩放动效模拟。
///
/// 时序由 [CardConfirmNotifier] 单一来源驱动：notifier 按
/// 「每卡 750ms（>5 张时每卡 200ms）+ 500ms」推进当前展示下标并在
/// 到期后清空 floatPreviewCodes；本组件只渲染传入的 [currentIndex]
/// 对应的卡片，不持有任何逐张计时 / 自动关闭逻辑。
///
/// 组件自身仅保留淡入/缩放动效（约 300ms，纯装饰），
/// 在 [currentIndex] 变化时重播。
///
/// 手势：点击卡片经 [onInspectCard] 打开卡片详情抽屉（纯检视、不回包）；
/// 提前关闭挪到右上角 × 按钮（[onDismiss]）。
class ConfirmFloatingCard extends StatefulWidget {
  final List<int> codes;

  /// 当前展示的卡下标（由页面从 cardConfirmProvider 状态读取）。
  final int currentIndex;

  final String title;
  final String Function(int code) cardNameBuilder;
  final VoidCallback? onDismiss;

  /// 点击卡片查看详情；为 null 时卡片不响应点击。
  final void Function(int code)? onInspectCard;

  const ConfirmFloatingCard({
    super.key,
    required this.codes,
    this.currentIndex = 0,
    required this.title,
    required this.cardNameBuilder,
    this.onDismiss,
    this.onInspectCard,
  });

  @override
  State<ConfirmFloatingCard> createState() => _ConfirmFloatingCardState();
}

class _ConfirmFloatingCardState extends State<ConfirmFloatingCard>
    with SingleTickerProviderStateMixin {
  /// 纯装饰动效：淡入 + 缩放，与自动关闭时序无关。
  static const _cosmeticDuration = Duration(milliseconds: 300);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _cosmeticDuration, vsync: this);
    _scaleAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.3)),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ConfirmFloatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // 切换到下一张卡：重播装饰动效。
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
    final compact = DuelRoomLayout.of(context).isCompact;
    final width = compact ? 126.0 : 150.0;
    final imageWidth = compact ? 106.0 : 130.0;
    final imageHeight = compact ? 152.0 : 186.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: Transform.scale(scale: _scaleAnim.value, child: child),
        );
      },
      child: MouseRegion(
        key: const ValueKey('confirm-floating-card'),
        cursor: widget.onInspectCard != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: GestureDetector(
          onTap: widget.onInspectCard == null
              ? null
              : () => widget.onInspectCard!(code),
          child: Stack(
            children: [
              Container(
                width: width,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xF2080C14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00F0FF),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CardImage(
                        code: code,
                        width: imageWidth,
                        height: imageHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD7E3F2),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Noto Sans SC',
                        height: 1.25,
                      ),
                    ),
                    if (widget.codes.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${index + 1} / ${widget.codes.length}',
                          style: const TextStyle(
                            color: Color(0xFF8B9BB4),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 提前关闭挪到右上角 ×；卡片本体点击 = 查看详情。
              if (widget.onDismiss != null)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Tooltip(
                    message: '关闭',
                    child: Semantics(
                      label: '关闭',
                      button: true,
                      enabled: true,
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: const ValueKey('confirm-floating-close'),
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onDismiss,
                        child: const SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: Icon(
                              Icons.close,
                              color: Color(0xFF8B9BB4),
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
