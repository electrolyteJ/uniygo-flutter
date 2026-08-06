import 'package:flutter/material.dart';
import '../../shared/card_image.dart';

class HandCardsBar extends StatefulWidget {
  final List<int> handCodes;
  final int? selectedCardSequence;
  final void Function(int sequence, int code)? onCardTap;
  final void Function(int sequence, int code)? onCardDoubleTap;

  /// 以手牌栏自身左上角为原点，上报当前选中卡片的实际渲染矩形。
  /// 手牌溢出滚动或窗口尺寸变化时，该矩形仍然准确。
  final ValueChanged<Rect?>? onSelectedCardRectChanged;

  const HandCardsBar({
    super.key,
    required this.handCodes,
    this.selectedCardSequence,
    this.onCardTap,
    this.onCardDoubleTap,
    this.onSelectedCardRectChanged,
  });

  @override
  State<HandCardsBar> createState() => _HandCardsBarState();
}

class _HandCardsBarState extends State<HandCardsBar> {
  int? _hoveredSequence;
  final GlobalKey _rootKey = GlobalKey();
  final Map<int, GlobalKey> _cardKeys = <int, GlobalKey>{};
  Rect? _lastReportedRect;
  bool _rectEmitQueued = false;

  @override
  void didUpdateWidget(covariant HandCardsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCardSequence != widget.selectedCardSequence) {
      _scheduleRectEmit();
      // 选中上浮动画结束后再补报一次，让 popover 跟随最终位置。
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _emitSelectedCardRect();
      });
    }
  }

  void _scheduleRectEmit() {
    if (widget.onSelectedCardRectChanged == null) return;
    if (_rectEmitQueued) return;
    _rectEmitQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rectEmitQueued = false;
      if (!mounted) return;
      _emitSelectedCardRect();
    });
  }

  void _emitSelectedCardRect() {
    final callback = widget.onSelectedCardRectChanged;
    if (callback == null) return;
    final selected = widget.selectedCardSequence;
    Rect? rect;
    final rootBox = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (selected != null && rootBox != null && rootBox.hasSize) {
      final cardBox =
          _cardKeys[selected]?.currentContext?.findRenderObject() as RenderBox?;
      if (cardBox != null && cardBox.hasSize) {
        rect =
            cardBox.localToGlobal(Offset.zero, ancestor: rootBox) &
            cardBox.size;
      }
    }
    if (rect == _lastReportedRect) return;
    _lastReportedRect = rect;
    callback(rect);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.handCodes.isEmpty) return const SizedBox(height: 96);
    _scheduleRectEmit();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _scheduleRectEmit();
        return false;
      },
      child: Container(
        key: _rootKey,
        // v10 .hand: 底部手牌栏，卡片 68x94 微微探出轨道
        height: 96,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 4),
        // 关键：允许 scale(1.22) 和 translateY(-20) 在 3D 空间中自然溢出容器
        clipBehavior: Clip.none,
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: widget.handCodes.asMap().entries.map((entry) {
                final index = entry.key;
                final code = entry.value;
                final isSelected = widget.selectedCardSequence == index;
                final isHovered = _hoveredSequence == index;
                final isActive = isSelected || isHovered;

                // 100% 还原大师级弧形逻辑 (Convex Arc)
                final centerIndex = (widget.handCodes.length - 1) / 2;
                final relativePos = index - centerIndex;
                final absRelative = relativePos.abs();
                final maxAbs = centerIndex > 0 ? centerIndex : 1.0;

                // 物理模型：中心卡片略微升起，呈现凸形扇形
                // 弧形高度因子 (0.0 到 1.0)，边缘 0，中心 1
                final double arcFactor = (1.0 - (absRelative / maxAbs)).clamp(
                  0.0,
                  1.0,
                );
                final double yArc = arcFactor * 10.0; // 中心最高点升起 10px

                // 旋转角度：向两侧呈放射状轻微倾斜
                final double rotation = relativePos * 0.10;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ), // 对应 gap: 8px (左右各4)
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredSequence = index),
                    onExit: (_) => setState(() => _hoveredSequence = null),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onCardTap?.call(index, code),
                      onDoubleTap: () =>
                          widget.onCardDoubleTap?.call(index, code),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        // 使用 HTML 中定义的 cubic-bezier(0.34, 1.56, 0.64, 1) 实现灵动的回弹感
                        curve: const Cubic(0.34, 1.56, 0.64, 1),
                        transformAlignment: Alignment.bottomCenter,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // 3D 视角透视深度
                          ..translateByDouble(
                            0.0,
                            -yArc - (isActive ? 22.0 : 0.0),
                            0.0,
                            1.0,
                          )
                          ..rotateZ(rotation)
                          ..scaleByDouble(
                            isActive ? 1.16 : 1.0, // v10 .hand-card.selected
                            isActive ? 1.16 : 1.0,
                            1.0,
                            1.0,
                          ),
                        child: Container(
                          // 用于向上一层上报选中卡片的实际渲染矩形（含浮动变换）
                          key: _cardKeys.putIfAbsent(index, GlobalKey.new),
                          // v10 .hand-card: width 68px, height 94px（按轨道高度微缩）
                          width: 64,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              // isActive 时使用 --cyan-glow (#00f0ff)，默认使用 --gold-glow (#ffd700)
                              color: isActive
                                  ? const Color(0xFF00F0FF)
                                  : const Color(0xFFFFD700),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                // isActive 时增强赛博发光: 0 12px 30px rgba(0, 240, 255, 0.8)
                                // 默认时: 0 6px 16px rgba(0, 0, 0, 0.7)
                                color: isActive
                                    ? const Color(
                                        0xFF00F0FF,
                                      ).withValues(alpha: 0.8)
                                    : Colors.black.withValues(alpha: 0.7),
                                blurRadius: isActive ? 30 : 16,
                                offset: Offset(0, isActive ? 12 : 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CardImage(code: code, width: 64, height: 90),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
