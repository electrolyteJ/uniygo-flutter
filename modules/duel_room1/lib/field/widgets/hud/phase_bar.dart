import 'dart:ui';
import 'package:flutter/material.dart';

/// 顶部居中回合徽章（回合数 + 当前行动方 + 剩余时间）。
class PhaseBar extends StatelessWidget {
  final int turnCount;
  final bool isMyTurn;
  final int leftTimeSeconds;

  const PhaseBar({
    super.key,
    required this.turnCount,
    required this.isMyTurn,
    this.leftTimeSeconds = 0,
  });

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 64, child: Center(child: _buildTurnChip()));
  }

  Widget _buildTurnChip() {
    final showTimer = leftTimeSeconds > 0;
    final urgent = leftTimeSeconds > 0 && leftTimeSeconds <= 30;
    final timerColor = urgent
        ? const Color(0xFFFF4D4D)
        : const Color(0xFFFFD700);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [Color(0xB8060B14), Color(0xB30F192A), Color(0xB8060B14)],
            ),
            border: Border.all(color: const Color(0x3300F0FF), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x1A00F0FF), blurRadius: 24),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1A00F0FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x7000F0FF)),
                ),
                child: Text(
                  'TURN $turnCount · ${isMyTurn ? 'YOUR TURN' : 'OPPONENT'}',
                  style: const TextStyle(
                    color: Color(0xFF00F0FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (showTimer) ...[
                const SizedBox(width: 14),
                Text(
                  '⏱ ${_formatTime(leftTimeSeconds)}',
                  style: TextStyle(
                    color: timerColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
