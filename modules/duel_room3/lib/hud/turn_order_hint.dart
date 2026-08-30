import 'dart:async';

import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// 先后攻提示：居中短暂展示一次，自带淡入 → 停留 → 淡出 → onDismiss 生命周期。
///
/// 对照 room1 turn_order_hint.dart 的触发与动画：调用方（场地页）监听房间
/// stage 进入 RoomInDuel 时挂载，onDismiss 回调里把本组件从树中移除。
/// room1 用 3200ms 停留，本房按需求收敛到约 2 秒（2000ms 停留 + 400ms 淡出）。
class TurnOrderHint extends StatefulWidget {
  const TurnOrderHint({super.key, required this.isFirst, this.onDismiss});

  final bool isFirst;
  final VoidCallback? onDismiss;

  @override
  State<TurnOrderHint> createState() => _TurnOrderHintState();
}

class _TurnOrderHintState extends State<TurnOrderHint> {
  static const _fadeDuration = Duration(milliseconds: 400);
  static const _holdDuration = Duration(milliseconds: 2000);

  double _opacity = 0.0;
  Timer? _holdTimer;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    // 首帧后再置 1，让 AnimatedOpacity 真正从 0 过渡到 1（否则首帧即满）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1.0);
    });
    _holdTimer = Timer(_holdDuration, () {
      if (!mounted) return;
      setState(() => _opacity = 0.0);
      _fadeTimer = Timer(_fadeDuration, () {
        if (mounted) widget.onDismiss?.call();
      });
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isFirst ? HudTheme.cyan : HudTheme.gold;
    final icon = widget.isFirst ? Icons.flash_on : Icons.shield;
    final label = widget.isFirst ? '你先攻' : '你后攻';
    final subtitle = widget.isFirst ? 'First Turn' : 'Second Turn';
    return AnimatedOpacity(
      opacity: _opacity,
      duration: _fadeDuration,
      curve: Curves.easeOutCubic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF05070F).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.85), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 36),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: HudTheme.caption.copyWith(letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
