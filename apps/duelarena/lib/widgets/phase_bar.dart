import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../models/duel_state.dart';
import '../preview_helpers.dart';

class PhaseBar extends StatelessWidget {
  final DuelPhase currentPhase;
  final bool isPlayerTurn;
  final int turn;
  final ValueChanged<DuelPhase>? onPhaseTap;

  const PhaseBar({
    super.key,
    required this.currentPhase,
    required this.isPlayerTurn,
    required this.turn,
    this.onPhaseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPlayerTurn
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'TURN $turn',
                style: TextStyle(
                  color:
                      isPlayerTurn ? Colors.lightBlueAccent : Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ...DuelPhase.values.map((phase) {
              final isCurrent = phase == currentPhase;
              final isPast = DuelPhase.values.indexOf(phase) <
                  DuelPhase.values.indexOf(currentPhase);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => onPhaseTap?.call(phase),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.amber.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isCurrent
                          ? Border.all(
                              color: Colors.amber.withValues(alpha: 0.6))
                          : null,
                    ),
                    child: Text(
                      phase.label,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.amberAccent
                            : isPast
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.25),
                        fontSize: 10,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

@Preview(name: '主要阶段1', group: 'PhaseBar', wrapper: darkPreviewWrapper)
Widget previewPhaseMain1() => const PhaseBar(
    currentPhase: DuelPhase.main1, isPlayerTurn: true, turn: 3);

@Preview(name: '战斗阶段', group: 'PhaseBar', wrapper: darkPreviewWrapper)
Widget previewPhaseBattle() => const PhaseBar(
    currentPhase: DuelPhase.battle, isPlayerTurn: false, turn: 5);
