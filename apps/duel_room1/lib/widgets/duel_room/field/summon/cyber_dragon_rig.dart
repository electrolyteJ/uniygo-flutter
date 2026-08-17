import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/resources.dart';

/// 程序化「电子龙」机械蛇形装备（rig）。
///
/// 仓库没有电子龙的 glb 模型资源（且版权敏感），这里用参数化几何体
/// 拼一只风格化机械龙：金属躯干节段 + 青色自发光胸口核心/眼部，
/// 契合电子龙的机械蛇设定，零版权风险。
///
/// 同时承担召唤演出驱动：[update] 内推进时间线：
/// 升起螺旋 → 展开盘旋 → 落地闪光 → 回调移除。
class CyberDragonRig extends Object3D {
  CyberDragonRig({required this.onCompleted, Vector3? basePosition})
    : basePosition = basePosition ?? Vector3.zero();

  /// 演出结束回调（组件随即自行移除）。
  final void Function() onCompleted;

  /// 演出基准位置（目标卡槽的世界坐标）；时间线在此基础上叠加位移。
  final Vector3 basePosition;

  /// 演出总时长（秒）。
  static const double duration = 1.55;

  // ---- 时间线拐点 ----
  static const double _riseEnd = 0.9;
  static const double _flourishEnd = 1.25;

  // ---- 躯干参数 ----
  static const int _segmentCount = 9;
  static const double _segmentSpacing = 0.34;

  final List<MeshComponent> _segments = [];

  /// 落地闪光球：自发光（Unlit）材质，落地阶段从 0 膨胀再收回，
  /// 代替光源强度脉冲（flame_3d 的 LightSource.intensity 不可变）。
  late final MeshComponent _flashOrb;

  double _t = 0;
  bool _completed = false;

  /// 金属银材质（躯干）。
  static final _metalMaterial = SpatialMaterial(
    albedoColor: const Color(0xFFDDE4EE),
    metallic: 0.95,
    roughness: 0.25,
  );

  /// 深色关节材质。
  static final _jointMaterial = SpatialMaterial(
    albedoColor: const Color(0xFF3A4250),
    metallic: 0.8,
    roughness: 0.5,
  );

  /// 青色自发光材质（核心/眼部——「电子」感来源）。
  static final _glowMaterial = UnlitMaterial(
    albedoColor: const Color(0xFF35E8FF),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildBody();
    _buildHead();
    _flashOrb = MeshComponent(
      mesh: SphereMesh(radius: 1, segments: 24, material: _glowMaterial),
      position: Vector3(0, 0.2, 0),
      scale: Vector3.zero(),
    );
    await add(_flashOrb);
  }

  /// 自身无可视网格（视觉全部由子组件承担），空实现。
  @override
  void draw(RenderContext context) {}

  void _buildBody() {
    for (var i = 0; i < _segmentCount; i++) {
      final frac = i / (_segmentCount - 1);
      final radius = 0.30 - 0.17 * frac; // 头粗尾细
      final segment = MeshComponent(
        mesh: SphereMesh(radius: radius, segments: 24, material: _metalMaterial),
        position: _restPose(i),
      );
      _segments.add(segment);
      add(segment);
      // 节段间的深色关节环
      if (i > 0) {
        final joint = MeshComponent(
          mesh: SphereMesh(radius: radius * 0.55, segments: 12, material: _jointMaterial),
          position: _restPose(i) + Vector3(0, -0.1, 0.12),
        );
        add(joint);
      }
    }
    // 胸口自发光核心（第 2 节位置）
    final core = MeshComponent(
      mesh: SphereMesh(radius: 0.15, segments: 16, material: _glowMaterial),
      position: _restPose(1) + Vector3(0, 0, 0.30),
    );
    add(core);
  }

  void _buildHead() {
    final headPos = _restPose(0) + Vector3(0, 0.16, 0.34);
    add(
      MeshComponent(
        mesh: CuboidMesh(size: Vector3(0.44, 0.26, 0.62), material: _metalMaterial),
        position: headPos,
      ),
    );
    // 眼部发光条
    add(
      MeshComponent(
        mesh: CuboidMesh(size: Vector3(0.34, 0.05, 0.05), material: _glowMaterial),
        position: headPos + Vector3(0, 0.05, 0.32),
      ),
    );
    // 双角（向后掠的圆锥）
    for (final side in [-1.0, 1.0]) {
      add(
        MeshComponent(
          mesh: ConeMesh(radius: 0.06, height: 0.5, material: _metalMaterial),
          position: headPos + Vector3(0.14 * side, 0.16, -0.18),
          rotation: Quaternion.euler(-0.9, 0, 0.12 * side),
        ),
      );
    }
  }

  /// 静止姿态：蛇形 S 曲线——头在前上方，躯干向后下方盘绕。
  Vector3 _restPose(int i) {
    final angle = i * 0.55;
    return Vector3(
      math.sin(angle) * 0.38,
      0.55 - i * _segmentSpacing * 0.52,
      -i * _segmentSpacing + math.cos(angle) * 0.1,
    );
  }

  static double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

  @override
  void update(double dt) {
    super.update(dt);
    if (_completed) return;
    _t += dt;

    // ---- 根变换：升起螺旋 → 盘旋 → 落地 ----
    double rootY;
    double spin;
    double scale;
    if (_t < _riseEnd) {
      final k = _easeOutCubic(_t / _riseEnd);
      rootY = -3.2 + 3.2 * k;
      spin = 4 * math.pi * k;
      scale = 0.25 + 0.75 * k;
    } else if (_t < _flourishEnd) {
      final k = (_t - _riseEnd) / (_flourishEnd - _riseEnd);
      rootY = 0;
      spin = 4 * math.pi + math.pi * k;
      scale = 1.0;
    } else {
      final k = _easeOutCubic((_t - _flourishEnd) / (duration - _flourishEnd));
      rootY = -0.75 * k;
      spin = 5 * math.pi + 0.4 * k;
      scale = 1.0 - 0.15 * k;
    }
    transform.position.setValues(
      basePosition.x,
      basePosition.y + rootY,
      basePosition.z,
    );
    transform.rotation.setFrom(Quaternion.euler(0, spin, 0));
    transform.scale.splat(scale); // splat 在 NotifyingVector3 覆写清单内，确保触发变换通知

    // ---- 蛇形波动（节段相位差正弦） ----
    final amp = _t < _riseEnd ? 0.02 : 0.06;
    for (var i = 0; i < _segments.length; i++) {
      final base = _restPose(i);
      _segments[i].transform.position.setValues(
        base.x + math.sin(_t * 6 + i * 0.8) * amp * (i / _segments.length),
        base.y,
        base.z,
      );
    }

    // ---- 落地闪光：自发光球膨胀-收回 ----
    if (_t > _flourishEnd) {
      final k = ((_t - _flourishEnd) / (duration - _flourishEnd)).clamp(0.0, 1.0);
      _flashOrb.transform.scale.splat(2.4 * math.sin(k * math.pi));
    }

    if (_t >= duration) {
      _completed = true;
      onCompleted();
      removeFromParent();
    }
  }
}
