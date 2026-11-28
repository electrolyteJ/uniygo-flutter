import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_3d/camera.dart';
import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';

import '../../../theme/cyber_skin.dart';
import '../card_texture_cache.dart';
import '../tween_3d.dart';
import 'digit_atlas.dart';
import 'particle_system_3d.dart';
import 'ring_mesh.dart';

/// 召唤特效种类（场景层自有枚举，biz SummonEffectType 由桥接层映射）。
enum SummonFx { normal, special, flip, set, ritual, fusion, synchro, xyz, link }

const _classicSummonColors = {
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

/// 赛博皮肤召唤色：提高饱和度，并把 XYZ / Link 换成品红 / 亮青。
const _cyberSummonColors = {
  SummonFx.normal: ui.Color(0xFFFFC93C),
  SummonFx.special: ui.Color(0xFFFF5A2E),
  SummonFx.flip: CyberPalette.acid,
  SummonFx.set: ui.Color(0xFF6C7AA8),
  SummonFx.ritual: ui.Color(0xFF4D7CFF),
  SummonFx.fusion: CyberPalette.violet,
  SummonFx.synchro: ui.Color(0xFFE6FBFF),
  SummonFx.xyz: CyberPalette.magenta,
  SummonFx.link: CyberPalette.cyan,
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
    final cyber = CyberSkin.isOn;
    final color = (cyber ? _cyberSummonColors : _classicSummonColors)[fx]!;
    if (fx == SummonFx.set) {
      // 盖放：低调的一圈涟漪粒子
      particles.burst(
        origin: at + Vector3(0, 0.15, 0),
        color: color,
        count: cyber ? 16 : 10,
        speed: cyber ? 1.6 : 1.2,
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
    tweens.addVector(
      Vector3Tween(
        from: Vector3.all(0.3),
        to: Vector3.all(1.6),
        duration: 0.9,
        ease: easeOutCubic,
        apply: (v) => ring.scale.setFrom(v),
      ),
    );
    tweens.addScalar(
      ScalarTween(
        from: 0,
        to: 6.0,
        duration: 0.9,
        apply: (v) => ring.rotation.setFrom(Quaternion.euler(v, 0, 0)),
      ),
    );
    tweens.addScalar(
      ScalarTween(
        from: 1.0,
        to: 0.0,
        duration: 0.9,
        apply: (a) => ringMaterial.albedoColor = color.withValues(alpha: a),
      ),
    );
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
    tweens.addScalar(
      ScalarTween(
        from: 0.01,
        to: 3.4,
        duration: 0.28,
        ease: easeOutCubic,
        apply: (v) {
          beam.scale.setFrom(Vector3(1, v, 1));
          beam.position.setFrom(at + Vector3(0, v / 2, 0));
        },
        onComplete: () {
          tweens.addScalar(
            ScalarTween(
              from: 1.0,
              to: 0.0,
              duration: 0.4,
              apply: (a) =>
                  beamMaterial.albedoColor = color.withValues(alpha: a),
            ),
          );
        },
      ),
    );
    if (cyber) {
      // 第二层召唤门：更大、反向自转的品红外环，与主环构成双层符文门。
      final outerMat = UnlitMaterial(albedoColor: CyberPalette.magenta);
      final outerRing = MeshComponent(
        mesh: RingMesh(
          innerRadius: 0.92,
          outerRadius: 1.02,
          material: outerMat,
        ),
        position: at + Vector3(0, 0.05, 0),
      );
      _spawnTransient(outerRing, ttl: 1.05);
      tweens.addVector(
        Vector3Tween(
          from: Vector3.all(0.25),
          to: Vector3.all(1.9),
          duration: 1.05,
          ease: easeOutCubic,
          apply: (v) => outerRing.scale.setFrom(v),
        ),
      );
      tweens.addScalar(
        ScalarTween(
          from: 0,
          to: -7.0,
          duration: 1.05,
          apply: (v) => outerRing.rotation.setFrom(Quaternion.euler(v, 0, 0)),
        ),
      );
      tweens.addScalar(
        ScalarTween(
          from: 1.0,
          to: 0.0,
          duration: 1.05,
          apply: (a) =>
              outerMat.albedoColor = CyberPalette.magenta.withValues(alpha: a),
        ),
      );

      // 地面冲击波：贴地快速扩散的薄环。
      final shockMat = UnlitMaterial(albedoColor: CyberPalette.cyan);
      final shock = MeshComponent(
        mesh: RingMesh(
          innerRadius: 0.30,
          outerRadius: 0.42,
          material: shockMat,
        ),
        position: at + Vector3(0, 0.035, 0),
      );
      _spawnTransient(shock, ttl: 0.55);
      tweens.addVector(
        Vector3Tween(
          from: Vector3.all(0.5),
          to: Vector3.all(4.2),
          duration: 0.55,
          ease: easeOutCubic,
          apply: (v) => shock.scale.setFrom(v),
        ),
      );
      tweens.addScalar(
        ScalarTween(
          from: 0.95,
          to: 0.0,
          duration: 0.55,
          apply: (a) =>
              shockMat.albedoColor = CyberPalette.cyan.withValues(alpha: a),
        ),
      );

      // 副光柱：更细更高、错峰拔起，主副光柱形成双色拔剑感。
      final subMat = UnlitMaterial(albedoColor: CyberPalette.magenta);
      final subBeam = MeshComponent(
        mesh: CylinderMesh(
          radius: 0.14,
          height: 1,
          segments: 16,
          material: subMat,
        ),
        position: at + Vector3(0, 0.5, 0),
      );
      _spawnTransient(subBeam, ttl: 0.85);
      tweens.addScalar(
        ScalarTween(
          from: 0.01,
          to: 4.2,
          duration: 0.38,
          ease: easeOutCubic,
          apply: (v) {
            subBeam.scale.setFrom(Vector3(1, v, 1));
            subBeam.position.setFrom(at + Vector3(0, v / 2, 0));
          },
          onComplete: () {
            tweens.addScalar(
              ScalarTween(
                from: 1.0,
                to: 0.0,
                duration: 0.42,
                apply: (a) => subMat.albedoColor = CyberPalette.magenta
                    .withValues(alpha: a),
              ),
            );
          },
        ),
      );
    }

    // 粒子爆发（池上限 260，分层不堆量：主色 + 少量异色细粒）
    particles.burst(
      origin: at + Vector3(0, 0.4, 0),
      color: color,
      count: cyber ? 46 : 34,
      speed: cyber ? 3.6 : 3.0,
      life: cyber ? 1.1 : 0.9,
    );
    if (cyber) {
      particles.burst(
        origin: at + Vector3(0, 0.7, 0),
        color: CyberPalette.cyan,
        count: 14,
        speed: 2.2,
        upBias: 1.1,
        life: 0.8,
        size: 0.06,
      );
    }
  }

  // ───────────────────────── 攻击 ─────────────────────────

  /// 攻击光束（高攻怪追加）：从 [from] 到 [to] 的瞬时圆柱光束。
  void playBeamFx(Vector3 from, Vector3 to, {ui.Color? color}) {
    final cyber = CyberSkin.isOn;
    final beamColor =
        color ?? (cyber ? CyberPalette.beam : CyberPalette.classicBeam);
    final dir = to - from;
    final length = dir.length;
    if (length < 1e-3) return;
    final material = UnlitMaterial(albedoColor: beamColor);
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
    tweens.addScalar(
      ScalarTween(
        from: 1.0,
        to: 0.0,
        duration: 0.32,
        apply: (a) => material.albedoColor = beamColor.withValues(alpha: a),
      ),
    );

    if (cyber) {
      // 内芯：更细的品红光束，稍晚淡出，形成双色「能量束」。
      final coreMat = UnlitMaterial(albedoColor: CyberPalette.magenta);
      final core = MeshComponent(
        mesh: CylinderMesh(
          radius: 0.035,
          height: 1,
          segments: 8,
          material: coreMat,
        ),
        position: (from + to) / 2,
      );
      if (axis.length > 1e-4) {
        core.rotation.setFrom(Quaternion.axisAngle(axis.normalized(), angle));
      } else if (d.y < 0) {
        core.rotation.setFrom(Quaternion.axisAngle(Vector3(1, 0, 0), math.pi));
      }
      core.scale.setFrom(Vector3(1, length, 1));
      _spawnTransient(core, ttl: 0.42);
      tweens.addScalar(
        ScalarTween(
          from: 1.0,
          to: 0.0,
          duration: 0.42,
          apply: (a) =>
              coreMat.albedoColor = CyberPalette.magenta.withValues(alpha: a),
        ),
      );
      // 沿束撒少量细粒（每 0.6 世界单位一个，最多 12 个）。
      final steps = math.min(12, (length / 0.6).ceil());
      for (var i = 1; i < steps; i++) {
        particles.trail(
          origin: from + dir * (i / steps),
          color: CyberPalette.cyan,
          size: 0.06,
          life: 0.35,
        );
      }
    }
  }

  /// 命中爆发（攻击命中点 / 破坏点）。
  void playImpactFx(Vector3 at, {ui.Color? color}) {
    final cyber = CyberSkin.isOn;
    final impactColor =
        color ?? (cyber ? CyberPalette.impact : CyberPalette.classicImpact);
    particles.burst(
      origin: at,
      color: impactColor,
      count: cyber ? 44 : 30,
      speed: cyber ? 4.0 : 3.4,
      life: 0.7,
      size: 0.11,
    );
    if (cyber) {
      // 异色细粒：青色上冲，模拟能量溅射。
      particles.burst(
        origin: at,
        color: CyberPalette.cyan,
        count: 12,
        speed: 2.0,
        upBias: 1.2,
        life: 0.5,
        size: 0.07,
      );
      // 品红外圈闪光：比白核心更大、更慢淡出。
      final auraMat = UnlitMaterial(albedoColor: CyberPalette.magenta);
      final aura = MeshComponent(
        mesh: PlaneMesh(size: Vector2(1, 1), material: auraMat),
        position: at.clone(),
        rotation: Quaternion.euler(0, 1.5707963, 0),
      );
      _spawnTransient(aura, ttl: 0.30);
      tweens.addVector(
        Vector3Tween(
          from: Vector3.all(0.3),
          to: Vector3.all(2.8),
          duration: 0.30,
          ease: easeOutCubic,
          apply: (v) => aura.scale.setFrom(v),
        ),
      );
      tweens.addScalar(
        ScalarTween(
          from: 0.8,
          to: 0.0,
          duration: 0.30,
          apply: (a) =>
              auraMat.albedoColor = CyberPalette.magenta.withValues(alpha: a),
        ),
      );
    }
    // 命中闪光：瞬放的大平面
    final flashMaterial = UnlitMaterial(
      albedoColor: const ui.Color(0xFFFFFFFF),
    );
    final flash = MeshComponent(
      mesh: PlaneMesh(size: Vector2(1, 1), material: flashMaterial),
      position: at.clone(),
      rotation: Quaternion.euler(0, 1.5707963, 0),
    );
    _spawnTransient(flash, ttl: 0.18);
    tweens.addVector(
      Vector3Tween(
        from: Vector3.all(0.2),
        to: Vector3.all(cyber ? 2.1 : 1.8),
        duration: 0.18,
        ease: easeOutCubic,
        apply: (v) => flash.scale.setFrom(v),
      ),
    );
    tweens.addScalar(
      ScalarTween(
        from: 0.95,
        to: 0.0,
        duration: 0.18,
        apply: (a) => flashMaterial.albedoColor = const ui.Color(
          0xFFFFFFFF,
        ).withValues(alpha: a),
      ),
    );
  }

  // ───────────────────────── 伤害数字 ─────────────────────────

  final List<MeshComponent> _digitPool = [];

  /// 在 [at] 上方飘出伤害/回复数字（billboard 由 update 驱动朝向相机）。
  void playDamageNumber(Vector3 at, int amount, {bool heal = false}) {
    final text = (heal ? '+' : '-') + amount.abs().toString();
    final cyber = CyberSkin.isOn;
    final color = heal
        ? (cyber ? CyberPalette.heal : CyberPalette.classicHeal)
        : (cyber ? CyberPalette.danger : CyberPalette.classicDanger);
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
      tweens.addScalar(
        ScalarTween(
          from: 0,
          to: 1,
          duration: 1.0,
          apply: (t) {
            digit.position.setFrom(basePos + Vector3(0, t * 0.9, 0));
            final alpha = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
            material.albedoColor = color.withValues(
              alpha: alpha.clamp(0.0, 1.0),
            );
          },
        ),
      );
      tweens.addVector(
        Vector3Tween(
          from: Vector3.all(0.01),
          to: Vector3.all(0.55),
          duration: 0.25 + delay,
          ease: easeOutBack,
          apply: (v) => digit.scale.setFrom(v),
        ),
      );
    }
  }

  // ───────────────────────── 抽牌飞牌 ─────────────────────────

  /// 抽牌三段式演出（MDPro3 风格）：
  /// 1) 从牌组弹起（上升 + 放大）
  /// 2) 悬停翻牌：[faceCode] 非空（明牌/己方抽牌）时绕 Y 轴翻到正面卡图
  /// 3) 弧线滑向手牌方向 + 粒子拖尾，末端缩小消失
  ///
  /// [index] 连抽时的序号（错帧播放）；[toSelf] 为己方（飞向屏幕近端）。
  /// 各阶段通过 onComplete 链式调度（TweenEngine 的补间并行执行，
  /// 并行写同一属性会互相覆盖）。
  Future<void> playDrawFlight(
    Vector3 from, {
    required bool toSelf,
    int index = 0,
    int? faceCode,
  }) async {
    final back = await CardTextureCache.instance.cardBack();
    final material = UnlitMaterial(albedoTexture: back);
    final card = MeshComponent(
      mesh: PlaneMesh(size: Vector2(0.62, 0.90), material: material),
      position: from + Vector3(0, 0.2, 0),
      rotation: Quaternion.euler(0, 1.5707963, 0),
      scale: Vector3.all(0.3),
    );
    // 悬停点：牌组上方，略偏场心（朝镜头方向）
    final hover = from + Vector3(-from.x * 0.25, 2.2, -from.z * 0.25);
    // 手牌方向终点：己方近端下方（HUD 手牌区），对方远端上方
    final target = toSelf ? Vector3(0, 1.0, 5.6) : Vector3(0, 1.6, -5.6);
    final stagger = index * 0.22;
    final total = stagger + 0.32 + 0.3 + 0.6; // 延迟+弹起+翻牌+滑入
    _spawnTransient(card, ttl: total + 0.05);

    _after(stagger, () {
      // 阶段 1：弹起
      tweens.addVector(
        Vector3Tween(
          from: card.position.clone(),
          to: hover,
          duration: 0.32,
          ease: easeOutCubic,
          apply: (v) => card.position.setFrom(v),
        ),
      );
      tweens.addVector(
        Vector3Tween(
          from: Vector3.all(0.3),
          to: Vector3.all(1.0),
          duration: 0.32,
          ease: easeOutBack,
          apply: (v) => card.scale.setFrom(v),
          onComplete: () {
            // 阶段 2：悬停翻牌（明牌翻到卡图，否则卡背转一圈示意）
            final flipTo = faceCode != null ? math.pi : math.pi * 2;
            var swapped = false;
            tweens.addScalar(
              ScalarTween(
                from: 0,
                to: flipTo,
                duration: 0.3,
                ease: easeInOutCubic,
                apply: (v) {
                  card.rotation.setFrom(Quaternion.euler(0, 1.5707963 + v, 0));
                  if (!swapped && faceCode != null && v >= math.pi / 2) {
                    swapped = true;
                    CardTextureCache.instance.ensure(faceCode, (texture) {
                      material.albedoTexture = texture;
                    });
                  }
                },
                onComplete: () {
                  // 阶段 3：滑向手牌 + 拖尾 + 缩小
                  tweens.addVector(
                    Vector3Tween(
                      from: card.position.clone(),
                      to: target,
                      duration: 0.6,
                      arcHeight: 0.5,
                      ease: easeInOutCubic,
                      apply: (v) {
                        card.position.setFrom(v);
                        particles.trail(
                          origin: v,
                          color: CyberSkin.isOn
                              ? CyberPalette.cyan
                              : CyberPalette.classicBeam,
                        );
                        if (CyberSkin.isOn) {
                          particles.trail(
                            origin: v,
                            color: CyberPalette.magenta,
                            size: 0.05,
                            life: 0.3,
                          );
                        }
                      },
                    ),
                  );
                  tweens.addVector(
                    Vector3Tween(
                      from: Vector3.all(1.0),
                      to: Vector3.all(0.4),
                      duration: 0.6,
                      apply: (v) => card.scale.setFrom(v),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    });
  }

  /// 延迟 [delay] 秒后执行 [fn]（借道补间引擎的空标量补间）。
  void _after(double delay, void Function() fn) {
    if (delay <= 0) {
      fn();
      return;
    }
    tweens.addScalar(
      ScalarTween(
        from: 0,
        to: 1,
        duration: delay,
        apply: (_) {},
        onComplete: fn,
      ),
    );
  }

  // ───────────────────────── 内部 ─────────────────────────

  void _spawnTransient(
    Component3D component, {
    required double ttl,
    void Function()? onDone,
  }) {
    _transient.add(component);
    add(component);
    tweens.addScalar(
      ScalarTween(
        from: 0,
        to: 1,
        duration: ttl,
        apply: (_) {},
        onComplete: () {
          component.removeFromParent();
          _transient.remove(component);
          onDone?.call();
        },
      ),
    );
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
          digit.rotation.setFrom(Quaternion.euler(yaw, 1.5707963 + pitch, 0));
        }
      }
    }
  }

  Vector3? _cameraPosition;

  /// 由 Game 每帧提供相机位置（伤害数字 billboard 用）。
  set cameraPosition(Vector3 value) => _cameraPosition = value;
}
