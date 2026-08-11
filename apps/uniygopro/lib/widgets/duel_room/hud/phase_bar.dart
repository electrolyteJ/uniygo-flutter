import 'dart:ui';
import 'package:flutter/material.dart';

/// 顶部居中回合徽章（回合数 + 当前行动方）。
class PhaseBar extends StatelessWidget {
  final int turnCount;
  final bool isMyTurn;

  const PhaseBar({super.key, required this.turnCount, required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    // v10: .turn-chip —— 顶部居中悬浮胶囊（回合徽章 + 计时）。
    return SizedBox(
      height: 64,
      child: Center(child: _buildTurnChip()),
    );
  }

  Widget _buildTurnChip() {
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
              const SizedBox(width: 14),
              const Text(
                '⏱ 118s',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
