import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 洗牌抖动动画：当 [tick] 变化时，对 child 施加一次水平衰减抖动。
///
/// 用于洗主卡组 / 洗额外卡组 / 洗手牌时的视觉反馈。
class ShuffleShake extends StatefulWidget {
  final int tick;
  final Widget child;

  const ShuffleShake({super.key, required this.tick, required this.child});

  @override
  State<ShuffleShake> createState() => _ShuffleShakeState();
}

class _ShuffleShakeState extends State<ShuffleShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void didUpdateWidget(ShuffleShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tick != widget.tick) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 衰减正弦抖动：幅度随进度线性衰减，来回 6 次。
        final dx = math.sin(t * math.pi * 6) * (1 - t) * 8.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
