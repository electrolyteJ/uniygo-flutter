import 'package:flutter/material.dart';
import '../shared/card_image.dart';

class HandCardsBar extends StatefulWidget {
  final List<int> handCodes;
  final int? selectedCardCode;
  final ValueChanged<int>? onCardTap;
  final ValueChanged<int>? onCardDoubleTap;

  const HandCardsBar({
    super.key,
    required this.handCodes,
    this.selectedCardCode,
    this.onCardTap,
    this.onCardDoubleTap,
  });

  @override
  State<HandCardsBar> createState() => _HandCardsBarState();
}

class _HandCardsBarState extends State<HandCardsBar> {
  int? _hoveredCode;

  @override
  Widget build(BuildContext context) {
    if (widget.handCodes.isEmpty) return const SizedBox(height: 84);

    return Container(
      // 100% 还原 HTML .hand-arc-rail 规范: 高度 84px
      height: 84,
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
              final isSelected = widget.selectedCardCode == code;
              final isHovered = _hoveredCode == code;
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
              final double yArc = arcFactor * 8.0; // 中心最高点升起 8px

              // 旋转角度：向两侧呈放射状轻微倾斜
              final double rotation = relativePos * 0.05;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ), // 对应 gap: 8px (左右各4)
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hoveredCode = code),
                  onExit: (_) => setState(() => _hoveredCode = null),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => widget.onCardTap?.call(code),
                    onDoubleTap: () => widget.onCardDoubleTap?.call(code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      // 使用 HTML 中定义的 cubic-bezier(0.34, 1.56, 0.64, 1) 实现灵动的回弹感
                      curve: const Cubic(0.34, 1.56, 0.64, 1),
                      transformAlignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // 3D 视角透视深度
                        ..translate(
                          0.0,
                          -yArc - (isActive ? 20.0 : 0.0),
                          0.0,
                        ) // .hand-card-item:hover { translateY(-20px) }
                        ..rotateZ(rotation)
                        ..scale(isActive ? 1.22 : 1.0), // scale(1.22)
                      child: Container(
                        // 100% 还原 HTML 卡片尺寸: width 56px, height 78px
                        width: 56,
                        height: 78,
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
                                  ? const Color(0xFF00F0FF).withOpacity(0.8)
                                  : Colors.black.withOpacity(0.7),
                              blurRadius: isActive ? 30 : 16,
                              offset: Offset(0, isActive ? 12 : 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CardImage(code: code, width: 56, height: 78),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
