import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart';
import 'package:provider/provider.dart';
import '../../stores/duel_board_store.dart';
import '../../stores/duel_selection_store.dart';

class PhaseBar extends StatefulWidget {
  final Set<int> tappablePhaseCodes;
  final ValueChanged<int>? onPhaseTap;

  const PhaseBar({
    super.key,
    this.tappablePhaseCodes = const <int>{},
    this.onPhaseTap,
  });

  @override
  State<PhaseBar> createState() => _PhaseBarState();
}

class _PhaseBarState extends State<PhaseBar> {
  late final DuelBoardStore boardState;
  late final DuelSelectionStore selectionState;

  @override
  void initState() {
    super.initState();
    boardState = context.read<DuelBoardStore>();
    selectionState = context.read<DuelSelectionStore>();
  }

  static const _phases = [
    {'code': PHASE_DRAW, 'activeMask': PHASE_DRAW, 'name': 'DP'},
    {'code': PHASE_STANDBY, 'activeMask': PHASE_STANDBY, 'name': 'SP'},
    {'code': PHASE_MAIN1, 'activeMask': PHASE_MAIN1, 'name': 'MAIN 1'},
    {
      'code': PHASE_BATTLE_START,
      'activeMask':
          PHASE_BATTLE_START |
          PHASE_BATTLE_STEP |
          PHASE_DAMAGE |
          PHASE_DAMAGE_CAL |
          PHASE_BATTLE,
      'name': 'BATTLE',
    },
    {'code': PHASE_MAIN2, 'activeMask': PHASE_MAIN2, 'name': 'MAIN 2'},
    {'code': PHASE_END, 'activeMask': PHASE_END, 'name': 'END'},
  ];

  @override
  Widget build(BuildContext context) {
    final tappablePhaseCodes = widget.tappablePhaseCodes;
    final onPhaseTap = widget.onPhaseTap;
    final isMyTurn = boardState.currentPlayer == boardState.myController;
    final currentPhase = boardState.phase;
    const panelBorder = Color(0x5900F0FF); // rgba(0, 240, 255, 0.35)

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFA060B14), // rgba(6, 11, 20, 0.98)
                const Color(0xF2101A2A), // rgba(16, 26, 42, 0.95)
                const Color(0xFA060B14),
              ],
            ),
            border: const Border(
              bottom: BorderSide(color: panelBorder, width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Turn Info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00F0FF).withOpacity(0.3),
                          const Color(0xFF0064C8).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF00F0FF)),
                    ),
                    child: Text(
                      'TURN ${boardState.turnCount} - ${isMyTurn ? 'YOUR TURN' : 'OPPONENT'}',
                      style: const TextStyle(
                        color: Color(0xFF00F0FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '⏱ 118s',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ],
              ),

              // Phase Tracker
              Row(
                children: _phases.map((p) {
                  final code = p['code'] as int;
                  final activeMask = p['activeMask'] as int;
                  final name = p['name'] as String;
                  final isActive = (currentPhase & activeMask) != 0;
                  final isTappable =
                      tappablePhaseCodes.contains(code) && onPhaseTap != null;

                  return MouseRegion(
                    cursor: isTappable
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    child: GestureDetector(
                      onTap: isTappable ? () => onPhaseTap?.call(code) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? null
                              : Colors.white.withOpacity(
                                  isTappable ? 0.08 : 0.03,
                                ),
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF00F0FF),
                                    Color(0xFF0077FF),
                                  ],
                                )
                              : isTappable
                              ? LinearGradient(
                                  colors: [
                                    const Color(0xFF00F0FF).withOpacity(0.16),
                                    const Color(0xFF0077FF).withOpacity(0.08),
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: isActive
                                ? Colors.white
                                : isTappable
                                ? const Color(0xFF00F0FF).withOpacity(0.65)
                                : Colors.white.withOpacity(0.08),
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF00F0FF,
                                    ).withOpacity(0.6),
                                    blurRadius: 14,
                                  ),
                                ]
                              : isTappable
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF00F0FF,
                                    ).withOpacity(0.18),
                                    blurRadius: 12,
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : isTappable
                                ? const Color(0xFFD7F9FF)
                                : const Color(0xFF8B9BB4),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
