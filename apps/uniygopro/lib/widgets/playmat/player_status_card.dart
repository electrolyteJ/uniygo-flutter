import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class PlayerStatusCard extends StatelessWidget {
  final String name;
  final int lp;
  final int maxLp;
  final bool isSelf;
  final bool isActiveTurn;
  final int deckCount;
  final int extraCount;
  final int graveCount;
  final int removedCount;
  final VoidCallback? onExtraTap;
  final VoidCallback? onGraveTap;
  final VoidCallback? onRemovedTap;

  const PlayerStatusCard({
    super.key,
    required this.name,
    required this.lp,
    this.maxLp = 8000,
    required this.isSelf,
    required this.isActiveTurn,
    required this.deckCount,
    required this.extraCount,
    required this.graveCount,
    required this.removedCount,
    this.onExtraTap,
    this.onGraveTap,
    this.onRemovedTap,
  });

  @override
  Widget build(BuildContext context) {
    const cyanGlow = Color(0xFF00F0FF);
    const crimsonGlow = Color(0xFFFF0055);
    final borderColor = isSelf
        ? cyanGlow.withOpacity(0.4)
        : crimsonGlow.withOpacity(0.5);
    final shadowColor = isSelf ? cyanGlow : crimsonGlow;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xE6080E18), // rgba(8, 14, 24, 0.9)
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isSelf
                        ? [const Color(0xFFFFD700), const Color(0xFFFF9800)]
                        : [const Color(0xFF00F0FF), const Color(0xFF0077FF)],
                  ),
                  border: Border.all(
                    color: isSelf ? Colors.amber : cyanGlow,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(width: 10),
              // LP
              Text(
                '$lp',
                style: TextStyle(
                  color: isSelf ? cyanGlow : crimsonGlow,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(width: 10),
              // Counts
              Container(
                padding: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    _buildCountText('D', deckCount),
                    const SizedBox(width: 6),
                    _buildCountText('EX', extraCount, onTap: onExtraTap),
                    const SizedBox(width: 6),
                    _buildCountText('GY', graveCount, onTap: onGraveTap),
                    const SizedBox(width: 6),
                    _buildCountText('RM', removedCount, onTap: onRemovedTap),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountText(String label, int count, {VoidCallback? onTap}) {
    final child = RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF8B9BB4),
          fontSize: 10,
          fontFamily: 'Orbitron',
        ),
        children: [
          TextSpan(text: '$label:'),
          TextSpan(
            text: '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

@Preview(
  name: 'PlayerStatusCard self',
  size: Size(300, 50),
  brightness: Brightness.dark,
)
Widget playerStatusCardSelfPreview() => const PlayerStatusCard(
  name: 'Player',
  lp: 7200,
  isSelf: true,
  isActiveTurn: true,
  deckCount: 35,
  extraCount: 8,
  graveCount: 3,
  removedCount: 1,
);

@Preview(
  name: 'PlayerStatusCard opponent',
  size: Size(300, 50),
  brightness: Brightness.dark,
)
Widget playerStatusCardOpponentPreview() => const PlayerStatusCard(
  name: 'Rival',
  lp: 5100,
  isSelf: false,
  isActiveTurn: false,
  deckCount: 40,
  extraCount: 10,
  graveCount: 5,
  removedCount: 0,
);
