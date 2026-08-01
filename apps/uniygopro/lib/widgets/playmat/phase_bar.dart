import 'dart:ui';
import 'package:flutter/material.dart';
import '../../stores/duel_room_state.dart';

class PhaseBar extends StatelessWidget {
  final DuelRoomState duel;

  const PhaseBar({super.key, required this.duel});

  static const _phases = [
    {'code': 0x01, 'name': 'DP'},
    {'code': 0x02, 'name': 'SP'},
    {'code': 0x04, 'name': 'MAIN 1'},
    {'code': 0x08, 'name': 'BATTLE'},
    {'code': 0x10, 'name': 'MAIN 2'},
    {'code': 0x20, 'name': 'END'},
  ];

  @override
  Widget build(BuildContext context) {
    final isMyTurn = duel.currentPlayer == duel.myController;
    final currentPhase = duel.phase;
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                      'TURN ${duel.turnCount} - ${isMyTurn ? 'YOUR TURN' : 'OPPONENT'}',
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
                  final name = p['name'] as String;
                  final isActive = (currentPhase & code) != 0;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? null : Colors.white.withOpacity(0.03),
                      gradient: isActive
                          ? const LinearGradient(colors: [Color(0xFF00F0FF), Color(0xFF0077FF)])
                          : null,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isActive ? Colors.white : Colors.white.withOpacity(0.08),
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00F0FF).withOpacity(0.6),
                                blurRadius: 14,
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFF8B9BB4),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Orbitron',
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
