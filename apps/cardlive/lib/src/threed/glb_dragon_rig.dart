import 'dart:math' as math;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/model.dart'
    show AnimationState, Model, ModelComponent;

import 'glb_mesh_loader.dart';
/// glb 模型版召唤演出 rig（cardlive 鉴赏页电子龙条目使用）。
///
/// 时间线分两段：
/// 1. 召唤演出（约 [summonDuration] 秒）：升起螺旋 → 展开盘旋 →
///    落地闪光，与程序化 [CyberDragonRig] 同一套节奏；
/// 2. 待机动画（无限）：慢速转盘展示 + 上下浮动 + 呼吸缩放，
///    让静态 glb 模型持续「活」着。
///
/// [loop] 为 true 时演出结束进入待机循环（鉴赏模式）；
/// 否则演出结束即回调 [onCompleted] 并自行移除。
class GlbDragonRig extends Object3D {
  GlbDragonRig({
    required this.assetPath,
    required this.onCompleted,
    Vector3? basePosition,
    this.loop = false,
    this.targetHeight = 1.7,
  }) : basePosition = basePosition ?? Vector3.zero();

  /// cardlive 包内 glb 资产路径（相对资产根 assets/ 之后），
  /// 如 models/cyber_dragon.glb。
  final String assetPath;

  /// 演出结束回调（组件随即自行移除）。[loop] 模式下不会被调用。
  final void Function() onCompleted;

  /// 演出基准位置（世界坐标）；时间线在此基础上叠加位移。
  final Vector3 basePosition;

  /// 鉴赏模式：召唤演出结束后进入无限待机动画。
  final bool loop;

  /// 模型归一化后的目标高度（世界单位）。
  final double targetHeight;

  /// 召唤演出总时长（秒）。
  static const double summonDuration = 1.6;

  // ---- 召唤时间线拐点 ----
  static const double _riseEnd = 0.95;
  static const double _flourishEnd = 1.3;

  /// 落地沉降量（比程序化 rig 浅，待机浮动围绕落点）。
  static const double _landSink = 0.35;

  /// 待机动画起始 yaw（接续召唤收尾的 5π+0.4，避免跳变）。
  static const double _idleBaseYaw = 5 * math.pi + 0.4;

  ModelComponent? _model;

  double _t = 0;
  double _idleT = 0;
  bool _summonDone = false;
  bool _completed = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final model = await loadCardliveModel(assetPath);

    // 归一化：按节点变换后的包围盒缩放到 targetHeight，
    // x/z 居中，底面落在 y=0。
    final bounds = _modelBounds(model);
    final size = bounds.max - bounds.min;
    final fitScale = size.y > 1e-6 ? targetHeight / size.y : 1.0;
    final centerX = (bounds.min.x + bounds.max.x) / 2;
    final centerZ = (bounds.min.z + bounds.max.z) / 2;
    _model = ModelComponent(
      model: model,
      scale: Vector3.all(fitScale),
      position: Vector3(
        -centerX * fitScale,
        -bounds.min.y * fitScale,
        -centerZ * fitScale,
      ),
    );
    await add(_model!);
  }

  /// 模型应用节点变换后的包围盒：
  /// 各网格 AABB 的 8 个角点经所属节点 combinedTransform 变换后取并集。
  /// （[Model.aabb] 不含节点变换，直接拿来归一化会算错尺寸。）
  Aabb3 _modelBounds(Model model) {
    final processed = model.processNodes(AnimationState());
    var minX = double.infinity;
    var minY = double.infinity;
    var minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var maxZ = double.negativeInfinity;
    for (final node in processed.values) {
      final mesh = node.node.mesh;
      if (mesh == null) continue;
      final box = mesh.aabb;
      for (final x in [box.min.x, box.max.x]) {
        for (final y in [box.min.y, box.max.y]) {
          for (final z in [box.min.z, box.max.z]) {
            final p = node.combinedTransform.transform3(Vector3(x, y, z));
            minX = math.min(minX, p.x);
            minY = math.min(minY, p.y);
            minZ = math.min(minZ, p.z);
            maxX = math.max(maxX, p.x);
            maxY = math.max(maxY, p.y);
            maxZ = math.max(maxZ, p.z);
          }
        }
      }
    }
    return Aabb3.minMax(Vector3(minX, minY, minZ), Vector3(maxX, maxY, maxZ));
  }

  /// 自身无可视网格（视觉由子组件承担），空实现。
  @override
  void draw(RenderContext context) {}

  /// 覆盖局部包围盒：flame_3d 的 AABB 脏标记只向上传播，祖先移动时
  /// 子组件的世界 AABB 不会重算（冻结在初始帧位置），导致本 rig 的
  /// 包围盒永远停在升起前（-3.2），视锥剔除恒为 outside、子组件
  /// 被跳过。返回一个覆盖演出活动范围的局部盒，让剔除按当前帧
  /// 变换正常工作。
  @override
  Aabb3 computeLocalAabb() => Aabb3.minMax(
        Vector3.all(-_effectRadius),
        Vector3.all(_effectRadius),
      );

  /// 演出活动半径：模型归一化高度 1.7 + 升起行程 3.2 + 余量。
  static const double _effectRadius = 6.0;


  static double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

  @override
  void update(double dt) {
    super.update(dt);
    if (_completed) return;
    // 模型异步加载期间不走时间线：避免非 loop 模式下演出
    // 「播完」、rig 在模型就绪前就自行移除（什么都看不到）。
    if (_model == null) return;

    if (!_summonDone) {
      _updateSummon(dt);
    } else {
      _updateIdle(dt);
    }
    // flame_3d 的 AABB 脏标记只向上传播：rig 移动后子组件的世界
    // AABB 不会自动重算（其变换矩阵已随向下传播刷新，缺的只是触发
    // 重算），每帧标记一次让子组件剔除判定跟得上。
    _model?.markAabbDirty();
  }

  void _updateSummon(double dt) {
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
      final k = _easeOutCubic((_t - _flourishEnd) / (summonDuration - _flourishEnd));
      rootY = -_landSink * k;
      spin = 5 * math.pi + 0.4 * k;
      scale = 1.0 - 0.15 * k;
    }
    transform.position.setValues(
      basePosition.x,
      basePosition.y + rootY,
      basePosition.z,
    );
    transform.rotation.setFrom(Quaternion.euler(spin, 0, 0));
    transform.scale.splat(scale);

    if (_t >= summonDuration) {
      _summonDone = true;
      if (!loop) {
        _completed = true;
        onCompleted();
        removeFromParent();
      }
    }
  }

  /// 待机：慢速转盘 + 上下浮动 + 呼吸缩放（围绕落点与收尾姿态接续）。
  void _updateIdle(double dt) {
    _idleT += dt;
    final bob = math.sin(_idleT * 1.5) * 0.05;
    final yaw = _idleBaseYaw + _idleT * 0.55 + math.sin(_idleT * 1.1) * 0.06;
    final breathe = 0.85 * (1.0 + math.sin(_idleT * 2.1) * 0.02);
    transform.position.setValues(
      basePosition.x,
      basePosition.y - _landSink + bob,
      basePosition.z,
    );
    transform.rotation.setFrom(Quaternion.euler(yaw, 0, 0));
    transform.scale.splat(breathe);
  }
}
