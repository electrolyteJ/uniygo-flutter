import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_portal/flutter_portal.dart';

import 'package:biz/widgets/card_image.dart';

class HandCardsBar extends StatefulWidget {
  final List<int> handCodes;
  final int? selectedCardSequence;
  final void Function(int sequence, int code)? onCardTap;

  /// 控制卡面是否可见。
  /// - true：显示卡面图片（默认）。
  /// - false：以卡背占位渲染，不加载卡面网络图片，
  ///   适用于对手手牌、隐私/录播遮罩等场景。
  final bool cardsVisible;

  /// 选中卡上悬浮的弹层内容（如手牌操作菜单）。
  ///
  /// 非空时，选中卡会被 [PortalTarget] 包裹：弹层渲染在全局 [Portal]
  /// 的 Overlay 层，锚定到选中卡并自动跟随滚动、自动避让屏幕边界，
  /// 不再受手牌栏自身 Stack 裁剪或命中测试限制。
  final Widget? overlayContent;

  /// 是否显示 [overlayContent]。仅在卡片被选中时生效。
  final bool overlayVisible;

  /// 就地选择模式（连锁/选卡等）：可选中的手牌下标。
  /// 非空时这些卡高亮上浮，其余手牌置灰弱化。
  final Set<int> highlightedSequences;

  /// 就地选择模式中已勾选的手牌下标（比高亮更强的选中态）。
  final Set<int> checkedSequences;

  /// 每张手牌布局后的矩形回调，供抽卡动画计算终点。
  ///
  /// 上报的矩形位于 [cardRectsAncestor] 坐标系（与场地 anchors 的
  /// localToGlobal(ancestor:) 同一祖先，见 PrototypePlaymatField 的
  /// anchor 上报）；为 null 时退回全局坐标。
  final ValueChanged<Map<int, Rect>>? onCardRectsChanged;

  /// 手牌矩形上报的坐标空间祖先（应与场地 anchor 使用同一祖先，
  /// 保证抽卡动画起点/终点坐标系一致）。
  final RenderBox? cardRectsAncestor;

  /// 洗手牌信号：变化时对手牌栏施加一次抖动。
  final int shuffleTick;

  const HandCardsBar({
    super.key,
    required this.handCodes,
    this.selectedCardSequence,
    this.onCardTap,
    this.cardsVisible = true,
    this.overlayContent,
    this.overlayVisible = false,
    this.highlightedSequences = const {},
    this.checkedSequences = const {},
    this.onCardRectsChanged,
    this.cardRectsAncestor,
    this.shuffleTick = 0,
  });

  @override
  State<HandCardsBar> createState() => _HandCardsBarState();
}

class _HandCardsBarState extends State<HandCardsBar>
    with SingleTickerProviderStateMixin {
  int? _hoveredSequence;
  final Map<int, GlobalKey> _cardKeys = {};
  bool _rectReportQueued = false;

  late final AnimationController _shuffleController;
  List<double> _shuffleOffsets = const [];

  @override
  void initState() {
    super.initState();
    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(covariant HandCardsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shuffleTick != widget.shuffleTick) {
      _startShuffle();
    }
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    super.dispose();
  }

  /// 每张手牌生成一个随机横向偏移（约 ±1.5 个卡位），播放
  /// 「来回替换位置」的洗牌动画，而非整条手牌左右抖动。
  void _startShuffle() {
    final count = widget.handCodes.length;
    if (count < 2) return;
    final rnd = math.Random();
    _shuffleOffsets = List.generate(count, (_) {
      return (rnd.nextDouble() * 2 - 1) * 108.0;
    });
    _shuffleController.forward(from: 0);
  }

  void _scheduleRectReport() {
    if (_rectReportQueued) return;
    _rectReportQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rectReportQueued = false;
      if (!mounted || widget.onCardRectsChanged == null) return;
      final ancestor = widget.cardRectsAncestor;
      final rects = <int, Rect>{};
      for (final entry in _cardKeys.entries) {
        final context = entry.value.currentContext;
        if (context == null) continue;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) continue;
        // 与场地 anchor 相同的祖先坐标空间，保证抽卡动画
        // 终点与 _fieldAnchors.slotRects 起点坐标系一致。
        final topLeft = ancestor != null && ancestor.attached
            ? box.localToGlobal(Offset.zero, ancestor: ancestor)
            : box.localToGlobal(Offset.zero);
        rects[entry.key] = topLeft & box.size;
      }
      widget.onCardRectsChanged!(rects);
    });
  }

  /// 更新悬停手牌下标。延后到帧末再 setState，避免在 MouseTracker 设备
  /// 更新阶段同步 setState 触发 Flutter 的 !_debugDuringDeviceUpdate
  /// 重入断言（见 flutter issue #84241 / #107355）。
  void _setHovered(int? sequence) {
    if (_hoveredSequence == sequence) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hoveredSequence != sequence) {
        setState(() => _hoveredSequence = sequence);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.handCodes.isEmpty) return const SizedBox(height: 96);
    _scheduleRectReport();

    return AnimatedBuilder(
      animation: _shuffleController,
      builder: (context, child) {
        final t = _shuffleController.value;
        // 洗牌进度：0 → 1 → 0（先换位，再回位）。
        final progress = math.sin(t * math.pi);
        return Container(
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
                  final selectionMode = widget.highlightedSequences.isNotEmpty;
                  final isHighlighted =
                      selectionMode &&
                      widget.highlightedSequences.contains(index);
                  final isChecked = widget.checkedSequences.contains(index);
                  final isDimmed = selectionMode && !isHighlighted;

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

                  final cardKey = _cardKeys.putIfAbsent(index, GlobalKey.new);
                  // 手牌数量变化时 _shuffleOffsets 可能还是上次的长度，做越界保护。
                  final shuffleDx = index < _shuffleOffsets.length
                      ? _shuffleOffsets[index] * progress
                      : 0.0;
                  final Widget card = KeyedSubtree(
                    key: cardKey,
                    child: Transform.translate(
                      offset: Offset(shuffleDx, 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ), // 对应 gap: 8px (左右各4)
                        child: MouseRegion(
                          onEnter: (_) => _setHovered(index),
                          onExit: (_) => _setHovered(null),
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => widget.onCardTap?.call(index, code),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              // 使用 HTML 中定义的 cubic-bezier(0.34, 1.56, 0.64, 1) 实现灵动的回弹感
                              curve: const Cubic(0.34, 1.56, 0.64, 1),
                              transformAlignment: Alignment.bottomCenter,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001) // 3D 视角透视深度
                                ..translateByDouble(
                                  0.0,
                                  -yArc -
                                      (isActive
                                          ? 22.0
                                          : isHighlighted
                                          ? 14.0
                                          : 0.0),
                                  0.0,
                                  1.0,
                                )
                                ..rotateZ(rotation)
                                ..scaleByDouble(
                                  isActive
                                      ? 1.16
                                      : 1.0, // v10 .hand-card.selected
                                  isActive ? 1.16 : 1.0,
                                  1.0,
                                  1.0,
                                ),
                              child: Container(
                                // v10 .hand-card: width 68px, height 94px（按轨道高度微缩）
                                width: 64,
                                height: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    // isActive/选中态使用 --cyan-glow (#00f0ff)，默认使用 --gold-glow (#ffd700)
                                    color: isChecked
                                        ? const Color(0xFF00F0FF)
                                        : isActive
                                        ? const Color(0xFF00F0FF)
                                        : isHighlighted
                                        ? const Color(0xFF00F0FF)
                                        : const Color(0xFFFFD700),
                                    width: isChecked ? 2.5 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      // isActive/高亮时增强赛博发光: 0 12px 30px rgba(0, 240, 255, 0.8)
                                      // 默认时: 0 6px 16px rgba(0, 0, 0, 0.7)
                                      color:
                                          (isActive ||
                                              isHighlighted ||
                                              isChecked)
                                          ? const Color(0xFF00F0FF).withValues(
                                              alpha: isChecked ? 0.9 : 0.7,
                                            )
                                          : Colors.black.withValues(alpha: 0.7),
                                      blurRadius:
                                          (isActive ||
                                              isHighlighted ||
                                              isChecked)
                                          ? 30
                                          : 16,
                                      offset: Offset(
                                        0,
                                        (isActive || isHighlighted || isChecked)
                                            ? 12
                                            : 6,
                                      ),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    widget.cardsVisible
                                        ? CardImage(
                                            code: code,
                                            width: 64,
                                            height: 90,
                                          )
                                        : const _CardBack(
                                            width: 64,
                                            height: 90,
                                          ),
                                    if (isDimmed)
                                      IgnorePointer(
                                        child: ColoredBox(
                                          color: Colors.black.withValues(
                                            alpha: 0.55,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );

                  return isSelected && widget.overlayContent != null
                      ? PortalTarget(
                          visible: widget.overlayVisible,
                          anchor: const Aligned(
                            follower: Alignment.bottomCenter,
                            target: Alignment.topCenter,
                            offset: Offset(0, -8),
                            shiftToWithinBound: AxisFlag(x: true, y: true),
                          ),
                          portalFollower: widget.overlayContent!,
                          child: card,
                        )
                      : card;
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 手牌卡背占位组件。
///
/// 在 [HandCardsBar.cardsVisible] 为 false 时使用，不加载任何卡面网络图片，
/// 仅以赛博风格的自绘卡背遮蔽卡面信息。尺寸与卡面保持一致，
/// 以确保选中/悬停的浮动与缩放动画表现完全一致。
class _CardBack extends StatelessWidget {
  final double width;
  final double height;

  const _CardBack({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        size: Size(width, height),
        painter: _CardBackPainter(),
      ),
    );
  }
}

@Preview(
  name: 'HandCardsBar',
  size: Size(520, 120),
  brightness: Brightness.dark,
)
Widget previewHandCardsBar() => const HandCardsBar(
  handCodes: [89631139, 46986414, 15025844, 91152256, 13039848],
);

/// 卡背自绘内容：深色渐变底 + 金色双层边框 + 中心赛博徽记。
class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // 底色：深蓝黑垂直渐变，呼应整体赛博基调。
    final Paint bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1B3A), Color(0xFF0A0B1E)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 细密斜纹纹理，避免大面积纯色显空。
    final Paint stripePaint = Paint()
      ..color = const Color(0xFF3A3D6E).withValues(alpha: 0.35)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    const double step = 6.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripePaint,
      );
    }

    // 内框：双层金线，强化"卡背"质感。
    final Paint innerBorderPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.75)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final Rect innerRect = rect.deflate(4.0);
    canvas.drawRect(innerRect, innerBorderPaint);

    final Paint innerThinPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.30)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(innerRect.deflate(2.0), innerThinPaint);

    // 中心徽记：金色圆环 + 内部青色菱形，作为统一的"背面"标识。
    final Offset center = rect.center;
    final double radius = size.shortestSide * 0.22;

    final Paint ringPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, ringPaint);

    final Paint ringGlowPaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.55)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 2.0, ringGlowPaint);

    // 中心菱形（旋转 45° 的正方形）。
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.785398); // π/4
    final double diamondHalf = radius * 0.45;
    final Paint diamondPaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.85);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: diamondHalf * 2,
        height: diamondHalf * 2,
      ),
      diamondPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
