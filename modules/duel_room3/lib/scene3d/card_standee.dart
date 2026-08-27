import 'dart:ui' as ui;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';

import 'card_texture_cache.dart';
import 'field_3d_layout.dart';
import 'tween_3d.dart';

/// 立牌登场方式（场景层自有枚举，biz 的 SummonEffectType 由桥接层映射）。
enum StandeeEntrance { appear, summon, set, flip }

/// 3D 卡图立牌：竖直 PlaneMesh（卡图/卡背纹理）+ 薄边框 + XYZ 素材堆。
///
/// 变换约定：
/// - 根组件位于立牌中心（离地 [Field3DLayout.standeeBaseY] + cardH/2）
/// - 卡面 PlaneMesh 绕 X 轴 +90° 立起（PlaneMesh 默认平躺 XZ、法线 +Y，
///   旋转后位于 XY 平面、法线 +Z 朝向己方相机，纹理 v=0 在顶部）
/// - 守备表示：根组件绕 Y 轴 yaw 90°
/// - 里侧表示：纹理换成卡背
///
/// 注意 vector_math 的 Quaternion.euler(yaw, pitch, roll) 顺序为 Y/X/Z，
/// 欧拉角状态由本类字段 [_yawAngle]/[_tiltAngle] 维护（四元数分量不是角度）。
class CardStandee extends Component3D {
  CardStandee({
    required this.slotId,
    required this.code,
    required this.cardPosition,
    this.overlayCount = 0,
  });

  /// 所属槽位 id（[ZoneSlot3D].id，EMZ 为首个 slotKey）。
  final String slotId;

  int code;
  int cardPosition;
  int overlayCount;

  final TweenEngine3D tweens = TweenEngine3D();

  late final UnlitMaterial _frontMaterial;
  late final SpatialMaterial _frameMaterial;
  final List<MeshComponent> _overlaySlabs = [];
  bool _facedown = false;

  /// 销毁/移除中（析构动画播放后置位，控制器据此回收）。
  bool dying = false;

  /// 当前欧拉角状态（弧度）。yaw = 绕 Y（翻转演出），tilt = 绕 X 后仰，
  /// roll = 绕 Z 横置（守备表示）。
  double _yawAngle = 0;
  double _tiltAngle = Field3DLayout.standeeTiltRad;
  double _rollAngle = 0;

  double get _targetRoll => Field3DLayout.standeeRoll(cardPosition);

  void _compose() {
    rotation.setFrom(Quaternion.euler(_yawAngle, _tiltAngle, _rollAngle));
  }

  @override
  Future<void> onLoad() async {
    _facedown = Field3DLayout.isFacedown(cardPosition);
    _rollAngle = _targetRoll;
    _frontMaterial = UnlitMaterial(
      albedoColor: const ui.Color(0xFF8A93A8), // 卡图未加载时的占位色
    );
    _frameMaterial = SpatialMaterial(
      albedoColor: const ui.Color(0xFF161B28),
      metallic: 0.4,
      roughness: 0.5,
    );
    await addAll([
      // 边框（略大于卡面的薄板，垫在卡面后面）
      MeshComponent(
        mesh: CuboidMesh(
          size: Vector3(
            Field3DLayout.cardW + 0.07,
            Field3DLayout.cardH + 0.07,
            0.035,
          ),
          material: _frameMaterial,
        ),
        position: Vector3(0, 0, -0.022),
      ),
      // 卡面（平躺平面绕 X 立起）
      MeshComponent(
        mesh: PlaneMesh(
          size: Vector2(Field3DLayout.cardW, Field3DLayout.cardH),
          material: _frontMaterial,
        ),
        rotation: Quaternion.euler(0, 1.5707963, 0),
      ),
    ]);
    _compose();
    _syncOverlays();
    _loadTexture();
  }

  void _loadTexture() {
    if (_facedown || code <= 0) {
      CardTextureCache.instance.cardBack().then((t) {
        if (dying) return;
        _frontMaterial.albedoTexture = t;
        _frontMaterial.albedoColor = const ui.Color(0xFFFFFFFF);
      });
    } else {
      CardTextureCache.instance.ensure(code, (texture) {
        if (dying) return;
        _frontMaterial.albedoTexture = texture;
        _frontMaterial.albedoColor = const ui.Color(0xFFFFFFFF);
      });
    }
  }

  /// 快照更新：表示形式/素材数/卡号变化。
  void applyCard({
    required int code,
    required int position,
    required int overlayCount,
  }) {
    final prevFacedown = _facedown;
    this.code = code;
    cardPosition = position;
    this.overlayCount = overlayCount;
    _facedown = Field3DLayout.isFacedown(position);
    if (prevFacedown != _facedown) _loadTexture();
    _syncOverlays();
    final targetRoll = _targetRoll;
    if ((targetRoll - _rollAngle).abs() > 1e-3) {
      final from = _rollAngle;
      _rollAngle = targetRoll;
      tweens.addScalar(ScalarTween(
        from: from,
        to: targetRoll,
        duration: 0.35,
        apply: (v) {
          _rollAngle = v;
          _compose();
        },
      ));
    }
  }

  void _syncOverlays() {
    // XYZ 素材：卡座前方一排小薄片（立起的小卡背靠前）
    while (_overlaySlabs.length < overlayCount) {
      final i = _overlaySlabs.length;
      final slab = MeshComponent(
        mesh: CuboidMesh(
          size: Vector3(0.22, 0.22, 0.03),
          material: UnlitMaterial(albedoColor: const ui.Color(0xFF0C0E14)),
        ),
        position: Vector3(
          -0.35 + 0.26 * i,
          -Field3DLayout.cardH / 2 + 0.13,
          0.12,
        ),
      );
      _overlaySlabs.add(slab);
      add(slab);
    }
    while (_overlaySlabs.length > overlayCount) {
      _overlaySlabs.removeLast().removeFromParent();
    }
  }

  /// 选中/可交互发光描边（null 关闭）。
  void setGlow(ui.Color? color) {
    _frameMaterial.albedoColor = color ?? const ui.Color(0xFF161B28);
  }

  /// 登场动画。
  void playEntrance(StandeeEntrance entrance) {
    switch (entrance) {
      case StandeeEntrance.summon:
        scale.setFrom(Vector3.all(0.01));
        tweens.addVector(Vector3Tween(
          from: Vector3.all(0.01),
          to: Vector3.all(1),
          duration: 0.45,
          ease: easeOutBack,
          apply: (v) => scale.setFrom(v),
        ));
      case StandeeEntrance.flip:
        final startYaw = _yawAngle;
        tweens.addScalar(ScalarTween(
          from: startYaw,
          to: startYaw + 1.5707963,
          duration: 0.18,
          apply: (v) {
            _yawAngle = v;
            _compose();
          },
          onComplete: () {
            _facedown = false;
            _loadTexture();
            tweens.addScalar(ScalarTween(
              from: _yawAngle,
              to: _yawAngle + 1.5707963,
              duration: 0.18,
              apply: (v) {
                _yawAngle = v;
                _compose();
              },
            ));
          },
        ));
      case StandeeEntrance.set:
      case StandeeEntrance.appear:
        scale.setFrom(Vector3.all(0.01));
        tweens.addVector(Vector3Tween(
          from: Vector3.all(0.01),
          to: Vector3.all(1),
          duration: 0.3,
          ease: easeOutCubic,
          apply: (v) => scale.setFrom(v),
        ));
    }
  }

  /// 攻击前扑：向 [target] 冲刺大半距离后返回，命中瞬间回调。
  void lunge(Vector3 target, {void Function()? onImpact}) {
    final from = position.clone();
    final hit = from + (target - from) * 0.72;
    tweens.addVector(Vector3Tween(
      from: from,
      to: hit,
      duration: 0.22,
      apply: (v) => position.setFrom(v),
      onComplete: () {
        onImpact?.call();
        tweens.addVector(Vector3Tween(
          from: hit,
          to: from,
          duration: 0.35,
          ease: easeOutCubic,
          apply: (v) => position.setFrom(v),
        ));
      },
    ));
  }

  /// 破坏动画：后仰倒地 + 下沉缩小，完成后回调（控制器移除组件）。
  void die({void Function()? onDone}) {
    dying = true;
    final fromTilt = _tiltAngle;
    _tiltAngle = -1.35;
    tweens.addScalar(ScalarTween(
      from: fromTilt,
      to: -1.35,
      duration: 0.4,
      apply: (v) {
        _tiltAngle = v;
        _compose();
      },
    ));
    tweens.addVector(Vector3Tween(
      from: position.clone(),
      to: position.clone()..y -= 1.2,
      duration: 0.5,
      apply: (v) => position.setFrom(v),
      onComplete: onDone,
    ));
    tweens.addVector(Vector3Tween(
      from: scale.clone(),
      to: Vector3.all(0.01),
      duration: 0.5,
      apply: (v) => scale.setFrom(v),
    ));
  }

  /// 飞向指定世界点（送墓/回手等弧线飞行），完成后回调。
  void flyTo(Vector3 target, {double arcHeight = 1.2, void Function()? onDone}) {
    tweens.addVector(Vector3Tween(
      from: position.clone(),
      to: target,
      duration: 0.45,
      arcHeight: arcHeight,
      apply: (v) => position.setFrom(v),
      onComplete: onDone,
    ));
    tweens.addVector(Vector3Tween(
      from: scale.clone(),
      to: Vector3.all(0.4),
      duration: 0.45,
      apply: (v) => scale.setFrom(v),
    ));
  }

  /// 命中检测用的世界空间 AABB（立牌卡体范围）。
  Aabb3 hitAabb() {
    final w = Field3DLayout.cardW * scale.x;
    final h = Field3DLayout.cardH * scale.y;
    final isDefense = _targetRoll.abs() > 0.1;
    final halfW = (isDefense ? h : w) / 2;
    return Aabb3.minMax(
      Vector3(position.x - halfW, position.y - h / 2, position.z - 0.15),
      Vector3(position.x + halfW, position.y + h / 2, position.z + 0.15),
    );
  }

  @override
  void update(double dt) {
    tweens.tick(dt);
  }

  @override
  void onRemove() {
    tweens.clear();
    super.onRemove();
  }
}
