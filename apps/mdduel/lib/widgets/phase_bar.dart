import 'package:flutter/material.dart';
import '../models/duel_state.dart';
import '../theme/md_theme.dart';

class PhaseBar extends StatelessWidget {
  final DuelState state;

  const PhaseBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: MdTheme.panel.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: MdTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('TURN ${state.turnN}', style: MdTheme.num(11, color: MdTheme.goldHi)),
          const SizedBox(width: 12),
          ...DuelPhase.values.map((p) {
            final active = p == state.phase;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: active
                    ? BoxDecoration(
                        color: MdTheme.gold.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: MdTheme.gold.withValues(alpha: .6)),
                      )
                    : null,
                child: Text(
                  p.en.split(' ').first,
                  style: MdTheme.body(9, color: active ? MdTheme.goldHi : MdTheme.textFaint, w: active ? FontWeight.w700 : FontWeight.w400),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
