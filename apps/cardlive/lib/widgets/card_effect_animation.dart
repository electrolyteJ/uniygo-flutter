import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../service/script_service.dart';

class CardEffectAnimation extends StatefulWidget {
  final String animationType;
  final Widget child;

  const CardEffectAnimation({
    super.key,
    required this.animationType,
    required this.child,
  });

  @override
  State<CardEffectAnimation> createState() => _CardEffectAnimationState();
}

class _CardEffectAnimationState extends State<CardEffectAnimation> {
  bool _isAnimating = false;

  void triggerAnimation() {
    setState(() {
      _isAnimating = true;
    });
    Future.delayed(1500.ms, () {
      setState(() {
        _isAnimating = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        _buildEffectOverlay(),
        _buildParticles(),
        _buildGlowEffect(),
      ],
    );
  }

  Widget _buildEffectOverlay() {
    if (!_isAnimating) return const SizedBox.shrink();

    Color overlayColor = Colors.white.withValues(alpha: 0.3);
    Duration duration = 500.ms;

    switch (widget.animationType) {
      case 'destroy':
        overlayColor = Colors.red.withValues(alpha: 0.5);
        duration = 400.ms;
        break;
      case 'spsummon':
        overlayColor = Colors.amber.withValues(alpha: 0.4);
        duration = 800.ms;
        break;
      case 'negate':
        overlayColor = Colors.purple.withValues(alpha: 0.4);
        duration = 600.ms;
        break;
      case 'atkchange':
        overlayColor = Colors.orange.withValues(alpha: 0.3);
        duration = 500.ms;
        break;
      case 'defchange':
        overlayColor = Colors.blue.withValues(alpha: 0.3);
        duration = 500.ms;
        break;
      case 'draw':
        overlayColor = Colors.cyan.withValues(alpha: 0.3);
        duration = 600.ms;
        break;
      case 'remove':
        overlayColor = Colors.grey.withValues(alpha: 0.4);
        duration = 500.ms;
        break;
      case 'tograve':
        overlayColor = Colors.brown.withValues(alpha: 0.4);
        duration = 500.ms;
        break;
      case 'field':
        overlayColor = Colors.green.withValues(alpha: 0.3);
        duration = 1000.ms;
        break;
      case 'ignition':
        overlayColor = Colors.yellow.withValues(alpha: 0.3);
        duration = 600.ms;
        break;
      case 'trigger':
        overlayColor = Colors.pink.withValues(alpha: 0.3);
        duration = 500.ms;
        break;
      case 'continuous':
        overlayColor = Colors.teal.withValues(alpha: 0.2);
        duration = 1200.ms;
        break;
      case 'quick':
        overlayColor = Colors.lime.withValues(alpha: 0.4);
        duration = 300.ms;
        break;
      case 'counter':
        overlayColor = Colors.indigo.withValues(alpha: 0.4);
        duration = 400.ms;
        break;
      case 'damage':
        overlayColor = Colors.red.withValues(alpha: 0.6);
        duration = 400.ms;
        break;
      case 'recover':
        overlayColor = Colors.green.withValues(alpha: 0.4);
        duration = 600.ms;
        break;
      case 'search':
        overlayColor = Colors.blueAccent.withValues(alpha: 0.3);
        duration = 700.ms;
        break;
      case 'deckdes':
        overlayColor = Colors.deepPurple.withValues(alpha: 0.4);
        duration = 500.ms;
        break;
      case 'summon':
        overlayColor = Colors.amberAccent.withValues(alpha: 0.3);
        duration = 600.ms;
        break;
      case 'position':
        overlayColor = Colors.cyanAccent.withValues(alpha: 0.3);
        duration = 400.ms;
        break;
      case 'tohand':
        overlayColor = Colors.lightBlue.withValues(alpha: 0.3);
        duration = 500.ms;
        break;
      default:
        overlayColor = Colors.white.withValues(alpha: 0.3);
        duration = 500.ms;
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: overlayColor,
        ),
      )
          .animate()
          .fadeIn(duration: 100.ms)
          .fadeOut(duration: duration, delay: duration - 100.ms)
          .scale(
            duration: duration,
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.05, 1.05),
          ),
    );
  }

  Widget _buildParticles() {
    if (!_isAnimating) return const SizedBox.shrink();

    final particles = <Widget>[];
    const particleCount = 20;
    const colors = [Colors.white, Colors.amber, Colors.cyan, Colors.purple];

    for (int i = 0; i < particleCount; i++) {
      final color = colors[i % colors.length];
      final delay = (i * 50).ms;
      final size = 4 + (i % 4);

      particles.add(
        Positioned(
          left: 50 + (i * 7) % 100,
          top: 50 + (i * 11) % 200,
          child: Container(
            width: size.toDouble(),
            height: size.toDouble(),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          )
              .animate()
              .fadeIn(duration: 100.ms, delay: delay)
              .move(
                duration: 800.ms,
                curve: Curves.easeOut,
                begin: const Offset(0, 0),
                end: Offset(
                  ((i - particleCount / 2) * 2).toDouble(),
                  (-50 - (i * 3)).toDouble(),
                ),
              )
              .fadeOut(duration: 400.ms, delay: 400.ms),
        ),
      );
    }

    return Stack(children: particles);
  }

  Widget _buildGlowEffect() {
    if (!_isAnimating) return const SizedBox.shrink();

    Color glowColor = Colors.white;

    switch (widget.animationType) {
      case 'destroy':
        glowColor = Colors.red;
        break;
      case 'spsummon':
        glowColor = Colors.amber;
        break;
      case 'negate':
        glowColor = Colors.purple;
        break;
      case 'atkchange':
        glowColor = Colors.orange;
        break;
      case 'draw':
        glowColor = Colors.cyan;
        break;
      case 'remove':
        glowColor = Colors.grey;
        break;
      case 'field':
        glowColor = Colors.green;
        break;
      case 'ignition':
        glowColor = Colors.yellow;
        break;
      case 'trigger':
        glowColor = Colors.pink;
        break;
      case 'damage':
        glowColor = Colors.redAccent;
        break;
      case 'recover':
        glowColor = Colors.greenAccent;
        break;
      case 'search':
        glowColor = Colors.blueAccent;
        break;
      default:
        glowColor = Colors.white;
    }

    final container = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
    );

    return Positioned.fill(
      child: container.animate()
          .fadeIn(duration: 200.ms)
          .fadeOut(duration: 300.ms),
    );
  }
}

class EffectNameAnimation extends StatelessWidget {
  final EffectType effect;
  final bool visible;

  const EffectNameAnimation({
    super.key,
    required this.effect,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Positioned(
      top: -30,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getEffectColor(effect.animationType).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 5,
              ),
            ],
          ),
          child: Text(
            effect.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 200.ms)
            .slide(begin: const Offset(0, -10), end: Offset.zero)
            .fadeOut(duration: 300.ms, delay: 800.ms),
      ),
    );
  }

  Color _getEffectColor(String type) {
    switch (type) {
      case 'destroy':
        return Colors.red;
      case 'spsummon':
        return Colors.amber;
      case 'negate':
        return Colors.purple;
      case 'atkchange':
        return Colors.orange;
      case 'defchange':
        return Colors.blue;
      case 'draw':
        return Colors.cyan;
      case 'remove':
        return Colors.grey;
      case 'tograve':
        return Colors.brown;
      case 'field':
        return Colors.green;
      case 'ignition':
        return Colors.yellow;
      case 'trigger':
        return Colors.pink;
      case 'continuous':
        return Colors.teal;
      case 'quick':
        return Colors.lime;
      case 'counter':
        return Colors.indigo;
      case 'damage':
        return Colors.redAccent;
      case 'recover':
        return Colors.greenAccent;
      case 'search':
        return Colors.blueAccent;
      case 'deckdes':
        return Colors.deepPurple;
      case 'summon':
        return Colors.amberAccent;
      case 'position':
        return Colors.cyanAccent;
      case 'tohand':
        return Colors.lightBlue;
      default:
        return Colors.white;
    }
  }
}