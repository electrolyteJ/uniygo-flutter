import 'package:flutter/material.dart';

class OpponentHandFan extends StatelessWidget {
  final int count;

  const OpponentHandFan({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    // v10 .opp-hand-fan：纯展示卡背扇形（数量显示在对手 HUD 上），不可交互
    final visibleCards = count <= 0 ? 0 : count.clamp(1, 7);
    final center = (visibleCards - 1) / 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(visibleCards, (index) {
        final relative = index - center;
        return Transform.translate(
          offset: Offset(0, relative.abs() * 3),
          child: Transform.rotate(
            angle: relative * 0.09, // 每张约 5°，两端 ±10°~15°
            child: Container(
              width: 34,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF31475E), Color(0xFF0A1020)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
