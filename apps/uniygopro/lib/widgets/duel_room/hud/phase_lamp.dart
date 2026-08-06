import 'dart:ui';

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

class PhaseLamp extends StatelessWidget {
  final DuelPhase phase;
  final bool enabled;
  final VoidCallback? onTap;

  const PhaseLamp({
    super.key,
    required this.phase,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onTap != null;
    return MouseRegion(
      cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: canTap ? onTap : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: canTap
                      ? const Color(0xFF00F0FF)
                      : Colors.white.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  if (canTap)
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.22),
                      blurRadius: 18,
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00F0FF),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00F0FF,
                          ).withValues(alpha: 0.65),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _phaseName(phase),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Orbitron',
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Text(
                        'CURRENT PHASE',
                        style: TextStyle(
                          color: Color(0xFF8B9BB4),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _phaseName(DuelPhase phase) {
    switch (phase) {
      case DuelPhase.dp:
        return 'DRAW PHASE';
      case DuelPhase.sp:
        return 'STANDBY PHASE';
      case DuelPhase.m1:
        return 'MAIN PHASE 1';
      case DuelPhase.bp:
        return 'BATTLE PHASE';
      case DuelPhase.m2:
        return 'MAIN PHASE 2';
      case DuelPhase.ep:
        return 'END PHASE';
      default:
        return 'PHASE';
    }
  }
}
