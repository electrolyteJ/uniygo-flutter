import 'package:flutter/material.dart';
import '../models/duel_state.dart';
import '../theme/duel_theme.dart';

class PhaseRail extends StatelessWidget {
  final DuelState state;

  const PhaseRail({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final foeActive = state.mode == GameMode.ai && state.turn == Side.foe;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('PHASE', style: DuelTheme.tech(9, color: DuelTheme.textDim, ls: 4)),
        const SizedBox(height: 6),
        for (final p in DuelPhase.values) _chip(p, foeActive),
      ],
    );
  }

  Widget _chip(DuelPhase p, bool foeActive) {
    final on = p == state.phase;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        gradient: on
            ? LinearGradient(
                colors: foeActive
                    ? const [DuelTheme.crimson, Color(0xFFC22650)]
                    : const [DuelTheme.gold, Color(0xFFC9982F)])
            : null,
        border: Border(
          right: BorderSide(
            color: on
                ? (foeActive ? const Color(0xFFFF8FAE) : DuelTheme.goldHi)
                : const Color(0x596A74A6),
            width: 2,
          ),
        ),
        boxShadow: [
          if (on)
            BoxShadow(
                color: (foeActive ? DuelTheme.crimson : DuelTheme.gold).withValues(alpha: .5),
                blurRadius: 16),
        ],
      ),
      child: Text(
        '${p.label} ${p.en}',
        style: DuelTheme.body(10,
            color: on ? const Color(0xFF0A0D24) : const Color(0xFF6A74A6),
            w: on ? FontWeight.w700 : FontWeight.w600,
            ls: 1.6),
      ),
    );
  }
}
