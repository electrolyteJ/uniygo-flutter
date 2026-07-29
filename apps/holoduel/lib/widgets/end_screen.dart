import 'package:flutter/material.dart';
import '../models/duel_state.dart';
import '../theme/duel_theme.dart';

class EndScreen extends StatelessWidget {
  final DuelState state;

  const EndScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.over || state.winner == null) return const SizedBox.shrink();
    final winner = state.winner!;
    final isAi = state.mode == GameMode.ai;
    final youWin = isAi && winner == Side.own;
    final winColor = youWin || !isAi ? DuelTheme.goldHi : const Color(0xFFFF5C7A);
    final cn = isAi ? (youWin ? '胜 利' : '败 北') : '${state.nameOf(winner)} 胜利';
    final en = isAi ? (youWin ? 'VICTORY' : 'DEFEAT') : 'PLAYER WINS';
    final st = state.side(isAi ? Side.own : winner);

    return Container(
      color: const Color(0xF20A0D2B),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cn,
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                  color: winColor,
                  shadows: [
                    Shadow(color: winColor.withValues(alpha: .8), blurRadius: 50),
                    const Shadow(color: Colors.black, offset: Offset(0, 5)),
                  ],
                )),
            const SizedBox(height: 12),
            Text(en, style: DuelTheme.tech(14, color: const Color(0xFF9AA6D8), w: FontWeight.w800, ls: 9)),
            const SizedBox(height: 30),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stat('回合 TURNS', state.turnN, 100),
                const SizedBox(width: 40),
                _stat('造成伤害 DAMAGE', st.damageDealt, 350),
                const SizedBox(width: 40),
                _stat('击破怪兽 KILLS', st.kills, 600),
              ],
            ),
            const SizedBox(height: 38),
            GestureDetector(
              onTap: () => state.reset(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [DuelTheme.goldHi, DuelTheme.gold, Color(0xFFB98A2E)]),
                  boxShadow: [BoxShadow(color: DuelTheme.gold.withValues(alpha: .45), blurRadius: 26)],
                ),
                child: Text('再战一局 REMATCH',
                    style: DuelTheme.body(15, color: const Color(0xFF0A0D24), w: FontWeight.w700, ls: 4)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value, int delayMs) {
    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: delayMs)),
      builder: (context, snap) {
        final started = snap.connectionState == ConnectionState.done;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: DuelTheme.body(11, color: DuelTheme.textDim, ls: 2)),
            const SizedBox(height: 5),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: value),
              duration: started ? const Duration(milliseconds: 900) : Duration.zero,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) =>
                  Text('$v', style: DuelTheme.tech(24, color: const Color(0xFFE8ECFF), w: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }
}
