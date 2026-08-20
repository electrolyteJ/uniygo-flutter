import 'dart:async';

import 'package:flutter/material.dart';

/// 连锁序号徽章（Flutter 侧卡片共用，如手牌栏）。
///
/// 行为与 Flame 侧卡槽徽章一致：
/// - [number] 非空：立即显示/更新序号；
/// - [number] 变 null（连锁结束）：停留 1s 后 300ms 淡出，淡出结束移除；
/// - 停留/淡出期间新序号到来：立即恢复并更新。
class ChainOrderBadge extends StatefulWidget {
  /// 连锁序号（1 起）；null 表示该卡不在当前连锁链上。
  final int? number;

  const ChainOrderBadge({super.key, required this.number});

  @override
  State<ChainOrderBadge> createState() => _ChainOrderBadgeState();
}

class _ChainOrderBadgeState extends State<ChainOrderBadge> {
  static const _lingerDuration = Duration(seconds: 1);
  static const _fadeDuration = Duration(milliseconds: 300);

  /// 正在展示的序号；[ChainOrderBadge.number] 为 null 后仍保留到淡出结束。
  int? _shown;
  bool _fading = false;
  Timer? _lingerTimer;

  @override
  void initState() {
    super.initState();
    _shown = widget.number;
  }

  @override
  void didUpdateWidget(covariant ChainOrderBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.number;
    if (next != null) {
      // 新序号：取消停留计时，立即恢复全量显示。
      _lingerTimer?.cancel();
      _lingerTimer = null;
      _shown = next;
      _fading = false;
    } else if (_shown != null && _lingerTimer == null && !_fading) {
      // 连锁结束：停留 1s 后开始淡出。
      _lingerTimer = Timer(_lingerDuration, () {
        if (mounted) setState(() => _fading = true);
      });
    }
  }

  @override
  void dispose() {
    _lingerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _fading ? 0.0 : 1.0,
      duration: _fadeDuration,
      onEnd: () {
        if (_fading && mounted) {
          setState(() {
            _shown = null;
            _fading = false;
          });
        }
      },
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xD90A101A),
          border: Border.all(color: const Color(0xFFFFD700), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.35),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$shown',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
