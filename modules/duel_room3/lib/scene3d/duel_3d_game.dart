import 'dart:ui';

import 'package:flame_3d/camera.dart';
import 'package:flame_3d/components.dart';
import 'package:flame_3d/game.dart';
import 'package:flame_3d/graphics.dart';

import 'arena_component.dart';
import 'camera_rig.dart';
import 'field_3d_layout.dart';
import 'fx/effects_manager.dart';
import 'raycast_3d.dart';
import 'standee_controller.dart';
import 'zone_grid_component.dart';

/// 决斗 3D 场景主 Game（纯 flame_3d 单层渲染）。
///
/// 职责：场景装配（竞技场/地砖/灯光）、相机运镜驱动、屏幕点击 →
/// 射线拾取分发。不 import Riverpod / biz —— 由页面侧 Duel3DBridge
/// 把状态快照翻译成指令调进来。
class Duel3DGame extends FlameGame3D<World3D, CameraComponent3D> {
  Duel3DGame({required int myController})
      : slots = Field3DLayout.buildSlots(myController),
        super(
          world: World3D(),
          camera: CameraComponent3D(
            position: Field3DLayout.defaultCameraPosition.clone(),
            target: Field3DLayout.defaultCameraTarget.clone(),
            fovY: Field3DLayout.defaultFovY,
          ),
        );

  /// 全部 32 个卡槽（布局期确定，整场复用）。
  final List<ZoneSlot3D> slots;

  final CameraRig cameraRig = CameraRig();
  late final ZoneGridComponent zoneGrid;
  late final StandeeController standees;
  late final EffectsManager effects;

  /// 卡槽 key → 立牌点击回调（优先于地砖点击）。由桥接层设置。
  void Function(String zoneKey)? onStandeeTap;

  /// 卡槽点击回调（参数为 [ZoneSlot3D.id]）。由桥接层设置。
  void Function(String slotId)? onSlotTap;

  /// 全局只初始化一次的 GpuBackend（幂等，cardlive 模式）：
  /// 渲染前必须预载全部 .shaderbundle，否则首帧材质抛异常。
  static Future<void>? _gpuBackendReady;

  /// 场景是否完成装配（onLoad 完成前 update 不得触碰 late 字段）。
  bool _sceneReady = false;

  /// 供页面层等待：GpuBackend 就绪后再挂载 GameWidget，
  /// 避免首帧渲染时 shader 尚未加载（Failed to initialize ShaderLibrary）。
  static Future<void> ensureGpuBackend() =>
      _gpuBackendReady ??= GpuBackend.initialize();

  @override
  Color backgroundColor() => const Color(0xFF05070F);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await ensureGpuBackend();
    zoneGrid = ZoneGridComponent(slots: slots);
    standees = StandeeController(slots: slots);
    effects = EffectsManager(camera: camera);
    await world.addAll([
      ArenaComponent(),
      zoneGrid,
      standees,
      effects,
      // flame_3d 无平行光/IBL；点光按 1/d² 衰减，强度按 cardlive 量级给。
      LightComponent.ambient(intensity: 0.62),
      LightComponent.point(position: Vector3(3, 6, 4), intensity: 60),
      LightComponent.point(
        position: Vector3(-3, 4, -5),
        color: const Color(0xFF88AAFF),
        intensity: 35,
      ),
    ]);
    _sceneReady = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_sceneReady) return;
    cameraRig.tick(camera, dt);
    effects.cameraPosition = camera.position;
  }

  /// 屏幕点击（逻辑像素）→ 射线拾取：优先立牌（后续接入），其次地砖。
  void handleTap(Offset screenPoint, Size viewportSize) {
    final ray = screenPointToRay(
      screenPoint: Vector2(screenPoint.dx, screenPoint.dy),
      viewportSize: Vector2(viewportSize.width, viewportSize.height),
      viewMatrix: camera.viewMatrix,
      projectionMatrix: camera.projectionMatrix,
    );
    // 优先命中立牌（立体卡体），其次地砖平面。
    final standeeKey = standees.hitTest(ray);
    if (standeeKey != null) {
      onStandeeTap?.call(standeeKey);
      return;
    }
    // 地砖平面求交（y=0）→ 找最近的槽位。
    final t = intersectPlaneY(ray, 0);
    if (t == null) return;
    final hit = ray.at(t);
    ZoneSlot3D? best;
    var bestDist = double.infinity;
    for (final slot in slots) {
      final dx = (hit.x - slot.center.x).abs();
      final dz = (hit.z - slot.center.z).abs();
      const half = Field3DLayout.tileSize / 2 + 0.08;
      if (dx <= half && dz <= half) {
        final d = dx + dz;
        if (d < bestDist) {
          bestDist = d;
          best = slot;
        }
      }
    }
    if (best != null) onSlotTap?.call(best.id);
  }
}
