import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_3d/camera.dart';
import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';

import '../card_texture_cache.dart';
import '../tween_3d.dart';
import 'digit_atlas.dart';
import 'particle_system_3d.dart';
import 'ring_mesh.dart';

/// 召唤特效种类（场景层自有枚举，biz SummonEffectType 由桥接层映射）。
enum SummonFx { normal, special, flip, set, ritual, fusion, synchro, xyz, link }

const _summonColors = {
  SummonFx.normal: ui.Color(0xFFFFD75A),
  SummonFx.special: ui.Color(0xFFFF8C42),
  SummonFx.flip: ui.Color(0xFF7CFF6B),
  SummonFx.set: ui.Color(0xFF9AA4B8),
  SummonFx.ritual: ui.Color(0xFF5AA8FF),
  SummonFx.fusion: ui.Color(0xFFB45AFF),
  SummonFx.synchro: ui.Color(0xFFF2F2F2),
  SummonFx.xyz: ui.Color(0xFFFFE08A),
  SummonFx.link: ui.Color(0xFF37E2FF),
};

/// 效果总控：召唤门/光柱、攻击光束、伤害数字、抽牌飞牌、破坏爆发。
///
/// 所有效果组件生命周期由本管理器托管（播完自动移除）。
class EffectsManager extends Component3D {
  EffectsManager({required CameraComponent3D camera})
      : particles = ParticleSystem3D(camera: camera);

  final ParticleSystem3D particles;
  final TweenEngine3D tweens = TweenEngine3D();

  /// 存活的临时效果组件（到期移除）。
  final List<Component3D> _transient = [];

  @override
  Future<void> onLoad() async {
    await DigitAtlas.instance.ensureBaked();
    await add(particles);
  }

  // ───────────────────────── 召唤 ─────────────────────────

  /// 在 [at]（地砖中心，y=0 平面）播放召唤特效：召唤门圆环 + 光柱 + 粒子爆发。
  void playSummonFx(Vector3 at, SummonFx fx) {
    final color = _summonColors[fx]!;
    if (fx == SummonFx.set) {
      // 盖放：低调的一圈涟漪粒子
      particles.burst(
        origin: at + Vector3(0, 0.15, 0),
        color: color,
        count: 10,
        speed: 1.2,
        life: 0.5,
      );
      return;
    }
    // 召唤门：圆环自转 + 放大 + 渐隐
    final ringMaterial = UnlitMaterial(albedoColor: color);
    final ring = MeshComponent(
      mesh: RingMesh(
        innerRadius: 0.55,
        outerRadius: 0.78,
        material: ringMaterial,
      ),
      position: at + Vector3(0, 0.06, 0),
    );
    _spawnTransient(ring, ttl: 0.9);
    tweens.addVector(Vector3Tween(
      from: Vector3.all(0.3),
      to: Vector3.all(1.6),
      duration: 0.9,
      ease: easeOutCubic,
      apply: (v) => ring.scale.setFrom(v),
    ));
    tweens.addScalar(ScalarTween(
      from: 0,
      to: 6.0,
      duration: 0.9,
      apply: (v) => ring.rotation.setFrom(Quaternion.euler(v, 0, 0)),
    ));
    tweens.addScalar(ScalarTween(
      from: 1.0,
      to: 0.0,
      duration: 0.9,
      apply: (a) => ringMaterial.albedoColor = color.withValues(alpha: a),
    ));
    // 光柱：细圆柱拔起后渐隐
    final beamMaterial = UnlitMaterial(albedoColor: color);
    final beam = MeshComponent(
      mesh: CylinderMesh(
        radius: 0.34,
        height: 1,
        segments: 24,
        material: beamMaterial,
      ),
      position: at + Vector3(0, 0.5, 0),
    );
    _spawnTransient(beam, ttl: 0.75);
    tweens.addScalar(ScalarTween(
      from: 0.01,
      to: 3.4,
      duration: 0.28,
      ease: easeOutCubic,
      apply: (v) {
        beam.scale.setFrom(Vector3(1, v, 1));
        beam.position.setFrom(at + Vector3(0, v / 2, 0));
      },
      onComplete: () {
        tweens.addScalar(ScalarTween(
          from: 1.0,
          to: 0.0,
          duration: 0.4,
          apply: (a) => beamMaterial.albedoColor = color.withValues(alpha: a),
        ));
      },
    ));
    // 粒子爆发
    particles.burst(
      origin: at + Vector3(0, 0.4, 0),
      color: color,
      count: 34,
      speed: 3.0,
      life: 0.9,
    );
  }

  // ───────────────────────── 攻击 ─────────────────────────

  /// 攻击光束（高攻怪追加）：从 [from] 到 [to] 的瞬时圆柱光束。
  void playBeamFx(
    Vector3 from,
    Vector3 to, {
    ui.Color color = const ui.Color(0xFF9FE8FF),
  }) {
    final dir = to - from;
    final length = dir.length;
    if (length < 1e-3) return;
    final material = UnlitMaterial(albedoColor: color);
    final beam = MeshComponent(
      mesh: CylinderMesh(
        radius: 0.09,
        height: 1,
        segments: 12,
        material: material,
      ),
      position: (from + to) / 2,
    );
    // 圆柱轴 Y → dir：axis = Y × dir，angle = acos(Y·dir)
    final d = dir.normalized();
    final axis = Vector3(0, 1, 0).cross(d);
    final angle = math.acos(d.y.clamp(-1.0, 1.0));
    if (axis.length > 1e-4) {
      beam.rotation.setFrom(Quaternion.axisAngle(axis.normalized(), angle));
    } else if (d.y < 0) {
      beam.rotation.setFrom(Quaternion.axisAngle(Vector3(1, 0, 0), math.pi));
    }
    beam.scale.setFrom(Vector3(1, length, 1));
    _spawnTransient(beam, ttl: 0.32);
    tweens.addScalar(ScalarTween(
      from: 1.0,
      to: 0.0,
      duration: 0.32,
      apply: (a) => material.albedoColor = color.withValues(alpha: a),
    ));
  }

  /// 命中爆发（攻击命中点 / 破坏点）。
  void playImpactFx(
    Vector3 at, {
    ui.Color color = const ui.Color(0xFFFFB347),
  }) {
    particles.burst(
      origin: at,
      color: color,
      count: 30,
      speed: 3.4,
      life: 0.7,
      size: 0.11,
    );
    // 命中闪光：瞬放的大平面
    final flashMaterial = UnlitMaterial(albedoColor: const ui.Color(0xFFFFFFFF));
    final flash = MeshComponent(
      mesh: PlaneMesh(size: Vector2(1, 1), material: flashMaterial),
      position: at.clone(),
      rotation: Quaternion.euler(0, 1.5707963, 0),
    );
    _spawnTransient(flash, ttl: 0.18);
    tweens.addVector(Vector3Tween(
      from: Vector3.all(0.2),
      to: Vector3.all(1.8),
      duration: 0.18,
      ease: easeOutCubic,
      apply: (v) => flash.scale.setFrom(v),
    ));
    tweens.addScalar(ScalarTween(
      from: 0.95,
      to: 0.0,
      duration: 0.18,
      apply: (a) => flashMaterial.albedoColor =
          const ui.Color(0xFFFFFFFF).withValues(alpha: a),
    ));
  }

  // ───────────────────────── 伤害数字 ─────────────────────────

  final List<MeshComponent> _digitPool = [];

  /// 在 [at] 上方飘出伤害/回复数字（billboard 由 update 驱动朝向相机）。
  void playDamageNumber(Vector3 at, int amount, {bool heal = false}) {
    final text = (heal ? '+' : '-') + amount.abs().toString();
    final color = heal ? const ui.Color(0xFF7CFF6B) : const ui.Color(0xFFFF5A5A);
    final chars = text.split('');
    final startX = at.x - (chars.length - 1) * 0.14;
    for (var i = 0; i < chars.length; i++) {
      final texture = DigitAtlas.instance.glyph(chars[i]);
      if (texture == null) continue;
      final material = UnlitMaterial(albedoTexture: texture);
      final digit = MeshComponent(
        mesh: PlaneMesh(size: Vector2(0.5, 0.68), material: material),
        position: Vector3(startX + i * 0.28, at.y + 0.9, at.z),
        rotation: Quaternion.euler(0, 1.5707963, 0),
      );
      _digitPool.add(digit);
      // ttl 到期时连引用一起移除（否则 _digitPool 只进不出，
      // update 每帧对全部历史数字做 billboard 计算）。
      _spawnTransient(
        digit,
        ttl: 1.0 + i * 0.05,
        onDone: () => _digitPool.remove(digit),
      );
      final basePos = digit.position.clone();
      final delay = i * 0.05;
      tweens.addScalar(ScalarTween(
        from: 0,
        to: 1,
        duration: 1.0,
        apply: (t) {
          digit.position.setFrom(basePos + Vector3(0, t * 0.9, 0));
          final alpha = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
          material.albedoColor =
              color.withValues(alpha: alpha.clamp(0.0, 1.0));
        },
      ));
      tweens.addVector(Vector3Tween(
        from: Vector3.all(0.01),
        to: Vector3.all(0.55),
        duration: 0.25 + delay,
        ease: easeOutBack,
        apply: (v) => digit.scale.setFrom(v),
      ));
    }
  }

  // ───────────────────────── 抽牌飞牌 ─────────────────────────

  /// 卡背小卡从 [from]（牌组槽位）弧线飞向手牌方向。
  /// [toSelf] 为己方（飞向屏幕近端下方），否则飞向对方牌手方向。
  Future<void> playDrawFlight(Vector3 from, {required bool toSelf}) async {
    final back = await CardTextureCache.instance.cardBack();
    final material = UnlitMaterial(albedoTexture: back);
    final card = MeshComponent(
      mesh: PlaneMesh(size: Vector2(0.5, 0.73), material: material),
      position: from + Vector3(0, 0.3, 0),
      rotation: Quaternion.euler(0, 1.5707963, 0),
    );
    _spawnTransient(card, ttl: 0.6);
    final target = toSelf
        ? Vector3(0, 1.2, 5.4) // 近端下方（HUD 手牌方向）
        : Vector3(0, 1.2, -5.4);
    tweens.addVector(Vector3Tween(
      from: card.position.clone(),
      to: target,
      duration: 0.55,
      arcHeight: 1.6,
      apply: (v) {
        card.position.setFrom(v);
        particles.trail(origin: v, color: const ui.Color(0xFF9FE8FF));
      },
    ));
    tweens.addScalar(ScalarTween(
      from: 0,
      to: math.pi * 4,
      duration: 0.55,
      apply: (v) => card.rotation.setFrom(Quaternion.euler(v, 1.5707963, 0)),
    ));
  }

  // ───────────────────────── 内部 ─────────────────────────

  void _spawnTransient(
    Component3D component, {
    required double ttl,
    void Function()? onDone,
  }) {
    _transient.add(component);
    add(component);
    tweens.addScalar(ScalarTween(
      from: 0,
      to: 1,
      duration: ttl,
      apply: (_) {},
      onComplete: () {
        component.removeFromParent();
        _transient.remove(component);
        onDone?.call();
      },
    ));
  }

  @override
  void update(double dt) {
    tweens.tick(dt);
    // 伤害数字 billboard：面向相机
    final camPos = _cameraPosition;
    if (camPos != null) {
      for (final digit in _digitPool) {
        final toCam = camPos - digit.position;
        final dist = toCam.length;
        if (dist > 1e-4) {
          final yaw = math.atan2(toCam.x, toCam.z);
          final pitch = -math.asin((toCam.y / dist).clamp(-1.0, 1.0));
          digit.rotation
              .setFrom(Quaternion.euler(yaw, 1.5707963 + pitch, 0));
        }
      }
    }
  }

  Vector3? _cameraPosition;

  /// 由 Game 每帧提供相机位置（伤害数字 billboard 用）。
  set cameraPosition(Vector3 value) => _cameraPosition = value;
}
