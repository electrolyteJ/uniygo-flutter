import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../themes/summon_theme.dart';

/// 粒子 —— 描述单个粒子的状态
class Particle {
  Offset position;
  Offset velocity;
  double alpha;
  double size;

  Particle(this.position, this.velocity, this.alpha, this.size);
}

/// 粒子系统组件 —— 从光环中心向外散射粒子
class ParticleSystem extends PositionComponent {
  final SummonTheme style;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();
  bool _emitted = false;
  bool get hasEmitted => _emitted;

  ParticleSystem({required this.style})
      : super(
          size: Vector2(400, 400),
          anchor: Anchor.center,
        );

  double progress = 0.0;

  void emit() {
    if (_emitted) return;
    _emitted = true;
    final center = Offset(size.x / 2, size.y / 2);
    for (int i = 0; i < style.particleCount; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 80 + _random.nextDouble() * 200;
      _particles.add(Particle(
        center,
        Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        1.0,
        1.5 + _random.nextDouble() * 3,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.alpha -= dt * 1.8; // 快速衰减
      if (p.alpha < 0) p.alpha = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_emitted) return;
    for (final p in _particles) {
      if (p.alpha <= 0) continue;
      canvas.drawCircle(
          p.position,
          p.size,
          Paint()
            ..color = style.particleColor.withValues(alpha: p.alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  /// 清理死粒子
  void cleanup() {
    _particles.removeWhere((p) => p.alpha <= 0);
  }
}
