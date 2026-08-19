import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class PlayerStatusCard extends StatefulWidget {
  final String name;
  final int lp;
  final int maxLp;
  final bool isSelf;
  final bool isActiveTurn;
  final int deckCount;
  final int extraCount;
  final int graveCount;
  final int removedCount;
  final int? handCount;
  final int lpDelta;
  final int lpEventId;
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
    this.handCount,
    this.lpDelta = 0,
    this.lpEventId = 0,
    this.onExtraTap,
    this.onGraveTap,
    this.onRemovedTap,
  });

  @override
  State<PlayerStatusCard> createState() => _PlayerStatusCardState();
}

class _PlayerStatusCardState extends State<PlayerStatusCard> {
  int _displayLp = 0;
  int _lpTweenBegin = 0;
  int _lpTweenEnd = 0;
  int? _floatingDelta;
  Timer? _floatingDeltaTimer;

  @override
  void initState() {
    super.initState();
    _displayLp = widget.lp;
    _lpTweenBegin = widget.lp;
    _lpTweenEnd = widget.lp;
  }

  @override
  void didUpdateWidget(covariant PlayerStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lp != widget.lp) {
      _lpTweenBegin = _displayLp;
      _lpTweenEnd = widget.lp;
    }
    if (oldWidget.lpEventId != widget.lpEventId && widget.lpDelta != 0) {
      _floatingDelta = widget.lpDelta;
      _floatingDeltaTimer?.cancel();
      _floatingDeltaTimer = Timer(const Duration(milliseconds: 1100), () {
        if (mounted) {
          setState(() => _floatingDelta = null);
        }
      });
    }
  }

  @override
  void dispose() {
    _floatingDeltaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cyanGlow = Color(0xFF00F0FF);
    const oppPink = Color(0xFFFF9FBB);
    final borderColor = widget.isSelf
        ? cyanGlow.withValues(alpha: 0.3)
        : const Color(0xFFFF4B82).withValues(alpha: 0.34);
    final shadowColor = widget.isSelf ? cyanGlow : const Color(0xFFFF4B82);
    final turnGlow = widget.isActiveTurn
        ? shadowColor.withValues(alpha: 0.8)
        : shadowColor.withValues(alpha: 0.5);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xE6080E18),
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: turnGlow,
                blurRadius: widget.isActiveTurn ? 28 : 22,
                spreadRadius: widget.isActiveTurn ? 1 : 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isSelf
                        ? [const Color(0xFF00F0FF), const Color(0xFF0077FF)]
                        : [const Color(0xFFFF6698), const Color(0xFF9F2257)],
                  ),
                  border: Border.all(
                    color: widget.isSelf ? cyanGlow : const Color(0xFFFF6698),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                widget.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(width: 14),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(
                  begin: _lpTweenBegin.toDouble(),
                  end: _lpTweenEnd.toDouble(),
                ),
                onEnd: () {
                  _displayLp = widget.lp;
                },
                builder: (context, value, child) {
                  final color = widget.isSelf ? cyanGlow : oppPink;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Text(
                        '${value.round()}',
                        style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      if (_floatingDelta != null)
                        Positioned(
                          right: -6,
                          top: -20,
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            tween: Tween<double>(begin: 0, end: 1),
                            builder: (context, progress, child) {
                              final delta = _floatingDelta!;
                              final isLoss = delta < 0;
                              final y = -18 * progress;
                              return Opacity(
                                opacity: 1 - progress,
                                child: Transform.translate(
                                  offset: Offset(0, y),
                                  child: Text(
                                    '${isLoss ? '' : '+'}${delta.abs()}',
                                    style: TextStyle(
                                      color: isLoss
                                          ? const Color(0xFFFF6B8D)
                                          : const Color(0xFF6CFFB8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Orbitron',
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    if (widget.handCount != null) ...[
                      _buildCountText('HAND', widget.handCount!),
                      const SizedBox(width: 8),
                    ],
                    _buildCountText('D', widget.deckCount),
                    const SizedBox(width: 8),
                    _buildCountText(
                      'EX',
                      widget.extraCount,
                      onTap: widget.onExtraTap,
                    ),
                    const SizedBox(width: 8),
                    _buildCountText(
                      'GY',
                      widget.graveCount,
                      onTap: widget.onGraveTap,
                    ),
                    const SizedBox(width: 8),
                    _buildCountText(
                      'B',
                      widget.removedCount,
                      onTap: widget.onRemovedTap,
                    ),
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
          fontSize: 12,
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
  size: Size(420, 70),
  brightness: Brightness.dark,
)
Widget playerStatusCardSelfPreview() => const PlayerStatusCard(
  name: 'Player',
  lp: 7200,
  lpDelta: -800,
  lpEventId: 1,
  isSelf: true,
  isActiveTurn: true,
  deckCount: 35,
  extraCount: 8,
  graveCount: 3,
  removedCount: 1,
);

@Preview(
  name: 'PlayerStatusCard opponent',
  size: Size(420, 70),
  brightness: Brightness.dark,
)
Widget playerStatusCardOpponentPreview() => const PlayerStatusCard(
  name: 'Rival',
  lp: 5100,
  lpDelta: -1200,
  lpEventId: 1,
  isSelf: false,
  isActiveTurn: false,
  deckCount: 40,
  extraCount: 10,
  graveCount: 5,
  removedCount: 0,
);
