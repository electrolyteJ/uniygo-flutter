import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:duelarena/widgets/field/projection.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'field_layout.dart';


/// Full-screen radial background, drawn in screen space.
class BackdropComponent extends Component {
  final FieldCamera camera;

  BackdropComponent({required this.camera});

  @override
  void render(Canvas canvas) {
    final s = camera.viewportSize;
    if (s.isEmpty) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width, s.height),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(s.width / 2, s.height * 0.35),
          s.height * 0.9,
          [
            const Color(0xFF151530),
            const Color(0xFF0A0A1A),
            const Color(0xFF050510),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
  }
}

/// The projected ground plane with a subtle grid, matching the duel mat.
class GroundComponent extends Component {
  final FieldCamera camera;

  GroundComponent({required this.camera});

  @override
  void render(Canvas canvas) {
    final s = camera.viewportSize;
    if (s.isEmpty) return;

    const hw = FieldLayout.groundHalfW + 1.4;
    const nz = FieldLayout.groundNearZ - 1.4;
    const fz = FieldLayout.groundFarZ + 1.4;

    final corners = [
      camera.project(const Vec3(-hw, 0, nz)),
      camera.project(const Vec3(hw, 0, nz)),
      camera.project(const Vec3(hw, 0, fz)),
      camera.project(const Vec3(-hw, 0, fz)),
    ];

    if (corners.every((c) => c != null)) {
      final path = Path()
        ..moveTo(corners[0]!.dx, corners[0]!.dy)
        ..lineTo(corners[1]!.dx, corners[1]!.dy)
        ..lineTo(corners[2]!.dx, corners[2]!.dy)
        ..lineTo(corners[3]!.dx, corners[3]!.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            corners[0]!,
            corners[2]!,
            [
              const Color(0xE8080818),
              const Color(0xF00E0E25),
              const Color(0xE0121230),
            ],
            [0.0, 0.5, 1.0],
          ),
      );
    }

    _drawGridLines(canvas, hw, nz, fz);
  }

  void _drawGridLines(Canvas canvas, double hw, double nz, double fz) {
    for (double z = nz; z <= fz; z += 0.7) {
      final p1 = camera.project(Vec3(-hw, 0, z));
      final p2 = camera.project(Vec3(hw, 0, z));
      if (p1 == null || p2 == null) continue;
      final depth = camera.depthOf(Vec3(0, 0, z));
      final alpha = (0.12 * (1 - depth / 25)).clamp(0.02, 0.12);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = 0.5
          ..color = Colors.cyanAccent.withValues(alpha: alpha),
      );
    }
    for (double x = -hw; x <= hw; x += 0.7) {
      final p1 = camera.project(Vec3(x, 0, nz));
      final p2 = camera.project(Vec3(x, 0, fz));
      if (p1 == null || p2 == null) continue;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = 0.5
          ..color = Colors.cyanAccent.withValues(alpha: 0.05),
      );
    }
  }
}

/// Floating dust particles, in world space.
class ParticlesComponent extends Component {
  final FieldCamera camera;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random(1337);
  double _time = 0;

  ParticlesComponent({required this.camera});

  @override
  Future<void> onLoad() async {
    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        x: (_rng.nextDouble() - 0.5) * 7,
        y: _rng.nextDouble() * 3.5,
        z: (_rng.nextDouble() - 0.5) * 10,
        speed: 0.15 + _rng.nextDouble() * 0.35,
        alpha: 0.1 + _rng.nextDouble() * 0.25,
        radius: 0.5 + _rng.nextDouble() * 1.5,
        drift: 0.5 + _rng.nextDouble() * 1.5,
        phase: _rng.nextDouble() * math.pi * 2,
        color: _rng.nextBool() ? Colors.cyanAccent : Colors.amber,
      ));
    }
  }

  @override
  void update(double dt) {
    _time += dt;
    for (final p in _particles) {
      p.y += p.speed * dt;
      p.x += math.sin(_time * p.drift + p.phase) * dt * 0.15;
      if (p.y > 3.5) {
        p.y = 0;
        p.x = (_rng.nextDouble() - 0.5) * 7;
        p.z = (_rng.nextDouble() - 0.5) * 10;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final s = camera.viewportSize;
    if (s.isEmpty) return;
    for (final p in _particles) {
      final world = Vec3(p.x, p.y, p.z);
      final pos = camera.project(world);
      if (pos == null) continue;
      final depth = camera.depthOf(world);
      final scale = camera.scaleAtDepth(depth, s.height);
      final r = p.radius * scale * 0.01;
      final alpha = p.alpha * (1 - p.y / 3.5);
      if (r < 0.3 || alpha < 0.01) continue;
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = p.color.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
      );
    }
  }
}

class _Particle {
  double x, y, z;
  final double speed;
  final double alpha;
  final double radius;
  final double drift;
  final double phase;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.z,
    required this.speed,
    required this.alpha,
    required this.radius,
    required this.drift,
    required this.phase,
    required this.color,
  });
}

/// Screen-space vignette drawn on top of the scene.
class VignetteComponent extends Component {
  final FieldCamera camera;

  VignetteComponent({required this.camera});

  @override
  void render(Canvas canvas) {
    final s = camera.viewportSize;
    if (s.isEmpty) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width, s.height),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(s.width / 2, s.height / 2),
          math.max(s.width, s.height) * 0.7,
          [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.4),
          ],
          [0, 0.6, 1],
        ),
    );
  }
}
