import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:biz/widgets/card_image.dart';
import '../../models/chain_link.dart';

/// 连锁堆叠展示组件。
///
/// 展示条件（两个缺一不可）：
/// 1. 连锁数量满足阈值（默认 >= 2；[showChain1Animation] 开启时 >= 1）
/// 2. 连锁组建阶段已结束（sealed == true，即 MSG_CHAIN_SOLVING 已触发）
///
/// 满足条件后全量展示 1s，之后自动淡出消失。
class ChainStackOverlay extends StatefulWidget {
  final List<ChainLink> chains;

  /// 连锁组建阶段已结束（MSG_CHAIN_SOLVING 之后），此时可以展示完整连锁链条。
  final bool chainSealed;

  /// 是否连锁 1 也显示（来自全局设置「连锁1 也要显示连锁动画」）。
  final bool showChain1Animation;

  /// 卡名解析（由业务侧注入，避免组件反向依赖 store）。
  final String Function(int code) cardNameBuilder;

  const ChainStackOverlay({
    super.key,
    required this.chains,
    required this.chainSealed,
    required this.cardNameBuilder,
    this.showChain1Animation = false,
  });

  @override
  State<ChainStackOverlay> createState() => _ChainStackOverlayState();
}

class _ChainStackOverlayState extends State<ChainStackOverlay>
    with SingleTickerProviderStateMixin {
  static const _displayDuration = Duration(seconds: 1);

  /// 快照：外部 chains 为空时或淡出后仍保留最后一帧用于淡出动画。
  List<ChainLink>? _snapshot;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurveTween(curve: Curves.easeOut).animate(_fadeController);
    _fadeController.value = 1.0;
    // 组件可能在连锁已封印后（modal 卸载→重挂）才首次挂载：此时
    // didUpdateWidget 不会触发，必须在此兜底启动淡出计时，否则连锁叠层
    // 会卡在满透明度永不消失。
    _onChanged();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChainStackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅连锁数据/封印状态变化时重计时；cardNameBuilder 等
    // 其他 prop 变化（页面每次 build 都会重建本组件）不应打断淡出。
    if (oldWidget.chains != widget.chains ||
        oldWidget.chainSealed != widget.chainSealed) {
      _onChanged();
    }
  }

  bool _shouldShow() {
    final enough = widget.showChain1Animation
        ? widget.chains.isNotEmpty
        : widget.chains.length >= 2;
    return enough && widget.chainSealed;
  }

  void _onChanged() {
    if (_shouldShow()) {
      // 新连锁到来：中断淡出 & 取消旧定时器，立即全量显示
      _dismissTimer?.cancel();
      _snapshot = null;
      _fadeController.value = 1.0;
      // 启动 1s 定时器，到时开始淡出
      _dismissTimer = Timer(_displayDuration, _startFadeOut);
    }
    // 空列表不处理——由定时器负责触发淡出
  }

  void _startFadeOut() {
    if (!mounted) return;
    _fadeController.reverse();
  }

  /// 徽章原始尺寸（3 倍卡图）。
  static const double _cardWidth = 300.0;
  static const double _cardHeight = 420.0;

  @override
  Widget build(BuildContext context) {
    if (_shouldShow()) {
      _snapshot = List.of(widget.chains);
    }
    if (_snapshot == null) return const SizedBox.shrink();

    final displayChains = _snapshot!;

    // 徽章尺寸自适应：卡图高度不超过屏幕高度的 35%，
    // 小屏（手机竖屏等）按比例缩小，大屏保持原始尺寸。
    final screenHeight = MediaQuery.sizeOf(context).height;
    final scale = ((screenHeight * 0.35) / _cardHeight).clamp(0.4, 1.0);
    final cardWidth = _cardWidth * scale;
    final cardHeight = _cardHeight * scale;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < displayChains.length; i++) ...[
                if (i > 0) _ChainArrow(),
                _PulseChainBadge(
                  index: i + 1,
                  code: displayChains[i].code,
                  name: widget.cardNameBuilder(displayChains[i].code),
                  color: const Color(0xFFFFD700),
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

@Preview(
  name: 'ChainStackOverlay',
  size: Size(700, 520),
  brightness: Brightness.dark,
)
Widget previewChainStackOverlay() => ChainStackOverlay(
  chains: const [
    ChainLink(code: 89631139, controller: 0, zone: 4, sequence: 0),
    ChainLink(code: 46986414, controller: 1, zone: 4, sequence: 1),
    ChainLink(code: 55144522, controller: 0, zone: 8, sequence: 0),
  ],
  chainSealed: true,
  cardNameBuilder: (code) => 'Card #$code',
);

/// 两个连锁 badge 之间的横向箭头指示器。
class _ChainArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 3, color: Colors.white30),
          const Icon(
            Icons.arrow_forward_ios,
            color: Color(0xFFFFD700),
            size: 22,
          ),
          Container(width: 12, height: 3, color: Colors.white30),
        ],
      ),
    );
  }
}

class _PulseChainBadge extends StatefulWidget {
  final int index;
  final int code;
  final String name;
  final Color color;

  /// 自适应后的卡图尺寸（由父级按屏幕高度缩放后传入）。
  final double cardWidth;
  final double cardHeight;

  const _PulseChainBadge({
    required this.index,
    required this.code,
    required this.name,
    required this.color,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  State<_PulseChainBadge> createState() => _PulseChainBadgeState();
}

class _PulseChainBadgeState extends State<_PulseChainBadge>
    with SingleTickerProviderStateMixin {
  /// 字号随卡图缩放的参考高度。
  static const double _referenceCardHeight = 420.0;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = (widget.cardHeight / _referenceCardHeight).clamp(
      0.5,
      1.0,
    );
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1.0,
        end: 1.03,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xC70A101A),
          border: Border.all(color: widget.color, width: 1.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.24),
              blurRadius: 20,
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: 4, top: 4, right: 4, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 卡图
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CardImage(
                code: widget.code,
                width: widget.cardWidth,
                height: widget.cardHeight,
              ),
            ),
            SizedBox(height: 8 * textScale),
            // 连锁序号
            Text(
              'CHAIN ${widget.index}',
              style: TextStyle(
                color: widget.color,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                fontSize: 18 * textScale,
              ),
            ),
            SizedBox(height: 4 * textScale),
            // 卡名
            SizedBox(
              width: widget.cardWidth,
              child: Text(
                widget.name,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14 * textScale,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
