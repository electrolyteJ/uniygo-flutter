import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

class SummonParticleFX extends PositionComponent {
  final Vector2 spawnPosition;
  final Color color;

  SummonParticleFX({
    required this.spawnPosition,
    this.color = const Color(0xFF00F0FF), // Matches --cyan-glow
  }) : super(position: spawnPosition);

  @override
  Future<void> onLoad() async {
    final random = Random();

    // 创建向上的赛博能量流 (Vertical Energy Stream)
    final particle = Particle.generate(
      count: 25,
      lifespan: 1.0,
      generator: (i) {
        final double lineLength = 15.0 + random.nextDouble() * 20.0;
        final double xOffset = (random.nextDouble() - 0.5) * 60.0;
        final double speed = 150.0 + random.nextDouble() * 100.0;

        return AcceleratedParticle(
          position: Vector2(xOffset, 40),
          speed: Vector2(0, -speed),
          acceleration: Vector2(0, -100),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final opacity = (1.0 - particle.progress).clamp(0.0, 1.0);
              final paint = Paint()
                ..color = color.withOpacity(opacity)
                ..strokeWidth = 2.0
                ..style = PaintingStyle.stroke
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
              
              // 绘制垂直能量线
              canvas.drawLine(
                Offset.zero,
                Offset(0, lineLength),
                paint,
              );

              // 增加顶端亮点
              canvas.drawCircle(
                Offset.zero, 
                1.5, 
                Paint()..color = Colors.white.withOpacity(opacity)
              );
            },
          ),
        );
      },
    );

    add(ParticleSystemComponent(particle: particle));
  }
}
