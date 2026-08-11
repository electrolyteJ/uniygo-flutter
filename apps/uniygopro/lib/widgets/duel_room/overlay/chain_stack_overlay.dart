import 'dart:async';

import 'package:flutter/material.dart';
import '../../../models/ChainLink.dart';
import '../../../image/card_image.dart';

/// 连锁堆叠展示组件。
///
/// 展示条件（两个缺一不可）：
/// 1. 至少 2 个连锁（chains.length >= 2）
/// 2. 连锁组建阶段已结束（sealed == true，即 MSG_CHAIN_SOLVING 已触发）
///
/// 满足条件后全量展示 1s，之后自动淡出消失。
class ChainStackOverlay extends StatefulWidget {
  final List<ChainLink> chains;
  /// 连锁组建阶段已结束（MSG_CHAIN_SOLVING 之后），此时可以展示完整连锁链条。
  final bool chainSealed;
  /// 卡名解析（由业务侧注入，避免组件反向依赖 store）。
  final String Function(int code) cardNameBuilder;

  const ChainStackOverlay({
    super.key,
    required this.chains,
    required this.chainSealed,
    required this.cardNameBuilder,
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
    _onChanged();
  }

  bool _shouldShow() => widget.chains.length >= 2 && widget.chainSealed;

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
    if (_snapshot == null && _fadeController.isCompleted) {
      // 当前无快照且在完全显示状态：外部 chains 在此期间已被清空
      // 取最后已知内容做快照（build 里已更新 _snapshot）
    }
    _fadeController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShow()) {
      _snapshot = List.of(widget.chains);
    }
    if (_snapshot == null) return const SizedBox.shrink();

    final displayChains = _snapshot!;

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
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
          const Icon(Icons.arrow_forward_ios, color: Color(0xFFFFD700), size: 22),
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

  const _PulseChainBadge({
    required this.index,
    required this.code,
    required this.name,
    required this.color,
  });

  @override
  State<_PulseChainBadge> createState() => _PulseChainBadgeState();
}

class _PulseChainBadgeState extends State<_PulseChainBadge>
    with SingleTickerProviderStateMixin {
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

  // 原来的 3 倍大小
  static const double _cardWidth = 300.0;
  static const double _cardHeight = 420.0;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.03).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
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
        padding: const EdgeInsets.only(
          left: 4,
          top: 4,
          right: 4,
          bottom: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 卡图
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CardImage(
                code: widget.code,
                width: _cardWidth,
                height: _cardHeight,
              ),
            ),
            const SizedBox(height: 8),
            // 连锁序号
            Text(
              'CHAIN ${widget.index}',
              style: TextStyle(
                color: widget.color,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            // 卡名
            SizedBox(
              width: _cardWidth,
              child: Text(
                widget.name,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
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
