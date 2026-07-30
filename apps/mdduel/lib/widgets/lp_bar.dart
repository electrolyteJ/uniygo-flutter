import 'package:flutter/material.dart';
import '../models/duel_state.dart';
import '../theme/md_theme.dart';

class LpBar extends StatelessWidget {
  final DuelState state;
  final Side side;

  const LpBar({super.key, required this.state, required this.side});

  @override
  Widget build(BuildContext context) {
    final st = state.side(side);
    final isOwn = side == Side.own;
    final ratio = (st.lp / 8000).clamp(0.0, 1.0);
    final barColor = isOwn ? MdTheme.gold : MdTheme.crimson;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MdTheme.panel.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: barColor.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.nameOf(side), style: MdTheme.body(12, color: barColor, w: FontWeight.w700, ls: 1)),
              const SizedBox(width: 8),
              Text(isOwn ? 'DUELIST' : 'OPPONENT', style: MdTheme.body(8, color: MdTheme.textFaint, ls: 2)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('LP', style: MdTheme.body(9, color: MdTheme.textDim, ls: 2)),
              const SizedBox(width: 8),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: st.lp, end: st.lp),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, _) => Text(
                  '$value',
                  style: MdTheme.num(24, color: isOwn ? MdTheme.goldHi : const Color(0xFFFFDFE8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 180,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.white.withValues(alpha: .08)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [barColor.withValues(alpha: .7), barColor]),
                        boxShadow: [BoxShadow(color: barColor.withValues(alpha: .6), blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
