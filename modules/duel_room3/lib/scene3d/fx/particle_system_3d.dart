import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_3d/camera.dart';
import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';

/// 单个 3D 粒子（池化复用）。
class _Particle {
  _Particle(this.component, this.material);

  final MeshComponent component;
  final UnlitMaterial material;
  Vector3 velocity = Vector3.zero();
  double life = 0;
  double maxLife = 1;
  double size = 0.1;
  double gravity = 0;
  double drag = 0;
  bool active = false;
}

/// 3D 粒子系统：池化 billboard 小平面，纯 flame_3d 实现。
///
/// - 粒子 = 每帧朝向相机的 PlaneMesh（[CameraComponent3D] 求 yaw/pitch）
/// - 属性：初速度锥形散布 / 重力 / 阻尼 / 生命期 / 尺寸 / 颜色渐隐
/// - 发射器：burst（爆发）/ fountain（喷泉）/ trail（拖尾单发）
class ParticleSystem3D extends Component3D {
  ParticleSystem3D({required this.camera, this.maxParticles = 260});

  final CameraComponent3D camera;
  final int maxParticles;

  final List<_Particle> _pool = [];
  final math.Random _rng = math.Random();

  /// 爆发发射。
  void burst({
    required Vector3 origin,
    required ui.Color color,
    int count = 24,
    double speed = 2.4,
    double spread = 1.0,
    double upBias = 0.7,
    double life = 0.8,
    double size = 0.09,
    double gravity = -2.2,
    double drag = 1.6,
  }) {
    for (var i = 0; i < count; i++) {
      final p = _obtain();
      if (p == null) return;
      final theta = _rng.nextDouble() * math.pi * 2;
      final r = _rng.nextDouble() * spread;
      p.velocity = Vector3(
            math.cos(theta) * r,
            upBias + _rng.nextDouble() * spread * 0.6,
            math.sin(theta) * r,
          ) *
          speed;
      p.component.position.setFrom(origin);
      p.life = p.maxLife = life * (0.6 + _rng.nextDouble() * 0.7);
      p.size = size * (0.7 + _rng.nextDouble() * 0.8);
      p.gravity = gravity;
      p.drag = drag;
      p.active = true;
      p.material.albedoColor = color;
      p.component.scale.setFrom(Vector3.all(p.size));
    }
  }

  /// 单发拖尾粒子（供飞行轨迹沿途撒点）。
  void trail({
    required Vector3 origin,
    required ui.Color color,
    double size = 0.07,
    double life = 0.4,
  }) {
    final p = _obtain();
    if (p == null) return;
    p.velocity = Vector3(
      (_rng.nextDouble() - 0.5) * 0.4,
      (_rng.nextDouble() - 0.2) * 0.4,
      (_rng.nextDouble() - 0.5) * 0.4,
    );
    p.component.position.setFrom(origin);
    p.life = p.maxLife = life;
    p.size = size;
    p.gravity = 0;
    p.drag = 2.0;
    p.active = true;
    p.material.albedoColor = color;
    p.component.scale.setFrom(Vector3.all(size));
  }

  _Particle? _obtain() {
    for (final p in _pool) {
      if (!p.active) return p;
    }
    if (_pool.length >= maxParticles) return null;
    final material = UnlitMaterial();
    final component = MeshComponent(
      mesh: PlaneMesh(size: Vector2(1, 1), material: material),
      rotation: Quaternion.euler(0, 1.5707963, 0),
    );
    final p = _Particle(component, material);
    _pool.add(p);
    add(component);
    return p;
  }

  @override
  void update(double dt) {
    final camPos = camera.position;
    for (final p in _pool) {
      if (!p.active) continue;
      p.life -= dt;
      if (p.life <= 0) {
        p.active = false;
        p.component.scale.setFrom(Vector3.all(0.0001));
        continue;
      }
      // 积分
      p.velocity.y += p.gravity * dt;
      p.velocity.scale(1 / (1 + p.drag * dt));
      p.component.position.add(p.velocity * dt);
      // billboard：法线指向相机（yaw=atan2(dx,dz)，pitch=-asin(dy/|d|)）
      final toCam = camPos - p.component.position;
      final dist = toCam.length;
      if (dist > 1e-4) {
        final yaw = math.atan2(toCam.x, toCam.z);
        final pitch = -math.asin((toCam.y / dist).clamp(-1.0, 1.0));
        p.component.rotation
            .setFrom(Quaternion.euler(yaw, 1.5707963 + pitch, 0));
      }
      // 生命渐隐 + 尺寸衰减
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      final base = p.material.albedoColor;
      p.material.albedoColor = ui.Color.fromRGBO(
        (base.r * 255).round(),
        (base.g * 255).round(),
        (base.b * 255).round(),
        t,
      );
      p.component.scale.setFrom(Vector3.all(p.size * (0.4 + 0.6 * t)));
    }
  }
}
